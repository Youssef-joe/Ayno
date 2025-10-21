package main

import (
	"fmt"
	"sync"
	"time"
)

func simulateProcessing() time.Duration {
	start := time.Now()
	
	for i := 0; i < 1000; i++ {
		_ = i * 2
	}
	
	return time.Since(start)
}

func runBenchmark(requests int, concurrency int) {
	fmt.Printf("Running benchmark: %d requests with %d concurrent workers\n", requests, concurrency)
	
	var wg sync.WaitGroup
	latencies := make([]time.Duration, requests)
	semaphore := make(chan struct{}, concurrency)
	
	start := time.Now()
	
	for i := 0; i < requests; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			semaphore <- struct{}{}
			
			latencies[idx] = simulateProcessing()
			
			<-semaphore
		}(i)
	}
	
	wg.Wait()
	totalTime := time.Since(start)
	
	var total time.Duration
	min := latencies[0]
	max := latencies[0]
	
	for _, lat := range latencies {
		total += lat
		if lat < min {
			min = lat
		}
		if lat > max {
			max = lat
		}
	}
	
	avg := total / time.Duration(len(latencies))
	throughput := float64(requests) / totalTime.Seconds()
	
	fmt.Printf("\nResults:\n")
	fmt.Printf("Total time: %v\n", totalTime)
	fmt.Printf("Throughput: %.0f requests/sec\n", throughput)
	fmt.Printf("Min latency: %v\n", min)
	fmt.Printf("Max latency: %v\n", max)
	fmt.Printf("Avg latency: %v\n", avg)
}

func main() {
	fmt.Println("=== Polyglot Performance Benchmark ===")
	
	runBenchmark(1000, 10)
	fmt.Println()
	runBenchmark(10000, 100)
	fmt.Println()
	runBenchmark(50000, 500)
}