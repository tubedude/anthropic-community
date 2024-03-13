defmodule Anthropic.Tools.ToolBehaviour do
  @moduledoc """
  Defines a behaviour for creating tools that can be used with Anthropic's AI models.

  This module provides a set of callbacks and basic functions to support tool description
  and invocation, as described in the [Anthropic documentation](https://docs.anthropic.com/claude/docs/functions-external-tools).

  To create a new tool, define a module that implements the `Anthropic.Tools.ToolBehaviour` behaviour.
  The module should implement the following callbacks:

  - `description/0`: Returns a string describing the purpose and functionality of the tool.
  - `parameters/0`: Returns a list of parameter specifications, where each parameter is represented
    as a tuple of `{name, type, description}`.
  - `invoke/1`: Invokes the tool with the provided Keyword list arguments and returns the result
    as a string.

  Example:

      defmodule MyTool do
        use Anthropic.Tools.ToolBehaviour

        def description do
          "A tool that performs a specific task."
        end

        def parameters do
          [
            {:param1, :string, "Description of param1."},
            {:param2, :integer, "Description of param2."}
          ]
        end

        def invoke(keyword_list) do
          # Implement the tool's functionality here
          # Use the provided arguments to perform the task
          # Return the result as a string
        end
      end
  """

  @type parameter_type() :: :string | :float | :integer
  @type parameter() :: {atom(), parameter_type(), String.t()}

  @doc """
  Returns a string describing the purpose and functionality of the tool.
  """
  @callback description() :: String.t()

  @doc """
  Returns a list of parameter specifications for the tool.

  Each parameter is represented as a tuple of `{name, type, description}`, where:
  - `name` is an atom representing the parameter name.
  - `type` is an atom representing the parameter type (`:string`, `:float`, or `:integer`).
  - `description` is a string describing the purpose of the parameter.
  """
  @callback parameters() :: list(parameter())

  @doc """
  Invokes the tool with the provided list of string arguments and returns the result as a string.
  """
  @callback invoke(Keyword.t()) :: String.t()

  defmacro __using__(_) do
    quote do
      @behaviour Anthropic.Tools.ToolBehaviour
    end
  end
end
