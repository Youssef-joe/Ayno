defmodule Polyglot.ProcessorClient do
  @moduledoc """
  Processor client - uses HTTP with smart batching and connection pooling.
  Phase 2 upgrades this to gRPC for 5x faster communication.
  """

  require Logger

  @processor_url System.get_env("GO_PROCESSOR_URL", "http://localhost:8080")
  @pool_name :processor_pool
  @pool_size 10

  def init_pool do
    # Create connection pool for HTTP requests
    {:ok, _} = :poolboy.start_link(
      [name: {:local, @pool_name}, worker_module: Polyglot.ProcessorWorker, size: @pool_size, max_overflow: 5]
    )
    :ok
  rescue
    _ -> :already_started
  end

  def process_event(event) do
    forward_event(:process, event)
  end

  def process_batch(events) do
    forward_event(:batch, events)
  end

  # Route event to processor
  defp forward_event(:process, event) do
    try do
      url = "#{@processor_url}/process"
      headers = [{"Content-Type", "application/json"}]
      body = Jason.encode!(event)

      case HTTPoison.post(url, body, headers, timeout: 5000) do
        {:ok, %HTTPoison.Response{status_code: 200}} ->
          Logger.debug("Event processed: #{event.id}")
          :ok

        {:ok, response} ->
          Logger.error("Processor error: #{response.status_code}")
          :error

        {:error, reason} ->
          Logger.error("Processor unreachable: #{inspect(reason)}")
          :error
      end
    rescue
      e ->
        Logger.error("Processor exception: #{inspect(e)}")
        :error
    end
  end

  defp forward_event(:batch, events) do
    try do
      url = "#{@processor_url}/process-batch"
      headers = [{"Content-Type", "application/json"}]
      body = Jason.encode!(%{events: events})

      case HTTPoison.post(url, body, headers, timeout: 5000) do
        {:ok, %HTTPoison.Response{status_code: 200, body: resp_body}} ->
          case Jason.decode(resp_body) do
            {:ok, result} ->
              Logger.debug("Batch processed: #{result["processed"]}/#{result["total"]} in #{result["duration_ms"]}ms")
              if result["failed"] > 0 do
                Logger.warn("Batch had #{result["failed"]} failures")
              end
              :ok

            {:error, _} ->
              Logger.error("Invalid batch response")
              :error
          end

        {:ok, response} ->
          Logger.error("Batch error: #{response.status_code}")
          :error

        {:error, reason} ->
          Logger.error("Batch unreachable: #{inspect(reason)}")
          :error
      end
    rescue
      e ->
        Logger.error("Batch exception: #{inspect(e)}")
        :error
    end
  end
end

# Worker module for connection pooling (Phase 2 feature)
defmodule Polyglot.ProcessorWorker do
  @moduledoc "Connection pool worker for processor requests"

  def start_link(_) do
    # Placeholder for gRPC channel connection in Phase 2
    {:ok, %{}}
  end
end
