defmodule Anthropic.Messages.Content.Document do
  @moduledoc """
  A PDF or plain-text document content block, usable anywhere a message can include content
  — vision-capable models can read PDFs directly. Supports four source variants:

  - `:base64` — inline PDF bytes, built via `process_document/3`.
  - `:url` — a hosted PDF, built via `from_url/2`.
  - `:text` — inline plain text, built via `from_text/2`.
  - `:content` — a pre-formatted string or list of content blocks (for citing structured
    content rather than a raw document), built via `from_content/2`.

  ## Examples

      {:ok, doc} = Anthropic.Messages.Content.Document.process_document("/path/to/report.pdf", :path)

      Anthropic.Messages.create(client,
        model: "claude-opus-4-8",
        max_tokens: 1024,
        messages: [
          %{role: "user", content: [doc, %{type: "text", text: "Summarize this document."}]}
        ]
      )
  """

  defstruct [
    :source_type,
    :data,
    :media_type,
    :url,
    :content,
    :cache_control,
    :citations,
    :context,
    :title
  ]

  @type source_type :: String.t()
  @type t :: %__MODULE__{
          source_type: source_type(),
          data: String.t() | nil,
          media_type: String.t() | nil,
          url: String.t() | nil,
          content: String.t() | list(map()) | nil,
          cache_control: map() | nil,
          citations: map() | nil,
          context: String.t() | nil,
          title: String.t() | nil
        }

  @type input_type :: :binary | :path | :base64
  @type build_opts :: [
          title: String.t(),
          context: String.t(),
          citations: map(),
          cache_control: map()
        ]
  @type process_output :: {:ok, t()} | {:error, String.t()}

  @doc """
  Processes a local PDF (binary data, a file path, or an already-base64-encoded string) into
  a base64 document content block.

  ## Options

  * `:title` — optional document title shown to the model.
  * `:context` — optional context text shown to the model alongside the document.
  * `:citations` — optional citations config map, e.g. `%{enabled: true}`.
  * `:cache_control` — optional `Anthropic.CacheControl` map.
  """
  @spec process_document(binary() | String.t(), input_type(), build_opts()) :: process_output()
  def process_document(input, input_type, opts \\ []) do
    case read_input({input_type, input}) do
      {:ok, binary} ->
        {:ok,
         %__MODULE__{
           source_type: "base64",
           media_type: "application/pdf",
           data: :base64.encode(binary)
         }
         |> apply_opts(opts)}

      {:error, {:file_error, reason, path}} ->
        {:error, "Error reading file #{reason} path: #{path}"}

      {:error, :invalid_base64} ->
        {:error, "Invalid base64 data provided for the document."}
    end
  end

  @doc "Builds a document content block referencing a hosted PDF URL."
  @spec from_url(String.t(), build_opts()) :: t()
  def from_url(url, opts \\ []) when is_binary(url) do
    %__MODULE__{source_type: "url", url: url} |> apply_opts(opts)
  end

  @doc "Builds a plain-text document content block from inline text."
  @spec from_text(String.t(), build_opts()) :: t()
  def from_text(text, opts \\ []) when is_binary(text) do
    %__MODULE__{source_type: "text", media_type: "text/plain", data: text} |> apply_opts(opts)
  end

  @doc """
  Builds a document content block from pre-formatted content — a string or a list of
  content-block maps — rather than a raw document. Useful for citing structured content that
  didn't come from an actual PDF/text file.
  """
  @spec from_content(String.t() | list(map()), build_opts()) :: t()
  def from_content(content, opts \\ []) when is_binary(content) or is_list(content) do
    %__MODULE__{source_type: "content", content: content} |> apply_opts(opts)
  end

  defp read_input({:binary, binary}), do: {:ok, binary}

  defp read_input({:path, path}) do
    case File.read(path) do
      {:ok, binary} -> {:ok, binary}
      {:error, reason} -> {:error, {:file_error, reason, path}}
    end
  end

  defp read_input({:base64, base64}) do
    case Base.decode64(base64, ignore: :whitespace) do
      {:ok, binary} -> {:ok, binary}
      :error -> {:error, :invalid_base64}
    end
  end

  defp apply_opts(document, opts) do
    %{
      document
      | title: opts[:title],
        context: opts[:context],
        citations: opts[:citations],
        cache_control: opts[:cache_control]
    }
  end
end
