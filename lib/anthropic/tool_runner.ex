defmodule Anthropic.ToolRunner do
  @moduledoc """
  Drives `Anthropic.Messages.create/2` in a loop, executing tool calls the assistant
  requests until it produces a final answer (`stop_reason` other than `"tool_use"`).

  ## Example

      client = Anthropic.Client.new(api_key: System.fetch_env!("ANTHROPIC_API_KEY"))

      {:ok, message, _history} =
        Anthropic.ToolRunner.run(
          client,
          [model: "claude-opus-4-8", max_tokens: 1024,
           messages: [%{role: "user", content: "What's the weather in Paris?"}]],
          [MyApp.WeatherTool]
        )
  """

  alias Anthropic.{Client, Error}
  alias Anthropic.Messages
  alias Anthropic.Messages.{Message, Content}
  alias Anthropic.Messages.Content.ToolUse

  @default_max_iterations 25

  @doc """
  Runs `client`/`opts` through `Anthropic.Messages.create/2`, executing any requested
  `tools` and feeding results back, until the assistant stops requesting tools (or
  `max_iterations` is exceeded).

  Returns `{:ok, final_message, messages_history}` on success, where `messages_history` is
  the full `messages` param list (including every assistant tool_use turn and user
  tool_result turn) so the caller can continue the conversation. Returns `{:error,
  %Anthropic.Error{}}` if the underlying API call fails or the loop exceeds
  `max_iterations`.
  """
  @spec run(Client.t(), Messages.create_opts(), list(module()), pos_integer()) ::
          {:ok, Message.t(), list(map())} | {:error, Error.t()}
  def run(%Client{} = client, opts, tools, max_iterations \\ @default_max_iterations)
      when is_list(tools) do
    tool_map = Map.new(tools, &{&1.name(), &1})
    messages = Keyword.fetch!(opts, :messages)
    opts = Keyword.put(opts, :tools, tools)

    loop(client, opts, messages, tool_map, max_iterations)
  end

  defp loop(_client, _opts, _messages, _tool_map, 0) do
    {:error, Error.new(:tool_runner_max_iterations, "exceeded max_iterations")}
  end

  defp loop(client, opts, messages, tool_map, remaining) do
    case Messages.create(client, Keyword.put(opts, :messages, messages)) do
      {:error, _reason} = error ->
        error

      {:ok, %Message{} = message} ->
        if Message.tool_use?(message) do
          messages = messages ++ [Message.to_param(message)]

          tool_results =
            message
            |> Message.tool_uses()
            |> Enum.map(&execute_one(&1, tool_map))

          messages = messages ++ [%{role: "user", content: tool_results}]

          loop(client, opts, messages, tool_map, remaining - 1)
        else
          {:ok, message, messages ++ [Message.to_param(message)]}
        end
    end
  end

  defp execute_one(%ToolUse{id: id, name: name, input: input}, tool_map) do
    case Map.fetch(tool_map, name) do
      :error ->
        Content.to_json(%Content.ToolResult{
          tool_use_id: id,
          content: "Error: tool #{inspect(name)} is not registered",
          is_error: true
        })

      {:ok, tool_module} ->
        case tool_module.execute(input) do
          {:ok, result} ->
            Content.to_json(%Content.ToolResult{
              tool_use_id: id,
              content: to_string_content(result)
            })

          {:error, reason} ->
            Content.to_json(%Content.ToolResult{
              tool_use_id: id,
              content: to_string_content(reason),
              is_error: true
            })
        end
    end
  end

  defp to_string_content(result) when is_binary(result), do: result
  defp to_string_content(result), do: Jason.encode!(result)
end
