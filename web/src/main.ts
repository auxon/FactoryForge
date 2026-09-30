// Boot: game + view + UI, input wiring, fixed-step frame loop.
import { Game } from './sim/game';
import { View } from './render/view';
import { UI } from './ui/panels';
import { BUILDING_MAP } from './data/buildings';
import type { Dir } from './sim/world';
import './style.css';

const seed = (Math.random() * 0xffffffff) >>> 0;
const game = new Game(seed);
const container = document.getElementById('app')!;
const canvasHost = document.createElement('div');
canvasHost.id = 'scene';
container.appendChild(canvasHost);
const uiRoot = document.createElement('div');
uiRoot.id = 'ui';
container.appendChild(uiRoot);

const view = new View(canvasHost, game);
const ui = new UI(uiRoot, game, view);
// dev/debug hook (used by automated checks; harmless in prod)
(window as unknown as { __ff: unknown }).__ff = { game, view, ui };

// walk-up-to-use prompt
const prompt = document.createElement('div');
prompt.id = 'prompt';
prompt.style.display = 'none';
uiRoot.appendChild(prompt);

/** Nearest machine within use-range of the player. */
function nearMachine(): { id: number; name: string } | null {
  let best: { id: number; name: string; d: number } | null = null;
  for (const e of game.world.entities.values()) {
    const def = BUILDING_MAP.get(e.buildingId);
    if (!def || def.type === 'Belt' || def.type === 'Pipe' || def.type === 'Wall') continue;
    const cx = e.x + def.width / 2, cy = e.y + def.height / 2;
    const d = Math.hypot(game.player.x - cx, game.player.y - cy);
    if (d <= 2.5 + Math.max(def.width, def.height) / 2 && (!best || d < best.d)) {
      best = { id: e.id, name: def.name, d };
    }
  }
  return best;
}

function updatePrompt(): void {
  // auto-close machine UI when walking away
  if (ui.panel === 'machine' && view.selectedId != null) {
    const e = game.world.entities.get(view.selectedId);
    if (e) {
      const def = BUILDING_MAP.get(e.buildingId)!;
      const d = Math.hypot(game.player.x - (e.x + def.width / 2), game.player.y - (e.y + def.height / 2));
      if (d > 5 + Math.max(def.width, def.height)) {
        ui.panel = null; view.selectedId = null; ui.render();
      }
    }
  }
  const n = nearMachine();
  const using = ui.panel === 'machine' && view.selectedId != null;
  if (n && !using && !view.ghostId) {
    prompt.style.display = 'block';
    prompt.textContent = `[E] Use ${n.name} — walk inside a machine to operate it`;
    prompt.dataset.machineId = String(n.id);
  } else {
    prompt.style.display = 'none';
    delete prompt.dataset.machineId;
  }
}

game.say('Welcome to FactoryForge Web. Press ? for help.');

// ---- input ----
const keys = new Set<string>();
window.addEventListener('keydown', (e) => {
  const k = e.key.toLowerCase();
  if (k === 'escape') {
    if (view.ghostId) ui.placeMode(null);
    else { ui.panel = null; view.selectedId = null; ui.render(); }
    return;
  }
  if (k === 'r') {
    if (view.ghostId) {
      ui.ghostDir = ((ui.ghostDir + 1) % 4) as Dir;
      view.setGhost(view.ghostId, ui.ghostDir);
    } else if (view.selectedId != null) {
      const ent = game.world.entities.get(view.selectedId);
      if (ent) {
        ent.dir = ((ent.dir + 1) % 4) as Dir;
        // rebuild mesh with new direction (preserve all runtime state)
        game.world.remove(ent.id);
        const { buildingId, x, y, dir } = ent;
        const fresh = game.world.place(buildingId, x, y, dir);
        if (fresh) {
          fresh.inv = ent.inv; fresh.recipeId = ent.recipeId;
          fresh.progress = ent.progress; fresh.fuel = ent.fuel;
          fresh.left = ent.left; fresh.right = ent.right;
          fresh.held = ent.held; fresh.fluid = ent.fluid;
          view.selectedId = fresh.id;
          ui.render();
        }
      }
    }
    return;
  }
  if (k === 'b') { ui.toggle('build'); return; }
  if (k === 'c') { ui.toggle('craft'); return; }
  if (k === 'v') { ui.toggle('inv'); return; }
  if (k === 'g') { ui.toggle('research'); return; }
  if (k === 'e') {
    // walk-up-use: open the nearby machine (or close it if open)
    if (ui.panel === 'machine') { ui.panel = null; view.selectedId = null; ui.render(); return; }
    const n = nearMachine();
    if (n) {
      view.selectedId = n.id;
      view.followPlayer = true;
      ui.openMachine();
    }
    return;
  }
  if (k === ' ') { e.preventDefault(); game.playerAttack(); return; }
  keys.add(k);
});
window.addEventListener('keyup', (e) => keys.delete(e.key.toLowerCase()));

view.onTileClick = (x, y) => {
  if (view.ghostId) {
    const e = game.tryPlace(view.ghostId, x, y, ui.ghostDir);
    if (e) {
      view.selectedId = e.id;
      ui.refresh();
    }
    return;
  }
  const ent = game.world.entityAt(x, y);
  if (ent) {
    view.selectedId = ent.id;
    ui.openMachine();
    return;
  }
  // enemy adjacent? attack
  const purse = game.enemies.some((en) => Math.hypot(en.x - x, en.y - y) < 2);
  if (purse) { game.playerAttack(); return; }
  // hand-mine: teleport-free — mine if resource near player-adjacent tile clicked
  const px = Math.floor(game.player.x), py = Math.floor(game.player.y);
  if (Math.abs(x - px) <= 2 && Math.abs(y - py) <= 2) {
    const got = game.handMine();
    if (got) ui.refresh();
  }
};

// drag-paint belts: track mouse held with ghost belt selected
let painting = false;
canvasHost.addEventListener('pointerdown', (e) => {
  if (e.button === 0 && view.ghostId) {
    const def = BUILDING_MAP.get(view.ghostId);
    if (def && (def.type === 'Belt' || def.type === 'Pipe')) painting = true;
  }
});
window.addEventListener('pointerup', () => { painting = false; });
canvasHost.addEventListener('pointermove', () => {
  if (painting && view.ghostId && view.hoverTile) {
    const [x, y] = view.hoverTile;
    if (!game.world.entityAt(x, y)) game.tryPlace(view.ghostId, x, y, ui.ghostDir);
  }
});

// ---- main loop ----
let last = performance.now();
function loop(now: number): void {
  const dt = Math.min(0.25, (now - last) / 1000);
  last = now;
  // movement (variable dt like Swift player.update)
  let mx = 0, my = 0;
  if (keys.has('w') || keys.has('arrowup')) my -= 1;
  if (keys.has('s') || keys.has('arrowdown')) my += 1;
  if (keys.has('a') || keys.has('arrowleft')) mx -= 1;
  if (keys.has('d') || keys.has('arrowright')) mx += 1;
  if (mx !== 0 || my !== 0) {
    const l = Math.hypot(mx, my);
    game.movePlayer(mx / l, my / l, dt);
    view.followPlayer = true;
  }
  game.frame(dt);
  view.update(dt);
  updatePrompt();
  requestAnimationFrame(loop);
}
requestAnimationFrame(loop);
