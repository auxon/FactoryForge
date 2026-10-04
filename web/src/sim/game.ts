// Game loop + systems. Faithful simplified port of Swift systems:
// fixed 1/60 timestep (max 5/frame), priorities mining->belt->inserter->
// crafting->power->research->enemy->combat->rocket->cleanup.
import { BUILDING_MAP } from '../data/buildings';
import { RECIPE_MAP } from '../data/recipes';
import { ITEM_MAP, DEFAULT_UNLOCKED_RECIPES } from '../data/items';
import { TECH_MAP } from '../data/tech';
import { FUEL_BURN_SECONDS } from '../data/fluids';
import { Inventory } from './inventory';
import { World, Ent, Dir, DIR_VEC } from './world';

export interface CraftJob { recipeId: string; progress: number; count: number; }

export class Game {
  world: World;
  player = {
    x: 0.5, y: 0.5, hp: 250, maxHp: 250,
    inv: new Inventory(70),
    craftQueue: [] as CraftJob[],
    dead: false,
    /** True on frames the player actually walked (set by movePlayer). */
    moving: false,
  };
  unlocked = new Set<string>(DEFAULT_UNLOCKED_RECIPES);
  completedTech = new Set<string>();
  currentResearch: string | null = null;
  researchProgress: Record<string, number> = {};
  bonuses = { miningSpeed: 0, craftingSpeed: 0, researchSpeed: 0 };
  spacePacks = 0;
  launched = false;
  enemies: Ent[] = [];
  spawners: { x: number; y: number; hp: number; timer: number }[] = [];
  waveTimer = 120;
  acc = 0;
  speed = 1;
  paused = false;
  /** Dev/test cheat: all machines fully powered. */
  freePower = false;
  /** Seconds remaining on the player attack swing (view-only). */
  playerSwing = 0;
  onWin: (() => void) | null = null;
  log: string[] = [];

  constructor(seed: number) {
    this.world = new World(seed);
    this.player.inv.add('iron-plate', 10);
    this.player.inv.add('coal', 10);
    this.player.inv.add('wood', 10);
    this.player.inv.add('firearm-magazine', 50);
    this.player.inv.add('burner-mining-drill', 2);
    this.player.inv.add('stone-furnace', 2);
    this.player.inv.add('transport-belt', 20);
    this.player.inv.add('inserter', 6);
    this.player.inv.add('wooden-chest', 2);
    // starting spawners far from spawn
    this.spawners = [
      { x: 55, y: -20, hp: 350, timer: 5 },
      { x: -55, y: -25, hp: 350, timer: 12 },
      { x: 30, y: 55, hp: 350, timer: 18 },
    ];
  }

  say(msg: string): void {
    this.log.push(msg);
    if (this.log.length > 8) this.log.shift();
  }

  frame(dt: number): void {
    if (this.paused || this.player.dead) return;
    const scale = this.speed;
    this.acc += Math.min(dt, 1 / 30) * scale;
    let n = 0;
    while (this.acc >= 1 / 60 && n < 5) {
      this.tick(1 / 60);
      this.acc -= 1 / 60;
      n++;
    }
  }

  tick(dt: number): void {
    this.playerSwing = Math.max(0, this.playerSwing - dt);
    this.world.playTime += dt;
    this.world.evo = Math.min(1, this.world.playTime / (4 * 3600) * 0.5);
    this.tickPlayer(dt);
    this.tickMining(dt);
    this.tickBelts(dt);
    this.tickInserters(dt);
    this.tickCrafting(dt);
    this.tickPower(dt);
    this.tickResearch(dt);
    this.tickEnemies(dt);
    this.tickCombat(dt);
    this.tickRocket(dt);
    this.tickHandCraft(dt);
    // regen
    if (this.player.hp < this.player.maxHp) {
      this.player.hp = Math.min(this.player.maxHp, this.player.hp + 1.0 * dt);
    }
  }

  // ---- player ----
  movePlayer(dx: number, dy: number, dt: number): void {
    if (this.player.dead) return;
    const sp = 5.0;
    this.player.x += dx * sp * dt;
    this.player.y += dy * sp * dt;
    this.player.moving = true;
  }

  /** Hand-mine: 1 item per call if a resource/tree is adjacent. */
  handMine(): string | null {
    const px = Math.floor(this.player.x), py = Math.floor(this.player.y);
    for (let dx = -1; dx <= 1; dx++) {
      for (let dy = -1; dy <= 1; dy++) {
        const k = `${px + dx},${py + dy}`;
        const dep = this.world.resources.get(k);
        if (dep && dep.amount > 0 && this.player.inv.canAccept(dep.outputItem)) {
          const got = this.world.mineResource(px + dx, py + dy, 1);
          if (got) { this.player.inv.add(got, 1); return got; }
        }
        const tree = this.world.trees.get(k);
        if (tree && tree > 0 && this.player.inv.canAccept('wood')) {
          this.world.trees.set(k, tree - 1);
          if (tree - 1 <= 0) this.world.trees.delete(k);
          this.player.inv.add('wood', 1);
          return 'wood';
        }
      }
    }
    return null;
  }

  queueHandCraft(recipeId: string, count = 1): boolean {
    const r = RECIPE_MAP.get(recipeId);
    if (!r || !this.unlocked.has(recipeId)) return false;
    if (r.fluidInputs.length > 0) return false; // needs machine
    for (let i = 0; i < count; i++) {
      if (!this.player.inv.has(r.inputs)) return i > 0;
      for (const inp of r.inputs) this.player.inv.remove(inp.itemId, inp.count);
      this.player.craftQueue.push({ recipeId, progress: 0, count: 1 });
    }
    return true;
  }

  tickPlayer(_dt: number): void { /* movement applied in frame via keys */ }

  tickHandCraft(dt: number): void {
    const job = this.player.craftQueue[0];
    if (!job) return;
    const r = RECIPE_MAP.get(job.recipeId);
    if (!r) { this.player.craftQueue.shift(); return; }
    job.progress += dt / Math.max(0.05, r.craftTime);
    if (job.progress >= 1) {
      for (const o of r.outputs) this.player.inv.add(o.itemId, o.count);
      this.player.craftQueue.shift();
    }
  }

  // ---- mining ----
  tickMining(dt: number): void {
    for (const e of this.world.entities.values()) {
      const def = BUILDING_MAP.get(e.buildingId);
      if (!def || (def.type !== 'Miner' && def.type !== 'Pumpjack' && def.type !== 'WaterPump')) continue;
      if (def.type === 'WaterPump') {
        // offshore/water pump: needs adjacent water, fills fluid buffer
        if (this.waterAdjacent(e)) {
          const rate = def.extractionRate ?? 20;
          e.fluid['water'] = Math.min(def.fluidCapacity ?? 50, (e.fluid['water'] ?? 0) + rate * dt * e.satisfaction);
        }
        continue;
      }
      if (def.type === 'Pumpjack') {
        if (e.satisfaction <= 0) continue;
        const dep = this.world.resourceNear(e.x, e.y, 2);
        if (!dep || dep.outputItem !== 'crude-oil') continue;
        const rate = def.extractionRate ?? 1;
        e.progress += (dt / (1 / rate)) * e.satisfaction;
        if (e.progress >= 1) {
          e.progress = 0;
          e.inv['crude-oil'] = (e.inv['crude-oil'] ?? 0) + 1;
        }
        continue;
      }
      // ore miners
      const burner = (def.powerConsumption ?? 0) === 0;
      if (!burner && e.satisfaction <= 0) continue;
      if (burner) {
        if (e.fuel <= 0) {
          const got = this.burnFuel(e);
          if (!got) continue;
        }
        e.fuel = Math.max(0, e.fuel - dt);
      }
      const dep = this.world.resourceNear(e.x, e.y, 2);
      if (!dep) continue;
      const mult = (burner ? 1 : e.satisfaction) * (1 + this.bonuses.miningSpeed);
      const miningTime = 1 / ((def.miningSpeed ?? 0.5) * mult);
      e.progress += dt / miningTime;
      if (e.progress >= 1) {
        e.progress = 0;
        const got = this.world.mineResource(dep.x, dep.y, 1);
        if (got) e.inv[got] = (e.inv[got] ?? 0) + 1;
      }
    }
  }

  burnFuel(e: Ent): boolean {
    for (const f of ['coal', 'wood', 'solid-fuel']) {
      if ((e.inv[f] ?? 0) > 0) {
        e.inv[f]!--;
        e.fuel = FUEL_BURN_SECONDS[f] ?? 4;
        return true;
      }
    }
    return false;
  }

  waterAdjacent(e: Ent): boolean {
    const def = BUILDING_MAP.get(e.buildingId);
    const w = def?.width ?? 1, h = def?.height ?? 1;
    for (let dx = -1; dx <= w; dx++) {
      for (let dy = -1; dy <= h; dy++) {
        if (this.world.water.has(`${e.x + dx},${e.y + dy}`)) return true;
      }
    }
    return false;
  }

  // ---- belts ----
  beltOutput(x: number, y: number, dir: Dir): Ent | null {
    const [dx, dy] = DIR_VEC[dir];
    const t = this.world.entityAt(x + dx, y + dy);
    if (!t) return null;
    const d = BUILDING_MAP.get(t.buildingId);
    return d && d.type === 'Belt' ? t : null;
  }

  tickBelts(dt: number): void {
    // process in reverse topological-ish order: sort by x+y along flow is
    // overkill at web scale; two passes end-to-start approximated by id desc
    const belts = [...this.world.entities.values()].filter((e) => {
      const d = BUILDING_MAP.get(e.buildingId);
      return d?.type === 'Belt';
    });
    for (const e of belts) {
      const def = BUILDING_MAP.get(e.buildingId)!;
      const speed = (def.beltSpeed ?? 1.875) * dt;
      const out = this.beltOutput(e.x, e.y, e.dir);
      this.moveLane(e.left, speed, out);
      this.moveLane(e.right, speed, out);
    }
  }

  moveLane(lane: { itemId: string; progress: number }[], speed: number, out: Ent | null): void {
    lane.sort((a, b) => b.progress - a.progress);
    for (let i = 0; i < lane.length; i++) {
      const it = lane[i];
      let np = it.progress + speed;
      if (i > 0) np = Math.min(np, lane[i - 1].progress - 0.25);
      if (np >= 1.0) {
        if (out) {
          const target = out.left.length <= out.right.length ? out.left : out.right;
          const front = target.length > 0 ? Math.max(...target.map((t) => t.progress)) : 1;
          if (target.length === 0 || front > 0.25) {
            target.push({ itemId: it.itemId, progress: 0 });
            lane.splice(i, 1); i--;
            continue;
          }
        }
        np = 1.0;
      }
      it.progress = Math.max(it.progress, Math.min(np, 1.0));
    }
  }

  // ---- inserters (auto: source behind, target ahead) ----
  tickInserters(dt: number): void {
    for (const e of this.world.entities.values()) {
      const def = BUILDING_MAP.get(e.buildingId);
      if (!def || def.type !== 'Inserter') continue;
      if (e.satisfaction <= 0) continue;
      e.cooldown -= dt;
      if (e.cooldown > 0) continue;
      const [dx, dy] = DIR_VEC[e.dir];
      const src = this.world.entityAt(e.x - dx, e.y - dy);
      const dst = this.world.entityAt(e.x + dx, e.y + dy);
      const stack = def.inserterStackSize ?? 1;
      if (!e.held) {
        const got = this.inserterTake(src, stack);
        if (got) { e.held = got; e.cooldown = 1 / (def.inserterSpeed ?? 4); }
      } else {
        if (this.inserterDrop(dst, e.held, stack)) {
          e.held = null;
          e.cooldown = 1 / (def.inserterSpeed ?? 4);
        } else {
          e.cooldown = 0.25;
        }
      }
    }
  }

  inserterTake(src: Ent | null, n: number): string | null {
    if (!src) return null;
    const def = BUILDING_MAP.get(src.buildingId);
    if (!def) return null;
    if (def.type === 'Belt') {
      for (const lane of [src.left, src.right]) {
        const idx = lane.findIndex((i) => i.progress >= 0.9);
        if (idx >= 0) return lane.splice(idx, 1)[0].itemId;
      }
      return null;
    }
    // machine output: any buffered item
    for (const k of Object.keys(src.inv)) {
      if ((src.inv[k] ?? 0) >= n && this.isOutputItem(src, k)) {
        src.inv[k]! -= n;
        return k;
      }
    }
    return null;
  }

  isOutputItem(src: Ent, itemId: string): boolean {
    // belts handled elsewhere; for machines, anything not an input of the
    // active recipe counts as output. No recipe -> everything is output.
    const r = src.recipeId ? RECIPE_MAP.get(src.recipeId) : undefined;
    if (!r) return true;
    return !r.inputs.some((i) => i.itemId === itemId);
  }

  inserterDrop(dst: Ent | null, itemId: string, n: number): boolean {
    if (!dst) return false;
    const def = BUILDING_MAP.get(dst.buildingId);
    if (!def) return false;
    if (def.type === 'Belt') {
      const lane = dst.left.length <= dst.right.length ? dst.left : dst.right;
      const front = lane.length > 0 ? Math.max(...lane.map((t) => t.progress)) : 1;
      if (lane.length === 0 || front > 0.25) {
        for (let i = 0; i < n; i++) lane.push({ itemId, progress: 0 });
        return true;
      }
      return false;
    }
    const cap = 200;
    dst.inv[itemId] = Math.min(cap, (dst.inv[itemId] ?? 0) + n);
    return true;
  }

  // ---- crafting (assemblers + furnaces) ----
  tickCrafting(dt: number): void {
    for (const e of this.world.entities.values()) {
      const def = BUILDING_MAP.get(e.buildingId);
      if (!def || (def.type !== 'Assembler' && def.type !== 'Furnace' && def.type !== 'ChemicalPlant' && def.type !== 'OilRefinery' && def.type !== 'Centrifuge')) continue;
      const burner = def.type === 'Furnace' && (def.powerConsumption ?? 0) === 0;
      if (!burner && e.satisfaction <= 0) continue;
      if (burner) {
        if (e.progress > 0 || this.furnaceHasWork(e)) {
          if (e.fuel <= 0 && !this.burnFuel(e)) continue;
          e.fuel = Math.max(0, e.fuel - dt);
        } else continue;
      }
      // auto-select furnace recipe
      if (def.type === 'Furnace' && !e.recipeId) {
        for (const rid of ['iron-plate', 'copper-plate', 'stone-brick', 'steel-plate']) {
          const r = RECIPE_MAP.get(rid)!;
          if (this.hasInputs(e, r)) { e.recipeId = rid; break; }
        }
        if (!e.recipeId) continue;
      }
      if (!e.recipeId) continue;
      const r = RECIPE_MAP.get(e.recipeId);
      if (!r) continue;
      if (e.progress > 0) {
        const t = r.craftTime / ((def.craftingSpeed ?? 1) * (burner ? 1 : e.satisfaction) * (1 + this.bonuses.craftingSpeed));
        e.progress += dt / Math.max(0.01, t);
        if (e.progress >= 1) {
          e.progress = 0;
          for (const o of r.outputs) e.inv[o.itemId] = (e.inv[o.itemId] ?? 0) + o.count;
          if (def.type === 'Furnace') e.recipeId = null; // re-auto-select
        }
      } else if (this.hasInputs(e, r)) {
        for (const i of r.inputs) e.inv[i.itemId]! -= i.count;
        e.progress = 0.001;
      }
    }
  }

  hasInputs(e: Ent, r: { inputs: { itemId: string; count: number }[] }): boolean {
    return r.inputs.every((i) => (e.inv[i.itemId] ?? 0) >= i.count);
  }

  furnaceHasWork(e: Ent): boolean {
    for (const rid of ['iron-plate', 'copper-plate', 'stone-brick', 'steel-plate']) {
      const r = RECIPE_MAP.get(rid)!;
      if (this.hasInputs(e, r)) return true;
    }
    return e.progress > 0;
  }

  // ---- power (simplified flood-fill networks over poles) ----
  tickPower(_dt: number): void {
    if (this.freePower) {
      for (const e of this.world.entities.values()) e.satisfaction = 1;
      return;
    }
    // group poles into networks by wireReach
    const poles = [...this.world.entities.values()].filter((e) => {
      const d = BUILDING_MAP.get(e.buildingId);
      return d?.type === 'PowerPole';
    });
    const netOf = new Map<number, number>();
    let nextNet = 0;
    const reach = (e: Ent): number => BUILDING_MAP.get(e.buildingId)?.wireReach ?? 7.5;
    for (const p of poles) {
      if (netOf.has(p.id)) continue;
      const net = nextNet++;
      const stack = [p];
      netOf.set(p.id, net);
      while (stack.length > 0) {
        const cur = stack.pop()!;
        for (const q of poles) {
          if (netOf.has(q.id)) continue;
          const d = Math.hypot(cur.x - q.x, cur.y - q.y);
          if (d <= Math.min(reach(cur), reach(q))) {
            netOf.set(q.id, net);
            stack.push(q);
          }
        }
      }
    }
    // attach consumers/generators to nearest network via supplyArea
    interface NetStat { prod: number; cons: number; members: Ent[]; }
    const nets = new Map<number, NetStat>();
    const ensure = (n: number): NetStat => {
      let s = nets.get(n);
      if (!s) { s = { prod: 0, cons: 0, members: [] }; nets.set(n, s); }
      return s;
    };
    for (const e of this.world.entities.values()) {
      const def = BUILDING_MAP.get(e.buildingId);
      if (!def) continue;
      if (def.type === 'PowerPole') { e.networkId = netOf.get(e.id) ?? -1; continue; }
      const cons = def.powerConsumption ?? 0;
      const prod = def.powerProduction ?? 0;
      if (cons === 0 && prod === 0) { e.satisfaction = 1; continue; }
      // find covering pole network
      let net = -1;
      for (const p of poles) {
        const area = BUILDING_MAP.get(p.buildingId)?.supplyArea ?? 2.5;
        const cx = e.x + (def.width - 1) / 2, cy = e.y + (def.height - 1) / 2;
        if (Math.hypot(p.x + 0.5 - (cx + 0.5), p.y + 0.5 - (cy + 0.5)) <= area + Math.max(def.width, def.height) / 2) {
          net = netOf.get(p.id) ?? -1;
          if (net >= 0) break;
        }
      }
      e.networkId = net;
      if (net < 0) { e.satisfaction = cons > 0 ? 0 : 1; continue; }
      const st = ensure(net);
      st.members.push(e);
      // solar output varies by time of day (60s day)
      let p = prod;
      if (def.type === 'SolarPanel') {
        const t = (this.world.playTime / 60) % 1;
        p = prod * Math.max(0, Math.sin(t * Math.PI));
      }
      if (p > 0) st.prod += p;
      if (cons > 0) st.cons += cons;
    }
    for (const st of nets.values()) {
      const sat = st.cons > 0 ? Math.min(1, st.prod / st.cons) : 1;
      for (const e of st.members) {
        const def = BUILDING_MAP.get(e.buildingId)!;
        e.satisfaction = (def.powerConsumption ?? 0) > 0 ? sat : 1;
      }
    }
  }

  // ---- research ----
  startResearch(id: string): boolean {
    const t = TECH_MAP.get(id);
    if (!t || this.completedTech.has(id)) return false;
    if (!t.prerequisites.every((p) => this.completedTech.has(p))) return false;
    this.currentResearch = id;
    this.researchProgress = {};
    for (const e of this.world.entities.values()) {
      if (BUILDING_MAP.get(e.buildingId)?.type === 'Lab') e.researching = true;
    }
    return true;
  }

  tickResearch(_dt: number): void {
    if (!this.currentResearch) return;
    const t = TECH_MAP.get(this.currentResearch);
    if (!t) return;
    const labs = [...this.world.entities.values()].filter((e) =>
      BUILDING_MAP.get(e.buildingId)?.type === 'Lab' && e.satisfaction > 0);
    if (labs.length === 0) return;
    for (const lab of labs) {
      for (const c of t.cost) {
        const have = this.researchProgress[c.packId] ?? 0;
        if (have < c.count && (lab.inv[c.packId] ?? 0) > 0) {
          lab.inv[c.packId]!--;
          this.researchProgress[c.packId] = have + 1;
        }
      }
    }
    if (t.cost.every((c) => (this.researchProgress[c.packId] ?? 0) >= c.count)) {
      this.completedTech.add(t.id);
      for (const r of t.unlocks.recipes) this.unlocked.add(r);
      for (const b of t.unlocks.bonuses) {
        if (b.type === 'miningSpeed') this.bonuses.miningSpeed += b.modifier;
        if (b.type === 'craftingSpeed') this.bonuses.craftingSpeed += b.modifier;
        if (b.type === 'researchSpeed') this.bonuses.researchSpeed += b.modifier;
      }
      this.say(`Researched ${t.name}`);
      this.currentResearch = null;
      for (const e of this.world.entities.values()) {
        if (BUILDING_MAP.get(e.buildingId)?.type === 'Lab') e.researching = false;
      }
    }
  }

  researchFraction(): number {
    if (!this.currentResearch) return 0;
    const t = TECH_MAP.get(this.currentResearch)!;
    let have = 0, need = 0;
    for (const c of t.cost) {
      have += Math.min(this.researchProgress[c.packId] ?? 0, c.count);
      need += c.count;
    }
    return need > 0 ? have / need : 1;
  }

  // ---- enemies + combat ----
  tickEnemies(dt: number): void {
    // grace period: biters stay home for the first 5 minutes (setup time)
    const grace = this.world.playTime < 300;
    // spawners trickle
    for (const s of this.spawners) {
      if (s.hp <= 0) continue;
      s.timer -= dt;
      if (s.timer <= 0 && !grace && this.enemies.length < 50) {
        s.timer = 20;
        const id = nextIdTick();
        this.enemies.push({
          ...blankEnemy(), id, buildingId: '__enemy',
          x: s.x, y: s.y, dir: 0 as Dir,
          enemyId: 'small-biter', tx: this.player.x, ty: this.player.y, atkCd: 0,
          hp: 15,
        });
      }
    }
    // waves
    this.waveTimer -= dt;
    if (this.waveTimer <= 0) {
      this.waveTimer = 300;
      for (let i = 0; i < 3; i++) {
        const a = Math.random() * Math.PI * 2;
        this.enemies.push({
          ...blankEnemy(), id: nextIdTick(), buildingId: '__enemy',
          x: this.player.x + Math.cos(a) * 50, y: this.player.y + Math.sin(a) * 50,
          dir: 0 as Dir, enemyId: 'small-biter',
          tx: this.player.x, ty: this.player.y, atkCd: 0, hp: 15,
        });
      }
      this.say('Biter wave incoming!');
    }
    // AI: chase player, attack in range
    for (const en of this.enemies) {
      en.tx = this.player.x; en.ty = this.player.y;
      const dx = en.tx - en.x, dy = en.ty - en.y;
      const d = Math.hypot(dx, dy);
      en.atkCd -= dt;
      if (d > 1.0) {
        const sp = 2.5;
        en.x += (dx / d) * sp * dt;
        en.y += (dy / d) * sp * dt;
      } else if (en.atkCd <= 0) {
        en.atkCd = 0.5;
        this.player.hp -= 7;
        if (this.player.hp <= 0) {
          this.player.hp = 0;
          this.player.dead = true;
          this.say('You died. Reload to try again.');
        }
      }
    }
  }

  tickCombat(dt: number): void {
    for (const e of this.world.entities.values()) {
      const def = BUILDING_MAP.get(e.buildingId);
      if (!def || def.type !== 'Turret') continue;
      // laser needs power; gun needs ammo
      if ((def.powerConsumption ?? 0) > 0 && e.satisfaction < 0.5) continue;
      e.turretCd -= dt;
      // find target
      let best: Ent | null = null; let bestD = def.turretRange ?? 18;
      for (const en of this.enemies) {
        const d = Math.hypot(en.x - (e.x + 0.5), en.y - (e.y + 0.5));
        if (d <= bestD) { best = en; bestD = d; }
      }
      // spawners as targets too
      if (!best) {
        for (const s of this.spawners) {
          if (s.hp <= 0) continue;
          const d = Math.hypot(s.x - (e.x + 0.5), s.y - (e.y + 0.5));
          if (d <= (def.turretRange ?? 18)) { best = null; break; }
        }
      }
      if (best && e.turretCd <= 0) {
        if ((def.powerConsumption ?? 0) === 0) {
          if ((e.inv['firearm-magazine'] ?? 0) <= 0 && (e.inv['piercing-rounds-magazine'] ?? 0) <= 0) continue;
          if ((e.inv['firearm-magazine'] ?? 0) > 0) e.inv['firearm-magazine']!--;
          else e.inv['piercing-rounds-magazine']!--;
        }
        e.turretCd = 1 / (def.turretFireRate ?? 10);
        best.hp -= def.turretDamage ?? 6;
        if (best.hp <= 0) {
          this.enemies = this.enemies.filter((x) => x !== best);
        }
      }
    }
    // player melee/ranged vs enemies+spawners handled by click in UI (attackNearest)
  }

  /** Player attacks nearest enemy/spawner within range 10. */
  playerAttack(): boolean {
    if (this.player.dead) return false;
    const hasGun = this.player.inv.count('firearm-magazine') > 0 ||
      this.player.inv.count('piercing-rounds-magazine') > 0;
    const hasSword = this.player.inv.count('sword') > 0;
    const range = hasGun ? 10 : hasSword ? 2 : 0;
    if (range === 0) return false;
    this.playerSwing = 0.4;
    let best: Ent | null = null; let bestD = range;
    for (const en of this.enemies) {
      const d = Math.hypot(en.x - this.player.x, en.y - this.player.y);
      if (d <= bestD) { best = en; bestD = d; }
    }
    if (!best) {
      for (const s of this.spawners) {
        if (s.hp <= 0) continue;
        const d = Math.hypot(s.x - this.player.x, s.y - this.player.y);
        if (d <= bestD) {
          s.hp -= hasGun ? 5 : 7.5;
          if (hasGun) this.player.inv.remove('firearm-magazine', 1);
          if (s.hp <= 0) this.say('Nest destroyed!');
          return true;
        }
      }
      return false;
    }
    if (hasGun) this.player.inv.remove('firearm-magazine', 1);
    best.hp -= hasGun ? 5 : 7.5;
    if (best.hp <= 0) this.enemies = this.enemies.filter((x) => x !== best);
    return true;
  }

  // ---- rocket / win ----
  tickRocket(dt: number): void {
    for (const e of this.world.entities.values()) {
      if (BUILDING_MAP.get(e.buildingId)?.type !== 'RocketSilo') continue;
      if (!e.assembled) {
        if ((e.inv['rocket-parts'] ?? 0) >= 100 && (e.inv['rocket-fuel'] ?? 0) >= 50 && (e.inv['satellite'] ?? 0) >= 1) {
          e.assembled = true;
          this.say('Rocket assembled — launching!');
          e.launching = true;
          e.launchT = 0;
        }
        continue;
      }
      if (e.launching) {
        e.launchT += dt;
        if (e.launchT >= 10) {
          e.launching = false;
          e.inv['rocket-parts']! -= 100;
          e.inv['rocket-fuel']! -= 50;
          e.inv['satellite']! -= 1;
          e.inv['space-science-pack'] = (e.inv['space-science-pack'] ?? 0) + 1000;
          this.spacePacks += 1000;
          this.launched = true;
          this.say('ROCKET LAUNCHED! +1000 space science. You win!');
          this.onWin?.();
        }
      }
    }
  }

  // ---- placement API (validates + charges cost) ----
  tryPlace(buildingId: string, x: number, y: number, dir: Dir): Ent | null {
    const def = BUILDING_MAP.get(buildingId);
    if (!def) return null;
    if (!this.player.inv.has(def.cost)) {
      this.say(`Need ${def.cost.map((c) => `${c.count}x ${ITEM_MAP.get(c.itemId)?.name ?? c.itemId}`).join(', ')}`);
      return null;
    }
    const e = this.world.place(buildingId, x, y, dir);
    if (!e) { this.say('Cannot place here'); return null; }
    for (const c of def.cost) this.player.inv.remove(c.itemId, c.count);
    return e;
  }

  // ---- save/load (localStorage; Swift used Documents/saves/<slot>.json) ----
  save(slot = 'save1'): void {
    const data = {
      version: 1, seed: this.world.seed, playTime: this.world.playTime,
      player: {
        x: this.player.x, y: this.player.y, hp: this.player.hp,
        inv: this.player.inv.serialize(),
      },
      entities: [...this.world.entities.values()],
      resources: [...this.world.resources.values()],
      trees: [...this.world.trees.entries()],
      unlocked: [...this.unlocked], completed: [...this.completedTech],
      currentResearch: this.currentResearch, researchProgress: this.researchProgress,
      bonuses: this.bonuses, spacePacks: this.spacePacks, launched: this.launched,
    };
    localStorage.setItem(`ff-${slot}`, JSON.stringify(data));
    this.say(`Saved to ${slot}`);
  }

  load(slot = 'save1'): boolean {
    try {
      const raw = localStorage.getItem(`ff-${slot}`);
      if (!raw) return false;
      const d = JSON.parse(raw);
      this.world = new World(d.seed);
      this.world.playTime = d.playTime;
      this.world.resources = new Map(d.resources.map((r: { x: number; y: number }) => [`${r.x},${r.y}`, r]));
      this.world.trees = new Map(d.trees);
      this.world.entities.clear(); this.world.grid.clear();
      for (const e of d.entities as Ent[]) {
        this.world.entities.set(e.id, e);
        for (const [tx, ty] of this.world.tilesOf(e)) this.world.grid.set(`${tx},${ty}`, e.id);
      }
      this.player.x = d.player.x; this.player.y = d.player.y;
      this.player.hp = d.player.hp;
      this.player.inv = Inventory.deserialize(70, d.player.inv);
      this.unlocked = new Set(d.unlocked);
      this.completedTech = new Set(d.completed);
      this.currentResearch = d.currentResearch;
      this.researchProgress = d.researchProgress;
      this.bonuses = d.bonuses;
      this.spacePacks = d.spacePacks; this.launched = d.launched;
      this.say(`Loaded ${slot}`);
      return true;
    } catch {
      return false;
    }
  }
}

let enemyIdCounter = 1000000;
function nextIdTick(): number { return enemyIdCounter++; }

function blankEnemy(): Ent {
  return {
    id: 0, buildingId: '__enemy', x: 0, y: 0, dir: 0,
    progress: 0, recipeId: null, fuel: 0, inv: {}, fluid: {},
    satisfaction: 1, networkId: -1, left: [], right: [],
    held: null, armT: 0, cooldown: 0, hp: 15, turretCd: 0,
    researching: false, assembled: false, launching: false, launchT: 0,
    enemyId: 'small-biter', tx: 0, ty: 0, atkCd: 0,
  };
}

// re-export for UI convenience
export type { Dir };
export { DIR_VEC };
export { ITEM_MAP };
