defmodule Anthropic.ClientTest do
  use ExUnit.Case, async: false

  alias Anthropic.Client

  describe "new/1" do
    test "builds a client from explicit opts" do
      assert %Client{api_key: "explicit-key", base_url: "https://api.anthropic.com"} =
               Client.new(api_key: "explicit-key")
    end

    test "explicit opts take precedence over Application env and system env" do
      Application.put_env(:anthropic, :api_key, "from-app-env")
      System.put_env("ANTHROPIC_API_KEY", "from-system-env")

      assert %Client{api_key: "explicit-key"} = Client.new(api_key: "explicit-key")

      Application.delete_env(:anthropic, :api_key)
      System.delete_env("ANTHROPIC_API_KEY")
    end

    test "Application env takes precedence over system env" do
      Application.put_env(:anthropic, :api_key, "from-app-env")
      System.put_env("ANTHROPIC_API_KEY", "from-system-env")

      assert %Client{api_key: "from-app-env"} = Client.new([])

      Application.delete_env(:anthropic, :api_key)
      System.delete_env("ANTHROPIC_API_KEY")
    end

    test "falls back to system env when nothing else is set" do
      previous = Application.get_env(:anthropic, :api_key)
      Application.delete_env(:anthropic, :api_key)
      System.put_env("ANTHROPIC_API_KEY", "from-system-env")

      assert %Client{api_key: "from-system-env"} = Client.new([])

      System.delete_env("ANTHROPIC_API_KEY")
      if previous, do: Application.put_env(:anthropic, :api_key, previous)
    end

    test "raises when api_key cannot be resolved" do
      previous = Application.get_env(:anthropic, :api_key)
      Application.delete_env(:anthropic, :api_key)

      assert_raise ArgumentError, ~r/api_key is required/, fn -> Client.new([]) end

      if previous, do: Application.put_env(:anthropic, :api_key, previous)
    end

    test "raises when max_retries is negative" do
      assert_raise ArgumentError, ~r/max_retries must be >= 0/, fn ->
        Client.new(api_key: "key", max_retries: -1)
      end
    end

    test "defaults" do
      client = Client.new(api_key: "key")

      assert client.base_url == "https://api.anthropic.com"
      assert client.api_version == "2023-06-01"
      assert client.max_retries == 2
      assert client.default_headers == []
    end
  end

  describe "inspect/1" do
    test "never prints the api_key" do
      client = Client.new(api_key: "sk-ant-super-secret-value")

      refute inspect(client) =~ "sk-ant-super-secret-value"
    end
  end
end
