defmodule Anthropic.CacheControlTest do
  use ExUnit.Case, async: true

  alias Anthropic.CacheControl

  describe "ephemeral/1" do
    test "with no opts" do
      assert CacheControl.ephemeral() == %{type: "ephemeral"}
    end

    test "with a valid ttl" do
      assert CacheControl.ephemeral(ttl: "1h") == %{type: "ephemeral", ttl: "1h"}
      assert CacheControl.ephemeral(ttl: "5m") == %{type: "ephemeral", ttl: "5m"}
    end

    test "raises on an invalid ttl" do
      assert_raise NimbleOptions.ValidationError, fn ->
        CacheControl.ephemeral(ttl: "1d")
      end
    end
  end
end
