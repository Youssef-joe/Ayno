import Config

config :polyglot, Polyglot.Gateway.Endpoint,
  http: [port: 4000],
  server: true,
  secret_key_base: "your-secret-key-base-here-change-in-production"

config :phoenix, :json_library, Jason

config :logger, level: :info