defmodule Anthropic.Tools.CodeExecutionTest do
  use ExUnit.Case, async: true

  alias Anthropic.Tools.CodeExecution

  test "defaults to the latest version and just name/type" do
    assert CodeExecution.new() == %{type: "code_execution_20260521", name: "code_execution"}
  end

  test "with cache_control" do
    assert CodeExecution.new(cache_control: Anthropic.CacheControl.ephemeral()) == %{
             type: "code_execution_20260521",
             name: "code_execution",
             cache_control: %{type: "ephemeral"}
           }
  end
end
