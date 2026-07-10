defmodule Anthropic.Messages.Content.ToolResult do
  @moduledoc """
  The result of executing a tool, sent back to the API as a `tool_result` content block
  inside a `user` message. `tool_use_id` must match the `id` of the corresponding
  `Anthropic.Messages.Content.ToolUse` block the assistant requested.
  """

  defstruct [:tool_use_id, :content, is_error: false]

  @type t :: %__MODULE__{
          tool_use_id: String.t(),
          content: String.t() | list(map()),
          is_error: boolean()
        }
end
