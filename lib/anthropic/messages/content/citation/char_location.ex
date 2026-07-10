defmodule Anthropic.Messages.Content.Citation.CharLocation do
  @moduledoc "A citation to a character range within a plain-text document."

  defstruct [
    :cited_text,
    :document_index,
    :document_title,
    :end_char_index,
    :file_id,
    :start_char_index
  ]

  @type t :: %__MODULE__{
          cited_text: String.t(),
          document_index: non_neg_integer(),
          document_title: String.t() | nil,
          end_char_index: non_neg_integer(),
          file_id: String.t() | nil,
          start_char_index: non_neg_integer()
        }
end
