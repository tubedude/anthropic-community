defmodule Anthropic.Messages.RequestTest do
  use ExUnit.Case, async: true

  alias Anthropic.Client
  alias Anthropic.Messages.Request
  alias Anthropic.Messages.Content.Image

  setup do
    {:ok, client: Client.new(api_key: "test-key")}
  end

  describe "build/3" do
    test "builds valid params", %{client: client} do
      assert {:ok, params} =
               Request.build(
                 client,
                 [
                   model: "claude-opus-4-8",
                   max_tokens: 100,
                   messages: [%{role: "user", content: "Hi"}]
                 ],
                 stream: false
               )

      assert params.model == "claude-opus-4-8"
      assert params.max_tokens == 100
      assert params.stream == false
    end

    test "uses client.default_model when :model is omitted", %{client: client} do
      client = %{client | default_model: "claude-opus-4-8"}

      assert {:ok, %{model: "claude-opus-4-8"}} =
               Request.build(
                 client,
                 [max_tokens: 100, messages: [%{role: "user", content: "Hi"}]],
                 stream: false
               )
    end

    test "sets stream: true when requested", %{client: client} do
      assert {:ok, %{stream: true}} =
               Request.build(
                 client,
                 [
                   model: "claude-opus-4-8",
                   max_tokens: 100,
                   messages: [%{role: "user", content: "Hi"}]
                 ],
                 stream: true
               )
    end

    test "errors when model is missing", %{client: client} do
      assert {:error, %Anthropic.Error{type: :validation_error, message: message}} =
               Request.build(
                 client,
                 [max_tokens: 100, messages: [%{role: "user", content: "Hi"}]],
                 stream: false
               )

      assert message =~ "model"
    end

    test "errors when max_tokens is missing", %{client: client} do
      assert {:error, %Anthropic.Error{type: :validation_error, message: message}} =
               Request.build(
                 client,
                 [model: "claude-opus-4-8", messages: [%{role: "user", content: "Hi"}]],
                 stream: false
               )

      assert message =~ "max_tokens"
    end

    test "errors when max_tokens is not a positive integer", %{client: client} do
      assert {:error, %Anthropic.Error{type: :validation_error}} =
               Request.build(
                 client,
                 [
                   model: "claude-opus-4-8",
                   max_tokens: 0,
                   messages: [%{role: "user", content: "Hi"}]
                 ],
                 stream: false
               )
    end

    test "errors when messages is missing or empty", %{client: client} do
      assert {:error, %Anthropic.Error{type: :validation_error, message: message}} =
               Request.build(client, [model: "claude-opus-4-8", max_tokens: 100], stream: false)

      assert message =~ "messages"

      assert {:error, %Anthropic.Error{type: :validation_error}} =
               Request.build(client, [model: "claude-opus-4-8", max_tokens: 100, messages: []],
                 stream: false
               )
    end

    test "normalizes typed content-block structs inside message content into wire maps", %{
      client: client
    } do
      {:ok, image} = Image.process_image("test/images/image.png", :path)

      assert {:ok, params} =
               Request.build(
                 client,
                 [
                   model: "claude-opus-4-8",
                   max_tokens: 100,
                   messages: [
                     %{role: "user", content: [image, %{type: "text", text: "What's this?"}]}
                   ]
                 ],
                 stream: false
               )

      assert [
               %{type: "image", source: %{type: "base64", media_type: "image/png"}},
               %{type: "text", text: "What's this?"}
             ] =
               Enum.at(params.messages, 0).content
    end

    test "normalizes a Document content-block struct inside message content", %{client: client} do
      doc = Anthropic.Messages.Content.Document.from_url("https://example.com/report.pdf")

      assert {:ok, params} =
               Request.build(
                 client,
                 [
                   model: "claude-opus-4-8",
                   max_tokens: 100,
                   messages: [
                     %{role: "user", content: [doc, %{type: "text", text: "Summarize."}]}
                   ]
                 ],
                 stream: false
               )

      assert [
               %{type: "document", source: %{type: "url", url: "https://example.com/report.pdf"}},
               %{type: "text", text: "Summarize."}
             ] =
               Enum.at(params.messages, 0).content
    end

    test "drops nil-valued keys from the final params", %{client: client} do
      assert {:ok, params} =
               Request.build(
                 client,
                 [
                   model: "claude-opus-4-8",
                   max_tokens: 100,
                   messages: [%{role: "user", content: "Hi"}]
                 ],
                 stream: false
               )

      refute Map.has_key?(params, :system)
      refute Map.has_key?(params, :tools)
    end

    test "passes a :thinking option straight through to the wire params", %{client: client} do
      assert {:ok, %{thinking: %{type: "enabled", budget_tokens: 10_000}}} =
               Request.build(
                 client,
                 [
                   model: "claude-opus-4-8",
                   max_tokens: 100,
                   messages: [%{role: "user", content: "Hi"}],
                   thinking: Anthropic.Thinking.enabled(budget_tokens: 10_000)
                 ],
                 stream: false
               )
    end

    test "passes an :output_config option straight through to the wire params", %{client: client} do
      output_config = Anthropic.OutputConfig.json_schema(%{"type" => "object"}, effort: "high")

      assert {:ok, %{output_config: ^output_config}} =
               Request.build(
                 client,
                 [
                   model: "claude-opus-4-8",
                   max_tokens: 100,
                   messages: [%{role: "user", content: "Hi"}],
                   output_config: output_config
                 ],
                 stream: false
               )
    end

    test "propagates cache_control on a content-block struct into the normalized wire params",
         %{client: client} do
      assert {:ok, params} =
               Request.build(
                 client,
                 [
                   model: "claude-opus-4-8",
                   max_tokens: 100,
                   messages: [
                     %{
                       role: "user",
                       content: [
                         %Anthropic.Messages.Content.Text{
                           text: "Big context",
                           cache_control: Anthropic.CacheControl.ephemeral()
                         }
                       ]
                     }
                   ]
                 ],
                 stream: false
               )

      assert [%{type: "text", text: "Big context", cache_control: %{type: "ephemeral"}}] =
               Enum.at(params.messages, 0).content
    end
  end
end
