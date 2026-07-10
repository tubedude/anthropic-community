defmodule Anthropic.Tools.WebFetch do
  @moduledoc """
  Builds the [web fetch](https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-fetch-tool)
  server tool definition. Pass the result inside the `:tools` list to
  `Anthropic.Messages.create/2` — Claude fetches the URL server-side and the result comes
  back as a `%Anthropic.Messages.Content.WebFetchToolResult{}` block; no client-side
  `execute/1` needed.

  ## Examples

      Anthropic.Messages.create(client,
        model: "claude-opus-4-8",
        max_tokens: 1024,
        tools: [Anthropic.Tools.WebFetch.new(max_uses: 3)],
        messages: [%{role: "user", content: "Summarize https://example.com/article"}]
      )
  """

  @latest_version "web_fetch_20260318"

  @schema NimbleOptions.new!(
            version: [
              type: :string,
              default: @latest_version,
              doc: "The tool's versioned `type` string. Override to pin an older API version."
            ],
            max_uses: [
              type: :pos_integer,
              doc: "Maximum number of fetches Claude can perform in this request."
            ],
            max_content_tokens: [
              type: :pos_integer,
              doc: "Approximate cap on tokens used by fetched page content."
            ],
            allowed_domains: [type: {:list, :string}, doc: "Only these domains may be fetched."],
            blocked_domains: [type: {:list, :string}, doc: "These domains may never be fetched."],
            citations: [
              type: :map,
              doc:
                "Citations config for fetched documents, e.g. `%{enabled: true}`. Disabled by default."
            ],
            cache_control: [type: :map, doc: "An `Anthropic.CacheControl` map."]
          )

  @doc """
  ## Options

  #{NimbleOptions.docs(@schema)}
  """
  @spec new(keyword()) :: map()
  def new(opts \\ []) do
    opts = NimbleOptions.validate!(opts, @schema)
    {version, opts} = Keyword.pop!(opts, :version)

    Anthropic.Tools.ServerTool.build(%{type: version, name: "web_fetch"}, opts)
  end
end
