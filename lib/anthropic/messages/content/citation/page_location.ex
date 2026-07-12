defmodule Anthropic.Messages.Content.Citation.PageLocation do
  @moduledoc "A citation to a page range within a PDF document."

  defstruct [
    :cited_text,
    :document_index,
    :document_title,
    :end_page_number,
    :file_id,
    :start_page_number
  ]

  @type t :: %__MODULE__{
          cited_text: String.t(),
          document_index: non_neg_integer(),
          document_title: String.t() | nil,
          end_page_number: pos_integer(),
          file_id: String.t() | nil,
          start_page_number: pos_integer()
        }
end
