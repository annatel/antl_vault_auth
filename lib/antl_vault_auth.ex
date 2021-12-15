defmodule AntlVaultAuth do
  @moduledoc false

  @spec auth(Vault.t, map()) :: {:ok, Vault.t} | {:error, any()}
  def auth(vault, params) do
    AntlVaultAuth.Tokens.auth(vault, params)
  end

end
