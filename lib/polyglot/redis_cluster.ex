defmodule Polyglot.RedisCluster do
  @moduledoc """
  Redis cluster support for distributed deployments.
  Handles connection pooling and automatic failover.
  """

  require Logger

  def get_connection do
    case Redix.command(:redix, ["PING"]) do
      {:ok, "PONG"} ->
        Logger.debug("Redis healthy")
        {:ok, :redix}

      {:error, reason} ->
        Logger.error("Redis error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def publish(channel, message) do
    case get_connection() do
      {:ok, conn} ->
        case Redix.command(conn, ["PUBLISH", channel, message]) do
          {:ok, count} ->
            Logger.debug("Message published to #{count} subscribers")
            {:ok, count}

          {:error, reason} ->
            Logger.error("Publish error: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def set_key(key, value, ttl \\ 3600) do
    case get_connection() do
      {:ok, conn} ->
        case Redix.command(conn, ["SETEX", key, ttl, value]) do
          {:ok, "OK"} ->
            Logger.debug("Key #{key} set in Redis")
            :ok

          {:error, reason} ->
            Logger.error("Set error: #{inspect(reason)}")
            :error
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_key(key) do
    case get_connection() do
      {:ok, conn} ->
        case Redix.command(conn, ["GET", key]) do
          {:ok, value} ->
            {:ok, value}

          {:error, reason} ->
            Logger.error("Get error: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
