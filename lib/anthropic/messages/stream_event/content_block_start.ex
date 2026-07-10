defmodule Anthropic.Messages.StreamEvent.ContentBlockStart do
  @moduledoc "Announces a new content block at `index`, with its (still-partial) initial value."

  defstruct [:index, :content_block]

  @type t :: %__MODULE__{index: non_neg_integer(), content_block: Anthropic.Messages.Content.t()}
end
