defmodule Anthropic.Messages.StreamAccumulatorTest do
  use ExUnit.Case, async: true

  alias Anthropic.Messages.StreamAccumulator
  alias Anthropic.Messages.StreamEvent, as: SE
  alias Anthropic.Messages.Content

  defp base_message do
    %Anthropic.Messages.Message{
      id: "msg_1",
      type: "message",
      role: "assistant",
      content: [],
      model: "claude-opus-4-8",
      usage: %{"input_tokens" => 10}
    }
  end

  describe "accumulate/1" do
    test "folds a simple text response" do
      events = [
        %SE.MessageStart{message: base_message()},
        %SE.ContentBlockStart{index: 0, content_block: %Content.Text{text: ""}},
        %SE.ContentBlockDelta{index: 0, delta: %{"type" => "text_delta", "text" => "Hi"}},
        %SE.ContentBlockDelta{index: 0, delta: %{"type" => "text_delta", "text" => " there"}},
        %SE.ContentBlockStop{index: 0},
        %SE.MessageDelta{
          delta: %{"stop_reason" => "end_turn", "stop_sequence" => nil},
          usage: %{"output_tokens" => 3}
        },
        %SE.MessageStop{}
      ]

      assert {:ok, message} = StreamAccumulator.accumulate(events)

      assert message.stop_reason == "end_turn"
      assert message.content == [%Content.Text{text: "Hi there"}]
      assert message.usage == %{"input_tokens" => 10, "output_tokens" => 3}
    end

    test "accumulates split input_json_delta fragments into a parsed tool_use input" do
      events = [
        %SE.MessageStart{message: base_message()},
        %SE.ContentBlockStart{
          index: 0,
          content_block: %Content.ToolUse{id: "toolu_1", name: "get_weather", input: %{}}
        },
        %SE.ContentBlockDelta{
          index: 0,
          delta: %{"type" => "input_json_delta", "partial_json" => "{\"loc"}
        },
        %SE.ContentBlockDelta{
          index: 0,
          delta: %{"type" => "input_json_delta", "partial_json" => "ation\":\"Paris\"}"}
        },
        %SE.ContentBlockStop{index: 0},
        %SE.MessageDelta{delta: %{"stop_reason" => "tool_use"}, usage: %{"output_tokens" => 8}},
        %SE.MessageStop{}
      ]

      assert {:ok, message} = StreamAccumulator.accumulate(events)

      assert message.content == [
               %Content.ToolUse{
                 id: "toolu_1",
                 name: "get_weather",
                 input: %{"location" => "Paris"}
               }
             ]
    end

    test "handles multiple content blocks in order" do
      events = [
        %SE.MessageStart{message: base_message()},
        %SE.ContentBlockStart{
          index: 0,
          content_block: %Content.Thinking{thinking: "", signature: nil}
        },
        %SE.ContentBlockDelta{
          index: 0,
          delta: %{"type" => "thinking_delta", "thinking" => "Let me think"}
        },
        %SE.ContentBlockDelta{
          index: 0,
          delta: %{"type" => "signature_delta", "signature" => "sig123"}
        },
        %SE.ContentBlockStop{index: 0},
        %SE.ContentBlockStart{index: 1, content_block: %Content.Text{text: ""}},
        %SE.ContentBlockDelta{index: 1, delta: %{"type" => "text_delta", "text" => "Answer"}},
        %SE.ContentBlockStop{index: 1},
        %SE.MessageDelta{delta: %{"stop_reason" => "end_turn"}, usage: %{"output_tokens" => 5}},
        %SE.MessageStop{}
      ]

      assert {:ok, message} = StreamAccumulator.accumulate(events)

      assert message.content == [
               %Content.Thinking{thinking: "Let me think", signature: "sig123"},
               %Content.Text{text: "Answer"}
             ]
    end

    test "an in-band Error event halts accumulation and returns {:error, error}" do
      events = [
        %SE.MessageStart{message: base_message()},
        %SE.ContentBlockStart{index: 0, content_block: %Content.Text{text: ""}},
        %SE.ContentBlockDelta{index: 0, delta: %{"type" => "text_delta", "text" => "partial"}},
        %SE.Error{error: Anthropic.Error.new(:overloaded_error, "Overloaded")}
      ]

      assert {:error, %Anthropic.Error{type: :overloaded_error}} =
               StreamAccumulator.accumulate(events)
    end

    test "accumulates split input_json_delta fragments into a parsed server_tool_use input" do
      events = [
        %SE.MessageStart{message: base_message()},
        %SE.ContentBlockStart{
          index: 0,
          content_block: %Content.ServerToolUse{id: "srvtoolu_1", name: "web_search", input: %{}}
        },
        %SE.ContentBlockDelta{
          index: 0,
          delta: %{"type" => "input_json_delta", "partial_json" => "{\"que"}
        },
        %SE.ContentBlockDelta{
          index: 0,
          delta: %{"type" => "input_json_delta", "partial_json" => "ry\":\"elixir\"}"}
        },
        %SE.ContentBlockStop{index: 0},
        %SE.MessageDelta{delta: %{"stop_reason" => "end_turn"}, usage: %{"output_tokens" => 8}},
        %SE.MessageStop{}
      ]

      assert {:ok, message} = StreamAccumulator.accumulate(events)

      assert message.content == [
               %Content.ServerToolUse{
                 id: "srvtoolu_1",
                 name: "web_search",
                 input: %{"query" => "elixir"},
                 caller: nil
               }
             ]
    end

    test "malformed accumulated JSON for a tool_use input falls back to an empty map" do
      events = [
        %SE.MessageStart{message: base_message()},
        %SE.ContentBlockStart{
          index: 0,
          content_block: %Content.ToolUse{id: "toolu_1", name: "x", input: %{}}
        },
        %SE.ContentBlockDelta{
          index: 0,
          delta: %{"type" => "input_json_delta", "partial_json" => "not json"}
        },
        %SE.ContentBlockStop{index: 0},
        %SE.MessageDelta{delta: %{"stop_reason" => "tool_use"}, usage: %{}},
        %SE.MessageStop{}
      ]

      assert {:ok, message} = StreamAccumulator.accumulate(events)
      assert [%Content.ToolUse{input: %{}}] = message.content
    end
  end
end
