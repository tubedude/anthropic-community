defmodule Anthropic.Tools.Utils do
  @moduledoc """
  Defines tooling to use with modules that implement `Anthropic.Tools.ToolBehaviour`.
  """

  def generate_tool_description(tool_module) when is_atom(tool_module) do
    description = tool_module.description()
    parameters = tool_module.parameters()

    """
    <tool_description>
    <tool_name>#{tool_module}</tool_name>
    <description>
    #{description}
    </description>
    <parameters>
    #{generate_parameters_xml(parameters)}</parameters>
    </tool_description>
    """
  end

  defp generate_parameters_xml(parameters) do
    Enum.map(parameters, fn {name, type, description} ->
      """
      <parameter>
      <name>#{name}</name>
      <type>#{type}</type>
      <description>#{description}</description>
      </parameter>
      """
    end)
    |> Enum.join()
  end

  # @spec parse_invoke_function(binary()) :: list(binary())
  def parse_invoke_function(xml_string) do
    invoke_blocks_pattern = ~r/<invoke>(.*?)<\/invoke>/s
    tool_name_pattern = ~r/<tool_name>(.*?)<\/tool_name>/
    params_pattern = ~r/<param\d+>(.*?)<\/param\d+>/

    Regex.scan(invoke_blocks_pattern, xml_string)
    |> Enum.map(fn [_, invoke_block] ->
      tool_name =
        Regex.scan(tool_name_pattern, invoke_block)
        |> List.first()
        |> then(fn [_, name] -> name end)
        |> safe_convert_to_atom()

      params =
        Regex.scan(params_pattern, invoke_block)
        |> Enum.map(fn [_, param] -> param end)

      {tool_name, params}
    end)
  end

  defp safe_convert_to_atom(tool_name_string) when is_binary(tool_name_string) do
    String.to_existing_atom(tool_name_string)
  rescue
    ArgumentError -> nil
  end

  defp safe_convert_to_atom(_), do: nil

  def execute_async(module, args) when is_atom(module) and is_list(args) do
    Task.async(fn ->
      apply(module, :invoke, args)
    end)
  end

  def format_response(tasks, tool_names) do
    results =
      Enum.zip(tool_names, Task.await_many(tasks))
      |> Enum.map(fn {tool_name, result} -> {tool_name, result} end)

    build_xml(results)
  end

  defp build_xml(results) do
    """
    <function_results>
    #{Enum.map(results, fn {tool_name, result} -> """
      <result>
        <tool_name>#{tool_name}</tool_name>
        <stdout>
          #{result}
        </stdout>
      </result>
      """ end) |> Enum.join()}</function_results>
    """
  end

  def separator do
    """
    Here are the tools available:
    <tools>
    """
  end
end
