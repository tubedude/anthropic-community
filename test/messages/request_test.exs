defmodule Anthropic.Messages.RequestTest do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  describe "create/1" do
    test "no options" do
      assert %Anthropic.Messages.Request{model: "claude-3-haiku-20240307"} =
               Anthropic.Messages.Request.create()
    end

    test "with options" do
      assert %Anthropic.Messages.Request{max_tokens: 100} =
               Anthropic.Messages.Request.create(max_tokens: 100)

      assert %Anthropic.Messages.Request{top_k: 2} = Anthropic.Messages.Request.create(top_k: 2)
    end

    test "options precedent" do
      Application.put_env(:anthropic, :model, "in_env")

      assert %Anthropic.Messages.Request{model: "model"} =
               Anthropic.Messages.Request.create(model: "model")

      assert %Anthropic.Messages.Request{model: "in_env"} =
               Anthropic.Messages.Request.create()

      Application.put_env(:anthropic, :model, "claude-3-haiku-20240307")
    end
  end

  describe "send_request/2" do
    setup do
      {:ok, [request: Anthropic.new()]}
    end

    test "with valid options returns a response", %{request: request} do
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

    test "with bad json body", %{request: request} do
      bad_body = " text\": \"I've tried \" "

      Anthropic.MockHTTPClient
      |> expect(:request, fn _req, _client, _opts ->
        {:ok, %Finch.Response{status: 200, body: bad_body}}
      end)
      |> expect(:build, fn method, url, headers, body, opts ->
        Finch.build(method, url, headers, body, opts)
      end)

      assert {:error,
              %Jason.DecodeError{
                __exception__: true,
                data: " text\": \"I've tried \" ",
                position: 1,
                token: nil
              }} =
               Anthropic.Messages.Request.send_request(request, [])
    end

    test "bad everything", %{request: request} do
      Anthropic.MockHTTPClient
      |> expect(:request, fn _req, _client, _opts ->
        {:error, :very_bad}
      end)
      |> expect(:build, fn method, url, headers, body, opts ->
        Finch.build(method, url, headers, body, opts)
      end)

      assert {:error, :very_bad} =
               Anthropic.Messages.Request.send_request(request, [])
    end
  end
end
