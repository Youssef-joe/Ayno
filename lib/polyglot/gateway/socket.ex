defmodule Polyglot.Gateway.Socket do
  use Phoenix.Socket
  require Logger

  channel("room:*", Polyglot.Gateway.RoomChannel)
  channel("ticker:*", Polyglot.Gateway.TickerChannel)
  channel("match:*", Polyglot.Gateway.MatchChannel)
  channel("post:*", Polyglot.Gateway.PostChannel)

  # Authentication with token
  def connect(%{"app_id" => app_id, "token" => token}, socket, _connect_info) do
    Logger.info(
      "WebSocket connect attempt - app: #{app_id}, token: #{String.slice(token, 0, 20)}..."
    )

    case Polyglot.Auth.verify_token(token, app_id) do
      {:ok, user_id} ->
        Logger.info("WebSocket authenticated - app: #{app_id}, user: #{user_id}")
        _ = Polyglot.SessionStore.put_presence(app_id, user_id)
        socket = assign(socket, :app_id, app_id)
        socket = assign(socket, :user_id, user_id)
        {:ok, socket}

      {:error, reason} ->
        Logger.warning("WebSocket auth failed - app: #{app_id}, reason: #{inspect(reason)}")
        :error
    end
  end

  # Fallback: allow test connections without proper auth (dev only)
  def connect(%{"app_id" => app_id}, socket, _connect_info) do
    Logger.warning("WebSocket connecting without token - app: #{app_id} (dev mode)")
    user_id = "anonymous_#{System.unique_integer([:positive])}"
    _ = Polyglot.SessionStore.put_presence(app_id, user_id)
    socket = assign(socket, :app_id, app_id)
    socket = assign(socket, :user_id, user_id)
    {:ok, socket}
  end

  # Reject connections without app_id
  def connect(params, _socket, _connect_info) do
    Logger.warning("WebSocket connect rejected - params: #{inspect(params)}")
    :error
  end

  def id(socket) do
    app_id = Map.get(socket.assigns, :app_id, "unknown")
    user_id = Map.get(socket.assigns, :user_id, "unknown")
    "user_socket:#{app_id}:#{user_id}"
  end
end
