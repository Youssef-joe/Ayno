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

  # Run "mix help deps" to learn about dependencies.
  defp deps do
  [
  {:phoenix, "~> 1.7"},
  {:phoenix_pubsub, "~> 2.1"},
  {:phoenix_pubsub_redis, "~> 1.1"},
  {:plug_cowboy, "~> 2.5"},
  {:jason, "~> 1.2"},
  {:redix, "~> 1.2"},
      {:httpoison, "~> 2.0"}
    ]
  end
end
