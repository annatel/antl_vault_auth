defmodule AntlVaultAuth do
  @moduledoc false
  alias AntlVaultAuth.AuthenticatedVaults

  @doc """
  Authenticate a client.
  To force a refreshing of a cached token the [force: true] opts must be passed
  """
  @spec auth(Vault.t(), map(), keyword()) :: {:ok, Vault.t()} | {:error, any()}
  def auth(vault, params, opts \\ [])

  def auth(%Vault{} = vault, %{} = params, [force: true]) do
    AuthenticatedVaults.login(vault, params)
  end

  def auth(%Vault{} = vault, %{} = params, _) do
    case AuthenticatedVaults.lookup(vault, params) do
      %Vault{} = vault -> {:ok, vault}
      nil -> vault |> AuthenticatedVaults.login(params)
    end
  end
end
