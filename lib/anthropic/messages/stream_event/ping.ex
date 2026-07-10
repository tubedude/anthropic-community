defmodule Anthropic.Messages.StreamEvent.Ping do
  @moduledoc "A keep-alive event with no payload."

  defstruct []

  @type t :: %__MODULE__{}
end
