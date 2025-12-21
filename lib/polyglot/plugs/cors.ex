defmodule Polyglot.Plugs.CORS do
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "Content-Type, X-API-Key, Authorization")
    |> handle_options()
  end

  defp handle_options(%{method: "OPTIONS"} = conn) do
    conn |> send_resp(200, "") |> halt()
  end

  defp handle_options(conn), do: conn
end
