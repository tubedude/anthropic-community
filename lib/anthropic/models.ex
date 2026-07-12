defmodule Anthropic.Models do
  @moduledoc "The `Models` resource: list and retrieve available Claude models."

  alias Anthropic.{Client, Error}

  @type list_opts :: [before_id: String.t(), after_id: String.t(), limit: pos_integer()]
  @type list_result :: %{
          data: list(map()),
          has_more: boolean(),
          first_id: String.t() | nil,
          last_id: String.t() | nil
        }

  @doc """
  Lists available models, most recently released first.

  ## Examples

      {:ok, %{data: models}} = Anthropic.Models.list(client)
  """
  @spec list(Client.t(), list_opts()) :: {:ok, list_result()} | {:error, Error.t()}
  def list(%Client{} = client, opts \\ []) do
    with {:ok, body} <- Anthropic.HTTPTransport.get(client, "/v1/models" <> query_string(opts)) do
      {:ok,
       %{
         data: body["data"] || [],
         has_more: body["has_more"] || false,
         first_id: body["first_id"],
         last_id: body["last_id"]
       }}
    end
  end

  @doc "Retrieves a single model by id."
  @spec retrieve(Client.t(), model_id :: String.t()) :: {:ok, map()} | {:error, Error.t()}
  def retrieve(%Client{} = client, model_id) when is_binary(model_id) do
    Anthropic.HTTPTransport.get(client, "/v1/models/#{URI.encode(model_id)}")
  end

  @doc """
  Like `list/2`, but returns a lazy `Stream` of individual model maps that transparently
  fetches subsequent pages as it's consumed, instead of one page at a time.

  ## Examples

      client
      |> Anthropic.Models.list_all()
      |> Enum.each(&IO.puts(&1["id"]))
  """
  @spec list_all(Client.t(), list_opts()) :: Enumerable.t()
  def list_all(%Client{} = client, opts \\ []) do
    Anthropic.Pagination.stream(opts, &list(client, &1))
  end

  defp query_string([]), do: ""

  defp query_string(opts) do
    "?" <> URI.encode_query(opts)
  end
end
