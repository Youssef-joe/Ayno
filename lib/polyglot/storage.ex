defmodule Polyglot.Storage do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    :ets.new(:event_history, [:named_table, :public, :duplicate_bag])
    {:ok, %{}}
  end

  def store_event(channel, event) do
    :ets.insert(:event_history, {channel, event})
  end

  def get_history(channel, limit \\ 100) do
    case :ets.lookup(:event_history, channel) do
      events when is_list(events) ->
        events
        |> Enum.take(limit)
        |> Enum.map(fn {_channel, event} -> event end)
        |> Enum.reverse()

      _ ->
        []
    end
  end
end
