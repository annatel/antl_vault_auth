defmodule AntlVaultAuth.RefreshAuthTokenWorker do
  @moduledoc false
  use GenServer

  alias AntlVaultAuth.AuthenticatedVaults

  # Api

  @spec refresh_token(Vault.t, map) :: boolean()
  def refresh_token(vault, params) do
    # This is the rare case and the operation is not atomic but this is not critical
    unless has_refresh_message(vault, params) do
      GenServer.cast(__MODULE__, {:login, vault, params})
    end
  end

  defp has_refresh_message(vault, params) do
    {:messages, messages} = Process.info(Process.whereis(__MODULE__), :messages)

    messages
    |> Enum.filter(&match?({_, {:login, _, _}}, &1))
    |> Enum.map(fn({_, {_, vault, params}}) -> {vault, params} end)
    |> Enum.any?(&match?(^&1, {vault, params}))
  end

  # GenServer impl

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(args) do
    AuthenticatedVaults.init()
    login_clients(args)
    state = make_state(args)
    schedule_token_renewal(state.checkout_interval)
    {:ok, state}
  end

  @impl true
  def handle_info(:renew, state) do
    AuthenticatedVaults.login_all(state.time_to_expiration)
    schedule_token_renewal(state.checkout_interval)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:login, vault, params}, state) do
    AuthenticatedVaults.login(vault, params)
    {:noreply, state}
  end

  defp schedule_token_renewal(interval) do
    Process.send_after(self(), :renew, :timer.seconds(interval))
  end

  defp make_state(args) do
    %{
      checkout_interval: Map.get(args, :checkout_interval, 60),
      time_to_expiration: Map.get(args, :time_to_expiration, 60 * 5)
    }
  end

  defp login_clients(%{clients: clients}) when is_list(clients) do
    Enum.each(clients, fn {vault, params} ->
      AuthenticatedVaults.login(vault, params)
    end)
  end
  defp login_clients(_), do: :ok

end
