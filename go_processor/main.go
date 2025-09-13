package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os/exec"
	"time"
)

type Event struct {
	ID      string                 `json:"id"`
	AppID   string                 `json:"app_id"`
	Channel string                 `json:"channel"`
	Type    string                 `json:"type"`
	Data    map[string]interface{} `json:"data"`
	Meta    map[string]interface{} `json:"meta"`
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
	return p.cppEnabled && (event.Channel[:7] == "ticker:" || event.Channel[:6] == "match:")
}

func (p *Processor) processCpp(event Event) error {
	data, _ := json.Marshal(event)
	cmd := exec.Command("./cpp_driver/driver", string(data))
	return cmd.Run()
}

func main() {
	processor := &Processor{cppEnabled: true}
	
	http.HandleFunc("/process", func(w http.ResponseWriter, r *http.Request) {
		var event Event
		json.NewDecoder(r.Body).Decode(&event)
		
		start := time.Now()
		err := processor.processEvent(event)
		duration := time.Since(start)
		
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		
		json.NewEncoder(w).Encode(map[string]interface{}{
			"processed": true,
			"duration_ms": duration.Nanoseconds() / 1000000,
		})
	})
	
	log.Println("Go processor starting on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}