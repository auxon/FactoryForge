// Ported from TechTree.swift (TechnologyRegistry). 35 technologies.
// researchTime informational — ResearchSystem completes on pack counts.
import type { Technology } from './types';

function T(id: string, name: string, prerequisites: string[],
  cost: [string, number][], researchTime: number,
  recipes: string[], bonuses: { type: string; modifier: number }[] = [],
  order: string, tier: number, description = ''): Technology {
  return {
    id, name, description, prerequisites,
    cost: cost.map(([packId, count]) => ({ packId, count })),
    researchTime, unlocks: { recipes, bonuses }, order, tier,
  };
}
const A = 'automation-science-pack', L = 'logistic-science-pack', C = 'chemical-science-pack';

export const TECHNOLOGIES: Technology[] = [
  // tier 1
  T('automation', 'Automation', [], [[A, 10]], 10, ['assembling-machine-1'], [], 'a', 1),
  T('logistics', 'Logistics', [], [[A, 20]], 15, ['fast-inserter', 'long-handed-inserter'], [], 'b', 1),
  T('turrets', 'Turrets', [], [[A, 10]], 10, ['gun-turret'], [], 'c', 1),
  T('stone-walls', 'Stone Walls', [], [[A, 10]], 10, ['stone-wall'], [], 'd', 1),
  T('steel-processing', 'Steel Processing', [], [[A, 50]], 20, ['steel-plate'], [], 'e', 1),
  T('military', 'Military', [], [[A, 20]], 15, ['piercing-rounds-magazine'], [], 'f', 1),
  // tier 2
  T('logistic-science-pack', 'Logistic Science Pack', ['automation'], [[A, 75]], 30, ['logistic-science-pack'], [], 'a', 2),
  T('automation-2', 'Automation 2', ['automation', 'logistic-science-pack'], [[A, 40], [L, 40]], 30, ['assembling-machine-2'], [], 'b', 2),
  T('logistics-2', 'Logistics 2', ['logistics', 'logistic-science-pack'], [[A, 40], [L, 40]], 30, ['fast-transport-belt'], [], 'c', 2),
  T('advanced-material-processing', 'Advanced Material Processing', ['steel-processing'], [[A, 50], [L, 50]], 30, ['steel-furnace'], [], 'd', 2),
  T('solar-energy', 'Solar Energy', ['logistic-science-pack'], [[A, 100], [L, 100]], 60, ['solar-panel'], [], 'e', 2),
  T('electric-energy-accumulators', 'Electric Energy Accumulators', ['solar-energy'], [[A, 100], [L, 100]], 60, ['accumulator'], [], 'f', 2),
  T('laser-turrets', 'Laser Turrets', ['turrets', 'logistic-science-pack'], [[A, 150], [L, 150]], 60, ['laser-turret'], [], 'g', 2),
  T('mining-productivity-1', 'Mining Productivity 1', ['logistic-science-pack'], [[A, 100], [L, 100]], 60, [], [{ type: 'miningSpeed', modifier: 0.1 }], 'z-a', 2),
  T('research-speed-1', 'Research Speed 1', ['logistic-science-pack'], [[A, 100], [L, 100]], 60, [], [{ type: 'researchSpeed', modifier: 0.2 }], 'z-b', 2),
  T('advanced-electronics', 'Advanced Electronics', ['logistic-science-pack'], [[A, 75], [L, 75]], 45, ['advanced-circuit', 'processing-unit'], [], 'h', 2),
  // tier 3
  T('automation-3', 'Automation 3', ['automation-2', 'advanced-electronics'], [[A, 100], [L, 100], [C, 100]], 60, ['assembling-machine-3'], [], 'c', 3),
  T('advanced-logistics', 'Advanced Logistics', ['logistics-2'], [[A, 75], [L, 75]], 45, ['underground-belt', 'splitter', 'merger'], [], 'd', 3),
  T('oil-processing', 'Oil Processing', ['advanced-electronics'], [[A, 50], [L, 50], [C, 50]], 30, ['pumpjack', 'water-pump', 'basic-oil-processing'], [], 'a', 3),
  T('advanced-oil-processing', 'Advanced Oil Processing', ['oil-processing'], [[A, 50], [L, 50], [C, 50]], 30, ['oil-refinery', 'advanced-oil-processing'], [], 'b', 3),
  T('chemistry', 'Chemistry', ['advanced-oil-processing'], [[A, 100], [L, 100], [C, 100]], 30, ['chemical-plant', 'sulfur', 'plastic-bar', 'chemical-science-pack'], [], 'c', 3),
  T('sulfur-processing', 'Sulfur Processing', ['chemistry'], [[A, 100], [L, 100], [C, 100]], 30, ['sulfuric-acid'], [], 'd', 3),
  T('oil-cracking', 'Oil Cracking', ['chemistry'], [[A, 100], [L, 100], [C, 100]], 30, ['light-oil-cracking', 'heavy-oil-cracking'], [], 'e', 3),
  T('battery', 'Battery', ['sulfur-processing'], [[A, 100], [L, 100], [C, 100]], 30, ['battery'], [], 'f', 3),
  T('explosives', 'Explosives', ['sulfur-processing'], [[A, 100], [L, 100], [C, 100]], 30, ['explosives'], [], 'g', 3),
  T('lubricant', 'Lubricant', ['oil-cracking'], [[A, 100], [L, 100], [C, 100]], 30, ['lubricant'], [], 'h', 3),
  T('stack-inserter', 'Stack Inserter', ['advanced-electronics'], [[A, 150], [L, 150], [C, 150]], 30, ['stack-inserter'], [], 'i', 3),
  T('nuclear-processing', 'Nuclear Processing', ['chemistry'], [[A, 200], [L, 200], [C, 200]], 45, ['uranium-processing', 'nuclear-fuel'], [], 'j', 3),
  T('nuclear-power', 'Nuclear Power', ['nuclear-processing', 'automation-3'], [[A, 300], [L, 300], [C, 300]], 60, ['nuclear-reactor', 'centrifuge'], [], 'k', 3),
  T('rocket-fuel', 'Rocket Fuel', ['advanced-oil-processing'], [[A, 200], [L, 200], [C, 200]], 30, ['solid-fuel', 'rocket-fuel'], [], 'l', 3),
  T('low-density-structure', 'Low Density Structure', ['rocket-fuel'], [[A, 200], [L, 200], [C, 200]], 30, ['low-density-structure'], [], 'm', 3),
  T('rocket-parts', 'Rocket Parts', ['low-density-structure'], [[A, 300], [L, 300], [C, 300]], 45, ['rocket-parts'], [], 'n', 3),
  T('satellite', 'Satellite', ['rocket-parts', 'solar-energy'], [[A, 400], [L, 400], [C, 400]], 60, ['satellite'], [], 'o', 3),
  T('rocket-silo', 'Rocket Silo', ['satellite'], [[A, 500], [L, 500], [C, 500]], 90, ['rocket-silo'], [], 'p', 3),
  // tier 4
  T('space-science-pack', 'Space Science', ['rocket-silo'], [[A, 1000], [L, 1000], [C, 1000]], 120, ['space-science-pack'], [], 'q', 4),
];

export const TECH_MAP: Map<string, Technology> =
  new Map(TECHNOLOGIES.map((t) => [t.id, t]));
