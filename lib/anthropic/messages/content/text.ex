defmodule Anthropic.Messages.Content.Text do
  @moduledoc "A plain text content block."

  defstruct [:text, :citations]

  @type t :: %__MODULE__{text: String.t(), citations: list(map()) | nil}
end
