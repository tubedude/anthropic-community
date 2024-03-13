defmodule Anthropic.Messages.ResponseTest do
  use ExUnit.Case, async: true

  alias Anthropic.Messages.Response
  alias AnthropicTest.MockTool

  require AnthropicTest.MockTool

  describe "parse/2 with tool invocation" do
    setup do
      tools_request =
        Anthropic.new()
        |> Anthropic.register_tool(MockTool)

      {:ok, request: tools_request}
    end

    test "parses tool invocation from content text", %{request: request} do
      # Simulated JSON string as it would be received from the API
      simulated_response_json = """
      {
        "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
        "type": "message",
        "role": "assistant",
        "content": [
          {
            "type": "text",
            "text": "<function_calls><invoke><tool_name>Elixir.AnthropicTest.MockTool</tool_name><parameters><param1>test_value1</param1><param2>42</param2></parameters></invoke></function_calls>"
          }
        ],
        "model": "claude-2.1",
        "stop_reason": "end_turn",
        "stop_sequence": null,
        "usage": {
          "input_tokens": 12,
          "output_tokens": 6
        }
      }
      """

      # Parse the simulated JSON response
      {:ok, parsed_response} =
        Response.parse(
          {:ok, %Finch.Response{status: 200, body: simulated_response_json}},
          request
        )

      # Expected invocation format
      expected_invocations = [{MockTool, ["test_value1", "42"]}]

      # Assert invocations are parsed and stored correctly
      assert parsed_response.invocations == expected_invocations
    end
  end
end
