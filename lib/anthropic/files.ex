defmodule Anthropic.Files do
  @moduledoc """
  The `Files` resource: upload a file once and reference it by `file_id` in a later message
  instead of inlining base64 data.

  This is a beta API. Every request this module sends automatically carries the
  `anthropic-beta: files-api-2025-04-14` header it currently requires — no client
  configuration needed, and this doesn't affect any other resource's requests.

  Referencing an uploaded file's `file_id` back in a `Messages.create/2` call (a `%{type:
  "file", file_id: ...}` content-block source) is *also* beta and not yet modeled by
  `Anthropic.Messages.Content.Image`/`Document` — pass it as a raw map, and add the same
  beta header to that call via `:default_headers` on the `Client` (or a one-off header if
  your Finch adapter supports per-request headers):

      {:ok, file} = Anthropic.Files.create(client, "/path/to/report.pdf")

      Anthropic.Messages.create(client,
        model: "claude-opus-4-8",
        max_tokens: 1024,
        messages: [
          %{role: "user", content: [%{type: "document", source: %{type: "file", file_id: file.id}}]}
        ]
      )
  """

  alias Anthropic.{Client, Error, HTTPTransport, Pagination}

  @beta_header {"anthropic-beta", "files-api-2025-04-14"}

  @type file_metadata :: %{
          id: String.t(),
          type: String.t(),
          filename: String.t(),
          mime_type: String.t(),
          size_bytes: non_neg_integer(),
          created_at: String.t(),
          downloadable: boolean() | nil,
          scope: String.t() | nil
        }

  @doc """
  Uploads a local file (by path). `:content_type` is guessed from the file extension via
  `MIME.from_path/1` when not given.
  """
  @spec create(Client.t(), path :: String.t(), content_type: String.t()) ::
          {:ok, file_metadata()} | {:error, Error.t()}
  def create(%Client{} = client, path, opts \\ []) when is_binary(path) do
    case File.read(path) do
      {:ok, data} ->
        content_type = Keyword.get_lazy(opts, :content_type, fn -> MIME.from_path(path) end)
        upload(client, data, Path.basename(path), content_type)

      {:error, reason} ->
        {:error,
         Error.validation("could not read file at #{path}: #{:file.format_error(reason)}")}
    end
  end

  @doc "Uploads raw binary data with an explicit filename (`:content_type` defaults to `\"application/octet-stream\"`)."
  @spec create_from_binary(Client.t(), binary(), String.t(), content_type: String.t()) ::
          {:ok, file_metadata()} | {:error, Error.t()}
  def create_from_binary(%Client{} = client, data, filename, opts \\ [])
      when is_binary(data) and is_binary(filename) do
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")
    upload(client, data, filename, content_type)
  end

  defp upload(client, data, filename, content_type) do
    fields = [{"file", data, filename: filename, content_type: content_type}]

    with {:ok, body} <- HTTPTransport.post_multipart(client, "/v1/files", fields, [@beta_header]) do
      {:ok, from_json(body)}
    end
  end

  @doc "Lists uploaded files, most recently created first."
  @spec list(Client.t(),
          before_id: String.t(),
          after_id: String.t(),
          limit: pos_integer(),
          scope_id: String.t()
        ) ::
          {:ok,
           %{
             data: list(file_metadata()),
             has_more: boolean(),
             first_id: String.t() | nil,
             last_id: String.t() | nil
           }}
          | {:error, Error.t()}
  def list(%Client{} = client, opts \\ []) do
    query = if opts == [], do: "", else: "?" <> URI.encode_query(opts)

    with {:ok, body} <- HTTPTransport.get(client, "/v1/files" <> query, [@beta_header]) do
      {:ok,
       %{
         data: Enum.map(body["data"] || [], &from_json/1),
         has_more: body["has_more"] || false,
         first_id: body["first_id"],
         last_id: body["last_id"]
       }}
    end
  end

  @doc """
  Like `list/2`, but returns a lazy `Stream` of individual files that transparently
  fetches subsequent pages as it's consumed, instead of one page at a time.
  """
  @spec list_all(Client.t(), keyword()) :: Enumerable.t()
  def list_all(%Client{} = client, opts \\ []) do
    Pagination.stream(opts, &list(client, &1))
  end

  @doc "Retrieves a file's metadata."
  @spec retrieve(Client.t(), file_id :: String.t()) ::
          {:ok, file_metadata()} | {:error, Error.t()}
  def retrieve(%Client{} = client, file_id) when is_binary(file_id) do
    with {:ok, body} <- HTTPTransport.get(client, "/v1/files/#{file_id}", [@beta_header]) do
      {:ok, from_json(body)}
    end
  end

  @doc "Downloads a file's raw content."
  @spec download(Client.t(), file_id :: String.t()) :: {:ok, binary()} | {:error, Error.t()}
  def download(%Client{} = client, file_id) when is_binary(file_id) do
    HTTPTransport.get_binary(client, "/v1/files/#{file_id}/content", [
      @beta_header,
      {"accept", "application/binary"}
    ])
  end

  @doc "Deletes a file."
  @spec delete(Client.t(), file_id :: String.t()) ::
          {:ok, %{id: String.t(), type: String.t()}} | {:error, Error.t()}
  def delete(%Client{} = client, file_id) when is_binary(file_id) do
    with {:ok, body} <- HTTPTransport.delete(client, "/v1/files/#{file_id}", [@beta_header]) do
      {:ok, %{id: body["id"], type: body["type"]}}
    end
  end

  defp from_json(body) do
    %{
      id: body["id"],
      type: body["type"],
      filename: body["filename"],
      mime_type: body["mime_type"],
      size_bytes: body["size_bytes"],
      created_at: body["created_at"],
      downloadable: body["downloadable"],
      scope: body["scope"]
    }
  end
end
