defmodule Anthropic.Tools.WebSearch do
  @moduledoc """
  Builds the [web search](https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-search-tool)
  server tool definition. Pass the result inside the `:tools` list to
  `Anthropic.Messages.create/2` — Claude performs the search server-side and the result
  comes back as a `%Anthropic.Messages.Content.WebSearchToolResult{}` block; there is no
  client-side `execute/1` to implement, unlike `Anthropic.Tools`-based custom tools.

  ## Examples

      Anthropic.Messages.create(client,
        model: "claude-opus-4-8",
        max_tokens: 1024,
        tools: [Anthropic.Tools.WebSearch.new(max_uses: 3)],
        messages: [%{role: "user", content: "What's the latest Elixir release?"}]
      )
  """

  @latest_version "web_search_20260318"

  @schema NimbleOptions.new!(
            version: [
              type: :string,
              default: @latest_version,
              doc: "The tool's versioned `type` string. Override to pin an older API version."
            ],
            max_uses: [
              type: :pos_integer,
              doc: "Maximum number of searches Claude can perform in this request."
            ],
            allowed_domains: [
              type: {:list, :string},
              doc:
                "Only these domains are included in results. Cannot be combined with `:blocked_domains`."
            ],
            blocked_domains: [
              type: {:list, :string},
              doc:
                "These domains are never included in results. Cannot be combined with `:allowed_domains`."
            ],
            user_location: [
              type: :map,
              doc:
                "Location hint (e.g. `%{type: \"approximate\", city: \"...\"}`) for more relevant results."
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

    Anthropic.Tools.ServerTool.build(%{type: version, name: "web_search"}, opts)
  end
end
