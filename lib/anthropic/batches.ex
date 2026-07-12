defmodule Anthropic.Batches do
  @moduledoc """
  The `Batches` resource (Message Batches API): submit up to 100k `Messages.create/2`-shaped
  requests for asynchronous, discounted bulk processing.

  ## Example

      {:ok, batch} =
        Anthropic.Batches.create(client, [
          %{custom_id: "request-1", params: [model: "claude-opus-4-8", max_tokens: 100, messages: [%{role: "user", content: "Hi"}]]},
          %{custom_id: "request-2", params: [model: "claude-opus-4-8", max_tokens: 100, messages: [%{role: "user", content: "Hello"}]]}
        ])

      {:ok, batch} = Anthropic.Batches.retrieve(client, batch.id)

      if batch.processing_status == "ended" do
        {:ok, results} = Anthropic.Batches.results(client, batch)
      end
  """

  alias Anthropic.{Client, Error}
  alias Anthropic.Messages.{Message, Request}

  @type batch_request :: %{
          required(:custom_id) => String.t(),
          required(:params) => Anthropic.Messages.create_opts()
        }
  @type batch :: %{
          id: String.t(),
          type: String.t(),
          processing_status: String.t(),
          request_counts: map(),
          results_url: String.t() | nil,
          created_at: String.t() | nil,
          ended_at: String.t() | nil,
          expires_at: String.t() | nil
        }
  @type result :: %{
          custom_id: String.t(),
          type: String.t(),
          message: Message.t() | nil,
          error: Error.t() | nil
        }
  @type deleted_batch :: %{id: String.t(), type: String.t()}

  @doc "Creates a message batch from a list of `%{custom_id:, params:}` requests."
  @spec create(Client.t(), list(batch_request())) :: {:ok, batch()} | {:error, Error.t()}
  def create(%Client{} = client, requests) when is_list(requests) do
    with {:ok, wire_requests} <- build_requests(client, requests),
         {:ok, body} <-
           Anthropic.HTTPTransport.post(client, "/v1/messages/batches", %{requests: wire_requests}) do
      {:ok, from_json(body)}
    end
  end

  @doc "Retrieves a batch by id."
  @spec retrieve(Client.t(), batch_id :: String.t()) :: {:ok, batch()} | {:error, Error.t()}
  def retrieve(%Client{} = client, batch_id) when is_binary(batch_id) do
    with {:ok, body} <-
           Anthropic.HTTPTransport.get(client, "/v1/messages/batches/#{URI.encode(batch_id)}") do
      {:ok, from_json(body)}
    end
  end

  @type list_result :: %{
          data: list(batch()),
          has_more: boolean(),
          first_id: String.t() | nil,
          last_id: String.t() | nil
        }

  @doc "Lists batches, most recently created first."
  @spec list(Client.t(), before_id: String.t(), after_id: String.t(), limit: pos_integer()) ::
          {:ok, list_result()} | {:error, Error.t()}
  def list(%Client{} = client, opts \\ []) do
    query = if opts == [], do: "", else: "?" <> URI.encode_query(opts)

    with {:ok, body} <- Anthropic.HTTPTransport.get(client, "/v1/messages/batches" <> query) do
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
  Like `list/2`, but returns a lazy `Stream` of individual batches that transparently
  fetches subsequent pages as it's consumed, instead of one page at a time.
  """
  @spec list_all(Client.t(), before_id: String.t(), after_id: String.t(), limit: pos_integer()) ::
          Enumerable.t()
  def list_all(%Client{} = client, opts \\ []) do
    Anthropic.Pagination.stream(opts, &list(client, &1))
  end

  @doc "Cancels a batch that is still processing."
  @spec cancel(Client.t(), batch_id :: String.t()) :: {:ok, batch()} | {:error, Error.t()}
  def cancel(%Client{} = client, batch_id) when is_binary(batch_id) do
    with {:ok, body} <-
           Anthropic.HTTPTransport.post(
             client,
             "/v1/messages/batches/#{URI.encode(batch_id)}/cancel",
             %{}
           ) do
      {:ok, from_json(body)}
    end
  end

  @doc """
  Deletes a batch's tracking data. The batch must first be in an ended state (cannot delete
  an in-progress batch).
  """
  @spec delete(Client.t(), batch_id :: String.t()) :: {:ok, deleted_batch()} | {:error, Error.t()}
  def delete(%Client{} = client, batch_id) when is_binary(batch_id) do
    with {:ok, body} <-
           Anthropic.HTTPTransport.delete(client, "/v1/messages/batches/#{URI.encode(batch_id)}") do
      {:ok, %{id: body["id"], type: body["type"]}}
    end
  end

  @doc """
  Fetches and parses the JSONL results of an ended batch, matched by `custom_id`. Accepts
  either a batch id or a `batch()` map already carrying `results_url` (avoids an extra
  `retrieve/2` round-trip).
  """
  @spec results(Client.t(), batch() | String.t()) :: {:ok, list(result())} | {:error, Error.t()}
  def results(%Client{} = client, %{results_url: url}) when is_binary(url) do
    fetch_results(client, url)
  end

  def results(%Client{}, %{results_url: nil}) do
    {:error, Error.new(:invalid_request_error, "batch has no results yet (not ended)")}
  end

  def results(%Client{} = client, batch_id) when is_binary(batch_id) do
    with {:ok, %{results_url: url}} when is_binary(url) <- retrieve(client, batch_id) do
      fetch_results(client, url)
    else
      {:ok, %{results_url: nil}} ->
        {:error, Error.new(:invalid_request_error, "batch has no results yet (not ended)")}

      {:error, _reason} = error ->
        error
    end
  end

  defp fetch_results(client, url) do
    with :ok <- verify_same_host(client, url),
         {:ok, jsonl} <- Anthropic.HTTPTransport.get_raw(client, url) do
      results =
        jsonl
        |> String.split("\n", trim: true)
        |> Enum.map(&Jason.decode!/1)
        |> Enum.map(&parse_result/1)

      {:ok, results}
    end
  end

  # `results_url` comes from the API's own JSON response, but `get_raw/2` sends the client's
  # api_key to whatever URL it's given — refuse to follow it off the configured API host,
  # so a tampered/malicious response body can't exfiltrate the credential to an attacker host.
  defp verify_same_host(%Client{base_url: base_url}, url) do
    if URI.parse(url).host == URI.parse(base_url).host do
      :ok
    else
      {:error,
       Error.new(:invalid_request_error, "results_url host does not match client base_url")}
    end
  end

  defp parse_result(%{
         "custom_id" => custom_id,
         "result" => %{"type" => "succeeded", "message" => message}
       }) do
    %{custom_id: custom_id, type: "succeeded", message: Message.from_json(message), error: nil}
  end

  defp parse_result(%{
         "custom_id" => custom_id,
         "result" => %{"type" => "errored", "error" => error}
       }) do
    %{custom_id: custom_id, type: "errored", message: nil, error: Error.from_wire_error(error)}
  end

  defp parse_result(%{"custom_id" => custom_id, "result" => %{"type" => type}}) do
    %{custom_id: custom_id, type: type, message: nil, error: nil}
  end

  defp build_requests(client, requests) do
    Enum.reduce_while(requests, {:ok, []}, fn %{custom_id: custom_id, params: params},
                                              {:ok, acc} ->
      case Request.build(client, params, stream: false) do
        {:ok, built} ->
          {:cont, {:ok, [%{custom_id: custom_id, params: Map.delete(built, :stream)} | acc]}}

        {:error, _reason} = error ->
          {:halt, error}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      {:error, _reason} = error -> error
    end
  end

  defp from_json(body) do
    %{
      id: body["id"],
      type: body["type"],
      processing_status: body["processing_status"],
      request_counts: body["request_counts"] || %{},
      results_url: body["results_url"],
      created_at: body["created_at"],
      ended_at: body["ended_at"],
      expires_at: body["expires_at"]
    }
  end
end
