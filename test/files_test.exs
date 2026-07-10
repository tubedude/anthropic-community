defmodule Anthropic.FilesTest do
  use ExUnit.Case
  import Mox

  alias Anthropic.{Client, Files}

  setup :verify_on_exit!

  setup do
    {:ok, client: Client.new(api_key: "test-key")}
  end

  defp file_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "file_1",
        "type" => "file",
        "filename" => "report.pdf",
        "mime_type" => "application/pdf",
        "size_bytes" => 1024,
        "created_at" => "2026-07-10T00:00:00Z",
        "downloadable" => true,
        "scope" => nil
      },
      overrides
    )
  end

  defp has_beta_header?(req) do
    Enum.any?(req.headers, fn {k, v} -> k == "anthropic-beta" and v == "files-api-2025-04-14" end)
  end

  describe "create/3" do
    test "uploads a local file as multipart/form-data with the beta header", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.path == "/v1/files"
        assert req.method == "POST"
        assert has_beta_header?(req)

        [{"content-type", content_type}] =
          Enum.filter(req.headers, fn {k, _} -> k == "content-type" end)

        assert content_type =~ "multipart/form-data; boundary="

        body = IO.iodata_to_binary(req.body)
        assert body =~ "name=\"file\"; filename=\"image.png\""
        assert body =~ "Content-Type: image/png"

        {:ok, %Finch.Response{status: 200, body: Jason.encode!(file_json()), headers: []}}
      end)

      assert {:ok, %{id: "file_1", filename: "report.pdf", mime_type: "application/pdf"}} =
               Files.create(client, "test/images/image.png")
    end

    test "returns a validation-shaped error when the path doesn't exist", %{client: client} do
      assert {:error, %Anthropic.Error{type: :invalid_request_error}} =
               Files.create(client, "test/nofile.pdf")
    end
  end

  describe "create_from_binary/4" do
    test "uploads raw binary with an explicit filename and content_type", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        body = IO.iodata_to_binary(req.body)
        assert body =~ "name=\"file\"; filename=\"notes.txt\""
        assert body =~ "Content-Type: text/plain"
        assert body =~ "hello world"

        {:ok,
         %Finch.Response{
           status: 200,
           body: Jason.encode!(file_json(%{"filename" => "notes.txt"})),
           headers: []
         }}
      end)

      assert {:ok, %{filename: "notes.txt"}} =
               Files.create_from_binary(client, "hello world", "notes.txt",
                 content_type: "text/plain"
               )
    end

    test "defaults content_type to application/octet-stream", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        body = IO.iodata_to_binary(req.body)
        assert body =~ "Content-Type: application/octet-stream"
        {:ok, %Finch.Response{status: 200, body: Jason.encode!(file_json()), headers: []}}
      end)

      assert {:ok, %{}} = Files.create_from_binary(client, "data", "f.bin")
    end
  end

  describe "list/2" do
    test "returns the file list with the beta header", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.path == "/v1/files"
        assert has_beta_header?(req)

        {:ok,
         %Finch.Response{
           status: 200,
           body: Jason.encode!(%{"data" => [file_json()], "has_more" => false}),
           headers: []
         }}
      end)

      assert {:ok, %{data: [%{id: "file_1"}], has_more: false}} = Files.list(client)
    end
  end

  describe "list_all/2" do
    test "auto-paginates via after_id/last_id", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.query == nil

        {:ok,
         %Finch.Response{
           status: 200,
           body:
             Jason.encode!(%{
               "data" => [file_json(%{"id" => "file_1"})],
               "has_more" => true,
               "last_id" => "file_1"
             }),
           headers: []
         }}
      end)
      |> expect(:request, fn req, _pool, _opts ->
        assert req.query == "after_id=file_1"

        {:ok,
         %Finch.Response{
           status: 200,
           body:
             Jason.encode!(%{
               "data" => [file_json(%{"id" => "file_2"})],
               "has_more" => false,
               "last_id" => "file_2"
             }),
           headers: []
         }}
      end)

      assert client |> Files.list_all() |> Enum.map(& &1.id) == ["file_1", "file_2"]
    end
  end

  describe "retrieve/2" do
    test "returns file metadata with the beta header", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.path == "/v1/files/file_1"
        assert has_beta_header?(req)
        {:ok, %Finch.Response{status: 200, body: Jason.encode!(file_json()), headers: []}}
      end)

      assert {:ok, %{id: "file_1"}} = Files.retrieve(client, "file_1")
    end
  end

  describe "download/2" do
    test "returns the raw binary content with the beta and accept headers", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.path == "/v1/files/file_1/content"
        assert has_beta_header?(req)
        assert {"accept", "application/binary"} in req.headers
        {:ok, %Finch.Response{status: 200, body: <<1, 2, 3>>, headers: []}}
      end)

      assert {:ok, <<1, 2, 3>>} = Files.download(client, "file_1")
    end
  end

  describe "delete/2" do
    test "deletes a file with the beta header", %{client: client} do
      Anthropic.MockHTTPAdapter
      |> expect(:request, fn req, _pool, _opts ->
        assert req.method == "DELETE"
        assert req.path == "/v1/files/file_1"
        assert has_beta_header?(req)

        {:ok,
         %Finch.Response{
           status: 200,
           body: Jason.encode!(%{"id" => "file_1", "type" => "file_deleted"}),
           headers: []
         }}
      end)

      assert {:ok, %{id: "file_1", type: "file_deleted"}} = Files.delete(client, "file_1")
    end
  end
end
