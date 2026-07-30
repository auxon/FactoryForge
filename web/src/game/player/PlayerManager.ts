import type { World } from '../../engine/ecs/World';
import type { Entity } from '../../engine/ecs/Entity';
import { emptyInventory, inventoryAdd, RenderLayer, createSpriteAnimation, type InventoryComponent, type PlayerComponent } from '../components';
import type { ItemRegistry } from '../data/Registries';
import { getStartingItems } from '../data/Registries';
import { playerFrames } from '../../engine/render/AssetCatalog';

export interface PlayerInfo {
  playerId: number;
  entity: Entity;
  name: string;
  isAI: boolean;
}

export class PlayerManager {
  private players = new Map<number, PlayerInfo>();
  private nextId = 1;

  constructor(
    private world: World,
    private items: ItemRegistry,
  ) {}

  createPlayer(name: string, isAI: boolean, x = 0, y = 0): number {
    const playerId = this.nextId++;
    const inv = emptyInventory(70);
    for (const stack of getStartingItems()) {
      inventoryAdd(inv, stack.itemId, stack.count, this.items.stackSize(stack.itemId));
    }
    // Give starter placeables for web playability
    for (const [id, count] of [
      ['burner-mining-drill', 5],
      ['stone-furnace', 4],
      ['transport-belt', 100],
      ['inserter', 20],
      ['wooden-chest', 5],
      ['small-electric-pole', 20],
      ['boiler', 2],
      ['steam-engine', 2],
      ['pipe', 50],
      ['water-pump', 1],
      ['lab', 1],
      ['assembling-machine-1', 2],
      ['gun-turret', 2],
      ['stone-wall', 20],
    ] as const) {
      inventoryAdd(inv, id, count as number, this.items.stackSize(id));
    }

    const entity = this.world
      .spawnWith()
      .with('position', { tileX: x, tileY: y, offsetX: 0.5, offsetY: 0.5 })
      .with('sprite', {
        textureId: 'player_down_0',
        width: 1,
        height: 1,
        layer: RenderLayer.Entity,
        animation: createSpriteAnimation(playerFrames('down'), 0.08, true),
      })
      .with('health', { current: 100, max: 100 })
      .with('inventory', inv)
      .with('player', {
        playerId,
        name,
        isAI,
        moveX: 0,
        moveY: 0,
        craftQueue: [],
        facing: 'down' as const,
      })
      .with('ownership', { playerId })
      .build();

    this.players.set(playerId, { playerId, entity, name, isAI });
    return playerId;
  }

  getPlayer(playerId: number): PlayerInfo | undefined {
    return this.players.get(playerId);
  }

  get all(): PlayerInfo[] {
    return [...this.players.values()];
  }

  getInventory(playerId: number): InventoryComponent | undefined {
    const p = this.players.get(playerId);
    if (!p) return undefined;
    return this.world.getByName<InventoryComponent>('inventory', p.entity);
  }
}
