alias Polyglot.Operational.{APIKey, TenantConfig, UserRecord}
alias Polyglot.Repo

app_id = System.get_env("SEED_APP_ID", "demo-app")
app_name = System.get_env("SEED_APP_NAME", "Demo App")
seed_user_id = System.get_env("SEED_USER_ID", "demo-user")
seed_api_key = System.get_env("SEED_API_KEY", "demo-app-local-key")

tenant_attrs = %{
  app_id: app_id,
  name: app_name,
  status: "active",
  settings: %{"plan" => "dev"}
}

user_attrs = %{
  app_id: app_id,
  user_id: seed_user_id,
  status: "active",
  roles: ["member"],
  metadata: %{"seeded" => true}
}

api_key_attrs = %{
  app_id: app_id,
  key_hash: APIKey.hash_raw_key(seed_api_key),
  status: "active",
  rate_limit: 1_000,
  rate_window_seconds: 60
}

tenant_changeset = TenantConfig.changeset(%TenantConfig{}, tenant_attrs)

Repo.insert!(
  tenant_changeset,
  on_conflict: [set: [name: app_name, status: "active", settings: tenant_attrs.settings]],
  conflict_target: [:app_id]
)

user_changeset = UserRecord.changeset(%UserRecord{}, user_attrs)

Repo.insert!(
  user_changeset,
  on_conflict: [
    set: [
      status: "active",
      roles: user_attrs.roles,
      metadata: user_attrs.metadata
    ]
  ],
  conflict_target: [:app_id, :user_id]
)

api_key_changeset = APIKey.changeset(%APIKey{}, api_key_attrs)

Repo.insert!(
  api_key_changeset,
  on_conflict: [
    set: [
      key_hash: api_key_attrs.key_hash,
      status: "active",
      rate_limit: api_key_attrs.rate_limit,
      rate_window_seconds: api_key_attrs.rate_window_seconds
    ]
  ],
  conflict_target: [:app_id]
)

IO.puts("Seeded tenant #{app_id}")
IO.puts("Seeded user #{seed_user_id}")
IO.puts("Seeded API key #{seed_api_key}")
