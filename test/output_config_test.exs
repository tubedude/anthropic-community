defmodule Anthropic.OutputConfigTest do
  use ExUnit.Case, async: true

  alias Anthropic.OutputConfig

  @json_schema %{
    "type" => "object",
    "properties" => %{"answer" => %{"type" => "string"}},
    "required" => ["answer"]
  }

  describe "json_schema/2" do
    test "with no opts" do
      assert OutputConfig.json_schema(@json_schema) == %{
               format: %{type: "json_schema", schema: @json_schema}
             }
    end

    test "with an effort level" do
      assert OutputConfig.json_schema(@json_schema, effort: "high") == %{
               format: %{type: "json_schema", schema: @json_schema},
               effort: "high"
             }
    end

    test "raises on an invalid effort level" do
      assert_raise NimbleOptions.ValidationError, fn ->
        OutputConfig.json_schema(@json_schema, effort: "extreme")
      end
    end

    test "raises when the schema is not a map" do
      assert_raise FunctionClauseError, fn -> OutputConfig.json_schema("not a map") end
    end
  end
end
