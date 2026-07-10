defmodule Anthropic.Messages.Content.Text do
  @moduledoc "A plain text content block."

  defstruct [:text, :citations, :cache_control]

  @type t :: %__MODULE__{
          text: String.t(),
          citations: list(map()) | nil,
          cache_control: map() | nil
        }
end
