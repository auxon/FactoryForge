import * as THREE from 'three';
import type { GameView } from './ViewMode';
import type { Camera2D } from './Camera2D';
import type { World } from '../ecs/World';
import type { ChunkManager } from '../../game/world/ChunkManager';
import { CHUNK_SIZE } from '../../game/world/Chunk';
import type { PositionComponent, SpriteComponent } from '../../game/components';
import { RenderLayer } from '../../game/components';
import { createRenderer, type GameRenderer } from './createRenderer';
import { assets } from './AssetCatalog';

const OPAQUE_TILES = new Set(['grass', 'dirt', 'sand', 'water', 'stone']);

interface Quad {
  mesh: THREE.Mesh;
  key: string;
  textureId: string;
}

export class OrthoSpriteView implements GameView {
  readonly kind = 'ortho2d' as const;
  private renderer!: GameRenderer;
  private scene = new THREE.Scene();
  private camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 1000);
  private quads = new Map<string, Quad>();
  private tileQuads = new Map<string, THREE.Mesh>();
  private tileTex = new Map<string, string>();
  private geom = new THREE.PlaneGeometry(1, 1);
  private materials = new Map<string, THREE.MeshBasicMaterial>();
  private enabled = true;
  private width = 800;
  private height = 600;
  private canvas!: HTMLCanvasElement;

  async init(canvas: HTMLCanvasElement): Promise<void> {
    this.canvas = canvas;
    this.renderer = await createRenderer(canvas, false);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.scene.background = new THREE.Color('#1a2a18');
    this.camera.position.z = 10;
  }

  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
    if (this.canvas) this.canvas.style.display = enabled ? 'block' : 'none';
  }

  resize(width: number, height: number): void {
    this.width = width;
    this.height = height;
    this.renderer.setSize(width, height, false);
  }

  private mat(textureId: string, opaque = false): THREE.MeshBasicMaterial {
    const key = opaque ? `o:${textureId}` : textureId;
    let m = this.materials.get(key);
    if (!m) {
      m = new THREE.MeshBasicMaterial({
        map: assets.get(textureId),
        transparent: !opaque,
        depthWrite: opaque,
        // Cut out near-zero alpha so transparent PNG padding doesn't tint quads
        alphaTest: opaque ? 0 : 0.1,
      });
      this.materials.set(key, m);
    } else {
      const map = assets.get(textureId);
      if (m.map !== map) {
        m.map = map;
        m.needsUpdate = true;
      }
    }
    return m;
  }

  private syncTile(key: string, x: number, y: number, textureId: string, z: number, scale = 1): void {
    const opaque = OPAQUE_TILES.has(textureId);
    let mesh = this.tileQuads.get(key);
    if (!mesh) {
      mesh = new THREE.Mesh(this.geom, this.mat(textureId, opaque));
      this.tileQuads.set(key, mesh);
      this.tileTex.set(key, textureId);
      this.scene.add(mesh);
    } else if (this.tileTex.get(key) !== textureId) {
      mesh.material = this.mat(textureId, opaque);
      this.tileTex.set(key, textureId);
    } else {
      mesh.material = this.mat(textureId, opaque);
    }
    mesh.position.set(x, y, z);
    // Tiny overlap avoids sub-pixel cracks after crop; content is now edge-to-edge
    mesh.scale.set(scale, scale, 1);
    mesh.visible = true;
  }

  private syncSprite(
    key: string,
    x: number,
    y: number,
    w: number,
    h: number,
    textureId: string,
    z: number,
    rot = 0,
  ): void {
    let q = this.quads.get(key);
    if (!q) {
      const mesh = new THREE.Mesh(this.geom, this.mat(textureId));
      q = { mesh, key, textureId };
      this.quads.set(key, q);
      this.scene.add(mesh);
    } else {
      q.textureId = textureId;
      q.mesh.material = this.mat(textureId);
    }
    q.mesh.position.set(x, y, z);
    q.mesh.scale.set(w, h, 1);
    q.mesh.rotation.z = -rot;
    q.mesh.visible = true;
  }

  render(world: World, chunks: ChunkManager, camera: Camera2D, _dt: number): void {
    if (!this.enabled) return;

    const halfW = this.width / (2 * camera.zoom * camera.pixelsPerTile);
    const halfH = this.height / (2 * camera.zoom * camera.pixelsPerTile);
    this.camera.left = -halfW;
    this.camera.right = halfW;
    this.camera.top = halfH;
    this.camera.bottom = -halfH;
    this.camera.position.x = camera.x;
    this.camera.position.y = camera.y;
    this.camera.updateProjectionMatrix();

    const seenTiles = new Set<string>();
    const seenSprites = new Set<string>();

    for (const chunk of chunks.loadedChunks()) {
      for (let ly = 0; ly < CHUNK_SIZE; ly++) {
        for (let lx = 0; lx < CHUNK_SIZE; lx++) {
          const wx = chunk.coord.x * CHUNK_SIZE + lx + 0.5;
          const wy = chunk.coord.y * CHUNK_SIZE + ly + 0.5;
          if (Math.abs(wx - camera.x) > halfW + 2 || Math.abs(wy - camera.y) > halfH + 2) continue;
          const tile = chunk.tiles[ly]![lx]!;
          const key = `t:${chunk.coord.x},${chunk.coord.y}:${lx},${ly}`;
          seenTiles.add(key);
          this.syncTile(key, wx, wy, tile.type, RenderLayer.Ground * 0.01, 1.002);
          if (tile.resource) {
            const rk = `r:${key}`;
            seenTiles.add(rk);
            this.syncTile(rk, wx, wy, tile.resource.type, RenderLayer.GroundDecoration * 0.01, 0.75);
          }
        }
      }
    }

    world.forEach<SpriteComponent>('sprite', (sprite, entity) => {
      if (sprite.visible === false) return;
      const pos = world.getByName<PositionComponent>('position', entity);
      if (!pos) return;
      const x = pos.tileX + pos.offsetX;
      const y = pos.tileY + pos.offsetY;
      if (Math.abs(x - camera.x) > halfW + 4 || Math.abs(y - camera.y) > halfH + 4) return;
      const key = `s:${entity.id}`;
      seenSprites.add(key);
      const rot = ((sprite.rotation ?? 0) * Math.PI) / 2;
      this.syncSprite(
        key,
        x + (sprite.width - 1) * 0.5,
        y + (sprite.height - 1) * 0.5,
        sprite.width * 0.95,
        sprite.height * 0.95,
        sprite.textureId,
        sprite.layer * 0.01,
        rot,
      );
    });

    for (const [key, mesh] of this.tileQuads) {
      if (!seenTiles.has(key)) mesh.visible = false;
    }
    for (const [key, q] of this.quads) {
      if (!seenSprites.has(key)) q.mesh.visible = false;
    }

    this.renderer.render(this.scene, this.camera);
  }

  dispose(): void {
    for (const m of this.materials.values()) m.dispose();
    this.geom.dispose();
    this.renderer.dispose();
  }
}
