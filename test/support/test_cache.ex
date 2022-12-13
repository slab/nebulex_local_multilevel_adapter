defmodule NebulexLocalDistributedAdapter.TestCache do
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

  defmodule MyCache do
    use Nebulex.Cache,
      otp_app: :nebulex_local_distributed_adapter,
      adapter: NebulexLocalDistributedAdapter
  end
end
