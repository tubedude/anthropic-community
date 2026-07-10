defmodule Anthropic.Tools do
  @moduledoc """
  Behaviour for user-defined tools, driving the native Anthropic `tools` API field (JSON
  Schema `input_schema`) rather than a hand-rolled prompt-injection protocol.

  ## Example

      defmodule MyApp.WeatherTool do
        use Anthropic.Tools

        @impl true
        def name, do: "get_weather"

        @impl true
        def description, do: "Get the current weather for a given city."

        @impl true
        def input_schema do
          %{
            "type" => "object",
            "properties" => %{
              "location" => %{"type" => "string", "description" => "City and state, e.g. San Francisco, CA"}
            },
            "required" => ["location"]
          }
        end

        @impl true
        def execute(%{"location" => location}) do
          {:ok, "72F and sunny in \#{location}"}
        end
      end

  Register tools with `Anthropic.Messages.create/2` via the `:tools` option (either tool
  modules or raw wire-shape maps), or drive a full agentic loop with `Anthropic.ToolRunner.run/4`.
  """

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback input_schema() :: map()
  @callback execute(input :: map()) :: {:ok, String.t() | map()} | {:error, String.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Anthropic.Tools
    end
  end

  @doc "Serializes a tool module (or a raw wire-shape map, passed through unchanged) into a `tools` request param entry."
  @spec to_param(module() | map()) :: map()
  def to_param(tool_module) when is_atom(tool_module) do
    %{
      name: tool_module.name(),
      description: tool_module.description(),
      input_schema: tool_module.input_schema()
    }
  end

  def to_param(%{} = raw_tool_map), do: raw_tool_map
end
