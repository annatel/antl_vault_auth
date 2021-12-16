defmodule AntlVaultAuth.AuthenticatedVaults do
  @moduledoc false

  @ets_table :auth_tokens
  @ets_table_spec [:set, :public, {:read_concurrency, true}, :named_table, :compressed]

  require Logger

  alias AntlVaultAuth.VaultUtils

  @spec init() :: true
  def init() do
    @ets_table = :ets.new(@ets_table, @ets_table_spec)
  end

  @spec login_all(pos_integer()) :: :ok
  def login_all(time_to_expiration) when is_integer(time_to_expiration) do
    authenticated_vaults_list()
    |> Enum.filter(&VaultUtils.expired_in_less_than?(elem(&1, 1), time_to_expiration))
    |> Enum.each(&login(elem(&1, 1), elem(&1, 1).credentials))
  end

  @spec login(Vault.t(), map) :: {:ok, Vault.t()} | {:error, [term]}
  def login(%Vault{} = vault, %{} = params) do
    case Vault.auth(vault, params) do
      {:ok, vault} ->
        save(vault, params)

      {:error, error} ->
        {:error, error} |> tap(&Logger.error(inspect(&1)))
    end
  end

  @spec lookup(Vault.t(), map) :: Vault.t() | nil
  def lookup(%Vault{} = vault, params) do
    case :ets.lookup(@ets_table, VaultUtils.vault_hash(vault, params)) do
      [{_, ets_vault}] -> ets_vault
      _ -> nil
    end
  end

  defp save(%Vault{} = vault, params) do
    true = :ets.insert(@ets_table, {VaultUtils.vault_hash(vault, params), vault})
    {:ok, vault}
  end

  defp authenticated_vaults_list(), do: :ets.tab2list(@ets_table)

end
