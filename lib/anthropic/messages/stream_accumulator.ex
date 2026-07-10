defmodule Anthropic.Messages.StreamAccumulator do
  @moduledoc """
  Folds a stream of `Anthropic.Messages.StreamEvent` structs (as produced by
  `Anthropic.Messages.stream/2`) into a final `Anthropic.Messages.Message` — the streaming
  equivalent of `Anthropic.Messages.create/2`'s return value.
  """

  alias Anthropic.Messages.{Message, Content}
  alias Anthropic.Messages.StreamEvent, as: SE

  @spec accumulate(Enumerable.t()) :: {:ok, Message.t()} | {:error, Anthropic.Error.t()}
  def accumulate(event_stream) do
    event_stream
    |> Enum.reduce_while({%Message{content: []}, %{}}, &fold/2)
    |> case do
      {:error, _reason} = error -> error
      {%Message{} = message, blocks} -> {:ok, %{message | content: finalize_blocks(blocks)}}
    end
  end

  defp fold(%SE.MessageStart{message: partial}, {_msg, _blocks}), do: {:cont, {partial, %{}}}

  defp fold(%SE.ContentBlockStart{index: index, content_block: block}, {msg, blocks}) do
    entry = %{block: block, raw_json: if(match?(%Content.ToolUse{}, block), do: "", else: nil)}
    {:cont, {msg, Map.put(blocks, index, entry)}}
  end

  defp fold(%SE.ContentBlockDelta{index: index, delta: delta}, {msg, blocks}) do
    {:cont, {msg, Map.update!(blocks, index, &apply_delta(&1, delta))}}
  end

  defp fold(%SE.ContentBlockStop{}, acc), do: {:cont, acc}

  defp fold(%SE.MessageDelta{delta: delta, usage: usage}, {msg, blocks}) do
    updated = %{
      msg
      | stop_reason: delta["stop_reason"] || msg.stop_reason,
        stop_sequence: delta["stop_sequence"] || msg.stop_sequence,
        usage: Map.merge(msg.usage || %{}, usage || %{})
    }

    {:cont, {updated, blocks}}
  end

  defp fold(%SE.MessageStop{}, acc), do: {:cont, acc}
  defp fold(%SE.Ping{}, acc), do: {:cont, acc}
  defp fold(%SE.Error{error: error}, _acc), do: {:halt, {:error, error}}

  defp apply_delta(%{block: %Content.Text{text: text} = block} = entry, %{
         "type" => "text_delta",
         "text" => piece
       }) do
    %{entry | block: %{block | text: text <> piece}}
  end

  defp apply_delta(%{raw_json: raw_json} = entry, %{
         "type" => "input_json_delta",
         "partial_json" => piece
       })
       when is_binary(raw_json) do
    %{entry | raw_json: raw_json <> piece}
  end

  defp apply_delta(%{block: %Content.Thinking{thinking: thinking} = block} = entry, %{
         "type" => "thinking_delta",
         "thinking" => piece
       }) do
    %{entry | block: %{block | thinking: thinking <> piece}}
  end

  defp apply_delta(%{block: %Content.Thinking{} = block} = entry, %{
         "type" => "signature_delta",
         "signature" => signature
       }) do
    %{entry | block: %{block | signature: signature}}
  end

  defp apply_delta(entry, _delta), do: entry

  defp finalize_blocks(blocks) do
    blocks
    |> Enum.sort_by(fn {index, _entry} -> index end)
    |> Enum.map(fn {_index, entry} -> finalize_block(entry) end)
  end

  defp finalize_block(%{block: %Content.ToolUse{} = block, raw_json: raw_json})
       when is_binary(raw_json) do
    input =
      case Jason.decode(raw_json) do
        {:ok, decoded} -> decoded
        {:error, _reason} -> %{}
      end

    %{block | input: input}
  end

  defp finalize_block(%{block: block}), do: block
end
