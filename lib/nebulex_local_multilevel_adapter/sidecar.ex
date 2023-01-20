defmodule NebulexLocalMultilevelAdapter.Sidecar do
  @moduledoc false
  use GenServer

  import Nebulex.Helpers

  alias Nebulex.Cache.Cluster

  @doc false
  def start_link(%{name: name} = adapter_meta) do
    GenServer.start_link(__MODULE__, adapter_meta, name: normalize_module_name([name, Sidecar]))
  end

  @impl true
  def init(adapter_meta) do
    # Trap exit signals to run cleanup job
    _ = Process.flag(:trap_exit, true)

    {:ok, adapter_meta, {:continue, :join_cluster}}
  end

  @impl true
  def handle_continue(:join_cluster, adapter_meta) do
    join_cluster(adapter_meta)
  end

  @impl true
  def handle_info(:join_cluster, adapter_meta) do
    join_cluster(adapter_meta)
  end

  def join_cluster(adapter_meta) do
    _ = Nebulex.Cache.Registry.lookup(adapter_meta.name)

    # Ensure joining the cluster only when the cache supervision tree is started
    :ok = Cluster.join(adapter_meta.name)
    {:noreply, adapter_meta}
  rescue
    ArgumentError ->
      Process.send_after(self(), :join_cluster, 50)
      {:noreply, adapter_meta}
  end

  @impl true
  def terminate(_reason, state) do
    # Ensure leaving the cluster when the cache stops
    :ok = Cluster.leave(state.name)
  end
end
