defmodule Anthropic.ToolRunnerTest do
  use ExUnit.Case
  import Mox

  alias Anthropic.{Client, ToolRunner}
  alias AnthropicTest.MockTool

  setup :verify_on_exit!

  setup do
    {:ok, client: Client.new(api_key: "test-key")}
  end

  defp response(status, body),
    do: %Finch.Response{status: status, body: Jason.encode!(body), headers: []}

  defp tool_use_body(tool_calls) do
    %{
      "id" => "msg_1",
      "type" => "message",
      "role" => "assistant",
      "content" =>
        Enum.map(tool_calls, fn {id, name, input} ->
          %{"type" => "tool_use", "id" => id, "name" => name, "input" => input}
        end),
      "model" => "claude-opus-4-8",
      "stop_reason" => "tool_use",
      "usage" => %{"input_tokens" => 10, "output_tokens" => 5}
    }
  end

  defp final_text_body(text) do
    %{
      "id" => "msg_final",
      "type" => "message",
      "role" => "assistant",
      "content" => [%{"type" => "text", "text" => text}],
      "model" => "claude-opus-4-8",
      "stop_reason" => "end_turn",
      "usage" => %{"input_tokens" => 10, "output_tokens" => 5}
    }
  end

  describe "run/4 with a single tool call" do
    test "executes the tool and returns the final text response", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn _req, _pool, _opts ->
        {:ok,
         response(
           200,
           tool_use_body([{"toolu_1", "mock_tool", %{"param1" => "a", "param2" => 1}}])
         )}
      end)
      |> expect(:request, fn _req, _pool, _opts ->
        {:ok, response(200, final_text_body("All done."))}
      end)

      {:ok, message, history} =
        ToolRunner.run(
          client,
          [
            model: "claude-opus-4-8",
            max_tokens: 100,
            messages: [%{role: "user", content: "Use the tool"}]
          ],
          [MockTool]
        )

      assert %Anthropic.Messages.Message{stop_reason: "end_turn"} = message
      assert [%Anthropic.Messages.Content.Text{text: "All done."}] = message.content

      # history: original user message, assistant tool_use, user tool_result, assistant final
      assert length(history) == 4
      assert Enum.at(history, 0).content == "Use the tool"

      assistant_tool_use = Enum.at(history, 1)
      assert assistant_tool_use.role == "assistant"
      assert [%{type: "tool_use", id: "toolu_1", name: "mock_tool"}] = assistant_tool_use.content

      user_tool_result = Enum.at(history, 2)
      assert user_tool_result.role == "user"

      assert [
               %{
                 type: "tool_result",
                 tool_use_id: "toolu_1",
                 content: "Mock result",
                 is_error: false
               }
             ] = user_tool_result.content
    end
  end

  describe "run/4 with parallel tool calls" do
    test "sends all tool_results for one turn in a single user message", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn _req, _pool, _opts ->
        {:ok,
         response(
           200,
           tool_use_body([
             {"toolu_1", "mock_tool", %{"param1" => "a", "param2" => 1}},
             {"toolu_2", "mock_tool", %{"param1" => "b", "param2" => 2}}
           ])
         )}
      end)
      |> expect(:request, fn req, _pool, _opts ->
        body = Jason.decode!(req.body)
        last_message = List.last(body["messages"])

        assert last_message["role"] == "user"
        assert length(last_message["content"]) == 2
        assert Enum.map(last_message["content"], & &1["tool_use_id"]) == ["toolu_1", "toolu_2"]

        {:ok, response(200, final_text_body("Both done."))}
      end)

      assert {:ok, %Anthropic.Messages.Message{}, _history} =
               ToolRunner.run(
                 client,
                 [
                   model: "claude-opus-4-8",
                   max_tokens: 100,
                   messages: [%{role: "user", content: "Use both"}]
                 ],
                 [MockTool]
               )
    end
  end

  describe "run/4 with an unregistered tool" do
    test "returns an is_error tool_result and the loop continues", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn _req, _pool, _opts ->
        {:ok, response(200, tool_use_body([{"toolu_1", "unknown_tool", %{}}]))}
      end)
      |> expect(:request, fn req, _pool, _opts ->
        body = Jason.decode!(req.body)
        last_message = List.last(body["messages"])
        result = List.first(last_message["content"])

        assert result["is_error"] == true
        assert result["content"] =~ "not registered"

        {:ok, response(200, final_text_body("Recovered."))}
      end)

      assert {:ok, %Anthropic.Messages.Message{stop_reason: "end_turn"}, _history} =
               ToolRunner.run(
                 client,
                 [
                   model: "claude-opus-4-8",
                   max_tokens: 100,
                   messages: [%{role: "user", content: "Use unknown"}]
                 ],
                 [MockTool]
               )
    end
  end

  describe "run/4 max_iterations" do
    test "returns an error when the loop never converges", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> stub(:request, fn _req, _pool, _opts ->
        {:ok,
         response(
           200,
           tool_use_body([{"toolu_1", "mock_tool", %{"param1" => "a", "param2" => 1}}])
         )}
      end)

      assert {:error, %Anthropic.Error{type: :tool_runner_max_iterations}} =
               ToolRunner.run(
                 client,
                 [
                   model: "claude-opus-4-8",
                   max_tokens: 100,
                   messages: [%{role: "user", content: "Loop forever"}]
                 ],
                 [MockTool],
                 2
               )
    end
  end
end
