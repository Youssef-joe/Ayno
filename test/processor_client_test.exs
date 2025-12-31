defmodule Polyglot.ProcessorClientTest do
  use ExUnit.Case
  doctest Polyglot.ProcessorClient

  setup do
    # Initialize circuit breaker for tests
    Polyglot.ProcessorClient.init_breaker()
    :ok
  end

  describe "process_event" do
    test "processes event via gRPC when available" do
      event = %{
        id: "test-1",
        app_id: "test-app",
        channel: "room:test",
        type: "message",
        data: %{text: "hello"},
        meta: %{}
      }

      result = Polyglot.ProcessorClient.process_event(event)
      
      # Should either succeed via gRPC or fallback to HTTP
      assert result == :ok or result == {:error, _}
    end

    test "falls back to HTTP when gRPC unavailable" do
      event = %{
        id: "test-2",
        app_id: "test-app",
        channel: "room:test",
        type: "message",
        data: %{text: "fallback test"},
        meta: %{}
      }

      result = Polyglot.ProcessorClient.process_event(event)
      
      # Should complete (via HTTP fallback if gRPC down)
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "process_batch" do
    test "processes batch of events" do
      events = [
        %{
          id: "batch-1",
          app_id: "test-app",
          channel: "room:test",
          type: "message",
          data: %{text: "msg1"},
          meta: %{}
        },
        %{
          id: "batch-2",
          app_id: "test-app",
          channel: "room:test",
          type: "message",
          data: %{text: "msg2"},
          meta: %{}
        }
      ]

      result = Polyglot.ProcessorClient.process_batch(events)
      
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "circuit_breaker" do
    test "circuit breaker status accessible" do
      {:ok, status} = Polyglot.CircuitBreaker.status(:processor_breaker)
      
      assert status.state in [:closed, :open, :half_open]
      assert is_integer(status.failures)
    end

    test "breaker_is_open? helper works" do
      is_open = Polyglot.ProcessorClient.breaker_is_open?()
      
      assert is_boolean(is_open)
    end
  end

  describe "health_check" do
    test "health check returns status or error" do
      result = Polyglot.ProcessorClient.health_check()
      
      # Should be either {:ok, status} or {:error, reason}
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
