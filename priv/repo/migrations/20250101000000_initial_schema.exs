defmodule Polyglot.Repo.Migrations.InitialSchema do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS pgcrypto", "")

    # API Keys table for authentication
    create table(:api_keys, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :app_id, :string, null: false
      add :key_hash, :string, null: false
      add :status, :string, default: "active", null: false
      add :rate_limit, :integer, default: 1000
      add :rate_window_seconds, :integer, default: 60
      add :last_used_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:api_keys, [:app_id])
    create unique_index(:api_keys, [:key_hash])
    create index(:api_keys, [:status])

    # Request logs table
    create table(:request_logs, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :app_id, :string, null: false
      add :endpoint, :string, null: false
      add :method, :string, null: false
      add :status_code, :integer
      add :response_time_ms, :integer
      add :error_message, :text
      add :ip_address, :string
      timestamps(type: :utc_datetime)
    end

    create index(:request_logs, [:app_id])
    create index(:request_logs, [:inserted_at])
    create index(:request_logs, [:status_code])

    # Processing jobs table for async task tracking
    create table(:jobs, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :app_id, :string, null: false
      add :processor_type, :string, null: false
      add :input_data, :jsonb, null: false
      add :output_data, :jsonb
      add :status, :string, default: "pending", null: false
      add :error_message, :text
      add :retry_count, :integer, default: 0
      add :max_retries, :integer, default: 3
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:jobs, [:app_id])
    create index(:jobs, [:status])
    create index(:jobs, [:processor_type])
    create index(:jobs, [:inserted_at])

    # Metrics/Analytics table
    create table(:metrics, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :app_id, :string, null: false
      add :metric_type, :string, null: false
      add :metric_name, :string, null: false
      add :value, :float, null: false
      add :tags, :jsonb
      timestamps(type: :utc_datetime)
    end

    create index(:metrics, [:app_id])
    create index(:metrics, [:metric_type])
    create index(:metrics, [:metric_name])
    create index(:metrics, [:inserted_at])
  end
end
