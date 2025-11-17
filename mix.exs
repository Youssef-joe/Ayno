defmodule Polyglot.MixProject do
  use Mix.Project

  def project do
    [
      app: :polyglot,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run ya jjoooe mtnsash "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Polyglot.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_pubsub_redis, "~> 1.1"},
      {:plug_cowboy, "~> 2.5"},
      {:jason, "~> 1.2"},
      {:redix, "~> 1.2"},
      {:httpoison, "~> 2.0"},
      # Authentication & Security
      {:joken, "~> 2.6"},
      {:bcrypt_elixir, "~> 3.1"},
      # Rate limiting & throttling
      {:hammer, "~> 6.1"},
      # Observability
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      # Environment & Config
      {:dotenvy, "~> 0.4.0"},
      # Error tracking (optional)
      {:sentry, "~> 10.0"},
      # Clustering & Distribution
      {:libcluster, "~> 3.3"},
      # Fast event batching
      {:broadway, "~> 1.0"},
      # Native performance (NIF bindings)
      {:rustler, "~> 0.32"}
    ]
  end
end
