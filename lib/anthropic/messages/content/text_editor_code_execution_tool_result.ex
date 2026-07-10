defmodule Anthropic.Messages.Content.TextEditorCodeExecutionToolResult do
  @moduledoc """
  The result of a `text_editor` server-tool call (view/create/str_replace). `content` is
  the raw decoded JSON payload — not deeply typed, since its shape varies by which editor
  command was run; see the [text editor tool
  docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/text-editor-tool) for
  its shape.
  """

  defstruct [:tool_use_id, :content]

  @type t :: %__MODULE__{tool_use_id: String.t(), content: map()}
end
