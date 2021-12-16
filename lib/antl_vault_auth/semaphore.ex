defmodule AntlVaultAuth.Semaphore do

  @doc """
  Creates an ets table to host the semaphores
  """
  @spec init(atom()) :: boolean()
  def init(table) when is_atom(table) do
    ^table = :ets.new(table, [:set, :public, :named_table, {:write_concurrency, true}])
  end

  @doc """
  Acquire a semaphore, incrementing the internal count by one.
  """
  @spec acquire(atom(), term(), integer()) :: boolean()
  def acquire(table, name, max) do
    case :ets.update_counter(table, name, [{2, 0}, {2, 1, max, max}], {name, 0}) do
      [^max, _] -> false
      _ -> true
    end
  end

  @doc """
  Release a semaphore, decrementing the internal count by one.
  """
  @spec release(atom(), term()) :: boolean()
  def release(table, name) do
    case :ets.update_counter(table, name, [{2, 0}, {2, -1, 0, 0}], {name, 0}) do
      [0, _] -> false
      _ -> true
    end
  end

  @doc """
  Reset sempahore to a specific count.
  """
  @spec reset(atom(), term(), integer()) :: boolean()
  def reset(table, name, count \\ 0) do
    :ets.update_element(table, name, {2, count})
  end

  @doc """
  Number of acquired semaphores.
  """
  @spec count(atom(), term()) :: integer()
  def count(table, name) do
    case :ets.lookup(table, name) do
      [{_, count}] -> count
      _ -> 0
    end
  end

end
