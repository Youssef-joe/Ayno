// Minimal JavaScript SDK for Polyglot Realtime Engine
class RealtimeEngine {
  constructor(appId, clientKey) {
    this.appId = appId;
    this.clientKey = clientKey;
    this.socket = null;
    this.channels = new Map();
  }

  async connect() {
    const { Socket } = await import("phoenix");
    this.socket = new Socket("/socket", {
      params: { app_id: this.appId, token: this.clientKey }
    });
    this.socket.connect();
  }

  subscribe(channelName, callback) {
    const channel = this.socket.channel(channelName, {});
    channel.join()
      .receive("ok", () => console.log(`Joined ${channelName}`))
      .receive("error", (resp) => console.log("Unable to join", resp));
    
    channel.on("event", callback);
    this.channels.set(channelName, channel);
    return channel;
  }

  publish(channelName, eventData) {
    const channel = this.channels.get(channelName);
    if (channel) {
      channel.push("publish", eventData);
    }
  }
}