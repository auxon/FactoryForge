// Three.js 3D view: tilted perspective camera, procedural machine models
// with sprite emblems, pole wires, smoke, shadows, animated parts.
import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { BUILDING_MAP } from '../data/buildings';
import type { Game } from '../sim/game';
import type { Ent } from '../sim/world';
import { DIR_VEC } from '../sim/world';
import { buildModel, isActive, itemColor, type Anim } from './models';
import { GlbLibrary, MODEL_FOR, PLAYER_GLB, BITER_GLB, SPITTER_GLB, NEST_GLB } from './glb';
import { Nature, bakeTerrainCanvas } from './nature';

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
  private anims = new Map<number, Anim>();
  private glb = new GlbLibrary();
  private glbFileOf = new Map<number, string>();
  private beltItems = new Map<number, THREE.Mesh[]>();
  private oreMesh: THREE.InstancedMesh | null = null;
  private trunkMesh: THREE.InstancedMesh | null = null;
  private leafMesh: THREE.InstancedMesh | null = null;
  private waterMesh: THREE.Mesh | null = null;
  private wireLines: THREE.LineSegments | null = null;
  private playerMesh!: THREE.Group;
  private enemyMeshes = new Map<number, THREE.Group>();
  private spawnerMeshes = new Map<number, THREE.Group>();
  private lastResCount = -1;
  private lastTreeCount = -1;
  private lastEntCount = -1;
  private raycaster = new THREE.Raycaster();
  private groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
  private selBox: THREE.LineSegments;
  private selLabel: THREE.Sprite | null = null;
  private selLabelCanvas: HTMLCanvasElement;
  private selLabelTex: THREE.CanvasTexture;
  private clock = 0;
  private labelTimer = 0;
  // smoke: one Points cloud, 14 particles per emitter
  private smokeGeo!: THREE.BufferGeometry;
  private smokePts!: THREE.Points;
  private smokeData: { x: number; y: number; z: number; life: number }[] = [];
  private waterMat!: THREE.MeshLambertMaterial;
  private nature: Nature;
  private legacyTrees = true;

  constructor(container: HTMLElement, game: Game) {
    this.game = game;
    this.renderer = new THREE.WebGLRenderer({ antialias: true });
    this.renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
    this.renderer.setSize(container.clientWidth, container.clientHeight);
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.28;
    container.appendChild(this.renderer.domElement);

    this.scene.background = new THREE.Color(0x7d93a6);
    this.scene.fog = new THREE.Fog(0x7d93a6, 64, 165);

    this.camera = new THREE.PerspectiveCamera(
      50, container.clientWidth / container.clientHeight, 0.1, 600);

    const pmrem = new THREE.PMREMGenerator(this.renderer);
    this.scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.02).texture;
    this.scene.environmentIntensity = 0.95;
    pmrem.dispose();

    const sun = new THREE.DirectionalLight(0xffe6c0, 2.85);
    sun.position.set(36, 52, 22);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    sun.shadow.camera.left = -60; sun.shadow.camera.right = 60;
    sun.shadow.camera.top = 60; sun.shadow.camera.bottom = -60;
    sun.shadow.camera.far = 200;
    this.scene.add(sun);
    this.scene.add(new THREE.AmbientLight(0xfff4e4, 0.45));
    this.scene.add(new THREE.HemisphereLight(0xffe2b8, 0x4a3a28, 0.62));

    // ground: baked PBR zone canvas (grass/dirt/sand per world features)
    const zoneTex = new THREE.CanvasTexture(
      bakeTerrainCanvas(game.world, game.world.seed));
    zoneTex.colorSpace = THREE.SRGBColorSpace;
    zoneTex.anisotropy = 4;
    const ground = new THREE.Mesh(
      new THREE.PlaneGeometry(400, 400),
      new THREE.MeshStandardMaterial({ map: zoneTex, roughness: 0.95, metalness: 0 }),
    );
    ground.rotation.x = -Math.PI / 2;
    ground.receiveShadow = true;
    this.scene.add(ground);
    // close-up PBR detail overlay: repeating grass diffuse+normal, translucent
    const texLoader = new THREE.TextureLoader();
    const base = (import.meta.env.BASE_URL || '/');
    const T = (f: string): string => `${base}tex/${f}`.replace(/\/+/g, '/');
    const gDiff = texLoader.load(T('leafy_grass_Diffuse.jpg'));
    gDiff.wrapS = gDiff.wrapT = THREE.RepeatWrapping;
    gDiff.repeat.set(110, 110);
    gDiff.colorSpace = THREE.SRGBColorSpace;
    const gNor = texLoader.load(T('leafy_grass_nor_gl.png'));
    gNor.wrapS = gNor.wrapT = THREE.RepeatWrapping;
    gNor.repeat.set(110, 110);
    const detail = new THREE.Mesh(
      new THREE.PlaneGeometry(400, 400),
      new THREE.MeshStandardMaterial({
        map: gDiff, normalMap: gNor, normalScale: new THREE.Vector2(0.6, 0.6),
        transparent: true, opacity: 0.42, roughness: 1,
        depthWrite: false,
      }),
    );
    detail.rotation.x = -Math.PI / 2;
    detail.position.y = 0.015;
    detail.renderOrder = 1;
    this.scene.add(detail);
    const grid = new THREE.GridHelper(400, 400, 0x4a6a4a, 0x3d5c3d);
    grid.position.y = 0.02;
    (grid.material as THREE.Material).transparent = true;
    (grid.material as THREE.Material).opacity = 0.35;
    this.scene.add(grid);

    this.buildPlayer();
    this.nature = new Nature(this.scene, game.world, game.world.seed);
    // hero actors: swap to GLB when loaded
    for (const f of [PLAYER_GLB, BITER_GLB, SPITTER_GLB, NEST_GLB]) {
      void this.glb.load(f).then(() => this.onGlbFileReady(f));
    }

    this.selBox = new THREE.LineSegments(
      new THREE.EdgesGeometry(new THREE.BoxGeometry(1.02, 1.02, 1.02)),
      new THREE.LineBasicMaterial({ color: 0xffff00 }),
    );
    this.selBox.visible = false;
    this.scene.add(this.selBox);

    this.selLabelCanvas = document.createElement('canvas');
    this.selLabelCanvas.width = 512; this.selLabelCanvas.height = 96;
    this.selLabelTex = new THREE.CanvasTexture(this.selLabelCanvas);
    this.selLabel = new THREE.Sprite(new THREE.SpriteMaterial({
      map: this.selLabelTex, depthTest: false, transparent: true,
    }));
    this.selLabel.scale.set(6, 1.1, 1);
    this.selLabel.visible = false;
    this.scene.add(this.selLabel);

    // smoke cloud
    const MAXP = 64 * 14;
    const pos = new Float32Array(MAXP * 3).fill(-999);
    this.smokeGeo = new THREE.BufferGeometry();
    this.smokeGeo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    this.smokePts = new THREE.Points(this.smokeGeo, new THREE.PointsMaterial({
      color: 0xddd4c4, size: 0.68, transparent: true, opacity: 0.38,
      depthWrite: false,
    }));
    this.smokePts.frustumCulled = false;
    this.scene.add(this.smokePts);
    for (let i = 0; i < MAXP; i++) this.smokeData.push({ x: 0, y: -999, z: 0, life: Math.random() });

    this.bindPointer(container);
    new ResizeObserver(() => {
      this.renderer.setSize(container.clientWidth, container.clientHeight);
      this.camera.aspect = container.clientWidth / container.clientHeight;
      this.camera.updateProjectionMatrix();
    }).observe(container);
  }

  private buildPlayer(): void {
    const g = new THREE.Group();
    const body = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.26, 0.7, 12),
      new THREE.MeshStandardMaterial({ color: 0xc4a056, metalness: 0.55, roughness: 0.4 }));
    body.position.y = 0.5; body.castShadow = true;
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.18, 12, 10),
      new THREE.MeshStandardMaterial({ color: 0x8a8680, metalness: 0.65, roughness: 0.35 }));
    head.position.y = 1.02; head.castShadow = true;
    const visor = new THREE.Mesh(new THREE.BoxGeometry(0.22, 0.08, 0.06),
      new THREE.MeshStandardMaterial({ color: 0x3aa8c8, emissive: 0x145868, metalness: 0.2, roughness: 0.15 }));
    visor.position.set(0, 1.02, 0.16);
    const pack = new THREE.Mesh(new THREE.BoxGeometry(0.24, 0.36, 0.16),
      new THREE.MeshStandardMaterial({ color: 0x4a4642, metalness: 0.7, roughness: 0.45 }));
    pack.position.set(0, 0.62, -0.2); pack.castShadow = true;
    g.add(body, head, visor, pack);
    g.name = 'player';
    this.playerMesh = g;
    this.scene.add(g);
  }

  setGhost(id: string | null, dir: 0 | 1 | 2 | 3 = 0): void {
    this.ghostId = id;
    this.ghostDir = dir;
    if (this.ghostMesh) { this.scene.remove(this.ghostMesh); this.ghostMesh = null; }
    if (id) {
      const def = BUILDING_MAP.get(id);
      const w = def?.width ?? 1, h = def?.height ?? 1;
      this.ghostMesh = new THREE.Mesh(
        new THREE.BoxGeometry(w, 0.6, h),
        new THREE.MeshBasicMaterial({ color: 0x00ff00, transparent: true, opacity: 0.4, depthTest: false }),
      );
      this.ghostMesh.position.y = 0.3;
      this.ghostMesh.renderOrder = 5;
      this.scene.add(this.ghostMesh);
    }
  }

  /** Project a world position to CSS pixels inside the canvas. */
  worldToScreen(x: number, y: number, z: number): [number, number] {
    const v = new THREE.Vector3(x, y, z).project(this.camera);
    const rect = this.renderer.domElement.getBoundingClientRect();
    return [(v.x * 0.5 + 0.5) * rect.width + rect.left,
            (-v.y * 0.5 + 0.5) * rect.height + rect.top];
  }

  private bindPointer(container: HTMLElement): void {
    const el = this.renderer.domElement;
    let rmbDown = false;
    let lastX = 0, lastY = 0;
    void container;
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
      if (e.key === 'e' || e.key === 'E') {
        // E is walk-up-use in game; only orbit when typing nowhere... game handles E.
        // Keep Q-only orbit to avoid conflict: ignore E here.
      }
      if (e.key === 'f' || e.key === 'F') this.followPlayer = true;
    });
  }

  /** A GLB file finished loading: force-swap entities/actors using it. */
  private onGlbFileReady(file: string): void {
    for (const [id, f] of this.glbFileOf) {
      if (f === file) {
        const g = this.entMeshes.get(id);
        if (g) this.scene.remove(g);
        this.entMeshes.delete(id);
        this.anims.delete(id);
        this.glbFileOf.delete(id);
      }
    }
    if (file === PLAYER_GLB) this.swapPlayerToGlb();
    if (file === NEST_GLB) {
      for (const m of this.spawnerMeshes.values()) this.scene.remove(m);
      this.spawnerMeshes.clear();
    }
  }

  /** Wrap a GLB clone so model-forward (-Z) becomes game-forward (+Z). */
  private wrapGlb(clone: THREE.Group): THREE.Group {
    const g = new THREE.Group();
    clone.rotation.y = Math.PI;
    clone.traverse((o) => {
      if (o instanceof THREE.Mesh) { o.castShadow = true; }
    });
    g.add(clone);
    g.userData.glb = true;
    return g;
  }

  private syncEntities(): void {
    const seen = new Set<number>();
    for (const e of this.game.world.entities.values()) {
      seen.add(e.id);
      let g = this.entMeshes.get(e.id);
      if (!g) {
        const def = BUILDING_MAP.get(e.buildingId);
        const w = def?.width ?? 1, h = def?.height ?? 1;
        const entry = MODEL_FOR[e.buildingId];
        const proto = entry ? this.glb.get(entry.file) : null;
        if (proto) {
          // GLB hero model
          const inner = proto.clone(true);
          if (entry!.tint != null) {
            inner.traverse((o) => {
              if (o instanceof THREE.Mesh) {
                const m = o.material as THREE.MeshStandardMaterial;
                if (m && 'color' in m) {
                  o.material = m.clone();
                  (o.material as THREE.MeshStandardMaterial).color.multiply(
                    new THREE.Color(entry!.tint!));
                }
              }
            });
          }
          if (entry!.scale != null) inner.scale.setScalar(entry!.scale);
          this.glb.reseat(inner);
          g = this.wrapGlb(inner);
          // hide silo rocket until assembled (sync below drives it)
          const anim0 = this.glb.collectAnim(g);
          if (e.buildingId === 'rocket-silo' && anim0.rockets) {
            for (const r of anim0.rockets) r.visible = false;
          }
          this.anims.set(e.id, anim0);
          this.glbFileOf.set(e.id, entry!.file);
          // directional buildings face their direction
          if (def?.type === 'Inserter' || def?.type === 'Belt') {
            const [dx, dy] = DIR_VEC[e.dir];
            g.rotation.y = Math.atan2(dx, dy);
          }
        } else {
          if (entry) {
            // record wanted file so the async load swaps this mesh on arrival
            this.glbFileOf.set(e.id, entry.file);
            void this.glb.load(entry.file).then(() => this.onGlbFileReady(entry.file));
          }
          const { group, anim } = buildModel(e);
          g = group;
          this.anims.set(e.id, anim);
        }
        this.entMeshes.set(e.id, g);
        g.position.set(e.x + w / 2, 0, e.y + h / 2);
        this.scene.add(g);
      }
      const anim = this.anims.get(e.id)!;
      const active = isActive(e);
      const t = this.clock;
      const baseY = (o: THREE.Object3D): number => {
        if (o.userData.baseY == null) o.userData.baseY = o.position.y;
        return o.userData.baseY as number;
      };
      if (anim.rotor && active) anim.rotor.rotateY(0.25);
      if (anim.wheel && e.satisfaction > 0) anim.wheel.rotateZ(0.12);
      if (anim.beam && active) anim.beam.rotation.z = Math.sin(t * 2.2) * 0.28;
      if (anim.arms) {
        anim.arms.forEach((a, i) => {
          a.position.y = baseY(a) + (active ? Math.sin(t * 5 + i * Math.PI) * 0.18 : 0);
        });
      }
      if (anim.arm) {
        if (anim.arm.userData.baseRotY == null) anim.arm.userData.baseRotY = anim.arm.rotation.y;
        const br = anim.arm.userData.baseRotY as number;
        anim.arm.rotation.y = active ? br + Math.sin(t * 3) * 0.55 : br;
      }
      if (anim.armTip) {
        // show held item
        let held = anim.armTip.getObjectByName('held');
        if (e.held && !held) {
          held = new THREE.Mesh(new THREE.BoxGeometry(0.25, 0.25, 0.25),
            new THREE.MeshBasicMaterial({ color: itemColor(e.held) }));
          held.name = 'held';
          anim.armTip.add(held);
        } else if (!e.held && held) anim.armTip.remove(held);
      }
      if (anim.glow) {
        const on = active;
        const m = anim.glow.material as THREE.MeshBasicMaterial | THREE.MeshStandardMaterial;
        if ('emissiveIntensity' in m) {
          m.emissiveIntensity = on ? 2.2 + Math.sin(t * 9) * 0.8 : 0.12;
        } else if (m instanceof THREE.MeshBasicMaterial && anim.glow.geometry.type === 'PlaneGeometry') {
          m.color.setHex(on ? (Math.sin(t * 9) > 0 ? 0xff6600 : 0xff3300) : 0x3a2018);
        }
      }
      if (anim.head) {
        // aim at nearest enemy
        const def = BUILDING_MAP.get(e.buildingId);
        const range = def?.turretRange ?? 18;
        let bx = 0, bz = 0, bd = range;
        for (const en of this.game.enemies) {
          const d = Math.hypot(en.x - (e.x + 0.5), en.y - (e.y + 0.5));
          if (d < bd) { bd = d; bx = en.x; bz = en.y; }
        }
        if (bd < range) {
          anim.head.rotation.y = Math.atan2(bx - (e.x + 0.5), bz - (e.y + 0.5));
        } else anim.head.rotation.y += 0.005;
      }
      if (anim.rockets && e.buildingId === 'rocket-silo') {
        const show = e.assembled || e.launching;
        const rise = e.launching ? (e.launchT / 10) * 14 : 0;
        for (const r of anim.rockets) {
          r.visible = show;
          r.position.y = baseY(r) + rise;
        }
      } else if (anim.rocket && e.buildingId === 'rocket-silo') {
        anim.rocket.visible = e.assembled || e.launching;
        const by = baseY(anim.rocket);
        if (e.launching) anim.rocket.position.y = by + (e.launchT / 10) * 14;
        else if (e.assembled) anim.rocket.position.y = by;
      }
      let lamp: THREE.Object3D | undefined = g.getObjectByName('lamp') as THREE.Mesh | undefined;
      if (!lamp) {
        g.traverse((o) => {
          if (!lamp && o instanceof THREE.Mesh && /^Lamp/.test(o.name)) lamp = o;
        });
      }
      if (lamp) {
        let lm = (lamp as THREE.Mesh).material as THREE.MeshBasicMaterial | THREE.MeshStandardMaterial;
        if (!lm.userData.own) {
          lm = lm.clone();
          (lamp as THREE.Mesh).material = lm;
          lm.userData.own = true;
        }
        const hex = e.satisfaction > 0 ? 0x00ff00 : 0xff0000;
        if ('emissive' in lm) lm.emissive.setHex(hex);
        else if ('color' in lm) (lm as THREE.MeshBasicMaterial).color.setHex(hex);
      }
      const def = BUILDING_MAP.get(e.buildingId);
      if (def?.type === 'Belt') this.syncBeltItems(e);
    }
    for (const [id, g] of this.entMeshes) {
      if (!seen.has(id)) {
        this.scene.remove(g);
        this.entMeshes.delete(id);
        this.anims.delete(id);
        const arr = this.beltItems.get(id);
        if (arr) { for (const m of arr) this.scene.remove(m); this.beltItems.delete(id); }
      }
    }
    if (this.game.world.entities.size !== this.lastEntCount) {
      this.lastEntCount = this.game.world.entities.size;
      this.syncWires();
    }
    this.syncSelection();
  }

  private syncBeltItems(e: Ent): void {
    let arr = this.beltItems.get(e.id);
    if (!arr) { arr = []; this.beltItems.set(e.id, arr); }
    const want = e.left.length + e.right.length;
    while (arr.length < want) {
      const m = new THREE.Mesh(new THREE.BoxGeometry(0.24, 0.16, 0.24),
        new THREE.MeshBasicMaterial({ color: 0xff8800 }));
      arr.push(m);
      this.scene.add(m);
    }
    while (arr.length > want) {
      const m = arr.pop()!;
      this.scene.remove(m);
    }
    let k = 0;
    const [dx, dy] = DIR_VEC[e.dir];
    const lanes: [typeof e.left, number][] = [[e.left, -0.22], [e.right, 0.22]];
    for (const [lane, side] of lanes) {
      const px = -dy * side, pz = dx * side;
      for (const it of lane) {
        const m = arr[k++];
        if (!m) continue;
        (m.material as THREE.MeshBasicMaterial).color.setHex(itemColor(it.itemId));
        m.position.set(
          e.x + 0.5 + dx * (it.progress - 0.5) + px, 0.3,
          e.y + 0.5 + dy * (it.progress - 0.5) + pz);
      }
    }
  }

  private syncWires(): void {
    if (this.wireLines) { this.scene.remove(this.wireLines); this.wireLines = null; }
    const poles = [...this.game.world.entities.values()].filter((e) =>
      BUILDING_MAP.get(e.buildingId)?.type === 'PowerPole');
    if (poles.length < 2) return;
    const pts: number[] = [];
    for (let i = 0; i < poles.length; i++) {
      for (let j = i + 1; j < poles.length; j++) {
        const a = poles[i], b = poles[j];
        const ra = BUILDING_MAP.get(a.buildingId)?.wireReach ?? 7.5;
        const rb = BUILDING_MAP.get(b.buildingId)?.wireReach ?? 7.5;
        const d = Math.hypot(a.x - b.x, a.y - b.y);
        if (d <= Math.min(ra, rb) && d > 0.5) {
          const ax = a.x + 0.5, az = a.y + 0.5, bx = b.x + 0.5, bz = b.y + 0.5;
          const topY = 2.0;
          // sagging wire: 8 segments
          let px = ax, py = topY, pz = az;
          for (let s = 1; s <= 8; s++) {
            const f = s / 8;
            const nx = ax + (bx - ax) * f;
            const nz = az + (bz - az) * f;
            const ny = topY - Math.sin(f * Math.PI) * Math.min(0.8, d * 0.08);
            pts.push(px, py, pz, nx, ny, nz);
            px = nx; py = ny; pz = nz;
          }
        }
      }
    }
    if (pts.length === 0) return;
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(pts, 3));
    this.wireLines = new THREE.LineSegments(geo,
      new THREE.LineBasicMaterial({ color: 0x222222 }));
    this.scene.add(this.wireLines);
  }

  private syncSelection(): void {
    const e = this.selectedId != null ? this.game.world.entities.get(this.selectedId) : undefined;
    if (!e) {
      this.selBox.visible = false;
      if (this.selLabel) this.selLabel.visible = false;
      if (this.selectedId != null) this.selectedId = null;
      return;
    }
    const def = BUILDING_MAP.get(e.buildingId);
    const w = def?.width ?? 1, h = def?.height ?? 1;
    this.selBox.visible = true;
    this.selBox.scale.set(w, 1.4, h);
    this.selBox.position.set(e.x + w / 2, 0.7, e.y + h / 2);
    // label (2 Hz refresh)
    if (this.selLabel && this.clock - this.labelTimer > 0.5) {
      this.labelTimer = this.clock;
      const ctx = this.selLabelCanvas.getContext('2d')!;
      ctx.clearRect(0, 0, 512, 96);
      ctx.fillStyle = 'rgba(8,14,8,0.85)';
      ctx.fillRect(0, 0, 512, 96);
      ctx.fillStyle = '#ffd75a';
      ctx.font = 'bold 34px sans-serif';
      ctx.fillText(def?.name ?? e.buildingId, 12, 40);
      ctx.fillStyle = '#b8d8b8';
      ctx.font = '26px sans-serif';
      ctx.fillText(this.describe(e), 12, 76);
      this.selLabelTex.needsUpdate = true;
      this.selLabel.position.set(e.x + w / 2, 2.6 + h * 0.2, e.y + h / 2);
      this.selLabel.visible = true;
    } else if (this.selLabel && !this.selLabel.visible) {
      this.labelTimer = 0; // force next update
    }
  }

  private describe(e: Ent): string {
    const keys = Object.keys(e.inv).filter((k) => (e.inv[k] ?? 0) > 0);
    const buf = keys.length > 0 ? keys.map((k) => `${e.inv[k]}× ${k.split('-')[0]}`).join(' ') : 'empty';
    const extra = e.recipeId ? ` ${Math.floor(e.progress * 100)}%` : '';
    return `${buf}${extra} · ⛏${Math.round(e.satisfaction * 100)}% pwr`;
  }

  private syncResources(): void {
    const w = this.game.world;
    if (w.resources.size !== this.lastResCount) {
      this.lastResCount = w.resources.size;
      if (this.oreMesh) { this.scene.remove(this.oreMesh); this.oreMesh = null; }
      const deps = [...w.resources.values()];
      this.oreMesh = new THREE.InstancedMesh(
        new THREE.BoxGeometry(0.5, 0.3, 0.42),
        new THREE.MeshStandardMaterial({ roughness: 0.85, metalness: 0.35 }),
        Math.max(1, deps.length),
      );
      const m = new THREE.Matrix4();
      const q = new THREE.Quaternion();
      const eul = new THREE.Euler();
      const sc = new THREE.Vector3();
      const pv = new THREE.Vector3();
      const c = new THREE.Color();
      const ORE: Record<string, number> = {
        'iron-ore': 0x54687e, 'copper-ore': 0xb06a35, coal: 0x1e1e1e,
        stone: 0x8a8a8a, 'uranium-ore': 0x55dd33, 'crude-oil': 0x1a0a28,
      };
      deps.forEach((d, i) => {
        const s = 0.55 + Math.min(0.5, d.amount / 9000);
        const h = ((d.x * 37 + d.y * 91) % 100) / 100;
        eul.set((h - 0.5) * 0.35, h * Math.PI * 2, 0);
        q.setFromEuler(eul);
        sc.set(s * (0.8 + h * 0.4), 0.7 + h * 0.7, s);
        pv.set(d.x + 0.25 + h * 0.5, 0.12, d.y + 0.5 - h * 0.3);
        m.compose(pv, q, sc);
        this.oreMesh!.setMatrixAt(i, m);
        this.oreMesh!.setColorAt(i, c.setHex(ORE[d.outputItem] ?? 0x888888));
      });
      this.oreMesh.instanceMatrix.needsUpdate = true;
      if (this.oreMesh.instanceColor) this.oreMesh.instanceColor.needsUpdate = true;
      this.oreMesh.castShadow = true;
      this.scene.add(this.oreMesh);
    }
    if (w.trees.size !== this.lastTreeCount) {
      this.lastTreeCount = w.trees.size;
      if (this.nature.loaded) {
        // GLB trees take over: drop legacy cones once
        if (this.legacyTrees) {
          this.legacyTrees = false;
          if (this.trunkMesh) { this.scene.remove(this.trunkMesh); this.trunkMesh = null; }
          if (this.leafMesh) { this.scene.remove(this.leafMesh); this.leafMesh = null; }
        }
        return;
      }
      if (this.trunkMesh) { this.scene.remove(this.trunkMesh); this.trunkMesh = null; }
      if (this.leafMesh) { this.scene.remove(this.leafMesh); this.leafMesh = null; }
      const trees = [...w.trees.keys()];
      const n = Math.max(1, trees.length);
      this.trunkMesh = new THREE.InstancedMesh(
        new THREE.CylinderGeometry(0.09, 0.13, 0.7, 6),
        new THREE.MeshLambertMaterial({ color: 0x6b4a2b }), n);
      this.leafMesh = new THREE.InstancedMesh(
        new THREE.ConeGeometry(0.5, 1.4, 7),
        new THREE.MeshLambertMaterial({ color: 0x2f7a2f }), n);
      const m = new THREE.Matrix4();
      trees.forEach((k, i) => {
        const [x, y] = k.split(',').map(Number);
        m.makeTranslation(x + 0.5, 0.35, y + 0.5);
        this.trunkMesh!.setMatrixAt(i, m);
        m.makeTranslation(x + 0.5, 1.3, y + 0.5);
        this.leafMesh!.setMatrixAt(i, m);
      });
      this.trunkMesh.instanceMatrix.needsUpdate = true;
      this.leafMesh.instanceMatrix.needsUpdate = true;
      this.trunkMesh.castShadow = this.leafMesh.castShadow = true;
      this.scene.add(this.trunkMesh, this.leafMesh);
    }
    if (!this.waterMesh && w.water.size > 0) {
      const geo = new THREE.BufferGeometry();
      const verts: number[] = [];
      for (const k of w.water) {
        const [x, y] = k.split(',').map(Number);
        verts.push(x, 0.03, y, x + 1, 0.03, y, x + 1, 0.03, y + 1);
        verts.push(x, 0.03, y, x + 1, 0.03, y + 1, x, 0.03, y + 1);
      }
      geo.setAttribute('position', new THREE.Float32BufferAttribute(verts, 3));
      geo.computeVertexNormals();
      this.waterMat = new THREE.MeshLambertMaterial({
        color: 0x2a72cc, transparent: true, opacity: 0.85 });
      this.waterMesh = new THREE.Mesh(geo, this.waterMat);
      this.scene.add(this.waterMesh);
    }
    if (this.waterMat) {
      this.waterMat.opacity = 0.78 + Math.sin(this.clock * 1.5) * 0.07;
    }
  }

  /** Swap the procedural player rig for the Blender engineer GLB. */
  private swapPlayerToGlb(): void {
    const proto = this.glb.get(PLAYER_GLB);
    if (!proto || this.playerMesh.userData.glb) return;
    this.playerMesh.clear();
    const inner = proto.clone(true);
    inner.rotation.y = Math.PI; // model-forward (-Z) -> game-forward (+Z)
    inner.traverse((o) => {
      if (o instanceof THREE.Mesh) o.castShadow = true;
    });
    this.playerMesh.add(inner);
    this.playerMesh.userData.glb = true;
  }

  private syncActors(): void {
    const p = this.game.player;
    if (!this.playerMesh.userData.glb) {
      const proto = this.glb.get(PLAYER_GLB);
      if (proto) this.swapPlayerToGlb();
    }
    const px = this.playerMesh.position.x, pz = this.playerMesh.position.z;
    const moved = Math.hypot(p.x - px, p.y - pz);
    this.playerMesh.position.set(p.x, moved > 0.001 ? Math.abs(Math.sin(this.clock * 10)) * 0.06 : 0, p.y);
    if (moved > 0.001) {
      this.playerMesh.rotation.y = Math.atan2(p.x - px, p.y - pz);
    }
    const seen = new Set<number>();
    for (const en of this.game.enemies) {
      seen.add(en.id);
      let grp = this.enemyMeshes.get(en.id);
      if (!grp) {
        const spitter = (en.enemyId ?? '').includes('spitter');
        const proto = this.glb.get(spitter ? SPITTER_GLB : BITER_GLB);
        grp = new THREE.Group();
        if (proto) {
          const inner = proto.clone(true);
          inner.rotation.y = Math.PI;
          inner.traverse((o) => {
            if (o instanceof THREE.Mesh) o.castShadow = true;
          });
          grp.add(inner);
          grp.userData.glb = true;
          const tier = en.enemyId ?? '';
          const s = tier.includes('behemoth') ? 2.4 : tier.includes('big') ? 1.7
            : tier.includes('medium') ? 1.3 : 1.0;
          grp.scale.setScalar(s);
        } else {
          const body = new THREE.Mesh(new THREE.SphereGeometry(0.32, 12, 8),
            new THREE.MeshStandardMaterial({ color: 0x6a4024, metalness: 0.2, roughness: 0.55 }));
          body.scale.set(1.1, 0.75, 1.35); body.position.y = 0.32; body.castShadow = true;
          const jaw = new THREE.Mesh(new THREE.ConeGeometry(0.12, 0.32, 6),
            new THREE.MeshStandardMaterial({ color: 0xc8b080, metalness: 0.1, roughness: 0.5 }));
          jaw.position.set(0, 0.26, 0.42);
          jaw.rotation.x = Math.PI / 2;
          grp.add(body, jaw);
        }
        this.enemyMeshes.set(en.id, grp);
        this.scene.add(grp);
      }
      grp.position.set(en.x, 0, en.y);
      grp.rotation.y = Math.atan2(en.tx - en.x, en.ty - en.y);
    }
    for (const [id, m] of this.enemyMeshes) {
      if (!seen.has(id)) { this.scene.remove(m); this.enemyMeshes.delete(id); }
    }
    // spawners (nests)
    const sseen = new Set<number>();
    this.game.spawners.forEach((s, i) => {
      if (s.hp <= 0) return;
      sseen.add(i);
      let m = this.spawnerMeshes.get(i);
      if (!m) {
        m = new THREE.Group();
        const proto = this.glb.get(NEST_GLB);
        if (proto) {
          const inner = proto.clone(true);
          inner.traverse((o) => {
            if (o instanceof THREE.Mesh) o.castShadow = true;
          });
          inner.scale.setScalar(1.0);
          m.add(inner);
          m.userData.glb = true;
        } else {
          const blob = new THREE.Mesh(new THREE.SphereGeometry(1.4, 12, 8),
            new THREE.MeshLambertMaterial({ color: 0x5a1a2a }));
          blob.scale.y = 0.55;
          blob.position.y = 0.2;
          blob.castShadow = true;
          m.add(blob);
        }
        m.position.set(s.x, 0, s.y);
        this.spawnerMeshes.set(i, m);
        this.scene.add(m);
      }
    });
    for (const [i, m] of this.spawnerMeshes) {
      if (!sseen.has(i)) { this.scene.remove(m); this.spawnerMeshes.delete(i); }
    }
  }

  private syncSmoke(dt: number): void {
    void dt;
    // collect emitters
    const emitters: { x: number; y: number; z: number }[] = [];
    for (const e of this.game.world.entities.values()) {
      const a = this.anims.get(e.id);
      if (a?.smoke && isActive(e) && emitters.length < 64) {
        const def = BUILDING_MAP.get(e.buildingId);
        const w = def?.width ?? 1, h = def?.height ?? 1;
        emitters.push({ x: e.x + w / 2, y: 2.0, z: e.y + h / 2 });
      }
    }
    const P = 14;
    const pos = this.smokeGeo.getAttribute('position') as THREE.BufferAttribute;
    for (let i = 0; i < this.smokeData.length; i++) {
      const d = this.smokeData[i];
      const em = emitters.length > 0 ? emitters[i % emitters.length] : null;
      d.life += 0.008;
      if (d.life >= 1 || !em) {
        if (em && Math.random() < emitters.length / 64 + 0.1) {
          d.x = em.x + (Math.random() - 0.5) * 0.3;
          d.y = em.y;
          d.z = em.z + (Math.random() - 0.5) * 0.3;
          d.life = 0;
        } else {
          d.y = -999;
          pos.setXYZ(i, 0, -999, 0);
          continue;
        }
      }
      void P;
      d.y += 0.03;
      d.x += 0.008;
      pos.setXYZ(i, d.x, d.y, d.z);
    }
    pos.needsUpdate = true;
  }

  update(dt: number): void {
    this.clock += dt;
    if (this.followPlayer) {
      this.target.x += (this.game.player.x - this.target.x) * Math.min(1, dt * 5);
      this.target.z += (this.game.player.y - this.target.z) * Math.min(1, dt * 5);
    }
    // keep shadow frustum near camera target
    const pit = 0.9;
    this.camera.position.set(
      this.target.x + Math.cos(this.yaw) * this.zoom * Math.cos(pit),
      this.zoom * Math.sin(pit),
      this.target.z + Math.sin(this.yaw) * this.zoom * Math.cos(pit),
    );
    this.camera.lookAt(this.target);
    if (this.ghostMesh && this.hoverTile) {
      const def = this.ghostId ? BUILDING_MAP.get(this.ghostId) : undefined;
      const w = def?.width ?? 1, h = def?.height ?? 1;
      this.ghostMesh.position.set(this.hoverTile[0] + w / 2, 0.3, this.hoverTile[1] + h / 2);
      const ok = this.game.world.canPlace(this.ghostId!, this.hoverTile[0], this.hoverTile[1]).ok;
      (this.ghostMesh.material as THREE.MeshBasicMaterial).color.setHex(ok ? 0x00ff00 : 0xff0000);
      this.ghostMesh.visible = true;
    } else if (this.ghostMesh) this.ghostMesh.visible = false;
    this.syncEntities();
    this.syncResources();
    this.nature.update(this.game.world.entities.size);
    this.syncActors();
    this.syncSmoke(dt);
    this.renderer.render(this.scene, this.camera);
  }
}
