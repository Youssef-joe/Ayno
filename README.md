# Polyglot Realtime Engine

A multi-tenant realtime platform built with Elixir Phoenix, supporting WebSocket and HTTP APIs for chat, trading, gaming, and any realtime application.

## Architecture

- **Elixir Gateway**: Phoenix WebSocket/HTTP server with multi-tenant channels
- **Go Processor**: Event processing and analytics (HTTP on port 8080)
- **C++ Driver**: Ultra-low latency processing (optional)
- **Storage**: In-memory ETS for history, Redis for sessions

## Quick Start

### Using Docker (Recommended)

```bash
docker-compose up --build
```

### Manual Setup

1. Build components:
```bash
make all  # or manually: cd go_processor && go build -o processor main.go
```

2. Start services:
```bash
# Terminal 1: Go Processor
cd go_processor && ./processor

# Terminal 2: Elixir Gateway
mix deps.get
mix phx.server
```

3. Test:
```bash
# Health check
curl http://localhost:4000/health

# Publish event
curl -X POST http://localhost:4000/apps/demo-app/channels/room:test/publish \
  -H "Content-Type: application/json" \
  -H "X-API-Key: valid_key_demo-app" \
  -d '{"type": "message", "data": {"text": "Hello World"}}'

# Get history
curl http://localhost:4000/apps/demo-app/channels/room:test/history
```

## API

### WebSocket

```javascript
import { Socket } from "phoenix";

const socket = new Socket("ws://localhost:4000/socket", {
  params: { app_id: "your-app", token: "valid_token_user123" }
});

socket.connect();

const channel = socket.channel("room:lobby", {});
channel.join();
channel.on("event", (event) => console.log(event));
```

### HTTP

```bash
# Publish
curl -X POST /apps/{app_id}/channels/{channel}/publish \
  -H "X-API-Key: valid_key_{app_id}" \
  -d '{"type": "message", "data": {"text": "Hello"}}'

# History
curl /apps/{app_id}/channels/{channel}/history
```

## Examples

See `examples/` directory for client implementations in HTML/JavaScript and Python.

## Testing

Run benchmarks:
```bash
mix run benchmarks/benchmark.exs
```

Run tests:
```bash
mix test
```

## Development

- Elixir 1.17+
- Go 1.21+
- Redis (optional, for future persistence)

## License

MIT
