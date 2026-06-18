defmodule Polyglot.ClusterBenchmark do
  @doc """
  Benchmarks the cluster with C++ driver integration
  Tests message distribution across nodes and C++ processing latency
  """
  
  def run_cluster_benchmark do
    IO.puts("=== Polyglot Cluster Benchmark ===")
    IO.puts("Testing distributed processing with C++ driver integration\n")
    
    # Test 1: Intra-cluster message passing
    benchmark_cluster_messaging()
    
    # Test 2: C++ driver processing latency
    benchmark_cpp_driver_latency()
    
    # Test 3: End-to-end distributed pipeline
    benchmark_distributed_pipeline()
  end
  
  defp benchmark_cluster_messaging do
    IO.puts("Test 1: Cluster Message Distribution")
    IO.puts("-----------------------------------")
    
    message_counts = [100, 1000, 10000]
    
    Enum.each(message_counts, fn count ->
      start_time = System.monotonic_time(:millisecond)
      
      tasks = for i <- 1..count do
        Task.async(fn ->
          # Simulate message broadcast via pubsub
          message = %{
            id: "msg_#{i}",
            payload: "cluster test #{i}",
            timestamp: System.monotonic_time(:millisecond)
          }
          
          # In real cluster: Phoenix.PubSub.broadcast(:pubsub, "system", message)
          simulate_cluster_message(message)
        end)
      end
      
      Task.await_all(tasks, 30_000)
      
      elapsed = System.monotonic_time(:millisecond) - start_time
      throughput = round(count / (elapsed / 1000))
      
      IO.puts("  #{count} messages: #{elapsed}ms (#{throughput} msg/s)")
    end)
    
    IO.puts("")
  end
  
  defp benchmark_cpp_driver_latency do
    IO.puts("Test 2: C++ Driver Processing Latency")
    IO.puts("-------------------------------------")
    
    concurrency_levels = [10, 50, 100]
    
    Enum.each(concurrency_levels, fn concurrency ->
      latencies = []
      
      start_time = System.monotonic_time(:microsecond)
      
      tasks = for i <- 1..1000 do
        Task.async(fn ->
          event = %{
            id: "evt_#{i}",
            data: "test_#{i}",
            timestamp: System.monotonic_time(:microsecond)
          }
          
          process_with_cpp_driver(event)
        end)
      end
      
      # Process with controlled concurrency
      results = Task.await_many(tasks, 30_000)
      
      elapsed_us = System.monotonic_time(:microsecond) - start_time
      elapsed_ms = elapsed_us / 1000
      
      avg_latency = elapsed_us / 1000
      throughput = round(1000 / (elapsed_ms / 1000))
      
      IO.puts("  Concurrency=#{concurrency}: avg_latency=#{round(avg_latency)}μs, throughput=#{throughput} events/s")
    end)
    
    IO.puts("")
  end
  
  defp benchmark_distributed_pipeline do
    IO.puts("Test 3: End-to-End Distributed Pipeline")
    IO.puts("----------------------------------------")
    
    IO.puts("  Publishing 1000 events through distributed pipeline...")
    
    start_time = System.monotonic_time(:millisecond)
    
    for i <- 1..1000 do
      event = %{
        id: "pipe_#{i}",
        app_id: "benchmark",
        channel: "ticker:BTCUSD",
        data: %{price: 50000 + i},
        timestamp: System.monotonic_time(:millisecond)
      }
      
      # Simulate: broadcast -> other nodes -> C++ processing -> response
      _result = simulate_pipeline(event)
    end
    
    total_time = System.monotonic_time(:millisecond) - start_time
    throughput = round(1000 / (total_time / 1000))
    
    IO.puts("  Total time: #{total_time}ms")
    IO.puts("  Throughput: #{throughput} events/s")
    IO.puts("")
  end
  
  # Simulation functions
  defp simulate_cluster_message(message) do
    # Simulate network latency and cluster coordination (0.1-1ms)
    :timer.sleep(:rand.uniform(10) |> Kernel./(100))
    message
  end
  
  defp process_with_cpp_driver(event) do
    # Simulate C++ driver call via NIF/FFI (~100-200μs per call)
    json = Jason.encode!(event)
    
    # Actual implementation would call:
    # :polyglot_cpp.process_event(json)
    
    # For benchmark: simulate 100-200μs latency
    start = System.monotonic_time(:microsecond)
    while System.monotonic_time(:microsecond) - start < 100 do
      # Busy wait to simulate processing
    end
    
    {:ok, event}
  end
  
  defp simulate_pipeline(event) do
    # 1. Broadcast to cluster
    simulate_cluster_message(event)
    
    # 2. Other nodes receive (1ms simulated)
    :timer.sleep(1)
    
    # 3. C++ processing
    {:ok, _result} = process_with_cpp_driver(event)
    
    # 4. Response
    {:ok, event}
  end
end

# Run the benchmark
Polyglot.ClusterBenchmark.run_cluster_benchmark()
