defmodule Anthropic.Messages.Content.CodeExecutionToolResult do
  @moduledoc """
  The result of a `code_execution` server-tool call. `content` is the raw decoded JSON
  payload (a stdout/stderr/return-code map, or an error map) — not deeply typed; see the
  [code execution tool
  docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/code-execution-tool)
  for its shape.
  """

  defstruct [:tool_use_id, :content]

  @type t :: %__MODULE__{tool_use_id: String.t(), content: map()}
end
