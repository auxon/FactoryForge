// Procedural 3D models for every building type + sprite emblems.
// Each builder returns { group, anim } where anim parts are posed per-frame
// by the view (rotor spin, arm swing, glow flicker, ...).
import * as THREE from 'three';
import { BUILDING_MAP } from '../data/buildings';
import type { Ent } from '../sim/world';
import { DIR_VEC } from '../sim/world';

export interface Anim {
  rotor?: THREE.Object3D;   // spins when active (drill bit, centrifuge)
  wheel?: THREE.Object3D;   // steam flywheel
  beam?: THREE.Object3D;    // pumpjack walking beam (sine rock)
  arm?: THREE.Object3D;     // inserter arm (swings)
  armTip?: THREE.Object3D;  // held-item mount
  arms?: THREE.Object3D[];  // assembler press arms (bob)
  head?: THREE.Object3D;    // turret head (aims)
  glow?: THREE.Mesh;        // emissive fire/activity lamp
  rocket?: THREE.Object3D;  // silo rocket representative part (rises on launch)
  rockets?: THREE.Object3D[]; // ALL silo rocket parts (visibility driven together)
  smoke?: boolean;          // emits smoke when active
}

const texCache = new Map<string, THREE.Texture | null>();
const loader = new THREE.TextureLoader();

const EMBLEM_FALLBACK: Record<string, string> = {
  'burner-mining-drill': 'electric_mining_drill',
  'steel-furnace': 'furnace', 'stone-furnace': 'furnace',
  'assembling-machine-1': 'assembler', 'assembling-machine-2': 'assembler',
  'fast-transport-belt': 'transport_belt', 'express-transport-belt': 'transport_belt',
  'underground-belt': 'transport_belt', 'splitter': 'transport_belt',
  'merger': 'transport_belt', 'belt-bridge': 'transport_belt',
  'long-handed-inserter': 'inserter', 'fast-inserter': 'inserter', 'stack-inserter': 'inserter',
  'chemical-plant': 'chemical_plant', 'oil-refinery': 'oil_refinery',
  'electric-furnace': 'electric_furnace', 'electric-mining-drill': 'electric_mining_drill',
  'assembling-machine-3': 'assembling_machine_3',
};

function emblem(textureId: string, size: number, y: number): THREE.Mesh | null {
  const key = EMBLEM_FALLBACK[textureId] ?? textureId;
  let tex = texCache.get(key);
  if (tex === undefined) {
    tex = null;
    const base = (import.meta.env.BASE_URL || '/');
    loader.load(`${base}assets/${key}.png`.replace(/\/+/g, '/'),
      (t) => {
        t.magFilter = THREE.NearestFilter;
        t.minFilter = THREE.NearestFilter;
        texCache.set(key, t);
        const m = matCache.get(key);
        if (m) { m.map = t; m.needsUpdate = true; }
      },
      undefined,
      () => texCache.set(key, null));
    texCache.set(key, tex);
  }
  const mat = new THREE.MeshBasicMaterial({
    map: tex ?? undefined, transparent: true, alphaTest: 0.4,
  });
  matCache.set(key, mat);
  const m = new THREE.Mesh(new THREE.PlaneGeometry(size, size), mat);
  m.rotation.x = -Math.PI / 2;
  m.position.y = y;
  return m;
}
const matCache = new Map<string, THREE.MeshBasicMaterial>();

const lam = (color: number, emissive = 0x000000): THREE.MeshLambertMaterial =>
  new THREE.MeshLambertMaterial({ color, emissive });

function box(w: number, h: number, d: number, color: number, x = 0, y = 0, z = 0, emissive = 0): THREE.Mesh {
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), lam(color, emissive));
  m.position.set(x, y, z);
  m.castShadow = true;
  return m;
}
function cyl(rt: number, rb: number, h: number, color: number, x = 0, y = 0, z = 0, seg = 12): THREE.Mesh {
  const m = new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, h, seg), lam(color));
  m.position.set(x, y, z);
  m.castShadow = true;
  return m;
}

export const ITEM_COLORS: Record<string, number> = {
  'iron-ore': 0x5a7a9a, 'iron-plate': 0xb9c8d4, 'copper-ore': 0xc47b3a,
  'copper-plate': 0xe09a5a, coal: 0x1c1c1c, stone: 0x8f8f8f,
  'stone-brick': 0xa08060, 'iron-gear-wheel': 0x9aa2aa, 'copper-cable': 0xd86a3a,
  wood: 0x7a5230, steel: 0x6a6a72, 'steel-plate': 0x77777f,
  'electronic-circuit': 0x2a9a4a, 'advanced-circuit': 0xcc3333,
  'processing-unit': 0x3344cc, 'automation-science-pack': 0xcc3333,
  'logistic-science-pack': 0x33aa66, 'chemical-science-pack': 0x3399cc,
  'military-science-pack': 0x555555, 'production-science-pack': 0xaa33aa,
  'utility-science-pack': 0xcccc33, 'space-science-pack': 0xdddddd,
  'firearm-magazine': 0x444444, 'piercing-rounds-magazine': 0x882222,
  plastic: 0xdddddd, 'plastic-bar': 0xdddddd, battery: 0x33cc66,
  sulfur: 0xcccc44, 'solid-fuel': 0x666644, 'rocket-fuel': 0xaaaaff,
  'rocket-parts': 0xcccccc, satellite: 0x88aaff, 'uranium-ore': 0x66ff44,
};

export function itemColor(id: string): number {
  return ITEM_COLORS[id] ?? 0xff8800;
}

export function buildModel(e: Ent): { group: THREE.Group; anim: Anim } {
  const def = BUILDING_MAP.get(e.buildingId);
  const type = def?.type ?? '';
  const w = def?.width ?? 1, h = def?.height ?? 1;
  const g = new THREE.Group();
  const anim: Anim = {};
  const [dx, dz] = DIR_VEC[e.dir];
  const add = (o: THREE.Object3D): void => { g.add(o); };
  const topEmblem = (tex: string, s = Math.min(w, h) * 0.62): void => {
    const m = emblem(tex, s, modelHeight(type) + 0.03);
    if (m) add(m);
  };

  switch (type) {
    case 'Miner': {
      const burner = e.buildingId.startsWith('burner');
      add(box(w * 0.9, 0.5, h * 0.9, burner ? 0x6a3a22 : 0x4a453c, 0, 0.25, 0));
      add(box(w * 0.5, 0.9, h * 0.5, 0x8a6a2a, 0, 0.9, 0));
      const rotor = new THREE.Group();
      const bit = cyl(0.12, 0.02, 1.1, 0xcccccc, 0, -0.4, 0, 8);
      rotor.add(bit);
      rotor.position.set(0, 1.3, 0);
      add(rotor);
      anim.rotor = rotor;
      anim.smoke = burner;
      const glow = new THREE.Mesh(new THREE.SphereGeometry(0.12, 8, 8),
        new THREE.MeshBasicMaterial({ color: 0xff6600 }));
      glow.position.set(-w / 2 + 0.25, 0.6, -h / 2 + 0.25);
      add(glow); anim.glow = glow;
      break;
    }
    case 'Furnace': {
      add(box(w * 0.9, 1.1, h * 0.9, 0x6a6a72, 0, 0.55, 0));
      add(box(0.5, 1.6, 0.5, 0x4a4a52, w * 0.2, 1.2, -h * 0.2)); // chimney
      const mouth = new THREE.Mesh(new THREE.PlaneGeometry(0.7, 0.4),
        new THREE.MeshBasicMaterial({ color: 0xff5500 }));
      mouth.position.set(0, 0.45, h * 0.46);
      add(mouth); anim.glow = mouth;
      anim.smoke = true;
      topEmblem(e.buildingId);
      break;
    }
    case 'Assembler': {
      add(box(w * 0.9, 0.9, h * 0.9, 0x4a453c, 0, 0.45, 0));
      add(box(w * 0.7, 0.25, h * 0.7, 0xb08a3a, 0, 1.0, 0)); // brass top
      anim.arms = [];
      for (const s of [-1, 1]) {
        const arm = box(0.25, 0.7, 0.25, 0xc4a24a, s * w * 0.25, 1.3, 0);
        add(arm); anim.arms.push(arm);
      }
      topEmblem(e.buildingId);
      break;
    }
    case 'Belt': {
      add(box(w * 0.96, 0.18, h * 0.96, 0x2c2c30, 0, 0.09, 0));
      add(box(0.08, 0.3, h * 0.96, 0x55555c, -w * 0.44, 0.2, 0));
      add(box(0.08, 0.3, h * 0.96, 0x55555c, w * 0.44, 0.2, 0));
      const nub = box(0.3, 0.1, 0.3, 0xffcc33, dx * 0.28, 0.24, dz * 0.28);
      (nub.material as THREE.MeshLambertMaterial).emissive.setHex(0x664400);
      add(nub);
      break;
    }
    case 'Inserter': {
      add(box(0.7, 0.25, 0.7, 0x8a8a3a, 0, 0.12, 0));
      add(cyl(0.18, 0.24, 0.5, 0x5a5a5e, 0, 0.4, 0));
      const arm = new THREE.Group();
      const bar = box(0.16, 0.12, 1.5, 0xd8d83f, 0, 0, 0);
      arm.add(bar);
      const tip = new THREE.Group();
      tip.position.set(0, 0, 0.7);
      arm.add(tip);
      arm.position.set(0, 0.7, 0);
      arm.rotation.y = Math.atan2(dx, dz);
      add(arm);
      anim.arm = arm; anim.armTip = tip;
      break;
    }
    case 'PowerPole': {
      const big = e.buildingId.startsWith('big');
      add(cyl(0.09, 0.12, big ? 3.2 : 2.2, 0x6b4a2b, 0, big ? 1.6 : 1.1, 0, 8));
      add(box(big ? 2.0 : 1.2, 0.1, 0.1, 0x6b4a2b, 0, big ? 2.9 : 2.0, 0));
      break;
    }
    case 'Generator': {
      if (e.buildingId === 'boiler') {
        add(box(1.8, 1.2, 2.6, 0x6a3a22, 0, 0.6, 0));
        add(box(0.5, 2.0, 0.5, 0x3a322c, 0.4, 1.6, -0.8));
        const glow = new THREE.Mesh(new THREE.PlaneGeometry(0.8, 0.5),
          new THREE.MeshBasicMaterial({ color: 0xff5500 }));
        glow.position.set(0, 0.5, 1.32);
        add(glow); anim.glow = glow; anim.smoke = true;
      } else { // steam engine
        add(box(2.6, 0.8, 1.4, 0x4a453c, 0, 0.4, 0));
        add(cyl(0.5, 0.5, 2.2, 0xb08a3a, 0, 0.7, 0));
        const wheel = new THREE.Mesh(new THREE.TorusGeometry(0.7, 0.12, 8, 20), lam(0x2a2622));
        wheel.position.set(-1.5, 0.8, 0);
        wheel.rotation.y = Math.PI / 2;
        wheel.castShadow = true;
        add(wheel); anim.wheel = wheel;
        topEmblem('steam_engine', 1.2);
      }
      break;
    }
    case 'SolarPanel': {
      add(box(2.6, 0.15, 0.3, 0x555555, 0, 0.4, 1.1));
      const panel = box(2.7, 0.1, 2.4, 0x1a3a8a, 0, 1.0, 0);
      panel.rotation.x = -0.35;
      add(panel);
      add(box(2.7, 0.02, 2.4, 0x3a6adf, 0, 1.02, 0));
      break;
    }
    case 'Accumulator': {
      add(box(1.7, 1.0, 1.7, 0x2a7a4a, 0, 0.5, 0));
      const bar = box(1.4, 0.2, 0.2, 0x33ff66, 0, 1.1, 0.8);
      (bar.material as THREE.MeshLambertMaterial).emissive.setHex(0x00aa33);
      add(bar); anim.glow = bar;
      break;
    }
    case 'Turret': {
      const laser = e.buildingId.startsWith('laser');
      add(box(w * 0.8, 0.5, h * 0.8, 0x4a4a52, 0, 0.25, 0));
      const head = new THREE.Group();
      head.add(box(0.8, 0.5, 0.8, laser ? 0x3a3a6a : 0x5a5a62, 0, 0, 0));
      const barrel = cyl(0.09, 0.11, laser ? 1.0 : 1.4, laser ? 0x66aaff : 0x222222, 0, 0.1, laser ? 0.8 : 1.0, 8);
      barrel.rotation.x = Math.PI / 2;
      head.add(barrel);
      head.position.set(0, 0.85, 0);
      add(head); anim.head = head;
      topEmblem(e.buildingId, 1.0);
      break;
    }
    case 'Wall': {
      add(box(0.95, 0.8, 0.95, 0x999966, 0, 0.4, 0));
      add(box(0.99, 0.2, 0.99, 0xb0b088, 0, 0.9, 0));
      break;
    }
    case 'Chest': {
      add(box(0.9, 0.6, 0.9, 0xa06a35, 0, 0.3, 0));
      add(box(0.95, 0.18, 0.95, 0x7a4e26, 0, 0.68, 0));
      break;
    }
    case 'Pipe': {
      const under = e.buildingId.startsWith('underground');
      if (under) add(box(0.9, 0.35, 0.9, 0x77777f, 0, 0.17, 0));
      else {
        const p = cyl(0.28, 0.28, 0.9, 0xb8b8c0, 0, 0.28, 0, 10);
        p.rotation.z = Math.PI / 2;
        add(p);
      }
      break;
    }
    case 'Pumpjack': case 'WaterPump': {
      const water = type === 'WaterPump';
      add(box(0.9, 0.4, 0.9, water ? 0x3388cc : 0x333388, 0, 0.2, 0));
      add(box(0.3, 1.2, 0.3, 0x555555, -0.2, 0.9, 0));
      const beam = new THREE.Group();
      beam.add(box(1.8, 0.18, 0.25, water ? 0x66aadd : 0x888888, 0.5, 0, 0));
      beam.add(box(0.25, 0.9, 0.25, 0x666666, 1.2, -0.45, 0));
      beam.position.set(-0.2, 1.6, 0);
      add(beam); anim.beam = beam;
      break;
    }
    case 'OilRefinery': {
      add(box(2.6, 1.2, 2.6, 0x6a3a6a, 0, 0.6, 0));
      add(cyl(0.7, 0.7, 2.6, 0x8a5a8a, -0.7, 1.9, -0.7));
      add(cyl(0.5, 0.5, 3.2, 0x9a6a9a, 0.8, 2.2, 0.6));
      anim.smoke = true;
      topEmblem('oil_refinery', 1.4);
      break;
    }
    case 'ChemicalPlant': {
      add(box(2.4, 1.0, 2.4, 0x3a7a3a, 0, 0.5, 0));
      const tank = new THREE.Mesh(new THREE.SphereGeometry(0.9, 14, 12), lam(0x9ac8e8));
      tank.position.set(0, 1.6, 0);
      tank.castShadow = true;
      add(tank);
      topEmblem('chemical_plant', 1.2);
      break;
    }
    case 'FluidTank': {
      add(cyl(1.3, 1.3, 2.2, 0x9ab8cc, 0, 1.1, 0, 16));
      add(cyl(1.35, 1.35, 0.15, 0x7a98ac, 0, 2.25, 0, 16));
      break;
    }
    case 'NuclearReactor': {
      add(cyl(2.0, 2.2, 2.0, 0x4a8a6a, 0, 1.0, 0, 16));
      const glow = cyl(0.8, 0.8, 2.2, 0x66ff66, 0, 1.1, 0, 12);
      (glow.material as THREE.MeshLambertMaterial).emissive.setHex(0x00cc44);
      add(glow); anim.glow = glow;
      break;
    }
    case 'Centrifuge': {
      add(cyl(1.2, 1.3, 0.8, 0x8a9a8a, 0, 0.4, 0, 14));
      const rotor = cyl(0.7, 0.7, 0.7, 0xccffcc, 0, 1.1, 0, 12);
      add(rotor); anim.rotor = rotor;
      break;
    }
    case 'RocketSilo': {
      add(cyl(3.6, 4.0, 0.6, 0x666666, 0, 0.3, 0, 8));
      add(box(1.2, 3.4, 1.2, 0x888888, -3.2, 1.7, -3.2));
      const rocket = new THREE.Group();
      rocket.add(cyl(0.7, 0.7, 2.6, 0xdddddd, 0, 1.3, 0, 12));
      rocket.add(cyl(0.01, 0.7, 1.0, 0xcc3333, 0, 3.1, 0, 12));
      rocket.position.set(0, e.assembled ? 0.6 : -3.2, 0);
      rocket.visible = e.assembled;
      add(rocket); anim.rocket = rocket;
      topEmblem('rocket_silo', 3.0);
      break;
    }
    case 'Lab': {
      add(box(2.6, 0.9, 2.6, 0xe8e8e8, 0, 0.45, 0));
      const dome = new THREE.Mesh(new THREE.SphereGeometry(1.0, 14, 10, 0, Math.PI * 2, 0, Math.PI / 2), lam(0x9ad8f8));
      dome.position.set(0, 0.9, 0);
      dome.castShadow = true;
      add(dome);
      const flask = new THREE.Mesh(new THREE.SphereGeometry(0.3, 10, 8),
        new THREE.MeshBasicMaterial({ color: 0xff44ff }));
      flask.position.set(0, 1.2, 0);
      add(flask); anim.glow = flask;
      topEmblem('lab', 1.2);
      break;
    }
    case 'UnitProduction': {
      add(box(w * 0.85, 1.2, h * 0.85, 0x884422, 0, 0.6, 0));
      add(box(w * 0.6, 0.8, h * 0.6, 0xaa6633, 0, 1.6, 0));
      break;
    }
    default: {
      add(box(w * 0.9, 0.8, h * 0.9, 0x888888, 0, 0.4, 0));
    }
  }

  // power-status lamp
  const def2 = BUILDING_MAP.get(e.buildingId);
  if ((def2?.powerConsumption ?? 0) > 0) {
    const lamp = new THREE.Mesh(new THREE.SphereGeometry(0.13, 8, 8),
      new THREE.MeshBasicMaterial({ color: 0x00ff00 }));
    lamp.position.set(-w / 2 + 0.25, modelHeight(type) + 0.15, -h / 2 + 0.25);
    lamp.name = 'lamp';
    add(lamp);
  }

  g.position.set(e.x + w / 2, 0, e.y + h / 2);
  return { group: g, anim };
}

export function modelHeight(type: string): number {
  switch (type) {
    case 'RocketSilo': return 3.6;
    case 'OilRefinery': return 3.4;
    case 'NuclearReactor': return 2.2;
    case 'FluidTank': return 2.4;
    case 'Belt': case 'Pipe': return 0.35;
    case 'Wall': return 1.0;
    case 'PowerPole': return 3.0;
    default: return 1.4;
  }
}

/** Is this machine visually "running" right now? */
export function isActive(e: Ent): boolean {
  const def = BUILDING_MAP.get(e.buildingId);
  const t = def?.type ?? '';
  const powered = (def?.powerConsumption ?? 0) === 0 || e.satisfaction > 0;
  switch (t) {
    case 'Miner': return e.fuel > 0 || (powered && e.progress > 0);
    case 'Furnace': return e.progress > 0 || e.recipeId != null;
    case 'Assembler': case 'ChemicalPlant': case 'OilRefinery': case 'Centrifuge':
      return powered && e.recipeId != null && e.progress > 0;
    case 'Lab': return e.researching && powered;
    case 'Pumpjack': case 'WaterPump': return powered;
    case 'Generator': return e.fuel > 0 || t === 'Generator';
    case 'Inserter': return powered;
    case 'Turret': return true;
    case 'RocketSilo': return e.launching;
    default: return false;
  }
}
