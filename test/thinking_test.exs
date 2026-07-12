defmodule Anthropic.ThinkingTest do
  use ExUnit.Case, async: true

  alias Anthropic.Thinking

  describe "enabled/1" do
    test "with just budget_tokens" do
      assert Thinking.enabled(budget_tokens: 10_000) == %{type: "enabled", budget_tokens: 10_000}
    end

    test "with display" do
      assert Thinking.enabled(budget_tokens: 10_000, display: "omitted") ==
               %{type: "enabled", budget_tokens: 10_000, display: "omitted"}
    end

    test "raises when budget_tokens is missing" do
      assert_raise NimbleOptions.ValidationError, fn -> Thinking.enabled([]) end
    end

    test "raises when budget_tokens is not a positive integer" do
      assert_raise NimbleOptions.ValidationError, fn -> Thinking.enabled(budget_tokens: -1) end
    end

    test "raises on an invalid display value" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Thinking.enabled(budget_tokens: 10_000, display: "verbose")
      end
    end
  end

  describe "adaptive/1" do
    test "with no opts" do
      assert Thinking.adaptive() == %{type: "adaptive"}
    end

    test "with display" do
      assert Thinking.adaptive(display: "summarized") == %{
               type: "adaptive",
               display: "summarized"
             }
    end
  end

  describe "disabled/0" do
    test "returns the disabled shape" do
      assert Thinking.disabled() == %{type: "disabled"}
    end
  end
end
