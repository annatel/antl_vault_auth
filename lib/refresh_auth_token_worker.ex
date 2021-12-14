defmodule AntlVaultAuth.RefreshAuthTokenWorker do
  @moduledoc false
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(args) do
    AntlVaultAuth.Tokens.init()
    state = make_state(args)
    schedule_token_renewal(state.checkout_interval)
    {:ok, state}
  end

  @impl true
  def handle_info(:renew, state) do
    AntlVaultAuth.Tokens.renew(state.time_to_expiration)
    schedule_token_renewal(state.checkout_interval)
    {:noreply, state}
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
