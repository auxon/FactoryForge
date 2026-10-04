// GLB hero models (Blender-authored) + prefix animation convention.
// File per building; animatable parts found by name prefix:
// Rotor* (spin) | Arm* (bob/swing) | Beam* (rock) | Head* (aim) |
// Wheel* (spin) | Rocket* (rise group) | Glow* (flicker) | Lamp* (power color)
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import type { Anim } from './models';

/** Base path so models resolve under dev, dist, or a subpath deploy. */
const BASE = import.meta.env.BASE_URL || '/';
const M = (f: string): string => `${BASE}models/${f}`.replace(/\/+/g, '/');

interface Entry { file: string; tint?: number; scale?: number; }

/** Per-file sculpt fixes: models authored off-scale relative to their footprint. */
const SCALE_FIX: Record<string, number> = {
  // engineer authored 0.55 tall; procedural rig is ~1.1
  [M('ff-player.glb')]: 2.0,
};

/** buildingId -> GLB. Unlisted ids use the procedural fallback. */
export const MODEL_FOR: Record<string, Entry> = {
  'burner-mining-drill': { file: M('ff-burner-drill.glb') },
  'electric-mining-drill': { file: M('ff-electric-drill.glb') },
  pumpjack: { file: M('ff-pumpjack.glb') },
  'water-pump': { file: M('ff-waterpump.glb') },
  'offshore-pump': { file: M('ff-waterpump.glb') },
  'stone-furnace': { file: M('ff-stone-furnace.glb') },
  'steel-furnace': { file: M('ff-steel-furnace.glb') },
  'electric-furnace': { file: M('ff-electric-furnace.glb') },
  'assembling-machine-1': { file: M('ff-assembler.glb') },
  'assembling-machine-2': { file: M('ff-assembler.glb'), tint: 0xbfe0ff },
  'assembling-machine-3': { file: M('ff-assembler.glb'), tint: 0xffe0b0 },
  'transport-belt': { file: M('ff-belt.glb') },
  'fast-transport-belt': { file: M('ff-belt.glb'), tint: 0xffd070 },
  'express-transport-belt': { file: M('ff-belt.glb'), tint: 0x70c0ff },
  'underground-belt': { file: M('ff-belt.glb') },
  splitter: { file: M('ff-belt.glb') },
  merger: { file: M('ff-belt.glb') },
  'belt-bridge': { file: M('ff-belt.glb') },
  inserter: { file: M('ff-inserter.glb') },
  'long-handed-inserter': { file: M('ff-inserter.glb'), scale: 1.25 },
  'fast-inserter': { file: M('ff-inserter.glb'), tint: 0xffd070 },
  'stack-inserter': { file: M('ff-inserter.glb'), tint: 0x70c0ff },
  'small-electric-pole': { file: M('ff-pole.glb') },
  'medium-electric-pole': { file: M('ff-pole.glb'), scale: 1.2 },
  'big-electric-pole': { file: M('ff-pole.glb'), scale: 1.6 },
  boiler: { file: M('ff-boiler.glb') },
  'steam-engine': { file: M('ff-steam-engine.glb') },
  'solar-panel': { file: M('ff-solar.glb') },
  accumulator: { file: M('ff-accumulator.glb') },
  'gun-turret': { file: M('ff-gun-turret.glb') },
  'laser-turret': { file: M('ff-laser-turret.glb') },
  'stone-wall': { file: M('ff-wall.glb') },
  'wooden-chest': { file: M('ff-chest.glb') },
  'iron-chest': { file: M('ff-chest.glb'), tint: 0xc0c8d0 },
  'steel-chest': { file: M('ff-chest.glb'), tint: 0x90a0b0 },
  'oil-refinery': { file: M('ff-refinery.glb') },
  'chemical-plant': { file: M('ff-chemplant.glb') },
  pipe: { file: M('ff-pipe.glb') },
  'underground-pipe': { file: M('ff-pipe.glb') },
  'fluid-tank': { file: M('ff-tank.glb') },
  'nuclear-reactor': { file: M('ff-reactor.glb') },
  centrifuge: { file: M('ff-centrifuge.glb') },
  'rocket-silo': { file: M('ff-silo.glb') },
  lab: { file: M('ff-lab.glb') },
};

export const PLAYER_GLB = M('ff-player.glb');
export const BITER_GLB = M('ff-biter.glb');
export const SPITTER_GLB = M('ff-spitter.glb');
export const NEST_GLB = M('ff-nest.glb');

const loader = new GLTFLoader();

export class GlbLibrary {
  protos = new Map<string, THREE.Group>();
  pending = new Map<string, Promise<THREE.Group>>();

  get(file: string): THREE.Group | null {
    return this.protos.get(file) ?? null;
  }

  load(file: string): Promise<THREE.Group> {
    const hit = this.pending.get(file);
    if (hit) return hit;
    const p = new Promise<THREE.Group>((res, rej) => {
      loader.load(file, (g) => {
        const scene = g.scene;
        scene.traverse((o) => {
          if (o instanceof THREE.Mesh) {
            o.castShadow = true;
            o.receiveShadow = false;
          }
        });
        // Sculpt fix (baked once into the proto, inherited by every clone):
        // Blender models are authored centered on the origin, so without
        // seating every building sinks halfway into the ground.
        const fix = SCALE_FIX[file];
        if (fix != null) scene.scale.setScalar(fix);
        const box = new THREE.Box3().setFromObject(scene);
        scene.position.y -= box.min.y;
        scene.userData.seatY = scene.position.y;
        this.protos.set(file, scene);
        res(scene);
      }, undefined, rej);
    });
    this.pending.set(file, p);
    return p;
  }

  /** Re-seat a clone after caller-side rescaling (scale re-sinks the base). */
  reseat(g: THREE.Group): void {
    const box = new THREE.Box3().setFromObject(g);
    g.position.y -= box.min.y;
  }
  instantiate(buildingId: string, x: number, y: number, w: number, h: number): THREE.Group | null {
    const entry = MODEL_FOR[buildingId];
    if (!entry) return null;
    const proto = this.protos.get(entry.file);
    if (!proto) {
      void this.load(entry.file);
      return null;
    }
    const g = proto.clone(true);
    if (entry.tint != null) {
      g.traverse((o) => {
        if (o instanceof THREE.Mesh) {
          const m = o.material as THREE.MeshStandardMaterial;
          if (m && 'color' in m) {
            o.material = m.clone();
            (o.material as THREE.MeshStandardMaterial).color.multiply(
              new THREE.Color(entry.tint!));
          }
        }
      });
    }
    if (entry.scale != null) g.scale.setScalar(entry.scale);
    g.position.set(x + w / 2, 0, y + h / 2);
    // proto carries the baked seat offset; position.set above cleared it
    g.position.y += (proto.userData.seatY as number) ?? 0;
    return g;
  }

  /** Collect animation parts by name prefix into the shared Anim shape. */
  collectAnim(g: THREE.Group): Anim {
    const anim: Anim = {};
    const arms: THREE.Object3D[] = [];
    const rockets: THREE.Object3D[] = [];
    const headCands: THREE.Object3D[] = [];
    g.traverse((o) => {
      const n = o.name;
      if (!n) return;
      if (n.startsWith('Rotor') && !anim.rotor) anim.rotor = o;
      else if (n.startsWith('ArmTip') && !anim.armTip) anim.armTip = o;
      // pipe connectors (ArmX/ArmZ) are static geometry, not moving arms
      else if (/^Arm[XZ]$/.test(n)) return;
      else if (n.startsWith('Arm')) arms.push(o);
      else if (n.startsWith('Beam') && !anim.beam) anim.beam = o;
      else if (n.startsWith('Head')) headCands.push(o);
      else if (n.startsWith('Wheel') && !anim.wheel) anim.wheel = o;
      else if (n.startsWith('Glow') && !anim.glow && o instanceof THREE.Mesh) anim.glow = o;
      else if (n.startsWith('Lamp') && !anim.glow && o instanceof THREE.Mesh) anim.glow = o;
      else if (n.startsWith('Rocket')) rockets.push(o);
    });
    // Prefer the true head (exact 'Head' / 'Head.NNN') over fins and decoys.
    headCands.sort((a, b) => {
      const score = (n: string): number =>
        n === 'Head' ? 0 : /^Head\.\d+$/.test(n) ? 1 : 2;
      return score(a.name) - score(b.name);
    });
    if (headCands.length > 0) anim.head = headCands[0];
    if (arms.length > 0) {
      anim.arm = arms[0];
      anim.arms = arms;
    }
    // Silo rocket is many parts (body/bell/fins/nose/glow); drive them together.
    if (rockets.length > 0) {
      anim.rockets = rockets;
      anim.rocket = rockets.find((o) => o.name === 'RocketRig')
        ?? rockets.find((o) => /^RocketBody/.test(o.name))
        ?? rockets[0];
    }
    return anim;
  }
}
