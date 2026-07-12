defmodule Anthropic.HTTPTransport.Adapter do
  @moduledoc """
  Behaviour for the underlying HTTP transport. Defaults to `Finch`, swappable via
  `Application.get_env(:anthropic, :http_adapter, Finch)` — used in tests to mock the
  network boundary while exercising the real retry/backoff/SSE-parsing logic in
  `Anthropic.HTTPTransport`.
  """

  @callback request(Finch.Request.t(), pool :: atom(), opts :: keyword()) ::
              {:ok, Finch.Response.t()} | {:error, Exception.t()}

  @callback stream(Finch.Request.t(), pool :: atom(), acc :: any(), fun(), opts :: keyword()) ::
              {:ok, any()} | {:error, Exception.t()}
end
