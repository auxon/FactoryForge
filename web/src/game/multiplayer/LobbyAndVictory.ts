export type MatchMode = 'freeForAll' | 'teamDeathmatch' | 'singlePlayer' | 'pvai';

export interface LobbySlot {
  slotId: number;
  playerId: number | null;
  name: string;
  isAI: boolean;
  team: number;
  ready: boolean;
}

export interface MatchConfig {
  mode: MatchMode;
  maxPlayers: number;
  seed: number;
  friendlyFire: boolean;
  tickRate: number;
  difficulty?: string;
}

export class LobbySystem {
  slots: LobbySlot[] = [];
  config: MatchConfig = {
    mode: 'singlePlayer',
    maxPlayers: 8,
    seed: Math.floor(Math.random() * 1e9),
    friendlyFire: false,
    tickRate: 60,
    difficulty: 'normal',
  };

  reset(max = 8): void {
    this.slots = Array.from({ length: max }, (_, i) => ({
      slotId: i,
      playerId: i === 0 ? 1 : null,
      name: i === 0 ? 'Player' : '',
      isAI: false,
      team: i % 2,
      ready: i === 0,
    }));
  }

  addAI(): void {
    const slot = this.slots.find((s) => s.playerId === null);
    if (!slot) return;
    slot.playerId = 1000 + slot.slotId;
    slot.name = `AI-${slot.slotId}`;
    slot.isAI = true;
    slot.ready = true;
  }

  setReady(slotId: number, ready: boolean): void {
    const s = this.slots[slotId];
    if (s) s.ready = ready;
  }

  canStart(): boolean {
    const filled = this.slots.filter((s) => s.playerId !== null);
    return filled.length > 0 && filled.every((s) => s.ready);
  }
}

export class VictorySystem {
  winnerId: number | null = null;
  reason: string | null = null;

  check(
    mode: MatchMode,
    players: Array<{ playerId: number; alive: boolean; team: number }>,
    rocketVictory: boolean,
    localId: number,
  ): void {
    if (this.winnerId !== null) return;
    if (mode === 'singlePlayer' && rocketVictory) {
      this.winnerId = localId;
      this.reason = 'Rocket launched with satellite';
      return;
    }
    if (mode === 'pvai' || mode === 'freeForAll') {
      const alive = players.filter((p) => p.alive);
      if (alive.length === 1) {
        this.winnerId = alive[0]!.playerId;
        this.reason = 'Last standing';
      }
    }
    if (mode === 'teamDeathmatch') {
      const teams = new Map<number, number>();
      for (const p of players.filter((x) => x.alive)) {
        teams.set(p.team, (teams.get(p.team) ?? 0) + 1);
      }
      if (teams.size === 1) {
        const team = [...teams.keys()][0]!;
        this.winnerId = players.find((p) => p.team === team)?.playerId ?? null;
        this.reason = `Team ${team} wins`;
      }
    }
  }

  reset(): void {
    this.winnerId = null;
    this.reason = null;
  }
}

export class FogOfWarSystem {
  visible = new Set<string>();
  visionRadius = 24;

  update(playerPositions: Array<{ x: number; y: number }>): void {
    this.visible.clear();
    for (const p of playerPositions) {
      const r = this.visionRadius;
      for (let y = -r; y <= r; y++) {
        for (let x = -r; x <= r; x++) {
          if (x * x + y * y <= r * r) {
            this.visible.add(`${Math.floor(p.x + x)},${Math.floor(p.y + y)}`);
          }
        }
      }
    }
  }

  isVisible(tx: number, ty: number): boolean {
    return this.visible.has(`${tx},${ty}`);
  }
}

export class SpawnSystem {
  constructor(private spawnRadius = 40) {}

  positions(count: number): Array<{ x: number; y: number }> {
    const out: Array<{ x: number; y: number }> = [];
    for (let i = 0; i < count; i++) {
      const angle = (i / count) * Math.PI * 2;
      out.push({
        x: Math.round(Math.cos(angle) * this.spawnRadius),
        y: Math.round(Math.sin(angle) * this.spawnRadius),
      });
    }
    return out;
  }
}
