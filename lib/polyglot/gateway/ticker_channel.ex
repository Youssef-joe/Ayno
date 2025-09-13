defmodule Polyglot.Gateway.TickerChannel do
  use Phoenix.Channel

  def join("ticker:" <> symbol, _params, socket) do
    topic = "#{socket.assigns.app_id}:ticker:#{symbol}"
    Phoenix.PubSub.subscribe(Polyglot.PubSub, topic)
    {:ok, socket}
  end

  def handle_info({:event, event}, socket) do
    push(socket, "event", event)
    {:noreply, socket}
  end
end