defmodule Anthropic.Messages.StreamEventTest do
  use ExUnit.Case, async: true

  alias Anthropic.Messages.StreamEvent, as: SE
  alias Anthropic.Messages.Content

  describe "decode/2" do
    test "message_start" do
      data =
        Jason.encode!(%{
          "type" => "message_start",
          "message" => %{
            "id" => "msg_1",
            "type" => "message",
            "role" => "assistant",
            "content" => [],
            "model" => "claude-opus-4-8",
            "usage" => %{"input_tokens" => 10, "output_tokens" => 0}
          }
        })

      assert %SE.MessageStart{
               message: %Anthropic.Messages.Message{id: "msg_1", role: "assistant"}
             } =
               SE.decode("message_start", data)
    end

    test "content_block_start with a text block" do
      data =
        Jason.encode!(%{
          "type" => "content_block_start",
          "index" => 0,
          "content_block" => %{"type" => "text", "text" => ""}
        })

      assert %SE.ContentBlockStart{index: 0, content_block: %Content.Text{text: ""}} =
               SE.decode("content_block_start", data)
    end

    test "content_block_start with a tool_use block" do
      data =
        Jason.encode!(%{
          "type" => "content_block_start",
          "index" => 1,
          "content_block" => %{
            "type" => "tool_use",
            "id" => "toolu_1",
            "name" => "get_weather",
            "input" => %{}
          }
        })

      assert %SE.ContentBlockStart{
               index: 1,
               content_block: %Content.ToolUse{id: "toolu_1", name: "get_weather"}
             } =
               SE.decode("content_block_start", data)
    end

    test "content_block_delta text_delta" do
      data =
        Jason.encode!(%{
          "type" => "content_block_delta",
          "index" => 0,
          "delta" => %{"type" => "text_delta", "text" => "Hi"}
        })

      assert %SE.ContentBlockDelta{index: 0, delta: %{"type" => "text_delta", "text" => "Hi"}} =
               SE.decode("content_block_delta", data)
    end

    test "content_block_stop" do
      data = Jason.encode!(%{"type" => "content_block_stop", "index" => 0})
      assert %SE.ContentBlockStop{index: 0} = SE.decode("content_block_stop", data)
    end

    test "message_delta" do
      data =
        Jason.encode!(%{
          "type" => "message_delta",
          "delta" => %{"stop_reason" => "end_turn", "stop_sequence" => nil},
          "usage" => %{"output_tokens" => 15}
        })

      assert %SE.MessageDelta{
               delta: %{"stop_reason" => "end_turn"},
               usage: %{"output_tokens" => 15}
             } =
               SE.decode("message_delta", data)
    end

    test "message_stop" do
      assert %SE.MessageStop{} =
               SE.decode("message_stop", Jason.encode!(%{"type" => "message_stop"}))
    end

    test "ping" do
      assert %SE.Ping{} = SE.decode("ping", Jason.encode!(%{"type" => "ping"}))
    end

    test "error event" do
      data =
        Jason.encode!(%{
          "type" => "error",
          "error" => %{"type" => "overloaded_error", "message" => "Overloaded"}
        })

      assert %SE.Error{error: %Anthropic.Error{type: :overloaded_error, message: "Overloaded"}} =
               SE.decode("error", data)
    end

    test "malformed JSON decodes to a terminal Error event rather than raising" do
      assert %SE.Error{error: %Anthropic.Error{type: :decode_error}} = SE.decode(nil, "not json{")
    end

    test "an unrecognized but valid JSON event decodes to a decode_error" do
      assert %SE.Error{error: %Anthropic.Error{type: :decode_error}} =
               SE.decode("mystery", Jason.encode!(%{"type" => "some_future_event"}))
    end
  end
end
