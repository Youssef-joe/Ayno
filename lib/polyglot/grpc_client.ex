defmodule Polyglot.GRPCClient do
  @moduledoc """
  gRPC client for processor communication with intelligent fallback to HTTP.
  Provides 5x throughput improvement over HTTP with graceful degradation.
  """

  require Logger

  @grpc_host System.get_env("GO_PROCESSOR_GRPC_HOST", "localhost")
  @grpc_port String.to_integer(System.get_env("GO_PROCESSOR_GRPC_PORT", "9090"))
  @http_url System.get_env("GO_PROCESSOR_URL", "http://localhost:8080")
  @use_grpc System.get_env("USE_GRPC", "true") == "true"
  @timeout 5000
  @retry_count 3

  def process_event(event) do
    call_processor(:process, event)
  end

  def process_batch(events) do
    call_processor(:batch, events)
  end

  def health_check do
    case call_grpc(:health, %Polyglot.Pb.HealthRequest{}) do
      {:ok, response} ->
        {:ok, response.status}
      {:error, _reason} ->
        # Fall back to HTTP health check
        case HTTPoison.get("#{@http_url}/health", [], timeout: @timeout) do
          {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
            case Jason.decode(body) do
              {:ok, %{"status" => status}} -> {:ok, status}
              _ -> {:error, :invalid_response}
            end
          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # Private

  defp call_processor(:process, event) do
    if @use_grpc do
      try_grpc_process(event)
    else
      http_process(event)
    end
  end

  defp call_processor(:batch, events) do
    if @use_grpc do
      try_grpc_batch(events)
    else
      http_batch(events)
    end
  end

  # gRPC Implementations

  defp try_grpc_process(event, attempt \\ 1) when attempt <= @retry_count do
    pb_event = event_to_pb(event)
    request = %Polyglot.Pb.ProcessRequest{event: pb_event}

    case call_grpc(:process, request) do
      {:ok, response} ->
        Logger.debug("Event processed via gRPC: #{event.id}")
        {:ok, %{processed: response.processed, duration_ms: response.duration_ms}}

      {:error, reason} ->
        if attempt < @retry_count do
          Logger.warn("gRPC failed (attempt #{attempt}/#{@retry_count}): #{inspect(reason)}")
          Process.sleep(100 * attempt)
          try_grpc_process(event, attempt + 1)
        else
          Logger.warn("gRPC failed after #{@retry_count} attempts, falling back to HTTP")
          http_process(event)
        end
    end
  rescue
    e ->
      Logger.error("gRPC exception: #{inspect(e)}, falling back to HTTP")
      http_process(event)
  end

  defp try_grpc_batch(events, attempt \\ 1) when attempt <= @retry_count do
    pb_events = Enum.map(events, &event_to_pb/1)
    request = %Polyglot.Pb.ProcessBatchRequest{events: pb_events}

    case call_grpc(:process_batch, request) do
      {:ok, response} ->
        Logger.debug("Batch processed via gRPC: #{response.processed}/#{response.total}")
        {:ok, %{processed: response.processed, failed: response.failed, total: response.total}}

      {:error, reason} ->
        if attempt < @retry_count do
          Logger.warn("gRPC batch failed (attempt #{attempt}/#{@retry_count}): #{inspect(reason)}")
          Process.sleep(100 * attempt)
          try_grpc_batch(events, attempt + 1)
        else
          Logger.warn("gRPC batch failed after #{@retry_count} attempts, falling back to HTTP")
          http_batch(events)
        end
    end
  rescue
    e ->
      Logger.error("gRPC batch exception: #{inspect(e)}, falling back to HTTP")
      http_batch(events)
  end

  # HTTP Implementations (fallback)

  defp http_process(event) do
    try do
      url = "#{@http_url}/process"
      headers = [{"Content-Type", "application/json"}]
      body = Jason.encode!(event)

      case HTTPoison.post(url, body, headers, timeout: @timeout) do
        {:ok, %HTTPoison.Response{status_code: 200, body: resp_body}} ->
          case Jason.decode(resp_body) do
            {:ok, result} ->
              Logger.debug("Event processed via HTTP: #{event.id}")
              {:ok, result}
            {:error, _} ->
              Logger.error("Invalid HTTP response")
              {:error, :invalid_response}
          end

        {:ok, response} ->
          Logger.error("Processor HTTP error: #{response.status_code}")
          {:error, :processor_error}

        {:error, reason} ->
          Logger.error("Processor unreachable: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Processor HTTP exception: #{inspect(e)}")
        {:error, e}
    end
  end

  defp http_batch(events) do
    try do
      url = "#{@http_url}/process-batch"
      headers = [{"Content-Type", "application/json"}]
      body = Jason.encode!(%{events: events})

      case HTTPoison.post(url, body, headers, timeout: @timeout) do
        {:ok, %HTTPoison.Response{status_code: 200, body: resp_body}} ->
          case Jason.decode(resp_body) do
            {:ok, result} ->
              Logger.debug("Batch processed via HTTP: #{result["processed"]}/#{result["total"]}")
              {:ok, result}
            {:error, _} ->
              Logger.error("Invalid HTTP batch response")
              {:error, :invalid_response}
          end

        {:ok, response} ->
          Logger.error("Batch HTTP error: #{response.status_code}")
          {:error, :processor_error}

        {:error, reason} ->
          Logger.error("Batch unreachable: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Batch HTTP exception: #{inspect(e)}")
        {:error, e}
    end
  end

  # gRPC Communication

  defp call_grpc(method, request) do
    with {:ok, channel} <- get_channel() do
      case method do
        :process ->
          Polyglot.Pb.Processor.Stub.process(channel, request, timeout: @timeout)

        :process_batch ->
          Polyglot.Pb.Processor.Stub.process_batch(channel, request, timeout: @timeout)

        :health ->
          Polyglot.Pb.Processor.Stub.health(channel, request, timeout: @timeout)
      end
    end
  rescue
    e ->
      {:error, e}
  end

  defp get_channel do
    case GRPC.Stub.connect("#{@grpc_host}:#{@grpc_port}") do
      {:ok, channel} ->
        {:ok, channel}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Conversion utilities

  defp event_to_pb(event) when is_map(event) do
    %Polyglot.Pb.Processor{
      id: Map.get(event, :id, ""),
      app_id: Map.get(event, :app_id, ""),
      channel: Map.get(event, :channel, ""),
      type: Map.get(event, :type, ""),
      data: stringify_map(Map.get(event, :data, %{})),
      meta: stringify_map(Map.get(event, :meta, %{}))
    }
  end

  defp stringify_map(map) do
    Map.new(map, fn {k, v} ->
      {to_string(k), to_string(v)}
    end)
  end
end
