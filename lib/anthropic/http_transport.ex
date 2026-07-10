defmodule Anthropic.HTTPTransport do
  @moduledoc """
  The single internal request-sending layer. `Anthropic.Messages.create/2` (via `post/3`),
  `Anthropic.Models`/`Anthropic.Batches` (via `get/2`, `post/3`, and `delete/2`), and
  `Anthropic.Messages.stream/2` (via `stream/3`) all funnel through this module, so
  header-building, retry/backoff, and error-mapping are defined exactly once and never
  diverge between request styles.
  """

  alias Anthropic.{Client, Error}
  alias Anthropic.HTTPTransport.Retry

  @spec post(Client.t(), path :: String.t(), params :: map()) ::
          {:ok, map()} | {:error, Error.t()}
  def post(%Client{} = client, path, params) do
    send_request(client, :post, client.base_url <> path, Jason.encode!(params), 0, decode: true)
  end

  @spec get(Client.t(), path :: String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(%Client{} = client, path) do
    send_request(client, :get, client.base_url <> path, nil, 0, decode: true)
  end

  @doc """
  Like `get/2`, but takes a full URL and returns the raw text body rather than JSON-decoding
  it — used to fetch batch results (`results_url`), which is JSONL, not a single JSON document.
  """
  @spec get_raw(Client.t(), url :: String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def get_raw(%Client{} = client, url) do
    send_request(client, :get, url, nil, 0, decode: false)
  end

  @spec delete(Client.t(), path :: String.t()) :: {:ok, map()} | {:error, Error.t()}
  def delete(%Client{} = client, path) do
    send_request(client, :delete, client.base_url <> path, nil, 0, decode: true)
  end

  defp send_request(client, method, url, body, attempt, decode: decode?) do
    req = build_request(client, method, url, body)

    case adapter().request(req, client.http_pool, receive_timeout: client.timeout) do
      {:ok, %Finch.Response{status: 200, body: response_body}} ->
        if decode?, do: decode_body(response_body), else: {:ok, response_body}

      {:ok, %Finch.Response{status: status, body: response_body, headers: headers}} ->
        error = Error.from_response(status, response_body, headers)
        maybe_retry(client, method, url, body, attempt, error, headers, decode: decode?)

      {:error, reason} ->
        error = Error.new(:connection_error, Exception.message(reason))
        maybe_retry(client, method, url, body, attempt, error, [], decode: decode?)
    end
  end

  defp decode_body(body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        {:ok, decoded}

      {:error, %Jason.DecodeError{} = reason} ->
        {:error, Error.new(:decode_error, Exception.message(reason))}
    end
  end

  defp maybe_retry(client, method, url, body, attempt, error, headers, decode: decode?) do
    if Retry.should_retry?(error, attempt, client.max_retries, headers) do
      Process.sleep(Retry.delay_ms(attempt, headers))
      send_request(client, method, url, body, attempt + 1, decode: decode?)
    else
      {:error, error}
    end
  end

  @doc false
  def build_request(%Client{} = client, method, url, body \\ nil) do
    headers =
      [
        {"x-api-key", client.api_key},
        {"anthropic-version", client.api_version},
        {"content-type", "application/json"}
      ] ++ client.default_headers

    Finch.build(method, url, headers, body)
  end

  @doc """
  Returns a lazy `Stream.t()` of `Anthropic.Messages.StreamEvent` structs for a
  `POST`-with-SSE-response request (currently only used by `Anthropic.Messages.stream/2`).

  The initial connection attempt goes through the same retry/backoff as `post/4` (a 429/5xx
  before any bytes arrive is retried); once streaming has started, a mid-stream failure is
  delivered as a final `%Anthropic.Messages.StreamEvent.Error{}` element instead of raising or
  silently retrying (which would require replaying partial content).
  """
  @spec stream(Client.t(), path :: String.t(), params :: map()) :: Enumerable.t()
  def stream(%Client{} = client, path, params) do
    Stream.resource(
      fn -> start_stream(client, client.base_url <> path, Jason.encode!(params), 0) end,
      &next_events/1,
      &close_stream/1
    )
  end

  defp start_stream(client, url, body, attempt) do
    req = build_request(client, :post, url, body)
    parent = self()
    ref = make_ref()

    # Task.start (unlinked) + an explicit monitor, not Task.start_link: linking would mean a
    # crash inside the task (as opposed to a clean {:error, _} return from the adapter) kills
    # this stream's consumer process outright — contradicting the documented contract that
    # transport failures are delivered as a terminal StreamEvent.Error, never raised.
    {:ok, task_pid} =
      Task.start(fn ->
        initial_acc = %{
          sse: Anthropic.HTTPTransport.SSE.new(),
          status: nil,
          headers: [],
          error_chunks: []
        }

        result =
          adapter().stream(req, client.http_pool, initial_acc, &handle_chunk(&1, &2, parent, ref),
            receive_timeout: client.timeout
          )

        send(parent, {ref, :finished, result})
      end)

    monitor_ref = Process.monitor(task_pid)

    %{
      ref: ref,
      task: task_pid,
      monitor_ref: monitor_ref,
      client: client,
      url: url,
      body: body,
      attempt: attempt,
      connected: false
    }
  end

  defp handle_chunk({:status, status}, acc, parent, ref) do
    if status == 200, do: send(parent, {ref, :connected})
    %{acc | status: status}
  end

  defp handle_chunk({:headers, headers}, acc, _parent, _ref), do: %{acc | headers: headers}

  defp handle_chunk({:data, chunk}, %{status: 200} = acc, parent, ref) do
    {frames, sse} = Anthropic.HTTPTransport.SSE.feed(acc.sse, chunk)

    Enum.each(frames, fn {event_name, data} ->
      send(parent, {ref, :event, Anthropic.Messages.StreamEvent.decode(event_name, data)})
    end)

    %{acc | sse: sse}
  end

  defp handle_chunk({:data, chunk}, acc, _parent, _ref),
    do: %{acc | error_chunks: [chunk | acc.error_chunks]}

  defp next_events(%{halted: true} = state), do: {:halt, state}

  defp next_events(%{ref: ref, monitor_ref: monitor_ref} = state) do
    receive do
      {^ref, :connected} ->
        next_events(%{state | connected: true})

      {^ref, :event, event} ->
        {[event], state}

      {^ref, :finished, {:ok, %{status: 200}}} ->
        {:halt, state}

      # No {:status, _} chunk was ever delivered (connection accepted then closed before a
      # response line arrived) — there's no HTTP status to build an Error.from_response/3
      # around, so this is a connection failure, not an API error response.
      {^ref, :finished, {:ok, %{status: nil}}} ->
        retry_or_emit_error(
          state,
          Error.new(:connection_error, "stream closed before any response"),
          []
        )

      {^ref, :finished, {:ok, %{status: status, headers: headers, error_chunks: chunks}}} ->
        body = chunks |> Enum.reverse() |> IO.iodata_to_binary()
        retry_or_emit_error(state, Error.from_response(status, body, headers), headers)

      {^ref, :finished, {:error, reason}} ->
        retry_or_emit_error(state, Error.new(:connection_error, Exception.message(reason)), [])

      # The task exits normally right after sending :finished, so a :normal DOWN is expected
      # and already handled via the :finished message above — ignore it. A non-normal reason
      # means the task crashed before it could report a result; surface that as a terminal
      # error instead of leaving the stream hanging (this is the failure mode Task.start_link
      # would otherwise propagate through the link and crash the consumer with).
      {:DOWN, ^monitor_ref, :process, _pid, :normal} ->
        next_events(state)

      {:DOWN, ^monitor_ref, :process, _pid, reason} ->
        retry_or_emit_error(
          state,
          Error.new(:connection_error, "stream process crashed: #{inspect(reason)}"),
          []
        )
    after
      state.client.timeout ->
        {[%Anthropic.Messages.StreamEvent.Error{error: Error.timeout()}],
         Map.put(state, :halted, true)}
    end
  end

  # A failure before the connection was confirmed (status 200) is safe to retry, exactly like
  # post/4 — no bytes were ever delivered to the caller. Once `connected: true`, retrying would
  # mean silently replaying/duplicating partial content, so any failure past that point is
  # always terminal, regardless of Error.retryable?/1 or remaining attempts.
  defp retry_or_emit_error(%{connected: true} = state, error, _headers) do
    {[%Anthropic.Messages.StreamEvent.Error{error: error}], Map.put(state, :halted, true)}
  end

  defp retry_or_emit_error(state, error, headers) do
    if Retry.should_retry?(error, state.attempt, state.client.max_retries, headers) do
      # Reap the just-finished (or still-lingering) task before spawning its replacement —
      # otherwise each retry orphans the previous attempt's task/monitor.
      close_stream(state)
      Process.sleep(Retry.delay_ms(state.attempt, headers))
      {[], start_stream(state.client, state.url, state.body, state.attempt + 1)}
    else
      {[%Anthropic.Messages.StreamEvent.Error{error: error}], Map.put(state, :halted, true)}
    end
  end

  defp close_stream(%{task: task_pid, monitor_ref: monitor_ref}) do
    Process.demonitor(monitor_ref, [:flush])
    if Process.alive?(task_pid), do: Process.exit(task_pid, :kill)
  end

  defp adapter, do: Application.get_env(:anthropic, :http_adapter, Finch)
end
