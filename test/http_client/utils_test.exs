defmodule Anthropic.HttpClient.UtilsTest do
  use ExUnit.Case, async: true

  alias Anthropic.HttpClient.Utils

  describe "build_header/1" do
    test "build_header includes user-agent" do
      config = %Anthropic.Config{api_key: "test-key", anthropic_version: "2023-01"}
      headers = Utils.build_header(config)

      assert Enum.any?(headers, fn {key, val} ->
               key == "user-agent" and String.starts_with?(val, "anthropic-community-elixir/")
             end)
    end
  end
end
