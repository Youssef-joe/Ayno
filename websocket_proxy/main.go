package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for dev
	},
}

type Client struct {
	conn    *websocket.Conn
	send    chan []byte
	appID   string
	channel string
	userID  string
}

type Hub struct {
	clients    map[*Client]bool
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
	mu         sync.RWMutex
}

type Message struct {
	Type string      `json:"type"`
	Data interface{} `json:"data"`
}

type EventData struct {
	Text string `json:"text"`
}

type PublishPayload struct {
	Type string    `json:"type"`
	Data EventData `json:"data"`
}

const (
	elixirURL     = "http://localhost:4000"
	pollInterval  = 300 * time.Millisecond
	writeWait     = 10 * time.Second
	pongWait      = 60 * time.Second
	pingInterval  = (pongWait * 9) / 10
	maxMessageSize = 512 * 1024
)

var hub = &Hub{
	clients:    make(map[*Client]bool),
	broadcast:  make(chan []byte, 256),
	register:   make(chan *Client),
	unregister: make(chan *Client),
}

func (h *Hub) run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()
			log.Printf("[REGISTER] Client %s joined channel %s:%s", client.userID, client.appID, client.channel)

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
			}
			h.mu.Unlock()
			log.Printf("[UNREGISTER] Client %s left channel %s:%s", client.userID, client.appID, client.channel)

		case message := <-h.broadcast:
			h.mu.RLock()
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					// Client's send channel is full, drop message
				}
			}
			h.mu.RUnlock()
		}
	}
}

func (c *Client) readPump() {
	defer func() {
		hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error: %v", err)
			}
			break
		}

		// Parse incoming message
		var msg map[string]interface{}
		if err := json.Unmarshal(message, &msg); err != nil {
			log.Printf("Failed to parse message: %v", err)
			continue
		}

		// Handle publish events
		if event, ok := msg["event"].(string); ok && event == "publish" {
			if payload, ok := msg["payload"].(map[string]interface{}); ok {
				c.publishEvent(payload)
			}
		}
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(pingInterval)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (c *Client) publishEvent(payload map[string]interface{}) {
	// Extract type and data from payload
	eventType := "message"
	if t, ok := payload["type"].(string); ok {
		eventType = t
	}

	eventData := map[string]interface{}{}
	if data, ok := payload["data"].(map[string]interface{}); ok {
		eventData = data
	}

	// Forward to Elixir API
	publishPayload := PublishPayload{
		Type: eventType,
		Data: EventData{
			Text: fmt.Sprintf("%v", eventData["text"]),
		},
	}

	jsonPayload, err := json.Marshal(publishPayload)
	if err != nil {
		log.Printf("Failed to marshal payload: %v", err)
		return
	}

	url := fmt.Sprintf("%s/apps/%s/channels/%s/publish", elixirURL, c.appID, c.channel)
	apiKey := os.Getenv("API_KEY_" + strings.ToUpper(strings.ReplaceAll(c.appID, "-", "_")))
	if apiKey == "" {
		apiKey = fmt.Sprintf("valid_key_%s", c.appID)
	}

	req, _ := http.NewRequest("POST", url, bytes.NewBuffer(jsonPayload))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-API-Key", apiKey)
	req.Header.Set("X-User-Id", c.userID)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Printf("Failed to publish event: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		log.Printf("Publish failed with status %d", resp.StatusCode)
	}

	log.Printf("[PUBLISH] %s: %v", c.userID, eventData["text"])
}

func handleWS(w http.ResponseWriter, r *http.Request) {
	appID := r.URL.Query().Get("app_id")
	channel := r.URL.Query().Get("channel")
	userID := r.URL.Query().Get("user_id")

	if appID == "" {
		http.Error(w, "Missing app_id", http.StatusBadRequest)
		return
	}
	if channel == "" {
		channel = "room:default"
	}
	if userID == "" {
		userID = fmt.Sprintf("user_%d", time.Now().UnixNano())
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Upgrade error:", err)
		return
	}

	client := &Client{
		conn:    conn,
		send:    make(chan []byte, 256),
		appID:   appID,
		channel: channel,
		userID:  userID,
	}

	hub.register <- client

	go client.writePump()
	go client.readPump()
	go client.pollMessages()
}

func (c *Client) pollMessages() {
	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()

	var lastEventNum int64

	for range ticker.C {
		url := fmt.Sprintf("%s/apps/%s/channels/%s/history?limit=50", elixirURL, c.appID, c.channel)
		resp, err := http.Get(url)
		if err != nil {
			continue
		}

		var result map[string]interface{}
		json.NewDecoder(resp.Body).Decode(&result)
		resp.Body.Close()

		if events, ok := result["events"].([]interface{}); ok {
			// Process in reverse order (newest first) and stop at last seen
			for i := len(events) - 1; i >= 0; i-- {
				e := events[i]
				event, ok := e.(map[string]interface{})
				if !ok {
					continue
				}

				eventID, _ := event["id"].(string)
				var eventNum int64
				fmt.Sscanf(eventID, "evt_%d", &eventNum)

				if eventNum <= lastEventNum {
					continue
				}

				lastEventNum = eventNum

				// Build message
				msg := map[string]interface{}{
					"event": "broadcast",
					"payload": map[string]interface{}{
						"data": event["data"],
						"meta": event["meta"],
					},
				}

				jsonMsg, _ := json.Marshal(msg)
				select {
				case c.send <- jsonMsg:
				default:
					// Channel full, skip
				}
			}
		}
	}
}

func main() {
	go hub.run()

	http.HandleFunc("/socket", handleWS)
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	})

	port := ":3000"
	log.Printf("WebSocket proxy listening on ws://localhost:3000/socket")
	log.Fatal(http.ListenAndServe(port, nil))
}
