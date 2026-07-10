defmodule Anthropic.Messages.StreamEvent.Error do
  @moduledoc """
  A terminal error delivered as the final element of the event stream — either an in-band
  `event: error` frame from the API, or a transport-level failure (connection drop, decode
  failure, timeout) surfaced this way instead of raising mid-`Stream`.
  """

  defstruct [:error]

  @type t :: %__MODULE__{error: Anthropic.Error.t()}
end
