defmodule Polyglot.Benchmark do
  def run_websocket_benchmark(concurrent_clients \\ 100, messages_per_client \\ 1000) do
    IO.puts("Starting WebSocket benchmark: #{concurrent_clients} clients, #{messages_per_client} messages each")
    
    start_time = System.monotonic_time(:millisecond)
    
    tasks = for i <- 1..concurrent_clients do
      Task.async(fn -> simulate_client(i, messages_per_client) end)
    end
    
    results = Task.await_many(tasks, 30_000)
    
    end_time = System.monotonic_time(:millisecond)
    total_time = end_time - start_time
    total_messages = concurrent_clients * messages_per_client
    
    IO.puts("Benchmark Results:")
    IO.puts("Total time: #{total_time}ms")
    IO.puts("Total messages: #{total_messages}")
    IO.puts("Messages/second: #{round(total_messages / (total_time / 1000))}")
    IO.puts("Average latency: #{total_time / total_messages}ms per message")
    
    results
  end
  
  def run_http_benchmark(concurrent_requests \\ 1000) do
    IO.puts("Starting HTTP benchmark: #{concurrent_requests} concurrent requests")
    
    start_time = System.monotonic_time(:millisecond)
    
    tasks = for i <- 1..concurrent_requests do
      Task.async(fn -> http_request(i) end)
    end
    
    results = Task.await_many(tasks, 30_000)
    
    end_time = System.monotonic_time(:millisecond)
    total_time = end_time - start_time
    
    successful = Enum.count(results, &(&1 == :ok))
    
    IO.puts("HTTP Benchmark Results:")
    IO.puts("Total time: #{total_time}ms")
    IO.puts("Successful requests: #{successful}/#{concurrent_requests}")
    IO.puts("Requests/second: #{round(concurrent_requests / (total_time / 1000))}")
    
    results
  end
  
  defp simulate_client(client_id, message_count) do
    # Simulate WebSocket client sending messages
    for _ <- 1..message_count do
      :timer.sleep(1)
    end
    :ok
  end
  
  defp http_request(request_id) do
    url = "http://localhost:4000/apps/benchmark-app/channels/room:test/publish"
    headers = [{"Content-Type", "application/json"}, {"X-API-Key", "valid_key_benchmark-app"}]
    body = Jason.encode!(%{
      type: "benchmark",
      data: %{message: "test message #{request_id}"}
    })
    
    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200}} -> :ok
      _ -> :error
    end
  end
end

# Run benchmarks
Polyglot.Benchmark.run_websocket_benchmark(50, 100)
Polyglot.Benchmark.run_http_benchmark(500)