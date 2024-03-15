defmodule Anthropic.ConfigTest do
  use ExUnit.Case, async: false
  doctest Anthropic.Config

  alias Anthropic.Config

  describe "create/0 " do
    test "returns current opts" do
      assert %Anthropic.Config{} = Config.create([])
    end

    test "Environment takes precedence to default" do
      assert %Anthropic.Config{api_key: "Loaded_for_tests"} = Config.create([])
      Application.put_env(:anthropic, :api_key, "application.put_env.api_key")
      assert %Anthropic.Config{api_key: "application.put_env.api_key"} = Config.create([])

      assert %Anthropic.Config{api_key: "just_in_api_key"} =
               Config.create(api_key: "just_in_api_key")

      assert_raise ArgumentError, ":api_key must be a String.t(). Got: nil", fn -> %Anthropic.Config{} = Config.create(api_key: nil) end
      assert_raise ArgumentError, ":api_key must be a String.t(). Got: 123", fn -> %Anthropic.Config{} = Config.create(api_key: 123) end
    end
  end

  describe "validations" do
    test "api_key" do
      assert Anthropic.Config.validate_config(api_key: "good") == [api_key: "good"]

      assert_raise(ArgumentError, ":api_key must be a String.t(). Got: nil", fn ->
        Anthropic.Config.validate_config(api_key: nil)
      end)
    end

    test "api_url" do
      assert_raise(ArgumentError, ":api_url must be a String.t(). Got: nil", fn ->
        Anthropic.Config.validate_config(api_url: nil)
      end)
    end

    test "max_tokens" do
      assert Anthropic.Config.validate_config(max_tokens: 10) == [max_tokens: 10]

      assert_raise(ArgumentError, "Invalid max_tokens value, must be a positive integer.", fn ->
        Anthropic.Config.validate_config(max_tokens: "10")
      end)

      assert_raise(ArgumentError, "Invalid max_tokens value, must be a positive integer.", fn ->
        Anthropic.Config.validate_config(max_tokens: -10)
      end)
    end

    test "temperature" do
      assert Anthropic.Config.validate_config(temperature: 0.5) == [temperature: 0.5]

      assert_raise(
        ArgumentError,
        "Invalid temperature value, must be a float between 0.0 and 1.0.",
        fn -> Anthropic.Config.validate_config(temperature: "10") end
      )

      assert_raise(
        ArgumentError,
        "Invalid temperature value, must be a float between 0.0 and 1.0.",
        fn -> Anthropic.Config.validate_config(temperature: -10) end
      )
    end

    test "top_p" do
      assert Anthropic.Config.validate_config(top_p: 0.5) == [top_p: 0.5]

      assert_raise(
        ArgumentError,
        "Invalid top_p value, must be a float between 0.0 and 1.0.",
        fn -> Anthropic.Config.validate_config(top_p: "10") end
      )

      assert_raise(
        ArgumentError,
        "Invalid top_p value, must be a float between 0.0 and 1.0.",
        fn -> Anthropic.Config.validate_config(top_p: -10) end
      )
    end
  end

  describe "Enumerable implementation" do
    test "count" do
      assert Enum.count(%Anthropic.Config{}) == 3
    end

    test "member?" do
      assert Enum.member?(%Anthropic.Config{}, :api_key)
    end

    test "reduce function correctly handles :halted" do
      config = %Config{api_key: "test-model", api_url: "url"}
      reducer = fn _x, acc -> {:cont, [(& &1) | acc]} end

      assert [] == Enumerable.reduce(config, {:halt, []}, reducer) |> elem(1) |> :lists.reverse()

      assert [] ==
               Enumerable.reduce(config, {:suspend, []}, reducer) |> elem(1) |> :lists.reverse()

      assert {:error, Enumerable.Anthropic.Config} == Enumerable.slice(config)
      assert Enum.reduce(config, fn _e, acc -> acc end) == {:api_key, "test-model"}
    end
  end
end
