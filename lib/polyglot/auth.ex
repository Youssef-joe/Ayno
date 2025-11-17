defmodule Polyglot.Auth do
  require Logger

  # JWT configuration
  @token_ttl 3600  # 1 hour
  @secret System.get_env("JWT_SECRET", "dev-secret-key")

  def verify_token(token, app_id) when is_binary(token) and is_binary(app_id) do
    try do
      case decode_token(token) do
        {:ok, claims} ->
          # Verify app_id matches
          if claims["app_id"] == app_id and claims["exp"] > System.system_time(:second) do
            {:ok, claims["sub"]}
          else
            Logger.warning("Invalid token claims for app: #{app_id}")
            {:error, :invalid_token}
          end

        {:error, reason} ->
          Logger.warning("JWT verification failed: #{inspect(reason)}")
          {:error, :invalid_token}
      end
    rescue
      e ->
        Logger.error("Token verification error: #{inspect(e)}")
        {:error, :token_error}
    end
  end

  def verify_token(_, _) do
    {:error, :invalid_token}
  end

  def verify_app_key(conn, app_id) when is_binary(app_id) do
    case Plug.Conn.get_req_header(conn, "x-api-key") do
      [key] ->
        # Validate API key format and check against stored keys
        case validate_api_key(key, app_id) do
          true ->
            :ok

          false ->
            Logger.warning("Invalid API key attempt for app: #{app_id}")
            {:error, :unauthorized}
        end

      _ ->
        Logger.warning("Missing API key header for app: #{app_id}")
        {:error, :unauthorized}
    end
  end

  def verify_app_key(_, _) do
    {:error, :unauthorized}
  end

  # Generate JWT token (for testing/debugging - use secure token service in production)
  def generate_token(user_id, app_id) when is_binary(user_id) and is_binary(app_id) do
    claims = %{
      "sub" => user_id,
      "app_id" => app_id,
      "exp" => System.system_time(:second) + @token_ttl,
      "iat" => System.system_time(:second)
    }

    # Simple JWT encoding without signing (for development)
    # In production, use proper JWT signing with secret
    encoded = Jason.encode!(claims) |> Base.url_encode64()
    {:ok, "dev.#{encoded}.sig"}
  end

  defp decode_token(token) do
    # Simple JWT decoding (development only)
    # In production, verify signature properly
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

  # Validate API key - check against simple format
  defp validate_api_key(key, app_id) do
    # Format: "valid_key_{app_id}" for demo purposes
    # In production, store hashed keys in Redis/Database
    expected_key = "valid_key_#{app_id}"

    case key do
      ^expected_key ->
        true

      _ ->
        # Fallback: validate format
        case String.split(key, "_") do
          [^app_id, hash] -> String.length(hash) > 20
          _ -> false
        end
    end
  end
end
