defmodule Polyglot.CircuitBreaker do
  @moduledoc """
  Circuit breaker pattern for fault tolerance.
  Prevents cascading failures when processor goes down.
  """

  use GenServer
  require Logger

  @failure_threshold 5
  @recovery_timeout 30_000  # 30 seconds

  def start_link(name) do
    GenServer.start_link(__MODULE__, {name, :closed}, name: name)
  end

  def init({name, state}) do
    {:ok, %{name: name, state: state, failures: 0, last_failure: nil}}
  end

  def call(breaker, fun) do
    GenServer.call(breaker, {:call, fun})
  end

  def handle_call({:call, fun}, _from, state) do
    case state.state do
      :closed ->
        try do
          result = fun.()
          {:reply, {:ok, result}, %{state | failures: 0}}
        rescue
          e ->
            failures = state.failures + 1
            Logger.warn("Circuit breaker failure #{failures}: #{inspect(e)}")

            new_state =
              if failures >= @failure_threshold do
                Logger.error("Circuit breaker OPEN - too many failures")
                %{state | state: :open, failures: failures, last_failure: System.monotonic_time(:millisecond)}
              else
                %{state | failures: failures}
              end

            {:reply, {:error, :failed}, new_state}
        end

      :open ->
        elapsed = System.monotonic_time(:millisecond) - state.last_failure

        if elapsed >= @recovery_timeout do
          Logger.info("Circuit breaker attempting HALF_OPEN recovery")
          {:reply, {:error, :open}, %{state | state: :half_open}}
        else
          {:reply, {:error, :open}, state}
        end

      :half_open ->
        try do
          result = fun.()
          Logger.info("Circuit breaker recovered to CLOSED")
          {:reply, {:ok, result}, %{state | state: :closed, failures: 0}}
        rescue
          e ->
            Logger.error("Circuit breaker recovery failed: #{inspect(e)}")
            {:reply, {:error, :failed}, %{state | state: :open, last_failure: System.monotonic_time(:millisecond)}}
        end
    end
  end

  def status(breaker) do
    GenServer.call(breaker, :status)
  end

  def handle_call(:status, _from, state) do
    {:reply, %{state: state.state, failures: state.failures}, state}
  end
end
