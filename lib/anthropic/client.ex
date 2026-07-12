defmodule Anthropic.Client do
  @moduledoc """
  Holds connection-level configuration for the Anthropic API: credentials, base URL,
  API version, retry policy, and transport pool. Built once via `new/1` and passed
  explicitly as the first argument to every resource function (`Anthropic.Messages.create/2`,
  `Anthropic.Models.list/1`, etc.) rather than held implicitly in process/application state.

  ## Resolution order for `:api_key` and `:base_url`

  1. Explicit option passed to `new/1`.
  2. `Application.get_env(:anthropic, key)`.
  3. `ANTHROPIC_API_KEY` / `ANTHROPIC_BASE_URL` environment variables.
  4. For `:api_key` only: raises `ArgumentError` if still unresolved. `:base_url` defaults
     to `"https://api.anthropic.com"`.
  """

  @enforce_keys [:api_key]
  defstruct [
    :api_key,
    base_url: "https://api.anthropic.com",
    api_version: "2023-06-01",
    max_retries: 2,
    timeout: 600_000,
    default_model: nil,
    default_headers: [],
    http_pool: Anthropic.HTTPTransport.Engine
  ]

  @type t :: %__MODULE__{
          api_key: String.t(),
          base_url: String.t(),
          api_version: String.t(),
          max_retries: non_neg_integer(),
          timeout: pos_integer(),
          default_model: String.t() | nil,
          default_headers: [{String.t(), String.t()}],
          http_pool: atom()
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    opts
    |> Keyword.put_new_lazy(:api_key, fn -> resolve!(:api_key, "ANTHROPIC_API_KEY") end)
    |> Keyword.put_new_lazy(:base_url, fn ->
      resolve(:base_url, "ANTHROPIC_BASE_URL") || "https://api.anthropic.com"
    end)
    |> then(&struct!(__MODULE__, &1))
    |> validate!()
  end

  defp resolve!(app_env_key, env_var) do
    resolve(app_env_key, env_var) ||
      raise ArgumentError,
            "api_key is required (pass :api_key, set config :anthropic, :api_key, or set #{env_var})"
  end

  defp resolve(app_env_key, env_var) do
    Application.get_env(:anthropic, app_env_key) || System.get_env(env_var)
  end

  defp validate!(%__MODULE__{max_retries: r}) when r < 0 do
    raise ArgumentError, "max_retries must be >= 0, got: #{inspect(r)}"
  end

  defp validate!(%__MODULE__{api_key: key}) when not is_binary(key) or key == "" do
    raise ArgumentError, "api_key must be a non-empty String.t(), got: #{inspect(key)}"
  end

  defp validate!(client), do: client
end
