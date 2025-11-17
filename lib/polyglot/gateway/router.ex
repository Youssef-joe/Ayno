defmodule Polyglot.Gateway.Router do
  use Plug.Router
  require Logger

  plug :match
  plug :dispatch

  @processor_url System.get_env("GO_PROCESSOR_URL", "http://localhost:8080")
  @processor_timeout 5000

  # Publish event to channel
  post "/apps/:app_id/channels/:channel/publish" do
    Logger.info("Publish request - app: #{app_id}, channel: #{channel}")

    with {:auth, :ok} <- {:auth, Polyglot.Auth.verify_app_key(conn, app_id)},
         {:body, {:ok, body, _}} <- {:body, Plug.Conn.read_body(conn, size: 1_000_000)},
         {:json, {:ok, data}} <- {:json, Jason.decode(body)},
         {:validate, true} <- {:validate, valid_event?(data)} do
      handle_publish(conn, app_id, channel, data)
    else
      {:auth, {:error, _}} ->
        Logger.warning("Unauthorized publish attempt - app: #{app_id}")
        send_error(conn, 401, "Unauthorized")

      {:body, {:error, _}} ->
        Logger.error("Failed to read request body for app: #{app_id}")
        send_error(conn, 400, "Failed to read request body")

      {:json, {:error, _}} ->
        Logger.warning("Invalid JSON in publish request")
        send_error(conn, 400, "Invalid JSON payload")

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