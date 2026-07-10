defmodule Anthropic.Messages.StreamTest do
  use ExUnit.Case
  import Mox

  alias Anthropic.{Client, Messages}

  setup :verify_on_exit!

  setup do
    {:ok, client: Client.new(api_key: "test-key")}
  end

  defp sse_frame(event, data), do: "event: #{event}\ndata: #{Jason.encode!(data)}\n\n"

  defp happy_path_frames do
    [
      sse_frame("message_start", %{
        "type" => "message_start",
        "message" => %{
          "id" => "msg_1",
          "role" => "assistant",
          "content" => [],
          "model" => "claude-opus-4-8",
          "usage" => %{}
        }
      }),
      sse_frame("content_block_start", %{
        "type" => "content_block_start",
        "index" => 0,
        "content_block" => %{"type" => "text", "text" => ""}
      }),
      sse_frame("content_block_delta", %{
        "type" => "content_block_delta",
        "index" => 0,
        "delta" => %{"type" => "text_delta", "text" => "Hi"}
      }),
      sse_frame("content_block_stop", %{"type" => "content_block_stop", "index" => 0}),
      sse_frame("message_delta", %{
        "type" => "message_delta",
        "delta" => %{"stop_reason" => "end_turn"},
        "usage" => %{"output_tokens" => 2}
      }),
      sse_frame("message_stop", %{"type" => "message_stop"})
    ]
  end

  describe "stream/2 happy path" do
    test "yields typed events and folds into a final Message via stream_to_message/1", %{
      client: client
    } do
      Anthropic.MockHTTPAdapter
      |> expect(:stream, fn _req, _pool, acc, fun, _opts ->
        acc = fun.({:status, 200}, acc)
        acc = fun.({:headers, []}, acc)

        acc =
          Enum.reduce(happy_path_frames(), acc, fn frame, acc -> fun.({:data, frame}, acc) end)

        {:ok, acc}
      end)

      {:ok, message} =
        client
        |> Messages.stream(
          model: "claude-opus-4-8",
          max_tokens: 100,
          messages: [%{role: "user", content: "Hi"}]
        )
        |> Messages.stream_to_message()

      assert %Anthropic.Messages.Message{
               stop_reason: "end_turn",
               content: [%Anthropic.Messages.Content.Text{text: "Hi"}]
             } = message
    end

    test "raw event stream contains the individual typed events in order", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:stream, fn _req, _pool, acc, fun, _opts ->
        acc = fun.({:status, 200}, acc)

        acc =
          Enum.reduce(happy_path_frames(), acc, fn frame, acc -> fun.({:data, frame}, acc) end)

        {:ok, acc}
      end)

      events =
        client
        |> Messages.stream(
          model: "claude-opus-4-8",
          max_tokens: 100,
          messages: [%{role: "user", content: "Hi"}]
        )
        |> Enum.to_list()

      assert [
               %Anthropic.Messages.StreamEvent.MessageStart{},
               %Anthropic.Messages.StreamEvent.ContentBlockStart{},
               %Anthropic.Messages.StreamEvent.ContentBlockDelta{},
               %Anthropic.Messages.StreamEvent.ContentBlockStop{},
               %Anthropic.Messages.StreamEvent.MessageDelta{},
               %Anthropic.Messages.StreamEvent.MessageStop{}
             ] = events
    end
  end

  describe "stream/2 retry before connection" do
    test "retries a 429 on the initial connection then succeeds", %{client: client} do
      client = %{client | max_retries: 1}

      Anthropic.MockHTTPAdapter
      |> expect(:stream, fn _req, _pool, acc, fun, _opts ->
        acc = fun.({:status, 429}, acc)
        acc = fun.({:headers, [{"retry-after", "0"}]}, acc)

        acc =
          fun.(
            {:data,
             Jason.encode!(%{
               "type" => "error",
               "error" => %{"type" => "rate_limit_error", "message" => "slow down"}
             })},
            acc
          )

        {:ok, acc}
      end)
      |> expect(:stream, fn _req, _pool, acc, fun, _opts ->
        acc = fun.({:status, 200}, acc)

        acc =
          Enum.reduce(happy_path_frames(), acc, fn frame, acc -> fun.({:data, frame}, acc) end)

        {:ok, acc}
      end)

      {:ok, message} =
        client
        |> Messages.stream(
          model: "claude-opus-4-8",
          max_tokens: 100,
          messages: [%{role: "user", content: "Hi"}]
        )
        |> Messages.stream_to_message()

      assert %Anthropic.Messages.Message{stop_reason: "end_turn"} = message
    end
  end

  describe "stream/2 mid-stream failure" do
    test "a connection drop after streaming started is terminal, not retried", %{client: client} do
      client = %{client | max_retries: 2}

      Anthropic.MockHTTPAdapter
      |> expect(:stream, 1, fn _req, _pool, acc, fun, _opts ->
        acc = fun.({:status, 200}, acc)

        acc =
          fun.(
            {:data,
             sse_frame("content_block_start", %{
               "type" => "content_block_start",
               "index" => 0,
               "content_block" => %{"type" => "text", "text" => ""}
             })},
            acc
          )

        _acc =
          fun.(
            {:data,
             sse_frame("content_block_delta", %{
               "type" => "content_block_delta",
               "index" => 0,
               "delta" => %{"type" => "text_delta", "text" => "partial"}
             })},
            acc
          )

        {:error, %Mint.TransportError{reason: :closed}}
      end)

      assert {:error, %Anthropic.Error{type: :connection_error}} =
               client
               |> Messages.stream(
                 model: "claude-opus-4-8",
                 max_tokens: 100,
                 messages: [%{role: "user", content: "Hi"}]
               )
               |> Messages.stream_to_message()
    end
  end

  describe "stream/2 crash safety" do
    test "a crash inside the transport task surfaces as a terminal error instead of crashing the caller",
         %{client: client} do
      client = %{client | max_retries: 0}

      Anthropic.MockHTTPAdapter
      |> expect(:stream, fn _req, _pool, _acc, _fun, _opts -> raise "boom" end)

      assert {:error, %Anthropic.Error{type: :connection_error, message: message}} =
               client
               |> Messages.stream(
                 model: "claude-opus-4-8",
                 max_tokens: 100,
                 messages: [%{role: "user", content: "Hi"}]
               )
               |> Messages.stream_to_message()

      assert message =~ "crashed"
    end
  end

  describe "stream/2 no status received" do
    test "a stream that ends without ever receiving a status is a terminal connection error", %{
      client: client
    } do
      client = %{client | max_retries: 0}

      Anthropic.MockHTTPAdapter
      |> expect(:stream, fn _req, _pool, acc, _fun, _opts -> {:ok, acc} end)

      assert {:error, %Anthropic.Error{type: :connection_error, message: message}} =
               client
               |> Messages.stream(
                 model: "claude-opus-4-8",
                 max_tokens: 100,
                 messages: [%{role: "user", content: "Hi"}]
               )
               |> Messages.stream_to_message()

      assert message =~ "before any response"
    end
  end

  describe "stream/2 validation" do
    test "raises immediately when params are invalid, before returning a stream", %{
      client: client
    } do
      assert_raise Anthropic.Error, ~r/max_tokens/, fn ->
        Messages.stream(client,
          model: "claude-opus-4-8",
          messages: [%{role: "user", content: "Hi"}]
        )
      end
    end
  end
end
