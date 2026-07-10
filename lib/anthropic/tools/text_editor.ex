defmodule Anthropic.Tools.TextEditor do
  @moduledoc """
  Builds the [text editor](https://platform.claude.com/docs/en/agents-and-tools/tool-use/text-editor-tool)
  server tool definition. Pass the result inside the `:tools` list to
  `Anthropic.Messages.create/2` — Claude views/creates/edits files server-side in a sandbox
  and the result comes back as a
  `%Anthropic.Messages.Content.TextEditorCodeExecutionToolResult{}` block; no client-side
  `execute/1` needed.

  ## Examples

      Anthropic.Messages.create(client,
        model: "claude-opus-4-8",
        max_tokens: 1024,
        tools: [Anthropic.Tools.TextEditor.new()],
        messages: [%{role: "user", content: "Fix the typo in main.py"}]
      )
  """

  @latest_version "text_editor_20250728"

  @schema NimbleOptions.new!(
            version: [
              type: :string,
              default: @latest_version,
              doc: "The tool's versioned `type` string. Override to pin an older API version."
            ],
            max_characters: [
              type: :pos_integer,
              doc: "Maximum characters to display when viewing a file. Defaults to the full file."
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

    Anthropic.Tools.ServerTool.build(%{type: version, name: "str_replace_based_edit_tool"}, opts)
  end
end
