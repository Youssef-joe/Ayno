import WebSocket from 'ws';

export interface SocketOptions {
  appId: string;
  token: string;
  reconnect?: boolean;
  reconnectInterval?: number;
}

export interface Channel {
  join(): Promise<void>;
  leave(): void;
  on(event: string, callback: (data: any) => void): void;
  off(event: string, callback?: (data: any) => void): void;
  emit(event: string, data: any): void;
}

export class Socket {
  private ws: WebSocket | null = null;
  private url: string;
  private options: SocketOptions;
  private channels: Map<string, PolyglotChannel> = new Map();
  private eventListeners: Map<string, ((data: any) => void)[]> = new Map();
  private reconnectTimer: NodeJS.Timeout | null = null;
  private connected = false;

  constructor(url: string, options: SocketOptions) {
    this.url = url;
    this.options = {
      reconnect: true,
      reconnectInterval: 5000,
      ...options
    };
    this.connect();
  }

  private connect(): void {
    try {
      this.ws = new WebSocket(this.url, {
        headers: {
          'app_id': this.options.appId,
          'token': this.options.token
        }
      });

      this.ws.on('open', () => {
        this.connected = true;
        this.emitEvent('connect');
      });

      this.ws.on('message', (data: Buffer) => {
        try {
          const message = JSON.parse(data.toString());
          this.handleMessage(message);
        } catch (err) {
          console.error('Failed to parse message:', err);
        }
      });

      this.ws.on('close', () => {
        this.connected = false;
        this.emitEvent('disconnect');
        if (this.options.reconnect) {
          this.scheduleReconnect();
        }
      });

      this.ws.on('error', (error) => {
        console.error('WebSocket error:', error);
        this.emitEvent('error', error);
      });

    } catch (error) {
      console.error('Connection failed:', error);
      this.scheduleReconnect();
    }
  }

  private scheduleReconnect(): void {
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.reconnectTimer = setTimeout(() => {
      console.log('Attempting to reconnect...');
      this.connect();
    }, this.options.reconnectInterval);
  }

  private handleMessage(message: any): void {
    // Polyglot uses Phoenix-like message format
    if (message.event === 'phx_reply' && message.payload?.status === 'ok') {
      // Join success
      const channel = this.channels.get(message.topic);
      if (channel) {
        channel.emitEvent('join');
      }
    } else if (message.event && message.topic) {
      // Regular event
      const channel = this.channels.get(message.topic);
      if (channel) {
        channel.emitEvent(message.event, message.payload);
      }
    }
  }

  private emitEvent(event: string, data?: any): void {
    const listeners = this.eventListeners.get(event) || [];
    listeners.forEach(callback => callback(data));
  }

  on(event: string, callback: (data?: any) => void): void {
    if (!this.eventListeners.has(event)) {
      this.eventListeners.set(event, []);
    }
    this.eventListeners.get(event)!.push(callback);
  }

  off(event: string, callback?: (data?: any) => void): void {
    if (callback) {
      const listeners = this.eventListeners.get(event) || [];
      const index = listeners.indexOf(callback);
      if (index > -1) {
        listeners.splice(index, 1);
      }
    } else {
      this.eventListeners.delete(event);
    }
  }

  channel(topic: string): Channel {
    if (!this.channels.has(topic)) {
      this.channels.set(topic, new PolyglotChannel(topic, this));
    }
    return this.channels.get(topic)!;
  }

  disconnect(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    if (this.ws) {
      this.ws.close();
    }
  }

  isConnected(): boolean {
    return this.connected;
  }

  send(topic: string, event: string, payload: any): void {
    if (this.ws && this.connected) {
      const message = {
        topic,
        event,
        payload
      };
      this.ws.send(JSON.stringify(message));
    }
  }
}

class PolyglotChannel implements Channel {
  private topic: string;
  private socket: Socket;
  private eventListeners: Map<string, ((data: any) => void)[]> = new Map();
  private joined = false;

  constructor(topic: string, socket: Socket) {
    this.topic = topic;
    this.socket = socket;
  }

  async join(): Promise<void> {
    return new Promise((resolve, reject) => {
      const joinCallback = () => {
        this.joined = true;
        this.off('join', joinCallback);
        resolve();
      };

      const errorCallback = (error: any) => {
        this.off('join', joinCallback);
        this.off('error', errorCallback);
        reject(error);
      };

      this.on('join', joinCallback);
      this.on('error', errorCallback);

      this.socket.send(this.topic, 'phx_join', {});
    });
  }

  leave(): void {
    if (this.joined) {
      this.socket.send(this.topic, 'phx_leave', {});
      this.joined = false;
    }
  }

  on(event: string, callback: (data: any) => void): void {
    if (!this.eventListeners.has(event)) {
      this.eventListeners.set(event, []);
    }
    this.eventListeners.get(event)!.push(callback);
  }

  off(event: string, callback?: (data: any) => void): void {
    if (callback) {
      const listeners = this.eventListeners.get(event) || [];
      const index = listeners.indexOf(callback);
      if (index > -1) {
        listeners.splice(index, 1);
      }
    } else {
      this.eventListeners.delete(event);
    }
  }

  emit(event: string, data: any): void {
    if (this.joined) {
      this.socket.send(this.topic, event, data);
    }
  }

  emitEvent(event: string, data?: any): void {
    const listeners = this.eventListeners.get(event) || [];
    listeners.forEach(callback => callback(data));
  }
}

export default Socket;
