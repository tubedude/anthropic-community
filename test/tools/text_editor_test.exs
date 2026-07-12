defmodule Anthropic.Tools.TextEditorTest do
  use ExUnit.Case, async: true

  alias Anthropic.Tools.TextEditor

  test "defaults to the latest version and the fixed tool name" do
    assert TextEditor.new() == %{
             type: "text_editor_20250728",
             name: "str_replace_based_edit_tool"
           }
  end

  test "with max_characters" do
    assert TextEditor.new(max_characters: 5000) == %{
             type: "text_editor_20250728",
             name: "str_replace_based_edit_tool",
             max_characters: 5000
           }
  end
end
