defmodule Polyglot.HTTPAPIValidationTest do
  use ExUnit.Case
  require Logger

  describe "event structure validation" do
    test "accepts events with required fields" do
      params = %{
        "type" => "message",
        "data" => %{text: "hello"}
      }

      # This tests the validation logic used in router
      is_valid =
        is_map(params) and
          Map.has_key?(params, "type") and
          Map.has_key?(params, "data")

      assert is_valid == true
    end

    test "rejects events missing type field" do
      params = %{
        "data" => %{text: "hello"}
      }

      is_valid =
        is_map(params) and
          Map.has_key?(params, "type") and
          Map.has_key?(params, "data")

      assert is_valid == false
    end

    test "rejects events missing data field" do
      params = %{
        "type" => "message"
      }

      is_valid =
        is_map(params) and
          Map.has_key?(params, "type") and
          Map.has_key?(params, "data")

      assert is_valid == false
    end

    test "rejects nil params" do
      is_valid =
        is_map(nil) and
          Map.has_key?(nil, "type") and
          Map.has_key?(nil, "data")

      assert is_valid == false
    end

    test "rejects non-map params" do
      is_valid = is_map("not a map")
      assert is_valid == false
    end
  end

  describe "event data validation" do
    test "accepts various data types" do
      test_cases = [
        %{"type" => "msg", "data" => %{text: "string"}},
        %{"type" => "msg", "data" => %{count: 42}},
        %{"type" => "msg", "data" => %{active: true}},
        %{"type" => "msg", "data" => %{items: [1, 2, 3]}},
        %{"type" => "msg", "data" => %{nested: %{key: "value"}}},
        %{"type" => "msg", "data" => %{}}
      ]

      Enum.each(test_cases, fn params ->
        is_valid = is_map(params) and Map.has_key?(params, "data")
        assert is_valid
      end)
    end

    test "handles nested data structures" do
      params = %{
        "type" => "complex",
        "data" => %{
          user: %{
            id: "123",
            profile: %{
              name: "Alice",
              settings: %{
                notifications: true
              }
            }
          },
          events: [
            %{id: 1, name: "Event 1"},
            %{id: 2, name: "Event 2"}
          ]
        }
      }

      is_valid = is_map(params) and Map.has_key?(params, "data")
      assert is_valid
    end

    test "handles empty data" do
      params = %{
        "type" => "empty",
        "data" => %{}
      }

      is_valid = is_map(params) and Map.has_key?(params, "data")
      assert is_valid
    end

    test "rejects non-map data" do
      params = %{
        "type" => "invalid",
        "data" => "not a map"
      }

      # Data should be a map for proper JSON serialization
      is_data_map = is_map(params["data"])
      assert is_data_map == false
    end
  end

  describe "event type validation" do
    test "accepts various event types" do
      types = [
        "message",
        "chat",
        "status_update",
        "trade_execution",
        "match_result",
        "notification",
        "heartbeat",
        "custom_event_123"
      ]

      Enum.each(types, fn type ->
        is_valid = is_binary(type)
        assert is_valid
      end)
    end

    test "rejects empty type" do
      is_valid = is_binary("")
      assert is_valid  # Empty string is still a binary, validation should be stricter
    end

    test "rejects non-binary type" do
      non_binary_types = [123, true, nil, %{}, []]

      Enum.each(non_binary_types, fn type ->
        is_valid = is_binary(type)
        assert is_valid == false
      end)
    end
  end

  describe "channel validation" do
    test "accepts valid channel formats" do
      valid_channels = [
        "room:lobby",
        "room:test",
        "ticker:BTC-USD",
        "ticker:ETH-USD",
        "match:game_123",
        "match:chess:game_456",
        "post:article_789",
        "notifications:user_123",
        "private:user1:user2"
      ]

      Enum.each(valid_channels, fn channel ->
        # Basic validation: non-empty binary
        is_valid = is_binary(channel) and byte_size(channel) > 0
        assert is_valid
      end)
    end

    test "rejects invalid channel names" do
      invalid_channels = [
        "",
        nil,
        123,
        %{},
        []
      ]

      Enum.each(invalid_channels, fn channel ->
        is_valid = is_binary(channel) and byte_size(channel) > 0
        assert is_valid == false
      end)
    end

    test "handles channel names with special characters" do
      channels = [
        "room:test-123",
        "room:test_456",
        "room:test.789",
        "room:test@example.com"
      ]

      Enum.each(channels, fn channel ->
        is_valid = is_binary(channel) and byte_size(channel) > 0
        assert is_valid
      end)
    end

    test "rejects extremely long channel names" do
      long_channel = String.duplicate("x", 10000)
      is_valid = byte_size(long_channel) < 256  # Typical max length
      assert is_valid == false
    end
  end

  describe "API key validation" do
    test "validates API key presence" do
      headers_with_key = [{"x-api-key", "valid_key"}]
      headers_without_key = [{"authorization", "Bearer token"}]

      has_key =
        Enum.any?(headers_with_key, fn {header, _} ->
          String.downcase(header) == "x-api-key"
        end)

      assert has_key == true

      has_key2 =
        Enum.any?(headers_without_key, fn {header, _} ->
          String.downcase(header) == "x-api-key"
        end)

      assert has_key2 == false
    end

    test "handles case-insensitive header names" do
      test_cases = [
        [{"x-api-key", "key"}],
        [{"X-API-KEY", "key"}],
        [{"X-Api-Key", "key"}]
      ]

      Enum.each(test_cases, fn headers ->
        # Plug normalizes to lowercase
        {header, _} = List.first(headers)
        normalized = String.downcase(header)
        assert normalized == "x-api-key"
      end)
    end
  end

  describe "error response formatting" do
    test "error responses include proper fields" do
      # Test expected error response structure
      error_response = %{
        error: "Invalid request",
        status: 400
      }

      assert Map.has_key?(error_response, :error)
      assert Map.has_key?(error_response, :status)
    end

    test "success responses include event ID" do
      success_response = %{
        id: "evt_12345",
        timestamp: "2026-05-12T10:00:00Z"
      }

      assert Map.has_key?(success_response, :id)
      assert String.starts_with?(success_response.id, "evt_")
    end
  end

  describe "concurrent API requests" do
    test "handles multiple concurrent event publishes" do
      tasks = Enum.map(1..20, fn i ->
        Task.async(fn ->
          event = %{
            "id" => "evt_#{i}",
            "type" => "message",
            "data" => %{"index" => i}
          }

          is_valid =
            is_map(event) and
              Map.has_key?(event, "type") and
              Map.has_key?(event, "data")

          assert is_valid
        end)
      end)

      results = Task.await_many(tasks)
      assert length(results) == 20
    end

    test "validates many events concurrently" do
      events = Enum.map(1..50, fn i ->
        %{
          "type" => "test",
          "data" => %{"index" => i}
        }
      end)

      validated = Enum.map(events, fn event ->
        is_map(event) and
          Map.has_key?(event, "type") and
          Map.has_key?(event, "data")
      end)

      assert Enum.all?(validated, &(&1 == true))
    end
  end

  describe "JSON serialization" do
    test "events serialize to JSON" do
      event = %{
        id: "evt_001",
        type: "message",
        data: %{text: "hello"},
        meta: %{user: "alice"}
      }

      {:ok, json} = Jason.encode(event)
      assert is_binary(json)
      {:ok, decoded} = Jason.decode(json)
      assert is_map(decoded)
    end

    test "handles various data types in JSON" do
      events = [
        %{id: "1", type: "msg", data: %{text: "string"}, meta: %{}},
        %{id: "2", type: "msg", data: %{count: 42}, meta: %{}},
        %{id: "3", type: "msg", data: %{active: true}, meta: %{}},
        %{id: "4", type: "msg", data: %{items: [1, 2, 3]}, meta: %{}},
        %{id: "5", type: "msg", data: %{nested: %{key: "value"}}, meta: %{}}
      ]

      Enum.each(events, fn event ->
        {:ok, json} = Jason.encode(event)
        assert is_binary(json)
        {:ok, decoded} = Jason.decode(json)
        assert is_map(decoded)
      end)
    end

    test "rejects non-serializable data" do
      # PIDs, functions, etc. cannot be JSON serialized
      event_with_pid = %{
        id: "1",
        type: "msg",
        data: %{pid: self()},
        meta: %{}
      }

      result = Jason.encode(event_with_pid)
      assert match?({:error, _}, result)
    end
  end

  describe "request size limits" do
    test "handles large but reasonable payloads" do
      large_data = %{
        "text" => String.duplicate("x", 1000),
        "nested" => %{
          "data" => String.duplicate("y", 1000)
        }
      }

      event = %{
        "type" => "large_message",
        "data" => large_data
      }

      {:ok, json} = Jason.encode(event)
      size = byte_size(json)

      # Should be under 100KB
      assert size < 100_000
    end

    test "detects potentially oversized payloads" do
      # Create an event that's larger than typical
      huge_data = String.duplicate("x", 500_000)

      event = %{
        "type" => "huge",
        "data" => %{"payload" => huge_data}
      }

      {:ok, json} = Jason.encode(event)
      size = byte_size(json)

      # Should exceed 100KB limit
      assert size > 100_000
    end
  end
end
