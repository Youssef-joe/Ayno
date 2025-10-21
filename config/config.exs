import Config

config :polyglot, Polyglot.Gateway.Endpoint,
  http: [port: 4000],
  server: true,
  secret_key_base: "your-secret-key-base-here-change-in-production"

# Distributed PubSub with Redis for scaling across multiple nodes
config :phoenix, :pubsub,
  name: Polyglot.PubSub,
  adapter: Phoenix.PubSub.Redis,
  host: System.get_env("REDIS_HOST") || "localhost",
  port: 6379

config :phoenix, :json_library, Jason

config :logger, level: :info