defmodule Polyglot.MixProject do
  use Mix.Project

  def project do
    [
      app: :polyglot,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Polyglot.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_pubsub_redis, "~> 3.0"},
      {:plug_cowboy, "~> 2.5"},
      {:jason, "~> 1.2"},
      {:redix, "~> 1.2"},
      {:httpoison, "~> 2.0"},
      # Database
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.18"},
      # gRPC for high-performance communication
      {:grpc, "~> 0.7"},
      {:protobuf, "~> 0.15"},
      # Authentication & Security
      {:joken, "~> 2.6"},
      # {:bcrypt_elixir, "~> 3.1"},  # Temporarily disabled - requires C++ build tools
      # Observability
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      # {:prometheus_ex, "~> 3.0"},  # Phase 2 Extended: Prometheus metrics (planned)
      # {:prometheus_phoenix, "~> 1.3"},  # Phase 2 Extended: Phoenix integration (planned)
      # Environment & Config
      {:dotenvy, "~> 0.4.0"},
      # Error tracking (optional) - disabled for now, enable with valid SENTRY_DSN
      # {:sentry, "~> 10.0"},
      # Clustering & Distribution
      {:libcluster, "~> 3.3"},
      # Fast event batching
      {:broadway, "~> 1.0"},
      # Rate limiting
      {:hammer, "~> 6.0"},
      # Native performance (NIF bindings)
      # {:rustler, "~> 0.32"}  # Temporarily disabled - requires nmake
    ]
  end
end
