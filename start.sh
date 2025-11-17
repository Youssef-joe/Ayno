#!/bin/bash

# Polyglot Quick Start Script
# Starts all services in the background

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Starting Polyglot..."

# Check if Redis is running
if ! redis-cli ping >/dev/null 2>&1; then
    echo "⚠️  Redis not running. Starting Redis..."
    if command -v redis-server &> /dev/null; then
        redis-server --daemonize yes
        sleep 1
        echo "✓ Redis started (daemonized)"
    else
        echo "❌ Redis not found. Install Redis or run: docker run -d -p 6379:6379 redis:7-alpine"
        exit 1
    fi
fi

# Start Go Processor
echo "Starting Go Processor..."
cd go_processor
if [ ! -f processor ]; then
    echo "Building Go processor..."
    go build -o processor main.go
fi
./processor > /tmp/polyglot_go.log 2>&1 &
GO_PID=$!
echo "✓ Go Processor started (PID: $GO_PID)"
sleep 1

# Start Elixir Server
cd "$SCRIPT_DIR"
echo "Starting Elixir Server..."
mix phx.server > /tmp/polyglot_elixir.log 2>&1 &
ELIXIR_PID=$!
echo "✓ Elixir Server started (PID: $ELIXIR_PID)"
sleep 3

# Verify services are running
echo ""
echo "🔍 Verifying services..."

if curl -s http://localhost:8080/health >/dev/null; then
    echo "✓ Go Processor is running on http://localhost:8080"
else
    echo "❌ Go Processor failed to start"
    kill $GO_PID 2>/dev/null
    exit 1
fi

if curl -s http://localhost:4000/health >/dev/null; then
    echo "✓ Elixir Server is running on http://localhost:4000"
else
    echo "❌ Elixir Server failed to start"
    kill $ELIXIR_PID 2>/dev/null
    exit 1
fi

echo ""
echo "✅ All services are running!"
echo ""
echo "📝 Logs:"
echo "  - Go Processor: tail -f /tmp/polyglot_go.log"
echo "  - Elixir: tail -f /tmp/polyglot_elixir.log"
echo ""
echo "🧪 Test:"
echo "  curl -X POST http://localhost:4000/apps/demo-app/channels/room:test/publish \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -H 'X-API-Key: valid_key_demo-app' \\"
echo "    -d '{\"type\": \"message\", \"data\": {\"text\": \"Hello\"}}'"
echo ""
echo "❌ Stop all services:"
echo "  pkill -f 'mix phx.server' && pkill -f processor"
echo ""
