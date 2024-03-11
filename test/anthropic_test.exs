defmodule AnthropicTest do
  use ExUnit.Case
  doctest Anthropic

  alias Anthropic.Messages.Request
  alias Anthropic.Config

  test "new/1 returns a Anthropic.Message.Request" do
    assert %Request{} = Anthropic.new()
  end

  test "can override a config on runtime without altering GenServer" do
    assert %Request{temperature: 0.5} = Anthropic.new(temperature: 0.5)
    assert %Request{max_tokens: 100} = Anthropic.new(max_tokens: 100)
    assert %Config{temperature: 1.0} = Anthropic.Config.opts()
    assert %Config{max_tokens: 1000} = Anthropic.Config.opts()
  end

  describe "add_system_message/2" do
    test "adds system message" do
      request = Anthropic.new()

      assert %Request{system: "you are a helpful assistant"} =
               Anthropic.add_system_message(request, "you are a helpful assistant")
    end

    test "raises if message is invalid" do
      request = Anthropic.new()

      assert_raise ArgumentError, fn ->
        Anthropic.add_system_message(request, 123)
      end
    end
  end

  describe "add_user_message/2" do
    test "appends new message" do
      request =
        Anthropic.new()
        |> Anthropic.add_user_message("Message 1")
        |> Anthropic.add_user_message("Message 2")
        |> Anthropic.add_user_message("Message 3")

      assert List.first(request.messages).content == "Message 1"
      assert List.first(request.messages).role == :user

      assert List.last(request.messages).content == "Message 3"
      assert List.last(request.messages).role == :user
    end
  end

  describe "add_assistant_message/2" do
    test "appends new message" do
      request =
        Anthropic.new()
        |> Anthropic.add_user_message("Message 1")
        |> Anthropic.add_assistant_message("And the reply is...")

      assert List.last(request.messages).content == "And the reply is..."
      assert List.last(request.messages).role == :assistant
    end
  end
end
