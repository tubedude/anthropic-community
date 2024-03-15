defmodule Anthropic.Config do
  @moduledoc """
  Module provides struct for Anthropic.Config, and provides validations for various config options.

  ## Configuration

  The following configuration options are available:

  - `:api_key` - The API key for authenticating requests to the Anthropic API (required).
  - `:model` - The name of the model to use for generating responses (default: "claude-3-opus-20240229").
  - `:max_tokens` - The maximum number of tokens allowed in the generated response (default: 1000).
  - `:temperature` - The sampling temperature for controlling response randomness (default: 1.0).
  - `:top_p` - The cumulative probability threshold for nucleus sampling (default: 1.0).
  - `:top_k` - The number of top tokens to consider for sampling (default: 1).
  - `:anthropic_version` - The version of the Anthropic API to use (default: "2023-06-01").
  - `:api_url` - The URL of the Anthropic API (default: "https://api.anthropic.com/v1").

  These options can be set in your application's configuration file:

  ```elixir
  config :anthropic,
    api_key: "your_api_key",
    model: "claude-v1",
    max_tokens: 500,
    temperature: 0.7,
    top_p: 0.9,
    top_k: 5
  ```

  """

  @default [
    anthropic_version: "2023-06-01",
    api_url: "https://api.anthropic.com/v1",
    api_key: nil
  ]

  defstruct anthropic_version: nil,
            api_url: nil,
            api_key: nil

  @type t :: %__MODULE__{
          anthropic_version: String.t(),
          api_url: String.t(),
          api_key: String.t()
        }

  @type config_option ::
          {:anthropic_version, String.t()}
          | {:api_url, String.t()}
          | {:api_key, String.t()}

  @type config_options :: [config_option()]

  @spec create(keyword()) :: struct()
  def create(opts) do
    @default
    |> Keyword.merge(build_system_configs(@default))
    |> Keyword.merge(opts)
    |> validate_config()
    |> then(&struct(__MODULE__, &1))
  end

  def build_system_configs(opts) do
    opts
    |> Enum.map(&get_config_variable/1)
  end

  defp get_config_variable({key, default}) do
    value =
      Application.get_env(:anthropic, key, default)

    {key, value}
  end

  def validate_config(config) do
    config
    |> Enum.reduce([], fn {key, value}, acc ->
      validated_value =
        case key do
          :max_tokens -> validate_max_tokens(value)
          :temperature -> validate_temperature(value)
          :top_p -> validate_top_p(value)
          :api_key -> validate_is_binary(key, value)
          :api_url -> validate_is_binary(key, value)
          _ -> value
        end

      Keyword.put(acc, key, validated_value)
    end)
  end

  defp validate_max_tokens(value) when is_integer(value) and value > 0, do: value

  defp validate_max_tokens(_),
    do: raise(ArgumentError, "Invalid max_tokens value, must be a positive integer.")

  defp validate_temperature(value) when is_float(value) and value >= 0.0 and value <= 1.0,
    do: value

  defp validate_temperature(_),
    do: raise(ArgumentError, "Invalid temperature value, must be a float between 0.0 and 1.0.")

  defp validate_top_p(value) when is_float(value) and value >= 0.0 and value <= 1.0, do: value

  defp validate_top_p(_),
    do: raise(ArgumentError, "Invalid top_p value, must be a float between 0.0 and 1.0.")

  defp validate_is_binary(_key, value) when is_binary(value), do: value

  defp validate_is_binary(key, value),
    do: raise(ArgumentError, ":#{key} must be a String.t(). Got: #{inspect(value)}")

  defimpl Enumerable, for: Anthropic.Config do
    def count(%Anthropic.Config{} = config) do
      config
      |> Map.from_struct()
      |> Map.delete(:__struct__)
      |> Map.keys()
      |> length()
      |> then(fn elem -> {:ok, elem} end)
    end

    def member?(%Anthropic.Config{} = config, field) when is_atom(field) do
      Map.from_struct(config)
      |> Map.has_key?(field)
      |> then(fn bool -> {:ok, bool} end)
    end

    def reduce(_config, {:halt, acc}, _func), do: {:halted, acc}

    def reduce(config, {:suspend, acc}, func) do
      {:suspended, acc, fn acc -> reduce(config, {:cont, acc}, func) end}
    end

    def reduce(%Anthropic.Config{} = config, {:cont, acc}, func) do
      config
      |> Map.from_struct()
      |> Map.delete(:__struct__)
      |> Enum.reduce({:cont, acc}, fn {key, value}, {:cont, acc} ->
        if Map.has_key?(config, key) and not is_nil(value) do
          func.({key, value}, acc)
        else
          {:cont, acc}
        end
      end)
    end

    def slice(_enumerable), do: {:error, __MODULE__}
  end
end
