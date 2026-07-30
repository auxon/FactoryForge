import { WebSocketServer, WebSocket } from 'ws';
import {
  decodeMessage,
  encodeMessage,
  type GameRules,
  type NetworkMessage,
  type PlayerAction,
} from '../shared/net/protocol.ts';
import { GameLoop } from '../src/engine/core/GameLoop.ts';

const PORT = Number(process.env.PORT ?? 8080);

interface Client {
  ws: WebSocket;
  playerId: number;
}

const clients = new Map<WebSocket, Client>();
let nextPlayerId = 1;
const seed = Math.floor(Math.random() * 1e9);
const rules: GameRules = { seed, friendlyFire: false, maxPlayers: 8, tickRate: 60 };

const game = new GameLoop(seed, true);
game.matchMode = 'freeForAll';

const wss = new WebSocketServer({ port: PORT });
console.log(`FactoryForge MP server listening on ws://localhost:${PORT}`);

function broadcast(msg: NetworkMessage, except?: WebSocket): void {
  const data = encodeMessage(msg);
  for (const [ws] of clients) {
    if (ws !== except && ws.readyState === WebSocket.OPEN) ws.send(data);
  }
}

function applyAction(playerId: number, action: PlayerAction): void {
  if (action.type === 'build') {
    game.placeBuilding(action.buildingId, action.position.x, action.position.y, action.direction as 0 | 1 | 2 | 3, playerId);
  }
  if (action.type === 'move') {
    const p = game.playerManager.getPlayer(playerId);
    if (!p) return;
    // soft teleport / set target — for demo set position
    game.world.updatePosition(p.entity, Math.floor(action.position.x), Math.floor(action.position.y));
  }
  if (action.type === 'mine') {
    game.tryMineOrInteract(action.x, action.y);
  }
  if (action.type === 'shoot') {
    const p = game.playerManager.getPlayer(playerId);
    if (p) game.combatSystem.playerShoot(p.entity, action.x, action.y, playerId);
  }
}

wss.on('connection', (ws) => {
  const playerId = nextPlayerId++;
  // First client reuses local player; others spawn
  if (playerId > 1) {
    const angle = playerId * 1.2;
    game.playerManager.createPlayer(`P${playerId}`, false, Math.round(Math.cos(angle) * 30), Math.round(Math.sin(angle) * 30));
    // Map network id to last created — PlayerManager nextId already assigned
  }
  clients.set(ws, { ws, playerId });

  const handshake: NetworkMessage = { type: 'handshake', seed, rules, playerId };
  ws.send(encodeMessage(handshake));

  const snapshot: NetworkMessage = {
    type: 'snapshot',
    tick: 0,
    worldData: { entities: game.world.serializeEntities() },
  };
  ws.send(encodeMessage(snapshot));

  ws.on('message', (raw) => {
    let msg: NetworkMessage;
    try {
      msg = decodeMessage(String(raw));
    } catch {
      return;
    }
    if (msg.type === 'ping') {
      ws.send(encodeMessage({ type: 'pong', timestamp: msg.timestamp }));
      return;
    }
    if (msg.type === 'command') {
      applyAction(msg.playerId, msg.action);
      broadcast(
        {
          type: 'delta',
          tick: 0,
          deltas: [{ type: 'upsert', networkEntityId: 0, entityData: { action: msg.action } }],
        },
        ws,
      );
    }
  });

  ws.on('close', () => {
    clients.delete(ws);
  });
});

// Authoritative tick
setInterval(() => {
  game.frame(0, 0);
  if (clients.size === 0) return;
  // Periodic resync
  if (Math.random() < 0.02) {
    broadcast({
      type: 'resync',
      tick: 0,
      worldData: { entities: game.world.serializeEntities() },
    });
  }
}, 1000 / rules.tickRate);
