# Polyglot Realtime Engine

Multi-tenant realtime platform built with Elixir Phoenix. Supports WebSocket and HTTP APIs for chat, trading, gaming, and any realtime application.

## Features

- **Multi-tenant channels**: `room:*`, `ticker:*`, `match:*`, `post:*`
- **WebSocket & HTTP APIs**: Real-time and REST endpoints
- **Authentication**: Token-based auth per app and user
- **Rate limiting**: Per-tenant limits (Redis-backed)
- **Pub/Sub**: Phoenix PubSub for message distribution

## Quick Start

1. Build all components:
```bash
make all
```

2. Start services:
```bash
# Terminal 1: Elixir Gateway
make start-elixir

# Terminal 2: Go Processor
make start-go
```

3. Run benchmarks:
```bash
# Full system benchmark (starts all services)
./run_benchmark.sh

# Quick component-only benchmark
./quick_benchmark.sh

# Manual benchmark
make benchmark-all
```

3. Connect via WebSocket:
```javascript
const socket = new Socket("ws://localhost:4000/socket", {
  params: { app_id: "your-app", token: "valid_token_user123" }
});
```

## API Examples

### WebSocket
```javascript
// Subscribe to a room
const channel = socket.channel("room:lobby", {});
channel.join();

// Publish message
channel.push("publish", {
  type: "message", 
  data: { text: "Hello" }
});
```

### REST API
```bash
# Publish event
curl -X POST http://localhost:4000/apps/chat-app/channels/room:lobby/publish \
  -H "Content-Type: application/json" \
  -H "X-API-Key: valid_key_chat-app" \
  -d '{"type": "message", "data": {"text": "Hello"}}'

# Get history
curl http://localhost:4000/apps/chat-app/channels/room:lobby/history
```

## Architecture

```
CLIENT APPS → ELIXIR GATEWAY → GO PROCESSOR → C++ DRIVER (optional)
     ↓              ↓              ↓              ↓
 WebSocket/HTTP   PubSub      Analytics    Ultra-low latency
```

- **Elixir Gateway**: Phoenix WebSocket/HTTP endpoints, multi-tenant channels
- **Go Processor**: Event processing, analytics, storage, webhooks
- **C++ Driver**: <1ms latency for trading/gaming (optional)
- **Storage**: Redis for sessions, TimescaleDB for events

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:polyglot, "~> 0.1.0"}
  ]
end
```

## Examples

See `examples/chat_example.html` for a working chat implementation.