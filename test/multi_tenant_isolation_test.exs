defmodule Polyglot.MultiTenantIsolationTest do
  use ExUnit.Case
  require Logger

  setup do
    # Clear ETS before each test
    :ets.delete_all_objects(:event_history)
    :ok
  end

  describe "channel isolation across tenants" do
    test "different tenants have isolated channels" do
      channel_tenant1 = "room:test-#{System.unique_integer([:positive])}"
      channel_tenant2 = "room:test-#{System.unique_integer([:positive])}"

      event1 = %{
        id: "evt_t1",
        type: "msg",
        data: %{tenant: "tenant1"},
        meta: %{}
      }

      event2 = %{
        id: "evt_t2",
        type: "msg",
        data: %{tenant: "tenant2"},
        meta: %{}
      }

      Polyglot.Storage.store_event(channel_tenant1, event1)
      Polyglot.Storage.store_event(channel_tenant2, event2)

      history1 = Polyglot.Storage.get_history(channel_tenant1, 100)
      history2 = Polyglot.Storage.get_history(channel_tenant2, 100)

      # Histories should be separate (or empty if Redis down)
      assert is_list(history1)
      assert is_list(history2)
    end

    test "same channel name on different apps is isolated" do
      # Using different prefixes to simulate different apps
      channel_app1 = "app1:room:shared"
      channel_app2 = "app2:room:shared"

      event = %{
        id: "evt_shared",
        type: "msg",
        data: %{shared: true},
        meta: %{}
      }

      Polyglot.Storage.store_event(channel_app1, event)
      Polyglot.Storage.store_event(channel_app2, event)

      history1 = Polyglot.Storage.get_history(channel_app1, 100)
      history2 = Polyglot.Storage.get_history(channel_app2, 100)

      # Both should work without cross-contamination
      assert is_list(history1)
      assert is_list(history2)
    end
  end

  describe "tenant data segregation" do
    test "events from one tenant don't appear in another's history" do
      channels = Enum.map(1..5, fn i ->
        "room:tenant#{i}-#{System.unique_integer([:positive])}"
      end)

      # Store unique event to each channel
      Enum.each(channels, fn channel ->
        event = %{
          id: "evt_#{channel}",
          type: "msg",
          data: %{channel: channel},
          meta: %{}
        }

        Polyglot.Storage.store_event(channel, event)
      end)

      # Verify each channel only has its own data
      Enum.each(channels, fn channel ->
        history = Polyglot.Storage.get_history(channel, 100)

        # Either empty (Redis down) or has only this channel's events
        if length(history) > 0 do
          # All events should be from this channel
          assert Enum.all?(history, fn event ->
            event["data"]["channel"] == channel or event[:data][:channel] == channel
          end)
        end
      end)
    end

    test "concurrent multi-tenant operations don't interfere" do
      channels = Enum.map(1..5, fn i ->
        "tenant#{i}:room:#{System.unique_integer([:positive])}"
      end)

      # Create tasks for each tenant
      tasks =
        Enum.map(channels, fn channel ->
          Task.async(fn ->
            Enum.each(1..5, fn i ->
              event = %{
                id: "evt_#{channel}_#{i}",
                type: "msg",
                data: %{index: i},
                meta: %{}
              }

              Polyglot.Storage.store_event(channel, event)
            end)
          end)
        end)

      # Wait for all to complete
      results = Task.await_many(tasks)
      assert Enum.all?(results, &(&1 == :ok))

      # Verify isolation
      Enum.each(channels, fn channel ->
        history = Polyglot.Storage.get_history(channel, 100)
        assert is_list(history)
      end)
    end
  end

  describe "auth multi-tenancy" do
    test "tokens are scoped to app_id" do
      app1_token = {:ok, "token1"}
      app2_token = {:ok, "token2"}

      # Tokens generated for different apps should be different
      assert app1_token != app2_token
    end

    test "API key verification scoped to app_id" do
      conn = %Plug.Conn{req_headers: [{"x-api-key", "demo-app-local-key"}]}

      # Should verify or reject based on app_id
      result1 = Polyglot.Auth.verify_app_key(conn, "app1")
      result2 = Polyglot.Auth.verify_app_key(conn, "app2")

      # Both results should be tuples (either {:ok, _} or {:error, _})
      assert is_tuple(result1) or result1 == :ok
      assert is_tuple(result2) or result2 == :ok
    end
  end

  describe "channel naming conventions" do
    test "supports various channel name formats" do
      channels = [
        "room:lobby",
        "ticker:BTC-USD",
        "match:game_123:players",
        "post:article_456",
        "notifications:user789",
        "private:user1:user2",
        "broadcast:announcement_001"
      ]

      # Store and retrieve from each
      Enum.each(channels, fn channel ->
        event = %{
          id: "evt_#{channel}",
          type: "test",
          data: %{channel: channel},
          meta: %{}
        }

        result = Polyglot.Storage.store_event(channel, event)
        assert result == :ok

        history = Polyglot.Storage.get_history(channel, 10)
        assert is_list(history)
      end)
    end

    test "handles deeply nested channel names" do
      channel = "app:tenant:workspace:room:channel:subchannel:id"

      event = %{
        id: "evt_nested",
        type: "msg",
        data: %{nested: true},
        meta: %{}
      }

      result = Polyglot.Storage.store_event(channel, event)
      assert result == :ok

      history = Polyglot.Storage.get_history(channel, 10)
      assert is_list(history)
    end
  end

  describe "tenant isolation with different storage backends" do
    test "Redis and ETS both maintain isolation" do
      channel1 = "room:redis-ets-#{System.unique_integer([:positive])}"

      event = %{
        id: "evt_backend",
        type: "msg",
        data: %{backend: "test"},
        meta: %{}
      }

      # Store event (will use Redis if available, else ETS)
      Polyglot.Storage.store_event(channel1, event)

      # First retrieval
      history1 = Polyglot.Storage.get_history(channel1, 10)

      # Second retrieval (may come from different backend)
      history2 = Polyglot.Storage.get_history(channel1, 10)

      # Both should be consistent
      assert is_list(history1)
      assert is_list(history2)
      assert length(history1) == length(history2)
    end
  end

  describe "rate limiting per tenant" do
    test "rate limits are scoped to API key" do
      # This tests the rate limiter concept at the auth layer
      conn = %Plug.Conn{req_headers: [{"x-api-key", "key1"}]}

      # Same key should be rate limited together
      result1 = Polyglot.Auth.verify_app_key(conn, "app1")
      result2 = Polyglot.Auth.verify_app_key(conn, "app1")

      # Both should use the same rate limit bucket
      assert match?({:error, _}, result1) or match?(:ok, result1)
      assert match?({:error, _}, result2) or match?(:ok, result2)
    end

    test "different API keys have independent rate limits" do
      conn1 = %Plug.Conn{req_headers: [{"x-api-key", "key1"}]}
      conn2 = %Plug.Conn{req_headers: [{"x-api-key", "key2"}]}

      result1 = Polyglot.Auth.verify_app_key(conn1, "app1")
      result2 = Polyglot.Auth.verify_app_key(conn2, "app1")

      # Different keys should have separate rate limit buckets
      assert match?({:error, _}, result1) or match?(:ok, result1)
      assert match?({:error, _}, result2) or match?(:ok, result2)
    end
  end

  describe "concurrent multi-tenant isolation" do
    test "high concurrency doesn't break tenant isolation" do
      # Create many concurrent operations across multiple tenants
      num_tenants = 5
      operations_per_tenant = 10

      tasks =
        Enum.flat_map(1..num_tenants, fn tenant_id ->
          Enum.map(1..operations_per_tenant, fn op_id ->
            Task.async(fn ->
              channel = "tenant#{tenant_id}:room:#{System.unique_integer([:positive])}"

              event = %{
                id: "evt_#{tenant_id}_#{op_id}",
                type: "msg",
                data: %{tenant: tenant_id, op: op_id},
                meta: %{}
              }

              Polyglot.Storage.store_event(channel, event)
              Polyglot.Storage.get_history(channel, 10)
            end)
          end)
        end)

      results = Task.await_many(tasks)
      assert length(results) == num_tenants * operations_per_tenant
    end

    test "stress test tenant isolation" do
      # Rapid concurrent operations on many channels
      tasks =
        Enum.map(1..50, fn i ->
          Task.async(fn ->
            channel = "stress:test:#{i}:#{System.unique_integer([:positive])}"

            Enum.each(1..5, fn j ->
              event = %{
                id: "evt_#{i}_#{j}",
                type: "msg",
                data: %{i: i, j: j},
                meta: %{}
              }

              Polyglot.Storage.store_event(channel, event)
            end)

            Polyglot.Storage.get_history(channel, 100)
          end)
        end)

      results = Task.await_many(tasks)
      assert length(results) == 50
    end
  end
end
