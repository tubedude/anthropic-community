defmodule Anthropic.Tools.ServerTool do
  @moduledoc false

  @spec build(map(), keyword()) :: map()
  def build(base, opts) do
    Enum.reduce(opts, base, fn
      {_key, nil}, acc -> acc
      {key, value}, acc -> Map.put(acc, key, value)
    end)
  end
end
