// AAA nature: Blender-exported GLB tree/rock/grass + PBR zone terrain.
// Models: Poly Haven fir_sapling / boulder_01 / grass_bermuda_01 (CC0),
// decimated + diffuse-only for web. Textures: Poly Haven leafy_grass,
// dirt, sand_03 (CC0) used as repeating PBR detail + baked zone canvas.
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import type { World } from '../sim/world';
import { rng } from '../sim/world';

export class Nature {
  scene: THREE.Scene;
  world: World;
  seed: number;
  treeProto: THREE.Group | null = null;
  rockProto: THREE.Group | null = null;
  grassProto: THREE.Group | null = null;
  treeGroup = new THREE.Group();
  rockGroup = new THREE.Group();
  grassGroup = new THREE.Group();
  loaded = false;
  onReady: (() => void) | null = null;
  private lastTreeCount = -1;
  private lastEntCount = -1;

  constructor(scene: THREE.Scene, world: World, seed: number) {
    this.scene = scene;
    this.world = world;
    this.seed = seed;
    scene.add(this.treeGroup, this.rockGroup, this.grassGroup);
    const loader = new GLTFLoader();
    const base = (import.meta.env.BASE_URL || '/');
    const M = (f: string): string => `${base}models/${f}`.replace(/\/+/g, '/');
    const load = (url: string): Promise<THREE.Group> =>
      new Promise((res, rej) => loader.load(url, (g) => res(g.scene), undefined, rej));
    Promise.all([
      load(M('ff-tree-game.glb')),
      load(M('ff-rock-game.glb')),
      load(M('ff-grass.glb')),
    ]).then(([tree, rock, grass]) => {
      for (const g of [tree, rock, grass]) {
        g.traverse((o) => {
          if (o instanceof THREE.Mesh) { o.castShadow = true; o.receiveShadow = false; }
        });
      }
      // Same sculpt fix as buildings: center-authored models arrive sunk.
      // Trees also come out small next to the legacy cones, so grow them.
      // Seat is stored, not baked: clones below overwrite position/scale.
      tree.userData.baseScale = 1.6;
      for (const g of [tree, rock, grass]) {
        const box = new THREE.Box3().setFromObject(g);
        g.userData.seatY = -box.min.y;
      }
      this.treeProto = tree;
      this.rockProto = rock;
      this.grassProto = grass;
      this.loaded = true;
      this.lastTreeCount = -1;
      this.lastEntCount = -1;
      this.onReady?.();
    }).catch((e) => console.warn('nature models failed:', e));
  }

  /** Scatter static dressing: rocks near ore + random, grass tufts everywhere dry. */
  scatterStatic(): void {
    if (!this.loaded) return;
    const rand = rng(this.seed + 99);
    // rocks: ring each ore deposit + sparse random
    this.rockGroup.clear();
    const spots: [number, number, number][] = [];
    for (const d of this.world.resources.values()) {
      if (rand() < 0.3) spots.push([d.x + 0.5, d.y + 0.5, 0.5 + rand() * 0.9]);
    }
    for (let i = 0; i < 70; i++) {
      const x = Math.floor((rand() - 0.5) * 220);
      const y = Math.floor((rand() - 0.5) * 220);
      if (this.world.water.has(`${x},${y}`)) continue;
      spots.push([x + 0.5, y + 0.5, 0.4 + rand() * 1.1]);
    }
    for (const [x, y, s] of spots) {
      const m = this.rockProto!.clone();
      m.rotation.y = rand() * Math.PI * 2;
      m.scale.setScalar(s);
      m.position.set(x, (this.rockProto!.userData.seatY as number) * s, y);
      this.rockGroup.add(m);
    }
    // grass tufts: dense, not on water
    this.grassGroup.clear();
    for (let i = 0; i < 520; i++) {
      const x = Math.floor((rand() - 0.5) * 200);
      const y = Math.floor((rand() - 0.5) * 200);
      const k = `${x},${y}`;
      if (this.world.water.has(k)) continue;
      if (this.world.resources.has(k) && rand() < 0.7) continue;
      const m = this.grassProto!.clone();
      const gs = 0.8 + rand() * 1.4;
      m.position.set(x + rand(), (this.grassProto!.userData.seatY as number) * gs, y + rand());
      m.rotation.y = rand() * Math.PI * 2;
      m.scale.setScalar(gs);
      m.visible = true;
      m.userData.tx = x; m.userData.ty = y;
      this.grassGroup.add(m);
    }
    this.hideOverlaps();
  }

  /** Hide tufts inside building footprints (run on entity change). */
  hideOverlaps(): void {
    if (!this.loaded) return;
    for (const m of this.grassGroup.children) {
      const e = this.world.entityAt(m.userData.tx, m.userData.ty);
      m.visible = !e;
    }
  }

  /** Trees follow world.trees (choping updates automatically). */
  syncTrees(): void {
    if (!this.loaded) return;
    if (this.world.trees.size === this.lastTreeCount) return;
    this.lastTreeCount = this.world.trees.size;
    this.treeGroup.clear();
    const rand = rng(this.seed + 7);
    for (const k of this.world.trees.keys()) {
      const [x, y] = k.split(',').map(Number);
      const m = this.treeProto!.clone();
      m.rotation.y = ((x * 31 + y * 17) % 100) / 100 * Math.PI * 2;
      const ts = ((this.treeProto!.userData.baseScale as number) ?? 1)
        * (0.85 + (((x * 13 + y * 29) % 50) / 50) * 0.5 + rand() * 0.05);
      m.scale.setScalar(ts);
      m.position.set(x + 0.5, (this.treeProto!.userData.seatY as number) * ts, y + 0.5);
      this.treeGroup.add(m);
    }
  }

  update(entityCount: number): void {
    if (!this.loaded) return;
    if (this.rockGroup.children.length === 0) this.scatterStatic();
    this.syncTrees();
    if (entityCount !== this.lastEntCount) {
      this.lastEntCount = entityCount;
      this.hideOverlaps();
    }
  }
}

/** Baked 2048px zone canvas over the 400m plane: grass base + noise,
 * dirt around ore patches + spawn, sand ring at water, dark rock tint
 * under uranium/oil. Drawn once per world (seed). */
export function bakeTerrainCanvas(world: World, seed: number): HTMLCanvasElement {
  const S = 2048, WORLD = 400;
  const cv = document.createElement('canvas');
  cv.width = cv.height = S;
  const ctx = cv.getContext('2d')!;
  const px = (v: number): number => ((v + WORLD / 2) / WORLD) * S;
  const rand = rng(seed + 1234);
  // grass base
  ctx.fillStyle = '#4a6b3a';
  ctx.fillRect(0, 0, S, S);
  // large soft variation splotches
  for (let i = 0; i < 900; i++) {
    const x = rand() * S, y = rand() * S, r = 12 + rand() * 60;
    const g = ctx.createRadialGradient(x, y, 0, x, y, r);
    const tint = rand();
    const c = tint < 0.5 ? '58,92,52' : tint < 0.8 ? '74,107,58' : '96,128,72';
    g.addColorStop(0, `rgba(${c},0.5)`);
    g.addColorStop(1, `rgba(${c},0)`);
    ctx.fillStyle = g;
    ctx.fillRect(x - r, y - r, r * 2, r * 2);
  }
  const blob = (wx: number, wy: number, rTiles: number, color: string, alpha: number): void => {
    const x = px(wx), y = px(wy), r = (rTiles / WORLD) * S;
    const g = ctx.createRadialGradient(x, y, 0, x, y, r);
    g.addColorStop(0, color.replace('A', String(alpha)));
    g.addColorStop(1, color.replace('A', '0'));
    ctx.fillStyle = g;
    ctx.fillRect(x - r, y - r, r * 2, r * 2);
  };
  // dirt around every ore tile
  for (const d of world.resources.values()) {
    const dark = d.outputItem === 'uranium-ore' || d.outputItem === 'crude-oil';
    blob(d.x + 0.5, d.y + 0.5, 1.6, dark ? 'rgba(52,44,40,A)' : 'rgba(124,96,64,A)', 0.85);
  }
  // factory floor at spawn
  blob(0.5, 0.5, 9, 'rgba(130,104,70,A)', 0.9);
  // sand ring near water
  for (const k of world.water) {
    const [x, y] = k.split(',').map(Number);
    blob(x + 0.5, y + 0.5, 1.8, 'rgba(194,178,128,A)', 0.9);
  }
  // fine grain
  for (let i = 0; i < 6000; i++) {
    const v = rand();
    ctx.fillStyle = v < 0.5 ? 'rgba(0,0,0,0.05)' : 'rgba(255,255,240,0.04)';
    ctx.fillRect(rand() * S, rand() * S, 3, 3);
  }
  return cv;
}
