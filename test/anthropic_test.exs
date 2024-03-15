defmodule AnthropicTest do
  use ExUnit.Case
  doctest Anthropic

  import Mox

  alias Anthropic.Messages.Request
  alias AnthropicTest.MockTool

  # Seed 396199 Gives :api_key can not be nil

  describe "new/1" do
    test "returns a Anthropic.Message.Request" do
      assert %Request{} = Anthropic.new()
    end

    test "bad opts" do
      assert_raise ArgumentError, "Config must be a valid %Anthropic.Config{}. Got: \"oi\"", fn ->
        Anthropic.new(config: "oi")
      end
    end

    test "with multiple opts" do
      assert %Anthropic.Messages.Request{
               max_tokens: 500,
               __config__: %Anthropic.Config{api_key: "new"}
             } = Anthropic.new(api_key: "new", max_tokens: 500)
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

      assert List.first(request.messages).content == [%{type: "text", text: "Message 3"}]
      assert List.first(request.messages).role == :user

      assert List.last(request.messages).content == [%{type: "text", text: "Message 1"}]
      assert List.last(request.messages).role == :user
    end

    test "appends a list of different messages" do
      request =
        Anthropic.new()
        |> Anthropic.add_user_message(["Message 1", %{type: "text", content: ["Message 2"]}])

      assert List.last(request.messages).content == [
               %{text: "Message 1", type: "text"},
               %{type: "text", content: ["Message 2"]}
             ]

      assert List.last(request.messages).role == :user
    end
  end

  describe "add_assistant_message/2" do
    test "appends new message" do
      request =
        Anthropic.new()
        |> Anthropic.add_user_message("Message 1")
        |> Anthropic.add_assistant_message("And the reply is...")

      assert List.first(request.messages).content == [
               %{type: "text", text: "And the reply is..."}
             ]

      assert List.first(request.messages).role == :assistant
    end
  end

  describe "add_message/3" do
    test "appends a single message with the specified role" do
      request =
        Anthropic.new()
        |> Anthropic.add_message(:user, "Hello")
        |> Anthropic.add_message(:assistant, "Hi there!")

      assert [
               %{role: :assistant, content: [%{type: "text", text: "Hi there!"}]},
               %{role: :user, content: [%{type: "text", text: "Hello"}]}
             ] = request.messages
    end

    test "appends multiple messages with the specified role" do
      request =
        Anthropic.new()
        |> Anthropic.add_message(:user, ["Message 1", "Message 2"])

      assert [
               %{
                 role: :user,
                 content: [%{text: "Message 1", type: "text"}, %{text: "Message 2", type: "text"}]
               }
             ] = request.messages
    end
  end

  describe "process_invocations/1" do
    test "returns the response and updated request when there are no invocations" do
      response = %Anthropic.Messages.Response{content: "Hello!", invocations: []}
      request = Anthropic.new()

      assert {:ok, %Anthropic.Messages.Response{content: "Hello!"}, request} ==
               Anthropic.process_invocations({:ok, response, request})
    end

    test "processes invocations and updates the request" do
      # 1) Imagine I have a request that has a Tool.
      request =
        Anthropic.new()
        |> Anthropic.register_tool(MockTool)

      # 2) And now Imagine I have a response that has requested a invocation
      response = %Anthropic.Messages.Response{
        content: [
          %{
            text:
              "<function_calls><invoke><tool_name>AnthropicTest.MockTool</tool_name><parameters><param1>value1</param1><param2>value2</param2></parameters></invoke></function_calls>",
            type: "text"
          }
        ],
        invocations: [{MockTool, [param1: "value1", param2: "value2"]}]
      }

      # 4) The server receives the results and reply with: Chad: Ok.
      Anthropic.MockHTTPClient
      |> expect(:request, fn _req, _client, _opts ->
        {:ok,
         %Finch.Response{
           status: 200,
           body:
             "{\"content\": [{\"text\": \"Chad: OK.\", \"type\": \"text\"}\n  ],\n  \"id\": \"msg_013Zva2CMHLNnXjNJJKqJ2EF\",\n  \"model\": \"claude-3-opus-20240229\",\n  \"role\": \"assistant\",\n  \"stop_reason\": \"end_turn\",\n  \"stop_sequence\": null,\n  \"type\": \"message\",\n  \"usage\": {\"input_tokens\": 10,\"output_tokens\": 25\n  }\n}\n"
         }}
      end)
      |> expect(:build, fn method, url, headers, body, opts ->
        Finch.build(method, url, headers, body, opts)
      end)

      # 3) When I process the invocation, the sistem will return an empty invocation list, and will match the mocked response from the server.
      {:ok, updated_response, _updated_request} =
        Anthropic.process_invocations({:ok, response, request})

      assert [] == updated_response.invocations
      assert Enum.any?(updated_response.content, fn %{"text" => text} -> text =~ "Chad: OK." end)
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

    test "passes forward an Error" do
      request = Anthropic.new(model: "process_invocations/1 passes forward an Error")
      response = {:error, %{reason: :unknown}, request}

      assert {:error, %{reason: :unknown}, %Anthropic.Messages.Request{}} =
               Anthropic.process_invocations(response)
    end
  end

  describe "add_image/2" do
    test "from valid path" do
      elem =
        Anthropic.new()
        |> Anthropic.add_user_image({:path, "test/images/image.png"})
        |> then(fn req -> req.messages end)
        |> List.first()

      assert %{
               role: :user,
               content: [
                 %{
                   type: "image",
                   source: %{data: _data, type: "base64", media_type: "image/png"}
                 }
               ]
             } = elem
    end
  end

  describe "request_next_message/1" do
    # test "requires api_key" do
    #   api_key = Anthropic.Config.get(:api_key)

    #   assert_raise(ArgumentError, fn ->
    #     Anthropic.new(Anthropic.Config.reset(api_key: nil))
    #     |> Anthropic.add_user_message("Good morning")
    #     |> Anthropic.request_next_message()
    #   end)

    #   Anthropic.Config.reset(api_key: api_key)
    # end

    test "valid response" do
      request = Anthropic.new(model: "request_next_message_valid_response")

      Anthropic.MockHTTPClient
      |> expect(:request, fn _req, _client, _opts ->
        {:ok,
         %Finch.Response{
           status: 200,
           body:
             "{\"content\": [{\"text\": \"Oh Hello request_next_message/1 with valid response.\", \"type\": \"text\"}\n  ],\n  \"id\": \"msg_013Zva2CMHLNnXjNJJKqJ2EF\",\n  \"model\": \"claude-3-opus-20240229\",\n  \"role\": \"assistant\",\n  \"stop_reason\": \"end_turn\",\n  \"stop_sequence\": null,\n  \"type\": \"message\",\n  \"usage\": {\"input_tokens\": 10,\"output_tokens\": 25\n  }\n}\n"
         }}
      end)
      |> expect(:build, fn method, url, headers, body, opts ->
        Finch.build(method, url, headers, body, opts)
      end)

      assert {:ok, _, _} = Anthropic.request_next_message(request, [])
    end

    test "server error response" do
      request = Anthropic.new(model: "request_next_message_server error response")

      Anthropic.MockHTTPClient
      |> expect(:request, fn _req, _client, _opts ->
        {:ok,
         %Finch.Response{
           status: 400,
           body: Jason.encode!(%{type: "error", message: "Authentication Error"})
         }}
      end)
      |> expect(:build, fn method, url, headers, body, opts ->
        Finch.build(method, url, headers, body, opts)
      end)

      assert {:error, _, _} = Anthropic.request_next_message(request, [])
    end

    test "network error response" do
      request = Anthropic.new(model: "request_next_message_network error response")

      Anthropic.MockHTTPClient
      |> expect(:request, fn _req, _client, _opts ->
        {:error, %Finch.Error{reason: "Network Error"}}
      end)
      |> expect(:build, fn method, url, headers, body, opts ->
        Finch.build(method, url, headers, body, opts)
      end)

      assert {:error, %Finch.Error{}, _} = Anthropic.request_next_message(request, [])
    end

    test "Jason decode error response" do
      request = Anthropic.new(model: "request_next_message_jason decode error response")

      Anthropic.MockHTTPClient
      |> expect(:request, fn _req, _client, _opts ->
        {:error, %Jason.DecodeError{}}
      end)
      |> expect(:build, fn method, url, headers, body, opts ->
        Finch.build(method, url, headers, body, opts)
      end)

      assert {:error, %Jason.DecodeError{}, _} = Anthropic.request_next_message(request, [])
    end

    test "Catch all error response" do
      request = Anthropic.new(model: "request_next_message_jason catch all error")

      Anthropic.MockHTTPClient
      |> expect(:request, fn _req, _client, _opts ->
        {:error, "Unknown error"}
      end)
      |> expect(:build, fn method, url, headers, body, opts ->
        Finch.build(method, url, headers, body, opts)
      end)

      assert {:error, "Unknown error", _} = Anthropic.request_next_message(request, [])
    end
  end

  describe "register_tool/2" do
    setup do
      request = Anthropic.new()
      {:ok, request: request}
    end

    test "successfully registers a tool module", %{request: request} do
      assert Anthropic.register_tool(request, MockTool)
             |> then(& &1.tools)
             |> MapSet.member?(MockTool)
    end

    test "raises an error for unregistered modules", %{request: request} do
      assert_raise ArgumentError,
                   "Module Elixir.UnloadedMockTool is not loaded. Please use module full name (MyApp.AnthropicTool)",
                   fn ->
                     Anthropic.register_tool(request, UnloadedMockTool)
                   end
    end
  end

  describe "remove_tool/2" do
    setup do
      request = Anthropic.new()
      {:ok, request: request}
    end

    test "successfully removes a tool module", %{request: request} do
      request =
        Anthropic.register_tool(request, MockTool)

      assert MapSet.member?(request.tools, MockTool)

      assert !(Anthropic.remove_tool(request, MockTool)
               |> then(& &1.tools)
               |> MapSet.member?(MockTool))
    end
  end
end
