defmodule Anthropic.Thinking do
  @moduledoc """
  Builds `thinking` request-param maps for [extended
  thinking](https://platform.claude.com/docs/en/build-with-claude/extended-thinking). Pass
  the result as the `:thinking` option to `Anthropic.Messages.create/2` or `stream/2`.

  ## Examples

      Anthropic.Messages.create(client,
        model: "claude-opus-4-8",
        max_tokens: 4096,
        thinking: Anthropic.Thinking.enabled(budget_tokens: 10_000),
        messages: [%{role: "user", content: "..."}]
      )
  """

  @display_type {:in, ["summarized", "omitted"]}
  @display_doc "Controls how thinking content appears in the response. When set to `\"summarized\"`, thinking is returned normally. When set to `\"omitted\"`, thinking content is redacted but a signature is returned for multi-turn continuity. Defaults to `\"summarized\"`."

  @enabled_schema NimbleOptions.new!(
                    budget_tokens: [
                      type: :pos_integer,
                      required: true,
                      doc:
                        "Token budget for Claude's internal reasoning. Must be >= 1024 and less than `max_tokens`."
                    ],
                    display: [type: @display_type, doc: @display_doc]
                  )

  @adaptive_schema NimbleOptions.new!(display: [type: @display_type, doc: @display_doc])

  @doc """
  Enables extended thinking with a fixed token budget.

  ## Options

  #{NimbleOptions.docs(@enabled_schema)}
  """
  @spec enabled(keyword()) :: map()
  def enabled(opts) do
    opts = NimbleOptions.validate!(opts, @enabled_schema)

    %{type: "enabled", budget_tokens: opts[:budget_tokens]}
    |> maybe_put(:display, opts[:display])
  end

  @doc """
  Enables adaptive extended thinking — Claude decides how much to think, rather than a fixed
  token budget.

  ## Options

  #{NimbleOptions.docs(@adaptive_schema)}
  """
  @spec adaptive(keyword()) :: map()
  def adaptive(opts \\ []) do
    opts = NimbleOptions.validate!(opts, @adaptive_schema)

    %{type: "adaptive"}
    |> maybe_put(:display, opts[:display])
  end

  @doc "Disables extended thinking. Equivalent to omitting `:thinking` entirely, provided for symmetry with `enabled/1` and `adaptive/1`."
  @spec disabled() :: map()
  def disabled, do: %{type: "disabled"}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
