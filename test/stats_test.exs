defmodule NebulexClusteredMultilevel.StatsTest do
  use Nebulex.NodeCase

  import Nebulex.CacheCase, only: [wait_until: 1]

  alias NebulexLocalDistributedAdapter.TestCache, as: Cache

  setup do
    levels = [
      {Cache.Local, [name: :l2_for_stats]},
      {Cache.Local2, [name: :l3_for_stats]}
    ]

    node_pid_list =
      start_caches([node() | Node.list()], [
        {Cache.AllLocal, [stats: true, levels: levels, local_opts: [name: :l1_for_stats]]}
      ])

    on_exit(fn ->
      :ok = Process.sleep(100)
      stop_caches(node_pid_list)
    end)

    {:ok, cache: Cache.AllLocal}
  end

  describe "stats/0" do
    test "hits and misses", %{cache: cache} do
      :ok = cache.put_all(a: 1, b: 2)

      assert cache.get(:a) == 1
      assert cache.has_key?(:a)
      assert cache.ttl(:b) == :infinity
      refute cache.get(:c)
      refute cache.get(:d)

      assert cache.get_all([:a, :b, :c, :d]) == %{a: 1, b: 2}

      assert_stats_measurements(cache,
        l1: [hits: 5, misses: 4, writes: 2],
        l2: [hits: 0, misses: 4, writes: 2],
        l3: [hits: 0, misses: 4, writes: 2]
      )
    end

    test "writes and updates", %{cache: cache} do
      assert cache.put_all(a: 1, b: 2) == :ok
      assert cache.put_all(%{a: 1, b: 2}) == :ok
      refute cache.put_new_all(a: 1, b: 2)
      assert cache.put_new_all(c: 3, d: 4, e: 3)
      assert cache.put(1, 1) == :ok
      refute cache.put_new(1, 2)
      refute cache.replace(2, 2)
      assert cache.put_new(2, 2)
      assert cache.replace(2, 22)
      assert cache.incr(:counter) == 1
      assert cache.incr(:counter) == 2
      refute cache.expire(:f, 1000)
      assert cache.expire(:a, 1000)
      refute cache.touch(:f)
      assert cache.touch(:b)

      :ok = Process.sleep(1100)
      refute cache.get(:a)

      wait_until(fn ->
        assert_stats_measurements(cache,
          l1: [expirations: 1, misses: 1, writes: 10, updates: 4],
          l2: [expirations: 1, misses: 1, writes: 10, updates: 4],
          l3: [expirations: 1, misses: 1, writes: 10, updates: 4]
        )
      end)
    end

    test "evictions", %{cache: cache} do
      entries = for x <- 1..10, do: {x, x}
      :ok = cache.put_all(entries)

      assert cache.delete(1) == :ok
      assert cache.take(2) == 2
      refute cache.take(20)

      assert_stats_measurements(cache,
        l1: [evictions: 2, misses: 1, writes: 10],
        l2: [evictions: 2, misses: 1, writes: 10],
        l3: [evictions: 2, misses: 1, writes: 10]
      )

      assert cache.delete_all() == 24

      assert_stats_measurements(cache,
        l1: [evictions: 10, misses: 1, writes: 10],
        l2: [evictions: 10, misses: 1, writes: 10],
        l3: [evictions: 10, misses: 1, writes: 10]
      )
    end

    test "expirations", %{cache: cache} do
      :ok = cache.put_all(a: 1, b: 2)
      :ok = cache.put_all([c: 3, d: 4], ttl: 1000)

      assert cache.get_all([:a, :b, :c, :d]) == %{a: 1, b: 2, c: 3, d: 4}

      :ok = Process.sleep(1100)
      assert cache.get_all([:a, :b, :c, :d]) == %{a: 1, b: 2}

      wait_until(fn ->
        assert_stats_measurements(cache,
          l1: [evictions: 2, expirations: 2, hits: 6, misses: 2, writes: 4],
          l2: [evictions: 2, expirations: 2, hits: 0, misses: 2, writes: 4],
          l3: [evictions: 2, expirations: 2, hits: 0, misses: 2, writes: 4]
        )
      end)
    end
  end

  defp assert_stats_measurements(cache, levels) do
    measurements = cache.stats().measurements

    for {level, stats} <- levels, {stat, expected} <- stats do
      assert get_in(measurements, [level, stat]) == expected
    end
  end
end
