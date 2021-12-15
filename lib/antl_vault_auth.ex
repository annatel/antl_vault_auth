defmodule AntlVaultAuth do
  @moduledoc false
  alias AntlVaultAuth.AuthenticatedVaults

  @spec auth(Vault.t(), map()) :: {:ok, Vault.t()} | {:error, any()}
  def auth(%Vault{} = vault, %{} = params) do
    case AuthenticatedVaults.lookup(vault, params) do
      %Vault{} -> {:ok, vault}
      nil -> vault |> AuthenticatedVaults.login(params)
    end
  end
end
