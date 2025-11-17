defmodule Polyglot.Gateway.Endpoint do
  use Phoenix.Endpoint, otp_app: :polyglot

  socket "/socket", Polyglot.Gateway.Socket,
    websocket: true,
    longpoll: false

  # Security & Observability Plugs (order matters)
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # Security headers
  plug Polyglot.Plugs.SecurityHeaders

  # Body parsing
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  # Request logging
  plug Plug.Logger, log: :debug

  plug Polyglot.Gateway.Router
end