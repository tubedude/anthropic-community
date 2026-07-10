defmodule Anthropic.Tools.BashTest do
  use ExUnit.Case, async: true

  alias Anthropic.Tools.Bash

  test "defaults to the latest version and just name/type" do
    assert Bash.new() == %{type: "bash_20250124", name: "bash"}
  end
end
