defmodule Anthropic.Messages.StreamEvent.MessageStop do
  @moduledoc "The final event of a successful stream."

  defstruct []

  @type t :: %__MODULE__{}
end
