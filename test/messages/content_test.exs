defmodule Anthropic.Messages.ContentTest do
  use ExUnit.Case, async: true

  alias Anthropic.Messages.Content
  alias Anthropic.Messages.Content.{Text, ToolUse, ToolResult, Thinking, RedactedThinking}

  describe "from_json/1" do
    test "decodes a text block" do
      assert %Text{text: "hi", citations: nil} =
               Content.from_json(%{"type" => "text", "text" => "hi"})
    end

    test "decodes a tool_use block" do
      assert %ToolUse{id: "toolu_1", name: "get_weather", input: %{"location" => "Paris"}} =
               Content.from_json(%{
                 "type" => "tool_use",
                 "id" => "toolu_1",
                 "name" => "get_weather",
                 "input" => %{"location" => "Paris"}
               })
    end

    test "decodes a tool_result block" do
      assert %ToolResult{tool_use_id: "toolu_1", content: "72F", is_error: false} =
               Content.from_json(%{
                 "type" => "tool_result",
                 "tool_use_id" => "toolu_1",
                 "content" => "72F"
               })
    end

    test "decodes a thinking block" do
      assert %Thinking{thinking: "reasoning...", signature: "sig"} =
               Content.from_json(%{
                 "type" => "thinking",
                 "thinking" => "reasoning...",
                 "signature" => "sig"
               })
    end

    test "decodes a redacted_thinking block" do
      assert %RedactedThinking{data: "opaque"} =
               Content.from_json(%{"type" => "redacted_thinking", "data" => "opaque"})
    end

    test "passes unknown block types through as a raw map" do
      raw = %{"type" => "server_tool_use", "id" => "x"}
      assert Content.from_json(raw) == raw
    end

    test "decodes cache_control when present" do
      assert %Text{cache_control: %{"type" => "ephemeral"}} =
               Content.from_json(%{
                 "type" => "text",
                 "text" => "hi",
                 "cache_control" => %{"type" => "ephemeral"}
               })
    end
  end

  describe "to_json/1 round-trip" do
    test "text" do
      block = %Text{text: "hi"}
      assert %{type: "text", text: "hi"} = Content.to_json(block)
    end

    test "tool_use" do
      block = %ToolUse{id: "toolu_1", name: "get_weather", input: %{"location" => "Paris"}}

      assert Content.to_json(block) == %{
               type: "tool_use",
               id: "toolu_1",
               name: "get_weather",
               input: %{"location" => "Paris"}
             }
    end

    test "tool_result" do
      block = %ToolResult{tool_use_id: "toolu_1", content: "72F", is_error: false}

      assert Content.to_json(block) == %{
               type: "tool_result",
               tool_use_id: "toolu_1",
               content: "72F",
               is_error: false
             }
    end

    test "unknown map passes through unchanged" do
      raw = %{"type" => "server_tool_use"}
      assert Content.to_json(raw) == raw
    end
  end
end
