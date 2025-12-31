defmodule Polyglot.Repo do
  use Ecto.Repo,
    otp_app: :polyglot,
    adapter: Ecto.Adapters.Postgres
end
