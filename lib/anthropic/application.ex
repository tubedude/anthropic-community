defmodule Anthropic.Application do
  @moduledoc false

  use Application

  @doc false
  def start(_type, _args) do
    children = [
      Anthropic.Config,
      {Finch, name: Anthropic.HTTPClient.Engine}
    ]

    opts = [strategy: :one_for_one, name: Anthropic.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
