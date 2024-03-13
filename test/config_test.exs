defmodule Anthropic.ConfigTest do
  use ExUnit.Case, async: false
  doctest Anthropic.Config

  alias Anthropic.Config

  test "opts/0 returns current opts" do
    assert %Anthropic.Config{} = Config.opts()
  end

  describe "validations" do

    @tag :capture_log
    test "top_p" do
      Process.flag :trap_exit, true
      {:ok, config} = GenServer.start_link(Anthropic.Config, [], name: :new)

      catch_exit do
        GenServer.call(config, {:reset, [top_p: 1.1]})
      end

      assert_received({:EXIT, ^config, {%ArgumentError{message: "Invalid top_p value, must be a float between 0.0 and 1.0."}, _}})
    end

    test "valid top_p" do
      assert %Anthropic.Config{top_p: 0.9} = Anthropic.Config.reset(top_p: 0.9)
    end

    @tag :capture_log
    test "max_tokens" do
      Process.flag :trap_exit, true
      {:ok, config} = GenServer.start_link(Anthropic.Config, [], name: :new)

      catch_exit do
        GenServer.call(config, {:reset, [max_tokens: -10]})
      end

      assert_received({:EXIT, ^config, {%ArgumentError{message: "Invalid max_tokens value, must be a positive integer."}, _}})
    end

    @tag :capture_log
    test "temperature" do
      Process.flag :trap_exit, true
      {:ok, config} = GenServer.start_link(Anthropic.Config, [], name: :new)

      catch_exit do
        GenServer.call(config, {:reset, [temperature: 1.1]})
      end

      assert_received({:EXIT, ^config, {%ArgumentError{message: "Invalid temperature value, must be a float between 0.0 and 1.0."}, _}})
    end
  end

  describe "reset/1" do
    test "will rewrite runtime options" do
      Config.reset(temperature: 0.3)
      assert 0.3 == Config.opts().temperature
      Config.reset(temperature: 1.0)
    end

    test "will rewrite api_key runtime options" do
      Config.reset(api_key: "some other key")
      assert "some other key" == Config.opts().api_key
      Config.reset(api_key: "Loaded_for_tests")
    end

    # @tag :capture_log
    # test "will raise on invalid options" do
    #   Process.flag :trap_exit, true

    #   catch_exit do
    #     Config.reset(temperature: :hot)
    #   end

    #   Config.reset(temperature: :hot)

    # assert_receive({:DOWN, _, _},100)
    # assert_received({:EXIT, _, {%ArgumentError{message: "Invalid temperature value, must be a float between 0.0 and 1.0"}, _}})

    # end
  end

  describe "Enumerable implementation" do
    test "count" do
      assert Enum.count(%Anthropic.Config{}) == 8
    end

    test "member?" do
      assert Enum.member?(%Anthropic.Config{}, :api_key)
    end

    test "reduce function correctly handles :halted" do
      config = %Config{model: "test-model", max_tokens: 500, temperature: 0.5}
      reducer = fn _x, acc -> {:cont, [(& &1) | acc]} end
      assert [] == Enumerable.reduce(config, {:halt, []}, reducer) |> elem(1) |> :lists.reverse()

      assert [] ==
               Enumerable.reduce(config, {:suspend, []}, reducer) |> elem(1) |> :lists.reverse()

      assert {:error, Enumerable.Anthropic.Config} == Enumerable.slice(config)
    end
  end
end
