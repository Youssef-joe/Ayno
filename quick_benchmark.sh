#!/bin/bash

# Quick benchmark without starting servers
echo "=== Quick Benchmark (Components Only) ==="

# Build
make all

# C++ benchmark (standalone)
echo "=== C++ Ultra-Low Latency ==="
cd benchmarks && g++ -std=c++17 -O3 -o cpp_benchmark cpp_benchmark.cpp && ./cpp_benchmark
cd ..

echo "Done! For full system benchmark with servers, run: ./run_benchmark.sh"