#include <iostream>
#include <chrono>
#include <vector>
#include <thread>
#include <algorithm>

class CppBenchmark {
private:
    std::vector<std::chrono::microseconds> latencies;
    
public:
    void run_benchmark(int iterations = 100000) {
        std::cout << "Running C++ ultra-low latency benchmark..." << std::endl;
        
        latencies.reserve(iterations);
        
        for (int i = 0; i < iterations; ++i) {
            auto start = std::chrono::high_resolution_clock::now();
            
            // Simulate ultra-fast processing
            volatile int dummy = i * 2;
            
            auto end = std::chrono::high_resolution_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
            latencies.push_back(duration);
        }
        
        print_stats();
    }
    
private:
    void print_stats() {
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
        
        std::cout << "C++ Latency Results:" << std::endl;
        std::cout << "Min: " << min.count() << " μs" << std::endl;
        std::cout << "Max: " << max.count() << " μs" << std::endl;
        std::cout << "Avg: " << avg << " μs" << std::endl;
        std::cout << "P95: " << p95.count() << " μs" << std::endl;
        std::cout << "P99: " << p99.count() << " μs" << std::endl;
    }
};

int main() {
    CppBenchmark benchmark;
    benchmark.run_benchmark();
    return 0;
}