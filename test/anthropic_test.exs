defmodule AnthropicTest do
  use ExUnit.Case
  doctest Anthropic

  alias Anthropic.Messages.Request
  alias Anthropic.Config
  alias AnthropicTest.MockTool

  describe "new/1" do
    test "returns a Anthropic.Message.Request" do
      assert %Request{} = Anthropic.new()
    end

    test "can override a config on runtime without altering GenServer" do
      assert %Request{temperature: 0.5} = Anthropic.new(temperature: 0.5)
      assert %Request{max_tokens: 100} = Anthropic.new(max_tokens: 100)
      assert %Config{temperature: 1.0} = Anthropic.Config.opts()
      assert %Config{max_tokens: 1000} = Anthropic.Config.opts()
    end
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

  describe "add_message/3" do
    test "appends a single message with the specified role" do
      request =
        Anthropic.new()
        |> Anthropic.add_message(:user, "Hello")
        |> Anthropic.add_message(:assistant, "Hi there!")

      assert [
               %{role: :user, content: "Hello"},
               %{role: :assistant, content: "Hi there!"}
             ] = request.messages
    end

    test "appends multiple messages with the specified role" do
      request =
        Anthropic.new()
        |> Anthropic.add_message(:user, ["Message 1", "Message 2"])

      assert [
               %{role: :user, content: "Message 1"},
               %{role: :user, content: "Message 2"}
             ] = request.messages
    end
  end

  describe "process_invocations/1" do
    test "returns the response and updated request when there are no invocations" do
      response = %Anthropic.Messages.Response{content: "Hello!", invocations: []}
      request = Anthropic.new()

      assert {:ok, response, request} == Anthropic.process_invocations({:ok, response, request})
    end

    # TODO implement Mox
    @tag :skip
    test "processes invocations and updates the request" do
      response = %Anthropic.Messages.Response{
        content: "Here are the results:",
        invocations: [{MockTool, ["value1"]}]
      }

      request =
        Anthropic.new()
        |> Anthropic.register_tool(MockTool)

      {:ok, updated_response, updated_request} =
        Anthropic.process_invocations({:ok, response, request})

      assert updated_response.content =~ "MockTool result"
      assert updated_request.messages == [%{role: :user, content: "MockTool result"}]
    end

    test "returns an error when a tool is not found" do
      response = %Anthropic.Messages.Response{
        content: "Invoking a missing tool:",
        invocations: [{"MissingTool", %{}}]
      }

      request = Anthropic.new()

      assert_raise ArgumentError, "Invocation error: Tool MissingTool not found", fn ->
        Anthropic.process_invocations({:ok, response, request})
      end
    end
  end

  describe "add_image/2" do
    test "from valid path" do
      elem =
        Anthropic.new()
        |> Anthropic.add_image({:path, "test/images/image.png"})
        |> then(fn req -> req.messages end)
        |> List.first()

      assert %{
               role: :user,
               content: %{
                 type: "image",
                 source: %{data: _data, type: "base64", media_type: "image/png"}
               }
             } = elem
    end
  end

  describe "request_next_message/1" do
    test "requires api_key" do
      Anthropic.Config.reset(api_key: nil)

      assert_raise(ArgumentError, fn ->
        Anthropic.new(Anthropic.Config.reset(api_key: nil))
        |> Anthropic.add_user_message("Good morning")
        |> Anthropic.request_next_message()
      end)
    end
  end

  describe "register_tool/2" do
    setup do
      request = Anthropic.new()
      {:ok, request: request}
    end

    test "successfully registers a tool module", %{request: request} do
      assert %Request{tools: [MockTool]} = Anthropic.register_tool(request, MockTool)
    end

    test "does not duplicate tool registration", %{request: request} do
      request = Anthropic.register_tool(request, MockTool)
      assert %Request{tools: [MockTool]} = Anthropic.register_tool(request, MockTool)
    end

    test "raises an error for unregistered modules", %{request: request} do
      assert_raise ArgumentError,
                   "Module Elixir.UnloadedMockTool is not loaded. Please use module full name (MyApp.AnthropicTool)",
                   fn ->
                     Anthropic.register_tool(request, UnloadedMockTool)
                   end
    end
  end
end
