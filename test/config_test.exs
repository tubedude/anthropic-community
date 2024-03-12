defmodule ConfigTest do
  use ExUnit.Case, async: false
  doctest Anthropic

  alias Anthropic.Config

  test "opts/0 returns current opts" do
    assert %Anthropic.Config{} = Config.opts()
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
end
