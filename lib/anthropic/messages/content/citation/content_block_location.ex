defmodule Anthropic.Messages.Content.Citation.ContentBlockLocation do
  @moduledoc "A citation to a block range within a `content`-source document (`Document.from_content/2`)."

  defstruct [
    :cited_text,
    :document_index,
    :document_title,
    :end_block_index,
    :file_id,
    :start_block_index
  ]

  @type t :: %__MODULE__{
          cited_text: String.t(),
          document_index: non_neg_integer(),
          document_title: String.t() | nil,
          end_block_index: non_neg_integer(),
          file_id: String.t() | nil,
          start_block_index: non_neg_integer()
        }
end
