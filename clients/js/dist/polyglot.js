'use strict';

Object.defineProperty(exports, '__esModule', { value: true });

var WebSocket = require('ws');

class Socket {
    constructor(url, options) {
        this.ws = null;
        this.channels = new Map();
        this.eventListeners = new Map();
        this.reconnectTimer = null;
        this.connected = false;
        this.url = url;
        this.options = {
            reconnect: true,
            reconnectInterval: 5000,
            ...options
        };
        this.connect();
    }
    connect() {
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
            this.ws.on('message', (data) => {
                try {
                    const message = JSON.parse(data.toString());
                    this.handleMessage(message);
                }
                catch (err) {
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
        }
        catch (error) {
            console.error('Connection failed:', error);
            this.scheduleReconnect();
        }
    }
    scheduleReconnect() {
        if (this.reconnectTimer)
            clearTimeout(this.reconnectTimer);
        this.reconnectTimer = setTimeout(() => {
            console.log('Attempting to reconnect...');
            this.connect();
        }, this.options.reconnectInterval);
    }
    handleMessage(message) {
        // Polyglot uses Phoenix-like message format
        if (message.event === 'phx_reply' && message.payload?.status === 'ok') {
            // Join success
            const channel = this.channels.get(message.topic);
            if (channel) {
                channel.emitEvent('join');
            }
        }
        else if (message.event && message.topic) {
            // Regular event
            const channel = this.channels.get(message.topic);
            if (channel) {
                channel.emitEvent(message.event, message.payload);
            }
        }
    }
    emitEvent(event, data) {
        const listeners = this.eventListeners.get(event) || [];
        listeners.forEach(callback => callback(data));
    }
    on(event, callback) {
        if (!this.eventListeners.has(event)) {
            this.eventListeners.set(event, []);
        }
        this.eventListeners.get(event).push(callback);
    }
    off(event, callback) {
        if (callback) {
            const listeners = this.eventListeners.get(event) || [];
            const index = listeners.indexOf(callback);
            if (index > -1) {
                listeners.splice(index, 1);
            }
        }
        else {
            this.eventListeners.delete(event);
        }
    }
    channel(topic) {
        if (!this.channels.has(topic)) {
            this.channels.set(topic, new PolyglotChannel(topic, this));
        }
        return this.channels.get(topic);
    }
    disconnect() {
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = null;
        }
        if (this.ws) {
            this.ws.close();
        }
    }
    isConnected() {
        return this.connected;
    }
    send(topic, event, payload) {
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
class PolyglotChannel {
    constructor(topic, socket) {
        this.eventListeners = new Map();
        this.joined = false;
        this.topic = topic;
        this.socket = socket;
    }
    async join() {
        return new Promise((resolve, reject) => {
            const joinCallback = () => {
                this.joined = true;
                this.off('join', joinCallback);
                resolve();
            };
            const errorCallback = (error) => {
                this.off('join', joinCallback);
                this.off('error', errorCallback);
                reject(error);
            };
            this.on('join', joinCallback);
            this.on('error', errorCallback);
            this.socket.send(this.topic, 'phx_join', {});
        });
    }
    leave() {
        if (this.joined) {
            this.socket.send(this.topic, 'phx_leave', {});
            this.joined = false;
        }
    }
    on(event, callback) {
        if (!this.eventListeners.has(event)) {
            this.eventListeners.set(event, []);
        }
        this.eventListeners.get(event).push(callback);
    }
    off(event, callback) {
        if (callback) {
            const listeners = this.eventListeners.get(event) || [];
            const index = listeners.indexOf(callback);
            if (index > -1) {
                listeners.splice(index, 1);
            }
        }
        else {
            this.eventListeners.delete(event);
        }
    }
    emit(event, data) {
        if (this.joined) {
            this.socket.send(this.topic, event, data);
        }
    }
    emitEvent(event, data) {
        const listeners = this.eventListeners.get(event) || [];
        listeners.forEach(callback => callback(data));
    }
}

exports.Socket = Socket;
exports.default = Socket;
//# sourceMappingURL=polyglot.js.map
