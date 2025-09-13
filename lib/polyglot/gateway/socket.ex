defmodule Polyglot.Gateway.Socket do
  use Phoenix.Socket

  channel "room:*", Polyglot.Gateway.RoomChannel
  channel "ticker:*", Polyglot.Gateway.TickerChannel
  channel "match:*", Polyglot.Gateway.MatchChannel
  channel "post:*", Polyglot.Gateway.PostChannel

  def connect(%{"app_id" => app_id, "token" => token}, socket, _connect_info) do
    case Polyglot.Auth.verify_token(token, app_id) do
      {:ok, user_id} ->
        socket = assign(socket, :app_id, app_id)
        socket = assign(socket, :user_id, user_id)
        {:ok, socket}
      {:error, _} ->
        :error
    end
  end

  def id(socket), do: "user_socket:#{socket.assigns.app_id}:#{socket.assigns.user_id}"
end