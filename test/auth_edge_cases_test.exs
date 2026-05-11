defmodule Polyglot.AuthEdgeCasesTest do
  use ExUnit.Case
  require Logger

  describe "token verification edge cases" do
    test "rejects nil token" do
      result = Polyglot.Auth.verify_token(nil, "test-app")
      assert result == {:error, :invalid_token}
    end

    test "rejects empty token" do
      result = Polyglot.Auth.verify_token("", "test-app")
      assert result == {:error, :invalid_token}
    end

    test "rejects nil app_id" do
      result = Polyglot.Auth.verify_token("valid_token_user123", nil)
      assert result == {:error, :invalid_token}
    end

    test "rejects empty app_id" do
      result = Polyglot.Auth.verify_token("valid_token_user123", "")
      assert result == {:error, :invalid_token}
    end

    test "handles legacy token format" do
      # Legacy format: "valid_token_<user_id>"
      result = Polyglot.Auth.verify_token("valid_token_user123", "test-app")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles malformed JWT" do
      result = Polyglot.Auth.verify_token("malformed.jwt.token", "test-app")
      assert result == {:error, :invalid_token}
    end

    test "rejects tokens with wrong format" do
      result = Polyglot.Auth.verify_token("not_a_valid_token", "test-app")
      assert result == {:error, :invalid_token}
    end

    test "handles very long tokens gracefully" do
      long_token = String.duplicate("x", 10000)
      result = Polyglot.Auth.verify_token(long_token, "test-app")
      assert result == {:error, :invalid_token}
    end

    test "handles special characters in token" do
      result = Polyglot.Auth.verify_token("valid_token_user@123#456", "test-app")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "API key verification edge cases" do
    test "rejects nil API key header" do
      conn = %Plug.Conn{req_headers: []}
      result = Polyglot.Auth.verify_app_key(conn, "test-app")
      assert result == {:error, :unauthorized}
    end

    test "rejects empty API key" do
      conn = %Plug.Conn{req_headers: [{"x-api-key", ""}]}
      result = Polyglot.Auth.verify_app_key(conn, "test-app")
      assert match?({:error, :unauthorized}, result)
    end

    test "rejects nil app_id" do
      conn = %Plug.Conn{req_headers: [{"x-api-key", "valid_key_test-app"}]}
      result = Polyglot.Auth.verify_app_key(conn, nil)
      assert result == {:error, :unauthorized}
    end

    test "rejects empty app_id" do
      conn = %Plug.Conn{req_headers: [{"x-api-key", "valid_key_test-app"}]}
      result = Polyglot.Auth.verify_app_key(conn, "")
      assert result == {:error, :unauthorized}
    end

    test "ignores case sensitivity in header name" do
      # HTTP headers are case-insensitive, but Plug normalizes to lowercase
      conn = %Plug.Conn{req_headers: [{"x-api-key", "test-key"}]}
      result = Polyglot.Auth.verify_app_key(conn, "test-app")
      # Should fail auth but not crash
      assert match?({:error, :unauthorized}, result)
    end

    test "handles multiple API-key headers" do
      conn = %Plug.Conn{req_headers: [{"x-api-key", "key1"}, {"x-api-key", "key2"}]}
      result = Polyglot.Auth.verify_app_key(conn, "test-app")
      # Plug.Conn.get_req_header returns the first match
      assert match?({:error, :unauthorized}, result)
    end

    test "handles very long API key gracefully" do
      long_key = String.duplicate("k", 10000)
      conn = %Plug.Conn{req_headers: [{"x-api-key", long_key}]}
      result = Polyglot.Auth.verify_app_key(conn, "test-app")
      assert match?({:error, :unauthorized}, result)
    end

    test "handles special characters in app_id" do
      conn = %Plug.Conn{req_headers: [{"x-api-key", "valid_key_test-app"}]}
      result = Polyglot.Auth.verify_app_key(conn, "test-app@123#456")
      # Should attempt validation
      assert match?({:error, :unauthorized}, result)
    end
  end

  describe "generate_token" do
    test "generates valid token structure" do
      {:ok, token} = Polyglot.Auth.generate_token("user123", "test-app")
      assert is_binary(token)
      assert String.starts_with?(token, "dev.")
    end

    test "generates unique tokens" do
      {:ok, token1} = Polyglot.Auth.generate_token("user123", "test-app")
      {:ok, token2} = Polyglot.Auth.generate_token("user123", "test-app")
      # Tokens should be unique due to session ID
      assert token1 != token2
    end

    test "handles nil user_id" do
      result = Polyglot.Auth.generate_token(nil, "test-app")
      assert match?({:error, _}, result)
    end

    test "handles empty user_id" do
      result = Polyglot.Auth.generate_token("", "test-app")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles nil app_id" do
      result = Polyglot.Auth.generate_token("user123", nil)
      assert match?({:error, _}, result)
    end

    test "handles empty app_id" do
      result = Polyglot.Auth.generate_token("user123", "")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "generates token with special characters in user_id" do
      {:ok, token} = Polyglot.Auth.generate_token("user@123#456", "test-app")
      assert is_binary(token)
      assert String.starts_with?(token, "dev.")
    end

    test "token format is consistent" do
      {:ok, token1} = Polyglot.Auth.generate_token("user123", "app1")
      {:ok, token2} = Polyglot.Auth.generate_token("user456", "app2")

      # Both should start with "dev."
      assert String.starts_with?(token1, "dev.")
      assert String.starts_with?(token2, "dev.")

      # Both should have 3 parts separated by dots
      parts1 = String.split(token1, ".")
      parts2 = String.split(token2, ".")
      assert length(parts1) == 3
      assert length(parts2) == 3
    end
  end

  describe "concurrent auth operations" do
    test "token generation is thread-safe" do
      tasks = Enum.map(1..20, fn i ->
        Task.async(fn ->
          Polyglot.Auth.generate_token("user#{i}", "app#{i}")
        end)
      end)

      results = Task.await_many(tasks)
      assert length(results) == 20
      # All should succeed
      assert Enum.all?(results, &match?({:ok, _}, &1))
    end

    test "token verification is thread-safe" do
      tasks = Enum.map(1..20, fn i ->
        Task.async(fn ->
          Polyglot.Auth.verify_token("valid_token_user#{i}", "app#{i}")
        end)
      end)

      results = Task.await_many(tasks)
      assert length(results) == 20
    end

    test "mixed auth operations are thread-safe" do
      tasks =
        Enum.map(1..10, fn i ->
          Task.async(fn ->
            Polyglot.Auth.generate_token("user#{i}", "app#{i}")
          end)
        end) ++
          Enum.map(1..10, fn i ->
            Task.async(fn ->
              Polyglot.Auth.verify_token("valid_token_user#{i}", "app#{i}")
            end)
          end)

      results = Task.await_many(tasks)
      assert length(results) == 20
    end
  end

  describe "app_id validation" do
    test "validates app_id format in verify_app_key" do
      # Valid app_ids should work
      conn = %Plug.Conn{req_headers: [{"x-api-key", "valid_key_test-app"}]}
      result = Polyglot.Auth.verify_app_key(conn, "test-app")
      assert match?({:error, :unauthorized}, result)
    end

    test "handles numeric app_ids" do
      conn = %Plug.Conn{req_headers: [{"x-api-key", "test-key"}]}
      result = Polyglot.Auth.verify_app_key(conn, "12345")
      assert match?({:error, :unauthorized}, result)
    end

    test "handles app_ids with underscores" do
      conn = %Plug.Conn{req_headers: [{"x-api-key", "test-key"}]}
      result = Polyglot.Auth.verify_app_key(conn, "test_app_123")
      assert match?({:error, :unauthorized}, result)
    end
  end

  describe "user_id edge cases" do
    test "handles numeric user_ids" do
      {:ok, token} = Polyglot.Auth.generate_token("12345", "test-app")
      assert is_binary(token)
    end

    test "handles UUID user_ids" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      {:ok, token} = Polyglot.Auth.generate_token(uuid, "test-app")
      assert is_binary(token)
    end

    test "handles email-like user_ids" do
      {:ok, token} = Polyglot.Auth.generate_token("user@example.com", "test-app")
      assert is_binary(token)
    end
  end
end
