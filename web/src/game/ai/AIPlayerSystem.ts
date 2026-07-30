import type { World } from '../../engine/ecs/World';
import type { PlayerManager } from '../player/PlayerManager';
import type { InventoryComponent, PlayerComponent, PositionComponent } from '../components';
import { inventoryCount } from '../components';
import type { Direction } from '../components';

export type AIDifficulty = 'easy' | 'normal' | 'hard' | 'expert';

const SPEEDS: Record<AIDifficulty, number> = {
  easy: 0.5,
  normal: 1,
  hard: 1.5,
  expert: 2,
};

export class AIPlayerSystem {
  difficulty: AIDifficulty = 'normal';
  private timers = new Map<number, number>();

  constructor(
    private world: World,
    private players: PlayerManager,
    private placeBuilding: (playerId: number, id: string, x: number, y: number, dir: Direction) => boolean,
  ) {}

  update(dt: number): void {
    const scale = SPEEDS[this.difficulty];
    for (const p of this.players.all) {
      if (!p.isAI) continue;
      const t = (this.timers.get(p.playerId) ?? 0) + dt * scale;
      this.timers.set(p.playerId, t);
      if (t < 2) continue;
      this.timers.set(p.playerId, 0);

      const pos = this.world.getByName<PositionComponent>('position', p.entity)!;
      const inv = this.world.getByName<InventoryComponent>('inventory', p.entity)!;
      const pc = this.world.getByName<PlayerComponent>('player', p.entity)!;

      // Simple opening: place miners/furnaces/belts near spawn
      const ox = (p.playerId % 5) * 12;
      const oy = Math.floor(p.playerId / 5) * 12;

      if (inventoryCount(inv, 'burner-mining-drill') > 0) {
        this.placeBuilding(p.playerId, 'burner-mining-drill', pos.tileX + 2 + ox % 3, pos.tileY + oy % 3, 1);
      } else if (inventoryCount(inv, 'stone-furnace') > 0) {
        this.placeBuilding(p.playerId, 'stone-furnace', pos.tileX + 5, pos.tileY, 1);
      } else if (inventoryCount(inv, 'transport-belt') > 0) {
        this.placeBuilding(p.playerId, 'transport-belt', pos.tileX + 1, pos.tileY + 1, 1);
      } else if (inventoryCount(inv, 'gun-turret') > 0) {
        this.placeBuilding(p.playerId, 'gun-turret', pos.tileX - 2, pos.tileY - 2, 1);
      }

      // Wander
      pc.moveX = Math.sin(t + p.playerId) * 0.3;
      pc.moveY = Math.cos(t * 0.7 + p.playerId) * 0.3;
    }
  }
}
