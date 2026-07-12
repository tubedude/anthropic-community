defmodule Anthropic.BatchesTest do
  use ExUnit.Case
  import Mox

  alias Anthropic.{Batches, Client}

  setup :verify_on_exit!

  setup do
    {:ok, client: Client.new(api_key: "test-key")}
  end

  defp batch_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "msgbatch_1",
        "type" => "message_batch",
        "processing_status" => "in_progress",
        "request_counts" => %{
          "processing" => 2,
          "succeeded" => 0,
          "errored" => 0,
          "canceled" => 0,
          "expired" => 0
        },
        "results_url" => nil,
        "created_at" => "2026-07-10T00:00:00Z",
        "ended_at" => nil,
        "expires_at" => "2026-07-11T00:00:00Z"
      },
      overrides
    )
  end

  describe "create/2" do
    test "builds the requests array and returns the batch", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.path == "/v1/messages/batches"
        body = Jason.decode!(req.body)

        assert [
                 %{
                   "custom_id" => "request-1",
                   "params" => %{"model" => "claude-opus-4-8", "max_tokens" => 100}
                 },
                 %{"custom_id" => "request-2"}
               ] = body["requests"]

        refute Map.has_key?(Enum.at(body["requests"], 0)["params"], "stream")

        {:ok, %Finch.Response{status: 200, body: Jason.encode!(batch_json()), headers: []}}
      end)

      assert {:ok, %{id: "msgbatch_1", processing_status: "in_progress"}} =
               Batches.create(client, [
                 %{
                   custom_id: "request-1",
                   params: [
                     model: "claude-opus-4-8",
                     max_tokens: 100,
                     messages: [%{role: "user", content: "Hi"}]
                   ]
                 },
                 %{
                   custom_id: "request-2",
                   params: [
                     model: "claude-opus-4-8",
                     max_tokens: 100,
                     messages: [%{role: "user", content: "Hello"}]
                   ]
                 }
               ])
    end

    test "returns a validation error without a request when a batch item is invalid", %{
      client: client
    } do
      assert {:error, %Anthropic.Error{type: :validation_error}} =
               Batches.create(client, [%{custom_id: "bad", params: [model: "claude-opus-4-8"]}])
    end
  end

  describe "retrieve/2" do
    test "returns the batch", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.path == "/v1/messages/batches/msgbatch_1"
        {:ok, %Finch.Response{status: 200, body: Jason.encode!(batch_json()), headers: []}}
      end)

      assert {:ok, %{id: "msgbatch_1"}} = Batches.retrieve(client, "msgbatch_1")
    end
  end

  describe "list/2" do
    test "returns a list of batches", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn _req, _pool, _opts ->
        {:ok,
         %Finch.Response{
           status: 200,
           body: Jason.encode!(%{"data" => [batch_json()], "has_more" => false}),
           headers: []
         }}
      end)

      assert {:ok, %{data: [%{id: "msgbatch_1"}], has_more: false}} = Batches.list(client)
    end
  end

  describe "list_all/2" do
    test "transparently walks all pages via after_id/last_id", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.query == nil

        {:ok,
         %Finch.Response{
           status: 200,
           body:
             Jason.encode!(%{
               "data" => [batch_json(%{"id" => "msgbatch_1"})],
               "has_more" => true,
               "last_id" => "msgbatch_1"
             }),
           headers: []
         }}
      end)
      |> expect(:request, fn req, _pool, _opts ->
        assert req.query == "after_id=msgbatch_1"

        {:ok,
         %Finch.Response{
           status: 200,
           body:
             Jason.encode!(%{
               "data" => [batch_json(%{"id" => "msgbatch_2"})],
               "has_more" => false,
               "last_id" => "msgbatch_2"
             }),
           headers: []
         }}
      end)

      assert client |> Batches.list_all() |> Enum.map(& &1.id) == ["msgbatch_1", "msgbatch_2"]
    end
  end

  describe "cancel/2" do
    test "cancels the batch", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.path == "/v1/messages/batches/msgbatch_1/cancel"

        {:ok,
         %Finch.Response{
           status: 200,
           body: Jason.encode!(batch_json(%{"processing_status" => "canceling"})),
           headers: []
         }}
      end)

      assert {:ok, %{processing_status: "canceling"}} = Batches.cancel(client, "msgbatch_1")
    end
  end

  describe "delete/2" do
    test "deletes the batch via DELETE and returns the deleted-batch id/type", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.method == "DELETE"
        assert req.path == "/v1/messages/batches/msgbatch_1"

        {:ok,
         %Finch.Response{
           status: 200,
           body: Jason.encode!(%{"id" => "msgbatch_1", "type" => "message_batch_deleted"}),
           headers: []
         }}
      end)

      assert {:ok, %{id: "msgbatch_1", type: "message_batch_deleted"}} =
               Batches.delete(client, "msgbatch_1")
    end

    test "maps a not_found error the same way as other resources", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn _req, _pool, _opts ->
        {:ok,
         %Finch.Response{
           status: 404,
           body:
             Jason.encode!(%{
               "type" => "error",
               "error" => %{"type" => "not_found_error", "message" => "not found"}
             }),
           headers: []
         }}
      end)

      assert {:error, %Anthropic.Error{type: :not_found_error, status: 404}} =
               Batches.delete(client, "msgbatch_1")
    end
  end

  describe "results/2" do
    test "fetches and parses JSONL results by custom_id, given a batch map", %{client: client} do
      jsonl =
        [
          Jason.encode!(%{
            "custom_id" => "request-1",
            "result" => %{
              "type" => "succeeded",
              "message" => %{
                "id" => "msg_1",
                "type" => "message",
                "role" => "assistant",
                "content" => [%{"type" => "text", "text" => "Hi!"}],
                "model" => "claude-opus-4-8",
                "stop_reason" => "end_turn",
                "usage" => %{"input_tokens" => 5, "output_tokens" => 3}
              }
            }
          }),
          Jason.encode!(%{
            "custom_id" => "request-2",
            "result" => %{
              "type" => "errored",
              "error" => %{"type" => "invalid_request_error", "message" => "bad params"}
            }
          })
        ]
        |> Enum.join("\n")

      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.path == "/results"
        {:ok, %Finch.Response{status: 200, body: jsonl, headers: []}}
      end)

      batch =
        batch_json(%{"results_url" => "https://api.anthropic.com/results"})
        |> then(fn b ->
          %{
            id: b["id"],
            type: b["type"],
            processing_status: "ended",
            request_counts: b["request_counts"],
            results_url: b["results_url"],
            created_at: b["created_at"],
            ended_at: b["created_at"],
            expires_at: b["expires_at"]
          }
        end)

      assert {:ok, results} = Batches.results(client, batch)

      assert [
               %{
                 custom_id: "request-1",
                 type: "succeeded",
                 message: %Anthropic.Messages.Message{},
                 error: nil
               },
               %{
                 custom_id: "request-2",
                 type: "errored",
                 message: nil,
                 error: %Anthropic.Error{type: :invalid_request_error}
               }
             ] = results
    end

    test "returns an error when the batch has not ended", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.path == "/v1/messages/batches/msgbatch_1"
        {:ok, %Finch.Response{status: 200, body: Jason.encode!(batch_json()), headers: []}}
      end)

      assert {:error, %Anthropic.Error{type: :invalid_request_error}} =
               Batches.results(client, "msgbatch_1")
    end

    test "returns a clean error (not a FunctionClauseError) when given a not-ended batch map directly",
         %{client: client} do
      batch = %{
        id: "msgbatch_1",
        type: "message_batch",
        processing_status: "in_progress",
        request_counts: %{},
        results_url: nil,
        created_at: nil,
        ended_at: nil,
        expires_at: nil
      }

      assert {:error, %Anthropic.Error{type: :invalid_request_error}} =
               Batches.results(client, batch)
    end
  end
end
