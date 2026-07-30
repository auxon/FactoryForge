import { Chunk, CHUNK_SIZE, chunkKey, worldToChunk, type ChunkCoord, type ChunkData, type TileData } from './Chunk';
import { WorldGenerator } from './WorldGenerator';

export class ChunkManager {
  private chunks = new Map<string, Chunk>();
  readonly generator: WorldGenerator;
  loadRadius = 3;

  constructor(seed: number) {
    this.generator = new WorldGenerator(seed);
  }

  getChunk(coord: ChunkCoord): Chunk | undefined {
    return this.chunks.get(chunkKey(coord));
  }

  ensureChunk(coord: ChunkCoord): Chunk {
    const key = chunkKey(coord);
    let c = this.chunks.get(key);
    if (!c) {
      c = this.generator.generateChunk(coord.x, coord.y);
      this.chunks.set(key, c);
    }
    return c;
  }

  updateAround(tileX: number, tileY: number): void {
    const center = worldToChunk(tileX, tileY);
    const needed = new Set<string>();
    for (let dy = -this.loadRadius; dy <= this.loadRadius; dy++) {
      for (let dx = -this.loadRadius; dx <= this.loadRadius; dx++) {
        const coord = { x: center.x + dx, y: center.y + dy };
        needed.add(chunkKey(coord));
        this.ensureChunk(coord);
      }
    }
    // Keep loaded chunks in radius; don't unload aggressively for gameplay stability
    for (const [key, chunk] of this.chunks) {
      if (!needed.has(key)) {
        const dist = Math.max(Math.abs(chunk.coord.x - center.x), Math.abs(chunk.coord.y - center.y));
        if (dist > this.loadRadius + 2) this.chunks.delete(key);
      }
    }
  }

  getTile(tileX: number, tileY: number): TileData | null {
    const coord = worldToChunk(tileX, tileY);
    const chunk = this.ensureChunk(coord);
    const lx = ((tileX % CHUNK_SIZE) + CHUNK_SIZE) % CHUNK_SIZE;
    const ly = ((tileY % CHUNK_SIZE) + CHUNK_SIZE) % CHUNK_SIZE;
    return chunk.getTileLocal(lx, ly);
  }

  setTileResource(tileX: number, tileY: number, amount: number): void {
    const tile = this.getTile(tileX, tileY);
    if (!tile?.resource) return;
    tile.resource.amount = amount;
    if (amount <= 0) tile.resource = null;
    const coord = worldToChunk(tileX, tileY);
    this.getChunk(coord)!.dirty = true;
  }

  addPollution(tileX: number, tileY: number, amount: number): void {
    const coord = worldToChunk(tileX, tileY);
    const chunk = this.ensureChunk(coord);
    chunk.pollution = Math.max(0, chunk.pollution + amount);
  }

  loadedChunks(): Chunk[] {
    return [...this.chunks.values()];
  }

  serialize(): ChunkData[] {
    return [...this.chunks.values()].map((c) => c.toData());
  }

  loadChunks(data: ChunkData[]): void {
    this.chunks.clear();
    for (const d of data) {
      const c = Chunk.fromData(d);
      this.chunks.set(chunkKey(c.coord), c);
    }
  }
}
