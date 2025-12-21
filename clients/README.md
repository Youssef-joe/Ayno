# Polyglot Test Clients

Minimal test clients for the Polyglot realtime engine.

## Browser Client

**File:** `test-client.html`

Open in browser: `file://$(pwd)/test-client.html` or serve with a local server.

Features:
- WebSocket connection tester
- HTTP API tester
- Real-time message logging
- Health/ready endpoints
- Event publishing & history

**Usage:**
1. Open `test-client.html` in browser
2. Make sure Polyglot server is running on `localhost:4000`
3. Click "Connect" for WebSocket or use HTTP buttons

## CLI Client (Node.js)

**File:** `test-client.js`

### Setup

```bash
npm install
```

### Commands

```bash
# Health check
node test-client.js health

# Ready check
node test-client.js ready

# Publish single event
node test-client.js publish

# Get history
node test-client.js history

# WebSocket test
node test-client.js ws

# Stress test (100 requests, 10 concurrent)
node test-client.js stress 100 10

# Stress test (1000 requests, 50 concurrent)
node test-client.js stress 1000 50

# Run all tests
node test-client.js full
```

### Configuration (Environment Variables)

```bash
# Custom server URL
POLYGLOT_URL=http://example.com:4000 node test-client.js health

# Custom app ID
APP_ID=my-app node test-client.js publish

# Custom channel
CHANNEL=room:lobby node test-client.js publish

# Full example
POLYGLOT_URL=http://localhost:4000 \
APP_ID=demo-app \
CHANNEL=room:test \
API_KEY=valid_key_demo-app \
node test-client.js full
```

### Use Cases

**Development Testing:**
```bash
npm run test
```

**Performance Testing:**
```bash
npm run stress-high
```

**Health Monitoring:**
```bash
npm run health
npm run ready
```

## Quick Start

1. Start Polyglot server:
```bash
./start.sh
```

2. Open browser test client:
```bash
open clients/test-client.html
```

3. Or use CLI:
```bash
cd clients
npm install
npm run test
```

## Expected Results

All endpoints should return `200 OK`:
- `GET /health` → `{"status": "ok"}`
- `GET /ready` → `{"status": "ready", "processor": "up"}`
- `POST /apps/{app_id}/channels/{channel}/publish` → Event published
- `GET /apps/{app_id}/channels/{channel}/history` → Event list

### Performance Baseline

- Single request: ~5ms
- Concurrent (50): ~25,000 req/s
- Stress test throughput: 10,000+ req/s
