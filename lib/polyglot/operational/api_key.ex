defmodule Polyglot.Operational.APIKey do
  @moduledoc """
  Postgres-backed API key record used for app authentication.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "api_keys" do
    field(:app_id, :string)
    field(:key_hash, :string)
    field(:status, :string, default: "active")
    field(:rate_limit, :integer, default: 1000)
    field(:rate_window_seconds, :integer, default: 60)
    field(:last_used_at, :utc_datetime)
    timestamps()
  end

  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:app_id, :key_hash, :status, :rate_limit, :rate_window_seconds, :last_used_at])
    |> validate_required([:app_id, :key_hash, :status])
    |> validate_inclusion(:status, ["active", "disabled", "revoked"])
    |> validate_number(:rate_limit, greater_than: 0)
    |> validate_number(:rate_window_seconds, greater_than: 0)
    |> unique_constraint(:app_id)
    |> unique_constraint(:key_hash)
  end

  def hash_raw_key(raw_key) when is_binary(raw_key) do
    digest = :crypto.hash(:sha256, raw_key) |> Base.encode16(case: :lower)
    "sha256:" <> digest
  end

  def valid_raw_key?(%__MODULE__{key_hash: stored_hash}, raw_key)
      when is_binary(stored_hash) and is_binary(raw_key) do
    candidate_hash = hash_raw_key(raw_key)

    cond do
      String.starts_with?(stored_hash, "sha256:") ->
        secure_compare(candidate_hash, stored_hash)

      true ->
        secure_compare(raw_key, stored_hash)
    end
  end

  def valid_raw_key?(_, _), do: false

  defp secure_compare(left, right) when byte_size(left) == byte_size(right) do
    Plug.Crypto.secure_compare(left, right)
  end

  defp secure_compare(_, _), do: false
end
