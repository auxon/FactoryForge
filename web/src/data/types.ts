// Ported from FactoryForge Swift: Item.swift, Recipe.swift, Building.swift,
// Technology.swift, FluidData.swift, ItemRegistry, RecipeRegistry,
// BuildingRegistry (JSON + embedded), TechnologyRegistry (TechTree.swift).

export type ItemCategory =
  | 'raw' | 'intermediate' | 'production' | 'logistics'
  | 'combat' | 'science' | 'fluid' | 'ammo';

export interface Item {
  id: string; name: string; stackSize: number; category: ItemCategory;
  subgroup?: string; order?: string;
  fuelValue?: number; fuelCategory?: string; placedAs?: string;
}

export type FluidType =
  | 'water' | 'steam' | 'crude-oil' | 'heavy-oil'
  | 'light-oil' | 'petroleum-gas' | 'sulfuric-acid' | 'lubricant';

export interface FluidDef {
  type: FluidType; density: number; viscosity: number;
  temperature: number; energyValue: number;
}

export interface ItemStack { itemId: string; count: number; maxStack?: number; }
export interface FluidStack { type: FluidType; amount: number; temperature?: number; maxAmount?: number; }

export type CraftingCategory =
  | 'crafting' | 'advanced-crafting' | 'smelting' | 'chemistry'
  | 'oil-processing' | 'centrifuging' | 'rocket-building';

export const CATEGORY_BUILDINGS: Record<CraftingCategory, string[]> = {
  crafting: ['player', 'assembling-machine-1', 'assembling-machine-2', 'assembling-machine-3'],
  'advanced-crafting': ['assembling-machine-2', 'assembling-machine-3'],
  smelting: ['stone-furnace', 'steel-furnace', 'electric-furnace'],
  chemistry: ['chemical-plant'],
  'oil-processing': ['oil-refinery'],
  centrifuging: ['centrifuge'],
  'rocket-building': ['rocket-silo'],
};

export interface Recipe {
  id: string; name: string;
  inputs: ItemStack[]; outputs: ItemStack[];
  fluidInputs: FluidStack[]; fluidOutputs: FluidStack[];
  craftTime: number; category: CraftingCategory;
  enabled: boolean; order: string; customTextureId?: string;
}

export interface BuildingDefinition {
  id: string; name: string; type: string;
  width: number; height: number; maxHealth: number;
  textureId: string; cost: ItemStack[];
  miningSpeed?: number; craftingSpeed?: number; craftingCategory?: string;
  beltSpeed?: number; inserterSpeed?: number; inserterStackSize?: number;
  powerConsumption?: number; powerProduction?: number;
  wireReach?: number; supplyArea?: number; fuelCategory?: string;
  accumulatorCapacity?: number; accumulatorChargeRate?: number;
  researchSpeed?: number; turretRange?: number; turretDamage?: number; turretFireRate?: number;
  inventorySlots?: number; fluidCapacity?: number;
  fluidInputType?: FluidType; fluidOutputType?: FluidType;
  extractionRate?: number; inputSlots?: number; outputSlots?: number; fuelSlots?: number;
}

export interface TechBonus { type: string; modifier: number; }
export interface Technology {
  id: string; name: string; description: string;
  prerequisites: string[]; cost: { packId: string; count: number }[];
  researchTime: number;
  unlocks: { recipes: string[]; bonuses: TechBonus[] };
  order: string; tier: number;
}
