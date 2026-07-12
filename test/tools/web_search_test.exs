defmodule Anthropic.Tools.WebSearchTest do
  use ExUnit.Case, async: true

  alias Anthropic.Tools.WebSearch

  test "defaults to the latest version and just name/type" do
    assert WebSearch.new() == %{type: "web_search_20260318", name: "web_search"}
  end

  test "with options" do
    assert WebSearch.new(max_uses: 3, allowed_domains: ["wikipedia.org"]) == %{
             type: "web_search_20260318",
             name: "web_search",
             max_uses: 3,
             allowed_domains: ["wikipedia.org"]
           }
  end

  test "version can be overridden" do
    assert %{type: "web_search_20250305"} = WebSearch.new(version: "web_search_20250305")
  end

  test "raises on an invalid option" do
    assert_raise NimbleOptions.ValidationError, fn -> WebSearch.new(max_uses: -1) end
  end

  test "the returned map passes straight through Anthropic.Tools.to_param/1" do
    tool = WebSearch.new(max_uses: 3)
    assert Anthropic.Tools.to_param(tool) == tool
  end
end
