import { decodeMessage, encodeMessage, type NetworkMessage, type PlayerAction } from '@shared/net/protocol';

export class NetClient {
  private ws: WebSocket | null = null;
  playerId: number | null = null;
  connected = false;
  onMessage: ((msg: NetworkMessage) => void) | null = null;

  connect(url: string): void {
    this.ws = new WebSocket(url);
    this.ws.onopen = () => {
      this.connected = true;
    };
    this.ws.onclose = () => {
      this.connected = false;
    };
    this.ws.onmessage = (ev) => {
      const msg = decodeMessage(String(ev.data));
      if (msg.type === 'handshake') this.playerId = msg.playerId;
      this.onMessage?.(msg);
    };
  }

  send(msg: NetworkMessage): void {
    if (this.ws?.readyState === WebSocket.OPEN) this.ws.send(encodeMessage(msg));
  }

  sendCommand(action: PlayerAction): void {
    if (this.playerId == null) return;
    this.send({ type: 'command', action, playerId: this.playerId });
  }

  ping(): void {
    this.send({ type: 'ping', timestamp: performance.now() });
  }

  disconnect(): void {
    this.ws?.close();
    this.ws = null;
  }
}
