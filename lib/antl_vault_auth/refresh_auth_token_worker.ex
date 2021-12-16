defmodule AntlVaultAuth.RefreshAuthTokenWorker do
  @moduledoc false
  use GenServer

  alias AntlVaultAuth.{AuthenticatedVaults, VaultUtils, Semaphore}

  @semaphores :refresh_auth_token_worker_semaphores_holder # unique name

  # Api

  @doc """
  Schedule the task of immediate login to Vault (update authenticated vault client)
  Identical requests {vault, param} will be deduplicated in the GenServer Queue
  """
  @spec schedule_immediate_login(Vault.t, map) :: boolean()
  def schedule_immediate_login(vault, params) do
    if Semaphore.acquire(@semaphores, semaphore_name(vault, params), 1) do
      GenServer.cast(__MODULE__, {:force_relogin, vault, params})
    end
  end

  # GenServer impl

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(args) do
    Semaphore.init(@semaphores)
    AuthenticatedVaults.init()
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
  def handle_cast({:force_relogin, vault, params}, state) do
    AuthenticatedVaults.login(vault, params)
    Semaphore.release(@semaphores, semaphore_name(vault, params))
    {:noreply, state}
  end

  defp semaphore_name(%Vault{} = vault, params) do
    VaultUtils.vault_hash(vault, params)
  end

  defp schedule_token_renewal(interval) do
    Process.send_after(self(), :renew, :timer.seconds(interval))
  end

  defp make_state(args) do
    %{
      checkout_interval: Keyword.get(args, :checkout_interval, 60),
      time_to_expiration: Keyword.get(args, :time_to_expiration, 60 * 5)
    }
  end

end
