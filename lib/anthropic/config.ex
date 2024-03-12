defmodule Anthropic.Config do
  @moduledoc """
  Module for setting up the configuration of Anthropic API.
  """

  use GenServer

  @default %{
    model: "claude-3-opus-20240229",
    anthropic_version: "2023-06-01",
    api_url: "https://api.anthropic.com/v1",
    max_tokens: 1000,
    temperature: 1.0,
    api_key: nil,
    top_k: 1
  }

  defstruct model: nil,
            anthropic_version: nil,
            api_url: nil,
            max_tokens: nil,
            temperature: nil,
            top_p: nil,
            top_k: nil,
            api_key: nil


  @type t :: %__MODULE__{
    model: String.t() | nil,
    anthropic_version: String.t() | nil,
    api_url: String.t() | nil,
    max_tokens: non_neg_integer() | nil,
    temperature: float() | nil,
    top_p: float() | nil,
    top_k: non_neg_integer() | nil,
    api_key: String.t() | nil
  }

  @type config_option ::
  {:model, String.t()}
  | {:anthropic_version, String.t()}
  | {:api_url, String.t()}
  | {:max_tokens, non_neg_integer()}
  | {:temperature, float()}
  | {:top_p, float()}
  | {:top_k, non_neg_integer()}
  | {:api_key, String.t()}

  @type config_options :: [config_option()]
  ### API

  def start_link(opts),
    do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    state =
      @default
      |> Enum.map(&get_config_variable/1)
      |> Enum.into(%{})
      |> validate_config()
      |> then(fn s -> struct(%__MODULE__{}, s) end)

    {:ok, state}
  end

  @doc """
  Retrieves the current configuration options.

  This function queries the GenServer to return the current state, which represents the active configuration.

  ## Returns

  - The current configuration as a `Anthropic.Config` struct.
  """
  def opts, do: GenServer.call(__MODULE__, :opts)

  @doc """
  Resets specific configuration options.

  Allows dynamically updating the configuration by merging provided options with the current state. The updated configuration is then validated.

  ## Parameters

  - `keyword_list`: A keyword list of configuration options to update.

  ## Returns

  - The updated configuration as a `Anthropic.Config` struct.
  """
  def reset(keyword_list), do: GenServer.call(__MODULE__, {:reset, keyword_list})

  ### Callbacks

  @impl true
  def handle_call(:opts, _from, state), do: {:reply, state, state}

  def handle_call({:reset, keyword_list}, _from, state) do
    new_state =
      keyword_list
      |> Enum.into(%{})
      |> then(fn map -> Map.merge(state, map) end)
      |> validate_config()
      |> then(fn s -> struct(%__MODULE__{}, s) end)

    {:reply, new_state, new_state}
  end

  ### Helpers

  defp get_config_variable({key, default}) do
    value =
      Application.get_env(:anthropic, key, default)

    {key, value}
  end

  defp validate_config(config) do
    config
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      validated_value =
        case key do
          :max_tokens -> validate_max_tokens(value)
          :temperature -> validate_temperature(value)
          :top_p -> validate_top_p(value)
          _ -> value
        end

      Map.put(acc, key, validated_value)
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
