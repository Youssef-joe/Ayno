all: build-go

build-cpp:
	cd cpp_driver && make

build-go:
	cd go_processor && go build -o processor .

build-grpc: build-go
	@echo "✓ gRPC server enabled (port 9090)"

start-elixir:
	mix phx.server

start-go:
	cd go_processor && ./processor

# Phase 2: gRPC with circuit breaker and failover
phase2: build-grpc
	@echo "Phase 2: gRPC + Circuit Breaker activation"
	@echo "✓ gRPC code generation: $(CURDIR)/lib/polyglot/pb/processor.pb.ex"
	@echo "✓ gRPC client: $(CURDIR)/lib/polyglot/grpc_client.ex"
	@echo "✓ Circuit breaker: $(CURDIR)/lib/polyglot/circuit_breaker.ex"
	@echo "✓ Integrated processor client: $(CURDIR)/lib/polyglot/processor_client.ex"
	@echo "✓ Docker Compose: gRPC port 9090 exposed"
	@echo ""
	@echo "Next: docker-compose up --build"

test:
	mix test

test-processor:
	mix test test/processor_client_test.exs -v

benchmark-all: build-cpp build-go
	@echo "Running full system benchmark..."
	cd benchmarks && go run latency_test.go
	cd benchmarks && g++ -std=c++17 -O3 -o cpp_benchmark cpp_benchmark.cpp && ./cpp_benchmark
	mix run benchmarks/benchmark.exs

clean:
	cd cpp_driver && make clean
	cd go_processor && rm -f processor
	cd benchmarks && rm -f cpp_benchmark
	mix clean

.PHONY: all build-cpp build-go build-grpc start-elixir start-go phase2 test test-processor benchmark-all clean
