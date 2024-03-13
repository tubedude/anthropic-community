defmodule Anthropic.Messages.RequestTest do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  test "send_request/2 sends a request and returns a response" do
    request = Anthropic.new()

    Anthropic.MockHTTPClient
    |> expect(:request, fn _req, _client, _opts ->
      {:ok,
       %Finch.Response{
         status: 200,
         body:
           "{\n  \"content\": [\n    {\n      \"text\": \"Hi! My name is Claude.\",\n      \"type\": \"text\"\n    }\n  ],\n  \"id\": \"msg_013Zva2CMHLNnXjNJJKqJ2EF\",\n  \"model\": \"claude-3-opus-20240229\",\n  \"role\": \"assistant\",\n  \"stop_reason\": \"end_turn\",\n  \"stop_sequence\": null,\n  \"type\": \"message\",\n  \"usage\": {\n    \"input_tokens\": 10,\n    \"output_tokens\": 25\n  }\n}\n"
       }}
    end)
    |> expect(:build, fn method, url, headers, body, opts ->
      Finch.build(method, url, headers, body, opts)
    end)

    assert {:ok, %Anthropic.Messages.Response{}} =
             Anthropic.Messages.Request.send_request(request, [])
  end
end
