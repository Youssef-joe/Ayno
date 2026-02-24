defmodule Polyglot.Operational do
  @moduledoc """
  Operational data access layer for tenant config, API keys, and user records.
  """

  import Ecto.Query
  require Logger

  alias Polyglot.Operational.{APIKey, TenantConfig, UserRecord}
  alias Polyglot.Repo

  def fetch_active_tenant(app_id) when is_binary(app_id) do
    query =
      from(t in TenantConfig,
        where: t.app_id == ^app_id and t.status == "active",
        limit: 1
      )

    safe_repo(fn -> Repo.one(query) end)
  end

  def fetch_user_record(app_id, user_id) when is_binary(app_id) and is_binary(user_id) do
    query =
      from(u in UserRecord,
        where: u.app_id == ^app_id and u.user_id == ^user_id,
        limit: 1
      )

    safe_repo(fn -> Repo.one(query) end)
  end

  def validate_api_key(app_id, raw_key) when is_binary(app_id) and is_binary(raw_key) do
    query =
      from(k in APIKey,
        where: k.app_id == ^app_id and k.status == "active",
        limit: 1
      )

    case safe_repo(fn -> Repo.one(query) end) do
      {:ok, nil} ->
        {:error, :api_key_not_found}

      {:ok, %APIKey{} = api_key} ->
        if APIKey.valid_raw_key?(api_key, raw_key) do
          touch_api_key_last_used(api_key.id)
          {:ok, api_key}
        else
          {:error, :invalid_api_key}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def validate_api_key(_, _), do: {:error, :invalid_api_key}

  def touch_user_last_seen(app_id, user_id) when is_binary(app_id) and is_binary(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    query =
      from(u in UserRecord,
        where: u.app_id == ^app_id and u.user_id == ^user_id
      )

    _ =
      safe_repo(fn ->
        Repo.update_all(query, set: [last_seen_at: now])
      end)

    :ok
  end

  def touch_user_last_seen(_, _), do: :ok

  defp touch_api_key_last_used(api_key_id) do
    Task.start(fn ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      query =
        from(k in APIKey,
          where: k.id == ^api_key_id
        )

      _ =
        safe_repo(fn ->
          Repo.update_all(query, set: [last_used_at: now])
        end)
    end)
  end

  defp safe_repo(fun) do
    {:ok, fun.()}
  rescue
    e in [DBConnection.ConnectionError, Postgrex.Error] ->
      Logger.error("Operational DB error: #{Exception.message(e)}")
      {:error, :db_unavailable}
  catch
    :exit, _ ->
      {:error, :db_unavailable}
  end
end
