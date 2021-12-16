defmodule AntlVaultAuth.SemaphoreTest do
  use ExUnit.Case, async: true

  alias AntlVaultAuth.Semaphore

  setup do
    semaphores = String.to_atom("semaphores_#{:erlang.unique_integer([:monotonic, :positive])}")
    Semaphore.init(semaphores)
    {:ok, semaphores: semaphores}
  end

  describe "acquire/3" do
    test "There is no resource acquired, let's acquire just one resource",
      %{semaphores: semaphores}
    do
      assert 0 == Semaphore.count(semaphores, :my)
      assert Semaphore.acquire(semaphores, :my, 1)
      assert 1 == Semaphore.count(semaphores, :my)
    end

    test "There is no acquired resource, let's acquire resource until maximum",
      %{semaphores: semaphores}
    do
      assert 0 == Semaphore.count(semaphores, :my)
      assert Semaphore.acquire(semaphores, :my, 3)
      assert Semaphore.acquire(semaphores, :my, 3)
      assert Semaphore.acquire(semaphores, :my, 3)
      refute Semaphore.acquire(semaphores, :my, 3)
      assert 3 == Semaphore.count(semaphores, :my)
    end

    test "There is no acquired resources, let's acquire different resources",
      %{semaphores: semaphores}
    do
      assert 0 == Semaphore.count(semaphores, :my_1)
      assert 0 == Semaphore.count(semaphores, :my_2)

      assert Semaphore.acquire(semaphores, :my_1, 1)
      assert Semaphore.acquire(semaphores, :my_2, 2)
      assert Semaphore.acquire(semaphores, :my_2, 2)

      assert 1 == Semaphore.count(semaphores, :my_1)
      assert 2 == Semaphore.count(semaphores, :my_2)
    end
  end

  describe "release/2" do
    test "There is no acquired resources, let's release not acquired one",
      %{semaphores: semaphores}
    do
      refute Semaphore.release(semaphores, :my)
      assert 0 == Semaphore.count(semaphores, :my)
    end

    test "There is acquired resources, let's release them all",
      %{semaphores: semaphores}
    do
      assert Semaphore.acquire(semaphores, :my, 3)
      assert Semaphore.acquire(semaphores, :my, 3)
      assert Semaphore.acquire(semaphores, :my, 3)

      assert Semaphore.release(semaphores, :my)
      assert Semaphore.release(semaphores, :my)
      assert Semaphore.release(semaphores, :my)
      refute Semaphore.release(semaphores, :my)

      assert 0 == Semaphore.count(semaphores, :my)
    end

    test "There is  acquired resources, let's release one of them",
      %{semaphores: semaphores}
    do
      assert Semaphore.acquire(semaphores, :my_1, 1)
      assert Semaphore.acquire(semaphores, :my_2, 1)

      assert Semaphore.release(semaphores, :my_1)

      assert 0 == Semaphore.count(semaphores, :my_1)
      assert 1 == Semaphore.count(semaphores, :my_2)
    end
  end

  describe "reset/3" do
    test "There is no acquired resources, let's reset not acquired one",
      %{semaphores: semaphores}
    do
      refute Semaphore.reset(semaphores, :my)
      assert 0 == Semaphore.count(semaphores, :my)
    end

    test "There is acquired resource, let's reset one by default value",
      %{semaphores: semaphores}
    do
      assert Semaphore.acquire(semaphores, :my, 1)
      assert Semaphore.reset(semaphores, :my)
      assert 0 == Semaphore.count(semaphores, :my)
    end

    test "There is acquired resource, let's reset one by custom value",
      %{semaphores: semaphores}
    do
      assert Semaphore.acquire(semaphores, :my, 1)
      assert Semaphore.reset(semaphores, :my, 10)
      assert 10 == Semaphore.count(semaphores, :my)
    end

    test "There is acquired resources, let's reset one of them",
      %{semaphores: semaphores}
    do
      assert Semaphore.acquire(semaphores, :my_1, 1)
      assert Semaphore.acquire(semaphores, :my_2, 1)

      assert Semaphore.reset(semaphores, :my_2, 10)

      assert 1 == Semaphore.count(semaphores, :my_1)
      assert 10 == Semaphore.count(semaphores, :my_2)
    end
  end
end
