defmodule Anthropic.Messages.Content.CitationTest do
  use ExUnit.Case, async: true

  alias Anthropic.Messages.Content.Citation

  alias Anthropic.Messages.Content.Citation.{
    CharLocation,
    PageLocation,
    ContentBlockLocation,
    SearchResultLocation,
    WebSearchResultLocation
  }

  describe "from_json/1" do
    test "char_location" do
      assert %CharLocation{
               cited_text: "quoted text",
               document_index: 0,
               document_title: "My Doc",
               end_char_index: 100,
               file_id: nil,
               start_char_index: 50
             } =
               Citation.from_json(%{
                 "type" => "char_location",
                 "cited_text" => "quoted text",
                 "document_index" => 0,
                 "document_title" => "My Doc",
                 "end_char_index" => 100,
                 "start_char_index" => 50
               })
    end

    test "page_location" do
      assert %PageLocation{
               cited_text: "text",
               document_index: 1,
               start_page_number: 3,
               end_page_number: 5
             } =
               Citation.from_json(%{
                 "type" => "page_location",
                 "cited_text" => "text",
                 "document_index" => 1,
                 "start_page_number" => 3,
                 "end_page_number" => 5
               })
    end

    test "content_block_location" do
      assert %ContentBlockLocation{
               cited_text: "text",
               document_index: 0,
               start_block_index: 0,
               end_block_index: 1
             } =
               Citation.from_json(%{
                 "type" => "content_block_location",
                 "cited_text" => "text",
                 "document_index" => 0,
                 "start_block_index" => 0,
                 "end_block_index" => 1
               })
    end

    test "search_result_location" do
      assert %SearchResultLocation{
               cited_text: "text",
               search_result_index: 2,
               source: "https://example.com",
               start_block_index: 0,
               end_block_index: 1,
               title: "Result title"
             } =
               Citation.from_json(%{
                 "type" => "search_result_location",
                 "cited_text" => "text",
                 "search_result_index" => 2,
                 "source" => "https://example.com",
                 "start_block_index" => 0,
                 "end_block_index" => 1,
                 "title" => "Result title"
               })
    end

    test "web_search_result_location" do
      assert %WebSearchResultLocation{
               cited_text: "text",
               encrypted_index: "enc123",
               title: "Page title",
               url: "https://example.com"
             } =
               Citation.from_json(%{
                 "type" => "web_search_result_location",
                 "cited_text" => "text",
                 "encrypted_index" => "enc123",
                 "title" => "Page title",
                 "url" => "https://example.com"
               })
    end

    test "passes an unrecognized citation type through as a raw map" do
      raw = %{"type" => "some_future_location"}
      assert Citation.from_json(raw) == raw
    end
  end

  describe "to_json/1 round-trip" do
    test "char_location" do
      citation = %CharLocation{
        cited_text: "quoted",
        document_index: 0,
        document_title: nil,
        end_char_index: 10,
        file_id: nil,
        start_char_index: 0
      }

      assert Citation.to_json(citation) == %{
               type: "char_location",
               cited_text: "quoted",
               document_index: 0,
               end_char_index: 10,
               start_char_index: 0
             }
    end

    test "web_search_result_location" do
      citation = %WebSearchResultLocation{
        cited_text: "x",
        encrypted_index: "e",
        title: nil,
        url: "https://x.com"
      }

      assert Citation.to_json(citation) == %{
               type: "web_search_result_location",
               cited_text: "x",
               encrypted_index: "e",
               url: "https://x.com"
             }
    end

    test "raw map passes through unchanged" do
      raw = %{"type" => "some_future_location"}
      assert Citation.to_json(raw) == raw
    end
  end
end
