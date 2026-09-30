// Three.js 3D view: tilted perspective camera, low-poly machines,
// instanced ores/trees, animated belt items, ghost placement preview.
import * as THREE from 'three';
import { BUILDING_MAP } from '../data/buildings';
import type { Game } from '../sim/game';
import type { Ent } from '../sim/world';
import { DIR_VEC } from '../sim/world';

const TILE = 1;

const BODY_COLORS: Record<string, number> = {
  Miner: 0xb87333, Furnace: 0x8a8d91, Assembler: 0x3f7fbf,
  Belt: 0x444444, Inserter: 0xd8d83f, PowerPole: 0x6b4a2b,
  Generator: 0xcc3333, SolarPanel: 0x2233aa, Accumulator: 0x33cc66,
  Turret: 0x555555, Wall: 0x999966, Chest: 0xa06a35,
  Pipe: 0xcccccc, OilRefinery: 0x7a4a8a, ChemicalPlant: 0x4a8a4a,
  FluidTank: 0x9ab8cc, NuclearReactor: 0x66ff66, Centrifuge: 0xaaffaa,
  RocketSilo: 0xdddddd, Lab: 0xffffff, UnitProduction: 0x884422,
  Pumpjack: 0x333388, WaterPump: 0x3388cc,
};

const ORE_COLORS: Record<string, number> = {
  'iron-ore': 0x5a7a9a, 'copper-ore': 0xc47b3a, coal: 0x222222,
  stone: 0x999999, 'uranium-ore': 0x66ff44, 'crude-oil': 0x3a1a5a, wood: 0x2a7a2a,
};

export class View {
  renderer: THREE.WebGLRenderer;
  scene = new THREE.Scene();
  camera: THREE.PerspectiveCamera;
  game: Game;
  target = new THREE.Vector3(0.5, 0, 0.5);
  zoom = 24;
  yaw = Math.PI / 4;
  followPlayer = true;
  ghostId: string | null = null;
  ghostDir: 0 | 1 | 2 | 3 = 0;
  ghostMesh: THREE.Mesh | null = null;
  hoverTile: [number, number] | null = null;
  selectedId: number | null = null;
  onTileClick: ((x: number, y: number, button: number) => void) | null = null;

  private entMeshes = new Map<number, THREE.Group>();
  private beltItems = new Map<number, THREE.Mesh[]>();
  private oreMesh: THREE.InstancedMesh | null = null;
  private treeMesh: THREE.InstancedMesh | null = null;
  private waterMesh: THREE.Mesh | null = null;
  private playerMesh!: THREE.Mesh;
  private enemyMeshes = new Map<number, THREE.Mesh>();
  private lastResCount = -1;
  private lastTreeCount = -1;
  private raycaster = new THREE.Raycaster();
  private groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
  private selBox: THREE.LineSegments;
  private clock = 0;

  constructor(container: HTMLElement, game: Game) {
    this.game = game;
    this.renderer = new THREE.WebGLRenderer({ antialias: true });
    this.renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
    this.renderer.setSize(container.clientWidth, container.clientHeight);
    container.appendChild(this.renderer.domElement);

    this.scene.background = new THREE.Color(0x1a2b1a);
    this.scene.fog = new THREE.Fog(0x1a2b1a, 60, 160);

    this.camera = new THREE.PerspectiveCamera(
      50, container.clientWidth / container.clientHeight, 0.1, 500);

    // lights
    const sun = new THREE.DirectionalLight(0xffffff, 1.6);
    sun.position.set(30, 50, 20);
    this.scene.add(sun);
    this.scene.add(new THREE.AmbientLight(0xffffff, 0.55));
    this.scene.add(new THREE.HemisphereLight(0xbdd7ff, 0x3a5a3a, 0.4));

    // ground
    const ground = new THREE.Mesh(
      new THREE.PlaneGeometry(400, 400),
      new THREE.MeshLambertMaterial({ color: 0x2e4a2e }),
    );
    ground.rotation.x = -Math.PI / 2;
    this.scene.add(ground);
    const grid = new THREE.GridHelper(400, 400, 0x3a5a3a, 0x365236);
    grid.position.y = 0.01;
    this.scene.add(grid);

    // player
    this.playerMesh = new THREE.Mesh(
      new THREE.CylinderGeometry(0.3, 0.35, 0.9, 12),
      new THREE.MeshLambertMaterial({ color: 0xffcc44 }),
    );
    this.playerMesh.position.y = 0.45;
    this.scene.add(this.playerMesh);

    // selection box
    this.selBox = new THREE.LineSegments(
      new THREE.EdgesGeometry(new THREE.BoxGeometry(1.02, 1.02, 1.02)),
      new THREE.LineBasicMaterial({ color: 0xffff00 }),
    );
    this.selBox.visible = false;
    this.scene.add(this.selBox);

    // ghost
    this.bindPointer(container);
    new ResizeObserver(() => {
      this.renderer.setSize(container.clientWidth, container.clientHeight);
      this.camera.aspect = container.clientWidth / container.clientHeight;
      this.camera.updateProjectionMatrix();
    }).observe(container);
  }

  setGhost(id: string | null, dir: 0 | 1 | 2 | 3 = 0): void {
    this.ghostId = id;
    this.ghostDir = dir;
    if (this.ghostMesh) { this.scene.remove(this.ghostMesh); this.ghostMesh = null; }
    if (id) {
      const def = BUILDING_MAP.get(id);
      const w = def?.width ?? 1, h = def?.height ?? 1;
      this.ghostMesh = new THREE.Mesh(
        new THREE.BoxGeometry(w, 0.5, h),
        new THREE.MeshBasicMaterial({ color: 0x00ff00, transparent: true, opacity: 0.4 }),
      );
      this.ghostMesh.position.y = 0.25;
      this.scene.add(this.ghostMesh);
    }
  }

  private bindPointer(container: HTMLElement): void {
    const el = this.renderer.domElement;
    let rmbDown = false;
    let lastX = 0, lastY = 0;
    el.addEventListener('contextmenu', (e) => e.preventDefault());
    el.addEventListener('pointermove', (e) => {
      const rect = el.getBoundingClientRect();
      const nx = ((e.clientX - rect.left) / rect.width) * 2 - 1;
      const ny = -((e.clientY - rect.top) / rect.height) * 2 + 1;
      this.raycaster.setFromCamera(new THREE.Vector2(nx, ny), this.camera);
      const pt = new THREE.Vector3();
      if (this.raycaster.ray.intersectPlane(this.groundPlane, pt)) {
        this.hoverTile = [Math.floor(pt.x), Math.floor(pt.z)];
      }
      if (rmbDown) {
        const dx = (e.clientX - lastX) * 0.02 * (this.zoom / 24);
        const dy = (e.clientY - lastY) * 0.02 * (this.zoom / 24);
        const cos = Math.cos(this.yaw), sin = Math.sin(this.yaw);
        this.target.x -= dx * cos - dy * sin;
        this.target.z -= dy * cos + dx * sin;
        this.followPlayer = false;
        lastX = e.clientX; lastY = e.clientY;
      }
    });
    el.addEventListener('pointerdown', (e) => {
      if (e.button === 2) { rmbDown = true; lastX = e.clientX; lastY = e.clientY; }
    });
    window.addEventListener('pointerup', (e) => {
      if (e.button === 2) rmbDown = false;
    });
    el.addEventListener('click', (e) => {
      if (this.hoverTile) this.onTileClick?.(this.hoverTile[0], this.hoverTile[1], e.button);
    });
    el.addEventListener('wheel', (e) => {
      e.preventDefault();
      this.zoom = Math.min(80, Math.max(6, this.zoom * (1 + Math.sign(e.deltaY) * 0.1)));
    }, { passive: false });
    window.addEventListener('keydown', (e) => {
      if (e.key === 'q' || e.key === 'Q') this.yaw += 0.15;
      if (e.key === 'e' || e.key === 'E') this.yaw -= 0.15;
      if (e.key === 'f' || e.key === 'F') this.followPlayer = true;
    });
  }

  private buildEntityMesh(e: Ent): THREE.Group {
    const def = BUILDING_MAP.get(e.buildingId);
    const g = new THREE.Group();
    const w = def?.width ?? 1, h = def?.height ?? 1;
    const color = BODY_COLORS[def?.type ?? ''] ?? 0x888888;
    const hgt = def?.type === 'Belt' || def?.type === 'Pipe' ? 0.2
      : def?.type === 'RocketSilo' ? 3.5
      : def?.type === 'Wall' ? 0.8 : 1.0;
    const body = new THREE.Mesh(
      new THREE.BoxGeometry(w * 0.92, hgt, h * 0.92),
      new THREE.MeshLambertMaterial({ color }),
    );
    body.position.y = hgt / 2;
    g.add(body);
    // direction nub for belts/inserters/miners
    if (def?.type === 'Belt' || def?.type === 'Inserter' || def?.type === 'Miner') {
      const [dx, dy] = DIR_VEC[e.dir];
      const nub = new THREE.Mesh(
        new THREE.BoxGeometry(0.3, 0.12, 0.3),
        new THREE.MeshBasicMaterial({ color: 0xffff00 }),
      );
      nub.position.set(dx * 0.3, hgt + 0.06, dy * 0.3);
      g.add(nub);
    }
    // power-status lamp
    if ((def?.powerConsumption ?? 0) > 0) {
      const lamp = new THREE.Mesh(
        new THREE.SphereGeometry(0.12, 8, 8),
        new THREE.MeshBasicMaterial({ color: e.satisfaction > 0 ? 0x00ff00 : 0xff0000 }),
      );
      lamp.position.set(-w / 2 + 0.2, hgt + 0.12, -h / 2 + 0.2);
      lamp.name = 'lamp';
      g.add(lamp);
    }
    g.position.set(e.x + w / 2, 0, e.y + h / 2);
    return g;
  }

  private syncEntities(): void {
    const seen = new Set<number>();
    for (const e of this.game.world.entities.values()) {
      seen.add(e.id);
      let g = this.entMeshes.get(e.id);
      if (!g) {
        g = this.buildEntityMesh(e);
        this.entMeshes.set(e.id, g);
        this.scene.add(g);
      }
      const lamp = g.getObjectByName('lamp') as THREE.Mesh | undefined;
      if (lamp) {
        (lamp.material as THREE.MeshBasicMaterial).color.setHex(
          e.satisfaction > 0 ? 0x00ff00 : 0xff0000);
      }
      // belt items
      const def = BUILDING_MAP.get(e.buildingId);
      if (def?.type === 'Belt') {
        let arr = this.beltItems.get(e.id);
        if (!arr) { arr = []; this.beltItems.set(e.id, arr); }
        const want = e.left.length + e.right.length;
        while (arr.length < want) {
          const m = new THREE.Mesh(
            new THREE.BoxGeometry(0.22, 0.12, 0.22),
            new THREE.MeshBasicMaterial({ color: 0xff8800 }),
          );
          arr.push(m);
          this.scene.add(m);
        }
        while (arr.length > want) {
          const m = arr.pop()!;
          this.scene.remove(m);
        }
        let k = 0;
        const [dx, dy] = DIR_VEC[e.dir];
        for (const lane of [e.left, e.right]) {
          const side = lane === e.left ? -0.22 : 0.22;
          const px = -dy * side, pz = dx * side;
          for (const it of lane) {
            const m = arr[k++];
            m.position.set(
              e.x + 0.5 + dx * (it.progress - 0.5) + px,
              0.3,
              e.y + 0.5 + dy * (it.progress - 0.5) + pz,
            );
          }
        }
      }
    }
    for (const [id, g] of this.entMeshes) {
      if (!seen.has(id)) {
        this.scene.remove(g);
        this.entMeshes.delete(id);
        const arr = this.beltItems.get(id);
        if (arr) { for (const m of arr) this.scene.remove(m); this.beltItems.delete(id); }
      }
    }
    // selection
    if (this.selectedId != null) {
      const e = this.game.world.entities.get(this.selectedId);
      if (e) {
        const def = BUILDING_MAP.get(e.buildingId);
        const w = def?.width ?? 1, h = def?.height ?? 1;
        this.selBox.visible = true;
        this.selBox.scale.set(w, 1.2, h);
        this.selBox.position.set(e.x + w / 2, 0.6, e.y + h / 2);
      } else { this.selBox.visible = false; this.selectedId = null; }
    } else this.selBox.visible = false;
  }

  private syncResources(): void {
    const w = this.game.world;
    if (w.resources.size !== this.lastResCount) {
      this.lastResCount = w.resources.size;
      if (this.oreMesh) { this.scene.remove(this.oreMesh); this.oreMesh = null; }
      const deps = [...w.resources.values()];
      this.oreMesh = new THREE.InstancedMesh(
        new THREE.BoxGeometry(0.7, 0.3, 0.7),
        new THREE.MeshLambertMaterial({ color: 0xffffff }),
        Math.max(1, deps.length),
      );
      const m = new THREE.Matrix4();
      const c = new THREE.Color();
      deps.forEach((d, i) => {
        m.makeTranslation(d.x + 0.5, 0.15, d.y + 0.5);
        this.oreMesh!.setMatrixAt(i, m);
        this.oreMesh!.setColorAt(i, c.setHex(ORE_COLORS[d.outputItem] ?? 0x888888));
      });
      this.oreMesh.instanceMatrix.needsUpdate = true;
      if (this.oreMesh.instanceColor) this.oreMesh.instanceColor.needsUpdate = true;
      this.scene.add(this.oreMesh);
    }
    if (w.trees.size !== this.lastTreeCount) {
      this.lastTreeCount = w.trees.size;
      if (this.treeMesh) { this.scene.remove(this.treeMesh); this.treeMesh = null; }
      const trees = [...w.trees.keys()];
      this.treeMesh = new THREE.InstancedMesh(
        new THREE.ConeGeometry(0.35, 1.2, 6),
        new THREE.MeshLambertMaterial({ color: 0x2a7a2a }),
        Math.max(1, trees.length),
      );
      const m = new THREE.Matrix4();
      trees.forEach((k, i) => {
        const [x, y] = k.split(',').map(Number);
        m.makeTranslation(x + 0.5, 0.6, y + 0.5);
        this.treeMesh!.setMatrixAt(i, m);
      });
      this.treeMesh.instanceMatrix.needsUpdate = true;
      this.scene.add(this.treeMesh);
    }
    if (!this.waterMesh && w.water.size > 0) {
      const pts = [...w.water].map((k) => k.split(',').map(Number));
      const geo = new THREE.BufferGeometry();
      const verts: number[] = [];
      for (const [x, y] of pts) {
        verts.push(x, 0.02, y, x + 1, 0.02, y, x + 1, 0.02, y + 1);
        verts.push(x, 0.02, y, x + 1, 0.02, y + 1, x, 0.02, y +  1);
      }
      geo.setAttribute('position', new THREE.Float32BufferAttribute(verts, 3));
      geo.computeVertexNormals();
      this.waterMesh = new THREE.Mesh(geo,
        new THREE.MeshLambertMaterial({ color: 0x2266cc, transparent: true, opacity: 0.85 }));
      this.scene.add(this.waterMesh);
    }
  }

  private syncActors(): void {
    const p = this.game.player;
    this.playerMesh.position.set(p.x, 0.45, p.y);
    (this.playerMesh.material as THREE.MeshLambertMaterial).color.setHex(
      p.dead ? 0x555555 : 0xffcc44);
    const seen = new Set<number>();
    for (const en of this.game.enemies) {
      seen.add(en.id);
      let m = this.enemyMeshes.get(en.id);
      if (!m) {
        m = new THREE.Mesh(
          new THREE.SphereGeometry(0.35, 8, 8),
          new THREE.MeshLambertMaterial({ color: 0xcc2222 }),
        );
        this.enemyMeshes.set(en.id, m);
        this.scene.add(m);
      }
      m.position.set(en.x, 0.35, en.y);
    }
    for (const [id, m] of this.enemyMeshes) {
      if (!seen.has(id)) { this.scene.remove(m); this.enemyMeshes.delete(id); }
    }
  }

  update(dt: number): void {
    this.clock += dt;
    if (this.followPlayer) {
      this.target.x += (this.game.player.x - this.target.x) * Math.min(1, dt * 5);
      this.target.z += (this.game.player.y - this.target.z) * Math.min(1, dt * 5);
    }
    const pit = 0.9; // steep-ish 3D view
    this.camera.position.set(
      this.target.x + Math.cos(this.yaw) * this.zoom * Math.cos(pit),
      this.zoom * Math.sin(pit),
      this.target.z + Math.sin(this.yaw) * this.zoom * Math.cos(pit),
    );
    this.camera.lookAt(this.target);
    if (this.ghostMesh && this.hoverTile) {
      const def = this.ghostId ? BUILDING_MAP.get(this.ghostId) : undefined;
      const w = def?.width ?? 1, h = def?.height ?? 1;
      this.ghostMesh.position.set(this.hoverTile[0] + w / 2, 0.25, this.hoverTile[1] + h / 2);
      const ok = this.game.world.canPlace(this.ghostId!, this.hoverTile[0], this.hoverTile[1]).ok;
      (this.ghostMesh.material as THREE.MeshBasicMaterial).color.setHex(ok ? 0x00ff00 : 0xff0000);
      this.ghostMesh.visible = true;
    } else if (this.ghostMesh) this.ghostMesh.visible = false;
    this.syncEntities();
    this.syncResources();
    this.syncActors();
    this.renderer.render(this.scene, this.camera);
  }
}
