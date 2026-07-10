defmodule Anthropic.Messages do
  @moduledoc """
  The `Messages` resource: `create/2` for a single request/response turn, `stream/2` for a
  server-sent-events stream of the same. See `Anthropic.ToolRunner` for driving a full
  tool-use agentic loop on top of `create/2`.
  """

  alias Anthropic.{Client, Error}
  alias Anthropic.Messages.{Message, Request}

  @type create_opts :: [
          model: String.t(),
          max_tokens: pos_integer(),
          messages: list(map()),
          system: String.t() | list(map()) | nil,
          tools: list(module() | map()) | nil,
          tool_choice: map() | nil,
          temperature: float() | nil,
          top_p: float() | nil,
          top_k: pos_integer() | nil,
          stop_sequences: list(String.t()) | nil,
          metadata: map() | nil
        ]

  @doc """
  Sends a single request to the Anthropic Messages API and returns the assistant's reply.

  ## Examples

      client = Anthropic.Client.new(api_key: System.fetch_env!("ANTHROPIC_API_KEY"))

      {:ok, message} =
        Anthropic.Messages.create(client,
          model: "claude-opus-4-8",
          max_tokens: 1024,
          messages: [%{role: "user", content: "Hello, Claude"}]
        )
  """
  @spec create(Client.t(), create_opts()) :: {:ok, Message.t()} | {:error, Error.t()}
  def create(%Client{} = client, opts) do
    :telemetry.span([:anthropic, :messages, :create], %{}, fn ->
      case do_create(client, opts) do
        {:ok, %Message{} = message} = result ->
          {result,
           %{model: message.model, stop_reason: message.stop_reason, usage: message.usage}}

        {:error, %Error{} = error} = result ->
          {result, %{error: error.type}}
      end
    end)
  end

  defp do_create(client, opts) do
    with {:ok, params} <- Request.build(client, opts, stream: false),
         {:ok, body} <- Anthropic.HTTPTransport.post(client, "/v1/messages", params) do
      {:ok, Message.from_json(body)}
    end
  end

  @doc "Like `create/2`, but returns the message directly and raises `Anthropic.Error` on failure."
  @spec create!(Client.t(), create_opts()) :: Message.t()
  def create!(client, opts) do
    case create(client, opts) do
      {:ok, message} -> message
      {:error, error} -> raise error
    end
  end

  @doc """
  Returns a lazy `Stream.t()` of `Anthropic.Messages.StreamEvent.t()` structs.

  Request-setup errors (invalid params) raise immediately, before any stream is returned.
  Errors that occur once the connection is open (rate limits, connection drops, decode
  failures) are delivered as a final `%Anthropic.Messages.StreamEvent.Error{}` element rather
  than raising mid-`Stream`, so callers can pattern-match on it without wrapping every
  iteration in `try`/`rescue`.

  ## Examples

      client
      |> Anthropic.Messages.stream(model: "claude-opus-4-8", max_tokens: 1024,
           messages: [%{role: "user", content: "Write a haiku about Elixir"}])
      |> Stream.each(fn
        %Anthropic.Messages.StreamEvent.ContentBlockDelta{delta: %{"type" => "text_delta", "text" => text}} ->
          IO.write(text)

        _other ->
          :ok
      end)
      |> Stream.run()
  """
  @spec stream(Client.t(), create_opts()) :: Enumerable.t()
  def stream(%Client{} = client, opts) do
    case Request.build(client, opts, stream: true) do
      {:ok, params} -> Anthropic.HTTPTransport.stream(client, "/v1/messages", params)
      {:error, error} -> raise error
    end
  end

  @doc """
  Consumes the result of `stream/2` and folds it into a final `Message.t()` — analogous to
  the official SDKs' `get_final_message()`.

  ## Examples

      {:ok, message} =
        client
        |> Anthropic.Messages.stream(model: "claude-opus-4-8", max_tokens: 1024,
             messages: [%{role: "user", content: "Write a haiku about Elixir"}])
        |> Anthropic.Messages.stream_to_message()
  """
  @spec stream_to_message(Enumerable.t()) :: {:ok, Message.t()} | {:error, Error.t()}
  def stream_to_message(event_stream) do
    Anthropic.Messages.StreamAccumulator.accumulate(event_stream)
  end

  @type count_tokens_opts :: [
          model: String.t(),
          messages: list(map()),
          system: String.t() | list(map()) | nil,
          tools: list(module() | map()) | nil,
          tool_choice: map() | nil
        ]

  @doc """
  Counts the input tokens a request would use, without sending it for completion. Accepts
  the same `:model`/`:messages`/`:system`/`:tools`/`:tool_choice` options as `create/2`
  (minus `:max_tokens`, which this endpoint doesn't accept).

  ## Examples

      {:ok, %{input_tokens: 15}} =
        Anthropic.Messages.count_tokens(client,
          model: "claude-opus-4-8",
          messages: [%{role: "user", content: "Hello, Claude"}]
        )
  """
  @spec count_tokens(Client.t(), count_tokens_opts()) ::
          {:ok, %{input_tokens: non_neg_integer()}} | {:error, Error.t()}
  def count_tokens(%Client{} = client, opts) do
    with {:ok, params} <- Request.build_count_tokens(client, opts),
         {:ok, body} <- Anthropic.HTTPTransport.post(client, "/v1/messages/count_tokens", params) do
      {:ok, %{input_tokens: body["input_tokens"]}}
    end
  end
end
