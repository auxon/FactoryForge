export const CHUNK_SIZE = 32;

export type TileType = 'grass' | 'dirt' | 'sand' | 'water' | 'stone';

export type ResourceType = 'iron-ore' | 'copper-ore' | 'coal' | 'stone' | 'uranium-ore' | 'crude-oil';

export interface ResourceDeposit {
  type: ResourceType;
  amount: number;
  originalAmount: number;
  richness: number;
}

export interface TileData {
  type: TileType;
  variation: number;
  resource: ResourceDeposit | null;
}

export interface ChunkCoord {
  x: number;
  y: number;
}

export function chunkKey(c: ChunkCoord): string {
  return `${c.x},${c.y}`;
}

export function worldToChunk(tileX: number, tileY: number): ChunkCoord {
  return {
    x: Math.floor(tileX / CHUNK_SIZE),
    y: Math.floor(tileY / CHUNK_SIZE),
  };
}

export interface ChunkData {
  coordX: number;
  coordY: number;
  tiles: TileData[][];
  pollution: number;
  biome: string;
  spawnerPositions: Array<[number, number]>;
}

export class Chunk {
  readonly coord: ChunkCoord;
  tiles: TileData[][];
  pollution = 0;
  biome = 'plains';
  spawnerPositions: Array<[number, number]> = [];
  dirty = true;

  constructor(coord: ChunkCoord, tiles?: TileData[][]) {
    this.coord = coord;
    this.tiles =
      tiles ??
      Array.from({ length: CHUNK_SIZE }, () =>
        Array.from({ length: CHUNK_SIZE }, () => ({
          type: 'grass' as TileType,
          variation: 0,
          resource: null,
        })),
      );
  }

  getTileLocal(lx: number, ly: number): TileData | null {
    if (lx < 0 || ly < 0 || lx >= CHUNK_SIZE || ly >= CHUNK_SIZE) return null;
    return this.tiles[ly]![lx]!;
  }

  toData(): ChunkData {
    return {
      coordX: this.coord.x,
      coordY: this.coord.y,
      tiles: this.tiles,
      pollution: this.pollution,
      biome: this.biome,
      spawnerPositions: this.spawnerPositions,
    };
  }

  static fromData(data: ChunkData): Chunk {
    const c = new Chunk({ x: data.coordX, y: data.coordY }, data.tiles);
    c.pollution = data.pollution;
    c.biome = data.biome;
    c.spawnerPositions = data.spawnerPositions ?? [];
    return c;
  }
}
