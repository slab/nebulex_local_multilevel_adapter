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

    # Ensure joining the cluster only when the cache supervision tree is started
    :ok = Cluster.join(adapter_meta.name)

    {:ok, adapter_meta}
  end

  @impl true
  def terminate(_reason, state) do
    # Ensure leaving the cluster when the cache stops
    :ok = Cluster.leave(state.name)
  end
end
