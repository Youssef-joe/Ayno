defmodule PolyglotTest do
  use ExUnit.Case
  doctest Polyglot

  test "publish creates event with correct structure" do
    event_id = Polyglot.publish("test-app", "room:test", %{"type" => "message", "data" => %{"text" => "hello"}})
    assert String.starts_with?(event_id, "evt_")
  end
end
