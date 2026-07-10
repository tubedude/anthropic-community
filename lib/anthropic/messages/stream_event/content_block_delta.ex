defmodule Anthropic.Messages.StreamEvent.ContentBlockDelta do
  @moduledoc """
  An incremental update to the content block at `index`. `delta` is the raw wire delta map,
  one of `%{"type" => "text_delta", "text" => ...}`, `%{"type" => "input_json_delta",
  "partial_json" => ...}`, `%{"type" => "thinking_delta", "thinking" => ...}`, or
  `%{"type" => "signature_delta", "signature" => ...}`.
  """

  defstruct [:index, :delta]

  @type t :: %__MODULE__{index: non_neg_integer(), delta: map()}
end
