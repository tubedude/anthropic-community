defmodule Anthropic.Messages.Content.DocumentTest do
  use ExUnit.Case, async: true

  alias Anthropic.Messages.Content
  alias Anthropic.Messages.Content.Document

  describe "process_document/3" do
    test "with a valid path" do
      assert {:ok, %Document{source_type: "base64", media_type: "application/pdf", data: data}} =
               Document.process_document("test/images/image.png", :path)

      assert is_binary(data)
    end

    test "with binary data" do
      {:ok, binary} = File.read("test/images/image.png")

      assert {:ok, %Document{source_type: "base64", media_type: "application/pdf"}} =
               Document.process_document(binary, :binary)
    end

    test "with already-base64-encoded data" do
      {:ok, binary} = File.read("test/images/image.png")
      base64 = :base64.encode(binary)

      assert {:ok, %Document{source_type: "base64", data: ^base64}} =
               Document.process_document(base64, :base64)
    end

    test "with invalid base64" do
      assert {:error, "Invalid base64 data provided for the document."} =
               Document.process_document("nonono", :base64)
    end

    test "with an invalid path" do
      assert {:error, "Error reading file enoent path: test/nofile.pdf"} =
               Document.process_document("test/nofile.pdf", :path)
    end

    test "passes through title/context/citations/cache_control options" do
      assert {:ok, doc} =
               Document.process_document("test/images/image.png", :path,
                 title: "Q3 Report",
                 context: "Internal financials",
                 citations: %{enabled: true},
                 cache_control: Anthropic.CacheControl.ephemeral()
               )

      assert doc.title == "Q3 Report"
      assert doc.context == "Internal financials"
      assert doc.citations == %{enabled: true}
      assert doc.cache_control == %{type: "ephemeral"}
    end
  end

  describe "from_url/2" do
    test "builds a url-source document" do
      assert %Document{source_type: "url", url: "https://example.com/report.pdf"} =
               Document.from_url("https://example.com/report.pdf")
    end
  end

  describe "from_text/2" do
    test "builds a text-source document" do
      assert %Document{source_type: "text", media_type: "text/plain", data: "Hello"} =
               Document.from_text("Hello")
    end
  end

  describe "from_content/2" do
    test "builds a content-source document from a string" do
      assert %Document{source_type: "content", content: "pre-formatted"} =
               Document.from_content("pre-formatted")
    end

    test "builds a content-source document from a list of blocks" do
      blocks = [%{type: "text", text: "chunk 1"}]
      assert %Document{source_type: "content", content: ^blocks} = Document.from_content(blocks)
    end
  end

  describe "Content.to_json/1 wire encoding" do
    test "base64 source" do
      {:ok, doc} = Document.process_document("test/images/image.png", :path, title: "Report")

      assert %{
               type: "document",
               source: %{type: "base64", media_type: "application/pdf", data: _},
               title: "Report"
             } =
               Content.to_json(doc)
    end

    test "url source" do
      assert Content.to_json(Document.from_url("https://example.com/report.pdf")) == %{
               type: "document",
               source: %{type: "url", url: "https://example.com/report.pdf"}
             }
    end

    test "text source" do
      assert Content.to_json(Document.from_text("Hello")) == %{
               type: "document",
               source: %{type: "text", media_type: "text/plain", data: "Hello"}
             }
    end

    test "content source" do
      assert Content.to_json(Document.from_content("pre-formatted")) == %{
               type: "document",
               source: %{type: "content", content: "pre-formatted"}
             }
    end

    test "drops nil optional fields" do
      json = Content.to_json(Document.from_text("Hello"))
      refute Map.has_key?(json, :cache_control)
      refute Map.has_key?(json, :citations)
      refute Map.has_key?(json, :context)
      refute Map.has_key?(json, :title)
    end

    test "includes cache_control/citations/context/title when set" do
      doc =
        Document.from_text("Hello",
          title: "Notes",
          context: "See appendix",
          citations: %{enabled: true},
          cache_control: Anthropic.CacheControl.ephemeral()
        )

      assert Content.to_json(doc) == %{
               type: "document",
               source: %{type: "text", media_type: "text/plain", data: "Hello"},
               title: "Notes",
               context: "See appendix",
               citations: %{enabled: true},
               cache_control: %{type: "ephemeral"}
             }
    end
  end
end
