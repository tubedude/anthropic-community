defmodule Anthropic.Messages.StreamEvent.ContentBlockStop do
  @moduledoc "Marks the content block at `index` as complete."

  defstruct [:index]

  @type t :: %__MODULE__{index: non_neg_integer()}
end
