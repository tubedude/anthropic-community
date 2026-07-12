defmodule Anthropic.Tools.Memory do
  @moduledoc """
  Builds the [memory](https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool)
  server tool definition. Pass the result inside the `:tools` list to
  `Anthropic.Messages.create/2` — Claude manages a persistent file-based memory store
  server-side; no client-side `execute/1` needed.

  ## Examples

      Anthropic.Messages.create(client,
        model: "claude-opus-4-8",
        max_tokens: 1024,
        tools: [Anthropic.Tools.Memory.new()],
        messages: [%{role: "user", content: "Remember that I prefer concise answers."}]
      )
  """

  @latest_version "memory_20250818"

  @schema NimbleOptions.new!(
            version: [
              type: :string,
              default: @latest_version,
              doc: "The tool's versioned `type` string. Override to pin an older API version."
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

    Anthropic.Tools.ServerTool.build(%{type: version, name: "memory"}, opts)
  end
end
