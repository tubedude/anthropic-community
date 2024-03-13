defmodule Anthropic.HTTPClient do
  @callback build(
              Finch.Request.method(),
              Finch.Request.url(),
              Finch.Request.headers(),
              Finch.Request.body(),
              Keyword.t()
            ) :: Finch.Request.t()
  @callback request(Finch.Request.t(), module(), keyword()) ::
              {:ok, Finch.Response.t()} | {:error, Exception.t()}

  def build(method, url, headers \\ [], body \\ nil, opts \\ []),
    do: impl().build(method, url, headers, body, opts)

  def request(req, name, opts \\ []), do: impl().request(req, name, opts)
  defp impl, do: Application.get_env(:anthropic, :http_client, Finch)
end
