export interface GameRules {
  seed: number;
  friendlyFire: boolean;
  maxPlayers: number;
  tickRate: number;
}

export type NetworkUnitCommand =
  | { type: 'move'; x: number; y: number }
  | { type: 'attack'; targetEntityId: number }
  | { type: 'hold' }
  | { type: 'stop' };

export type PlayerAction =
  | { type: 'move'; position: { x: number; y: number } }
  | { type: 'build'; buildingId: string; position: { x: number; y: number }; direction: number }
  | { type: 'attack'; targetEntityId: number }
  | { type: 'unitCommand'; unitId: number; command: NetworkUnitCommand }
  | { type: 'mine'; x: number; y: number }
  | { type: 'shoot'; x: number; y: number };

export type EntityDelta =
  | { type: 'upsert'; networkEntityId: number; entityData: Record<string, unknown> }
  | { type: 'remove'; networkEntityId: number };

export type NetworkMessage =
  | { type: 'handshake'; seed: number; rules: GameRules; playerId: number }
  | { type: 'snapshot'; worldData: { entities: unknown[] }; tick: number }
  | { type: 'delta'; deltas: EntityDelta[]; tick: number }
  | { type: 'command'; action: PlayerAction; playerId: number }
  | { type: 'ping'; timestamp: number }
  | { type: 'pong'; timestamp: number }
  | { type: 'ack'; messageId: number }
  | { type: 'resync'; worldData: { entities: unknown[] }; tick: number }
  | { type: 'lobby'; slots: unknown[]; config: unknown }
  | { type: 'chat'; text: string; from: string };

export function encodeMessage(msg: NetworkMessage): string {
  return JSON.stringify(msg);
}

export function decodeMessage(data: string): NetworkMessage {
  return JSON.parse(data) as NetworkMessage;
}
