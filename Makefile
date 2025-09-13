all: build-cpp build-go

build-cpp:
	cd cpp_driver && make

build-go:
	cd go_processor && go build -o processor main.go

start-elixir:
	mix phx.server

start-go:
	cd go_processor && ./processor

benchmark-all: build-cpp build-go
	@echo "Running full system benchmark..."
	cd benchmarks && go run latency_test.go
	cd benchmarks && g++ -std=c++17 -O3 -o cpp_benchmark cpp_benchmark.cpp && ./cpp_benchmark
	mix run benchmarks/benchmark.exs

clean:
	cd cpp_driver && make clean
	cd go_processor && rm -f processor
	cd benchmarks && rm -f cpp_benchmark

.PHONY: all build-cpp build-go start-elixir start-go benchmark-all clean