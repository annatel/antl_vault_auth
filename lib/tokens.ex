defmodule AntlVaultAuth.Tokens do
  @moduledoc false

  @ets_table :auth_tokens
  @ets_table_spec [:set, :public, {:read_concurrency, true}, :named_table, :compressed]

  require Logger

  @spec init() :: true
  def init() do
    @ets_table = :ets.new(@ets_table, @ets_table_spec)
  end

  @spec auth(Vault.t, map()) :: {:ok, Vault.t} | {:error, any()}
  def auth(vault, params) do
    with {:lookup, nil} <- {:lookup, lookup(vault, params)},
         {:auth, {:ok, vault}} <- {:auth, renew(vault, params)},
         true <- save(vault, params)
    do
      {:ok, vault}
    else
      {:lookup, vault} -> {:ok, vault}
      {:auth, error} -> error
    end
  end

  @spec renew_all(pos_integer()) :: :ok
  def renew_all(time_to_expiration) do
    Enum.each(:ets.tab2list(@ets_table), fn {{role_id, secret_id}, vault} ->
      if time_for_renew?(vault, time_to_expiration) do
        renew(vault, %{role_id: role_id, secret_id: secret_id})
      end
    end)
  end

  defp time_for_renew?(vault, time_to_expiration) do
    NaiveDateTime.diff(vault.token_expires_at, NaiveDateTime.utc_now(), :second) <= time_to_expiration
  end

  defp renew(vault, params) do
    case Vault.auth(vault, params) do
      {:ok, vault} ->
        true = save(vault, params)
        {:ok, vault}
      error ->
        Logger.error(inspect(error))
        error
    end
  end

  defp lookup(client_vault, %{role_id: role_id, secret_id: secret_id}) do
    with [{_, ets_vault}] <- :ets.lookup(@ets_table, {role_id, secret_id}),
         true <- same_vault?(vault_options(ets_vault), vault_options(client_vault))
    do
      ets_vault
    else
      _ -> nil
    end
  end

  defp save(vault, %{role_id: role_id, secret_id: secret_id}) do
    true = :ets.insert @ets_table, {{role_id, secret_id}, vault}
  end

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
