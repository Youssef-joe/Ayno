#!/bin/bash

echo "=== Polyglot Realtime Engine Benchmark ==="

# Build all components
echo "Building components..."
make all

# Start Go processor in background
echo "Starting Go processor..."
cd go_processor && ./processor &
GO_PID=$!
cd ..

# Wait for Go processor to start
sleep 2

# Start Elixir server in background
echo "Starting Elixir gateway..."
mix deps.get
mix phx.server &
ELIXIR_PID=$!

# Wait for services to start
sleep 5

echo "Running benchmarks..."

# Run Go latency benchmark
echo "=== Go Processor Latency Test ==="
cd benchmarks && go run latency_test.go
cd ..

# Run C++ benchmark
echo "=== C++ Ultra-Low Latency Test ==="
cd benchmarks && g++ -std=c++17 -O3 -o cpp_benchmark cpp_benchmark.cpp && ./cpp_benchmark
cd ..

# Run Elixir benchmark
echo "=== Elixir Gateway Benchmark ==="
mix run benchmarks/benchmark.exs

# Cleanup
echo "Cleaning up..."
kill $GO_PID $ELIXIR_PID 2>/dev/null

echo "Benchmark complete!"