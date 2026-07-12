defmodule Anthropic.Messages.Content.Citation.SearchResultLocation do
  @moduledoc "A citation to a block range within a `search_result` content block."

  defstruct [
    :cited_text,
    :end_block_index,
    :search_result_index,
    :source,
    :start_block_index,
    :title
  ]

  @type t :: %__MODULE__{
          cited_text: String.t(),
          end_block_index: non_neg_integer(),
          search_result_index: non_neg_integer(),
          source: String.t(),
          start_block_index: non_neg_integer(),
          title: String.t() | nil
        }
end
