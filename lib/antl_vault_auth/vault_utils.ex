defmodule AntlVaultAuth.VaultUtils do
  @moduledoc false

  @spec vault_hash(Vault.t, map()) :: integer()
  def vault_hash(%Vault{} = vault, params) do
    :erlang.phash2({vault_options(vault), params})
  end

  @spec vault_options(Vault.t) :: map
  def vault_options(%Vault{} = vault) do
    vault
    |> Map.from_struct()
    |> Map.delete(:credentials)
    |> Map.delete(:token)
    |> Map.delete(:token_expires_at)
  end

  @spec expired_in_less_than?(Vault.t, pos_integer()) :: boolean()
  def expired_in_less_than?(%Vault{token_expires_at: expires_at}, time_to_expiration) do
    NaiveDateTime.diff(expires_at, NaiveDateTime.utc_now(), :second) < time_to_expiration
  end

end
