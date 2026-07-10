defmodule Anthropic.Messages.StreamEvent do
  @moduledoc """
  Decodes a raw SSE frame (`{event_name, data}`, as produced by `Anthropic.HTTPTransport.SSE`)
  into a typed event struct. See `Anthropic.Messages.StreamAccumulator` for folding a stream
  of these into a final `Anthropic.Messages.Message`.
  """

  alias Anthropic.Messages.StreamEvent, as: SE
  alias Anthropic.Messages.{Content, Message}

  @type t ::
          SE.MessageStart.t()
          | SE.ContentBlockStart.t()
          | SE.ContentBlockDelta.t()
          | SE.ContentBlockStop.t()
          | SE.MessageDelta.t()
          | SE.MessageStop.t()
          | SE.Ping.t()
          | SE.Error.t()

  @doc "Decodes one raw SSE frame's `data` field into a typed event. `event_name` is accepted for parity with the SSE frame shape but the wire `\"type\"` field inside `data` is authoritative."
  @spec decode(event_name :: String.t() | nil, data :: String.t()) :: t()
  def decode(_event_name, data) do
    case Jason.decode(data) do
      {:ok, %{"type" => "message_start", "message" => msg}} ->
        %SE.MessageStart{message: Message.from_json(msg)}

      {:ok, %{"type" => "content_block_start", "index" => index, "content_block" => block}} ->
        %SE.ContentBlockStart{index: index, content_block: Content.from_json(block)}

      {:ok, %{"type" => "content_block_delta", "index" => index, "delta" => delta}} ->
        %SE.ContentBlockDelta{index: index, delta: delta}

      {:ok, %{"type" => "content_block_stop", "index" => index}} ->
        %SE.ContentBlockStop{index: index}

      {:ok, %{"type" => "message_delta", "delta" => delta} = event} ->
        %SE.MessageDelta{delta: delta, usage: event["usage"] || %{}}

      {:ok, %{"type" => "message_stop"}} ->
        %SE.MessageStop{}

      {:ok, %{"type" => "ping"}} ->
        %SE.Ping{}

      {:ok, %{"type" => "error", "error" => error}} ->
        %SE.Error{error: Anthropic.Error.from_wire_error(error)}

      {:ok, other} ->
        %SE.Error{
          error: Anthropic.Error.new(:decode_error, "unrecognized SSE event: #{inspect(other)}")
        }

      {:error, %Jason.DecodeError{} = reason} ->
        %SE.Error{
          error:
            Anthropic.Error.new(
              :decode_error,
              "could not decode SSE frame: #{Exception.message(reason)}"
            )
        }
    end
  end
end
