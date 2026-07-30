import * as THREE from 'three';
import type { GameView } from '../render/ViewMode';
import type { Camera2D } from '../render/Camera2D';
import type { World } from '../ecs/World';
import type { ChunkManager } from '../../game/world/ChunkManager';
import { CHUNK_SIZE } from '../../game/world/Chunk';
import { assets } from '../render/AssetCatalog';
import type { PositionComponent, SpriteComponent } from '../../game/components';
import { createRenderer, type GameRenderer } from '../render/createRenderer';

/** Perspective 3D view sharing the same ECS world coords (X/Z = tile plane, Y = height). */
export class Perspective3DView implements GameView {
  readonly kind = 'perspective3d' as const;
  private renderer!: GameRenderer;
  private scene = new THREE.Scene();
  private camera = new THREE.PerspectiveCamera(60, 1, 0.1, 500);
  private sun!: THREE.DirectionalLight;
  private terrain = new Map<string, THREE.Mesh>();
  private entities = new Map<string, THREE.Mesh>();
  private box = new THREE.BoxGeometry(1, 1, 1);
  private materials = new Map<string, THREE.MeshStandardMaterial>();
  private enabled = false;
  private canvas!: HTMLCanvasElement;
  private orbitAngle = 0.6;
  private orbitYaw = 0.4;

  async init(canvas: HTMLCanvasElement): Promise<void> {
    this.canvas = canvas;
    this.renderer = await createRenderer(canvas, true);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.scene.background = new THREE.Color('#87a0b5');
    this.scene.fog = new THREE.Fog('#87a0b5', 40, 120);

    const ambient = new THREE.AmbientLight(0xffffff, 0.45);
    this.scene.add(ambient);
    this.sun = new THREE.DirectionalLight(0xfff2dd, 1.1);
    this.sun.position.set(30, 50, 20);
    this.scene.add(this.sun);
  }

  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
    if (this.canvas) this.canvas.style.display = enabled ? 'block' : 'none';
  }

  resize(width: number, height: number): void {
    this.camera.aspect = width / Math.max(1, height);
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(width, height, false);
  }

  private mat(textureId: string): THREE.MeshStandardMaterial {
    let m = this.materials.get(textureId);
    if (!m) {
      m = new THREE.MeshStandardMaterial({
        map: assets.get(textureId),
        roughness: 0.85,
        metalness: 0.05,
      });
      this.materials.set(textureId, m);
    } else {
      const map = assets.get(textureId);
      if (m.map !== map) {
        m.map = map;
        m.needsUpdate = true;
      }
    }
    return m;
  }

  private heightFor(type: string): number {
    if (type === 'water') return 0.15;
    if (type === 'stone') return 0.55;
    if (type === 'sand') return 0.25;
    return 0.35;
  }

  render(world: World, chunks: ChunkManager, camera2d: Camera2D, dt: number): void {
    if (!this.enabled) return;

    const distance = Math.max(8, Math.min(100, 100 / camera2d.zoom));
    this.orbitYaw += dt * 0.05;
    const target = new THREE.Vector3(camera2d.x, 0, camera2d.y);
    const ox = Math.sin(this.orbitYaw) * Math.cos(this.orbitAngle) * distance;
    const oy = Math.sin(this.orbitAngle) * distance;
    const oz = Math.cos(this.orbitYaw) * Math.cos(this.orbitAngle) * distance;
    this.camera.position.set(target.x + ox, oy, target.z + oz);
    this.camera.lookAt(target);

    const seenT = new Set<string>();
    for (const chunk of chunks.loadedChunks()) {
      for (let ly = 0; ly < CHUNK_SIZE; ly += 1) {
        for (let lx = 0; lx < CHUNK_SIZE; lx += 1) {
          const wx = chunk.coord.x * CHUNK_SIZE + lx;
          const wz = chunk.coord.y * CHUNK_SIZE + ly;
          if (Math.hypot(wx - camera2d.x, wz - camera2d.y) > distance * 1.2) continue;
          const tile = chunk.tiles[ly]![lx]!;
          const key = `${chunk.coord.x},${chunk.coord.y}:${lx},${ly}`;
          seenT.add(key);
          let mesh = this.terrain.get(key);
          const h = this.heightFor(tile.type);
          if (!mesh) {
            mesh = new THREE.Mesh(this.box, this.mat(tile.type));
            this.terrain.set(key, mesh);
            this.scene.add(mesh);
          } else {
            mesh.material = this.mat(tile.type);
          }
          mesh.position.set(wx + 0.5, h / 2, wz + 0.5);
          mesh.scale.set(1, h, 1);
          mesh.visible = true;

          if (tile.resource) {
            const rk = `r:${key}`;
            seenT.add(rk);
            let rm = this.terrain.get(rk);
            if (!rm) {
              rm = new THREE.Mesh(this.box, this.mat(tile.resource.type));
              this.terrain.set(rk, rm);
              this.scene.add(rm);
            }
            rm.position.set(wx + 0.5, h + 0.2, wz + 0.5);
            rm.scale.set(0.45, 0.4, 0.45);
            rm.visible = true;
          }
        }
      }
    }
    for (const [k, m] of this.terrain) if (!seenT.has(k)) m.visible = false;

    const seenE = new Set<string>();
    world.forEach<SpriteComponent>('sprite', (sprite, entity) => {
      if (sprite.visible === false) return;
      const pos = world.getByName<PositionComponent>('position', entity);
      if (!pos) return;
      const key = `e:${entity.id}`;
      seenE.add(key);
      let mesh = this.entities.get(key);
      const color = sprite.textureId;
      if (!mesh) {
        mesh = new THREE.Mesh(this.box, this.mat(color));
        this.entities.set(key, mesh);
        this.scene.add(mesh);
      } else {
        mesh.material = this.mat(color);
      }
      const h = Math.max(0.4, Math.min(sprite.width, sprite.height) * 0.8);
      mesh.position.set(
        pos.tileX + pos.offsetX + (sprite.width - 1) * 0.5,
        h / 2 + 0.35,
        pos.tileY + pos.offsetY + (sprite.height - 1) * 0.5,
      );
      mesh.scale.set(sprite.width * 0.85, h, sprite.height * 0.85);
      mesh.visible = true;
    });
    for (const [k, m] of this.entities) if (!seenE.has(k)) m.visible = false;

    this.renderer.render(this.scene, this.camera);
  }

  dispose(): void {
    for (const m of this.materials.values()) m.dispose();
    this.box.dispose();
    this.renderer.dispose();
  }
}
