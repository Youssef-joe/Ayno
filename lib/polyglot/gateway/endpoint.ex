defmodule Polyglot.Gateway.Endpoint do
  use Phoenix.Endpoint, otp_app: :polyglot

  socket "/socket", Polyglot.Gateway.Socket,
    websocket: true,
    longpoll: false

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Polyglot.Gateway.Router
end