defmodule Tools.UtilsTest do
  use ExUnit.Case
  alias Anthropic.Tools.Utils

  describe "parse_invoke_function/1" do
    test "parses XML string and returns a list of tool invocations" do
      xml_string = """
      <invoke>
        <tool_name>Elixir.AnthropicTest.MockTool</tool_name>
        <parameters>
          <param1>value1</param1>
          <param2>42</param2>
        </parameters>
      </invoke>
      <invoke>
        <tool_name>Elixir.AnthropicTest.AnotherMockTool</tool_name>
        <parameters>
          <name>value2</name>
        </parameters>
      </invoke>
      """

      expected_invocations = [
        {AnthropicTest.MockTool, [param1: "value1", param2: "42"]},
        {AnthropicTest.AnotherMockTool, [name: "value2"]}
      ]

      actual_invocations = Utils.parse_invoke_function(xml_string)
      assert actual_invocations == expected_invocations
    end

    test "non-existing params atom" do
      invocation =
        "<invoke><tool_name>NoNExistant</tool_name><parameters><>Yeah</></parameters></invoke>"

      assert [nil: []] == Anthropic.Tools.Utils.parse_invoke_function(invocation)
    end
  end

  describe "execute_async/2" do
    test "executes the tool's invoke function asynchronously" do
      task = Utils.execute_async(AnthropicTest.MockTool, ["value1", 42])
      assert is_struct(task, Task)
    end
  end

  describe "format_response/2 with multiple tasks" do
    test "formats multiple tool invocation responses as XML" do
      task1 = Task.async(fn -> "Result from MockTool" end)
      task2 = Task.async(fn -> "Result from AnotherMockTool" end)
      tasks = [task1, task2]
      tool_names = [AnthropicTest.MockTool, AnthropicTest.AnotherMockTool]

      expected_xml =
        """
        <function_results>
        <result>
          <tool_name>Elixir.AnthropicTest.MockTool</tool_name>
          <stdout>
            Result from MockTool
          </stdout>
        </result>
        <result>
          <tool_name>Elixir.AnthropicTest.AnotherMockTool</tool_name>
          <stdout>
            Result from AnotherMockTool
          </stdout>
        </result>
        </function_results>
        """

      actual_xml = Utils.format_response(tasks, tool_names)
      assert actual_xml == expected_xml
    end
  end
end
