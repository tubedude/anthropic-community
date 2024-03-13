defmodule AnthropicTest.MockTool do
  @behaviour Anthropic.Tools.ToolBehaviour

  def description, do: "Mock tool for testing."

  def parameters,
    do: [{:param1, :string, "First parameter"}, {:param2, :integer, "Second parameter"}]

  def invoke(_args), do: "Mock result"
end
