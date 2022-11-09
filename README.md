# NebulexLocalDistributedAdapter

A variation of
[Multilevel](https://hexdocs.pm/nebulex/Nebulex.Adapters.Multilevel.html)
adapter that assumes Level 1 being `Local` cache running in a distributed
cluster.

## Installation

Add `nebulex_local_distributed_adapter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nebulex_local_distributed_adapter, "~> 0.1.0"}
  ]
end
```

## Usage

After installing, we can define our cache to use the adapter as follows:

```elixir
defmodule MyApp.Cache do
  use Nebulex.Cache,
    otp_app: :slab,
    adapter: NebulexLocalDistributedAdapter
end

defmodule MyApp.Cache.Local do
  use Nebulex.Cache,
    otp_app: :slab,
    adapter: Nebulex.Adapters.Local
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
  levels: [
    {MyApp.Cache.Local, []}
    {MyApp.Cache.Redis, []},
  ]
```

## How it works

`LocalDistributedAdapter` is different from `Nebulex.Adapters.Multilevel` in a couple of ways:

1. L1 must always be `Nebulex.Adapters.Local`
2. Other levels must be global for nodes, meaning they behave like a shared
  storage. Simplest example is `NebulexRedisAdapter`, but `Replicated` and
  `Partitioned` should work too.
3. All write operations are asynchronously broadcasted to other nodes which
  invalidate affected keys in their local L1 caches.

> #### Race conditions {: .warning}
> Due to asynchronous nature of invalidation it is possible that a node will read
stale value from its local cache.


## Development

`NebulexLocalDistributedAdapter` relies on shared test code from `Nebulex` repository, so you'll need to fetch it first

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
