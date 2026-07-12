defmodule Anthropic.Messages.Content.ServerToolUse do
  @moduledoc """
  A server tool invocation the API executed on Claude's behalf (web search, web fetch, code
  execution, bash, text editor). Unlike `Anthropic.Messages.Content.ToolUse`, this never
  needs a client-side `execute/1` dispatch — the matching `*ToolResult` block already
  carries the result within the same turn, and `Anthropic.ToolRunner`/`Message.tool_uses/1`
  don't match on this struct, so it's simply along for the ride when replaying message
  history.

  `name` is one of `"web_search"`, `"web_fetch"`, `"code_execution"`,
  `"bash_code_execution"`, `"text_editor_code_execution"` — note the last two differ from
  the tool definition's own name (`"bash"`/`"str_replace_based_edit_tool"`, per
  `Anthropic.Tools.Bash`/`Anthropic.Tools.TextEditor`).
  """

  defstruct [:id, :name, :input, :caller]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          input: map(),
          caller: map() | nil
        }
end
