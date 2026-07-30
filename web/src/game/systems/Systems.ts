import type { World } from '../../engine/ecs/World';
import type { Entity } from '../../engine/ecs/Entity';
import type { ChunkManager } from '../world/ChunkManager';
import type { BuildingRegistry, ItemRegistry, RecipeRegistry, TechnologyRegistry } from '../data/Registries';
import {
  type AssemblerComponent,
  type BeltComponent,
  type BoilerComponent,
  type Direction,
  type EnemyComponent,
  type FurnaceComponent,
  type GeneratorComponent,
  type HealthComponent,
  type InserterComponent,
  type InventoryComponent,
  type LabComponent,
  type MinerComponent,
  type PipeComponent,
  type PlayerComponent,
  type PositionComponent,
  type PowerConsumerComponent,
  type PowerPoleComponent,
  type ProjectileComponent,
  type RocketSiloComponent,
  type SolarPanelComponent,
  type AccumulatorComponent,
  type SteamEngineComponent,
  type TreeComponent,
  type TurretComponent,
  type UnitComponent,
  type UnitProductionComponent,
  type VelocityComponent,
  dirOffset,
  emptyInventory,
  inventoryAdd,
  inventoryCount,
  inventoryRemove,
  RenderLayer,
} from '../components';

export interface System {
  update(dt: number): void;
}

export class MiningSystem implements System {
  constructor(
    private world: World,
    private chunks: ChunkManager,
    private items: ItemRegistry,
    private buildings: BuildingRegistry,
  ) {}

  update(dt: number): void {
    this.world.forEach<MinerComponent>('miner', (miner, entity) => {
      const pos = this.world.getByName<PositionComponent>('position', entity)!;
      const inv = this.world.getByName<InventoryComponent>('inventory', entity);
      if (!inv) return;
      const def = this.buildings.get(miner.buildingId);
      const isBurner = miner.buildingId.includes('burner');
      if (isBurner) {
        const fuelOk =
          inventoryCount(inv, 'coal') > 0 ||
          inventoryCount(inv, 'wood') > 0 ||
          inventoryCount(inv, 'solid-fuel') > 0;
        if (!fuelOk) return;
      } else {
        const power = this.world.getByName<PowerConsumerComponent>('powerConsumer', entity);
        if (power && !power.powered) return;
      }

      const tile = this.chunks.getTile(pos.tileX, pos.tileY);
      if (!tile?.resource || tile.resource.type === 'crude-oil') return;

      miner.progress += miner.miningSpeed * (def?.miningSpeed ?? 1) * dt;
      if (miner.progress >= 1) {
        miner.progress = 0;
        const left = inventoryAdd(inv, tile.resource.type, 1, this.items.stackSize(tile.resource.type));
        if (left === 0) {
          tile.resource.amount -= 1;
          if (tile.resource.amount <= 0) tile.resource = null;
          if (isBurner && Math.random() < 0.05) {
            for (const fuel of ['coal', 'wood', 'solid-fuel']) {
              if (inventoryCount(inv, fuel) > 0) {
                inventoryRemove(inv, fuel, 1);
                break;
              }
            }
          }
          this.chunks.addPollution(pos.tileX, pos.tileY, 0.5);
        }
      }
    });
  }
}

export class BeltSystem implements System {
  constructor(private world: World) {}

  update(dt: number): void {
    this.world.forEach<BeltComponent>('belt', (belt) => {
      for (const item of belt.items) {
        item.progress += belt.speed * dt;
      }
      belt.items = belt.items.filter((i) => i.progress < 1.05);
    });

    // Transfer between adjacent belts
    this.world.forEach<BeltComponent>('belt', (belt, entity) => {
      const pos = this.world.getByName<PositionComponent>('position', entity)!;
      const [dx, dy] = dirOffset(belt.direction);
      const next = this.world.entityAt(pos.tileX + dx, pos.tileY + dy);
      if (!next) return;
      const nextBelt = this.world.getByName<BeltComponent>('belt', next);
      if (!nextBelt) return;
      const transferring = belt.items.filter((i) => i.progress >= 1);
      belt.items = belt.items.filter((i) => i.progress < 1);
      for (const item of transferring) {
        if (nextBelt.items.length < 4) {
          nextBelt.items.push({ itemId: item.itemId, progress: 0, lane: item.lane });
        } else {
          item.progress = 0.95;
          belt.items.push(item);
        }
      }
    });
  }

  tryInsert(entity: Entity, itemId: string): boolean {
    const belt = this.world.getByName<BeltComponent>('belt', entity);
    if (!belt || belt.items.length >= 4) return false;
    belt.items.push({ itemId, progress: 0.1, lane: 0 });
    return true;
  }

  tryExtract(entity: Entity): string | null {
    const belt = this.world.getByName<BeltComponent>('belt', entity);
    if (!belt || belt.items.length === 0) return null;
    const item = belt.items.shift()!;
    return item.itemId;
  }
}

export class InserterSystem implements System {
  constructor(
    private world: World,
    private belts: BeltSystem,
    private items: ItemRegistry,
  ) {}

  update(dt: number): void {
    this.world.forEach<InserterComponent>('inserter', (ins, entity) => {
      const power = this.world.getByName<PowerConsumerComponent>('powerConsumer', entity);
      if (power && !power.powered && !ins.buildingId.includes('burner')) return;
      const pos = this.world.getByName<PositionComponent>('position', entity)!;
      const [dx, dy] = dirOffset(ins.direction);
      const dropPos = { x: pos.tileX + dx * ins.reach, y: pos.tileY + dy * ins.reach };
      const pickPos = { x: pos.tileX - dx * ins.reach, y: pos.tileY - dy * ins.reach };

      if (!ins.heldItem) {
        ins.progress += ins.speed * dt;
        if (ins.progress < 1) return;
        ins.progress = 0;
        const src = this.world.entityAt(pickPos.x, pickPos.y);
        if (!src) return;
        const fromBelt = this.belts.tryExtract(src);
        if (fromBelt) {
          ins.heldItem = fromBelt;
          ins.heldCount = 1;
          return;
        }
        const inv = this.world.getByName<InventoryComponent>('inventory', src);
        if (!inv) return;
        for (const slot of inv.slots) {
          if (slot.itemId && slot.count > 0) {
            const take = Math.min(ins.stackSize, slot.count);
            ins.heldItem = slot.itemId;
            ins.heldCount = take;
            inventoryRemove(inv, slot.itemId, take);
            break;
          }
        }
      } else {
        ins.progress += ins.speed * dt;
        if (ins.progress < 1) return;
        ins.progress = 0;
        const dst = this.world.entityAt(dropPos.x, dropPos.y);
        if (!dst) return;
        if (this.world.hasByName('belt', dst)) {
          if (this.belts.tryInsert(dst, ins.heldItem)) {
            ins.heldCount--;
            if (ins.heldCount <= 0) ins.heldItem = null;
          }
          return;
        }
        const inv = this.world.getByName<InventoryComponent>('inventory', dst);
        if (!inv) return;
        const left = inventoryAdd(inv, ins.heldItem, ins.heldCount, this.items.stackSize(ins.heldItem));
        if (left < ins.heldCount) {
          ins.heldCount = left;
          if (left <= 0) ins.heldItem = null;
        }
      }
    });
  }
}

export class CraftingSystem implements System {
  constructor(
    private world: World,
    private recipes: RecipeRegistry,
    private items: ItemRegistry,
  ) {}

  update(dt: number): void {
    // Furnaces
    this.world.forEach<FurnaceComponent>('furnace', (furnace, entity) => {
      const inv = this.world.getByName<InventoryComponent>('inventory', entity);
      if (!inv) return;
      const power = this.world.getByName<PowerConsumerComponent>('powerConsumer', entity);
      const electric = furnace.buildingId.includes('electric');
      if (electric && power && !power.powered) return;

      if (!furnace.recipeId) {
        for (const slot of inv.slots) {
          if (!slot.itemId) continue;
          const recipe = this.recipes.forSmelting(slot.itemId);
          if (recipe) {
            furnace.recipeId = recipe.id;
            break;
          }
        }
      }
      const recipe = furnace.recipeId ? this.recipes.get(furnace.recipeId) : undefined;
      if (!recipe) return;

      if (!electric) {
        if (furnace.fuelRemaining <= 0) {
          for (const fuel of ['coal', 'wood', 'solid-fuel']) {
            if (inventoryRemove(inv, fuel, 1)) {
              furnace.fuelRemaining = this.items.fuelValue(fuel) / 1000;
              break;
            }
          }
        }
        if (furnace.fuelRemaining <= 0) return;
        furnace.fuelRemaining -= dt;
      }

      if (!recipe.inputs.every((i) => inventoryCount(inv, i.itemId) >= i.count)) {
        furnace.progress = 0;
        return;
      }
      furnace.progress += dt / recipe.craftTime;
      if (furnace.progress >= 1) {
        furnace.progress = 0;
        for (const i of recipe.inputs) inventoryRemove(inv, i.itemId, i.count);
        for (const o of recipe.outputs) inventoryAdd(inv, o.itemId, o.count, this.items.stackSize(o.itemId));
      }
    });

    // Assemblers
    this.world.forEach<AssemblerComponent>('assembler', (asm, entity) => {
      if (!asm.recipeId) return;
      const power = this.world.getByName<PowerConsumerComponent>('powerConsumer', entity);
      if (power && !power.powered) return;
      const inv = this.world.getByName<InventoryComponent>('inventory', entity);
      const recipe = this.recipes.get(asm.recipeId);
      if (!inv || !recipe) return;
      if (!recipe.inputs.every((i) => inventoryCount(inv, i.itemId) >= i.count)) {
        asm.progress = 0;
        return;
      }
      asm.progress += (asm.craftingSpeed * dt) / recipe.craftTime;
      if (asm.progress >= 1) {
        asm.progress = 0;
        for (const i of recipe.inputs) inventoryRemove(inv, i.itemId, i.count);
        for (const o of recipe.outputs) inventoryAdd(inv, o.itemId, o.count, this.items.stackSize(o.itemId));
      }
    });

    // Player hand crafting
    this.world.forEach<PlayerComponent>('player', (player, entity) => {
      const inv = this.world.getByName<InventoryComponent>('inventory', entity);
      if (!inv || player.craftQueue.length === 0) return;
      const job = player.craftQueue[0]!;
      const recipe = this.recipes.get(job.recipeId);
      if (!recipe) {
        player.craftQueue.shift();
        return;
      }
      if (!recipe.inputs.every((i) => inventoryCount(inv, i.itemId) >= i.count)) return;
      job.remaining -= dt;
      if (job.remaining <= 0) {
        for (const i of recipe.inputs) inventoryRemove(inv, i.itemId, i.count);
        for (const o of recipe.outputs) inventoryAdd(inv, o.itemId, o.count, this.items.stackSize(o.itemId));
        player.craftQueue.shift();
      }
    });
  }
}

export class PowerSystem implements System {
  networks: Array<{ poles: Entity[]; producers: number; consumers: number; satisfaction: number }> = [];

  constructor(private world: World) {}

  update(_dt: number): void {
    const poles = this.world.entries<PowerPoleComponent>('powerPole');
    const visited = new Set<number>();
    this.networks = [];

    for (const { entity } of poles) {
      if (visited.has(entity.id)) continue;
      const group: Entity[] = [];
      const queue = [entity];
      visited.add(entity.id);
      while (queue.length) {
        const cur = queue.shift()!;
        group.push(cur);
        const pos = this.world.getByName<PositionComponent>('position', cur)!;
        const pole = this.world.getByName<PowerPoleComponent>('powerPole', cur)!;
        for (const { entity: other } of poles) {
          if (visited.has(other.id)) continue;
          const op = this.world.getByName<PositionComponent>('position', other)!;
          const reach = Math.max(pole.wireReach, this.world.getByName<PowerPoleComponent>('powerPole', other)!.wireReach);
          if (Math.hypot(pos.tileX - op.tileX, pos.tileY - op.tileY) <= reach) {
            visited.add(other.id);
            queue.push(other);
          }
        }
      }

      let production = 0;
      let consumption = 0;
      const covered = new Set<number>();

      for (const poleE of group) {
        const pos = this.world.getByName<PositionComponent>('position', poleE)!;
        const pole = this.world.getByName<PowerPoleComponent>('powerPole', poleE)!;
        this.world.forEach<PositionComponent>('position', (p, e) => {
          if (Math.hypot(p.tileX - pos.tileX, p.tileY - pos.tileY) > pole.supplyRadius) return;
          covered.add(e.id);
        });
      }

      this.world.forEach<GeneratorComponent>('generator', (g, e) => {
        if (covered.has(e.id) && g.active) production += g.powerOutput;
      });
      this.world.forEach<SolarPanelComponent>('solar', (s, e) => {
        if (covered.has(e.id)) production += s.powerOutput * 0.7; // day average
      });
      this.world.forEach<SteamEngineComponent>('steamEngine', (s, e) => {
        if (covered.has(e.id)) production += s.powerOutput;
      });
      this.world.forEach<PowerConsumerComponent>('powerConsumer', (c, e) => {
        if (covered.has(e.id)) consumption += c.powerDraw;
      });

      // Accumulators charge/discharge
      let storedAvail = 0;
      this.world.forEach<AccumulatorComponent>('accumulator', (a, e) => {
        if (covered.has(e.id)) storedAvail += a.stored;
      });
      let satisfaction = consumption <= 0 ? 1 : Math.min(1, (production + storedAvail * 60) / consumption);
      const surplus = production - consumption * satisfaction;
      this.world.forEach<AccumulatorComponent>('accumulator', (a, e) => {
        if (!covered.has(e.id)) return;
        if (surplus > 0) a.stored = Math.min(a.capacity, a.stored + surplus * 0.01);
        else if (satisfaction < 1) a.stored = Math.max(0, a.stored - a.capacity * 0.002);
      });

      this.world.forEach<PowerConsumerComponent>('powerConsumer', (c, e) => {
        c.powered = covered.has(e.id) && satisfaction > 0.5;
      });

      this.networks.push({ poles: group, producers: production, consumers: consumption, satisfaction });
    }

    // Entities not near any pole
    if (poles.length === 0) {
      this.world.forEach<PowerConsumerComponent>('powerConsumer', (c) => {
        c.powered = false;
      });
    }
  }
}

export class FluidNetworkSystem implements System {
  constructor(
    private world: World,
    private buildings: BuildingRegistry,
    private items: ItemRegistry,
  ) {}

  update(dt: number): void {
    // Water pumps
    this.world.forEach<PipeComponent>('pipe', (pipe, entity) => {
      const building = this.world.getByName<{ buildingId: string }>('fluidProducer' as never, entity);
      void building;
    });

    this.world.forEach<{ buildingId: string; fluidId: string; rate: number }>('fluidProducer', (prod, entity) => {
      const pipe = this.world.getByName<PipeComponent>('pipe', entity);
      const pos = this.world.getByName<PositionComponent>('position', entity);
      if (!pos) return;
      if (prod.buildingId === 'water-pump' || prod.fluidId === 'water') {
        // Must be near water - simplified: always produce if labeled water-pump
        const target = pipe ?? this.findNearbyPipe(pos.tileX, pos.tileY);
        if (target) {
          target.fluidId = 'water';
          target.amount = Math.min(target.capacity, target.amount + prod.rate * dt);
        }
      }
      if (prod.fluidId === 'crude-oil') {
        // pumpjack
      }
    });

    // Equalize adjacent pipes
    const pipes = this.world.entries<PipeComponent>('pipe');
    for (const { entity, component: a } of pipes) {
      const pos = this.world.getByName<PositionComponent>('position', entity)!;
      for (const [dx, dy] of [
        [1, 0],
        [0, 1],
      ] as const) {
        const otherE = this.world.entityAt(pos.tileX + dx, pos.tileY + dy);
        if (!otherE) continue;
        const b = this.world.getByName<PipeComponent>('pipe', otherE);
        if (!b) continue;
        if (a.fluidId && b.fluidId && a.fluidId !== b.fluidId) continue;
        const fluid = a.fluidId ?? b.fluidId;
        if (!fluid) continue;
        a.fluidId = fluid;
        b.fluidId = fluid;
        const total = a.amount + b.amount;
        const avg = total / 2;
        a.amount = avg;
        b.amount = avg;
      }
    }

    // Boilers: water + fuel -> steam into connected pipes (stored as fluid steam via petroleum workaround: use light-oil id? use 'steam' as fluid id)
    this.world.forEach<BoilerComponent>('boiler', (boiler, entity) => {
      const inv = this.world.getByName<InventoryComponent>('inventory', entity);
      const pos = this.world.getByName<PositionComponent>('position', entity)!;
      if (!inv) return;
      if (boiler.fuelRemaining <= 0) {
        for (const fuel of ['coal', 'wood', 'solid-fuel']) {
          if (inventoryRemove(inv, fuel, 1)) {
            boiler.fuelRemaining = this.items.fuelValue(fuel) / 500;
            break;
          }
        }
      }
      if (boiler.fuelRemaining <= 0) return;
      const waterPipe = this.findNearbyPipe(pos.tileX, pos.tileY, 'water');
      if (!waterPipe || waterPipe.amount < 1) return;
      boiler.fuelRemaining -= dt;
      waterPipe.amount -= 0.5 * dt;
      const steamPipe = this.findNearbyPipe(pos.tileX + 1, pos.tileY) ?? this.findNearbyPipe(pos.tileX, pos.tileY + 1);
      if (steamPipe) {
        steamPipe.fluidId = 'steam';
        steamPipe.amount = Math.min(steamPipe.capacity, steamPipe.amount + 2 * dt);
      }
      boiler.temperature = 165;
    });

    // Steam engines
    this.world.forEach<SteamEngineComponent>('steamEngine', (engine, entity) => {
      const pos = this.world.getByName<PositionComponent>('position', entity)!;
      const steam = this.findNearbyPipe(pos.tileX, pos.tileY, 'steam');
      const gen = this.world.getByName<GeneratorComponent>('generator', entity);
      if (steam && steam.amount > 0.5) {
        steam.amount -= 1 * dt;
        engine.powerOutput = 900;
        if (gen) {
          gen.powerOutput = 900;
          gen.active = true;
        }
      } else {
        engine.powerOutput = 0;
        if (gen) gen.active = false;
      }
    });

    // Pumpjacks on oil
    this.world.forEach<{ buildingId: string }>('pumpjack', (pj, entity) => {
      void pj;
      const pos = this.world.getByName<PositionComponent>('position', entity)!;
      // handled via fluidProducer
      const pipe = this.findNearbyPipe(pos.tileX, pos.tileY);
      if (pipe) {
        pipe.fluidId = 'crude-oil';
        pipe.amount = Math.min(pipe.capacity, pipe.amount + 2 * dt);
      }
    });

    void this.buildings;
  }

  private findNearbyPipe(x: number, y: number, fluid?: string): PipeComponent | null {
    for (const [dx, dy] of [
      [0, 0],
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ] as const) {
      const e = this.world.entityAt(x + dx, y + dy);
      if (!e) continue;
      const p = this.world.getByName<PipeComponent>('pipe', e);
      if (!p) continue;
      if (fluid && p.fluidId && p.fluidId !== fluid) continue;
      return p;
    }
    return null;
  }
}

export class ResearchSystem implements System {
  currentResearchId: string | null = null;
  progress = new Map<string, number>();
  completed = new Set<string>();
  unlockedRecipes = new Set<string>([
    'iron-plate',
    'copper-plate',
    'iron-gear-wheel',
    'copper-cable',
    'electronic-circuit',
    'transport-belt',
    'inserter',
    'burner-mining-drill',
    'stone-furnace',
    'wooden-chest',
    'small-electric-pole',
    'pipe',
    'boiler',
    'steam-engine',
    'automation-science-pack',
    'firearm-magazine',
    'lab',
  ]);

  constructor(
    private world: World,
    private techs: TechnologyRegistry,
  ) {}

  update(dt: number): void {
    if (!this.currentResearchId) return;
    const tech = this.techs.get(this.currentResearchId);
    if (!tech) return;

    let labsWorking = 0;
    this.world.forEach<LabComponent>('lab', (lab, entity) => {
      const power = this.world.getByName<PowerConsumerComponent>('powerConsumer', entity);
      if (power && !power.powered) return;
      const inv = this.world.getByName<InventoryComponent>('inventory', entity);
      if (!inv) return;
      const hasPacks = tech.cost.every((c) => inventoryCount(inv, c.itemId) >= 1);
      if (!hasPacks) return;
      labsWorking++;
      lab.progress += dt;
      if (lab.progress >= 1) {
        lab.progress = 0;
        for (const c of tech.cost) inventoryRemove(inv, c.itemId, 1);
      }
    });

    if (labsWorking <= 0) return;
    const cur = this.progress.get(tech.id) ?? 0;
    const next = cur + (dt * labsWorking) / tech.researchTime;
    this.progress.set(tech.id, next);
    if (next >= tech.cost.reduce((n, c) => n + c.count, 0) || next >= 1) {
      // Complete when progress reaches 1 (normalized)
      if (next >= 1) {
        this.completed.add(tech.id);
        for (const r of tech.unlocks.recipes ?? []) this.unlockedRecipes.add(r);
        this.currentResearchId = null;
        this.progress.set(tech.id, 1);
      }
    }
  }

  startResearch(id: string): boolean {
    const tech = this.techs.get(id);
    if (!tech || this.completed.has(id)) return false;
    for (const pre of tech.prerequisites ?? []) {
      if (!this.completed.has(pre)) return false;
    }
    this.currentResearchId = id;
    return true;
  }

  serialize() {
    return {
      currentResearchId: this.currentResearchId,
      progress: Object.fromEntries(this.progress),
      completed: [...this.completed],
      unlockedRecipes: [...this.unlockedRecipes],
    };
  }

  load(data: {
    currentResearchId: string | null;
    progress: Record<string, number>;
    completed: string[];
    unlockedRecipes: string[];
  }): void {
    this.currentResearchId = data.currentResearchId;
    this.progress = new Map(Object.entries(data.progress ?? {}));
    this.completed = new Set(data.completed ?? []);
    this.unlockedRecipes = new Set(data.unlockedRecipes ?? this.unlockedRecipes);
  }
}

export class PollutionSystem implements System {
  constructor(
    private world: World,
    private chunks: ChunkManager,
  ) {}

  update(dt: number): void {
    this.world.forEach<MinerComponent>('miner', (_m, e) => {
      const pos = this.world.getByName<PositionComponent>('position', e)!;
      this.chunks.addPollution(pos.tileX, pos.tileY, 0.2 * dt);
    });
    this.world.forEach<FurnaceComponent>('furnace', (_f, e) => {
      const pos = this.world.getByName<PositionComponent>('position', e)!;
      this.chunks.addPollution(pos.tileX, pos.tileY, 0.3 * dt);
    });
    for (const chunk of this.chunks.loadedChunks()) {
      chunk.pollution = Math.max(0, chunk.pollution - 0.05 * dt);
    }
  }
}

export class EnemyAISystem implements System {
  spawnTimer = 0;

  constructor(
    private world: World,
    private chunks: ChunkManager,
    private getPlayerPos: () => { x: number; y: number } | null,
  ) {}

  update(dt: number): void {
    const playerPos = this.getPlayerPos();
    if (!playerPos) return;

    this.spawnTimer += dt;
    if (this.spawnTimer > 15) {
      this.spawnTimer = 0;
      let pollution = 0;
      for (const c of this.chunks.loadedChunks()) pollution += c.pollution;
      if (pollution > 20) {
        const angle = Math.random() * Math.PI * 2;
        const dist = 40 + Math.random() * 20;
        const x = Math.floor(playerPos.x + Math.cos(angle) * dist);
        const y = Math.floor(playerPos.y + Math.sin(angle) * dist);
        this.spawnBiter(x, y);
      }
      for (const chunk of this.chunks.loadedChunks()) {
        for (const [sx, sy] of chunk.spawnerPositions) {
          if (Math.hypot(sx - playerPos.x, sy - playerPos.y) < 60 && Math.random() < 0.1) {
            this.spawnBiter(sx + 1, sy + 1);
          }
        }
      }
    }

    this.world.forEach<EnemyComponent>('enemy', (enemy, entity) => {
      const pos = this.world.getByName<PositionComponent>('position', entity)!;
      const dx = playerPos.x - (pos.tileX + pos.offsetX);
      const dy = playerPos.y - (pos.tileY + pos.offsetY);
      const dist = Math.hypot(dx, dy);
      if (dist < enemy.aggroRange) {
        const nx = dx / (dist || 1);
        const ny = dy / (dist || 1);
        pos.offsetX += nx * enemy.speed * dt;
        pos.offsetY += ny * enemy.speed * dt;
        if (pos.offsetX >= 1) {
          pos.tileX++;
          pos.offsetX -= 1;
        }
        if (pos.offsetX < 0) {
          pos.tileX--;
          pos.offsetX += 1;
        }
        if (pos.offsetY >= 1) {
          pos.tileY++;
          pos.offsetY -= 1;
        }
        if (pos.offsetY < 0) {
          pos.tileY--;
          pos.offsetY += 1;
        }
        this.world.updatePosition(entity, pos.tileX, pos.tileY, pos.offsetX, pos.offsetY);
      }
      enemy.attackTimer -= dt;
      if (dist < 1.2 && enemy.attackTimer <= 0) {
        enemy.attackTimer = enemy.attackCooldown;
        // damage nearest player
        this.world.forEach<PlayerComponent>('player', (_p, pe) => {
          const hp = this.world.getByName<HealthComponent>('health', pe);
          if (hp) hp.current = Math.max(0, hp.current - enemy.damage);
        });
      }
    });
  }

  spawnBiter(x: number, y: number): void {
    this.world
      .spawnWith()
      .with('position', { tileX: x, tileY: y, offsetX: 0.5, offsetY: 0.5 })
      .with('sprite', {
        textureId: 'biter_0',
        width: 1,
        height: 1,
        layer: RenderLayer.Enemy,
        color: '#d32f2f',
      })
      .with('health', { current: 30, max: 30 })
      .with('enemy', {
        kind: 'biter',
        damage: 8,
        speed: 2.5,
        aggroRange: 25,
        attackCooldown: 1,
        attackTimer: 0,
      })
      .build();
  }
}

export class CombatSystem implements System {
  constructor(private world: World) {}

  update(dt: number): void {
    // Turrets
    this.world.forEach<TurretComponent>('turret', (turret, entity) => {
      turret.fireTimer -= dt;
      const pos = this.world.getByName<PositionComponent>('position', entity)!;
      const power = this.world.getByName<PowerConsumerComponent>('powerConsumer', entity);
      if (!turret.usesAmmo && power && !power.powered) return;
      if (turret.usesAmmo) {
        const inv = this.world.getByName<InventoryComponent>('inventory', entity);
        if (!inv || inventoryCount(inv, 'firearm-magazine') + inventoryCount(inv, 'piercing-rounds-magazine') <= 0)
          return;
      }
      if (turret.fireTimer > 0) return;

      let best: Entity | null = null;
      let bestDist = turret.range;
      this.world.forEach<EnemyComponent>('enemy', (_e, ee) => {
        const ep = this.world.getByName<PositionComponent>('position', ee)!;
        const d = Math.hypot(ep.tileX - pos.tileX, ep.tileY - pos.tileY);
        if (d < bestDist) {
          bestDist = d;
          best = ee;
        }
      });
      if (!best) return;
      turret.fireTimer = turret.cooldown;
      if (turret.usesAmmo) {
        const inv = this.world.getByName<InventoryComponent>('inventory', entity)!;
        if (!inventoryRemove(inv, 'firearm-magazine', 1)) inventoryRemove(inv, 'piercing-rounds-magazine', 1);
      }
      const hp = this.world.getByName<HealthComponent>('health', best);
      if (hp) {
        hp.current -= turret.damage;
        if (hp.current <= 0) this.world.despawnDeferred(best);
      }
    });

    // Projectiles
    this.world.forEach<ProjectileComponent>('projectile', (proj, entity) => {
      proj.ttl -= dt;
      const vel = this.world.getByName<VelocityComponent>('velocity', entity);
      const pos = this.world.getByName<PositionComponent>('position', entity);
      if (!pos || !vel) return;
      pos.offsetX += vel.vx * dt;
      pos.offsetY += vel.vy * dt;
      this.world.updatePosition(entity, pos.tileX, pos.tileY, pos.offsetX, pos.offsetY);
      this.world.forEach<EnemyComponent>('enemy', (_e, ee) => {
        const ep = this.world.getByName<PositionComponent>('position', ee)!;
        if (Math.hypot(ep.tileX + ep.offsetX - (pos.tileX + pos.offsetX), ep.tileY + ep.offsetY - (pos.tileY + pos.offsetY)) < 0.6) {
          const hp = this.world.getByName<HealthComponent>('health', ee);
          if (hp) {
            hp.current -= proj.damage;
            if (hp.current <= 0) this.world.despawnDeferred(ee);
          }
          proj.ttl = 0;
        }
      });
      if (proj.ttl <= 0) this.world.despawnDeferred(entity);
    });
  }

  playerShoot(from: Entity, targetX: number, targetY: number, ownerId: number): void {
    const inv = this.world.getByName<InventoryComponent>('inventory', from);
    const pos = this.world.getByName<PositionComponent>('position', from);
    if (!inv || !pos) return;
    if (!inventoryRemove(inv, 'firearm-magazine', 1) && !inventoryRemove(inv, 'piercing-rounds-magazine', 1)) return;
    const dx = targetX - (pos.tileX + pos.offsetX);
    const dy = targetY - (pos.tileY + pos.offsetY);
    const len = Math.hypot(dx, dy) || 1;
    this.world
      .spawnWith()
      .with('position', { tileX: pos.tileX, tileY: pos.tileY, offsetX: pos.offsetX, offsetY: pos.offsetY })
      .with('sprite', { textureId: 'default', width: 0.25, height: 0.25, layer: RenderLayer.Projectile, color: '#ffeb3b' })
      .with('velocity', { vx: (dx / len) * 18, vy: (dy / len) * 18 })
      .with('projectile', { damage: 12, ownerId, ttl: 1.2 })
      .build();
  }
}

export class UnitSystem implements System {
  constructor(private world: World) {}

  update(dt: number): void {
    this.world.forEach<UnitComponent>('unit', (unit, entity) => {
      const pos = this.world.getByName<PositionComponent>('position', entity)!;
      if (unit.command === 'move' && unit.targetX !== undefined && unit.targetY !== undefined) {
        const dx = unit.targetX - (pos.tileX + pos.offsetX);
        const dy = unit.targetY - (pos.tileY + pos.offsetY);
        const dist = Math.hypot(dx, dy);
        if (dist < 0.2) {
          unit.command = 'hold';
          return;
        }
        pos.offsetX += (dx / dist) * unit.speed * dt;
        pos.offsetY += (dy / dist) * unit.speed * dt;
        this.normalizePos(entity, pos);
      }
      if (unit.command === 'attack') {
        let tx = unit.targetX;
        let ty = unit.targetY;
        if (unit.targetEntity && this.world.isAlive(unit.targetEntity)) {
          const tp = this.world.getByName<PositionComponent>('position', unit.targetEntity);
          if (tp) {
            tx = tp.tileX + tp.offsetX;
            ty = tp.tileY + tp.offsetY;
          }
        }
        if (tx === undefined || ty === undefined) return;
        const dx = tx - (pos.tileX + pos.offsetX);
        const dy = ty - (pos.tileY + pos.offsetY);
        const dist = Math.hypot(dx, dy);
        if (dist > unit.range) {
          pos.offsetX += (dx / dist) * unit.speed * dt;
          pos.offsetY += (dy / dist) * unit.speed * dt;
          this.normalizePos(entity, pos);
        } else if (unit.targetEntity) {
          const hp = this.world.getByName<HealthComponent>('health', unit.targetEntity);
          if (hp) {
            hp.current -= unit.damage * dt;
            if (hp.current <= 0) this.world.despawnDeferred(unit.targetEntity);
          }
        }
      }
    });

    this.world.forEach<UnitProductionComponent>('unitProduction', (prod, entity) => {
      if (prod.queue.length === 0) return;
      const power = this.world.getByName<PowerConsumerComponent>('powerConsumer', entity);
      if (power && !power.powered) return;
      prod.progress += dt / 5;
      if (prod.progress >= 1) {
        prod.progress = 0;
        const type = prod.queue.shift()!;
        const pos = this.world.getByName<PositionComponent>('position', entity)!;
        const owner = this.world.getByName<{ playerId: number }>('ownership', entity);
        this.world
          .spawnWith()
          .with('position', { tileX: pos.tileX + 2, tileY: pos.tileY + 2, offsetX: 0.5, offsetY: 0.5 })
          .with('sprite', { textureId: 'unit', width: 1, height: 1, layer: RenderLayer.Entity, color: '#1976d2' })
          .with('health', { current: 50, max: 50 })
          .with('unit', {
            unitType: type,
            ownerId: owner?.playerId ?? 1,
            command: 'idle',
            speed: 3,
            damage: 10,
            range: 1.5,
          })
          .with('ownership', { playerId: owner?.playerId ?? 1 })
          .build();
      }
    });
  }

  private normalizePos(entity: Entity, pos: PositionComponent): void {
    while (pos.offsetX >= 1) {
      pos.tileX++;
      pos.offsetX -= 1;
    }
    while (pos.offsetX < 0) {
      pos.tileX--;
      pos.offsetX += 1;
    }
    while (pos.offsetY >= 1) {
      pos.tileY++;
      pos.offsetY -= 1;
    }
    while (pos.offsetY < 0) {
      pos.tileY--;
      pos.offsetY += 1;
    }
    this.world.updatePosition(entity, pos.tileX, pos.tileY, pos.offsetX, pos.offsetY);
  }
}

export class RocketSystem implements System {
  victory = false;

  constructor(private world: World) {}

  update(dt: number): void {
    this.world.forEach<RocketSiloComponent>('rocketSilo', (silo, entity) => {
      const power = this.world.getByName<PowerConsumerComponent>('powerConsumer', entity);
      if (power && !power.powered) return;
      const inv = this.world.getByName<InventoryComponent>('inventory', entity);
      if (!inv) return;

      if (silo.parts < silo.partsRequired) {
        if (inventoryRemove(inv, 'rocket-parts', 1)) silo.parts++;
      }
      if (!silo.hasSatellite && inventoryCount(inv, 'satellite') > 0) {
        inventoryRemove(inv, 'satellite', 1);
        silo.hasSatellite = true;
      }
      if (silo.parts >= silo.partsRequired && silo.hasSatellite && !silo.launching) {
        silo.launching = true;
      }
      if (silo.launching) {
        silo.launchProgress += dt / 10;
        if (silo.launchProgress >= 1) {
          silo.launching = false;
          silo.launchProgress = 0;
          silo.parts = 0;
          silo.hasSatellite = false;
          inventoryAdd(inv, 'space-science-pack', 1000);
          this.victory = true;
        }
      }
    });
  }
}

export class EntityCleanupSystem implements System {
  constructor(private world: World) {}

  update(_dt: number): void {
    this.world.forEach<HealthComponent>('health', (hp, entity) => {
      if (hp.current <= 0) this.world.despawnDeferred(entity);
    });
    this.world.processPending();
  }
}

export class AutoPlaySystem implements System {
  active = false;
  scenarioId: string | null = null;
  stepIndex = 0;
  waitTimer = 0;
  private scenarios: Record<string, Array<{ type: string; [k: string]: unknown }>> = {
    basic_mining: [
      { type: 'setGameSpeed', speed: 2 },
      { type: 'placeBuilding', buildingId: 'burner-mining-drill', x: 2, y: 0 },
      { type: 'wait', seconds: 5 },
    ],
    smelting_setup: [
      { type: 'placeBuilding', buildingId: 'stone-furnace', x: 4, y: 0 },
      { type: 'wait', seconds: 3 },
    ],
    production_line: [
      { type: 'placeBuilding', buildingId: 'transport-belt', x: 1, y: 1, direction: 1 },
      { type: 'placeBuilding', buildingId: 'transport-belt', x: 2, y: 1, direction: 1 },
      { type: 'placeBuilding', buildingId: 'inserter', x: 2, y: 0, direction: 2 },
      { type: 'wait', seconds: 5 },
    ],
  };

  constructor(
    private placeBuilding: (id: string, x: number, y: number, dir: Direction) => boolean,
    private setSpeed: (s: number) => void,
  ) {}

  start(scenarioId: string): void {
    this.scenarioId = scenarioId;
    this.stepIndex = 0;
    this.active = true;
    this.waitTimer = 0;
  }

  stop(): void {
    this.active = false;
  }

  listScenarios(): string[] {
    return Object.keys(this.scenarios);
  }

  update(dt: number): void {
    if (!this.active || !this.scenarioId) return;
    const steps = this.scenarios[this.scenarioId];
    if (!steps || this.stepIndex >= steps.length) {
      this.active = false;
      return;
    }
    const step = steps[this.stepIndex]!;
    if (step.type === 'wait') {
      this.waitTimer += dt;
      if (this.waitTimer >= (step.seconds as number)) {
        this.waitTimer = 0;
        this.stepIndex++;
      }
      return;
    }
    if (step.type === 'setGameSpeed') this.setSpeed(step.speed as number);
    if (step.type === 'placeBuilding') {
      this.placeBuilding(step.buildingId as string, step.x as number, step.y as number, (step.direction as Direction) ?? 1);
    }
    this.stepIndex++;
  }
}

export function chopTree(world: World, entity: Entity, playerInv: InventoryComponent, items: ItemRegistry): boolean {
  const tree = world.getByName<TreeComponent>('tree', entity);
  if (!tree) return false;
  tree.woodRemaining -= 1;
  inventoryAdd(playerInv, 'wood', 1, items.stackSize('wood'));
  if (tree.woodRemaining <= 0) world.despawn(entity);
  return true;
}

export { emptyInventory };
