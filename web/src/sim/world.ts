// World: seeded mapgen (ore, water, trees, oil, uranium), resources,
// entities + placement validation. Ported from ChunkManager/Tile/Resource
// concepts and BuildingRegistry placement rules (simplified to one grid).
import { BUILDING_MAP } from '../data/buildings';

export type Dir = 0 | 1 | 2 | 3; // N E S W
export const DIR_VEC: [number, number][] = [[0, -1], [1, 0], [0, 1], [-1, 0]];

export interface ResourceDeposit {
  x: number; y: number; outputItem: string; amount: number;
}

export interface BeltItem { itemId: string; progress: number; }
export interface BeltLane { items: BeltItem[]; }

export interface Ent {
  id: number; buildingId: string;
  x: number; y: number; dir: Dir;
  // runtime state (per type)
  progress: number;           // mining/crafting/research progress 0..1
  recipeId: string | null;    // furnace/assembler selected recipe
  fuel: number;               // burner fuel seconds remaining
  inv: Record<string, number>; // machine internal buffers {itemId: count}
  fluid: Record<string, number>; // fluid buffers {fluidType: liters}
  satisfaction: number;       // power 0..1
  networkId: number;
  // belts
  left: BeltItem[]; right: BeltItem[];
  // inserter
  held: string | null; armT: number; cooldown: number;
  // turret / enemy
  hp: number; turretCd: number;
  // lab
  researching: boolean;
  // silo
  assembled: boolean; launching: boolean; launchT: number;
  // enemy
  enemyId: string | null; tx: number; ty: number; atkCd: number;
}

let nextId = 1;

export function makeEntity(buildingId: string, x: number, y: number, dir: Dir = 0): Ent {
  const def = BUILDING_MAP.get(buildingId);
  return {
    id: nextId++, buildingId, x, y, dir,
    progress: 0, recipeId: null, fuel: 0, inv: {}, fluid: {},
    satisfaction: 1, networkId: -1,
    left: [], right: [],
    held: null, armT: 0, cooldown: 0,
    hp: def?.maxHealth ?? 100, turretCd: 0,
    researching: false,
    assembled: false, launching: false, launchT: 0,
    enemyId: null, tx: x, ty: y, atkCd: 0,
  };
}

// Seeded RNG (mulberry32)
export function rng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export class World {
  seed: number;
  resources = new Map<string, ResourceDeposit>(); // "x,y" -> deposit
  trees = new Map<string, number>();              // "x,y" -> wood left
  water = new Set<string>();                      // water tiles
  entities = new Map<number, Ent>();
  grid = new Map<string, number>();               // "x,y" -> entity id (footprint)
  playTime = 0;
  evo = 0;

  constructor(seed: number) {
    this.seed = seed;
    this.generate();
  }

  key(x: number, y: number): string { return `${x},${y}`; }

  generate(): void {
    const rand = rng(this.seed);
    // ore patches: ring layout around spawn like Factorio start area
    const patches = [
      { item: 'iron-ore', cx: -14, cy: -8, r: 7 },
      { item: 'copper-ore', cx: 14, cy: -8, r: 7 },
      { item: 'coal', cx: -12, cy: 12, r: 6 },
      { item: 'stone', cx: 12, cy: 12, r: 6 },
      { item: 'iron-ore', cx: -40, cy: -30, r: 9 },
      { item: 'copper-ore', cx: 40, cy: -30, r: 9 },
      { item: 'uranium-ore', cx: 60, cy: 40, r: 6 },
      { item: 'crude-oil', cx: -55, cy: 30, r: 4 },
    ];
    for (const p of patches) {
      for (let dx = -p.r; dx <= p.r; dx++) {
        for (let dy = -p.r; dy <= p.r; dy++) {
          if (dx * dx + dy * dy > p.r * p.r) continue;
          if (rand() < 0.25) continue;
          const x = p.cx + dx, y = p.cy + dy;
          const rich = p.item === 'uranium-ore' ? 500 + rand() * 1500
            : p.item === 'crude-oil' ? 10000 + rand() * 40000
            : 2000 + rand() * 8000;
          this.resources.set(this.key(x, y), {
            x, y, outputItem: p.item, amount: Math.floor(rich),
          });
        }
      }
    }
    // lake to the south-west (water for offshore pumps / steam)
    for (let dx = -12; dx <= 12; dx++) {
      for (let dy = -6; dy <= 6; dy++) {
        if ((dx * dx) / 100 + (dy * dy) / 25 < 1 && rand() < 0.9) {
          this.water.add(this.key(-30 + dx, 34 + dy));
        }
      }
    }
    // scattered trees (wood)
    for (let i = 0; i < 260; i++) {
      const x = Math.floor((rand() - 0.5) * 160);
      const y = Math.floor((rand() - 0.5) * 160);
      if (Math.abs(x) < 6 && Math.abs(y) < 6) continue;
      if (this.resources.has(this.key(x, y))) continue;
      this.trees.set(this.key(x, y), 4);
    }
  }

  tilesOf(e: Ent): [number, number][] {
    const def = BUILDING_MAP.get(e.buildingId);
    const w = def?.width ?? 1, h = def?.height ?? 1;
    const out: [number, number][] = [];
    for (let dx = 0; dx < w; dx++) for (let dy = 0; dy < h; dy++) out.push([e.x + dx, e.y + dy]);
    return out;
  }

  entityAt(x: number, y: number): Ent | null {
    const id = this.grid.get(this.key(x, y));
    return id == null ? null : (this.entities.get(id) ?? null);
  }

  canPlace(buildingId: string, x: number, y: number): { ok: boolean; reason?: string } {
    const def = BUILDING_MAP.get(buildingId);
    if (!def) return { ok: false, reason: 'unknown building' };
    for (let dx = 0; dx < def.width; dx++) {
      for (let dy = 0; dy < def.height; dy++) {
        const k = this.key(x + dx, y + dy);
        if (this.grid.has(k)) return { ok: false, reason: 'occupied' };
        if (this.water.has(k) && def.type !== 'WaterPump') return { ok: false, reason: 'water' };
      }
    }
    return { ok: true };
  }

  place(buildingId: string, x: number, y: number, dir: Dir = 0): Ent | null {
    const chk = this.canPlace(buildingId, x, y);
    if (!chk.ok) return null;
    const e = makeEntity(buildingId, x, y, dir);
    this.entities.set(e.id, e);
    for (const [tx, ty] of this.tilesOf(e)) this.grid.set(this.key(tx, ty), e.id);
    return e;
  }

  remove(id: number): Ent | null {
    const e = this.entities.get(id);
    if (!e) return null;
    for (const [tx, ty] of this.tilesOf(e)) this.grid.delete(this.key(tx, ty));
    this.entities.delete(id);
    return e;
  }

  mineResource(x: number, y: number, n: number): string | null {
    const k = this.key(x, y);
    const d = this.resources.get(k);
    if (!d || d.amount <= 0) return null;
    d.amount -= n;
    const out = d.outputItem;
    if (d.amount <= 0) this.resources.delete(k);
    return out;
  }

  resourceNear(x: number, y: number, radius: number): ResourceDeposit | null {
    for (let dx = -radius; dx <= radius; dx++) {
      for (let dy = -radius; dy <= radius; dy++) {
        const d = this.resources.get(this.key(x + dx, y + dy));
        if (d && d.amount > 0) return d;
      }
    }
    return null;
  }
}
