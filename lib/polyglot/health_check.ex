defmodule Polyglot.HealthCheck do
  @moduledoc """
  Health monitoring for critical services.
  Provides readiness and liveness checks for Kubernetes/orchestration.
  """

  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    # Check health every 10 seconds
    schedule_check()
    {:ok, %{state | go_processor: :unknown, redis: :unknown, checks_at: DateTime.utc_now()}}
  end

  def health_status do
    GenServer.call(__MODULE__, :status)
  end

  def handle_call(:status, _from, state) do
    {:reply, build_status(state), state}
  end

  def handle_info(:check_health, state) do
    new_state = %{
      state
      | go_processor: check_go_processor(),
        redis: check_redis(),
        checks_at: DateTime.utc_now()
    }

    schedule_check()
    {:noreply, new_state}
  end

  defp build_status(state) do
    all_healthy = state.go_processor == :healthy and state.redis == :healthy

    %{
      status: if(all_healthy, do: "healthy", else: "degraded"),
      checks: %{
        go_processor: state.go_processor,
        redis: state.redis
      },
      checked_at: state.checks_at,
      ready: all_healthy
    }
  end

  defp check_go_processor do
    processor_url = System.get_env("GO_PROCESSOR_URL", "http://localhost:8080")

    case HTTPoison.get("#{processor_url}/health", [], timeout: 2000) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        :healthy

      _ ->
        :unhealthy
    end
  rescue
    _ -> :unhealthy
  end

  defp check_redis do
    case Redix.command(:redix, ["PING"]) do
      {:ok, "PONG"} ->
        :healthy

      _ ->
        :unhealthy
    end
  rescue
    _ -> :unhealthy
  end

  defp schedule_check do
    Process.send_after(self(), :check_health, 10_000)
  end
end
