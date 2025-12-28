defmodule Polyglot.Gateway.Router do
  use Plug.Router
  require Logger

  # Parse request body before matching
  plug :parse_body
  plug :match
  plug :dispatch

  defp parse_body(conn, _opts) do
    case Plug.Conn.get_req_header(conn, "content-type") do
      ["application/json" <> _] ->
        case Plug.Conn.read_body(conn) do
          {:ok, body, conn} ->
            case Jason.decode(body) do
              {:ok, params} ->
                %{conn | body_params: params}
              {:error, _} ->
                conn
            end
          {:error, _} ->
            conn
        end
      _ ->
        conn
    end
  end

  @processor_url System.get_env("GO_PROCESSOR_URL", "http://localhost:8080")
  @processor_timeout 5000

  # Publish event to channel
  post "/apps/:app_id/channels/:channel/publish" do
    Logger.info("Publish request - app: #{app_id}, channel: #{channel}")

    with {:auth, :ok} <- {:auth, Polyglot.Auth.verify_app_key(conn, app_id)},
         {:validate, true} <- {:validate, valid_event?(conn.body_params)} do
      handle_publish(conn, app_id, channel, conn.body_params)
    else
      {:auth, {:error, _}} ->
        Logger.warning("Unauthorized publish attempt - app: #{app_id}")
        send_error(conn, 401, "Unauthorized")

      {:validate, false} ->
        Logger.warning("Invalid event data - missing required fields")
        send_error(conn, 400, "Event must have 'type' and 'data' fields")

      error ->
        Logger.error("Unexpected error in publish: #{inspect(error)}")
        send_error(conn, 500, "Internal server error")
    end
  end

  # Get channel history
  get "/apps/:app_id/channels/:channel/history" do
    Logger.info("History request - app: #{app_id}, channel: #{channel}")

    limit = String.to_integer(conn.params["limit"] || "100")
    limit = min(limit, 1000)  # Cap at 1000 events

    events = Polyglot.Storage.get_history(channel, limit)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{
      app_id: app_id,
      channel: channel,
      count: length(events),
      events: events
    }))
  end

  # Serve static test file
  get "/test" do
    file_path = Path.join([File.cwd!(), "priv", "test_realtime.html"])
    case File.read(file_path) do
      {:ok, content} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, content)
      {:error, _} ->
        Logger.warning("Test file not found: #{file_path}")
        send_error(conn, 404, "Test file not found")
    end
  end

  # Serve load test file (HTTP)
  get "/loadtest" do
    file_path = Path.join([File.cwd!(), "priv", "load_test.html"])
    case File.read(file_path) do
      {:ok, content} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, content)
      {:error, _} ->
        Logger.warning("Load test file not found: #{file_path}")
        send_error(conn, 404, "Load test file not found")
    end
  end

  # Serve WebSocket load test file
  get "/loadtest-ws" do
    file_path = Path.join([File.cwd!(), "priv", "loadtest_ws.html"])
    case File.read(file_path) do
      {:ok, content} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, content)
      {:error, _} ->
        Logger.warning("WebSocket load test file not found: #{file_path}")
        send_error(conn, 404, "WebSocket load test file not found")
    end
  end

  # Proxy processor health check (to avoid CORS issues)
  get "/processor-health" do
    case HTTPoison.get("#{@processor_url}/health", [], timeout: 2000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, body)
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(status, body)
      {:error, reason} ->
        Logger.error("Failed to reach processor: #{inspect(reason)}")
        send_error(conn, 503, "Processor unavailable")
    end
  end

  # Health check
  get "/health" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{
      status: "ok",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      version: Application.spec(:polyglot, :vsn) |> to_string()
    }))
  end

  # Readiness check (for orchestration)
  get "/ready" do
    status = Polyglot.HealthCheck.health_status()
    
    http_status = if status.ready, do: 200, else: 503
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(http_status, Jason.encode!(status))
  end

  # Liveness check
  get "/alive" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{status: "alive"}))
  end

  # 404 handler
  match _ do
    Logger.warning("404 - Path not found: #{conn.request_path}")
    send_error(conn, 404, "Endpoint not found")
  end

  # Private helpers

  defp handle_publish(conn, app_id, channel, data) do
    event = build_event(app_id, channel, data, conn)

    # Store event
    Polyglot.Storage.store_event(channel, event)

    # Send to Go processor asynchronously (don't block on success/failure)
    Task.start(fn -> forward_to_processor(event) end)

    # Broadcast to subscribers
    Phoenix.PubSub.broadcast(Polyglot.PubSub, "#{app_id}:#{channel}", {:event, event})

    Logger.info("Event published - id: #{event.id}, channel: #{channel}")

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{
      id: event.id,
      timestamp: event.meta.ts
    }))
  end

  defp build_event(app_id, channel, data, conn) do
    %{
      id: "evt_#{System.unique_integer([:positive])}",
      app_id: app_id,
      channel: channel,
      type: data["type"],
      data: data["data"],
      meta: %{
        user_id: get_user_id(conn),
        ts: DateTime.utc_now() |> DateTime.to_iso8601(),
        source_ip: format_remote_ip(conn.remote_ip)
      }
    }
  end

  defp get_user_id(conn) do
    case Plug.Conn.get_req_header(conn, "x-user-id") do
      [user_id] -> user_id
      _ -> nil
    end
  end

  defp valid_event?(%{"type" => type, "data" => _data}) when is_binary(type), do: true
  defp valid_event?(_), do: false

  defp forward_to_processor(event) do
    try do
      HTTPoison.post(
        "#{@processor_url}/process",
        Jason.encode!(event),
        [{"Content-Type", "application/json"}],
        timeout: @processor_timeout
      )
    rescue
      e ->
        Logger.error("Failed to forward event to processor: #{inspect(e)}")
    end
  end

  defp send_error(conn, status, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{error: message}))
  end

  defp format_remote_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp format_remote_ip({a, b, c, d, e, f, g, h}), do: "#{a}:#{b}:#{c}:#{d}:#{e}:#{f}:#{g}:#{h}"
  defp format_remote_ip(_), do: "unknown"
end