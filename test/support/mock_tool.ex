defmodule AnthropicTest.MockTool do
  use Anthropic.Tools

  @impl true
  def name, do: "mock_tool"

  @impl true
  def description, do: "Mock tool for testing."

  @impl true
  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "param1" => %{"type" => "string", "description" => "First parameter"},
        "param2" => %{"type" => "integer", "description" => "Second parameter"}
      },
      "required" => ["param1", "param2"]
    }
  end

  @impl true
  def execute(_input), do: {:ok, "Mock result"}
end
