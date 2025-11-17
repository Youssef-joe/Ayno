defmodule Polyglot.Plugs.SecurityHeaders do
  import Plug.Conn

  def init(_opts) do
    []
  end

  def call(conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "geolocation=(), microphone=(), camera=()")
    |> put_resp_header("strict-transport-security", "max-age=31536000; includeSubDomains")
  end
end
