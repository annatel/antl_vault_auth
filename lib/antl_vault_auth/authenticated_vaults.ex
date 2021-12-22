defmodule AntlVaultAuth.AuthenticatedVaults do
  @moduledoc false

  @ets_table :auth_tokens
  @ets_table_spec [:set, :public, {:read_concurrency, true}, :named_table, :compressed]

  require Logger

  @spec init() :: true
  def init() do
    @ets_table = :ets.new(@ets_table, @ets_table_spec)
  end

  @spec login_all(pos_integer()) :: :ok
  def login_all(time_to_expiration) when is_integer(time_to_expiration) do
    authenticated_vaults_list()
    |> Enum.filter(&expired_in_less_than?(&1, time_to_expiration))
    |> Enum.each(&login(&1, &1.credentials))
  end

  @spec login(Vault.t(), map) :: {:ok, Vault.t()} | {:error, [term]}
  def login(%Vault{} = vault, %{} = params) do
    case Vault.auth(vault, params) do
      {:ok, vault} ->
        save(vault, params)

      {:error, error} ->
        # The AntlVaultAuth.RefreshAuthTokenWorker.refresh_token(vault, params) method
        # must not be called here because inside of the 'refresh_token' method the AuthenticatedVaults.login(vault, params)
        # method will be called again and we can fall into an infinite loop,
        # for example, if credentials will be revoked
        {:error, error} |> tap(&Logger.error(inspect(&1)))
    end
  end

  @spec lookup(Vault.t(), map) :: Vault.t() | nil
  def lookup(%Vault{} = vault, %{} = params) do
    case :ets.lookup(@ets_table, vault_hash(vault, params)) do
      [{_, ets_vault}] -> ets_vault
      _ -> nil
    end
  end

  defp save(%Vault{} = vault, %{} = params) do
    true = :ets.insert(@ets_table, {vault_hash(vault, params), vault})
    {:ok, vault}
  end

  defp authenticated_vaults_list() do
    @ets_table |> :ets.tab2list() |> Enum.map(&elem(&1, 1))
  end

  defp vault_hash(%Vault{} = vault, %{} = params) do
    :erlang.phash2({vault_options(vault), params})
  end

  defp vault_options(%Vault{} = vault) do
    vault
    |> Map.from_struct()
    |> Map.delete(:credentials)
    |> Map.delete(:token)
    |> Map.delete(:token_expires_at)
  end

  defp expired_in_less_than?(%Vault{token_expires_at: expires_at}, time_to_expiration) do
    NaiveDateTime.diff(expires_at, NaiveDateTime.utc_now(), :second) < time_to_expiration
  end
end
