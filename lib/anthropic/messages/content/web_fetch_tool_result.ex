defmodule Anthropic.Messages.Content.WebFetchToolResult do
  @moduledoc """
  The result of a `web_fetch` server-tool call. `content` is the raw decoded JSON payload
  (a fetched-document map, or an error map) — not deeply typed; see the [web fetch tool
  docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-fetch-tool) for
  its shape.
  """

  defstruct [:tool_use_id, :content, :caller]

  @type t :: %__MODULE__{tool_use_id: String.t(), content: map(), caller: map() | nil}
end
