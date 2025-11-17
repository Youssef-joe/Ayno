defmodule Polyglot.Clustering do
  @moduledoc """
  Distributed clustering support for Polyglot.

  Enables multiple Elixir nodes to work together, sharing:
  - PubSub state (distributed)
  - Event processing (load balanced)
  - Presence tracking

  Strategies:
  - Kubernetes: Service discovery via DNS
  - Docker Compose: Static node list
  - Manual: Explicit node configuration
  """

  require Logger

  def start_link(_) do
    Logger.info("Starting Polyglot clustering...")

    topologies = topologies()

    {:ok, _} = Cluster.Supervisor.start_link(topologies: topologies)

    {:ok, self()}
  end

  # Get clustering configuration based on environment
  defp topologies do
    strategy = System.get_env("CLUSTER_STRATEGY", "static")

    case strategy do
      "kubernetes" -> kubernetes_topology()
      "dns" -> dns_topology()
      "redis" -> redis_topology()
      "static" -> static_topology()
      _ -> static_topology()
    end
  end

  # Kubernetes: Auto-discover nodes via service DNS
  defp kubernetes_topology do
    [
      polyglot: [
        strategy: Cluster.Strategy.Kubernetes.DNS,
        config: [
          service: System.get_env("K8S_SERVICE_NAME", "polyglot"),
          namespace: System.get_env("K8S_NAMESPACE", "default"),
          polling_interval: 5_000
        ]
      ]
    ]
  end

  # DNS-based discovery (works with Docker, Consul, etc.)
  defp dns_topology do
    [
      polyglot: [
        strategy: Cluster.Strategy.DNSPoll,
        config: [
          polling_interval: 5_000,
          query: System.get_env("DNS_QUERY", "polyglot.local")
        ]
      ]
    ]
  end

  # Redis-based node discovery
  defp redis_topology do
    [
      polyglot: [
        strategy: Cluster.Strategy.Epmd,
        config: [
          hosts: [
            String.to_atom(System.get_env("REDIS_HOST", "localhost"))
          ]
        ]
      ]
    ]
  end

  # Static node list (for docker-compose, simple deployments)
  defp static_topology do
    nodes =
      System.get_env("CLUSTER_NODES", "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.map(&String.to_atom/1)

    case nodes do
      [] ->
        # No clustering, single node
        Logger.info("No cluster nodes configured, running single-node mode")
        [polyglot: [strategy: Cluster.Strategy.Epmd, config: []]]

      _ ->
        Logger.info("Clustering with nodes: #{inspect(nodes)}")

        [
          polyglot: [
            strategy: Cluster.Strategy.Epmd,
            config: [hosts: nodes]
          ]
        ]
    end
  end

  @doc """
  Get all connected nodes in the cluster.
  """
  def nodes do
    Node.list()
  end

  @doc """
  Get node count (including self).
  """
  def node_count do
    length(Node.list()) + 1
  end

  @doc """
  Check if clustering is enabled.
  """
  def enabled? do
    node_count() > 1
  end

  @doc """
  Broadcast event to all nodes in cluster.
  """
  def broadcast(app_id, channel, event) do
    Phoenix.PubSub.broadcast(Polyglot.PubSub, "#{app_id}:#{channel}", {:event, event})
  end

  @doc """
  Get current node name.
  """
  def node_name do
    Node.self()
  end
end
