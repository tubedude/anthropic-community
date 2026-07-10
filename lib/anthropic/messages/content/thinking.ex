defmodule Anthropic.Messages.Content.Thinking do
  @moduledoc "An extended-thinking content block."

  defstruct [:thinking, :signature]

  @type t :: %__MODULE__{thinking: String.t(), signature: String.t() | nil}
end
