defmodule Polyglot.Application do
  use Application

  def start(_type, _args) do
    redis_host = System.get_env("REDIS_HOST", "localhost")
    redis_port = System.get_env("REDIS_PORT", "6379") |> String.to_integer()
    redis_url = "redis://#{redis_host}:#{redis_port}"
    
    children = [
      {Phoenix.PubSub, name: Polyglot.PubSub},
      {Redix, {redis_url, [name: :redix]}},
      Polyglot.Storage,
      Polyglot.EventPipeline,
      Polyglot.Gateway.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Polyglot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
