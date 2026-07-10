defmodule Anthropic.Messages.Content.ToolUse do
  @moduledoc "A tool invocation requested by the assistant, as a native `tool_use` content block."

  defstruct [:id, :name, :input]

  @type t :: %__MODULE__{id: String.t(), name: String.t(), input: map()}
end
