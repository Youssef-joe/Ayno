defmodule Polyglot.Storage do
  require Logger
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    :ets.new(:event_history, [:named_table, :public, :duplicate_bag])
    {:ok, %{}}
  end

  def store_event(channel, event) do
    if store_in_redis(channel, event) == :ok do
      :ok
    else
      :ets.insert(:event_history, {channel, event})
      :ok
    end
  end

  def get_history(channel, limit \\ 100) do
    case read_from_redis(channel, limit) do
      {:ok, events} -> events
      :fallback -> read_from_ets(channel, limit)
    end
  end

  defp store_in_redis(channel, event) do
    with true <- is_binary(channel),
         {:ok, encoded} <- Jason.encode(event),
         ttl when ttl > 0 <- history_ttl_seconds(),
         max_events when max_events > 0 <- history_max_events(),
         {:ok, _} <-
           Redix.pipeline(:redix, [
             ["LPUSH", history_key(channel), encoded],
             ["LTRIM", history_key(channel), "0", Integer.to_string(max_events - 1)],
             ["EXPIRE", history_key(channel), Integer.to_string(ttl)]
           ]) do
      :ok
    else
      {:error, reason} ->
        Logger.debug("Redis history store failed for #{channel}: #{inspect(reason)}")
        :fallback

      _ ->
        :fallback
    end
  rescue
    _ ->
      :fallback
  end

  defp read_from_redis(channel, limit) do
    safe_limit = min(max(limit, 1), history_max_events())

    case Redix.command(:redix, [
           "LRANGE",
           history_key(channel),
           "0",
           Integer.to_string(safe_limit - 1)
         ]) do
      {:ok, []} ->
        {:ok, []}

      {:ok, payloads} when is_list(payloads) ->
        events =
          payloads
          |> Enum.map(&decode_event/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.reverse()

        {:ok, events}

      {:error, _reason} ->
        :fallback
    end
  rescue
    _ ->
      :fallback
  end

  defp read_from_ets(channel, limit) do
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

  defp decode_event(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, decoded} -> decoded
      {:error, _} -> nil
    end
  end

  defp decode_event(_), do: nil

  defp history_key(channel), do: "history:#{channel}"

  defp history_ttl_seconds do
    Application.get_env(:polyglot, :storage, [])
    |> Keyword.get(:history_ttl_seconds, 3600)
  end

  defp history_max_events do
    Application.get_env(:polyglot, :storage, [])
    |> Keyword.get(:history_max_events, 1000)
  end
end
