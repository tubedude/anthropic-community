defmodule Anthropic.Tools.WebFetchTest do
  use ExUnit.Case, async: true

  alias Anthropic.Tools.WebFetch

  test "defaults to the latest version and just name/type" do
    assert WebFetch.new() == %{type: "web_fetch_20260318", name: "web_fetch"}
  end

  test "with options" do
    assert WebFetch.new(max_uses: 2, citations: %{enabled: true}) == %{
             type: "web_fetch_20260318",
             name: "web_fetch",
             max_uses: 2,
             citations: %{enabled: true}
           }
  end

  test "raises on an invalid option" do
    assert_raise NimbleOptions.ValidationError, fn -> WebFetch.new(unknown_opt: true) end
  end
end
