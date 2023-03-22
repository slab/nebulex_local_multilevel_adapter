# NebulexLocalMultilevelAdapter

A variation of
[Multilevel](https://hexdocs.pm/nebulex/Nebulex.Adapters.Multilevel.html)
adapter that assumes Level 1 being `Local` cache running in a distributed
cluster.

## Installation

Add `nebulex_local_multilevel_adapter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nebulex_local_multilevel_adapter, "~> 0.1.1"}
  ]
end
```

## Usage

<!-- MDOC -->

`NebulexLocalMultilevelAdapter` setup resembles `Nebulex.Adapters.Multilevel` with two exceptions: `model` option is always
`:inclusive` and the first level is autocreated:

```elixir
defmodule MyApp.Cache do
  use Nebulex.Cache,
    otp_app: :slab,
    adapter: NebulexLocalMultilevelAdapter
end

# This can be shared cache, e.g. Partitioned, Replicated, Memcached
defmodule MyApp.Cache.Redis do
  use Nebulex.Cache,
    otp_app: :slab,
    adapter: NebulexRedisAdapter
end
```

Then configure `MyApp.Cache` levels just like normal `Multilevel`:

```elixir
config :my_app, MyApp.Cache,
  local_opts: [],
  levels: [
    {MyApp.Cache.Redis, []},
  ]
```

The adapter will automatically create `MyApp.Cache.Local` L1 cache using options
provided in `local_opts`.

## How it works

`LocalMultilevelAdapter` is different from `Nebulex.Adapters.Multilevel` in a couple of ways:

1. L1 is created automatically and uses `Nebulex.Adapters.Local` adapter
2. Other levels must be global for nodes, meaning they behave like a shared
  storage. The simplest example is `NebulexRedisAdapter`, but `Replicated` and
  `Partitioned` should work too.
3. All write operations are asynchronously broadcasted to other nodes which
  invalidate affected keys in their local L1 caches.

> #### Race conditions {: .warning}
> There are several important things to keep in mind when working with a
> multilevel cache in a clustered environment:
> 1. Always update the underlying storage (e.g. Ecto repo) first and invalidate
>    the cache after to avoid a potential race condition when another client can
>    write a stale value to the cache. The adapter follows this pattern moving
>    from higher to lower levels with deletes.
> 2. Keep in mind that invalidation messages are broadcasted without any
>    confirmation from recipient nodes, so there is always a small chance of
>    reading a stale value from the cache.

<!-- MDOC -->

## Development

`NebulexLocalMultilevelAdapter` relies on shared test code from `Nebulex` repository, so you'll need to fetch it first

```console
export NEBULEX_PATH=nebulex
mix nbx.setup
```

make sure `epmd` is running:

```console
epmd -daemon
```

From this it should be business as usual:

```console
mix deps.get
mix test
```
