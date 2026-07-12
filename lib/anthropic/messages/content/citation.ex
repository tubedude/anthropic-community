defmodule Anthropic.Messages.Content.Citation do
  @moduledoc """
  Decodes a raw citation object (as found in a `Text` content block's `:citations` list)
  into one of the five typed citation-location structs, discriminated on `"type"`:
  `CharLocation`, `PageLocation`, `ContentBlockLocation`, `SearchResultLocation`,
  `WebSearchResultLocation`.

  Citations are response-only — there is no request-side citation object to encode back,
  only a `citations: %{enabled: true}` config attached to the source document/search-result
  block being cited (see `Anthropic.Messages.Content.Document`).
  """

  alias Anthropic.Messages.Content.Citation.{
    CharLocation,
    PageLocation,
    ContentBlockLocation,
    SearchResultLocation,
    WebSearchResultLocation
  }

  @type t ::
          CharLocation.t()
          | PageLocation.t()
          | ContentBlockLocation.t()
          | SearchResultLocation.t()
          | WebSearchResultLocation.t()

  @spec from_json(map()) :: t() | map()
  def from_json(%{"type" => "char_location"} = c) do
    %CharLocation{
      cited_text: c["cited_text"],
      document_index: c["document_index"],
      document_title: c["document_title"],
      end_char_index: c["end_char_index"],
      file_id: c["file_id"],
      start_char_index: c["start_char_index"]
    }
  end

  def from_json(%{"type" => "page_location"} = c) do
    %PageLocation{
      cited_text: c["cited_text"],
      document_index: c["document_index"],
      document_title: c["document_title"],
      end_page_number: c["end_page_number"],
      file_id: c["file_id"],
      start_page_number: c["start_page_number"]
    }
  end

  def from_json(%{"type" => "content_block_location"} = c) do
    %ContentBlockLocation{
      cited_text: c["cited_text"],
      document_index: c["document_index"],
      document_title: c["document_title"],
      end_block_index: c["end_block_index"],
      file_id: c["file_id"],
      start_block_index: c["start_block_index"]
    }
  end

  def from_json(%{"type" => "search_result_location"} = c) do
    %SearchResultLocation{
      cited_text: c["cited_text"],
      end_block_index: c["end_block_index"],
      search_result_index: c["search_result_index"],
      source: c["source"],
      start_block_index: c["start_block_index"],
      title: c["title"]
    }
  end

  def from_json(%{"type" => "web_search_result_location"} = c) do
    %WebSearchResultLocation{
      cited_text: c["cited_text"],
      encrypted_index: c["encrypted_index"],
      title: c["title"],
      url: c["url"]
    }
  end

  def from_json(raw) when is_map(raw), do: raw

  @doc """
  Encodes a citation struct (or a plain map, passed through unchanged) back to its wire
  shape — needed because `Anthropic.ToolRunner` and multi-turn conversations replay a
  `Text` block's `citations` list as-is into a later request's message history.
  """
  @spec to_json(t() | map()) :: map()
  def to_json(%CharLocation{} = c) do
    %{
      type: "char_location",
      cited_text: c.cited_text,
      document_index: c.document_index,
      document_title: c.document_title,
      end_char_index: c.end_char_index,
      file_id: c.file_id,
      start_char_index: c.start_char_index
    }
    |> compact()
  end

  def to_json(%PageLocation{} = c) do
    %{
      type: "page_location",
      cited_text: c.cited_text,
      document_index: c.document_index,
      document_title: c.document_title,
      end_page_number: c.end_page_number,
      file_id: c.file_id,
      start_page_number: c.start_page_number
    }
    |> compact()
  end

  def to_json(%ContentBlockLocation{} = c) do
    %{
      type: "content_block_location",
      cited_text: c.cited_text,
      document_index: c.document_index,
      document_title: c.document_title,
      end_block_index: c.end_block_index,
      file_id: c.file_id,
      start_block_index: c.start_block_index
    }
    |> compact()
  end

  def to_json(%SearchResultLocation{} = c) do
    %{
      type: "search_result_location",
      cited_text: c.cited_text,
      end_block_index: c.end_block_index,
      search_result_index: c.search_result_index,
      source: c.source,
      start_block_index: c.start_block_index,
      title: c.title
    }
    |> compact()
  end

  def to_json(%WebSearchResultLocation{} = c) do
    %{
      type: "web_search_result_location",
      cited_text: c.cited_text,
      encrypted_index: c.encrypted_index,
      title: c.title,
      url: c.url
    }
    |> compact()
  end

  def to_json(raw) when is_map(raw), do: raw

  defp compact(map), do: Map.reject(map, fn {_k, v} -> is_nil(v) end)
end
