defmodule Anthropic.Messages.Content.Citation.WebSearchResultLocation do
  @moduledoc "A citation to a web search result."

  defstruct [:cited_text, :encrypted_index, :title, :url]

  @type t :: %__MODULE__{
          cited_text: String.t(),
          encrypted_index: String.t(),
          title: String.t() | nil,
          url: String.t()
        }
end
