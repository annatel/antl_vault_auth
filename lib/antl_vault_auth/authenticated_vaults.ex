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
    list_authenticated_vaults()
    |> Enum.filter(&time_for_renew?(&1, time_to_expiration))
    |> Enum.each(fn {{role_id, secret_id}, vault} ->
      login(vault, %{role_id: role_id, secret_id: secret_id})
    end)
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
  def lookup(%Vault{} = vault, %{role_id: role_id, secret_id: secret_id}) do
    with [{_, ets_vault}] <- :ets.lookup(@ets_table, {role_id, secret_id}),
         true <- same_vault?(vault_options(ets_vault), vault_options(vault)) do
      ets_vault
    else
      _ -> nil
    end
  end

  defp save(vault, %{role_id: role_id, secret_id: secret_id}) do
    true = :ets.insert(@ets_table, {{role_id, secret_id}, vault})
    {:ok, vault}
  end

  defp list_authenticated_vaults(), do: :ets.tab2list(@ets_table)

  defp same_vault?(options, options), do: true
  defp same_vault?(_, _), do: false

  defp vault_options(%Vault{} = vault) do
    vault
    |> Map.from_struct()
    |> Map.delete(:credentials)
    |> Map.delete(:token)
    |> Map.delete(:token_expires_at)
  end
end
