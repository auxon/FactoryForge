// Ported from building_configs/*.json + embedded lab/offshore-pump.
// 47 runtime buildings.
import type { BuildingDefinition, ItemStack } from './types';

type P = [string, number];
const cost = (...pairs: P[]): ItemStack[] =>
  pairs.map(([itemId, count]) => ({ itemId, count }));

function B(def: Omit<BuildingDefinition, 'width' | 'height' | 'textureId'> & {
  width?: number; height?: number; textureId?: string;
}): BuildingDefinition {
  return { width: 1, height: 1, textureId: def.id.replace(/-/g, '_'), ...def };
}

export const BUILDINGS: BuildingDefinition[] = [
  // miners
  B({ id: 'burner-mining-drill', name: 'Burner Mining Drill', type: 'Miner', width: 2, height: 2, maxHealth: 150, cost: cost(['iron-plate', 5]), miningSpeed: 0.5, inputSlots: 0, outputSlots: 1, fuelSlots: 1, fuelCategory: 'chemical' }),
  B({ id: 'electric-mining-drill', name: 'Electric Mining Drill', type: 'Miner', width: 3, height: 3, maxHealth: 300, cost: cost(['electronic-circuit', 3], ['iron-gear-wheel', 5], ['iron-plate', 10]), miningSpeed: 0.75, powerConsumption: 90, inputSlots: 0, outputSlots: 1, fuelSlots: 0 }),
  B({ id: 'pumpjack', name: 'Pumpjack', type: 'Pumpjack', maxHealth: 200, cost: cost(['steel-plate', 5], ['iron-gear-wheel', 10], ['electronic-circuit', 5], ['pipe', 10]), powerConsumption: 90, extractionRate: 1.0, fluidOutputType: 'crude-oil', inventorySlots: 1, inputSlots: 0, outputSlots: 1, fuelSlots: 0 }),
  B({ id: 'water-pump', name: 'Water Pump', type: 'WaterPump', maxHealth: 150, cost: cost(['iron-plate', 5], ['pipe', 5], ['electronic-circuit', 2]), powerConsumption: 30, extractionRate: 20.0, fluidOutputType: 'water' }),
  B({ id: 'offshore-pump', name: 'Offshore Pump', type: 'WaterPump', maxHealth: 80, cost: cost(['electronic-circuit', 2], ['pipe', 1], ['iron-gear-wheel', 1]), powerConsumption: 10, fluidCapacity: 50, fluidOutputType: 'water' }),
  // furnaces
  B({ id: 'stone-furnace', name: 'Stone Furnace', type: 'Furnace', width: 2, height: 2, maxHealth: 200, cost: cost(['iron-plate', 5]), craftingSpeed: 1, craftingCategory: 'smelting', inputSlots: 1, outputSlots: 1, fuelSlots: 1 }),
  B({ id: 'steel-furnace', name: 'Steel Furnace', type: 'Furnace', width: 2, height: 2, maxHealth: 300, cost: cost(['steel-plate', 6], ['stone-brick', 10]), craftingSpeed: 2, craftingCategory: 'smelting', inputSlots: 1, outputSlots: 1, fuelSlots: 1 }),
  B({ id: 'electric-furnace', name: 'Electric Furnace', type: 'Furnace', width: 3, height: 3, maxHealth: 350, cost: cost(['steel-plate', 10], ['advanced-circuit', 5], ['stone-brick', 10]), craftingSpeed: 2, craftingCategory: 'smelting', powerConsumption: 180, inputSlots: 1, outputSlots: 1, fuelSlots: 0 }),
  // assemblers
  B({ id: 'assembling-machine-1', name: 'Assembling Machine 1', type: 'Assembler', width: 3, height: 3, maxHealth: 300, cost: cost(['electronic-circuit', 3], ['iron-gear-wheel', 5], ['iron-plate', 9]), craftingSpeed: 0.5, craftingCategory: 'crafting', powerConsumption: 75, inputSlots: 4, outputSlots: 4, fuelSlots: 0 }),
  B({ id: 'assembling-machine-2', name: 'Assembling Machine 2', type: 'Assembler', width: 3, height: 3, maxHealth: 350, cost: cost(['iron-plate', 9], ['electronic-circuit', 3], ['iron-gear-wheel', 5], ['assembling-machine-1', 1]), craftingSpeed: 0.75, craftingCategory: 'advanced-crafting', powerConsumption: 150, inputSlots: 4, outputSlots: 4, fuelSlots: 0 }),
  B({ id: 'assembling-machine-3', name: 'Assembling Machine 3', type: 'Assembler', width: 3, height: 3, maxHealth: 400, cost: cost(['assembling-machine-2', 2], ['speed-module', 4]), craftingSpeed: 1.25, craftingCategory: 'advanced-crafting', powerConsumption: 375, inputSlots: 4, outputSlots: 4, fuelSlots: 0 }),
  // belts
  B({ id: 'transport-belt', name: 'Transport Belt', type: 'Belt', maxHealth: 50, cost: cost(['iron-gear-wheel', 1], ['iron-plate', 1]), beltSpeed: 1.875 }),
  B({ id: 'fast-transport-belt', name: 'Fast Transport Belt', type: 'Belt', maxHealth: 50, cost: cost(['iron-gear-wheel', 5], ['iron-plate', 1]), beltSpeed: 3.75 }),
  B({ id: 'express-transport-belt', name: 'Express Transport Belt', type: 'Belt', maxHealth: 50, cost: cost(['iron-gear-wheel', 10], ['advanced-circuit', 2], ['steel-plate', 1]), beltSpeed: 5.625 }),
  B({ id: 'underground-belt', name: 'Underground Belt', type: 'Belt', maxHealth: 60, cost: cost(['iron-plate', 10], ['transport-belt', 5]), beltSpeed: 1.875 }),
  B({ id: 'splitter', name: 'Splitter', type: 'Belt', maxHealth: 80, cost: cost(['electronic-circuit', 5], ['iron-plate', 5], ['transport-belt', 4]), beltSpeed: 1.875 }),
  B({ id: 'merger', name: 'Merger', type: 'Belt', maxHealth: 80, cost: cost(['electronic-circuit', 5], ['iron-plate', 5], ['transport-belt', 4]), beltSpeed: 1.875 }),
  B({ id: 'belt-bridge', name: 'Belt Bridge', type: 'Belt', maxHealth: 50, cost: cost(['iron-plate', 1], ['iron-stick', 2], ['iron-gear-wheel', 2]), beltSpeed: 1.875 }),
  // inserters
  B({ id: 'inserter', name: 'Inserter', type: 'Inserter', maxHealth: 40, cost: cost(['electronic-circuit', 1], ['iron-gear-wheel', 1], ['iron-plate', 1]), inserterSpeed: 4.0, inserterStackSize: 1, powerConsumption: 13 }),
  B({ id: 'long-handed-inserter', name: 'Long Handed Inserter', type: 'Inserter', maxHealth: 40, cost: cost(['iron-gear-wheel', 1], ['iron-plate', 1], ['inserter', 1]), inserterSpeed: 1.2, inserterStackSize: 1, powerConsumption: 18 }),
  B({ id: 'fast-inserter', name: 'Fast Inserter', type: 'Inserter', maxHealth: 40, cost: cost(['electronic-circuit', 2], ['iron-plate', 2], ['inserter', 1]), inserterSpeed: 2.31, inserterStackSize: 1, powerConsumption: 46 }),
  B({ id: 'stack-inserter', name: 'Stack Inserter', type: 'Inserter', maxHealth: 40, cost: cost(['advanced-circuit', 1], ['electronic-circuit', 15], ['iron-gear-wheel', 15], ['fast-inserter', 1]), inserterSpeed: 1.5, inserterStackSize: 2, powerConsumption: 75 }),
  // power
  B({ id: 'small-electric-pole', name: 'Small Electric Pole', type: 'PowerPole', maxHealth: 100, cost: cost(['wood', 2], ['copper-cable', 2]), wireReach: 7.5, supplyArea: 2.5 }),
  B({ id: 'medium-electric-pole', name: 'Medium Electric Pole', type: 'PowerPole', maxHealth: 100, cost: cost(['steel-plate', 2], ['copper-plate', 2]), wireReach: 9, supplyArea: 3.5 }),
  B({ id: 'big-electric-pole', name: 'Big Electric Pole', type: 'PowerPole', width: 2, height: 2, maxHealth: 150, cost: cost(['steel-plate', 5], ['copper-plate', 5]), wireReach: 30, supplyArea: 2 }),
  B({ id: 'boiler', name: 'Boiler', type: 'Generator', width: 2, height: 3, maxHealth: 200, cost: cost(['iron-plate', 5], ['pipe', 4]), fuelCategory: 'chemical', fluidCapacity: 540, inputSlots: 0, outputSlots: 0, fuelSlots: 1 }),
  B({ id: 'steam-engine', name: 'Steam Engine', type: 'Generator', width: 3, height: 5, maxHealth: 400, cost: cost(['iron-gear-wheel', 8], ['iron-plate', 10], ['pipe', 5]), powerProduction: 900, fluidInputType: 'steam', fluidCapacity: 540 }),
  B({ id: 'solar-panel', name: 'Solar Panel', type: 'SolarPanel', width: 3, height: 3, maxHealth: 200, cost: cost(['steel-plate', 5], ['electronic-circuit', 15], ['copper-plate', 5]), powerProduction: 60 }),
  B({ id: 'accumulator', name: 'Accumulator', type: 'Accumulator', width: 2, height: 2, maxHealth: 150, cost: cost(['iron-plate', 2], ['battery', 5]), accumulatorCapacity: 5000, accumulatorChargeRate: 300 }),
  // combat
  B({ id: 'gun-turret', name: 'Gun Turret', type: 'Turret', width: 2, height: 2, maxHealth: 400, cost: cost(['iron-gear-wheel', 10], ['copper-plate', 10], ['iron-plate', 20]), turretRange: 18, turretDamage: 6, turretFireRate: 10, inputSlots: 1 }),
  B({ id: 'laser-turret', name: 'Laser Turret', type: 'Turret', width: 2, height: 2, maxHealth: 1000, cost: cost(['steel-plate', 20], ['electronic-circuit', 20], ['battery', 12]), turretRange: 24, turretDamage: 20, turretFireRate: 20, powerConsumption: 800, inputSlots: 1 }),
  B({ id: 'stone-wall', name: 'Stone Wall', type: 'Wall', maxHealth: 350, cost: cost(['stone-brick', 5]), textureId: 'wall' }),
  // storage
  B({ id: 'wooden-chest', name: 'Wooden Chest', type: 'Chest', maxHealth: 100, cost: cost(['wood', 2]), inventorySlots: 16 }),
  B({ id: 'iron-chest', name: 'Iron Chest', type: 'Chest', maxHealth: 200, cost: cost(['iron-plate', 8]), inventorySlots: 32 }),
  B({ id: 'steel-chest', name: 'Steel Chest', type: 'Chest', maxHealth: 350, cost: cost(['steel-plate', 8]), inventorySlots: 48 }),
  // fluids
  B({ id: 'oil-refinery', name: 'Oil Refinery', type: 'OilRefinery', width: 3, height: 3, maxHealth: 300, cost: cost(['steel-plate', 15], ['iron-gear-wheel', 10], ['electronic-circuit', 10], ['pipe', 10], ['stone-brick', 10]), powerConsumption: 420, craftingCategory: 'oil-processing', craftingSpeed: 1, fluidCapacity: 12500 }),
  B({ id: 'chemical-plant', name: 'Chemical Plant', type: 'ChemicalPlant', width: 3, height: 3, maxHealth: 300, cost: cost(['steel-plate', 5], ['iron-gear-wheel', 5], ['electronic-circuit', 5], ['pipe', 5]), powerConsumption: 210, inventorySlots: 5, inputSlots: 3, outputSlots: 2, fluidCapacity: 1500 }),
  B({ id: 'pipe', name: 'Pipe', type: 'Pipe', maxHealth: 50, cost: cost(['iron-plate', 1]), fluidCapacity: 100 }),
  B({ id: 'underground-pipe', name: 'Underground Pipe', type: 'Pipe', maxHealth: 60, cost: cost(['iron-plate', 5], ['pipe', 5]), fluidCapacity: 300 }),
  B({ id: 'fluid-tank', name: 'Fluid Tank', type: 'FluidTank', width: 3, height: 3, maxHealth: 500, cost: cost(['iron-plate', 20], ['steel-plate', 5], ['iron-gear-wheel', 3]), fluidCapacity: 25000 }),
  // nuclear
  B({ id: 'nuclear-reactor', name: 'Nuclear Reactor', type: 'NuclearReactor', width: 5, height: 5, maxHealth: 500, cost: cost(['steel-plate', 400], ['advanced-circuit', 400], ['copper-plate', 400], ['stone-brick', 400]), powerProduction: 40000, fuelSlots: 1 }),
  B({ id: 'centrifuge', name: 'Centrifuge', type: 'Centrifuge', width: 3, height: 3, maxHealth: 300, cost: cost(['centrifuge', 1]), powerConsumption: 350, inventorySlots: 4, inputSlots: 2, outputSlots: 2 }),
  // rockets
  B({ id: 'rocket-silo', name: 'Rocket Silo', type: 'RocketSilo', width: 9, height: 9, maxHealth: 5000, cost: cost(['steel-plate', 1000], ['stone-brick', 1000], ['pipe', 100], ['processing-unit', 200]), powerConsumption: 1000, inventorySlots: 5, inputSlots: 4, fuelSlots: 1 }),
  // lab (embedded in BuildingRegistry.swift)
  B({ id: 'lab', name: 'Lab', type: 'Lab', width: 3, height: 3, maxHealth: 150, cost: cost(['electronic-circuit', 10], ['iron-gear-wheel', 10], ['transport-belt', 4]), researchSpeed: 1.0, powerConsumption: 60, inputSlots: 2 }),
  // unit production (no items; not placeable via inventory)
  B({ id: 'military-barracks', name: 'Military Barracks', type: 'UnitProduction', width: 4, height: 3, maxHealth: 300, cost: cost(['iron-plate', 20], ['stone-brick', 10], ['electronic-circuit', 5]), powerConsumption: 50, inventorySlots: 10, outputSlots: 10 }),
  B({ id: 'fantasy-academy', name: 'Fantasy Academy', type: 'UnitProduction', width: 4, height: 3, maxHealth: 350, cost: cost(['stone-brick', 20], ['iron-plate', 15], ['electronic-circuit', 10]), powerConsumption: 75, inventorySlots: 8, outputSlots: 8 }),
  B({ id: 'elemental-summoning-circle', name: 'Elemental Summoning Circle', type: 'UnitProduction', width: 5, height: 5, maxHealth: 400, cost: cost(['stone-brick', 25], ['electronic-circuit', 15], ['advanced-circuit', 5]), powerConsumption: 100, inventorySlots: 6, outputSlots: 6 }),
];

export const BUILDING_MAP: Map<string, BuildingDefinition> =
  new Map(BUILDINGS.map((b) => [b.id, b]));

export const BUILD_CATEGORIES: { id: string; buildings: string[] }[] = [
  { id: 'miners', buildings: ['burner-mining-drill', 'electric-mining-drill', 'pumpjack', 'water-pump', 'offshore-pump'] },
  { id: 'furnaces', buildings: ['stone-furnace', 'steel-furnace', 'electric-furnace'] },
  { id: 'assemblers', buildings: ['assembling-machine-1', 'assembling-machine-2', 'assembling-machine-3'] },
  { id: 'belts', buildings: ['transport-belt', 'fast-transport-belt', 'express-transport-belt', 'underground-belt', 'splitter', 'merger', 'belt-bridge'] },
  { id: 'inserters', buildings: ['inserter', 'long-handed-inserter', 'fast-inserter', 'stack-inserter'] },
  { id: 'power', buildings: ['small-electric-pole', 'medium-electric-pole', 'big-electric-pole', 'boiler', 'steam-engine', 'solar-panel', 'accumulator'] },
  { id: 'combat', buildings: ['gun-turret', 'laser-turret', 'stone-wall'] },
  { id: 'storage', buildings: ['wooden-chest', 'iron-chest', 'steel-chest'] },
  { id: 'fluids', buildings: ['oil-refinery', 'chemical-plant', 'pipe', 'underground-pipe', 'fluid-tank'] },
  { id: 'nuclear', buildings: ['nuclear-reactor', 'centrifuge'] },
  { id: 'rockets', buildings: ['rocket-silo'] },
  { id: 'lab', buildings: ['lab'] },
];
