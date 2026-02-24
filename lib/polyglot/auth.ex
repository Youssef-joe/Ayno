defmodule Polyglot.Auth do
  require Logger

  @token_ttl 3600
  @legacy_token_prefix "valid_token_"
  @secret System.get_env("JWT_SECRET", "dev-secret-key")

  def verify_token(token, app_id) when is_binary(token) and is_binary(app_id) do
    case decode_token(token, app_id) do
      {:ok, claims} ->
        user_id = claims["sub"]

        with :ok <- validate_claims(claims, app_id),
             :ok <- maybe_validate_tenant(app_id),
             :ok <- maybe_validate_user_record(app_id, user_id),
             :ok <- validate_session(app_id, user_id, claims) do
          Polyglot.Operational.touch_user_last_seen(app_id, user_id)
          {:ok, user_id}
        else
          {:error, reason} ->
            Logger.warning("Token rejected for app #{app_id}: #{inspect(reason)}")
            {:error, :invalid_token}
        end

      {:error, reason} ->
        Logger.warning("Token decode failed for app #{app_id}: #{inspect(reason)}")
        {:error, :invalid_token}
    end
  rescue
    e ->
      Logger.error("Token verification error: #{inspect(e)}")
      {:error, :token_error}
  end

  def verify_token(_, _) do
    {:error, :invalid_token}
  end

  def verify_app_key(conn, app_id) when is_binary(app_id) do
    case maybe_validate_tenant(app_id) do
      :ok ->
        case Plug.Conn.get_req_header(conn, "x-api-key") do
          [key] ->
            case Polyglot.Operational.validate_api_key(app_id, key) do
              {:ok, _} ->
                :ok

              {:error, _reason} ->
                if allow_legacy_api_keys?() and validate_legacy_api_key(key, app_id) do
                  Logger.warning("Using legacy API key fallback for app: #{app_id}")
                  :ok
                else
                  Logger.warning("Invalid API key attempt for app: #{app_id}")
                  {:error, :unauthorized}
                end
            end

          _ ->
            Logger.warning("Missing API key header for app: #{app_id}")
            {:error, :unauthorized}
        end

      {:error, reason} ->
        Logger.warning("Tenant validation failed for app #{app_id}: #{inspect(reason)}")
        {:error, :unauthorized}
    end
  end

  def verify_app_key(_, _) do
    {:error, :unauthorized}
  end

  def generate_token(user_id, app_id) when is_binary(user_id) and is_binary(app_id) do
    session_id = "sess_" <> Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
    now = System.system_time(:second)

    claims = %{
      "sub" => user_id,
      "app_id" => app_id,
      "sid" => session_id,
      "exp" => now + @token_ttl,
      "iat" => now
    }

    with :ok <- Polyglot.SessionStore.put_session(app_id, session_id, user_id, @token_ttl) do
      encoded = Jason.encode!(claims) |> Base.url_encode64()
      {:ok, "dev.#{encoded}.sig"}
    else
      {:error, reason} ->
        Logger.error("Could not create Redis-backed session: #{inspect(reason)}")
        {:error, :session_unavailable}
    end
  end

  defp decode_token(token, app_id) do
    cond do
      String.starts_with?(token, @legacy_token_prefix) ->
        user_id = String.replace_prefix(token, @legacy_token_prefix, "")

        {:ok,
         %{
           "sub" => user_id,
           "app_id" => app_id,
           "exp" => System.system_time(:second) + 60
         }}

      true ->
        decode_dev_token(token)
    end
  end

  defp decode_dev_token(token) do
    case String.split(token, ".") do
      ["dev", encoded, "sig"] ->
        try do
          decoded = Base.url_decode64!(encoded)
          {:ok, Jason.decode!(decoded)}
        rescue
          _ -> {:error, :invalid_token}
        end

      _ ->
        {:error, :invalid_token}
    end
  end

  defp validate_claims(%{"sub" => user_id, "app_id" => claim_app_id, "exp" => exp}, app_id)
       when is_binary(user_id) and is_binary(claim_app_id) and is_integer(exp) do
    cond do
      claim_app_id != app_id ->
        {:error, :app_mismatch}

      exp <= System.system_time(:second) ->
        {:error, :expired}

      true ->
        :ok
    end
  end

  defp validate_claims(_, _), do: {:error, :invalid_claims}

  defp maybe_validate_tenant(app_id) do
    case Polyglot.Operational.fetch_active_tenant(app_id) do
      {:ok, nil} ->
        if require_tenant_config?() do
          {:error, :tenant_not_found}
        else
          :ok
        end

      {:ok, _tenant} ->
        :ok

      {:error, _reason} ->
        if require_tenant_config?() do
          {:error, :tenant_unavailable}
        else
          :ok
        end
    end
  end

  defp maybe_validate_user_record(_app_id, nil), do: {:error, :missing_user_id}

  defp maybe_validate_user_record(app_id, user_id) do
    case Polyglot.Operational.fetch_user_record(app_id, user_id) do
      {:ok, %Polyglot.Operational.UserRecord{status: "active"}} ->
        :ok

      {:ok, %Polyglot.Operational.UserRecord{}} ->
        {:error, :user_inactive}

      {:ok, nil} ->
        if require_user_records?() do
          {:error, :user_not_found}
        else
          :ok
        end

      {:error, _reason} ->
        if require_user_records?() do
          {:error, :user_unavailable}
        else
          :ok
        end
    end
  end

  defp validate_session(app_id, user_id, %{"sid" => session_id}) when is_binary(session_id) do
    case Polyglot.SessionStore.get_session(app_id, session_id) do
      {:ok, %{"user_id" => ^user_id}} ->
        Polyglot.SessionStore.put_session(app_id, session_id, user_id)
        :ok

      {:ok, _} ->
        {:error, :session_user_mismatch}

      :not_found ->
        {:error, :session_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_session(_app_id, _user_id, _claims), do: :ok

  defp validate_legacy_api_key(key, app_id) do
    expected_key = "valid_key_#{app_id}"

    case key do
      ^expected_key ->
        true

      _ ->
        case String.split(key, "_") do
          [^app_id, hash] -> String.length(hash) > 20
          _ -> false
        end
    end
  end

  defp require_tenant_config? do
    auth_config()
    |> Keyword.get(:require_tenant_config, false)
  end

  defp require_user_records? do
    auth_config()
    |> Keyword.get(:require_user_records, false)
  end

  defp allow_legacy_api_keys? do
    auth_config()
    |> Keyword.get(:allow_legacy_api_keys, false)
  end

  defp auth_config do
    Application.get_env(:polyglot, :auth, [])
  end

  # Keep secret available for future signed token support.
  def secret, do: @secret
end
