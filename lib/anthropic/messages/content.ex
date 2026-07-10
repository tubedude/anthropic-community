defmodule Anthropic.Messages.Content do
  @moduledoc """
  Dispatches between the typed content-block structs (`Text`, `ToolUse`, `ToolResult`,
  `Thinking`, `RedactedThinking`, `Image`, `Document`) and their wire JSON shape.

  Response and request content blocks share the same struct types: a `%Text{}` decoded
  from a response round-trips through `to_json/1` unchanged if replayed into a later
  request (e.g. in a tool-use loop), so there is no separate request-param/response-type
  split to maintain.

  Content-block types the API adds in the future (e.g. server-side tool blocks) decode as
  plain maps rather than raising, so callers on an older version of this library keep
  working — pattern-match on `%{"type" => ...}` alongside the typed structs to handle them.
  """

  alias Anthropic.Messages.Content.{
    Text,
    ToolUse,
    ToolResult,
    Thinking,
    RedactedThinking,
    Image,
    Document
  }

  @type t ::
          Text.t()
          | ToolUse.t()
          | ToolResult.t()
          | Thinking.t()
          | RedactedThinking.t()
          | Image.t()
          | Document.t()

  @spec from_json(map()) :: t() | map()
  def from_json(%{"type" => "text"} = b) do
    %Text{text: b["text"], citations: b["citations"], cache_control: b["cache_control"]}
  end

  def from_json(%{"type" => "tool_use"} = b) do
    %ToolUse{id: b["id"], name: b["name"], input: b["input"], cache_control: b["cache_control"]}
  end

  def from_json(%{"type" => "tool_result"} = b) do
    %ToolResult{
      tool_use_id: b["tool_use_id"],
      content: b["content"],
      is_error: b["is_error"] || false,
      cache_control: b["cache_control"]
    }
  end

  def from_json(%{"type" => "thinking"} = b) do
    %Thinking{thinking: b["thinking"], signature: b["signature"]}
  end

  def from_json(%{"type" => "redacted_thinking"} = b) do
    %RedactedThinking{data: b["data"]}
  end

  def from_json(raw) when is_map(raw), do: raw

  @doc "Encodes a content-block struct (or a plain map, passed through unchanged) back to its wire shape."
  @spec to_json(t() | map()) :: map()
  def to_json(%Text{text: text, citations: citations, cache_control: cache_control}) do
    %{type: "text", text: text, citations: citations, cache_control: cache_control} |> compact()
  end

  def to_json(%ToolUse{id: id, name: name, input: input, cache_control: cache_control}) do
    %{type: "tool_use", id: id, name: name, input: input, cache_control: cache_control}
    |> compact()
  end

  def to_json(%ToolResult{
        tool_use_id: id,
        content: content,
        is_error: is_error,
        cache_control: cache_control
      }) do
    %{
      type: "tool_result",
      tool_use_id: id,
      content: content,
      is_error: is_error,
      cache_control: cache_control
    }
    |> compact()
  end

  def to_json(%Thinking{thinking: thinking, signature: signature}) do
    %{type: "thinking", thinking: thinking, signature: signature}
  end

  def to_json(%RedactedThinking{data: data}) do
    %{type: "redacted_thinking", data: data}
  end

  def to_json(%Image{
        media_type: media_type,
        data: data,
        source_type: source_type,
        cache_control: cache_control
      }) do
    %{
      type: "image",
      source: %{type: source_type, media_type: media_type, data: data},
      cache_control: cache_control
    }
    |> compact()
  end

  def to_json(%Document{source_type: source_type} = doc) do
    %{
      type: "document",
      source: document_source(source_type, doc),
      cache_control: doc.cache_control,
      citations: doc.citations,
      context: doc.context,
      title: doc.title
    }
    |> compact()
  end

  def to_json(raw) when is_map(raw), do: raw

  defp document_source("base64", %Document{media_type: media_type, data: data}) do
    %{type: "base64", media_type: media_type, data: data}
  end

  defp document_source("url", %Document{url: url}), do: %{type: "url", url: url}

  defp document_source("text", %Document{media_type: media_type, data: data}) do
    %{type: "text", media_type: media_type, data: data}
  end

  defp document_source("content", %Document{content: content}),
    do: %{type: "content", content: content}

  defp compact(map), do: Map.reject(map, fn {_k, v} -> is_nil(v) end)
end
