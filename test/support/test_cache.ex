defmodule NebulexLocalDistributedAdapter.TestCache do
  defmodule AdapterMock do
    # Mostly a copy of Nebulex.TestCache.AdapterMock with expanded `delete/3` callback
    @behaviour Nebulex.Adapter
    @behaviour Nebulex.Adapter.Entry
    @behaviour Nebulex.Adapter.Queryable

    @impl true
    defmacro __before_compile__(_), do: :ok

    @impl true
    def init(opts) do
      child = {
        {Agent, System.unique_integer([:positive, :monotonic])},
        {Agent, :start_link, [fn -> :ok end, [name: opts[:child_name]]]},
        :permanent,
        5_000,
        :worker,
        [Agent]
      }

      {:ok, child, %{}}
    end

    @impl true
    def get(_, key, _) do
      if is_integer(key) do
        raise ArgumentError, "Error"
      else
        :ok
      end
    end

    @impl true
    def put(_, _, _, _, _, _) do
      :ok = Process.sleep(1000)
      true
    end

    @impl true
    def delete(_, :exit, _), do: Process.exit(self(), :normal)
    def delete(_, :exception, _), do: raise("raise")
    def delete(_, :throw, _), do: throw("throw")

    @impl true
    def take(_, _, _), do: nil

    @impl true
    def has_key?(_, _), do: true

    @impl true
    def ttl(_, _), do: nil

    @impl true
    def expire(_, _, _), do: true

    @impl true
    def touch(_, _), do: true

    @impl true
    def update_counter(_, _, _, _, _, _), do: 1

    @impl true
    def get_all(_, _, _) do
      :ok = Process.sleep(1000)
      %{}
    end

    @impl true
    def put_all(_, _, _, _, _), do: Process.exit(self(), :normal)

    @impl true
    def execute(_, :count_all, _, _) do
      _ = Process.exit(self(), :normal)
      0
    end

    def execute(_, :delete_all, _, _) do
      Process.sleep(2000)
      0
    end

    @impl true
    def stream(_, _, _), do: 1..10
  end

  defmodule Standalone do
    use Nebulex.Cache,
      otp_app: :nebulex_local_distributed_adapter,
      adapter: NebulexLocalDistributedAdapter
  end

  defmodule AllLocal do
    use Nebulex.Cache,
      otp_app: :nebulex_local_distributed_adapter,
      adapter: NebulexLocalDistributedAdapter
  end

  defmodule Connected do
    use Nebulex.Cache,
      otp_app: :nebulex_local_distributed_adapter,
      adapter: NebulexLocalDistributedAdapter
  end

  defmodule Isolated do
    use Nebulex.Cache,
      otp_app: :nebulex_local_distributed_adapter,
      adapter: NebulexLocalDistributedAdapter
  end

  defmodule Mock do
    use Nebulex.Cache,
      otp_app: :nebulex_local_distributed_adapter,
      adapter: NebulexLocalDistributedAdapter
  end

  defmodule L1 do
    use Nebulex.Cache,
      otp_app: :nebulex_local_distributed_adapter,
      adapter: Nebulex.Adapters.Local
  end

  defmodule L1.Mock do
    @moduledoc false
    use Nebulex.Cache,
      otp_app: :nebulex,
      adapter: NebulexLocalDistributedAdapter.TestCache.AdapterMock
  end

  defmodule Partitioned do
    use Nebulex.Cache,
      otp_app: :nebulex_local_distributed_adapter,
      adapter: Nebulex.Adapters.Partitioned
  end

  defmodule Local do
    use Nebulex.Cache,
      otp_app: :nebulex_local_distributed_adapter,
      adapter: Nebulex.Adapters.Local
  end

  defmodule Local2 do
    use Nebulex.Cache,
      otp_app: :nebulex_local_distributed_adapter,
      adapter: Nebulex.Adapters.Local
  end
end
