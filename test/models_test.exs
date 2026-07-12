defmodule Anthropic.ModelsTest do
  use ExUnit.Case
  import Mox

  alias Anthropic.{Client, Models}

  setup :verify_on_exit!

  setup do
    {:ok, client: Client.new(api_key: "test-key")}
  end

  describe "list/2" do
    test "returns the model list", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.path == "/v1/models"

        {:ok,
         %Finch.Response{
           status: 200,
           body:
             Jason.encode!(%{
               "data" => [%{"id" => "claude-opus-4-8", "display_name" => "Claude Opus 4.8"}],
               "has_more" => false,
               "first_id" => "claude-opus-4-8",
               "last_id" => "claude-opus-4-8"
             }),
           headers: []
         }}
      end)

      assert {:ok, %{data: [%{"id" => "claude-opus-4-8"}], has_more: false}} = Models.list(client)
    end

    test "encodes pagination options as a query string", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.query == "before_id=model_1&limit=10"
        {:ok, %Finch.Response{status: 200, body: Jason.encode!(%{"data" => []}), headers: []}}
      end)

      assert {:ok, %{data: []}} = Models.list(client, before_id: "model_1", limit: 10)
    end
  end

  describe "retrieve/2" do
    test "returns the not_found error mapped from the API", %{client: client} do
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
               Models.retrieve(client, "nope")
    end

    test "returns the model", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.path == "/v1/models/claude-opus-4-8"

        {:ok,
         %Finch.Response{
           status: 200,
           body: Jason.encode!(%{"id" => "claude-opus-4-8"}),
           headers: []
         }}
      end)

      assert {:ok, %{"id" => "claude-opus-4-8"}} = Models.retrieve(client, "claude-opus-4-8")
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
               "data" => [%{"id" => "model-a"}],
               "has_more" => true,
               "last_id" => "model-a"
             }),
           headers: []
         }}
      end)
      |> expect(:request, fn req, _pool, _opts ->
        assert req.query == "after_id=model-a"

        {:ok,
         %Finch.Response{
           status: 200,
           body:
             Jason.encode!(%{
               "data" => [%{"id" => "model-b"}],
               "has_more" => false,
               "last_id" => "model-b"
             }),
           headers: []
         }}
      end)

      assert client |> Models.list_all() |> Enum.to_list() == [
               %{"id" => "model-a"},
               %{"id" => "model-b"}
             ]
    end
  end
end
