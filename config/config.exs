import Config

# Load environment variables
if Code.ensure_loaded?(Dotenvy) do
  Dotenvy.source!(["#{config_env()}.env", ".env"])
end

# Get required secrets
secret_key_base = System.get_env("SECRET_KEY_BASE") || (config_env() == :prod && raise "SECRET_KEY_BASE not set") || "dev-secret-key"
redis_host = System.get_env("REDIS_HOST", "localhost")
redis_port = System.get_env("REDIS_PORT", "6379") |> String.to_integer()
jwt_secret = System.get_env("JWT_SECRET") || (config_env() == :prod && raise "JWT_SECRET not set") || "dev-jwt-secret"
app_port = System.get_env("APP_PORT", "4000") |> String.to_integer()
app_env = config_env()

# PostgreSQL Configuration
db_host = System.get_env("DB_HOST", "localhost")
db_port = System.get_env("DB_PORT", "5432") |> String.to_integer()
db_user = System.get_env("DB_USER", "polyglot")
db_password = System.get_env("DB_PASSWORD", "polyglot")
db_name = System.get_env("DB_NAME", "polyglot_#{app_env}")

config :polyglot, Polyglot.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: db_user,
  password: db_password,
  database: db_name,
  hostname: db_host,
  port: db_port,
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE", "10")),
  ssl: System.get_env("DB_SSL", "false") |> String.to_atom()

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

# Sentry Configuration (error tracking) - disabled for now
# To enable: uncomment sentry dependency in mix.exs and set SENTRY_DSN env var