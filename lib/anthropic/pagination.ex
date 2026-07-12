defmodule Anthropic.Pagination do
  @moduledoc """
  Auto-paginating `Stream` helper for cursor-based list endpoints (`Anthropic.Models.list_all/2`,
  `Anthropic.Batches.list_all/2`). Walks pages forward via `after_id`/`last_id`, fetching
  each page lazily as the stream is consumed, until the API reports `has_more: false` (or a
  page comes back with no `last_id` to continue from).

  A page-fetch failure raises `Anthropic.Error` from within the `Stream` — unlike
  `Anthropic.Messages.stream/2`, there's no typed "error event" in the wire protocol for
  list endpoints to deliver as a stream element instead, so raising (rescue-able, since
  `Anthropic.Error` is an exception) is the idiomatic Elixir way to surface it.
  """

  @type page :: %{data: list(term()), has_more: boolean(), last_id: String.t() | nil}
  @type fetch_page :: (keyword() -> {:ok, page()} | {:error, Anthropic.Error.t()})

  @spec stream(keyword(), fetch_page()) :: Enumerable.t()
  def stream(opts, fetch_page) when is_list(opts) and is_function(fetch_page, 1) do
    Stream.resource(
      fn -> :first end,
      fn
        :halt -> {:halt, :halt}
        :first -> fetch(fetch_page, opts)
        {:after, id} -> fetch(fetch_page, next_page_opts(opts, id))
      end,
      fn _state -> :ok end
    )
  end

  defp fetch(fetch_page, page_opts) do
    case fetch_page.(page_opts) do
      {:ok, %{data: []}} ->
        {:halt, :halt}

      {:ok, %{data: data} = page} ->
        {data, next_state(page)}

      {:error, error} ->
        raise error
    end
  end

  defp next_state(%{has_more: true, last_id: last_id}) when is_binary(last_id),
    do: {:after, last_id}

  defp next_state(_page), do: :halt

  defp next_page_opts(opts, after_id) do
    opts
    |> Keyword.delete(:before_id)
    |> Keyword.delete(:after_id)
    |> Keyword.put(:after_id, after_id)
  end
end
