defmodule Anthropic.HTTPTransport.SSE do
  @moduledoc """
  Minimal line-buffering Server-Sent-Events parser. Consumes raw byte chunks (as delivered
  by `Finch.stream/5`'s `:data` callback) and emits complete `{event_name, data}` frames,
  buffering partial lines and partial frames across chunk boundaries.
  """

  defstruct buffer: "", pending_event: nil, pending_data: []

  @type frame :: {event :: String.t() | nil, data :: String.t()}
  @type t :: %__MODULE__{
          buffer: String.t(),
          pending_event: String.t() | nil,
          pending_data: list(String.t())
        }

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Feeds a raw byte chunk in; returns the complete frames it produced and the updated parser state."
  @spec feed(t(), binary()) :: {list(frame()), t()}
  def feed(%__MODULE__{} = parser, chunk) when is_binary(chunk) do
    lines = String.split(parser.buffer <> chunk, "\n", trim: false)
    {complete_lines, [incomplete]} = Enum.split(lines, -1)

    process_lines(complete_lines, %{parser | buffer: incomplete})
  end

  defp process_lines(lines, parser) do
    Enum.reduce(lines, {[], parser}, fn line, {frames, parser} ->
      # The SSE spec allows CRLF line endings; strip a trailing \r left over from splitting
      # on "\n" alone so a "\r"-terminated field name/value doesn't leak into pending_event
      # or pending_data.
      case parse_line(String.trim_trailing(line, "\r"), parser) do
        {:frame, frame, parser} -> {frames ++ [frame], parser}
        {:continue, parser} -> {frames, parser}
      end
    end)
  end

  defp parse_line("", %{pending_data: []} = parser), do: {:continue, parser}

  defp parse_line("", parser) do
    data = parser.pending_data |> Enum.reverse() |> Enum.join("\n")
    {:frame, {parser.pending_event, data}, %{parser | pending_event: nil, pending_data: []}}
  end

  defp parse_line("event: " <> name, parser), do: {:continue, %{parser | pending_event: name}}

  defp parse_line("data: " <> data, parser),
    do: {:continue, %{parser | pending_data: [data | parser.pending_data]}}

  defp parse_line("data:" <> data, parser),
    do: {:continue, %{parser | pending_data: [String.trim_leading(data) | parser.pending_data]}}

  defp parse_line(":" <> _comment, parser), do: {:continue, parser}
  defp parse_line(_other, parser), do: {:continue, parser}
end
