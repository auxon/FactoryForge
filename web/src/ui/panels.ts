// DOM UI: HUD + Build/Craft/Inventory/Research/Machine panels.
import { BUILD_CATEGORIES, BUILDING_MAP } from '../data/buildings';
import { RECIPE_MAP } from '../data/recipes';
import { ITEM_MAP } from '../data/items';
import { TECH_MAP, TECHNOLOGIES } from '../data/tech';
import { CATEGORY_BUILDINGS } from '../data/types';
import type { Game } from '../sim/game';
import type { View } from '../render/view';
import type { Dir } from '../sim/world';

const iname = (id: string): string => ITEM_MAP.get(id)?.name ?? id;

export class UI {
  root: HTMLElement;
  game: Game;
  view: View;
  panel: string | null = null;
  buildCat = 'miners';
  ghostDir: Dir = 0;
  statusEl!: HTMLElement;
  logEl!: HTMLElement;

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

  machinePanel(el: HTMLElement): void {
    const e = this.game.world.entities.get(this.view.selectedId ?? -1);
    if (!e) { el.innerHTML = '<i>no selection</i>'; return; }
    const def = BUILDING_MAP.get(e.buildingId)!;
    const wrap = document.createElement('div');
    wrap.innerHTML = `<b>${def.name}</b> <small>HP ${Math.ceil(e.hp)}/${def.maxHealth} · power ${(e.satisfaction * 100).toFixed(0)}%</small> `;
    const close = document.createElement('button');
    close.textContent = '✕';
    close.onclick = () => { this.view.selectedId = null; this.panel = null; this.render(); };
    wrap.appendChild(close);

    // recipe picker for producers
    const cats: Record<string, string[]> = CATEGORY_BUILDINGS as unknown as Record<string, string[]>;
    const myCat = Object.entries(cats).find(([, ms]) =>
      ms.includes(e.buildingId) ||
      (def.type === 'Furnace' && def.craftingCategory === 'smelting'))?.[0];
    if (def.type === 'Assembler' || def.type === 'ChemicalPlant' || def.type === 'OilRefinery' || def.type === 'Centrifuge') {
      const cat = def.type === 'Assembler' ? (BUILDING_MAP.get(e.buildingId)?.craftingCategory ?? 'crafting') : myCat ?? 'chemistry';
      const sel = document.createElement('select');
      sel.innerHTML = '<option value="">— recipe —</option>';
      for (const r of [...RECIPE_MAP.values()].filter((r) => r.category === cat && this.game.unlocked.has(r.id))) {
        const o = document.createElement('option');
        o.value = r.id; o.textContent = r.name;
        if (e.recipeId === r.id) o.selected = true;
        sel.appendChild(o);
      }
      sel.onchange = () => { e.recipeId = sel.value || null; e.progress = 0; this.refresh(); };
      wrap.appendChild(sel);
      if (e.recipeId) {
        const r = RECIPE_MAP.get(e.recipeId)!;
        const p = document.createElement('div');
        p.textContent = `progress ${Math.floor(e.progress * 100)}% — ` +
          r.inputs.map((i) => {
            const have = (e.inv[i.itemId] ?? 0) + this.game.player.inv.count(i.itemId);
            return `${have >= i.count ? '✓' : '✗'} ${i.count}×${iname(i.itemId)}`;
          }).join(' · ');
        wrap.appendChild(p);
      }
    }
    if (def.type === 'Furnace') {
      const d = document.createElement('div');
      d.textContent = e.recipeId ? `smelting ${iname(e.recipeId)} ${Math.floor(e.progress * 100)}% · fuel ${e.fuel.toFixed(1)}s` : 'auto-selects from inputs · needs fuel if burner';
      wrap.appendChild(d);
    }
    if (def.type === 'Lab') {
      const d = document.createElement('div');
      d.textContent = this.game.currentResearch
        ? `researching ${TECH_MAP.get(this.game.currentResearch)?.name} ${Math.floor(this.game.researchFraction() * 100)}%`
        : 'no active research (press G)';
      wrap.appendChild(d);
    }
    if (def.type === 'RocketSilo') {
      const d = document.createElement('div');
      d.textContent = e.launching ? `LAUNCHING ${Math.floor((e.launchT / 10) * 100)}%`
        : e.assembled ? 'assembled' : `needs 100 rocket-parts (${e.inv['rocket-parts'] ?? 0}) + 50 rocket-fuel (${e.inv['rocket-fuel'] ?? 0}) + 1 satellite (${e.inv['satellite'] ?? 0})`;
      wrap.appendChild(d);
    }
    // buffers
    const buf = document.createElement('div');
    buf.className = 'buf';
    const keys = Object.keys(e.inv).filter((k) => (e.inv[k] ?? 0) > 0);
    buf.textContent = keys.length > 0
      ? keys.map((k) => `${iname(k)} ×${e.inv[k]}`).join(' · ') : '(empty)';
    wrap.appendChild(buf);
    // transfer buttons
    const row = document.createElement('div');
    row.className = 'btnrow';
    const load = document.createElement('button');
    load.textContent = 'Load all (from bags)';
    load.onclick = () => { this.loadMachine(e.id); this.render(); };
    const take = document.createElement('button');
    take.textContent = 'Take all';
    take.onclick = () => { this.takeMachine(e.id); this.render(); };
    const del = document.createElement('button');
    del.textContent = 'Demolish';
    del.onclick = () => {
      const gone = this.game.world.remove(e.id);
      if (gone) for (const [k, v] of Object.entries(gone.inv)) this.game.player.inv.add(k, v);
      this.view.selectedId = null; this.panel = null; this.render();
    };
    row.append(load, take, del);
    wrap.appendChild(row);
    el.appendChild(wrap);
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
