import Config

# Load environment variables
Dotenvy.source!(["#{config_env()}.env", ".env"])

# Get required secrets
secret_key_base = System.fetch_env!("SECRET_KEY_BASE")
redis_host = System.get_env("REDIS_HOST", "localhost")
redis_port = System.get_env("REDIS_PORT", "6379") |> String.to_integer()
jwt_secret = System.fetch_env!("JWT_SECRET")
app_port = System.get_env("APP_PORT", "4000") |> String.to_integer()
app_env = config_env()

config :polyglot, Polyglot.Gateway.Endpoint,
  http: [port: app_port],
  server: true,
  secret_key_base: secret_key_base,
  url: [host: System.get_env("APP_HOST", "localhost"), port: app_port],
  # Security headers
  cors: [
    origins: (System.get_env("CORS_ORIGINS", "http://localhost:3000") |> String.split(",")),
    credentials: true,
    max_age: 3600
  ]

# Distributed PubSub with Redis for scaling across multiple nodes
config :phoenix, :pubsub,
  name: Polyglot.PubSub,
  adapter: Phoenix.PubSub.Redis,
  host: redis_host,
  port: redis_port,
  database: System.get_env("REDIS_DB", "0") |> String.to_integer()

config :phoenix, :json_library, Jason

# Logging
config :logger, level: String.to_atom(System.get_env("LOG_LEVEL", "info"))

# JWT Configuration
config :joken,
  default_signer: jwt_secret

# Rate limiting configuration
config :hammer,
  backend: {:ets, [name: :hammer_backend]}

# Sentry Configuration (error tracking)
if app_env == :prod do
  config :sentry,
    dsn: System.get_env("SENTRY_DSN"),
    environment_name: app_env,
    enable_source_code_context: true,
    root_source_code_path: File.cwd!(),
    included_environments: [:prod]
end