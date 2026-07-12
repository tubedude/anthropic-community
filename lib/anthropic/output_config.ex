defmodule Anthropic.OutputConfig do
  @moduledoc """
  Builds `output_config` request-param maps for [structured
  outputs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs). Pass
  the result as the `:output_config` option to `Anthropic.Messages.create/2` or `stream/2`
  to constrain Claude's response to a given JSON Schema.

  ## Examples

      Anthropic.Messages.create(client,
        model: "claude-opus-4-8",
        max_tokens: 1024,
        output_config: Anthropic.OutputConfig.json_schema(%{
          "type" => "object",
          "properties" => %{"answer" => %{"type" => "string"}},
          "required" => ["answer"]
        }),
        messages: [%{role: "user", content: "..."}]
      )
  """

  @schema NimbleOptions.new!(
            effort: [
              type: {:in, ["low", "medium", "high", "xhigh", "max"]},
              doc: "Reasoning effort level to apply while producing the structured output."
            ]
          )

  @doc """
  Builds an `output_config` that constrains the response to the given JSON Schema.

  ## Options

  #{NimbleOptions.docs(@schema)}
  """
  @spec json_schema(map(), keyword()) :: map()
  def json_schema(json_schema, opts \\ []) when is_map(json_schema) do
    opts = NimbleOptions.validate!(opts, @schema)

    %{format: %{type: "json_schema", schema: json_schema}}
    |> maybe_put(:effort, opts[:effort])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
