import type { GameLoop } from '../engine/core/GameLoop';
import type { InputManager } from '../engine/input/InputManager';
import {
  inventoryCount,
  type AssemblerComponent,
  type InventoryComponent,
  type PositionComponent,
} from '../game/components';
import { listSaves, writeSave, readSave, deleteSave } from '../game/data/SaveStore';
import { assets } from '../engine/render/AssetCatalog';

export class Hud {
  root: HTMLElement;
  private panels: Record<string, HTMLElement> = {};
  private statusEl!: HTMLElement;
  view3d = false;
  private game: GameLoop;

  constructor(
    root: HTMLElement,
    game: GameLoop,
    private input: InputManager,
  ) {
    this.root = root;
    this.game = game;
    this.build();
    this.setInGame(false);
  }

  setGame(game: GameLoop): void {
    this.game = game;
  }

  setInGame(active: boolean): void {
    const hud = this.root.querySelector('.hud-shell') as HTMLElement | null;
    if (hud) hud.classList.toggle('hidden', !active);
  }

  private build(): void {
    this.root.innerHTML = `
      <div class="hud-shell hidden">
      <div class="hud-top">
        <div class="brand">FactoryForge</div>
        <div id="status" class="status"></div>
        <div class="toolbar">
          <button data-act="inv"><img src="/assets/inventory.png" alt="" class="tb-icon" /> Inventory</button>
          <button data-act="craft"><img src="/assets/gear.png" alt="" class="tb-icon" /> Craft</button>
          <button data-act="build"><img src="/assets/build.png" alt="" class="tb-icon" /> Build</button>
          <button data-act="research"><img src="/assets/research.png" alt="" class="tb-icon" /> Research</button>
          <button data-act="menu"><img src="/assets/menu.png" alt="" class="tb-icon" /> Menu</button>
          <button data-act="view">View 2D/3D</button>
          <button data-act="pause">Pause</button>
        </div>
      </div>
      <div id="panel-inv" class="panel hidden"></div>
      <div id="panel-craft" class="panel hidden"></div>
      <div id="panel-build" class="panel hidden"></div>
      <div id="panel-research" class="panel hidden"></div>
      <div id="panel-menu" class="panel hidden"></div>
      <div id="panel-machine" class="panel hidden"></div>
      <div id="panel-lobby" class="panel hidden"></div>
      <div id="panel-autoplay" class="panel hidden"></div>
      <div id="overlay-msg" class="overlay hidden"></div>
      <div class="help-hint">WASD move · Wheel zoom · MMB/RMB pan · LMB mine/select · R rotate · Esc deselect · B build</div>
      </div>
    `;
    this.statusEl = this.root.querySelector('#status')!;
    for (const id of ['inv', 'craft', 'build', 'research', 'menu', 'machine', 'lobby', 'autoplay']) {
      this.panels[id] = this.root.querySelector(`#panel-${id}`)!;
    }
    this.root.querySelector('.toolbar')!.addEventListener('click', (e) => {
      const btn = (e.target as HTMLElement).closest('button');
      if (!btn) return;
      const act = btn.getAttribute('data-act');
      if (act === 'inv') this.toggle('inv');
      if (act === 'craft') this.toggle('craft');
      if (act === 'build') this.toggle('build');
      if (act === 'research') this.toggle('research');
      if (act === 'menu') this.toggle('menu');
      if (act === 'pause') this.game.togglePause();
      if (act === 'view') {
        this.view3d = !this.view3d;
        this.root.dispatchEvent(new CustomEvent('toggle-view', { detail: this.view3d }));
      }
    });
  }

  toggle(name: string): void {
    const p = this.panels[name];
    if (!p) return;
    const opening = p.classList.contains('hidden');
    for (const panel of Object.values(this.panels)) panel.classList.add('hidden');
    if (opening) {
      p.classList.remove('hidden');
      this.renderPanel(name);
    }
  }

  hideAll(): void {
    for (const panel of Object.values(this.panels)) panel.classList.add('hidden');
  }

  showMessage(title: string, body: string): void {
    const el = this.root.querySelector('#overlay-msg')!;
    el.classList.remove('hidden');
    el.innerHTML = `<div class="modal"><h2>${title}</h2><p>${body}</p><button id="msg-ok">OK</button></div>`;
    el.querySelector('#msg-ok')!.addEventListener('click', () => el.classList.add('hidden'));
  }

  private renderPanel(name: string): void {
    if (name === 'inv') this.renderInventory();
    if (name === 'craft') this.renderCraft();
    if (name === 'build') this.renderBuild();
    if (name === 'research') this.renderResearch();
    if (name === 'menu') this.renderMenu();
    if (name === 'machine') this.renderMachine();
    if (name === 'lobby') this.renderLobby();
    if (name === 'autoplay') this.renderAutoPlay();
  }

  private renderInventory(): void {
    const inv = this.game.playerManager.getInventory(this.game.localPlayerId);
    if (!inv) return;
    this.panels.inv!.innerHTML = `<h3>Inventory</h3><div class="grid">${inv.slots
      .map((s, i) => {
        if (!s.itemId) return `<div class="slot empty">${i}</div>`;
        const url = assets.iconUrl(s.itemId);
        return `<div class="slot has-item" title="${s.itemId}"><img src="${url}" alt="${s.itemId}" /><span>${s.count}</span></div>`;
      })
      .join('')}</div>`;
  }

  private renderCraft(): void {
    const recipes = this.game.recipeRegistry.all.filter(
      (r) =>
        (r.category === 'crafting' || r.category === 'smelting') &&
        (this.game.researchSystem.unlockedRecipes.has(r.id) || r.category === 'smelting'),
    );
    this.panels.craft!.innerHTML = `<h3>Crafting</h3><div class="list">${recipes
      .map(
        (r) =>
          `<button class="list-item" data-recipe="${r.id}"><b>${r.name}</b><span>${r.inputs.map((i) => `${i.count} ${i.itemId}`).join(', ')}</span></button>`,
      )
      .join('')}</div>`;
    this.panels.craft!.onclick = (e) => {
      const btn = (e.target as HTMLElement).closest('[data-recipe]') as HTMLElement | null;
      if (!btn) return;
      this.game.queueCraft(btn.dataset.recipe!);
    };
  }

  private renderBuild(): void {
    const unlocked = this.game.researchSystem.unlockedRecipes;
    const buildings = this.game.buildingRegistry.all.filter(
      (b) => unlocked.has(b.id) || ['burner-mining-drill', 'stone-furnace', 'transport-belt', 'inserter', 'wooden-chest', 'small-electric-pole', 'pipe', 'boiler', 'steam-engine', 'water-pump', 'lab', 'gun-turret', 'wall', 'stone-wall'].includes(b.id),
    );
    this.panels.build!.innerHTML = `<h3>Build</h3><p>Click a building, then LMB to place. R rotates. Right-click cancels.</p><div class="list build-list">${buildings
      .map((b) => {
        const url = assets.iconUrl(b.id);
        return `<button class="list-item build-item" data-build="${b.id}"><img src="${url}" alt="" /><span><b>${b.name}</b><br/><em>${b.type}</em></span></button>`;
      })
      .join('')}</div>
      <div class="row">
        <button data-mode="remove">Remove mode</button>
        <button data-mode="none">Cancel</button>
      </div>`;
    this.panels.build!.onclick = (e) => {
      const t = e.target as HTMLElement;
      const build = t.closest('[data-build]') as HTMLElement | null;
      if (build) {
        this.input.buildMode = 'placing';
        this.input.placeBuildingId = build.dataset.build!;
        this.hideAll();
        this.input.focusGame();
        return;
      }
      const mode = t.closest('[data-mode]') as HTMLElement | null;
      if (mode?.dataset.mode === 'remove') {
        this.input.buildMode = 'removing';
        this.input.placeBuildingId = null;
        this.hideAll();
        this.input.focusGame();
      }
      if (mode?.dataset.mode === 'none') {
        this.input.buildMode = 'none';
        this.input.placeBuildingId = null;
        this.hideAll();
        this.input.focusGame();
      }
    };
  }

  private renderResearch(): void {
    const techs = this.game.technologyRegistry.all;
    this.panels.research!.innerHTML = `<h3>Research</h3><p>Current: ${this.game.researchSystem.currentResearchId ?? 'none'}</p><div class="list">${techs
      .map((t) => {
        const done = this.game.researchSystem.completed.has(t.id);
        const prog = this.game.researchSystem.progress.get(t.id) ?? 0;
        return `<button class="list-item" data-tech="${t.id}" ${done ? 'disabled' : ''}><b>${t.name}</b><span>${done ? 'Done' : `${(prog * 100).toFixed(0)}%`} · ${t.cost.map((c) => `${c.count} ${c.itemId}`).join(', ')}</span></button>`;
      })
      .join('')}</div>`;
    this.panels.research!.onclick = (e) => {
      const btn = (e.target as HTMLElement).closest('[data-tech]') as HTMLElement | null;
      if (!btn) return;
      this.game.researchSystem.startResearch(btn.dataset.tech!);
      this.renderResearch();
    };
  }

  private renderMenu(): void {
    const saves = listSaves();
    this.panels.menu!.innerHTML = `
      <h3>Menu</h3>
      <div class="row">
        <button id="save-game">Save</button>
        <button id="new-game">New Game</button>
      </div>
      <h4>Load</h4>
      <div class="list">${saves.map((s) => `<button class="list-item" data-load="${s}">${s}</button>`).join('') || '<p>No saves</p>'}</div>
      <h4>Modes</h4>
      <div class="row">
        <button id="start-pvai">Start PvAI</button>
        <button id="open-lobby">Lobby</button>
        <button id="open-autoplay">AutoPlay</button>
      </div>
      <h4>Help</h4>
      <p>Launch a rocket with a satellite to win. Automate mining, smelting, power, research, and defense.</p>
    `;
    this.panels.menu!.querySelector('#save-game')!.addEventListener('click', () => {
      const slot = `save_${new Date().toISOString().replace(/[:.]/g, '-')}`;
      writeSave(slot, this.game.serializeSave());
      this.renderMenu();
      this.showMessage('Saved', slot);
    });
    this.panels.menu!.querySelector('#new-game')!.addEventListener('click', () => {
      location.reload();
    });
    this.panels.menu!.querySelector('#start-pvai')!.addEventListener('click', () => {
      this.game.startPvAI();
      this.showMessage('PvAI', 'AI opponents spawned. Survive and outproduce them.');
    });
    this.panels.menu!.querySelector('#open-lobby')!.addEventListener('click', () => this.toggle('lobby'));
    this.panels.menu!.querySelector('#open-autoplay')!.addEventListener('click', () => this.toggle('autoplay'));
    this.panels.menu!.onclick = (e) => {
      const btn = (e.target as HTMLElement).closest('[data-load]') as HTMLElement | null;
      if (!btn) return;
      const save = readSave(btn.dataset.load!);
      if (save) {
        this.game.loadSave(save);
        this.showMessage('Loaded', btn.dataset.load!);
      }
    };
  }

  renderMachine(): void {
    const id = this.game.selectedEntities[0];
    if (id === undefined) {
      this.panels.machine!.innerHTML = '<h3>Machine</h3><p>No selection</p>';
      return;
    }
    const entity = this.game.world.entities.find((e) => e.id === id);
    if (!entity) return;
    const sprite = this.game.world.getByName<{ textureId: string }>('sprite', entity);
    const inv = this.game.world.getByName<InventoryComponent>('inventory', entity);
    const asm = this.game.world.getByName<AssemblerComponent>('assembler', entity);
    let html = `<h3>${sprite?.textureId ?? 'Machine'}</h3>`;
    if (inv) {
      html += `<div class="grid">${inv.slots
        .filter((s) => s.itemId)
        .map((s) => {
          const url = assets.iconUrl(s.itemId!);
          return `<div class="slot has-item" title="${s.itemId}"><img src="${url}" alt="" /><span>${s.count}</span></div>`;
        })
        .join('')}</div>`;
    }
    if (asm) {
      const recipes = this.game.recipeRegistry.byCategory('crafting').slice(0, 30);
      html += `<h4>Recipe: ${asm.recipeId ?? 'none'}</h4><div class="list">${recipes
        .map((r) => `<button class="list-item" data-set-recipe="${r.id}">${r.name}</button>`)
        .join('')}</div>`;
    }
    html += `<div class="row"><button id="rot">Rotate</button><button id="del">Delete</button></div>`;
    this.panels.machine!.innerHTML = html;
    this.panels.machine!.querySelector('#rot')?.addEventListener('click', () => this.game.rotateSelected());
    this.panels.machine!.querySelector('#del')?.addEventListener('click', () => {
      const pos = this.game.world.getByName<PositionComponent>('position', entity);
      if (pos) this.game.removeBuildingAt(pos.tileX, pos.tileY);
      this.hideAll();
    });
    this.panels.machine!.onclick = (e) => {
      const btn = (e.target as HTMLElement).closest('[data-set-recipe]') as HTMLElement | null;
      if (!btn) return;
      this.game.setAssemblerRecipe(id, btn.dataset.setRecipe!);
      this.renderMachine();
    };
  }

  private renderLobby(): void {
    this.game.lobby.reset(8);
    this.panels.lobby!.innerHTML = `
      <h3>Lobby</h3>
      <p>Mode: ${this.game.lobby.config.mode}</p>
      <div class="row">
        <button id="add-ai">Add AI</button>
        <button id="start-match">Start Match</button>
        <button id="connect-mp">Connect Multiplayer</button>
      </div>
      <div id="lobby-slots"></div>
      <input id="ws-url" value="ws://localhost:8080" style="width:100%;margin-top:8px" />
    `;
    const renderSlots = () => {
      this.panels.lobby!.querySelector('#lobby-slots')!.innerHTML = this.game.lobby.slots
        .map((s) => `<div class="slot-row">${s.slotId}: ${s.name || 'empty'} ${s.isAI ? '(AI)' : ''} ${s.ready ? 'ready' : ''}</div>`)
        .join('');
    };
    renderSlots();
    this.panels.lobby!.querySelector('#add-ai')!.addEventListener('click', () => {
      this.game.lobby.addAI();
      renderSlots();
    });
    this.panels.lobby!.querySelector('#start-match')!.addEventListener('click', () => {
      this.game.startPvAI();
      this.showMessage('Match', 'Local PvAI match started');
      this.hideAll();
    });
    this.panels.lobby!.querySelector('#connect-mp')!.addEventListener('click', () => {
      const url = (this.panels.lobby!.querySelector('#ws-url') as HTMLInputElement).value;
      this.root.dispatchEvent(new CustomEvent('mp-connect', { detail: url }));
    });
  }

  private renderAutoPlay(): void {
    const scenarios = this.game.autoPlaySystem.listScenarios();
    this.panels.autoplay!.innerHTML = `<h3>AutoPlay</h3><div class="list">${scenarios
      .map((s) => `<button class="list-item" data-scenario="${s}">${s}</button>`)
      .join('')}</div>
      <div class="row">
        <button data-speed="1">1x</button>
        <button data-speed="2">2x</button>
        <button data-speed="4">4x</button>
        <button data-speed="0">Pause</button>
        <button id="stop-ap">Stop</button>
      </div>`;
    this.panels.autoplay!.onclick = (e) => {
      const t = e.target as HTMLElement;
      const sc = t.closest('[data-scenario]') as HTMLElement | null;
      if (sc) this.game.autoPlaySystem.start(sc.dataset.scenario!);
      const sp = t.closest('[data-speed]') as HTMLElement | null;
      if (sp) this.game.setGameSpeed(Number(sp.dataset.speed));
      if (t.id === 'stop-ap') this.game.autoPlaySystem.stop();
    };
  }

  update(): void {
    const player = this.game.localPlayer;
    if (!player) return;
    const pos = this.game.world.getByName<PositionComponent>('position', player.entity)!;
    const inv = this.game.world.getByName<InventoryComponent>('inventory', player.entity)!;
    const net = this.game.powerSystem.networks[0];
    const iron = inventoryCount(inv, 'iron-ore') + inventoryCount(inv, 'iron-plate');
    const placing =
      this.input.buildMode === 'placing' && this.input.placeBuildingId
        ? ` · Place: ${this.input.placeBuildingId}`
        : this.input.buildMode === 'removing'
          ? ' · Remove mode'
          : '';
    this.statusEl.textContent = `Pos ${pos.tileX},${pos.tileY} · Time ${this.game.playTime.toFixed(0)}s · Speed ${this.game.gameSpeed}x · Power ${net ? `${(net.satisfaction * 100).toFixed(0)}%` : '—'} · Iron ${iron} · Entities ${this.game.world.entityCount}${placing}`;

    if (this.input.toggleInventory) this.toggle('inv');
    if (this.input.toggleCraft) this.toggle('craft');
    if (this.input.toggleBuild) this.toggle('build');
    if (this.input.toggleResearch) this.toggle('research');

    if (!this.panels.inv!.classList.contains('hidden')) this.renderInventory();
    if (!this.panels.machine!.classList.contains('hidden')) this.renderMachine();
  }

  openMachineIfSelected(): void {
    if (this.game.selectedEntities.length) {
      this.toggle('machine');
    }
  }
}

// silence unused import in case tree-shaking
void deleteSave;
