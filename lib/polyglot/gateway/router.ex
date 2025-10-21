defmodule Polyglot.Gateway.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  post "/apps/:app_id/channels/:channel/publish" do
    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} ->
        case Jason.decode(body) do
          {:ok, data} ->
            case Polyglot.Auth.verify_app_key(conn, app_id) do
              :ok ->
                event = %{
                  id: "evt_#{System.unique_integer([:positive])}",
                  app_id: app_id,
                  channel: channel,
                  type: data["type"],
                  data: data["data"],
                  meta: %{
                    user_id: get_req_header(conn, "x-user-id") |> List.first(),
                    ts: DateTime.utc_now() |> DateTime.to_iso8601()
                  }
                }

                # Store event
                Polyglot.Storage.store_event(channel, event)

                # Send to Go processor
                Task.start(fn -> forward_to_processor(event) end)

                # Broadcast to subscribers
              Phoenix.PubSub.broadcast(Polyglot.PubSub, "#{app_id}:#{channel}", {:event, event})

              conn
              |> put_resp_content_type("application/json")
            |> send_resp(200, Jason.encode!(%{id: event.id}))

              {:error, :unauthorized} ->
                conn
                |> put_resp_content_type("application/json")
                |> send_resp(401, Jason.encode!(%{error: "Invalid API key"}))

              _ ->
                conn
                |> put_resp_content_type("application/json")
                |> send_resp(400, Jason.encode!(%{error: "Auth verification failed"}))
            end

          {:error, _} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(400, Jason.encode!(%{error: "Invalid JSON"}))
        end

      {:error, _} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: "Failed to read request body"}))
    end
  end

  get "/apps/:app_id/channels/:channel/history" do
    events = Polyglot.Storage.get_history(channel)
    conn
    |> put_resp_content_type("application/json")
  |> send_resp(200, Jason.encode!(%{events: events}))
  end

  get "/health" do
  conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{status: "ok", timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}))
  end

  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "Not found"}))
  end

  defp forward_to_processor(event) do
    HTTPoison.post("http://localhost:8080/process", Jason.encode!(event), [{"Content-Type", "application/json"}])
  end
end