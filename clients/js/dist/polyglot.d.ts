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
export declare class Socket {
    private ws;
    private url;
    private options;
    private channels;
    private eventListeners;
    private reconnectTimer;
    private connected;
    constructor(url: string, options: SocketOptions);
    private connect;
    private scheduleReconnect;
    private handleMessage;
    private emitEvent;
    on(event: string, callback: (data?: any) => void): void;
    off(event: string, callback?: (data?: any) => void): void;
    channel(topic: string): Channel;
    disconnect(): void;
    isConnected(): boolean;
    send(topic: string, event: string, payload: any): void;
}
export default Socket;
