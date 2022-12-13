defmodule NebulexLocalDistributedAdapter.ClusteredTest do
  use Nebulex.NodeCase

  import Nebulex.CacheCase, only: [wait_until: 1]

  alias NebulexLocalDistributedAdapter.TestCache, as: Cache

  setup do
    node_pid_list =
      start_caches([node() | Node.list()], [
        {Cache.Isolated,
         [levels: [{Cache.Local, [name: :l2_for_isolated]}], local_opts: [name: :l1_for_isolated]]},
        {Cache.Connected,
         [
           levels: [{Cache.Partitioned, [name: :l2_for_connected]}],
           local_opts: [name: :l1_for_connected]
         ]}
      ])

    on_exit(fn ->
      :ok = Process.sleep(100)
      stop_caches(node_pid_list)
    end)

    {:ok, connected: Cache.Connected, isolated: Cache.Isolated}
  end

  describe "init/1" do
    test "supervisor tree" do
      assert {:ok,
              %{
                id: Cache.MyCache.Supervisor,
                start:
                  {Supervisor, :start_link,
                   [
                     [
                       {Cache.MyCache.Local,
                        [telemetry_prefix: [:prefix, :l1], telemetry: [:test], stats: false]},
                       {Cache.L2,
                        [telemetry_prefix: [:prefix, :l2], telemetry: [:test], stats: false]}
                     ],
                     [name: Cache.MyCache.Supervisor, strategy: :one_for_one]
                   ]}
              },
              %{
                levels: [
                  %{cache: Cache.MyCache.Local, name: nil},
                  %{cache: Cache.L2, name: nil}
                ],
                model: :inclusive,
                name: Cache.MyCache,
                started_at: _,
                stats: false,
                telemetry: [:test],
                telemetry_prefix: [:prefix]
              }} =
               NebulexLocalDistributedAdapter.init(
                 telemetry_prefix: [:prefix],
                 telemetry: [:test],
                 cache: Cache.MyCache,
                 levels: [{Cache.L2, []}]
               )
    end
  end

  describe "put" do
    test "writes only locally: isolated", %{isolated: cache} do
      assert cache.put(1, 1) == :ok
      assert cache.get(1) == 1

      assert_other_nodes(cache, :get, [1], nil)
    end

    test "writes only locally: connected", %{connected: cache} do
      assert cache.put(1, 1) == :ok
      assert cache.get(1) == 1

      assert_other_nodes(cache, :get, [1, [level: 1]], nil)
      assert_other_nodes(cache, :get, [1], 1)
    end

    test "broadcasts to remote l1", %{isolated: cache} do
      assert_other_nodes(cache, :put, [1, 1, [level: 1]], :ok)
      assert_other_nodes(cache, :get, [1], 1)

      assert cache.put(1, 2) == :ok

      wait_until(fn ->
        assert_other_nodes(cache, :get, [1], nil)
      end)
    end

    test "replicate write does not broadcasts", %{isolated: cache} do
      assert cache.put(1, 1, level: 2) == :ok
      assert_other_nodes(cache, :put, [1, 2, [level: 1]], :ok)
      assert_other_nodes(cache, :get, [1], 2)

      assert cache.get(1) == 1
      assert cache.get(1, level: 1) == 1
      assert_other_nodes(cache, :get, [1, [level: 1]], 2)
    end
  end

  describe "put_all" do
    test "writes only locally: isolated", %{isolated: cache} do
      assert cache.put_all(a: 1, b: 2) == :ok
      assert cache.get_all([:a, :b]) == %{a: 1, b: 2}

      assert_other_nodes(cache, :get_all, [[:a, :b]], %{})
    end

    test "writes only locally: connected", %{connected: cache} do
      assert cache.put_all(a: 1, b: 2) == :ok
      assert cache.get_all([:a, :b]) == %{a: 1, b: 2}

      assert_other_nodes(cache, :get_all, [[:a, :b], [level: 1]], %{})
      assert_other_nodes(cache, :get_all, [[:a, :b]], %{a: 1, b: 2})
    end

    test "broadcasts to remote l1", %{isolated: cache} do
      assert_other_nodes(cache, :put_all, [[a: 1, b: 2, c: 3], [level: 1]], :ok)
      assert_other_nodes(cache, :get_all, [[:a, :b, :c]], %{a: 1, b: 2, c: 3})

      assert cache.put_all(a: 1, b: 2) == :ok

      wait_until(fn ->
        assert_other_nodes(cache, :get_all, [[:a, :b, :c]], %{c: 3})
      end)
    end

    # atm get_all does not replicate
    @tag :skip
    test "replicate writes do not broadcast", %{isolated: cache} do
      assert cache.put_all([a: 1, b: 2], level: 2) == :ok
      assert_other_nodes(cache, :put_all, [%{a: 3, b: 4}, [level: 1]], :ok)
      assert_other_nodes(cache, :get_all, [[:a, :b]], %{a: 3, b: 4})

      assert cache.get_all([:a, :b], level: 1) == %{}
      assert cache.get_all([:a, :b]) == %{a: 1, b: 2}
      assert cache.get_all([:a, :b], level: 1) == %{a: 1, b: 2}
      assert_other_nodes(cache, :get_all, [[:a, :b], [level: 1]], %{a: 3, b: 4})
    end
  end

  describe "take" do
    test "broadcasts if succeeds", %{isolated: cache} do
      assert cache.put(1, 1) == :ok
      assert_other_nodes(cache, :put, [1, 1], :ok)

      assert cache.take(1) == 1

      wait_until(fn ->
        assert_other_nodes(cache, :get, [1, [level: 1]], nil)
      end)
    end

    test "no broadcast if no value", %{isolated: cache} do
      assert_other_nodes(cache, :put, [1, 1, [level: 2]], :ok)
      assert_other_nodes(cache, :get, [1], 1)
      assert_other_nodes(cache, :get, [1, [level: 1]], 1)

      assert cache.take(1) == nil
      assert_other_nodes(cache, :get, [1, [level: 1]], 1)
    end
  end

  describe "update_counter" do
    test "broadcasts to remote l1s", %{isolated: cache} do
      assert_other_nodes(cache, :put, [1, 10, [level: 1]], :ok)
      assert_other_nodes(cache, :get, [1], 10)

      assert cache.incr(1, 3) == 3

      wait_until(fn ->
        assert_other_nodes(cache, :get, [1, [level: 1]], nil)
      end)
    end
  end

  describe "expire" do
    test "broadcasts changes on success", %{isolated: cache} do
      assert cache.put(1, 1, level: 2, ttl: 10_000) == :ok
      assert cache.get(1) == 1

      assert_other_nodes(cache, :put, [1, 2, [level: 1]], :ok)
      assert_other_nodes(cache, :get, [1], 2)

      assert cache.expire(1, 4_000) == true

      wait_until(fn ->
        assert_other_nodes(cache, :get, [1, [level: 1]], nil)
      end)
    end

    test "no broadcast if no changes made", %{isolated: cache} do
      assert_other_nodes(cache, :put, [1, 2, [level: 1]], :ok)
      assert_other_nodes(cache, :get, [1], 2)

      assert cache.expire(1, 4_000) == false

      assert_other_nodes(cache, :get, [1, [level: 1]], 2)
    end
  end

  describe "delete_local" do
    test "deletes from l1", %{isolated: cache} do
      assert cache.put(1, 1) == :ok
      assert cache.get(1, level: 1) == 1

      assert cache.delete_local(1) == :ok
      refute cache.get(1, level: 1)
      assert cache.get(1, level: 2) == 1
    end
  end

  describe "delete" do
    test "invalidate remote l1s on delete: isolated", %{isolated: cache} do
      assert cache.put(1, 1) == :ok
      assert_other_nodes(cache, :put, [1, 2], :ok)
      assert cache.get(1) == 1
      assert_other_nodes(cache, :get, [1], 2)

      assert cache.delete(1)
      assert cache.get(1) == nil

      wait_until(fn ->
        assert_other_nodes(cache, :get, [1, [level: 1]], nil)
      end)

      assert_other_nodes(cache, :get, [1, [level: 2]], 2)
    end

    test "invalidate remote l1s on delete: connected", %{connected: cache} do
      assert cache.put(1, 1) == :ok
      assert cache.get(1) == 1
      assert_other_nodes(cache, :get, [1], 1)

      assert cache.delete(1)
      assert cache.get(1) == nil

      wait_until(fn ->
        assert_other_nodes(cache, :get, [1, [level: 1]], nil)
      end)

      assert_other_nodes(cache, :get, [1], nil)
    end

    test "can delete on just l2", %{connected: cache} do
      assert cache.put(1, 1) == :ok
      assert cache.get(1) == 1
      assert_other_nodes(cache, :get, [1], 1)

      assert cache.delete(1, level: 2)
      assert cache.get(1) == 1
      assert_other_nodes(cache, :get, [1], 1)
      assert_other_nodes(cache, :get, [1, [level: 2]], nil)
    end

    test "deleting on l1 does not broadcast", %{isolated: cache} do
      assert cache.put(1, 1) == :ok
      assert_other_nodes(cache, :put, [1, 2], :ok)
      assert cache.get(1) == 1
      assert_other_nodes(cache, :get, [1], 2)

      assert cache.delete(1, level: 1)
      assert cache.get(1, level: 1) == nil
      assert_other_nodes(cache, :get, [1, [level: 1]], 2)
    end
  end

  describe "delete all" do
    test "delete all: isolated", %{isolated: cache} do
      assert cache.put_all([a: 1, b: 1], level: 2) == :ok
      assert cache.put_all([a: 1, b: 1], level: 1) == :ok
      assert_other_nodes(cache, :put_all, [[a: 2, b: 2], [level: 2]], :ok)
      assert_other_nodes(cache, :put_all, [[a: 2, b: 2], [level: 1]], :ok)
      assert cache.get_all([:a, :b]) == %{a: 1, b: 1}
      assert_other_nodes(cache, :get_all, [[:a, :b]], %{a: 2, b: 2})

      assert cache.delete_all() == 4
      assert cache.get_all([:a, :b]) == %{}

      wait_until(fn ->
        assert_other_nodes(cache, :get_all, [[:a, :b], [level: 1]], %{})
      end)

      assert_other_nodes(cache, :get_all, [[:a, :b]], %{a: 2, b: 2})
    end

    test "delete all: connected", %{connected: cache} do
      assert cache.put_all(a: 1, b: 1) == :ok
      assert cache.get_all([:a, :b]) == %{a: 1, b: 1}
      assert_other_nodes(cache, :get_all, [[:a, :b]], %{a: 1, b: 1})

      assert cache.delete_all() == 4
      assert cache.get_all([:a, :b]) == %{}
      assert_other_nodes(cache, :get_all, [[:a, :b], [level: 1]], %{})
      assert_other_nodes(cache, :get_all, [[:a, :b]], %{})
    end

    test "delete_all alway affects all levels", %{isolated: cache} do
      assert cache.put_all([a: 1, b: 1], level: 2) == :ok
      assert cache.put_all([a: 1, b: 1], level: 1) == :ok
      assert_other_nodes(cache, :put_all, [[a: 2, b: 2], [level: 2]], :ok)
      assert cache.get_all([:a, :b]) == %{a: 1, b: 1}
      assert_other_nodes(cache, :get_all, [[:a, :b]], %{a: 2, b: 2})

      assert cache.delete_all(nil, level: 2) == 4
      assert cache.get_all([:a, :b], level: 2) == %{}
      assert cache.get_all([:a, :b], level: 1) == %{}

      wait_until(fn ->
        assert_other_nodes(cache, :get_all, [[:a, :b], [level: 2]], %{a: 2, b: 2})
        assert_other_nodes(cache, :get_all, [[:a, :b], [level: 1]], %{})
      end)
    end
  end

  defp assert_other_nodes(cache, action, args, expected) do
    assert results =
             :erpc.multicall(
               Node.list(),
               cache,
               :with_dynamic_cache,
               [cache, cache, action, args]
             )

    Enum.each(results, fn {:ok, res} -> assert res == expected end)
  end
end
