defmodule Anthropic.CacheControl do
  @moduledoc """
  Builds `cache_control` maps for [prompt
  caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching). Attach the
  result to a content block's `:cache_control` field
  (`Anthropic.Messages.Content.{Text, Image, ToolUse, ToolResult}`) to mark it as a cache
  breakpoint.

  ## Examples

      %Anthropic.Messages.Content.Text{text: large_system_prompt, cache_control: Anthropic.CacheControl.ephemeral()}
      %Anthropic.Messages.Content.Text{text: large_system_prompt, cache_control: Anthropic.CacheControl.ephemeral(ttl: "1h")}
  """

  @schema NimbleOptions.new!(
            ttl: [
              type: {:in, ["5m", "1h"]},
              doc:
                "Cache breakpoint time-to-live. Defaults to \"5m\" (the API's own default) when omitted."
            ]
          )

  @doc """
  Builds an ephemeral cache_control map.

  ## Options

  #{NimbleOptions.docs(@schema)}
  """
  @spec ephemeral(keyword()) :: map()
  def ephemeral(opts \\ []) do
    opts = NimbleOptions.validate!(opts, @schema)

    %{type: "ephemeral"}
    |> maybe_put(:ttl, opts[:ttl])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
