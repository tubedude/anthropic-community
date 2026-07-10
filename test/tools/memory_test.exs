defmodule Anthropic.Tools.MemoryTest do
  use ExUnit.Case, async: true

  alias Anthropic.Tools.Memory

  test "defaults to the latest version and just name/type" do
    assert Memory.new() == %{type: "memory_20250818", name: "memory"}
  end
end
