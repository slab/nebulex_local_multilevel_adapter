defmodule NebulexLocalDistributedAdapterTest do
  use ExUnit.Case
  doctest NebulexLocalDistributedAdapter

  test "greets the world" do
    assert NebulexLocalDistributedAdapter.hello() == :world
  end
end
