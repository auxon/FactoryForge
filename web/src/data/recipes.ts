// Ported from RecipeRegistry.swift. 59 unique recipes.
// NOTE (faithful to Swift): some recipes reference items with no Item
// definition: 'iron-stick', 'speed-module', 'stone-wall' (item is 'wall'),
// 'water-pump' (no item). Kept as-is; crafting validation must tolerate them.
import type { Recipe, ItemStack, FluidStack } from './types';

function R(id: string, name: string, inputs: Pair[], outputs: Pair[],
  craftTime: number, category: Recipe['category'], order: string,
  extra: Partial<Recipe> = {}): Recipe {
  const inp: ItemStack[] = inputs.map(([itemId, count]) => ({ itemId, count }));
  const out: ItemStack[] = outputs.map(([itemId, count]) => ({ itemId, count }));
  return {
    id, name, inputs: inp, outputs: out,
    fluidInputs: [], fluidOutputs: [], craftTime, category,
    enabled: true, order, ...extra,
  };
}
const F = (type: FluidStack['type'], amount: number): FluidStack => ({ type, amount });

// helper: pairs shorthand
type Pair = [string, number];
const p = (itemId: string, count: number): Pair => [itemId, count];

export const RECIPES: Recipe[] = [
  // smelting
  R('iron-plate', 'Iron Plate', [p('iron-ore', 1)], [p('iron-plate', 1)], 3.2, 'smelting', 'a'),
  R('copper-plate', 'Copper Plate', [p('copper-ore', 1)], [p('copper-plate', 1)], 3.2, 'smelting', 'b'),
  R('steel-plate', 'Steel Plate', [p('iron-plate', 5)], [p('steel-plate', 1)], 16, 'smelting', 'c'),
  R('stone-brick', 'Stone Brick', [p('stone', 2)], [p('stone-brick', 1)], 3.2, 'smelting', 'd'),
  // crafting intermediates
  R('iron-gear-wheel', 'Iron Gear Wheel', [p('iron-plate', 2)], [p('iron-gear-wheel', 1)], 0.5, 'crafting', 'a'),
  R('copper-cable', 'Copper Cable', [p('copper-plate', 1)], [p('copper-cable', 2)], 0.5, 'crafting', 'b'),
  R('pipe', 'Pipe', [p('iron-plate', 1)], [p('pipe', 1)], 0.5, 'crafting', 'b1'),
  R('electronic-circuit', 'Electronic Circuit', [p('iron-plate', 1), p('copper-cable', 3)], [p('electronic-circuit', 1)], 0.5, 'crafting', 'c'),
  R('advanced-circuit', 'Advanced Circuit', [p('electronic-circuit', 2), p('copper-cable', 4), p('plastic-bar', 2)], [p('advanced-circuit', 1)], 6, 'crafting', 'd'),
  R('processing-unit', 'Processing Unit', [p('advanced-circuit', 2), p('electronic-circuit', 20), p('sulfuric-acid', 5)], [p('processing-unit', 1)], 10, 'crafting', 'e'),
  R('low-density-structure', 'Low Density Structure', [p('steel-plate', 2), p('copper-plate', 20), p('plastic-bar', 5)], [p('low-density-structure', 1)], 20, 'crafting', 'j'),
  R('nuclear-reactor', 'Nuclear Reactor', [p('steel-plate', 400), p('advanced-circuit', 400), p('copper-plate', 400), p('stone-brick', 400)], [p('nuclear-reactor', 1)], 8, 'crafting', 'ad'),
  R('centrifuge', 'Centrifuge', [p('steel-plate', 50), p('advanced-circuit', 100), p('processing-unit', 100), p('stone-brick', 100)], [p('centrifuge', 1)], 4, 'crafting', 'ae'),
  R('rocket-fuel', 'Rocket Fuel', [p('solid-fuel', 10)], [p('rocket-fuel', 1)], 30, 'crafting', 'af'),
  R('rocket-parts', 'Rocket Parts', [p('steel-plate', 10), p('low-density-structure', 10), p('rocket-fuel', 10), p('electronic-circuit', 10)], [p('rocket-parts', 1)], 3, 'crafting', 'ag'),
  R('satellite', 'Satellite', [p('low-density-structure', 100), p('solar-panel', 100), p('accumulator', 100), p('radar', 5), p('processing-unit', 100), p('rocket-fuel', 50)], [p('satellite', 1)], 5, 'crafting', 'ah'),
  R('rocket-silo', 'Rocket Silo', [p('steel-plate', 1000), p('stone-brick', 1000), p('pipe', 100), p('processing-unit', 200)], [p('rocket-silo', 1)], 30, 'crafting', 'ai'),
  R('space-science-pack', 'Space Science Pack', [], [p('space-science-pack', 1000)], 0, 'crafting', 'aj'),
  // science
  R('automation-science-pack', 'Automation Science Pack', [p('copper-plate', 1), p('iron-gear-wheel', 1)], [p('automation-science-pack', 5)], 5, 'crafting', 'e'),
  R('logistic-science-pack', 'Logistic Science Pack', [p('inserter', 1), p('transport-belt', 1)], [p('logistic-science-pack', 5)], 6, 'crafting', 'f'),
  R('chemical-science-pack', 'Chemical Science Pack', [p('advanced-circuit', 3), p('engine-unit', 2), p('sulfuric-acid', 1)], [p('chemical-science-pack', 1)], 24, 'crafting', 'aa'),
  // belts / logistics
  R('transport-belt', 'Transport Belt', [p('iron-gear-wheel', 1), p('iron-plate', 1)], [p('transport-belt', 2)], 0.5, 'crafting', 'g'),
  R('fast-transport-belt', 'Fast Transport Belt', [p('iron-gear-wheel', 5), p('iron-plate', 1)], [p('fast-transport-belt', 1)], 0.5, 'crafting', 'g1'),
  R('express-transport-belt', 'Express Transport Belt', [p('iron-gear-wheel', 10), p('advanced-circuit', 2), p('steel-plate', 1)], [p('express-transport-belt', 1)], 0.5, 'crafting', 'g2'),
  R('underground-belt', 'Underground Belt', [p('iron-plate', 10), p('transport-belt', 5)], [p('underground-belt', 2)], 1, 'crafting', 'g3'),
  R('splitter', 'Splitter', [p('electronic-circuit', 5), p('iron-plate', 5), p('transport-belt', 4)], [p('splitter', 1)], 1, 'crafting', 'g4'),
  R('merger', 'Merger', [p('electronic-circuit', 5), p('iron-plate', 5), p('transport-belt', 4)], [p('merger', 1)], 1, 'crafting', 'g5'),
  R('belt-bridge', 'Belt Bridge', [p('iron-plate', 1), p('iron-stick', 2), p('iron-gear-wheel', 2)], [p('belt-bridge', 1)], 0.5, 'crafting', 'g6'),
  // inserters / chests / poles / furnaces / drills
  R('inserter', 'Inserter', [p('electronic-circuit', 1), p('iron-gear-wheel', 1), p('iron-plate', 1)], [p('inserter', 1)], 0.5, 'crafting', 'h'),
  R('long-handed-inserter', 'Long Handed Inserter', [p('iron-gear-wheel', 1), p('iron-plate', 1), p('inserter', 1)], [p('long-handed-inserter', 1)], 0.5, 'crafting', 'h1'),
  R('fast-inserter', 'Fast Inserter', [p('electronic-circuit', 2), p('iron-plate', 2), p('inserter', 1)], [p('fast-inserter', 1)], 0.5, 'crafting', 'h2'),
  R('stack-inserter', 'Stack Inserter', [p('advanced-circuit', 1), p('electronic-circuit', 15), p('iron-gear-wheel', 15), p('fast-inserter', 1)], [p('stack-inserter', 1)], 0.5, 'crafting', 'h3'),
  R('wooden-chest', 'Wooden Chest', [p('wood', 2)], [p('wooden-chest', 1)], 0.5, 'crafting', 'i'),
  R('iron-chest', 'Iron Chest', [p('iron-plate', 8)], [p('iron-chest', 1)], 0.5, 'crafting', 'i1'),
  R('steel-chest', 'Steel Chest', [p('steel-plate', 8)], [p('steel-chest', 1)], 0.5, 'crafting', 'i2'),
  R('small-electric-pole', 'Small Electric Pole', [p('wood', 2), p('copper-cable', 2)], [p('small-electric-pole', 2)], 0.5, 'crafting', 'j'),
  R('medium-electric-pole', 'Medium Electric Pole', [p('steel-plate', 2), p('copper-plate', 2)], [p('medium-electric-pole', 1)], 0.5, 'crafting', 'j1'),
  R('big-electric-pole', 'Big Electric Pole', [p('steel-plate', 5), p('copper-plate', 5)], [p('big-electric-pole', 1)], 0.5, 'crafting', 'j2'),
  R('stone-furnace', 'Stone Furnace', [p('iron-plate', 5)], [p('stone-furnace', 1)], 0.5, 'crafting', 'k'),
  R('steel-furnace', 'Steel Furnace', [p('steel-plate', 6), p('stone-brick', 10)], [p('steel-furnace', 1)], 3, 'crafting', 'k1'),
  R('burner-mining-drill', 'Burner Mining Drill', [p('iron-plate', 5)], [p('burner-mining-drill', 1)], 2, 'crafting', 'm'),
  R('electric-mining-drill', 'Electric Mining Drill', [p('electronic-circuit', 3), p('iron-gear-wheel', 5), p('iron-plate', 10)], [p('electric-mining-drill', 1)], 2, 'crafting', 'm1'),
  R('stone-wall', 'Stone Wall', [p('stone-brick', 5)], [p('stone-wall', 1)], 0.5, 'crafting', 'n'),
  R('firearm-magazine', 'Firearm Magazine', [p('iron-plate', 4)], [p('firearm-magazine', 1)], 1, 'crafting', 't'),
  R('water-pump', 'Water Pump', [p('iron-plate', 5), p('pipe', 5), p('electronic-circuit', 2)], [p('water-pump', 1)], 5, 'crafting', 'w'),
  // oil / chemistry
  {
    ...R('basic-oil-processing', 'Basic Oil Processing', [], [], 5, 'oil-processing', 'a', { customTextureId: 'oil_refinery' }),
    fluidInputs: [F('crude-oil', 50)],
    fluidOutputs: [F('petroleum-gas', 22.5), F('light-oil', 15), F('heavy-oil', 12.5)],
  },
  {
    ...R('advanced-oil-processing', 'Advanced Oil Processing', [], [], 5, 'oil-processing', 'c', { customTextureId: 'oil_refinery' }),
    fluidInputs: [F('crude-oil', 50), F('water', 25)],
    fluidOutputs: [F('petroleum-gas', 27.5), F('light-oil', 22.5), F('heavy-oil', 12.5)],
  },
  {
    ...R('light-oil-cracking', 'Light Oil Cracking', [], [], 5, 'chemistry', 'c', { customTextureId: 'chemical_plant' }),
    fluidInputs: [F('light-oil', 15), F('water', 15)],
    fluidOutputs: [F('petroleum-gas', 10)],
  },
  {
    ...R('heavy-oil-cracking', 'Heavy Oil Cracking', [], [], 5, 'chemistry', 'd', { customTextureId: 'chemical_plant' }),
    fluidInputs: [F('heavy-oil', 20), F('water', 15)],
    fluidOutputs: [F('light-oil', 15)],
  },
  {
    ...R('plastic-bar', 'Plastic Bar', [p('coal', 1)], [p('plastic-bar', 2)], 1, 'chemistry', 'e'),
    fluidInputs: [F('petroleum-gas', 10)],
  },
  {
    ...R('sulfur', 'Sulfur', [], [p('sulfur', 2)], 1, 'chemistry', 'f'),
    fluidInputs: [F('petroleum-gas', 15), F('water', 15)],
    fluidOutputs: [F('sulfuric-acid', 25)],
  },
  {
    ...R('sulfuric-acid', 'Sulfuric Acid', [p('sulfur', 5), p('iron-plate', 1)], [], 1, 'chemistry', 'g', { customTextureId: 'chemical_plant' }),
    fluidInputs: [F('water', 50)],
    fluidOutputs: [F('sulfuric-acid', 50)],
  },
  {
    ...R('lubricant', 'Lubricant', [], [], 1, 'chemistry', 'h', { customTextureId: 'chemical_plant' }),
    fluidInputs: [F('heavy-oil', 5)],
    fluidOutputs: [F('lubricant', 5)],
  },
  {
    ...R('solid-fuel', 'Solid Fuel', [p('coal', 1)], [p('solid-fuel', 1)], 2, 'chemistry', 'i'),
    fluidInputs: [F('petroleum-gas', 10)],
  },
  R('battery', 'Battery', [p('iron-plate', 1), p('copper-plate', 1), p('sulfuric-acid', 20)], [p('battery', 1)], 5, 'chemistry', 'i'),
  R('explosives', 'Explosives', [p('coal', 1), p('sulfur', 1), p('water', 1)], [p('explosives', 2)], 5, 'chemistry', 'j'),
  // nuclear
  R('uranium-processing', 'Uranium Processing', [p('uranium-ore', 10)], [p('uranium-235', 1), p('uranium-238', 9)], 12, 'centrifuging', 'ab'),
  R('nuclear-fuel', 'Nuclear Fuel', [p('uranium-235', 1), p('uranium-238', 19)], [p('nuclear-fuel', 1)], 60, 'centrifuging', 'ac'),
];

export const RECIPE_MAP: Map<string, Recipe> = new Map(RECIPES.map((r) => [r.id, r]));
