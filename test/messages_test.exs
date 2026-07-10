defmodule Anthropic.MessagesTest do
  use ExUnit.Case
  import Mox

  alias Anthropic.{Client, Error, Messages}
  alias Anthropic.Messages.Content.Text

  setup :verify_on_exit!

  setup do
    {:ok, client: Client.new(api_key: "test-key")}
  end

  defp success_body(text \\ "Hi! My name is Claude.") do
    Jason.encode!(%{
      "id" => "msg_013Zva2CMHLNnXjNJJKqJ2EF",
      "type" => "message",
      "role" => "assistant",
      "content" => [%{"type" => "text", "text" => text}],
      "model" => "claude-opus-4-8",
      "stop_reason" => "end_turn",
      "stop_sequence" => nil,
      "usage" => %{"input_tokens" => 10, "output_tokens" => 25}
    })
  end

  describe "create/2 happy path" do
    test "returns a typed Message", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn _req, _pool, _opts ->
        {:ok, %Finch.Response{status: 200, body: success_body(), headers: []}}
      end)

      assert {:ok, %Anthropic.Messages.Message{content: [%Text{text: "Hi! My name is Claude."}]}} =
               Messages.create(client,
                 model: "claude-opus-4-8",
                 max_tokens: 100,
                 messages: [%{role: "user", content: "Hi"}]
               )
    end
  end

  describe "create/2 validation" do
    test "returns a validation error without making a request when max_tokens is missing", %{
      client: client
    } do
      assert {:error, %Error{type: :validation_error, message: message}} =
               Messages.create(client,
                 model: "claude-opus-4-8",
                 messages: [%{role: "user", content: "Hi"}]
               )

      assert message =~ "max_tokens"
    end

    test "returns a validation error when messages is empty", %{client: client} do
      assert {:error, %Error{type: :validation_error}} =
               Messages.create(client, model: "claude-opus-4-8", max_tokens: 100, messages: [])
    end
  end

  describe "create/2 error mapping" do
    test "4xx errors are not retried", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, 1, fn _req, _pool, _opts ->
        {:ok,
         %Finch.Response{
           status: 400,
           body:
             Jason.encode!(%{
               "type" => "error",
               "error" => %{"type" => "invalid_request_error", "message" => "bad request"}
             }),
           headers: []
         }}
      end)

      assert {:error, %Error{type: :invalid_request_error, status: 400}} =
               Messages.create(client,
                 model: "claude-opus-4-8",
                 max_tokens: 100,
                 messages: [%{role: "user", content: "Hi"}]
               )
    end

    test "a connection error is mapped to :connection_error", %{client: client} do
      client = %{client | max_retries: 0}

      Anthropic.MockHTTPAdapter
      |> expect(:request, 1, fn _req, _pool, _opts ->
        {:error, %Mint.TransportError{reason: :closed}}
      end)

      assert {:error, %Error{type: :connection_error}} =
               Messages.create(client,
                 model: "claude-opus-4-8",
                 max_tokens: 100,
                 messages: [%{role: "user", content: "Hi"}]
               )
    end
  end

  describe "create/2 retry behavior" do
    test "retries a 429 then succeeds", %{client: client} do
      client = %{client | max_retries: 2}

      Anthropic.MockHTTPAdapter
      |> expect(:request, 1, fn _req, _pool, _opts ->
        {:ok,
         %Finch.Response{
           status: 429,
           body:
             Jason.encode!(%{
               "type" => "error",
               "error" => %{"type" => "rate_limit_error", "message" => "slow down"}
             }),
           headers: [{"retry-after", "0"}]
         }}
      end)
      |> expect(:request, 1, fn _req, _pool, _opts ->
        {:ok, %Finch.Response{status: 200, body: success_body(), headers: []}}
      end)

      assert {:ok, %Anthropic.Messages.Message{}} =
               Messages.create(client,
                 model: "claude-opus-4-8",
                 max_tokens: 100,
                 messages: [%{role: "user", content: "Hi"}]
               )
    end

    test "gives up after max_retries and returns the last error", %{client: client} do
      client = %{client | max_retries: 1}

      Anthropic.MockHTTPAdapter
      |> expect(:request, 2, fn _req, _pool, _opts ->
        {:ok,
         %Finch.Response{
           status: 500,
           body:
             Jason.encode!(%{
               "type" => "error",
               "error" => %{"type" => "api_error", "message" => "boom"}
             }),
           headers: []
         }}
      end)

      assert {:error, %Error{type: :api_error, status: 500}} =
               Messages.create(client,
                 model: "claude-opus-4-8",
                 max_tokens: 100,
                 messages: [%{role: "user", content: "Hi"}]
               )
    end
  end

  describe "create!/2" do
    test "returns the message directly on success", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn _req, _pool, _opts ->
        {:ok, %Finch.Response{status: 200, body: success_body(), headers: []}}
      end)

      assert %Anthropic.Messages.Message{} =
               Messages.create!(client,
                 model: "claude-opus-4-8",
                 max_tokens: 100,
                 messages: [%{role: "user", content: "Hi"}]
               )
    end

    test "raises Anthropic.Error on failure", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, 1, fn _req, _pool, _opts ->
        {:ok,
         %Finch.Response{
           status: 401,
           body:
             Jason.encode!(%{
               "type" => "error",
               "error" => %{"type" => "authentication_error", "message" => "bad key"}
             }),
           headers: []
         }}
      end)

      assert_raise Error, "[authentication_error (HTTP 401)] bad key", fn ->
        Messages.create!(client,
          model: "claude-opus-4-8",
          max_tokens: 100,
          messages: [%{role: "user", content: "Hi"}]
        )
      end
    end
  end

  describe "count_tokens/2" do
    test "returns the input token count without requiring max_tokens", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.path == "/v1/messages/count_tokens"
        body = Jason.decode!(req.body)
        refute Map.has_key?(body, "max_tokens")
        refute Map.has_key?(body, "stream")

        {:ok,
         %Finch.Response{status: 200, body: Jason.encode!(%{"input_tokens" => 15}), headers: []}}
      end)

      assert {:ok, %{input_tokens: 15}} =
               Messages.count_tokens(client,
                 model: "claude-opus-4-8",
                 messages: [%{role: "user", content: "Hi"}]
               )
    end

    test "returns a validation error when messages is missing", %{client: client} do
      assert {:error, %Error{type: :validation_error, message: message}} =
               Messages.count_tokens(client, model: "claude-opus-4-8")

      assert message =~ "messages"
    end
  end
end
