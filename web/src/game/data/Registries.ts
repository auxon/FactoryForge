import itemsData from '@shared/data/items.json';
import recipesData from '@shared/data/recipes.json';
import techsData from '@shared/data/techs.json';
import startingItemsData from '@shared/data/starting_items.json';

import miners from '@shared/data/buildings/miners.json';
import furnaces from '@shared/data/buildings/furnaces.json';
import assemblers from '@shared/data/buildings/assemblers.json';
import belts from '@shared/data/buildings/belts.json';
import inserters from '@shared/data/buildings/inserters.json';
import power from '@shared/data/buildings/power.json';
import fluids from '@shared/data/buildings/fluids.json';
import storage from '@shared/data/buildings/storage.json';
import combat from '@shared/data/buildings/combat.json';
import rockets from '@shared/data/buildings/rockets.json';
import nuclear from '@shared/data/buildings/nuclear.json';
import units from '@shared/data/buildings/units.json';

export interface ItemDef {
  id: string;
  name: string;
  stackSize: number;
  category: string;
  order: string;
  fuelValue?: number | null;
  fuelCategory?: string | null;
  placedAs?: string | null;
}

export interface ItemStack {
  itemId: string;
  count: number;
}

export interface RecipeDef {
  id: string;
  name: string;
  inputs: ItemStack[];
  outputs: ItemStack[];
  craftTime: number;
  category: string;
  order: string;
  enabled?: boolean;
}

export interface TechDef {
  id: string;
  name: string;
  description: string;
  cost: ItemStack[];
  researchTime: number;
  unlocks: { recipes?: string[]; buildings?: string[] };
  prerequisites?: string[];
  order: string;
  tier: number;
}

export interface BuildingDef {
  id: string;
  name: string;
  type: string;
  width?: number;
  height?: number;
  maxHealth?: number;
  cost?: ItemStack[];
  miningSpeed?: number;
  beltSpeed?: number;
  craftingSpeed?: number;
  powerConsumption?: number;
  powerProduction?: number;
  supplyArea?: number;
  wireReach?: number;
  insertionSpeed?: number;
  stackSize?: number;
  reach?: number;
  fuelSlots?: number;
  inputSlots?: number;
  outputSlots?: number;
  fluidCapacity?: number;
  range?: number;
  damage?: number;
  [key: string]: unknown;
}

export class ItemRegistry {
  private items = new Map<string, ItemDef>();

  constructor() {
    for (const item of itemsData as ItemDef[]) this.items.set(item.id, item);
  }

  get(id: string): ItemDef | undefined {
    return this.items.get(id);
  }

  get all(): ItemDef[] {
    return [...this.items.values()].sort((a, b) => a.order.localeCompare(b.order));
  }

  stackSize(id: string): number {
    return this.items.get(id)?.stackSize ?? 100;
  }

  isFuel(id: string): boolean {
    return (this.items.get(id)?.fuelValue ?? 0) > 0;
  }

  fuelValue(id: string): number {
    return this.items.get(id)?.fuelValue ?? 0;
  }
}

export class RecipeRegistry {
  private recipes = new Map<string, RecipeDef>();

  constructor() {
    for (const r of recipesData as RecipeDef[]) this.recipes.set(r.id, r);
  }

  get(id: string): RecipeDef | undefined {
    return this.recipes.get(id);
  }

  get all(): RecipeDef[] {
    return [...this.recipes.values()].sort((a, b) => a.order.localeCompare(b.order));
  }

  byCategory(category: string): RecipeDef[] {
    return this.all.filter((r) => r.category === category);
  }

  forSmelting(inputItemId: string): RecipeDef | undefined {
    return this.all.find(
      (r) => r.category === 'smelting' && r.inputs.some((i) => i.itemId === inputItemId),
    );
  }
}

export class TechnologyRegistry {
  private techs = new Map<string, TechDef>();

  constructor() {
    for (const t of techsData as TechDef[]) this.techs.set(t.id, t);
  }

  get(id: string): TechDef | undefined {
    return this.techs.get(id);
  }

  get all(): TechDef[] {
    return [...this.techs.values()].sort((a, b) => a.order.localeCompare(b.order));
  }
}

export class BuildingRegistry {
  private buildings = new Map<string, BuildingDef>();

  constructor() {
    const packs = [
      miners,
      furnaces,
      assemblers,
      belts,
      inserters,
      power,
      fluids,
      storage,
      combat,
      rockets,
      nuclear,
      units,
    ] as Array<BuildingDef[] | { buildings?: BuildingDef[] }>;

    for (const pack of packs) {
      const list = Array.isArray(pack) ? pack : (pack.buildings ?? []);
      for (const b of list) {
        this.buildings.set(b.id, {
          width: 1,
          height: 1,
          maxHealth: 100,
          ...b,
        });
      }
    }
  }

  get(id: string): BuildingDef | undefined {
    return this.buildings.get(id);
  }

  get all(): BuildingDef[] {
    return [...this.buildings.values()];
  }

  byType(type: string): BuildingDef[] {
    return this.all.filter((b) => b.type === type);
  }
}

export function getStartingItems(): ItemStack[] {
  const data = startingItemsData as { startingItems: Array<{ itemId: string; count: number }> };
  return data.startingItems.map((i) => ({ itemId: i.itemId, count: i.count }));
}
