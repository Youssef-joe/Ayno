defmodule Polyglot.Gateway.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  post "/apps/:app_id/channels/:channel/publish" do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn),
         {:ok, data} <- Jason.decode(body),
         :ok <- Polyglot.Auth.verify_app_key(conn, app_id) do
      
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

      # Send to Go processor
      Task.start(fn -> forward_to_processor(event) end)
      
      # Broadcast to subscribers
      Phoenix.PubSub.broadcast(Polyglot.PubSub, "#{app_id}:#{channel}", {:event, event})
      
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{id: event.id}))
    else
      _ -> send_resp(conn, 400, "Invalid request")
    end
  end

  get "/apps/:app_id/channels/:channel/history" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{events: []}))
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp forward_to_processor(event) do
    HTTPoison.post("http://localhost:8080/process", Jason.encode!(event), [{"Content-Type", "application/json"}])
  end
end