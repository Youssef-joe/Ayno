defmodule Polyglot.Gateway.MatchChannel do
  use Phoenix.Channel

  def join("match:" <> match_id, _params, socket) do
    topic = "#{socket.assigns.app_id}:match:#{match_id}"
    Phoenix.PubSub.subscribe(Polyglot.PubSub, topic)
    {:ok, socket}
  end

  def handle_in("publish", %{"type" => type, "data" => data}, socket) do
    event = %{
      id: "evt_#{System.unique_integer([:positive])}",
      app_id: socket.assigns.app_id,
      channel: socket.topic,
      type: type,
      data: data,
      meta: %{
        user_id: socket.assigns.user_id,
        ts: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }

    Phoenix.PubSub.broadcast(Polyglot.PubSub, "#{socket.assigns.app_id}:#{socket.topic}", {:event, event})
    {:reply, {:ok, %{id: event.id}}, socket}
  end

  def handle_info({:event, event}, socket) do
    push(socket, "event", event)
    {:noreply, socket}
  end
end