defmodule Polyglot.Auth do
  def verify_token(token, app_id) do
    # Minimal JWT verification - would use proper JWT library
    case token do
      "valid_token_" <> user_id -> {:ok, user_id}
      _ -> {:error, :invalid_token}
    end
  end

  def verify_app_key(conn, app_id) do
    case Plug.Conn.get_req_header(conn, "x-api-key") do
      ["valid_key_" <> ^app_id] -> :ok
      _ -> {:error, :unauthorized}
    end
  end
end