defmodule Polyglot.AuthTest do
  use ExUnit.Case

  test "verifies valid token" do
    assert {:ok, "user123"} = Polyglot.Auth.verify_token("valid_token_user123", "test-app")
  end

  test "rejects invalid token" do
    assert {:error, :invalid_token} = Polyglot.Auth.verify_token("invalid", "test-app")
  end

  test "verifies valid app key" do
    conn = %Plug.Conn{req_headers: [{"x-api-key", "valid_key_test-app"}]}
    assert :ok = Polyglot.Auth.verify_app_key(conn, "test-app")
  end

  test "rejects invalid app key" do
    conn = %Plug.Conn{req_headers: [{"x-api-key", "invalid"}]}
    assert {:error, :unauthorized} = Polyglot.Auth.verify_app_key(conn, "test-app")
  end
end
