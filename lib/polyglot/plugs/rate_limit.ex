defmodule Polyglot.Plugs.RateLimit do
  import Plug.Conn
  require Logger

  def init(opts) do
    opts
  end

  def call(conn, opts) do
    limit = Keyword.get(opts, :limit, 100)
    window = Keyword.get(opts, :window, 60)

    case get_identifier(conn) do
      {:ok, identifier} ->
        case check_rate_limit(identifier, limit, window) do
          :ok ->
            conn

          :exceeded ->
            Logger.warning("Rate limit exceeded for: #{identifier}")

            conn
            |> put_status(429)
            |> put_resp_content_type("application/json")
            |> send_resp(429, Jason.encode!(%{error: "Rate limit exceeded", retry_after: window}))
            |> halt()
        end

      :error ->
        # Could not identify client, allow through but log
        Logger.debug("Could not identify client for rate limiting")
        conn
    end
  end

  defp get_identifier(conn) do
    case Plug.Conn.get_req_header(conn, "x-api-key") do
      [key] -> {:ok, "api_key:#{key}"}
      _ -> {:ok, "ip:#{format_remote_ip(conn.remote_ip)}"}
    end
  end

  defp check_rate_limit(identifier, limit, window) do
    case :hammer.check_rate_limit(identifier, limit, window * 1000) do
      {:allow, _count} -> :ok
      {:deny, _limit} -> :exceeded
    end
  end

  defp format_remote_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp format_remote_ip({a, b, c, d, e, f, g, h}), do: "#{a}:#{b}:#{c}:#{d}:#{e}:#{f}:#{g}:#{h}"
end
