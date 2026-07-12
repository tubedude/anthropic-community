defmodule Anthropic.Tools.Bash do
  @moduledoc """
  Builds the [bash](https://platform.claude.com/docs/en/agents-and-tools/tool-use/bash-tool)
  server tool definition. Pass the result inside the `:tools` list to
  `Anthropic.Messages.create/2` — Claude runs shell commands server-side in a sandbox and
  the result comes back as a `%Anthropic.Messages.Content.BashCodeExecutionToolResult{}`
  block; no client-side `execute/1` needed.

  ## Examples

      Anthropic.Messages.create(client,
        model: "claude-opus-4-8",
        max_tokens: 1024,
        tools: [Anthropic.Tools.Bash.new()],
        messages: [%{role: "user", content: "List the files in the current directory."}]
      )
  """

  @latest_version "bash_20250124"

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

    Anthropic.Tools.ServerTool.build(%{type: version, name: "bash"}, opts)
  end
end
