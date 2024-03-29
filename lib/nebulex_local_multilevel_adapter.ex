defmodule NebulexLocalMultilevelAdapter do
  require Logger

  alias Nebulex.Cache.Cluster
  @external_resource readme = Path.join([__DIR__, "../README.md"])

  @moduledoc readme
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.fetch!(1)

  @behaviour Nebulex.Adapter
  @behaviour Nebulex.Adapter.Entry
  @behaviour Nebulex.Adapter.Queryable
  @behaviour Nebulex.Adapter.Stats

  @impl Nebulex.Adapter
  defmacro __before_compile__(env) do
    otp_app = Module.get_attribute(env.module, :otp_app)

    quote do
      defmodule Local do
        @moduledoc """
        This is the cache for L1
        """
        use Nebulex.Cache,
          otp_app: unquote(otp_app),
          adapter: Nebulex.Adapters.Local
      end

      def __local__, do: Local

      def delete_local(key, opts \\ []) do
        get_dynamic_cache()
        |> Nebulex.Adapter.with_meta(& &1.delete_local(&2, key, opts))
      end

      def delete_all_local(query, opts \\ []) do
        get_dynamic_cache()
        |> Nebulex.Adapter.with_meta(& &1.delete_all_local(&2, query, opts))
      end
    end
  end

  @impl Nebulex.Adapter
  def init(opts) do
    cache = Keyword.fetch!(opts, :cache)

    opts =
      opts
      |> Keyword.put(:model, :inclusive)
      |> Keyword.update!(:levels, fn levels ->
        [{cache.__local__(), Keyword.get(opts, :local_opts, [])} | levels]
      end)

    {:ok, child_spec, adapter_meta} = Nebulex.Adapters.Multilevel.init(opts)

    [l1_meta | _] = adapter_meta.levels

    adapter_meta = Map.put(adapter_meta, :l1_name, l1_meta.name || l1_meta.cache)

    child_spec =
      Map.update!(child_spec, :start, fn {module, function, [children | rest_args]} ->
        {module, function, [children ++ [{__MODULE__.Sidecar, adapter_meta}] | rest_args]}
      end)

    {:ok, child_spec, adapter_meta}
  end

  @impl Nebulex.Adapter.Entry
  defdelegate get(adapter_meta, key, opts), to: Nebulex.Adapters.Multilevel

  @impl Nebulex.Adapter.Entry
  defdelegate get_all(adapter_meta, keys, opts), to: Nebulex.Adapters.Multilevel

  @impl Nebulex.Adapter.Entry
  def put(adapter_meta, key, value, ttl, on_write, opts) do
    local = Nebulex.Adapters.Multilevel.put(adapter_meta, key, value, ttl, on_write, opts)

    unless Keyword.get(opts, :level, nil) do
      run_on_cluster!(adapter_meta, :delete_local, [key, opts])
    end

    local
  end

  @impl Nebulex.Adapter.Entry
  def put_all(adapter_meta, entries, ttl, on_write, opts) do
    local = Nebulex.Adapters.Multilevel.put_all(adapter_meta, entries, ttl, on_write, opts)

    unless Keyword.get(opts, :level, nil) do
      keys = for {key, _} <- entries, do: key

      run_on_cluster!(adapter_meta, :delete_all_local, [{:in, keys}, opts])
    end

    local
  end

  @impl Nebulex.Adapter.Entry
  def delete(adapter_meta, key, opts) do
    local = Nebulex.Adapters.Multilevel.delete(adapter_meta, key, opts)

    unless Keyword.get(opts, :level, nil) do
      run_on_cluster!(adapter_meta, :delete_local, [key, opts])
    end

    local
  end

  @impl Nebulex.Adapter.Entry
  def take(adapter_meta, key, opts) do
    local = Nebulex.Adapters.Multilevel.take(adapter_meta, key, opts)

    if local do
      run_on_cluster!(adapter_meta, :delete_local, [key, opts])
    end

    local
  end

  @impl Nebulex.Adapter.Entry
  def update_counter(adapter_meta, key, amount, ttl, default, opts) do
    local =
      Nebulex.Adapters.Multilevel.update_counter(adapter_meta, key, amount, ttl, default, opts)

    unless Keyword.get(opts, :level, nil) do
      run_on_cluster!(adapter_meta, :delete_local, [key, opts])
    end

    local
  end

  @impl Nebulex.Adapter.Entry
  defdelegate has_key?(adapter_meta, key), to: Nebulex.Adapters.Multilevel

  @impl Nebulex.Adapter.Entry
  defdelegate ttl(adapter_meta, key), to: Nebulex.Adapters.Multilevel

  @impl Nebulex.Adapter.Entry
  def expire(adapter_meta, key, ttl) do
    local = Nebulex.Adapters.Multilevel.expire(adapter_meta, key, ttl)

    if local do
      run_on_cluster!(adapter_meta, :delete_local, [key, []])
    end

    local
  end

  @impl Nebulex.Adapter.Entry
  defdelegate touch(adapter_meta, key), to: Nebulex.Adapters.Multilevel

  @impl Nebulex.Adapter.Queryable
  def execute(adapter_meta, operation, query, opts) do
    case operation do
      op when op in [:all, :count_all] ->
        Nebulex.Adapters.Multilevel.execute(adapter_meta, operation, query, opts)

      :delete_all ->
        local = Nebulex.Adapters.Multilevel.execute(adapter_meta, :delete_all, query, opts)
        run_on_cluster!(adapter_meta, :delete_all_local, [query, opts])

        local
    end
  end

  @impl Nebulex.Adapter.Queryable
  defdelegate stream(adapter_meta, query, opts), to: Nebulex.Adapters.Multilevel

  @impl Nebulex.Adapter.Stats
  defdelegate stats(adapter_meta), to: Nebulex.Adapters.Multilevel

  @doc false
  def delete_local(adapter_meta, key, _opts) do
    with_l1_cache(adapter_meta, :delete, [key, []])
  end

  @doc false
  def delete_all_local(adapter_meta, query, _opts) do
    with_l1_cache(adapter_meta, :delete_all, [query, []])
  end

  @doc false
  def execute_from_remote(cache, cache_name, fun, args) do
    apply(cache, :with_dynamic_cache, [cache_name, cache, fun, args])
  rescue
    e in [ArgumentError, Nebulex.RegistryLookupError] ->
      :error
      |> Exception.format(e, __STACKTRACE__)
      |> Logger.warning(crash_reason: {e, __STACKTRACE__})

      :ok

    e ->
      reraise e, __STACKTRACE__
  end

  defp with_l1_cache(%{levels: [l1_meta | _]} = adapter_meta, fun, args) do
    cache = l1_meta.cache
    cache.with_dynamic_cache(adapter_meta.l1_name, cache, fun, args)
  end

  defp run_on_cluster!(adapter_meta, fun, args) do
    adapter_meta.name
    |> Cluster.get_nodes()
    |> List.delete(node())
    |> :erpc.multicast(__MODULE__, :execute_from_remote, [
      adapter_meta.cache,
      adapter_meta.name,
      fun,
      args
    ])
  end
end
