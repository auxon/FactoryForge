import type { Camera2D } from './Camera2D';
import type { World } from '../ecs/World';
import type { ChunkManager } from '../../game/world/ChunkManager';

export type ViewKind = 'ortho2d' | 'perspective3d';

export interface GameView {
  readonly kind: ViewKind;
  init(canvas: HTMLCanvasElement): Promise<void>;
  resize(width: number, height: number): void;
  render(world: World, chunks: ChunkManager, camera: Camera2D, dt: number): void;
  dispose(): void;
  setEnabled(enabled: boolean): void;
}
