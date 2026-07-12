defmodule Anthropic.Messages.MessageTest do
  use ExUnit.Case, async: true

  alias Anthropic.Messages.Message
  alias Anthropic.Messages.Content.{Text, ToolUse}

  @raw_body %{
    "id" => "msg_013Zva2CMHLNnXjNJJKqJ2EF",
    "type" => "message",
    "role" => "assistant",
    "content" => [%{"type" => "text", "text" => "Hello!"}],
    "model" => "claude-opus-4-8",
    "stop_reason" => "end_turn",
    "stop_sequence" => nil,
    "usage" => %{"input_tokens" => 10, "output_tokens" => 5}
  }

  describe "from_json/1" do
    test "builds a Message struct with typed content" do
      message = Message.from_json(@raw_body)

      assert %Message{
               id: "msg_013Zva2CMHLNnXjNJJKqJ2EF",
               role: "assistant",
               model: "claude-opus-4-8",
               stop_reason: "end_turn",
               content: [%Text{text: "Hello!"}],
               usage: %{"input_tokens" => 10, "output_tokens" => 5}
             } = message
    end

    test "defaults content to [] and usage to %{} when absent" do
      assert %Message{content: [], usage: %{}} = Message.from_json(%{"id" => "msg_1"})
    end
  end

  describe "to_param/1" do
    test "converts a message back into a request-shaped map" do
      message = Message.from_json(@raw_body)

      assert %{role: "assistant", content: [%{type: "text", text: "Hello!"}]} =
               Message.to_param(message)
    end
  end

  describe "tool_use?/1 and tool_uses/1" do
    test "true and populated when stop_reason is tool_use" do
      body = %{
        @raw_body
        | "stop_reason" => "tool_use",
          "content" => [
            %{"type" => "text", "text" => "Let me check."},
            %{
              "type" => "tool_use",
              "id" => "toolu_1",
              "name" => "get_weather",
              "input" => %{"location" => "Paris"}
            }
          ]
      }

      message = Message.from_json(body)

      assert Message.tool_use?(message)
      assert [%ToolUse{id: "toolu_1", name: "get_weather"}] = Message.tool_uses(message)
    end

    test "false and empty when stop_reason is end_turn" do
      message = Message.from_json(@raw_body)

      refute Message.tool_use?(message)
      assert [] == Message.tool_uses(message)
    end

    test "tool_uses/1 ignores server_tool_use blocks — ToolRunner must never try to dispatch them" do
      body = %{
        @raw_body
        | "content" => [
            %{
              "type" => "server_tool_use",
              "id" => "srvtoolu_1",
              "name" => "web_search",
              "input" => %{"query" => "elixir"}
            },
            %{"type" => "web_search_tool_result", "tool_use_id" => "srvtoolu_1", "content" => []},
            %{"type" => "text", "text" => "Elixir 1.20 was released recently."}
          ]
      }

      message = Message.from_json(body)

      refute Message.tool_use?(message)
      assert [] == Message.tool_uses(message)
    end
  end
end
