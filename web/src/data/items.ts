// Ported from ItemRegistry.swift. 88 items. textureId = id with '-' -> '_'.
import type { Item } from './types';

function it(id: string, name: string, stackSize: number,
  category: Item['category'], extra: Partial<Item> = {}): Item {
  return { id, name, stackSize, category, subgroup: 'other', ...extra };
}

export const ITEMS: Item[] = [
  // raw (6)
  it('iron-ore', 'Iron Ore', 1000, 'raw', { order: 'a' }),
  it('copper-ore', 'Copper Ore', 1000, 'raw', { order: 'b' }),
  it('coal', 'Coal', 1000, 'raw', { order: 'c', fuelValue: 4000, fuelCategory: 'chemical' }),
  it('stone', 'Stone', 1000, 'raw', { order: 'd' }),
  it('wood', 'Wood', 1000, 'raw', { order: 'e', fuelValue: 2000, fuelCategory: 'chemical' }),
  it('uranium-ore', 'Uranium Ore', 1000, 'raw', { order: 'l' }),
  // fluid (7)
  it('water', 'Water', 0, 'fluid', { order: 'f' }),
  it('crude-oil', 'Crude Oil', 100, 'fluid', { order: 'g' }),
  it('petroleum-gas', 'Petroleum Gas', 0, 'fluid', { order: 'g' }),
  it('light-oil', 'Light Oil', 0, 'fluid', { order: 'h' }),
  it('heavy-oil', 'Heavy Oil', 0, 'fluid', { order: 'i' }),
  it('lubricant', 'Lubricant', 0, 'fluid', { order: 'j' }),
  it('sulfuric-acid', 'Sulfuric Acid', 0, 'fluid', { order: 'k' }),
  // intermediate (24)
  it('iron-plate', 'Iron Plate', 1000, 'intermediate', { order: 'a' }),
  it('copper-plate', 'Copper Plate', 1000, 'intermediate', { order: 'b' }),
  it('steel-plate', 'Steel Plate', 1000, 'intermediate', { order: 'c' }),
  it('stone-brick', 'Stone Brick', 1000, 'intermediate', { order: 'd' }),
  it('iron-gear-wheel', 'Iron Gear Wheel', 1000, 'intermediate', { order: 'e' }),
  it('copper-cable', 'Copper Cable', 1000, 'intermediate', { order: 'f' }),
  it('pipe', 'Pipe', 1000, 'intermediate', { order: 'f1' }),
  it('electronic-circuit', 'Electronic Circuit', 1000, 'intermediate', { order: 'g' }),
  it('advanced-circuit', 'Advanced Circuit', 1000, 'intermediate', { order: 'h' }),
  it('processing-unit', 'Processing Unit', 500, 'intermediate', { order: 'i' }),
  it('engine-unit', 'Engine Unit', 500, 'intermediate', { order: 'j' }),
  it('electric-engine-unit', 'Electric Engine Unit', 500, 'intermediate', { order: 'k' }),
  it('plastic-bar', 'Plastic Bar', 1000, 'intermediate', { order: 'l' }),
  it('sulfur', 'Sulfur', 1000, 'intermediate', { order: 'm' }),
  it('battery', 'Battery', 1000, 'intermediate', { order: 'n' }),
  it('explosives', 'Explosives', 500, 'intermediate', { order: 'o' }),
  it('uranium-235', 'Uranium 235', 100, 'intermediate', { order: 'p' }),
  it('uranium-238', 'Uranium 238', 100, 'intermediate', { order: 'q' }),
  it('nuclear-fuel', 'Nuclear Fuel', 10, 'intermediate', { order: 'r' }),
  it('rocket-fuel', 'Rocket Fuel', 100, 'intermediate', { order: 's' }),
  it('rocket-parts', 'Rocket Parts', 50, 'intermediate', { order: 't' }),
  it('satellite', 'Satellite', 10, 'intermediate', { order: 'u' }),
  it('low-density-structure', 'Low Density Structure', 100, 'intermediate', { order: 'v' }),
  it('solid-fuel', 'Solid Fuel', 500, 'intermediate', { order: 'w', fuelValue: 25000, fuelCategory: 'chemical' }),
  // --- web-port additions: items the Swift registries reference but never define.
  // Without these, whole branches (belts, modules, science) are uncraftable.
  it('iron-stick', 'Iron Stick', 1000, 'intermediate', { order: 'x' }),
  it('speed-module', 'Speed Module', 500, 'intermediate', { order: 'y' }),
  it('water-pump', 'Water Pump', 100, 'production', { order: 'm1', placedAs: 'water-pump' }),
  it('underground-pipe', 'Underground Pipe', 100, 'production', { order: 'm2' }),
  it('fluid-tank', 'Fluid Tank', 100, 'production', { order: 'm3' }),
  it('uranium-rounds-magazine', 'Uranium Rounds Magazine', 1000, 'ammo', { order: 'c' }),
  // science (7)
  it('automation-science-pack', 'Automation Science Pack', 200, 'science', { order: 'a' }),
  it('logistic-science-pack', 'Logistic Science Pack', 200, 'science', { order: 'b' }),
  it('military-science-pack', 'Military Science Pack', 200, 'science', { order: 'c' }),
  it('chemical-science-pack', 'Chemical Science Pack', 200, 'science', { order: 'd' }),
  it('production-science-pack', 'Production Science Pack', 200, 'science', { order: 'e' }),
  it('utility-science-pack', 'Utility Science Pack', 200, 'science', { order: 'f' }),
  it('space-science-pack', 'Space Science Pack', 2000, 'science', { order: 'g' }),
  // logistics (14)
  it('transport-belt', 'Transport Belt', 500, 'logistics', { order: 'a', placedAs: 'transport-belt' }),
  it('fast-transport-belt', 'Fast Transport Belt', 500, 'logistics', { order: 'b' }),
  it('express-transport-belt', 'Express Transport Belt', 500, 'logistics', { order: 'c' }),
  it('underground-belt', 'Underground Belt', 200, 'logistics', { order: 'd' }),
  it('splitter', 'Splitter', 200, 'logistics', { order: 'e' }),
  it('merger', 'Merger', 200, 'logistics', { order: 'f' }),
  it('belt-bridge', 'Belt Bridge', 200, 'logistics', { order: 'g' }),
  it('inserter', 'Inserter', 100, 'logistics', { order: 'h' }),
  it('long-handed-inserter', 'Long Handed Inserter', 100, 'logistics', { order: 'i' }),
  it('fast-inserter', 'Fast Inserter', 100, 'logistics', { order: 'j' }),
  it('stack-inserter', 'Stack Inserter', 50, 'logistics', { order: 'k' }),
  it('wooden-chest', 'Wooden Chest', 200, 'logistics', { order: 'l' }),
  it('iron-chest', 'Iron Chest', 200, 'logistics', { order: 'm' }),
  it('steel-chest', 'Steel Chest', 200, 'logistics', { order: 'n' }),
  // production (15) + power (7)
  it('burner-mining-drill', 'Burner Mining Drill', 100, 'production', { order: 'a', placedAs: 'burner-mining-drill' }),
  it('electric-mining-drill', 'Electric Mining Drill', 100, 'production', { order: 'b', placedAs: 'electric-mining-drill' }),
  it('stone-furnace', 'Stone Furnace', 100, 'production', { order: 'c', placedAs: 'stone-furnace' }),
  it('steel-furnace', 'Steel Furnace', 100, 'production', { order: 'd' }),
  it('electric-furnace', 'Electric Furnace', 100, 'production', { order: 'e' }),
  it('assembling-machine-1', 'Assembling Machine 1', 100, 'production', { order: 'f' }),
  it('assembling-machine-2', 'Assembling Machine 2', 100, 'production', { order: 'g' }),
  it('assembling-machine-3', 'Assembling Machine 3', 100, 'production', { order: 'h' }),
  it('lab', 'Lab', 50, 'production', { order: 'l' }),
  it('pumpjack', 'Pumpjack', 50, 'production', { order: 'm' }),
  it('oil-refinery', 'Oil Refinery', 50, 'production', { order: 'n' }),
  it('chemical-plant', 'Chemical Plant', 50, 'production', { order: 'o' }),
  it('nuclear-reactor', 'Nuclear Reactor', 20, 'production', { order: 'p' }),
  it('centrifuge', 'Centrifuge', 20, 'production', { order: 'q' }),
  it('rocket-silo', 'Rocket Silo', 1, 'production', { order: 'r' }),
  it('boiler', 'Boiler', 100, 'production', { order: 'j' }),
  it('steam-engine', 'Steam Engine', 50, 'production', { order: 'k' }),
  it('solar-panel', 'Solar Panel', 200, 'production', { order: 'l' }),
  it('accumulator', 'Accumulator', 100, 'production', { order: 'm' }),
  it('small-electric-pole', 'Small Electric Pole', 200, 'production', { order: 'n' }),
  it('medium-electric-pole', 'Medium Electric Pole', 200, 'production', { order: 'o' }),
  it('big-electric-pole', 'Big Electric Pole', 100, 'production', { order: 'p' }),
  // combat (6)
  it('sword', 'Sword', 1, 'combat', { order: 'a' }),
  it('gun-turret', 'Gun Turret', 100, 'combat', { order: 'c', placedAs: 'gun-turret' }),
  it('laser-turret', 'Laser Turret', 100, 'combat', { order: 'd' }),
  it('wall', 'Wall', 100, 'combat', { order: 'e', placedAs: 'stone-wall' }),
  it('grenade', 'Grenade', 100, 'combat', { order: 'f' }),
  it('radar', 'Radar', 50, 'combat', { order: 'g', placedAs: 'radar' }),
  // ammo (2)
  it('firearm-magazine', 'Firearm Magazine', 1000, 'ammo', { order: 'a' }),
  it('piercing-rounds-magazine', 'Piercing Rounds Magazine', 1000, 'ammo', { order: 'b' }),
];

export const ITEM_MAP: Map<string, Item> = new Map(ITEMS.map((i) => [i.id, i]));
export const textureIdFor = (id: string): string => id.replace(/-/g, '_');

export const ALLOWED_SCIENCE_PACKS = [
  'automation-science-pack', 'logistic-science-pack', 'military-science-pack',
  'chemical-science-pack', 'production-science-pack', 'utility-science-pack',
  'space-science-pack',
];
export const ALLOWED_FUEL = ['coal', 'wood', 'solid-fuel', 'rocket-fuel', 'nuclear-fuel'];

// Default-unlocked recipes from ResearchSystem (bypass research).
export const DEFAULT_UNLOCKED_RECIPES = [
  'iron-plate', 'copper-plate', 'stone-brick', 'steel-plate',
  'iron-gear-wheel', 'copper-cable', 'pipe', 'electronic-circuit',
  'transport-belt', 'belt-bridge', 'inserter',
  'wooden-chest', 'iron-chest',
  'burner-mining-drill', 'electric-mining-drill', 'stone-furnace',
  'boiler', 'steam-engine', 'small-electric-pole',
  'firearm-magazine', 'automation-science-pack',
  'lab', 'radar', 'pumpjack', 'oil-refinery', 'chemical-plant',
];
