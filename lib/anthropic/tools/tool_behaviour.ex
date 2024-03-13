defmodule Anthropic.Tools.ToolBehaviour do
  @moduledoc """
  Tool behaviour module, describe callbacks and basic functions to support tool description,
  as described in [the documentation](https://docs.anthropic.com/claude/docs/functions-external-tools)
  """
  @type parameter_type() :: :string | :float | :integer
  @type parameter() :: {atom(), parameter_type(), String.t()}

  @callback description() :: String.t()
  @callback parameters() :: list(parameter())
  @callback invoke(list(String.t())) :: String.t()

  defmacro __using__(_) do
    quote do
      @behaviour Anthropic.Tools.ToolBehaviour
    end
  end
end
