defmodule Polyglot.Repo.Migrations.AddTenantAndUserRecords do
  use Ecto.Migration

  def change do
    create table(:tenant_configs, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :app_id, :string, null: false
      add :name, :string, null: false
      add :status, :string, default: "active", null: false
      add :settings, :map, default: %{}, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:tenant_configs, [:app_id])
    create index(:tenant_configs, [:status])

    create table(:user_records, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :app_id, :string, null: false
      add :user_id, :string, null: false
      add :status, :string, default: "active", null: false
      add :roles, {:array, :string}, default: [], null: false
      add :metadata, :map, default: %{}, null: false
      add :last_seen_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_records, [:app_id, :user_id])
    create index(:user_records, [:status])
  end
end
