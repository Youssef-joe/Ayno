defmodule PolyglotTest do
  use ExUnit.Case
  doctest Polyglot

  test "greets the world" do
    assert Polyglot.hello() == :world
  end
end
