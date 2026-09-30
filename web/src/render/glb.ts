// GLB hero models (Blender-authored) + prefix animation convention.
// File per building; animatable parts found by name prefix:
// Rotor* (spin) | Arm* (bob/swing) | Beam* (rock) | Head* (aim) |
// Wheel* (spin) | Rocket* (rise group) | Glow* (flicker) | Lamp* (power color)
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import type { Anim } from './models';

interface Entry { file: string; tint?: number; scale?: number; }

/** buildingId -> GLB. Unlisted ids use the procedural fallback. */
export const MODEL_FOR: Record<string, Entry> = {
  'burner-mining-drill': { file: '/models/ff-burner-drill.glb' },
  'electric-mining-drill': { file: '/models/ff-electric-drill.glb' },
  pumpjack: { file: '/models/ff-pumpjack.glb' },
  'water-pump': { file: '/models/ff-waterpump.glb' },
  'offshore-pump': { file: '/models/ff-waterpump.glb' },
  'stone-furnace': { file: '/models/ff-stone-furnace.glb' },
  'steel-furnace': { file: '/models/ff-steel-furnace.glb' },
  'electric-furnace': { file: '/models/ff-electric-furnace.glb' },
  'assembling-machine-1': { file: '/models/ff-assembler.glb' },
  'assembling-machine-2': { file: '/models/ff-assembler.glb', tint: 0xbfe0ff },
  'assembling-machine-3': { file: '/models/ff-assembler.glb', tint: 0xffe0b0 },
  'transport-belt': { file: '/models/ff-belt.glb' },
  'fast-transport-belt': { file: '/models/ff-belt.glb', tint: 0xffd070 },
  'express-transport-belt': { file: '/models/ff-belt.glb', tint: 0x70c0ff },
  'underground-belt': { file: '/models/ff-belt.glb' },
  splitter: { file: '/models/ff-belt.glb' },
  merger: { file: '/models/ff-belt.glb' },
  'belt-bridge': { file: '/models/ff-belt.glb' },
  inserter: { file: '/models/ff-inserter.glb' },
  'long-handed-inserter': { file: '/models/ff-inserter.glb', scale: 1.25 },
  'fast-inserter': { file: '/models/ff-inserter.glb', tint: 0xffd070 },
  'stack-inserter': { file: '/models/ff-inserter.glb', tint: 0x70c0ff },
  'small-electric-pole': { file: '/models/ff-pole.glb' },
  'medium-electric-pole': { file: '/models/ff-pole.glb', scale: 1.2 },
  'big-electric-pole': { file: '/models/ff-pole.glb', scale: 1.6 },
  boiler: { file: '/models/ff-boiler.glb' },
  'steam-engine': { file: '/models/ff-steam-engine.glb' },
  'solar-panel': { file: '/models/ff-solar.glb' },
  accumulator: { file: '/models/ff-accumulator.glb' },
  'gun-turret': { file: '/models/ff-gun-turret.glb' },
  'laser-turret': { file: '/models/ff-laser-turret.glb' },
  'stone-wall': { file: '/models/ff-wall.glb' },
  'wooden-chest': { file: '/models/ff-chest.glb' },
  'iron-chest': { file: '/models/ff-chest.glb', tint: 0xc0c8d0 },
  'steel-chest': { file: '/models/ff-chest.glb', tint: 0x90a0b0 },
  'oil-refinery': { file: '/models/ff-refinery.glb' },
  'chemical-plant': { file: '/models/ff-chemplant.glb' },
  pipe: { file: '/models/ff-pipe.glb' },
  'underground-pipe': { file: '/models/ff-pipe.glb' },
  'fluid-tank': { file: '/models/ff-tank.glb' },
  'nuclear-reactor': { file: '/models/ff-reactor.glb' },
  centrifuge: { file: '/models/ff-centrifuge.glb' },
  'rocket-silo': { file: '/models/ff-silo.glb' },
  lab: { file: '/models/ff-lab.glb' },
};

export const PLAYER_GLB = '/models/ff-player.glb';
export const BITER_GLB = '/models/ff-biter.glb';
export const SPITTER_GLB = '/models/ff-spitter.glb';
export const NEST_GLB = '/models/ff-nest.glb';

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
        this.protos.set(file, scene);
        res(scene);
      }, undefined, rej);
    });
    this.pending.set(file, p);
    return p;
  }

  /** Instantiate a building GLB centered on tile footprint (x,y top-left). */
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
    return g;
  }

  /** Collect animation parts by name prefix into the shared Anim shape. */
  collectAnim(g: THREE.Group): Anim {
    const anim: Anim = {};
    const arms: THREE.Object3D[] = [];
    let rocket: THREE.Object3D | null = null;
    g.traverse((o) => {
      const n = o.name;
      if (n.startsWith('Rotor') && !anim.rotor) anim.rotor = o;
      else if (n.startsWith('ArmTip') && !anim.armTip) anim.armTip = o;
      else if (n.startsWith('Arm')) arms.push(o);
      else if (n.startsWith('Beam') && !anim.beam) anim.beam = o;
      else if (n.startsWith('Head') && !anim.head) anim.head = o;
      else if (n.startsWith('Wheel') && !anim.wheel) anim.wheel = o;
      else if (n.startsWith('Glow') && !anim.glow && o instanceof THREE.Mesh) anim.glow = o;
      else if (n.startsWith('Lamp') && !anim.glow && o instanceof THREE.Mesh) anim.glow = o;
      else if (n === 'RocketRig') rocket = o;
      else if (n.startsWith('Rocket') && !rocket) rocket = o;
    });
    if (arms.length > 0) {
      anim.arm = arms[0];
      anim.arms = arms;
    }
    if (rocket) anim.rocket = rocket;
    return anim;
  }
}
