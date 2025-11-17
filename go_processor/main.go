package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/exec"
	"time"

	"google.golang.org/grpc"
)

type Event struct {
	ID      string                 `json:"id"`
	AppID   string                 `json:"app_id"`
	Channel string                 `json:"channel"`
	Type    string                 `json:"type"`
	Data    map[string]interface{} `json:"data"`
	Meta    map[string]interface{} `json:"meta"`
}

type BatchRequest struct {
	Events []Event `json:"events"`
}

type Processor struct {
	cppEnabled bool
}

func (p *Processor) processEvent(event Event) error {
	// High-frequency events go to C++ layer
	if p.shouldUseCpp(event) {
		return p.processCpp(event)
	}
	
	// Standard processing
	log.Printf("Processing event %s for app %s", event.ID, event.AppID)
	
	// Simulate analytics, storage, webhooks
	time.Sleep(1 * time.Millisecond)
	return nil
}

func (p *Processor) shouldUseCpp(event Event) bool {
	if !p.cppEnabled || len(event.Channel) < 6 {
		return false
	}
	return (len(event.Channel) >= 7 && event.Channel[:7] == "ticker:") || 
	       (len(event.Channel) >= 6 && event.Channel[:6] == "match:")
}

func (p *Processor) processCpp(event Event) error {
	driverPath := "./cpp_driver/driver"
	if _, err := os.Stat(driverPath); os.IsNotExist(err) {
		// C++ driver not available, fall back to standard processing
		log.Printf("C++ driver not found at %s, falling back to Go processing", driverPath)
		return nil
	}
	
	data, err := json.Marshal(event)
	if err != nil {
		return err
	}
	
	cmd := exec.Command(driverPath, string(data))
	return cmd.Run()
}

func NewGrpcServer() *grpc.Server {
	return grpc.NewServer()
}

func main() {
	processor := &Processor{cppEnabled: true}
	
	// Start gRPC server on 9090
	go func() {
		if err := StartGRPCServer("9090", processor); err != nil {
			log.Printf("gRPC server error: %v", err)
		}
	}()
	
	// Single event processing
	http.HandleFunc("/process", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}
		
		var event Event
		if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
			http.Error(w, "Invalid JSON: "+err.Error(), http.StatusBadRequest)
			return
		}
		
		start := time.Now()
		err := processor.processEvent(event)
		duration := time.Since(start)
		
		if err != nil {
			log.Printf("Error processing event: %v", err)
			http.Error(w, "Processing error: "+err.Error(), http.StatusInternalServerError)
			return
		}
		
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"processed": true,
			"duration_ms": duration.Nanoseconds() / 1000000,
		})
	})
	
	// Batch event processing (for Broadway pipeline)
	http.HandleFunc("/process-batch", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}
		
		var batch BatchRequest
		if err := json.NewDecoder(r.Body).Decode(&batch); err != nil {
			http.Error(w, "Invalid JSON: "+err.Error(), http.StatusBadRequest)
			return
		}
		
		if len(batch.Events) == 0 {
			http.Error(w, "Empty batch", http.StatusBadRequest)
			return
		}
		
		start := time.Now()
		processed := 0
		failed := 0
		
		for _, event := range batch.Events {
			if err := processor.processEvent(event); err != nil {
				log.Printf("Error processing event in batch: %v", err)
				failed++
			} else {
				processed++
			}
		}
		
		duration := time.Since(start)
		
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"processed": processed,
			"failed": failed,
			"total": len(batch.Events),
			"duration_ms": duration.Nanoseconds() / 1000000,
		})
	})
	
	// Health check endpoint
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	})
	
	log.Println("Go processor starting on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}