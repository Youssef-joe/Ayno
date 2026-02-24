defmodule Polyglot.SessionStore do
  @moduledoc """
  Redis-backed storage for sessions and ephemeral presence state.
  """

  require Logger

  @session_prefix "session"
  @presence_prefix "presence"

  def put_session(app_id, session_id, user_id, ttl_seconds \\ session_ttl_seconds())
      when is_binary(app_id) and is_binary(session_id) and is_binary(user_id) and ttl_seconds > 0 do
    payload =
      Jason.encode!(%{
        "app_id" => app_id,
        "session_id" => session_id,
        "user_id" => user_id,
        "updated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      })

    command(["SETEX", session_key(app_id, session_id), Integer.to_string(ttl_seconds), payload])
  end

  def get_session(app_id, session_id) when is_binary(app_id) and is_binary(session_id) do
    case Redix.command(:redix, ["GET", session_key(app_id, session_id)]) do
      {:ok, nil} ->
        :not_found

      {:ok, payload} when is_binary(payload) ->
        case Jason.decode(payload) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, _} -> {:error, :invalid_session_payload}
        end

      {:error, reason} ->
        Logger.error("Failed to read session from Redis: #{inspect(reason)}")
        {:error, :redis_unavailable}
    end
  rescue
    _ ->
      {:error, :redis_unavailable}
  end

  def delete_session(app_id, session_id) when is_binary(app_id) and is_binary(session_id) do
    command(["DEL", session_key(app_id, session_id)])
  end

  def put_presence(app_id, user_id, ttl_seconds \\ presence_ttl_seconds())
      when is_binary(app_id) and is_binary(user_id) and ttl_seconds > 0 do
    command([
      "SETEX",
      presence_key(app_id, user_id),
      Integer.to_string(ttl_seconds),
      DateTime.utc_now() |> DateTime.to_iso8601()
    ])
  end

  def delete_presence(app_id, user_id) when is_binary(app_id) and is_binary(user_id) do
    command(["DEL", presence_key(app_id, user_id)])
  end

  defp command(cmd) do
    case Redix.command(:redix, cmd) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error("Redis command failed #{inspect(cmd)}: #{inspect(reason)}")
        {:error, :redis_unavailable}
    end
  rescue
    _ ->
      {:error, :redis_unavailable}
  end

  defp session_key(app_id, session_id), do: "#{@session_prefix}:#{app_id}:#{session_id}"
  defp presence_key(app_id, user_id), do: "#{@presence_prefix}:#{app_id}:#{user_id}"

  defp session_ttl_seconds do
    Application.get_env(:polyglot, :session_store, [])
    |> Keyword.get(:session_ttl_seconds, 3600)
  end

  defp presence_ttl_seconds do
    Application.get_env(:polyglot, :session_store, [])
    |> Keyword.get(:presence_ttl_seconds, 120)
  end
end
