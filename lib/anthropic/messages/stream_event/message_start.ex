defmodule Anthropic.Messages.StreamEvent.MessageStart do
  @moduledoc "The first event of a stream: a partial `Message` (empty content, incomplete usage)."

  defstruct [:message]

  @type t :: %__MODULE__{message: Anthropic.Messages.Message.t()}
end
