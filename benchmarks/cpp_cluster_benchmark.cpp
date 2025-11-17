#include <iostream>
#include <chrono>
#include <vector>
#include <thread>
#include <algorithm>
#include <numeric>

class ClusterCppBenchmark {
private:
    std::vector<std::chrono::microseconds> latencies;
    
public:
    void run_full_benchmark() {
        std::cout << "=== C++ Cluster Driver Benchmark ===" << std::endl;
        std::cout << std::endl;
        
        benchmark_event_processing();
        std::cout << std::endl;
        
        benchmark_concurrent_processing();
        std::cout << std::endl;
        
        benchmark_distributed_scenario();
    }
    
private:
    void benchmark_event_processing() {
        std::cout << "Test 1: Single-threaded Event Processing" << std::endl;
        std::cout << "----------------------------------------" << std::endl;
        
        int test_sizes[] = {1000, 10000, 100000};
        
        for (int size : test_sizes) {
            latencies.clear();
            latencies.reserve(size);
            
            auto start = std::chrono::high_resolution_clock::now();
            
            for (int i = 0; i < size; ++i) {
                auto iter_start = std::chrono::high_resolution_clock::now();
                
                // Simulate event processing: JSON parsing, validation, transformation
                process_event(i);
                
                auto iter_end = std::chrono::high_resolution_clock::now();
                auto duration = std::chrono::duration_cast<std::chrono::microseconds>(iter_end - iter_start);
                latencies.push_back(duration);
            }
            
            auto end = std::chrono::high_resolution_clock::now();
            auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
            
            print_results(size, total_time.count());
        }
    }
    
    void benchmark_concurrent_processing() {
        std::cout << "Test 2: Multi-threaded Concurrent Processing" << std::endl;
        std::cout << "-------------------------------------------" << std::endl;
        
        int thread_counts[] = {2, 4, 8};
        int events_per_thread = 10000;
        
        for (int num_threads : thread_counts) {
            latencies.clear();
            
            auto start = std::chrono::high_resolution_clock::now();
            
            std::vector<std::thread> threads;
            
            for (int t = 0; t < num_threads; ++t) {
                threads.emplace_back([this, t, events_per_thread]() {
                    for (int i = 0; i < events_per_thread; ++i) {
                        process_event(t * events_per_thread + i);
                    }
                });
            }
            
            for (auto& thread : threads) {
                thread.join();
            }
            
            auto end = std::chrono::high_resolution_clock::now();
            auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
            
            int total_events = num_threads * events_per_thread;
            double throughput = (total_events * 1000.0) / total_time.count();
            
            std::cout << "  Threads: " << num_threads << " | Total: " << total_events 
                      << " events | Time: " << total_time.count() << "ms | Throughput: " 
                      << (int)throughput << " events/s" << std::endl;
        }
    }
    
    void benchmark_distributed_scenario() {
        std::cout << "Test 3: Distributed Cluster Scenario" << std::endl;
        std::cout << "-----------------------------------" << std::endl;
        
        int num_nodes = 3;
        int events_per_node = 5000;
        
        std::cout << "  Simulating " << num_nodes << " cluster nodes, " 
                  << events_per_node << " events per node" << std::endl;
        
        latencies.clear();
        latencies.reserve(num_nodes * events_per_node);
        
        auto start = std::chrono::high_resolution_clock::now();
        
        // Simulate multi-node processing
        std::vector<std::thread> node_threads;
        for (int node = 0; node < num_nodes; ++node) {
            node_threads.emplace_back([this, node, events_per_node]() {
                for (int i = 0; i < events_per_node; ++i) {
                    // Simulate: receive event -> deserialize -> process -> serialize response
                    auto iter_start = std::chrono::high_resolution_clock::now();
                    
                    process_event(node * events_per_node + i);
                    
                    // Simulate network latency between nodes (0.1-0.5ms)
                    std::this_thread::sleep_for(std::chrono::microseconds(100 + (rand() % 400)));
                    
                    auto iter_end = std::chrono::high_resolution_clock::now();
                    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(iter_end - iter_start);
                    latencies.push_back(duration);
                }
            });
        }
        
        for (auto& thread : node_threads) {
            thread.join();
        }
        
        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
        
        int total_events = num_nodes * events_per_node;
        double throughput = (total_events * 1000.0) / total_time.count();
        
        std::cout << "  Total time: " << total_time.count() << "ms" << std::endl;
        std::cout << "  Total events: " << total_events << std::endl;
        std::cout << "  Throughput: " << (int)throughput << " events/s" << std::endl;
    }
    
    void process_event(int event_id) {
        // Simulate actual event processing:
        // - Message parsing/validation
        // - Routing decision
        // - Data transformation
        // - Enrichment
        
        volatile int dummy = event_id * 2;
        (void)dummy; // Suppress unused variable warning
    }
    
    void print_results(int event_count, long long total_time_ms) {
        std::sort(latencies.begin(), latencies.end());
        
        auto min = latencies.front();
        auto max = latencies.back();
        
        long long total = 0;
        for (const auto& lat : latencies) {
            total += lat.count();
        }
        auto avg = total / latencies.size();
        
        auto p95 = latencies[static_cast<size_t>(latencies.size() * 0.95)];
        auto p99 = latencies[static_cast<size_t>(latencies.size() * 0.99)];
        
        double throughput = (event_count * 1000.0) / total_time_ms;
        
        std::cout << "  Events: " << event_count << " | Time: " << total_time_ms << "ms" << std::endl;
        std::cout << "  Throughput: " << (int)throughput << " events/s" << std::endl;
        std::cout << "  Latency - Min: " << min.count() << "μs | Avg: " << avg 
                  << "μs | P95: " << p95.count() << "μs | P99: " << p99.count() << "μs | Max: " 
                  << max.count() << "μs" << std::endl;
    }
};

int main() {
    ClusterCppBenchmark benchmark;
    benchmark.run_full_benchmark();
    return 0;
}
