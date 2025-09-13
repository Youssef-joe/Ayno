defmodule Polyglot.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Polyglot.PubSub},
      {Redix, name: :redix},
      Polyglot.Gateway.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Polyglot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end