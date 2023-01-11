defmodule NebulexLocalMultilevelAdapter.CacheTest do
  @moduledoc """
  Shared Tests
  """

  defmacro __using__(_opts) do
    quote do
      use Nebulex.Cache.QueryableTest
    end
  end
end
