import type { Entity } from '../engine/ecs/Entity';

export type Direction = 0 | 1 | 2 | 3; // N E S W

export interface PositionComponent {
  tileX: number;
  tileY: number;
  offsetX: number;
  offsetY: number;
}

export interface SpriteAnimation {
  frames: string[];
  frameTime: number;
  currentFrame: number;
  elapsedTime: number;
  isLooping: boolean;
  isPlaying: boolean;
}

export function createSpriteAnimation(frames: string[], frameTime = 0.08, isLooping = true): SpriteAnimation {
  return {
    frames,
    frameTime,
    currentFrame: 0,
    elapsedTime: 0,
    isLooping,
    isPlaying: false,
  };
}

export function updateSpriteAnimation(anim: SpriteAnimation, deltaTime: number): string | null {
  if (!anim.isPlaying || anim.frames.length === 0) return null;
  anim.elapsedTime += deltaTime;
  while (anim.elapsedTime >= anim.frameTime) {
    anim.elapsedTime -= anim.frameTime;
    anim.currentFrame += 1;
    if (anim.currentFrame >= anim.frames.length) {
      if (anim.isLooping) anim.currentFrame = 0;
      else {
        anim.currentFrame = anim.frames.length - 1;
        anim.isPlaying = false;
      }
    }
  }
  return anim.frames[anim.currentFrame] ?? null;
}

export interface SpriteComponent {
  textureId: string;
  width: number;
  height: number;
  layer: RenderLayer;
  color?: string;
  rotation?: number;
  visible?: boolean;
  animation?: SpriteAnimation;
}

export enum RenderLayer {
  Ground = 0,
  GroundDecoration = 1,
  Shadow = 2,
  Building = 3,
  Entity = 4,
  Item = 5,
  Enemy = 6,
  Projectile = 7,
  Particle = 8,
  Ui = 9,
}

export interface HealthComponent {
  current: number;
  max: number;
}

export interface InventorySlot {
  itemId: string | null;
  count: number;
}

export interface InventoryComponent {
  slots: InventorySlot[];
}

export interface PlayerComponent {
  playerId: number;
  name: string;
  isAI: boolean;
  moveX: number;
  moveY: number;
  craftQueue: Array<{ recipeId: string; remaining: number }>;
  facing?: 'down' | 'up' | 'left' | 'right';
}

export interface OwnershipComponent {
  playerId: number;
}

export interface MinerComponent {
  buildingId: string;
  progress: number;
  miningSpeed: number;
}

export interface BeltItem {
  itemId: string;
  progress: number; // 0-1 along belt
  lane: 0 | 1;
}

export interface BeltComponent {
  buildingId: string;
  direction: Direction;
  speed: number;
  items: BeltItem[];
}

export interface InserterComponent {
  buildingId: string;
  direction: Direction;
  reach: number;
  speed: number;
  stackSize: number;
  progress: number;
  heldItem: string | null;
  heldCount: number;
  pickupEntity?: Entity;
  dropEntity?: Entity;
}

export interface FurnaceComponent {
  buildingId: string;
  progress: number;
  recipeId: string | null;
  fuelRemaining: number;
}

export interface AssemblerComponent {
  buildingId: string;
  progress: number;
  recipeId: string | null;
  craftingSpeed: number;
}

export interface ChestComponent {
  buildingId: string;
}

export interface PowerPoleComponent {
  buildingId: string;
  supplyRadius: number;
  wireReach: number;
}

export interface GeneratorComponent {
  buildingId: string;
  powerOutput: number; // Watts
  active: boolean;
}

export interface PowerConsumerComponent {
  buildingId: string;
  powerDraw: number;
  powered: boolean;
}

export interface SolarPanelComponent {
  buildingId: string;
  powerOutput: number;
}

export interface AccumulatorComponent {
  buildingId: string;
  capacity: number;
  stored: number;
}

export interface LabComponent {
  buildingId: string;
  progress: number;
}

export interface PipeComponent {
  buildingId: string;
  fluidId: string | null;
  amount: number;
  capacity: number;
}

export interface FluidProducerComponent {
  buildingId: string;
  fluidId: string;
  rate: number;
}

export interface BoilerComponent {
  buildingId: string;
  fuelRemaining: number;
  temperature: number;
}

export interface SteamEngineComponent {
  buildingId: string;
  powerOutput: number;
}

export interface TurretComponent {
  buildingId: string;
  range: number;
  damage: number;
  cooldown: number;
  fireTimer: number;
  usesAmmo: boolean;
}

export interface WallComponent {
  buildingId: string;
}

export interface EnemyComponent {
  kind: string;
  damage: number;
  speed: number;
  aggroRange: number;
  attackCooldown: number;
  attackTimer: number;
}

export interface UnitComponent {
  unitType: string;
  ownerId: number;
  command: 'idle' | 'move' | 'attack' | 'hold' | 'patrol';
  targetX?: number;
  targetY?: number;
  targetEntity?: Entity;
  speed: number;
  damage: number;
  range: number;
}

export interface UnitProductionComponent {
  buildingId: string;
  progress: number;
  queue: string[];
}

export interface RocketSiloComponent {
  buildingId: string;
  parts: number;
  partsRequired: number;
  hasSatellite: boolean;
  launching: boolean;
  launchProgress: number;
}

export interface TreeComponent {
  woodRemaining: number;
}

export interface VelocityComponent {
  vx: number;
  vy: number;
}

export interface ProjectileComponent {
  damage: number;
  ownerId: number;
  ttl: number;
}

export function emptyInventory(size: number): InventoryComponent {
  return {
    slots: Array.from({ length: size }, () => ({ itemId: null, count: 0 })),
  };
}

export function inventoryAdd(inv: InventoryComponent, itemId: string, count: number, stackSize = 1000): number {
  let remaining = count;
  for (const slot of inv.slots) {
    if (slot.itemId === itemId && slot.count < stackSize) {
      const space = stackSize - slot.count;
      const add = Math.min(space, remaining);
      slot.count += add;
      remaining -= add;
      if (remaining <= 0) return 0;
    }
  }
  for (const slot of inv.slots) {
    if (!slot.itemId) {
      const add = Math.min(stackSize, remaining);
      slot.itemId = itemId;
      slot.count = add;
      remaining -= add;
      if (remaining <= 0) return 0;
    }
  }
  return remaining;
}

export function inventoryCount(inv: InventoryComponent, itemId: string): number {
  return inv.slots.reduce((n, s) => (s.itemId === itemId ? n + s.count : n), 0);
}

export function inventoryRemove(inv: InventoryComponent, itemId: string, count: number): boolean {
  if (inventoryCount(inv, itemId) < count) return false;
  let remaining = count;
  for (const slot of inv.slots) {
    if (slot.itemId === itemId) {
      const take = Math.min(slot.count, remaining);
      slot.count -= take;
      remaining -= take;
      if (slot.count <= 0) {
        slot.itemId = null;
        slot.count = 0;
      }
      if (remaining <= 0) return true;
    }
  }
  return remaining <= 0;
}

export function dirOffset(d: Direction): [number, number] {
  switch (d) {
    case 0:
      return [0, -1];
    case 1:
      return [1, 0];
    case 2:
      return [0, 1];
    case 3:
      return [-1, 0];
  }
}

export function rotateDir(d: Direction, delta = 1): Direction {
  return ((((d + delta) % 4) + 4) % 4) as Direction;
}
