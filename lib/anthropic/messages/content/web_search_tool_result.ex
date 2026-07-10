defmodule Anthropic.Messages.Content.WebSearchToolResult do
  @moduledoc """
  The result of a `web_search` server-tool call. `content` is the raw decoded JSON payload
  (a list of search-result maps, or an error map) — not deeply typed, since the API defines
  several nested result/error sub-shapes; see the [web search tool
  docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-search-tool) for
  its shape.
  """

  defstruct [:tool_use_id, :content, :caller]

  @type t :: %__MODULE__{
          tool_use_id: String.t(),
          content: list(map()) | map(),
          caller: map() | nil
        }
end
