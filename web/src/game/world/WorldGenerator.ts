import { CHUNK_SIZE, Chunk, type ResourceType, type TileType } from './Chunk';

/** Simple seeded PRNG (mulberry32) */
export function createRng(seed: number): () => number {
  let t = seed >>> 0;
  return () => {
    t += 0x6d2b79f5;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r ^= r + Math.imul(r ^ (r >>> 7), 61 | r);
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

function hash2(x: number, y: number, seed: number): number {
  let h = seed ^ Math.imul(x, 374761393) ^ Math.imul(y, 668265263);
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

function valueNoise(x: number, y: number, seed: number): number {
  const x0 = Math.floor(x);
  const y0 = Math.floor(y);
  const fx = x - x0;
  const fy = y - y0;
  const a = hash2(x0, y0, seed);
  const b = hash2(x0 + 1, y0, seed);
  const c = hash2(x0, y0 + 1, seed);
  const d = hash2(x0 + 1, y0 + 1, seed);
  const u = fx * fx * (3 - 2 * fx);
  const v = fy * fy * (3 - 2 * fy);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}

function fbm(x: number, y: number, seed: number, octaves = 4): number {
  let amp = 1;
  let freq = 1;
  let sum = 0;
  let norm = 0;
  for (let i = 0; i < octaves; i++) {
    sum += valueNoise(x * freq, y * freq, seed + i * 1013) * amp;
    norm += amp;
    amp *= 0.5;
    freq *= 2;
  }
  return sum / norm;
}

const RESOURCE_TYPES: ResourceType[] = ['iron-ore', 'copper-ore', 'coal', 'stone', 'uranium-ore'];

export class WorldGenerator {
  constructor(public seed: number) {}

  generateChunk(cx: number, cy: number): Chunk {
    const chunk = new Chunk({ x: cx, y: cy });
    const elevSeed = this.seed;
    const moistSeed = this.seed + 99991;
    const resSeed = this.seed + 12345;

    for (let ly = 0; ly < CHUNK_SIZE; ly++) {
      for (let lx = 0; lx < CHUNK_SIZE; lx++) {
        const wx = cx * CHUNK_SIZE + lx;
        const wy = cy * CHUNK_SIZE + ly;
        const elev = fbm(wx / 48, wy / 48, elevSeed);
        const moist = fbm(wx / 64, wy / 64, moistSeed);

        let type: TileType = 'grass';
        if (elev < 0.32) type = 'water';
        else if (elev < 0.38) type = 'sand';
        else if (elev > 0.72) type = 'stone';
        else if (moist < 0.35) type = 'dirt';

        const tile = chunk.tiles[ly]![lx]!;
        tile.type = type;
        tile.variation = Math.floor(hash2(wx, wy, this.seed) * 4);

        if (type !== 'water') {
          const patch = fbm(wx / 20, wy / 20, resSeed);
          if (patch > 0.78) {
            const r = hash2(wx, wy, resSeed + 7);
            let resType: ResourceType = RESOURCE_TYPES[Math.floor(r * 4)]!;
            if (patch > 0.92 && r > 0.85) resType = 'uranium-ore';
            // oil near sand
            if (type === 'sand' && patch > 0.82) resType = 'crude-oil';
            const amount = resType === 'crude-oil' ? 100000 : 500 + Math.floor(r * 4500);
            tile.resource = {
              type: resType,
              amount,
              originalAmount: amount,
              richness: 1 + r,
            };
          }
        }

        // Biters spawners far from origin
        const dist = Math.hypot(wx, wy);
        if (dist > 80 && type !== 'water' && hash2(wx, wy, this.seed + 555) > 0.997) {
          chunk.spawnerPositions.push([wx, wy]);
        }
      }
    }

    chunk.biome = elevBiome(cx, cy, this.seed);
    return chunk;
  }

  shouldSpawnTree(wx: number, wy: number, tileType: TileType): boolean {
    if (tileType !== 'grass' && tileType !== 'dirt') return false;
    return hash2(wx, wy, this.seed + 7777) > 0.94;
  }
}

function elevBiome(cx: number, cy: number, seed: number): string {
  const n = fbm(cx / 4, cy / 4, seed);
  if (n < 0.35) return 'wetlands';
  if (n > 0.7) return 'highlands';
  return 'plains';
}
