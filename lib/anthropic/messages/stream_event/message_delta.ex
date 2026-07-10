defmodule Anthropic.Messages.StreamEvent.MessageDelta do
  @moduledoc "Top-level message fields that change at the end of a turn (`stop_reason`, `stop_sequence`) plus cumulative usage."

  defstruct [:delta, :usage]

  @type t :: %__MODULE__{delta: map(), usage: map()}
end
