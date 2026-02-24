defmodule Polyglot.Operational.UserRecord do
  @moduledoc """
  User identity record for a tenant stored in Postgres.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "user_records" do
    field(:app_id, :string)
    field(:user_id, :string)
    field(:status, :string, default: "active")
    field(:roles, {:array, :string}, default: [])
    field(:metadata, :map, default: %{})
    field(:last_seen_at, :utc_datetime)
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:app_id, :user_id, :status, :roles, :metadata, :last_seen_at])
    |> validate_required([:app_id, :user_id, :status])
    |> validate_inclusion(:status, ["active", "disabled", "deleted"])
    |> unique_constraint(:app_id, name: :user_records_app_id_user_id_index)
  end
end
