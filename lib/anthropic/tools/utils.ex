defmodule Anthropic.Tools.Utils do
  @moduledoc false

  @spec decorate_tools_description(any(), MapSet.t()) :: binary()
  def decorate_tools_description(system, tools) do
    if MapSet.size(tools) == 0 do
      system
    else
      tools_description =
        tools
        |> Enum.map(&generate_tool_description/1)
        |> Enum.join("\n")

      """
      #{system}

      In this environment you have access to a set of tools you can use to answer the user's question.
      You may call them like this:
      <function_calls>
        <invoke>
          <tool_name>$TOOL_NAME</tool_name>
          <parameters>
            <$PARAMETER_NAME>$PARAMETER_VALUE</$PARAMETER_NAME>
            ...
          </parameters>
        </invoke>
      </function_calls>
      When you feel the need to call functions, only send the proper XML. Do not write anything else and wait for my reply.
      Here are the tools available:
      <tools>
      #{tools_description}
      </tools>
      """
    end
  end

  defp generate_tool_description(tool_module) when is_atom(tool_module) do
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

  @spec parse_invoke_function(binary()) :: list(binary())
  def parse_invoke_function(xml_string) do
    ~r/<invoke>.*?<tool_name>(.*?)<\/tool_name>.*?<parameters>(.*?)<\/parameters>.*?<\/invoke>/s
    |> Regex.scan(xml_string, capture: :all_but_first)
    |> Enum.map(fn [tool_name, parameters] ->
      {safe_convert_to_atom(tool_name), parse_parameters(parameters)}
    end)
  end

  defp parse_parameters(parameters_string) do
    Regex.scan(~r/<(\w+)>(.*?)<\/\1>/, parameters_string, capture: :all_but_first)
    |> Enum.map(fn [param_name, param_value] ->
      {safe_convert_to_atom(param_name), param_value}
    end)
  end

  defp safe_convert_to_atom(tool_name_string) when is_binary(tool_name_string) do
    String.to_existing_atom(tool_name_string)
  rescue
    ArgumentError -> nil
  end

  def execute_async(module, args) when is_atom(module) and is_list(args) do
    Task.async(fn ->
      apply(module, :invoke, args)
    end)
  end

  def format_response(tasks, tool_names) when is_list(tasks) do
    results =
      Enum.zip(tool_names, Task.await_many(tasks))
      |> Enum.map(fn {tool_name, result} -> {tool_name, result} end)

    build_result_xml(results)
  end

  def format_response(task, tool_name) do
    result = Task.await(task)
    build_result_xml([{tool_name, result}])
  end

  defp build_result_xml(results) do
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
end
