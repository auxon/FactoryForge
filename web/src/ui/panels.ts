// DOM UI: HUD + Build/Craft/Inventory/Research/Machine panels.
import { BUILD_CATEGORIES, BUILDING_MAP } from '../data/buildings';
import { RECIPE_MAP } from '../data/recipes';
import { ITEM_MAP } from '../data/items';
import { TECH_MAP, TECHNOLOGIES } from '../data/tech';
import { CATEGORY_BUILDINGS } from '../data/types';
import type { BuildingDefinition } from '../data/types';
import { isActive, itemColor } from '../render/models';
import type { Game } from '../sim/game';
import type { View } from '../render/view';
import type { Dir } from '../sim/world';
import type { Ent } from '../sim/world';

const iname = (id: string): string => ITEM_MAP.get(id)?.name ?? id;
const hex = (id: string): string => `#${itemColor(id).toString(16).padStart(6, '0')}`;
const pretty = (id: string): string => id.split('-').map((w) => w[0].toUpperCase() + w.slice(1)).join(' ');

const VERB: Record<string, string> = {
  Miner: 'MINING', Furnace: 'SMELTING', Assembler: 'ASSEMBLING',
  ChemicalPlant: 'SYNTHESIZING', OilRefinery: 'REFINING', Centrifuge: 'ENRICHING',
  Lab: 'RESEARCHING', Pumpjack: 'PUMPING', WaterPump: 'PUMPING',
  Generator: 'GENERATING', Turret: 'ON GUARD', RocketSilo: 'STANDING BY',
  SolarPanel: 'COLLECTING', Accumulator: 'CHARGING', NuclearReactor: 'BURNING',
  Inserter: 'SWINGING', Belt: 'FLOWING', Pipe: 'FLOWING', FluidTank: 'STORING',
  Chest: 'STORING', Wall: 'HOLDING', PowerPole: 'RELAYING', UnitProduction: 'TRAINING',
};

export class UI {
  root: HTMLElement;
  game: Game;
  view: View;
  panel: string | null = null;
  buildCat = 'miners';
  ghostDir: Dir = 0;
  statusEl!: HTMLElement;
  logEl!: HTMLElement;
  machineBody: HTMLElement | null = null;

  constructor(root: HTMLElement, game: Game, view: View) {
    this.root = root;
    this.game = game;
    this.view = view;
    this.render();
    setInterval(() => this.refresh(), 500);
  }

  placeMode(id: string | null): void {
    this.view.setGhost(id, this.ghostDir);
    if (id) this.panel = null;
    this.render();
  }

  render(): void {
    const g = this.game;
    this.machineBody = null;
    this.root.innerHTML = '';
    const bar = document.createElement('div');
    bar.className = 'topbar';
    bar.innerHTML = `<b>FactoryForge Web</b> <span id="fps"></span>`;
    const mkBtn = (label: string, fn: () => void, active = false): HTMLButtonElement => {
      const b = document.createElement('button');
      b.textContent = label;
      if (active) b.classList.add('active');
      b.onclick = (e) => { e.stopPropagation(); fn(); };
      bar.appendChild(b);
      return b;
    };
    mkBtn(g.paused ? '▶' : '⏸', () => { g.paused = !g.paused; this.render(); });
    mkBtn(`⚡${g.speed}x`, () => { g.speed = g.speed >= 8 ? 1 : g.speed * 2; this.render(); });
    mkBtn('Build (B)', () => this.toggle('build'), this.panel === 'build');
    mkBtn('Craft (C)', () => this.toggle('craft'), this.panel === 'craft');
    mkBtn('Bags (V)', () => this.toggle('inv'), this.panel === 'inv');
    mkBtn('Research (G)', () => this.toggle('research'), this.panel === 'research');
    mkBtn('Save', () => { g.save(); this.refresh(); });
    mkBtn('Load', () => { g.load(); this.refresh(); });
    mkBtn('?', () => this.toggle('help'), this.panel === 'help');
    this.root.appendChild(bar);

    this.statusEl = document.createElement('div');
    this.statusEl.className = 'status';
    this.root.appendChild(this.statusEl);

    this.logEl = document.createElement('div');
    this.logEl.className = 'log';
    this.root.appendChild(this.logEl);

    const panelEl = document.createElement('div');
    panelEl.className = 'panel';
    if (this.panel === 'build') this.buildPanel(panelEl);
    else if (this.panel === 'craft') this.craftPanel(panelEl);
    else if (this.panel === 'inv') this.invPanel(panelEl);
    else if (this.panel === 'research') this.researchPanel(panelEl);
    else if (this.panel === 'help') this.helpPanel(panelEl);
    else if (this.panel === 'machine') this.machinePanel(panelEl);
    if (panelEl.children.length > 0) this.root.appendChild(panelEl);
    this.refresh();
  }

  toggle(p: string): void {
    this.panel = this.panel === p ? null : p;
    this.render();
  }

  refresh(): void {
    const g = this.game;
    const q = g.player.craftQueue[0];
    const qtxt = q ? `Crafting ${iname(q.recipeId)} ${Math.floor(q.progress * 100)}% (${g.player.craftQueue.length} queued)` : '';
    const res = g.currentResearch
      ? `Research ${TECH_MAP.get(g.currentResearch)?.name} ${Math.floor(g.researchFraction() * 100)}%` : 'No research';
    const packs = g.spacePacks > 0 ? ` 🚀${g.spacePacks}` : '';
    this.statusEl.textContent =
      `HP ${Math.ceil(g.player.hp)} | (${Math.floor(g.player.x)}, ${Math.floor(g.player.y)}) | ${res} | ${qtxt}${packs}` +
      (this.view.ghostId ? ` | PLACING ${iname(this.view.ghostId)} (R rotate, Esc cancel)` : '') +
      (g.launched ? ' | 🏆 ROCKET LAUNCHED — YOU WIN' : '');
    this.logEl.innerHTML = g.log.map((l) => `<div>${l}</div>`).join('');
    this.refreshMachine();
  }

  // ---- panels ----
  buildPanel(el: HTMLElement): void {
    const cats = document.createElement('div');
    cats.className = 'cats';
    for (const c of BUILD_CATEGORIES) {
      const b = document.createElement('button');
      b.textContent = c.id;
      if (c.id === this.buildCat) b.classList.add('active');
      b.onclick = () => { this.buildCat = c.id; this.render(); };
      cats.appendChild(b);
    }
    el.appendChild(cats);
    const grid = document.createElement('div');
    grid.className = 'grid';
    const cat = BUILD_CATEGORIES.find((c) => c.id === this.buildCat)!;
    for (const bid of cat.buildings) {
      const def = BUILDING_MAP.get(bid)!;
      const b = document.createElement('button');
      b.className = 'tile';
      const afford = this.game.player.inv.has(def.cost);
      b.disabled = !afford;
      b.innerHTML = `<b>${def.name}</b><small>${def.cost.map((c) => `${c.count}×${iname(c.itemId)}`).join(' ')}</small>`;
      b.onclick = () => this.placeMode(bid);
      grid.appendChild(b);
    }
    el.appendChild(grid);
  }

  craftPanel(el: HTMLElement): void {
    const list = document.createElement('div');
    list.className = 'list';
    const recs = [...RECIPE_MAP.values()]
      .filter((r) => this.game.unlocked.has(r.id) && r.fluidInputs.length === 0 && r.outputs.length > 0)
      .sort((a, b) => a.order.localeCompare(b.order));
    for (const r of recs) {
      const row = document.createElement('div');
      row.className = 'row';
      const can = this.game.player.inv.has(r.inputs);
      row.innerHTML = `<span>${r.name}: ${r.inputs.map((i) => `${i.count}×${iname(i.itemId)}`).join(' + ')} → ${r.outputs.map((o) => `${o.count}×${iname(o.itemId)}`).join(' + ')} <small>${r.craftTime}s</small></span>`;
      const b = document.createElement('button');
      b.textContent = 'Craft';
      b.disabled = !can;
      b.onclick = () => { this.game.queueHandCraft(r.id); this.refresh(); };
      row.appendChild(b);
      list.appendChild(row);
    }
    el.appendChild(list);
  }

  invPanel(el: HTMLElement): void {
    const grid = document.createElement('div');
    grid.className = 'invgrid';
    for (const s of this.game.player.inv.slots) {
      const d = document.createElement('div');
      d.className = 'slot';
      d.textContent = s ? `${iname(s.itemId)} ×${s.count}` : '';
      d.title = s ? s.itemId : '';
      grid.appendChild(d);
    }
    el.appendChild(grid);
  }

  researchPanel(el: HTMLElement): void {
    const list = document.createElement('div');
    list.className = 'list';
    const done = this.game.completedTech;
    const avail = TECHNOLOGIES.filter((t) =>
      !done.has(t.id) && t.prerequisites.every((p) => done.has(p)));
    const locked = TECHNOLOGIES.filter((t) =>
      !done.has(t.id) && !t.prerequisites.every((p) => done.has(p)));
    const row = (t: (typeof TECHNOLOGIES)[0], state: string): void => {
      const d = document.createElement('div');
      d.className = 'row';
      d.innerHTML = `<span>[T${t.tier}] ${t.name} <small>${t.cost.map((c) => `${c.count}×${iname(c.packId)}`).join(' + ')} → ${t.unlocks.recipes.map(iname).join(', ')}</small> <i>${state}</i></span>`;
      if (state === 'available') {
        const b = document.createElement('button');
        b.textContent = 'Research';
        b.onclick = () => { this.game.startResearch(t.id); this.refresh(); };
        d.appendChild(b);
      }
      list.appendChild(d);
    };
    if (this.game.currentResearch) {
      const t = TECH_MAP.get(this.game.currentResearch)!;
      row(t, `${Math.floor(this.game.researchFraction() * 100)}%`);
    }
    for (const t of avail) if (t.id !== this.game.currentResearch) row(t, 'available');
    for (const t of [...done].map((id) => TECH_MAP.get(id)!)) row(t, 'done');
    for (const t of locked.slice(0, 12)) row(t, `needs ${t.prerequisites.filter((p) => !done.has(p)).join(',')}`);
    el.appendChild(list);
  }

  helpPanel(el: HTMLElement): void {
    el.innerHTML = `<div class="help">
    <b>FactoryForge Web — core loop</b><br>
    WASD/arrows move (5 tiles/s) · Click ore/tree: hand-mine · Space: attack<br>
    Walk up to any machine → [E] Use opens its panel · walking away closes it<br>
    Left-click place (ghost) · Right-drag pan camera · Wheel zoom · Q/E orbit · F follow<br>
    R rotate ghost · Esc cancel · B build · C craft · V bags · G research<br>
    Loop: burner drill on ore → stone furnace (iron/copper) → assembler (gears/circuits/belts)
    → lab + automation science → research → oil → rocket silo (100 parts + 50 fuel + 1 satellite) → launch 🚀<br>
    Machines need inputs: select → Load all. Burners need coal/wood. Electric needs poles + power.<br>
    Inserters auto-pull from behind, drop ahead. Rotate with R while selected? Select inserter then press R.
    </div>`;
  }

  // ---- machine face: a panel that looks like the machine it controls ----
  private machineState(e: Ent, def: BuildingDefinition): { lamp: string; text: string } {
    if ((def.powerConsumption ?? 0) > 0 && e.satisfaction <= 0) {
      return { lamp: 'red', text: 'NO POWER' };
    }
    if ((def.fuelSlots ?? 0) > 0 && e.fuel <= 0) {
      return { lamp: 'amber', text: 'NO FUEL' };
    }
    const producer = ['Assembler', 'ChemicalPlant', 'OilRefinery', 'Centrifuge'].includes(def.type);
    if (producer && !e.recipeId) return { lamp: 'amber', text: 'NO RECIPE' };
    if (isActive(e)) return { lamp: 'green', text: VERB[def.type] ?? 'RUNNING' };
    return { lamp: 'dim', text: 'IDLE' };
  }

  /** One Factorio-style slot: color chip + count, green/red rim vs need. */
  private slot(itemId: string, count: number, need?: number): string {
    const cls = need == null ? '' : count >= need ? ' ok' : ' short';
    return `<div class="mslot${cls}" title="${iname(itemId)}"><i style="--c:${hex(itemId)}"></i>` +
      `<b>${count}</b>${need != null ? `<s>/${need}</s>` : ''}<span>${iname(itemId)}</span></div>`;
  }

  private prog(pct: number, kind = ''): string {
    const p = Math.max(0, Math.min(100, Math.floor(pct * 100)));
    return `<div class="mprog ${kind}"><div class="mfill" style="width:${p}%"></div><em>${p}%</em></div>`;
  }

  private recipeOptions(e: Ent, def: BuildingDefinition): string {
    const cats = CATEGORY_BUILDINGS as unknown as Record<string, string[]>;
    const myCat = Object.entries(cats).find(([, ms]) =>
      ms.includes(def.id) ||
      (def.type === 'Furnace' && (def as { craftingCategory?: string }).craftingCategory === 'smelting'))?.[0];
    const cat = def.type === 'Assembler'
      ? ((def as { craftingCategory?: string }).craftingCategory ?? 'crafting')
      : myCat ?? 'chemistry';
    let h = '<option value="">— program —</option>';
    for (const r of [...RECIPE_MAP.values()].filter((r) =>
      r.category === cat && this.game.unlocked.has(r.id))) {
      h += `<option value="${r.id}"${e.recipeId === r.id ? ' selected' : ''}>${r.name}</option>`;
    }
    return h;
  }

  /** Flow view: inputs → work → outputs, with live have/need rims. */
  private flowBody(e: Ent, recipeId: string | null, flame = false): string {
    if (!recipeId) {
      return '<div class="mempty">NO PROGRAM — pick one above to start the line.</div>' + this.bufferGrid(e);
    }
    const r = RECIPE_MAP.get(recipeId);
    if (!r) return this.bufferGrid(e);
    const ins = r.inputs.map((i) =>
      this.slot(i.itemId, e.inv[i.itemId] ?? 0, i.count)).join('');
    const outs = r.outputs.map((o) => this.slot(o.itemId, e.inv[o.itemId] ?? 0)).join('');
    const mid = flame
      ? `<div class="mfire${isActive(e) ? ' lit' : ''}">🔥</div>`
      : '<div class="mgear">⚙</div>';
    return `<div class="mflow"><div class="mcol"><label>IN</label><div class="mslots">${ins}</div></div>` +
      `${mid}<div class="mcol"><label>OUT</label><div class="mslots">${outs}</div></div></div>` +
      this.prog(e.progress, flame ? 'heat' : '') + this.bufferGrid(e);
  }

  private bufferGrid(e: Ent): string {
    const keys = Object.keys(e.inv).filter((k) => (e.inv[k] ?? 0) > 0);
    if (keys.length === 0 && Object.keys(e.fluid).length === 0) {
      return '<div class="mempty">BUFFER EMPTY</div>';
    }
    let h = '<div class="mbuffer"><label>BUFFER</label><div class="mslots">';
    for (const k of keys) h += this.slot(k, e.inv[k] ?? 0);
    for (const [k, v] of Object.entries(e.fluid)) {
      if (v > 0) h += `<div class="mslot fluid" title="${pretty(k)}"><i class="drop"></i><b>${Math.floor(v)}</b><span>${pretty(k)}</span></div>`;
    }
    return h + '</div></div>';
  }

  private fuelGauge(e: Ent): string {
    if (e.fuel <= 0) return '<div class="mfuel"><label>FUEL</label><div class="mempty">EMPTY — load coal / wood</div></div>';
    const w = Math.min(100, e.fuel);
    return `<div class="mfuel"><label>FUEL ⛽ ${e.fuel.toFixed(0)}s</label>` +
      `<div class="mprog fuel"><div class="mfill" style="width:${w}%"></div></div></div>`;
  }

  private powerStrip(e: Ent, def: BuildingDefinition): string {
    const need = def.powerConsumption ?? 0;
    if (!need && !def.powerProduction) return '';
    if (def.powerProduction) {
      return `<div class="mpower"><label>⚡ OUTPUT ${def.powerProduction}</label>` +
        `<div class="mprog power"><div class="mfill" style="width:${e.satisfaction * 100}%"></div></div></div>`;
    }
    return `<div class="mpower"><label>⚡ GRID ${Math.floor(e.satisfaction * 100)}% <small>needs ${need}</small></label>` +
      `<div class="mprog power"><div class="mfill" style="width:${e.satisfaction * 100}%"></div></div></div>`;
  }

  private machineBodyHtml(e: Ent, def: BuildingDefinition): string {
    switch (def.type) {
      case 'Furnace': {
        const rname = e.recipeId ? (RECIPE_MAP.get(e.recipeId)?.name ?? iname(e.recipeId)) : 'auto-smelt';
        return `<div class="msub">${rname}</div>` + this.flowBody(e, e.recipeId, true) + this.fuelGauge(e);
      }
      case 'Assembler': case 'ChemicalPlant': case 'OilRefinery': case 'Centrifuge': {
        return `<select class="mchip">${this.recipeOptions(e, def)}</select>` +
          this.flowBody(e, e.recipeId);
      }
      case 'Miner': {
        const burner = (def.powerConsumption ?? 0) === 0;
        const hasFuel = e.fuel > 0 ||
          ['coal', 'wood', 'solid-fuel'].some((f) => (e.inv[f] ?? 0) > 0);
        // Mirror the sim's exact lookup so the diagnosis can't disagree with it.
        const dep = this.game.world.resourceNear(e.x, e.y, 2);
        const out = Object.keys(e.inv).filter((k) => (e.inv[k] ?? 0) > 0 &&
          !['coal', 'wood', 'solid-fuel'].includes(k));
        let note = '';
        if (burner && !hasFuel) {
          note = '<div class="mempty warn">NO FUEL — press LOAD ALL to feed coal / wood</div>';
        } else if (!burner && e.satisfaction <= 0) {
          note = '<div class="mempty warn">NO POWER — connect poles + generation</div>';
        } else if (!dep) {
          note = '<div class="mempty warn">NO ORE IN RANGE — move the drill onto the patch</div>';
        } else if (out.length === 0 && e.progress > 0.02) {
          note = `<div class="msub">MINING ${iname(dep.outputItem)}…</div>`;
        }
        const slots = out.length > 0
          ? `<div class="mslots">${out.map((k) => this.slot(k, e.inv[k] ?? 0)).join('')}</div>`
          : '';
        return `<div class="mdrill"><div class="mbit${isActive(e) ? ' spin' : ''}">🛠</div></div>` +
          this.prog(e.progress) + note + slots + (burner ? this.fuelGauge(e) : '');
      }
      case 'Pumpjack': case 'WaterPump': {
        const fluids = Object.entries(e.fluid);
        const h = fluids.length > 0 && fluids.some(([, v]) => v > 0)
          ? `<div class="mslots">${fluids.filter(([, v]) => v > 0).map(([k, v]) =>
            `<div class="mslot fluid"><i class="drop"></i><b>${Math.floor(v)}</b><span>${pretty(k)}</span></div>`).join('')}</div>`
          : '<div class="mempty">NO FLUID — check placement + power</div>';
        return `<div class="msub">${pretty((def as { fluidOutputType?: string }).fluidOutputType ?? 'fluid')} · ` +
          `rate ${(def as { extractionRate?: number }).extractionRate ?? '?'}/s</div>` + h;
      }
      case 'Lab': {
        const packs = Object.keys(e.inv).filter((k) => (e.inv[k] ?? 0) > 0);
        const cur = this.game.currentResearch ? TECH_MAP.get(this.game.currentResearch)?.name ?? '' : '';
        return (this.game.currentResearch
          ? `<div class="msub">🔬 ${cur}</div>` + this.prog(this.game.researchFraction(), 'sci')
          : '<div class="mempty">NO ACTIVE RESEARCH — press G</div>') +
          (packs.length > 0
            ? `<div class="mslots">${packs.map((k) => this.slot(k, e.inv[k] ?? 0)).join('')}</div>`
            : '<div class="mempty">NO SCIENCE PACKS LOADED</div>');
      }
      case 'RocketSilo': {
        if (e.launching) return `<div class="mlaunch">🚀 LAUNCH ${Math.floor((e.launchT / 10) * 100)}%</div>` + this.prog(e.launchT / 10, 'sci');
        const need: [string, number][] = [['rocket-parts', 100], ['rocket-fuel', 50], ['satellite', 1]];
        const rows = need.map(([k, n]) => {
          const have = e.inv[k] ?? 0;
          return `<div class="mcheck${have >= n ? ' ok' : ''}">${have >= n ? '✓' : '○'} ${iname(k)} — ${have}/${n}</div>`;
        }).join('');
        return `<div class="mrocket">🚀</div>${rows}${e.assembled ? '<div class="mready">ASSEMBLED — READY</div>' : ''}`;
      }
      case 'Turret': {
        const ammo = Object.keys(e.inv).filter((k) => (e.inv[k] ?? 0) > 0);
        const d = def as { turretRange?: number; turretDamage?: number; turretFireRate?: number };
        return `<div class="mstats">RANGE ${d.turretRange ?? '?'} · DMG ${d.turretDamage ?? '?'} · RATE ${d.turretFireRate ?? '?'}</div>` +
          (ammo.length > 0
            ? `<div class="mslots">${ammo.map((k) => this.slot(k, e.inv[k] ?? 0)).join('')}</div>`
            : '<div class="mempty">NO AMMO — Load all to feed mags</div>');
      }
      case 'Generator': {
        if (def.id === 'boiler') return this.fuelGauge(e) + '<div class="msub">BOILS WATER → STEAM</div>';
        return `<div class="mstats">⚡ 900 · STEAM 540</div>` + this.powerStrip(e, def);
      }
      case 'NuclearReactor': {
        const fuel = Object.keys(e.inv).filter((k) => (e.inv[k] ?? 0) > 0);
        return (fuel.length > 0
          ? `<div class="mslots">${fuel.map((k) => this.slot(k, e.inv[k] ?? 0)).join('')}</div>`
          : '<div class="mempty">NO FUEL CELLS</div>') + '<div class="mstats">⚡ 40000 · NEIGHBOUR BONUS APPLIES</div>';
      }
      case 'SolarPanel': case 'Accumulator': case 'PowerPole': {
        const d = def as { accumulatorCapacity?: number; wireReach?: number; supplyArea?: number };
        const spec = def.type === 'PowerPole'
          ? `REACH ${d.wireReach ?? '?'} · AREA ${d.supplyArea ?? '?'}`
          : def.type === 'Accumulator' ? `STORE ${d.accumulatorCapacity ?? '?'}` : '⚡ 60 DAYTIME';
        return `<div class="mstats">${spec}</div>` + this.powerStrip(e, def);
      }
      case 'Chest': case 'FluidTank': case 'UnitProduction': {
        return this.bufferGrid(e);
      }
      case 'Belt': {
        const n = e.left.length + e.right.length;
        return `<div class="mstats">ON BELT: ${n} ITEMS</div>` + this.prog(Math.min(1, n / 8), 'belt');
      }
      case 'Pipe': {
        return this.bufferGrid(e);
      }
      case 'Inserter': {
        return `<div class="mstats">${e.held ? `HOLDING ${iname(e.held)}` : 'HAND EMPTY'} · ${Math.floor(e.satisfaction * 100)}% PWR</div>`;
      }
      default:
        return this.bufferGrid(e);
    }
  }

  machinePanel(el: HTMLElement): void {
    const e = this.game.world.entities.get(this.view.selectedId ?? -1);
    if (!e) { el.innerHTML = '<i>no selection</i>'; return; }
    const def = BUILDING_MAP.get(e.buildingId)!;
    const st = this.machineState(e, def);
    const hp = Math.max(0, Math.ceil((e.hp / def.maxHealth) * 100));
    const frame = document.createElement('div');
    frame.className = `machine mtype-${def.type.toLowerCase()}`;
    frame.innerHTML =
      `<div class="mhead"><span class="mlamp ${st.lamp}" id="mc-lamp"></span>` +
      `<div class="mtitle"><b>${def.name}</b><small id="mc-state">${st.text}</small></div>` +
      `<button class="mx" id="mc-x">✕</button></div>` +
      `<div class="mhp"><div class="mhp-fill" id="mc-hp" style="width:${hp}%"></div><span>HP ${Math.ceil(e.hp)}/${def.maxHealth}</span></div>` +
      this.powerStrip(e, def) +
      `<div class="mbody" id="mc-body">${this.machineBodyHtml(e, def)}</div>` +
      `<div class="mkeys"><button id="mc-load">⇪ LOAD ALL</button>` +
      `<button id="mc-take">⇩ TAKE ALL</button>` +
      `<button id="mc-demo" class="danger">✖ DEMOLISH</button></div>`;
    el.appendChild(frame);
    (frame.querySelector('#mc-x') as HTMLButtonElement).onclick = () => {
      this.view.selectedId = null; this.panel = null; this.render();
    };
    (frame.querySelector('#mc-load') as HTMLButtonElement).onclick = () => { this.loadMachine(e.id); this.refreshMachine(); };
    (frame.querySelector('#mc-take') as HTMLButtonElement).onclick = () => { this.takeMachine(e.id); this.refreshMachine(); };
    (frame.querySelector('#mc-demo') as HTMLButtonElement).onclick = () => {
      const gone = this.game.world.remove(e.id);
      if (gone) for (const [k, v] of Object.entries(gone.inv)) this.game.player.inv.add(k, v);
      this.view.selectedId = null; this.panel = null; this.render();
    };
    const sel = frame.querySelector('select.mchip') as HTMLSelectElement | null;
    if (sel) {
      sel.onchange = () => {
        e.recipeId = sel.value || null; e.progress = 0;
        const body = frame.querySelector('#mc-body');
        if (body) body.innerHTML = this.machineBodyHtml(e, def);
        this.rewireChip(frame, e, def);
        this.refreshMachine();
      };
    }
    this.machineBody = frame.querySelector('#mc-body');
  }

  /** Re-attach the recipe picker handler after a body re-render. */
  private rewireChip(frame: HTMLElement, e: Ent, def: BuildingDefinition): void {
    const sel = frame.querySelector('select.mchip') as HTMLSelectElement | null;
    if (sel) {
      sel.onchange = () => {
        e.recipeId = sel.value || null; e.progress = 0;
        const body = frame.querySelector('#mc-body');
        if (body) body.innerHTML = this.machineBodyHtml(e, def);
        this.rewireChip(frame, e, def);
        this.refreshMachine();
      };
    }
  }

  /** Live-update the open machine face (500ms tick + after actions). */
  refreshMachine(): void {
    if (this.panel !== 'machine' || !this.machineBody || !this.machineBody.isConnected) return;
    const e = this.game.world.entities.get(this.view.selectedId ?? -1);
    if (!e) return;
    const def = BUILDING_MAP.get(e.buildingId)!;
    // Never clobber the recipe picker mid-interaction.
    const ae = document.activeElement;
    if (ae && ae.tagName === 'SELECT' && this.machineBody.contains(ae)) return;
    const st = this.machineState(e, def);
    const lamp = document.getElementById('mc-lamp');
    if (lamp) lamp.className = `mlamp ${st.lamp}`;
    const state = document.getElementById('mc-state');
    if (state) state.textContent = st.text;
    const hp = document.getElementById('mc-hp') as HTMLElement | null;
    if (hp) hp.style.width = `${Math.max(0, Math.ceil((e.hp / def.maxHealth) * 100))}%`;
    this.machineBody.innerHTML = this.machineBodyHtml(e, def);
    const frame = this.machineBody.closest('.machine') as HTMLElement | null;
    if (frame) this.rewireChip(frame, e, def);
  }

  loadMachine(id: number): void {
    const e = this.game.world.entities.get(id);
    if (!e) return;
    const p = this.game.player.inv;
    // fuel first for burners
    for (const f of ['coal', 'wood', 'solid-fuel']) {
      const have = p.count(f);
      if (have > 0) { p.remove(f, have); e.inv[f] = (e.inv[f] ?? 0) + have; }
    }
    // ammo for gun turrets
    for (const a of ['firearm-magazine', 'piercing-rounds-magazine']) {
      const have = p.count(a);
      if (have > 0) { p.remove(a, Math.min(have, 50)); e.inv[a] = (e.inv[a] ?? 0) + Math.min(have, 50); }
    }
    // science packs for labs
    for (const s of ['automation-science-pack', 'logistic-science-pack', 'chemical-science-pack']) {
      const have = p.count(s);
      if (have > 0) { p.remove(s, have); e.inv[s] = (e.inv[s] ?? 0) + have; }
    }
    // recipe inputs
    if (e.recipeId) {
      const r = RECIPE_MAP.get(e.recipeId)!;
      for (const i of r.inputs) {
        const have = p.count(i.itemId);
        if (have > 0) { const n = Math.min(have, 100); p.remove(i.itemId, n); e.inv[i.itemId] = (e.inv[i.itemId] ?? 0) + n; }
      }
    } else {
      // furnace auto inputs
      for (const o of ['iron-ore', 'copper-ore', 'stone', 'iron-plate']) {
        const have = p.count(o);
        if (have > 0) { const n = Math.min(have, 100); p.remove(o, n); e.inv[o] = (e.inv[o] ?? 0) + n; }
      }
      // silo parts
      for (const o of ['rocket-parts', 'rocket-fuel', 'satellite']) {
        const have = p.count(o);
        if (have > 0) { p.remove(o, have); e.inv[o] = (e.inv[o] ?? 0) + have; }
      }
    }
  }

  takeMachine(id: number): void {
    const e = this.game.world.entities.get(id);
    if (!e) return;
    for (const [k, v] of Object.entries(e.inv)) {
      if (v > 0) {
        const left = this.game.player.inv.add(k, v);
        e.inv[k] = left;
      }
    }
  }

  openMachine(): void {
    this.panel = 'machine';
    this.render();
  }
}
