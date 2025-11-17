# Running Polyglot

## Option 1: Manual Setup (Recommended for Development)

### Prerequisites
- Elixir 1.17+
- Go 1.21+
- Redis

### Step 1: Install Redis

**Option A: If you have Redis installed**
```bash
redis-server
```

**Option B: Using Docker**
```bash
docker run -d -p 6379:6379 --name polyglot-redis redis:7-alpine
```

### Step 2: Start Go Processor (Terminal 1)
```bash
cd go_processor
go build -o processor main.go
./processor
```

Expected output:
```
Go processor starting on :8080
```

### Step 3: Start Elixir Server (Terminal 2)
```bash
mix phx.server
```

Expected output:
```
20:38:42.909 [info] Running Polyglot.Gateway.Endpoint with cowboy 2.13.0 at 0.0.0.0:4000 (http)
20:38:42.909 [info] Access Polyglot.Gateway.Endpoint at http://localhost:4000
```

## Testing

### Health Check
```bash
curl http://localhost:4000/health
curl http://localhost:8080/health
```

### Publish Event
```bash
curl -X POST http://localhost:4000/apps/demo-app/channels/room:test/publish \
  -H "Content-Type: application/json" \
  -H "X-API-Key: valid_key_demo-app" \
  -d '{"type": "message", "data": {"text": "Hello World"}}'
```

Response:
```json
{"id":"evt_1762","timestamp":"2025-11-17T18:39:56.107549Z"}
```

### Get Channel History
```bash
curl http://localhost:4000/apps/demo-app/channels/room:test/history
```

Response:
```json
{
  "app_id": "demo-app",
  "channel": "room:test",
  "count": 1,
  "events": [
    {
      "id": "evt_1762",
      "type": "message",
      "data": {"text": "Hello World"},
      "meta": {
        "ts": "2025-11-17T18:39:56.107549Z",
        "user_id": null,
        "source_ip": "127.0.0.1"
      }
    }
  ]
}
```

### Test Batch Processing (Go Processor)
```bash
curl -X POST http://localhost:8080/process-batch \
  -H "Content-Type: application/json" \
  -d '{
    "events": [
      {"id": "evt_1", "app_id": "demo", "channel": "room:1", "type": "message", "data": {"text": "hi"}, "meta": {}},
      {"id": "evt_2", "app_id": "demo", "channel": "room:1", "type": "message", "data": {"text": "hello"}, "meta": {}}
    ]
  }'
```

Response:
```json
{"processed":2,"failed":0,"total":2,"duration_ms":2}
```

## Configuration

Copy `.env.example` to `.env` and edit:

```bash
cp .env.example .env
```

Key variables:
- `SECRET_KEY_BASE` - Elixir secret key
- `JWT_SECRET` - JWT secret
- `REDIS_HOST` - Redis hostname (default: localhost)
- `REDIS_PORT` - Redis port (default: 6379)
- `GO_PROCESSOR_URL` - Go processor URL (default: http://localhost:8080)
- `LOG_LEVEL` - Logging level (debug, info, warn, error)

## API Keys

API keys follow format: `valid_key_{app_id}`

Examples:
- `valid_key_demo-app` - for app_id "demo-app"
- `valid_key_my-app` - for app_id "my-app"

Pass via header: `-H "X-API-Key: valid_key_{app_id}"`

## Stopping Services

```bash
# Stop all
pkill -f "mix phx.server"
pkill -f "processor"
redis-cli shutdown  # if using local Redis
docker stop polyglot-redis  # if using Docker Redis
```

## Architecture

```
Nginx (80)
  ↓
Elixir Phoenix (4000)
  ├→ PubSub (Redis)
  ├→ Storage (ETS)
  └→ Go Processor (8080)
       └→ C++ Driver (optional)
```

## Performance Notes

- Single event processing: ~1ms
- Batch processing (10 events): ~2ms
- In-memory ETS storage for history
- Redis for distributed PubSub (when scaling)
