defmodule Anthropic.Messages.Content.RedactedThinking do
  @moduledoc "A redacted-thinking content block (opaque, encrypted thinking content)."

  defstruct [:data]

  @type t :: %__MODULE__{data: String.t()}
end
