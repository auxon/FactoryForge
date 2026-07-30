import { World } from '../ecs/World';
import { gameTime } from './Time';
import { ChunkManager } from '../../game/world/ChunkManager';
import {
  BuildingRegistry,
  ItemRegistry,
  RecipeRegistry,
  TechnologyRegistry,
} from '../../game/data/Registries';
import { PlayerManager } from '../../game/player/PlayerManager';
import {
  AutoPlaySystem,
  BeltSystem,
  CombatSystem,
  CraftingSystem,
  EnemyAISystem,
  EntityCleanupSystem,
  FluidNetworkSystem,
  InserterSystem,
  MiningSystem,
  PollutionSystem,
  PowerSystem,
  ResearchSystem,
  RocketSystem,
  UnitSystem,
  chopTree,
} from '../../game/systems/Systems';
import { AIPlayerSystem } from '../../game/ai/AIPlayerSystem';
import {
  FogOfWarSystem,
  LobbySystem,
  SpawnSystem,
  VictorySystem,
  type MatchConfig,
  type MatchMode,
} from '../../game/multiplayer/LobbyAndVictory';
import {
  RenderLayer,
  emptyInventory,
  inventoryAdd,
  inventoryCount,
  inventoryRemove,
  createSpriteAnimation,
  updateSpriteAnimation,
  type Direction,
  type HealthComponent,
  type InventoryComponent,
  type PlayerComponent,
  type PositionComponent,
  type SpriteComponent,
  type UnitComponent,
} from '../../game/components';
import { playerFrames } from '../render/AssetCatalog';
import type { GameSave } from '@shared/save/types';
import type { BuildingDef } from '../../game/data/Registries';

export class GameLoop {
  world = new World();
  itemRegistry = new ItemRegistry();
  recipeRegistry = new RecipeRegistry();
  buildingRegistry = new BuildingRegistry();
  technologyRegistry = new TechnologyRegistry();
  chunkManager: ChunkManager;
  playerManager: PlayerManager;
  localPlayerId = 0;
  worldSeed: number;
  playTime = 0;
  gameSpeed = 1;
  isRunning = true;
  isHeadless = false;
  isPlayerDead = false;
  matchMode: MatchMode = 'singlePlayer';

  beltSystem: BeltSystem;
  researchSystem: ResearchSystem;
  powerSystem: PowerSystem;
  fluidSystem: FluidNetworkSystem;
  combatSystem: CombatSystem;
  rocketSystem: RocketSystem;
  autoPlaySystem: AutoPlaySystem;
  aiPlayerSystem: AIPlayerSystem;
  lobby = new LobbySystem();
  victory = new VictorySystem();
  fog = new FogOfWarSystem();
  spawnSystem = new SpawnSystem();

  private systems: Array<{ update(dt: number): void }> = [];
  private treeSpawned = new Set<string>();
  selectedEntities: number[] = [];
  onVictory: ((reason: string) => void) | null = null;
  onDeath: (() => void) | null = null;

  constructor(seed?: number, headless = false) {
    this.isHeadless = headless;
    this.worldSeed = seed ?? Math.floor(Math.random() * 1e9);
    this.chunkManager = new ChunkManager(this.worldSeed);
    this.playerManager = new PlayerManager(this.world, this.itemRegistry);
    this.localPlayerId = this.playerManager.createPlayer('Player', false, 0, 0);

    this.beltSystem = new BeltSystem(this.world);
    const mining = new MiningSystem(this.world, this.chunkManager, this.itemRegistry, this.buildingRegistry);
    const inserter = new InserterSystem(this.world, this.beltSystem, this.itemRegistry);
    const crafting = new CraftingSystem(this.world, this.recipeRegistry, this.itemRegistry);
    this.powerSystem = new PowerSystem(this.world);
    this.fluidSystem = new FluidNetworkSystem(this.world, this.buildingRegistry, this.itemRegistry);
    this.researchSystem = new ResearchSystem(this.world, this.technologyRegistry);
    const pollution = new PollutionSystem(this.world, this.chunkManager);
    const enemy = new EnemyAISystem(this.world, this.chunkManager, () => {
      const p = this.playerManager.getPlayer(this.localPlayerId);
      if (!p) return null;
      const pos = this.world.getByName<PositionComponent>('position', p.entity);
      return pos ? { x: pos.tileX + pos.offsetX, y: pos.tileY + pos.offsetY } : null;
    });
    this.combatSystem = new CombatSystem(this.world);
    const units = new UnitSystem(this.world);
    this.rocketSystem = new RocketSystem(this.world);
    const cleanup = new EntityCleanupSystem(this.world);
    this.autoPlaySystem = new AutoPlaySystem(
      (id, x, y, dir) => this.placeBuilding(id, x, y, dir, this.localPlayerId),
      (s) => {
        this.gameSpeed = s;
      },
    );
    this.aiPlayerSystem = new AIPlayerSystem(this.world, this.playerManager, (pid, id, x, y, dir) =>
      this.placeBuilding(id, x, y, dir, pid),
    );

    this.systems = [
      mining,
      this.beltSystem,
      this.fluidSystem,
      inserter,
      crafting,
      this.powerSystem,
      this.researchSystem,
      pollution,
      enemy,
      this.aiPlayerSystem,
      this.combatSystem,
      units,
      this.rocketSystem,
      cleanup,
      this.autoPlaySystem,
    ];

    this.chunkManager.updateAround(0, 0);
    this.spawnTreesAround(0, 0);
  }

  get localPlayer() {
    return this.playerManager.getPlayer(this.localPlayerId);
  }

  setGameSpeed(speed: number): void {
    this.gameSpeed = speed;
    gameTime.timeScale = speed === 0 ? 0 : 1;
  }

  togglePause(): void {
    if (this.gameSpeed === 0) this.setGameSpeed(1);
    else this.setGameSpeed(0);
  }

  fixedUpdate(): void {
    if (this.isPlayerDead) return;
    const dt = gameTime.fixedDeltaTime * (this.gameSpeed || 1);
    if (this.gameSpeed === 0) return;
    this.playTime += dt;

    const player = this.localPlayer;
    if (player) {
      const pc = this.world.getByName<PlayerComponent>('player', player.entity)!;
      const pos = this.world.getByName<PositionComponent>('position', player.entity)!;
      const speed = 5;
      pos.offsetX += pc.moveX * speed * dt;
      pos.offsetY += pc.moveY * speed * dt;
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
      this.world.updatePosition(player.entity, pos.tileX, pos.tileY, pos.offsetX, pos.offsetY);
      this.updatePlayerAnimation(player.entity, pc, dt);
      this.chunkManager.updateAround(pos.tileX, pos.tileY);
      this.spawnTreesAround(pos.tileX, pos.tileY);

      const hp = this.world.getByName<HealthComponent>('health', player.entity);
      if (hp && hp.current <= 0) {
        this.isPlayerDead = true;
        this.onDeath?.();
      }
    }

    for (const s of this.systems) s.update(dt);

    const positions = this.playerManager.all.map((p) => {
      const pos = this.world.getByName<PositionComponent>('position', p.entity)!;
      return { x: pos.tileX + pos.offsetX, y: pos.tileY + pos.offsetY };
    });
    this.fog.update(positions);

    this.victory.check(
      this.matchMode,
      this.playerManager.all.map((p) => {
        const hp = this.world.getByName<HealthComponent>('health', p.entity);
        return { playerId: p.playerId, alive: (hp?.current ?? 0) > 0, team: p.playerId % 2 };
      }),
      this.rocketSystem.victory,
      this.localPlayerId,
    );
    if (this.victory.winnerId !== null && this.victory.reason) {
      this.onVictory?.(this.victory.reason);
      this.rocketSystem.victory = false;
    }
  }

  frame(moveX: number, moveY: number): void {
    if (this.isHeadless) gameTime.updateDeterministic();
    else gameTime.update();

    const player = this.localPlayer;
    if (player) {
      const pc = this.world.getByName<PlayerComponent>('player', player.entity);
      if (pc && !pc.isAI) {
        pc.moveX = moveX;
        pc.moveY = moveY;
      }
    }

    let steps = 0;
    while (gameTime.consumeFixedUpdate() && steps < 5) {
      this.fixedUpdate();
      steps++;
    }
  }

  private updatePlayerAnimation(entity: import('../ecs/Entity').Entity, pc: PlayerComponent, dt: number): void {
    const sprite = this.world.getByName<SpriteComponent>('sprite', entity);
    if (!sprite) return;
    if (!sprite.animation) {
      sprite.animation = createSpriteAnimation(playerFrames('down'), 0.08, true);
    }

    const moving = Math.abs(pc.moveX) > 0.01 || Math.abs(pc.moveY) > 0.01;
    let facing = pc.facing ?? 'down';

    if (moving) {
      // Prefer dominant axis (matches iOS priority: up/down/right/left checks)
      if (Math.abs(pc.moveY) >= Math.abs(pc.moveX)) {
        // moveY < 0 is screen-up (see InputManager.updateMovement)
        facing = pc.moveY < 0 ? 'up' : 'down';
      } else {
        facing = pc.moveX < 0 ? 'left' : 'right';
      }

      const wantPrefix = `player_${facing}_0`;
      const currentFirst = sprite.animation.frames[0] ?? '';
      if (currentFirst !== wantPrefix) {
        const next = createSpriteAnimation(playerFrames(facing), 0.08, true);
        next.currentFrame = sprite.animation.currentFrame;
        next.elapsedTime = sprite.animation.elapsedTime;
        next.isPlaying = true;
        sprite.animation = next;
        sprite.textureId = next.frames[next.currentFrame] ?? wantPrefix;
      }

      if (!sprite.animation.isPlaying) sprite.animation.isPlaying = true;
      const frame = updateSpriteAnimation(sprite.animation, dt);
      if (frame) sprite.textureId = frame;
    } else {
      if (sprite.animation.isPlaying) {
        sprite.animation.isPlaying = false;
        sprite.animation.currentFrame = 0;
        sprite.animation.elapsedTime = 0;
      }
      sprite.textureId = sprite.animation.frames[0] ?? 'player_down_0';
    }

    pc.facing = facing;
  }

  private spawnTreesAround(tx: number, ty: number): void {
    for (let y = ty - 24; y <= ty + 24; y++) {
      for (let x = tx - 24; x <= tx + 24; x++) {
        const key = `${x},${y}`;
        if (this.treeSpawned.has(key)) continue;
        this.treeSpawned.add(key);
        const tile = this.chunkManager.getTile(x, y);
        if (!tile) continue;
        if (!this.chunkManager.generator.shouldSpawnTree(x, y, tile.type)) continue;
        if (this.world.entityAt(x, y)) continue;
        this.world
          .spawnWith()
          .with('position', { tileX: x, tileY: y, offsetX: 0.5, offsetY: 0.5 })
          .with('sprite', { textureId: 'tree', width: 1, height: 1, layer: RenderLayer.Entity })
          .with('tree', { woodRemaining: 4 })
          .with('health', { current: 20, max: 20 })
          .build();
      }
    }
  }

  tryMineOrInteract(wx: number, wy: number): void {
    const tx = Math.floor(wx);
    const ty = Math.floor(wy);
    const player = this.localPlayer;
    if (!player) return;
    const pos = this.world.getByName<PositionComponent>('position', player.entity)!;
    if (Math.hypot(pos.tileX - tx, pos.tileY - ty) > 3) return;
    const inv = this.world.getByName<InventoryComponent>('inventory', player.entity)!;

    const ent = this.world.entityAt(tx, ty);
    if (ent && this.world.hasByName('tree', ent)) {
      chopTree(this.world, ent, inv, this.itemRegistry);
      return;
    }
    const tile = this.chunkManager.getTile(tx, ty);
    if (tile?.resource && tile.resource.type !== 'crude-oil') {
      inventoryAdd(inv, tile.resource.type, 1, this.itemRegistry.stackSize(tile.resource.type));
      tile.resource.amount -= 1;
      if (tile.resource.amount <= 0) tile.resource = null;
    }
  }

  placeBuilding(buildingId: string, tileX: number, tileY: number, direction: Direction, playerId?: number): boolean {
    const pid = playerId ?? this.localPlayerId;
    const def = this.buildingRegistry.get(buildingId);
    if (!def) return false;
    const player = this.playerManager.getPlayer(pid);
    if (!player) return false;
    const inv = this.world.getByName<InventoryComponent>('inventory', player.entity);
    if (!inv) return false;

    const id = def.id;
    const type = def.type;
    const w = def.width ?? 1;
    const h = def.height ?? 1;

    // Clear trees in the footprint; block on other entities (player, buildings, enemies).
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const tx = tileX + x;
        const ty = tileY + y;
        const existing = this.world.entityAt(tx, ty);
        if (!existing) continue;
        if (this.world.hasByName('tree', existing)) {
          // Fully clear the tile (chopTree only removes one wood per call).
          while (this.world.isAlive(existing) && this.world.hasByName('tree', existing)) {
            chopTree(this.world, existing, inv, this.itemRegistry);
          }
          continue;
        }
        return false;
      }
    }

    // Cost: prefer item with same id
    if (inventoryCount(inv, buildingId) > 0) {
      inventoryRemove(inv, buildingId, 1);
    } else if (def.cost) {
      if (!def.cost.every((c) => inventoryCount(inv, c.itemId) >= c.count)) return false;
      for (const c of def.cost) inventoryRemove(inv, c.itemId, c.count);
    } else return false;

    const directional =
      type === 'belt' ||
      type === 'inserter' ||
      type === 'pipe' ||
      id.includes('belt') ||
      id.includes('inserter') ||
      id.includes('pipe') ||
      id === 'splitter' ||
      id === 'merger' ||
      id === 'underground-belt' ||
      id === 'underground-pipe';

    const entity = this.world
      .spawnWith()
      .with('position', { tileX, tileY, offsetX: 0.5, offsetY: 0.5 })
      .with('sprite', {
        textureId: buildingId,
        width: w,
        height: h,
        layer: type === 'belt' || type === 'pipe' ? RenderLayer.GroundDecoration : RenderLayer.Building,
        rotation: directional ? direction : 0,
      })
      .with('health', { current: def.maxHealth ?? 100, max: def.maxHealth ?? 100 })
      .with('ownership', { playerId: pid })
      .build();

    this.attachBuildingComponents(entity, def, direction);
    return true;
  }

  private attachBuildingComponents(entity: import('../ecs/Entity').Entity, def: BuildingDef, direction: Direction): void {
    const id = def.id;
    const type = def.type;
    const invSize = Math.max(4, (def.inputSlots ?? 0) + (def.outputSlots ?? 0) + (def.fuelSlots ?? 0) + 8);

    if (type === 'miner' || id.includes('drill')) {
      this.world.addByName('miner', { buildingId: id, progress: 0, miningSpeed: def.miningSpeed ?? 0.5 }, entity);
      this.world.addByName('inventory', emptyInventory(invSize), entity);
      if (!id.includes('burner')) {
        this.world.addByName('powerConsumer', { buildingId: id, powerDraw: def.powerConsumption ?? 90, powered: false }, entity);
      }
    }
    if (type === 'belt' || id.includes('belt') || id === 'splitter' || id === 'merger') {
      this.world.addByName(
        'belt',
        { buildingId: id, direction, speed: def.beltSpeed ?? 1.875, items: [] },
        entity,
      );
    }
    if (type === 'inserter' || id.includes('inserter')) {
      this.world.addByName(
        'inserter',
        {
          buildingId: id,
          direction,
          reach: (def.reach as number) ?? (id.includes('long') ? 2 : 1),
          speed: (def.insertionSpeed as number) ?? 1,
          stackSize: (def.stackSize as number) ?? 1,
          progress: 0,
          heldItem: null,
          heldCount: 0,
        },
        entity,
      );
      this.world.addByName('powerConsumer', { buildingId: id, powerDraw: 13, powered: false }, entity);
    }
    if (type === 'furnace' || id.includes('furnace')) {
      this.world.addByName('furnace', { buildingId: id, progress: 0, recipeId: null, fuelRemaining: 0 }, entity);
      this.world.addByName('inventory', emptyInventory(invSize), entity);
      if (id.includes('electric')) {
        this.world.addByName('powerConsumer', { buildingId: id, powerDraw: def.powerConsumption ?? 180, powered: false }, entity);
      }
    }
    if (type === 'assembler' || id.includes('assembling')) {
      this.world.addByName(
        'assembler',
        { buildingId: id, progress: 0, recipeId: null, craftingSpeed: def.craftingSpeed ?? 0.5 },
        entity,
      );
      this.world.addByName('inventory', emptyInventory(invSize), entity);
      this.world.addByName('powerConsumer', { buildingId: id, powerDraw: def.powerConsumption ?? 75, powered: false }, entity);
    }
    if (type === 'chest' || id.includes('chest')) {
      this.world.addByName('chest', { buildingId: id }, entity);
      this.world.addByName('inventory', emptyInventory(id.includes('steel') ? 48 : id.includes('iron') ? 32 : 16), entity);
    }
    if (type === 'powerPole' || id.includes('pole')) {
      this.world.addByName(
        'powerPole',
        {
          buildingId: id,
          supplyRadius: (def.supplyArea as number) ?? 5,
          wireReach: (def.wireReach as number) ?? 9,
        },
        entity,
      );
    }
    if (id === 'boiler') {
      this.world.addByName('boiler', { buildingId: id, fuelRemaining: 0, temperature: 15 }, entity);
      this.world.addByName('inventory', emptyInventory(4), entity);
    }
    if (id === 'steam-engine') {
      this.world.addByName('steamEngine', { buildingId: id, powerOutput: 0 }, entity);
      this.world.addByName('generator', { buildingId: id, powerOutput: 900, active: false }, entity);
    }
    if (id === 'solar-panel') {
      this.world.addByName('solar', { buildingId: id, powerOutput: def.powerProduction ?? 60 }, entity);
    }
    if (id === 'accumulator') {
      this.world.addByName('accumulator', { buildingId: id, capacity: 5000, stored: 0 }, entity);
    }
    if (id === 'lab' || type === 'lab') {
      this.world.addByName('lab', { buildingId: id, progress: 0 }, entity);
      this.world.addByName('inventory', emptyInventory(12), entity);
      this.world.addByName('powerConsumer', { buildingId: id, powerDraw: def.powerConsumption ?? 60, powered: false }, entity);
    }
    if (type === 'pipe' || id === 'pipe' || id === 'underground-pipe' || id === 'fluid-tank') {
      this.world.addByName(
        'pipe',
        { buildingId: id, fluidId: null, amount: 0, capacity: (def.fluidCapacity as number) ?? 100 },
        entity,
      );
    }
    if (id === 'water-pump') {
      this.world.addByName('fluidProducer', { buildingId: id, fluidId: 'water', rate: 20 }, entity);
      this.world.addByName('pipe', { buildingId: id, fluidId: 'water', amount: 0, capacity: 100 }, entity);
      this.world.addByName('powerConsumer', { buildingId: id, powerDraw: 30, powered: true }, entity);
    }
    if (id === 'pumpjack') {
      this.world.addByName('pumpjack', { buildingId: id }, entity);
      this.world.addByName('fluidProducer', { buildingId: id, fluidId: 'crude-oil', rate: 2 }, entity);
      this.world.addByName('powerConsumer', { buildingId: id, powerDraw: 90, powered: false }, entity);
    }
    if (id === 'oil-refinery' || id === 'chemical-plant') {
      this.world.addByName('assembler', { buildingId: id, progress: 0, recipeId: null, craftingSpeed: 1 }, entity);
      this.world.addByName('inventory', emptyInventory(16), entity);
      this.world.addByName('pipe', { buildingId: id, fluidId: null, amount: 0, capacity: 200 }, entity);
      this.world.addByName('powerConsumer', { buildingId: id, powerDraw: 210, powered: false }, entity);
    }
    if (id === 'gun-turret' || id === 'laser-turret') {
      this.world.addByName(
        'turret',
        {
          buildingId: id,
          range: (def.range as number) ?? 18,
          damage: (def.damage as number) ?? 20,
          cooldown: 0.4,
          fireTimer: 0,
          usesAmmo: id === 'gun-turret',
        },
        entity,
      );
      this.world.addByName('inventory', emptyInventory(8), entity);
      if (id === 'laser-turret') {
        this.world.addByName('powerConsumer', { buildingId: id, powerDraw: 240, powered: false }, entity);
      }
    }
    if (id === 'stone-wall' || type === 'wall') {
      this.world.addByName('wall', { buildingId: id }, entity);
    }
    if (id === 'rocket-silo') {
      this.world.addByName(
        'rocketSilo',
        { buildingId: id, parts: 0, partsRequired: 100, hasSatellite: false, launching: false, launchProgress: 0 },
        entity,
      );
      this.world.addByName('inventory', emptyInventory(20), entity);
      this.world.addByName('powerConsumer', { buildingId: id, powerDraw: 1000, powered: false }, entity);
    }
    if (type === 'unitProduction' || id.includes('barracks') || id.includes('academy') || id.includes('summoning')) {
      this.world.addByName('unitProduction', { buildingId: id, progress: 0, queue: [] }, entity);
      this.world.addByName('powerConsumer', { buildingId: id, powerDraw: 100, powered: false }, entity);
    }
  }

  removeBuildingAt(tx: number, ty: number): boolean {
    const e = this.world.entityAt(tx, ty);
    if (!e) return false;
    if (this.world.hasByName('player', e) || this.world.hasByName('enemy', e) || this.world.hasByName('tree', e))
      return false;
    // refund item
    const sprite = this.world.getByName<{ textureId: string }>('sprite', e);
    const player = this.localPlayer;
    if (player && sprite) {
      const inv = this.world.getByName<InventoryComponent>('inventory', player.entity)!;
      inventoryAdd(inv, sprite.textureId, 1, this.itemRegistry.stackSize(sprite.textureId));
    }
    this.world.despawn(e);
    return true;
  }

  rotateSelected(): void {
    for (const id of this.selectedEntities) {
      const entity = this.world.entities.find((e) => e.id === id);
      if (!entity) continue;
      const belt = this.world.getByName<{ direction: Direction }>('belt', entity);
      const ins = this.world.getByName<{ direction: Direction }>('inserter', entity);
      const sprite = this.world.getByName<{ rotation?: number }>('sprite', entity);
      if (belt) belt.direction = ((belt.direction + 1) % 4) as Direction;
      if (ins) ins.direction = ((ins.direction + 1) % 4) as Direction;
      if (sprite) sprite.rotation = ((sprite.rotation ?? 0) + 1) % 4;
    }
  }

  selectAt(wx: number, wy: number): void {
    const e = this.world.entityAt(Math.floor(wx), Math.floor(wy));
    this.selectedEntities = e ? [e.id] : [];
  }

  queueCraft(recipeId: string): void {
    const player = this.localPlayer;
    if (!player) return;
    if (!this.researchSystem.unlockedRecipes.has(recipeId) && !this.recipeRegistry.get(recipeId)) return;
    const recipe = this.recipeRegistry.get(recipeId);
    if (!recipe) return;
    const pc = this.world.getByName<PlayerComponent>('player', player.entity)!;
    pc.craftQueue.push({ recipeId, remaining: recipe.craftTime });
  }

  setAssemblerRecipe(entityId: number, recipeId: string): void {
    const entity = this.world.entities.find((e) => e.id === entityId);
    if (!entity) return;
    const asm = this.world.getByName<{ recipeId: string | null }>('assembler', entity);
    if (asm) asm.recipeId = recipeId;
  }

  commandSelectedUnits(cmd: 'move' | 'attack' | 'stop', x?: number, y?: number, targetId?: number): void {
    for (const id of this.selectedEntities) {
      const entity = this.world.entities.find((e) => e.id === id);
      if (!entity) continue;
      const unit = this.world.getByName<UnitComponent>('unit', entity);
      if (!unit) continue;
      if (cmd === 'stop') unit.command = 'hold';
      if (cmd === 'move' && x !== undefined && y !== undefined) {
        unit.command = 'move';
        unit.targetX = x;
        unit.targetY = y;
      }
      if (cmd === 'attack') {
        unit.command = 'attack';
        unit.targetX = x;
        unit.targetY = y;
        if (targetId !== undefined) {
          const t = this.world.entities.find((e) => e.id === targetId);
          if (t) unit.targetEntity = t;
        }
      }
    }
  }

  startPvAI(config?: Partial<MatchConfig>): void {
    this.matchMode = 'pvai';
    this.lobby.config = { ...this.lobby.config, ...config, mode: 'pvai' };
    this.lobby.reset(4);
    this.lobby.addAI();
    this.lobby.addAI();
    const spawns = this.spawnSystem.positions(3);
    // AI players
    let i = 1;
    for (const slot of this.lobby.slots) {
      if (!slot.isAI) continue;
      const s = spawns[i++] ?? { x: 20, y: 20 };
      this.playerManager.createPlayer(slot.name, true, s.x, s.y);
    }
  }

  serializeSave(): GameSave {
    const player = this.localPlayer!;
    const pos = this.world.getByName<PositionComponent>('position', player.entity)!;
    const inv = this.world.getByName<InventoryComponent>('inventory', player.entity)!;
    const hp = this.world.getByName<HealthComponent>('health', player.entity)!;
    return {
      version: 1,
      seed: this.worldSeed,
      playTime: this.playTime,
      playerData: {
        position: { x: pos.tileX + pos.offsetX, y: pos.tileY + pos.offsetY },
        inventory: inv,
        health: hp.current,
      },
      worldData: { entities: this.world.serializeEntities() },
      researchData: this.researchSystem.serialize(),
      chunks: this.chunkManager.serialize(),
      timestamp: new Date().toISOString(),
    };
  }

  loadSave(save: GameSave): void {
    this.world.clear();
    this.worldSeed = save.seed;
    this.chunkManager = new ChunkManager(save.seed);
    if (save.chunks?.length) this.chunkManager.loadChunks(save.chunks as never);
    this.playerManager = new PlayerManager(this.world, this.itemRegistry);
    this.localPlayerId = this.playerManager.createPlayer('Player', false, Math.floor(save.playerData.position.x), Math.floor(save.playerData.position.y));
    const player = this.localPlayer!;
    const inv = this.world.getByName<InventoryComponent>('inventory', player.entity)!;
    inv.slots = save.playerData.inventory.slots;
    const hp = this.world.getByName<HealthComponent>('health', player.entity)!;
    hp.current = save.playerData.health;
    this.researchSystem.load(save.researchData);
    this.playTime = save.playTime;
    this.isPlayerDead = false;
    this.victory.reset();
    // Rehydrate non-player entities from save
    for (const ed of save.worldData.entities) {
      if (ed.components.player) continue;
      const b = this.world.spawnWith();
      for (const [name, comp] of Object.entries(ed.components)) {
        b.with(name, comp);
      }
      b.build();
    }
  }
}
