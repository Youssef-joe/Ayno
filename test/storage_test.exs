defmodule Polyglot.StorageTest do
  use ExUnit.Case

  setup do
    # Clear ETS table before each test
    :ets.delete_all_objects(:event_history)
    :ok
  end

  test "stores and retrieves events" do
    event = %{id: "test-1", type: "message", data: %{text: "hello"}}
    Polyglot.Storage.store_event("room:test", event)

    history = Polyglot.Storage.get_history("room:test")
    assert length(history) == 1
    assert hd(history) == event
  end

  test "returns empty list for unknown channel" do
    history = Polyglot.Storage.get_history("room:unknown")
    assert history == []
  end
end
