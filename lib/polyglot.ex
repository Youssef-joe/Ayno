defmodule Polyglot do
  @moduledoc """
  Polyglot Realtime Engine - Multi-tenant realtime platform
  """

  def publish(app_id, channel, event_data) do
    event = %{
      id: "evt_#{System.unique_integer([:positive])}",
      app_id: app_id,
      channel: channel,
      type: event_data["type"],
      data: event_data["data"],
      meta: %{
        ts: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }

    Phoenix.PubSub.broadcast(Polyglot.PubSub, "#{app_id}:#{channel}", {:event, event})

    # Send to Go processor for additional processing
    Task.start(fn ->
      HTTPoison.post("http://localhost:8080/process", Jason.encode!(event), [{"Content-Type", "application/json"}])
    end)

    {:ok, event.id}
  end
end
