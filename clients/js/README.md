# Polyglot Realtime Client

A JavaScript/TypeScript client for the Polyglot Realtime Engine, providing a Socket.IO-like API for realtime messaging.

## Installation

```bash
npm install polyglot-realtime-client ws
```

## Usage

```javascript
import { Socket } from 'polyglot-realtime-client';

const socket = new Socket('ws://localhost:4000/socket', {
  appId: 'my-app',
  token: 'valid_token_user123'
});

socket.on('connect', () => {
  console.log('Connected to Polyglot');

  const channel = socket.channel('room:chat');

  channel.join()
    .then(() => {
      console.log('Joined chat room');

      // Listen for messages
      channel.on('event', (data) => {
        console.log('Received:', data);
      });

      // Send a message
      channel.emit('publish', {
        type: 'message',
        data: { text: 'Hello from client!' }
      });
    })
    .catch((error) => {
      console.error('Failed to join:', error);
    });
});

socket.on('disconnect', () => {
  console.log('Disconnected');
});
```

## API

### Socket

- `new Socket(url, options)`: Create a new socket connection
- `socket.on(event, callback)`: Listen for socket events (connect, disconnect, error)
- `socket.channel(topic)`: Get or create a channel
- `socket.disconnect()`: Close the connection

### Channel

- `channel.join()`: Join the channel (Promise-based)
- `channel.leave()`: Leave the channel
- `channel.on(event, callback)`: Listen for channel events
- `channel.emit(event, data)`: Send an event to the channel

## Options

- `appId`: Your Polyglot app ID
- `token`: User authentication token
- `reconnect`: Auto-reconnect on disconnect (default: true)
- `reconnectInterval`: Reconnect delay in ms (default: 5000)

## Requirements

- Node.js 14+
- For Node.js usage, install `ws` package

## License

MIT
