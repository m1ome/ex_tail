defmodule ExTailTest do
  use ExUnit.Case
  doctest ExTail

  test "greets the world" do
    assert ExTail.hello() == :world
  end
end
