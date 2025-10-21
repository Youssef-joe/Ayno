# Polyglot Examples

This directory contains example implementations showing how to integrate with the Polyglot Realtime Engine.

## Chat Example (WebSocket)

`chat_example.html` - A simple web-based chat application using WebSocket connections.

To run:
1. Start the Polyglot server
2. Open `chat_example.html` in a browser
3. Open multiple tabs to test real-time messaging

## Python HTTP Client

`python_client.py` - A Python script demonstrating HTTP API usage for publishing events and retrieving history.

To run:
```bash
pip install requests
python python_client.py
```

## Features Demonstrated

- WebSocket connections for real-time events
- HTTP publishing for server-to-server communication
- Event history retrieval
- Multi-tenant app isolation

## API Endpoints Used

- `POST /apps/{app_id}/channels/{channel}/publish` - Publish events
- `GET /apps/{app_id}/channels/{channel}/history` - Get event history
- `WS /socket` - WebSocket for real-time subscriptions
