// Ported from FluidData.swift. 8 fluids.
import type { FluidDef, FluidType } from './types';

export const FLUIDS: FluidDef[] = [
  { type: 'water', density: 1.0, viscosity: 1.0, temperature: 15, energyValue: 0 },
  { type: 'steam', density: 0.5, viscosity: 0.8, temperature: 165, energyValue: 500 },
  { type: 'crude-oil', density: 0.85, viscosity: 12.0, temperature: 20, energyValue: 0 },
  { type: 'heavy-oil', density: 0.95, viscosity: 20.0, temperature: 20, energyValue: 0 },
  { type: 'light-oil', density: 0.75, viscosity: 3.0, temperature: 20, energyValue: 0 },
  { type: 'petroleum-gas', density: 0.25, viscosity: 0.3, temperature: 20, energyValue: 0 },
  { type: 'sulfuric-acid', density: 1.8, viscosity: 2.5, temperature: 20, energyValue: 0 },
  { type: 'lubricant', density: 0.9, viscosity: 6.0, temperature: 20, energyValue: 0 },
];

export const FLUID_MAP: Map<FluidType, FluidDef> =
  new Map(FLUIDS.map((f) => [f.type, f]));

// Fuel burn seconds per item when used in burner miners/furnaces/boilers
// (MiningSystem/CraftingSystem/PowerSystem simplified-seconds model).
export const FUEL_BURN_SECONDS: Record<string, number> = {
  coal: 4.0,
  wood: 2.0,
  'solid-fuel': 12.0,
};

// Enemies (EnemyAISystem). stats: hp / damage / speed tiles-s / range / cooldown s.
export interface EnemyDef {
  id: string; hp: number; damage: number; speed: number;
  range: number; cooldown: number; ranged: boolean; minEvolution: number;
}
export const ENEMIES: EnemyDef[] = [
  { id: 'small-biter', hp: 15, damage: 7, speed: 3.0, range: 1, cooldown: 0.5, ranged: false, minEvolution: 0 },
  { id: 'medium-biter', hp: 75, damage: 15, speed: 2.5, range: 1, cooldown: 0.5, ranged: false, minEvolution: 0 },
  { id: 'big-biter', hp: 375, damage: 30, speed: 2.0, range: 1, cooldown: 0.5, ranged: false, minEvolution: 0.3 },
  { id: 'behemoth-biter', hp: 3000, damage: 90, speed: 1.5, range: 1, cooldown: 0.5, ranged: false, minEvolution: 0.6 },
  { id: 'small-spitter', hp: 10, damage: 10, speed: 2.5, range: 13, cooldown: 2.0, ranged: true, minEvolution: 0.1 },
  { id: 'medium-spitter', hp: 50, damage: 20, speed: 2.0, range: 14, cooldown: 2.0, ranged: true, minEvolution: 0.3 },
  { id: 'big-spitter', hp: 200, damage: 40, speed: 1.5, range: 15, cooldown: 2.0, ranged: true, minEvolution: 0.6 },
  { id: 'behemoth-spitter', hp: 1500, damage: 75, speed: 1.0, range: 16, cooldown: 2.0, ranged: true, minEvolution: 0.9 },
];

export const ENEMY_TUNING = {
  spawnerHp: 350,
  spawnerMaxEnemies: 5,
  spawnerCooldown: 20,
  pollutionThreshold: 100,
  globalCap: 50,
  waveInterval: 300,
  waveSpawnDistance: 50,
};
