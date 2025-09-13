package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"
)

type LatencyResult struct {
	Min    time.Duration
	Max    time.Duration
	Avg    time.Duration
	P95    time.Duration
	P99    time.Duration
}

func benchmarkLatency(requests int, concurrency int) LatencyResult {
	var wg sync.WaitGroup
	latencies := make([]time.Duration, requests)
	
	semaphore := make(chan struct{}, concurrency)
	
	for i := 0; i < requests; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			semaphore <- struct{}{}
			
			start := time.Now()
			makeRequest()
			latencies[idx] = time.Since(start)
			
			<-semaphore
		}(i)
	}
	
	wg.Wait()
	
	return calculateStats(latencies)
}

func makeRequest() {
	event := map[string]interface{}{
		"id":      fmt.Sprintf("evt_%d", time.Now().UnixNano()),
		"app_id":  "benchmark",
		"channel": "ticker:BTCUSD",
		"type":    "price_update",
		"data":    map[string]interface{}{"price": 50000.0},
	}
	
	data, _ := json.Marshal(event)
	http.Post("http://localhost:8080/process", "application/json", bytes.NewBuffer(data))
}

func calculateStats(latencies []time.Duration) LatencyResult {
	// Simple stats calculation
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
	
	return LatencyResult{
		Min: min,
		Max: max,
		Avg: total / time.Duration(len(latencies)),
		P95: latencies[int(float64(len(latencies))*0.95)],
		P99: latencies[int(float64(len(latencies))*0.99)],
	}
}

func main() {
	fmt.Println("Running Go processor latency benchmark...")
	
	result := benchmarkLatency(10000, 100)
	
	fmt.Printf("Latency Results:\n")
	fmt.Printf("Min: %v\n", result.Min)
	fmt.Printf("Max: %v\n", result.Max)
	fmt.Printf("Avg: %v\n", result.Avg)
	fmt.Printf("P95: %v\n", result.P95)
	fmt.Printf("P99: %v\n", result.P99)
}