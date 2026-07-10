defmodule Anthropic.Messages.Request do
  @moduledoc """
  Builds and validates the wire params for a `POST /v1/messages` request from a `Client` and
  caller-supplied options. This is the single place where client defaults, call-site opts,
  and wire-shape validation are merged for `Anthropic.Messages.create/2` and `stream/2`.
  """

  alias Anthropic.Client
  alias Anthropic.Messages.Content

  @spec build(Client.t(), keyword() | map(), stream: boolean()) ::
          {:ok, map()} | {:error, Anthropic.Error.t()}
  def build(%Client{} = client, opts, stream: stream?) do
    params =
      opts
      |> Map.new()
      |> Map.put_new(:model, client.default_model)
      |> Map.put(:stream, stream?)

    finish_build(params, require_max_tokens: true)
  end

  @doc """
  Like `build/3`, but for `POST /v1/messages/count_tokens`: same shape minus `max_tokens`
  (not accepted by that endpoint) and without a `stream` field.
  """
  @spec build_count_tokens(Client.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Anthropic.Error.t()}
  def build_count_tokens(%Client{} = client, opts) do
    params =
      opts
      |> Map.new()
      |> Map.put_new(:model, client.default_model)

    finish_build(params, require_max_tokens: false)
  end

  defp finish_build(params, require_max_tokens: require_max_tokens?) do
    case validate(params, require_max_tokens?) do
      :ok ->
        {:ok,
         params
         |> normalize_tools()
         |> normalize_messages()
         |> Map.reject(fn {_key, value} -> is_nil(value) end)}

      {:error, reason} ->
        {:error, Anthropic.Error.validation(reason)}
    end
  end

  defp validate(params, require_max_tokens?) do
    cond do
      not is_binary(Map.get(params, :model)) or Map.get(params, :model) == "" ->
        {:error, "model is required (pass :model or set Client.default_model)"}

      require_max_tokens? and
          (not is_integer(Map.get(params, :max_tokens)) or Map.get(params, :max_tokens) <= 0) ->
        {:error, "max_tokens is required and must be a positive integer"}

      not is_list(Map.get(params, :messages)) or Map.get(params, :messages) == [] ->
        {:error, "messages must be a non-empty list"}

      true ->
        :ok
    end
  end

  defp normalize_tools(%{tools: nil} = params), do: params

  defp normalize_tools(%{tools: tools} = params) when is_list(tools) do
    %{params | tools: Enum.map(tools, &Anthropic.Tools.to_param/1)}
  end

  defp normalize_tools(params), do: params

  defp normalize_messages(%{messages: messages} = params) when is_list(messages) do
    %{params | messages: Enum.map(messages, &normalize_message/1)}
  end

  defp normalize_messages(params), do: params

  defp normalize_message(%{content: content} = message) when is_list(content) do
    %{message | content: Enum.map(content, &Content.to_json/1)}
  end

  defp normalize_message(%{} = message), do: message
end
