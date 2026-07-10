defmodule Anthropic.Messages.ContentTest do
  use ExUnit.Case, async: true

  alias Anthropic.Messages.Content
  alias Anthropic.Messages.Content.{Text, ToolUse, ToolResult, Thinking, RedactedThinking}
  alias Anthropic.Messages.Content.Citation.CharLocation

  alias Anthropic.Messages.Content.{
    ServerToolUse,
    WebSearchToolResult,
    WebFetchToolResult,
    CodeExecutionToolResult,
    BashCodeExecutionToolResult,
    TextEditorCodeExecutionToolResult
  }

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
      raw = %{"type" => "computer_tool_use", "id" => "x"}
      assert Content.from_json(raw) == raw
    end

    test "decodes a server_tool_use block" do
      assert %ServerToolUse{id: "srvtoolu_1", name: "web_search", input: %{"query" => "elixir"}} =
               Content.from_json(%{
                 "type" => "server_tool_use",
                 "id" => "srvtoolu_1",
                 "name" => "web_search",
                 "input" => %{"query" => "elixir"}
               })
    end

    test "decodes a web_search_tool_result block" do
      assert %WebSearchToolResult{
               tool_use_id: "srvtoolu_1",
               content: [%{"type" => "web_search_result"}]
             } =
               Content.from_json(%{
                 "type" => "web_search_tool_result",
                 "tool_use_id" => "srvtoolu_1",
                 "content" => [%{"type" => "web_search_result"}]
               })
    end

    test "decodes a web_fetch_tool_result block" do
      assert %WebFetchToolResult{
               tool_use_id: "srvtoolu_1",
               content: %{"type" => "web_fetch_result"}
             } =
               Content.from_json(%{
                 "type" => "web_fetch_tool_result",
                 "tool_use_id" => "srvtoolu_1",
                 "content" => %{"type" => "web_fetch_result"}
               })
    end

    test "decodes a code_execution_tool_result block" do
      assert %CodeExecutionToolResult{tool_use_id: "srvtoolu_1", content: %{"stdout" => "42"}} =
               Content.from_json(%{
                 "type" => "code_execution_tool_result",
                 "tool_use_id" => "srvtoolu_1",
                 "content" => %{"stdout" => "42"}
               })
    end

    test "decodes a bash_code_execution_tool_result block" do
      assert %BashCodeExecutionToolResult{tool_use_id: "srvtoolu_1", content: %{"stdout" => "ok"}} =
               Content.from_json(%{
                 "type" => "bash_code_execution_tool_result",
                 "tool_use_id" => "srvtoolu_1",
                 "content" => %{"stdout" => "ok"}
               })
    end

    test "decodes a text_editor_code_execution_tool_result block" do
      assert %TextEditorCodeExecutionToolResult{
               tool_use_id: "srvtoolu_1",
               content: %{"file_text" => "..."}
             } =
               Content.from_json(%{
                 "type" => "text_editor_code_execution_tool_result",
                 "tool_use_id" => "srvtoolu_1",
                 "content" => %{"file_text" => "..."}
               })
    end

    test "decodes cache_control when present" do
      assert %Text{cache_control: %{"type" => "ephemeral"}} =
               Content.from_json(%{
                 "type" => "text",
                 "text" => "hi",
                 "cache_control" => %{"type" => "ephemeral"}
               })
    end

    test "decodes a text block's citations into typed citation structs" do
      assert %Text{
               citations: [
                 %CharLocation{
                   cited_text: "quoted",
                   document_index: 0,
                   start_char_index: 0,
                   end_char_index: 6
                 }
               ]
             } =
               Content.from_json(%{
                 "type" => "text",
                 "text" => "hi",
                 "citations" => [
                   %{
                     "type" => "char_location",
                     "cited_text" => "quoted",
                     "document_index" => 0,
                     "start_char_index" => 0,
                     "end_char_index" => 6
                   }
                 ]
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
      raw = %{"type" => "computer_tool_use"}
      assert Content.to_json(raw) == raw
    end

    test "server_tool_use" do
      block = %ServerToolUse{id: "srvtoolu_1", name: "web_search", input: %{"query" => "elixir"}}

      assert Content.to_json(block) == %{
               type: "server_tool_use",
               id: "srvtoolu_1",
               name: "web_search",
               input: %{"query" => "elixir"}
             }
    end

    test "web_search_tool_result" do
      block = %WebSearchToolResult{
        tool_use_id: "srvtoolu_1",
        content: [%{"type" => "web_search_result"}]
      }

      assert Content.to_json(block) == %{
               type: "web_search_tool_result",
               tool_use_id: "srvtoolu_1",
               content: [%{"type" => "web_search_result"}]
             }
    end

    test "code_execution_tool_result" do
      block = %CodeExecutionToolResult{tool_use_id: "srvtoolu_1", content: %{"stdout" => "42"}}

      assert Content.to_json(block) == %{
               type: "code_execution_tool_result",
               tool_use_id: "srvtoolu_1",
               content: %{"stdout" => "42"}
             }
    end

    test "re-encodes a text block's typed citations back to wire maps" do
      block = %Text{
        text: "hi",
        citations: [
          %CharLocation{
            cited_text: "quoted",
            document_index: 0,
            document_title: nil,
            end_char_index: 6,
            file_id: nil,
            start_char_index: 0
          }
        ]
      }

      assert Content.to_json(block) == %{
               type: "text",
               text: "hi",
               citations: [
                 %{
                   type: "char_location",
                   cited_text: "quoted",
                   document_index: 0,
                   end_char_index: 6,
                   start_char_index: 0
                 }
               ]
             }
    end
  end
end
