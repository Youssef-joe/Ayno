defmodule Polyglot.Operational.TenantConfig do
  @moduledoc """
  Operational tenant config stored in Postgres.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "tenant_configs" do
    field(:app_id, :string)
    field(:name, :string)
    field(:status, :string, default: "active")
    field(:settings, :map, default: %{})
    timestamps()
  end

  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:app_id, :name, :status, :settings])
    |> validate_required([:app_id, :name, :status])
    |> validate_inclusion(:status, ["active", "suspended", "disabled"])
    |> unique_constraint(:app_id)
  end
end
