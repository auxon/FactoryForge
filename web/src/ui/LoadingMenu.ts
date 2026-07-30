import { listSaves, readSave, deleteSave } from '../game/data/SaveStore';
import type { GameSave } from '@shared/save/types';
import { audio } from '../engine/audio/AudioManager';
import { assets } from '../engine/render/AssetCatalog';

export type MenuAction =
  | { type: 'new' }
  | { type: 'load'; save: GameSave; slot: string }
  | { type: 'pvai' }
  | { type: 'pvp' }
  | { type: 'autoplay' }
  | { type: 'help' };

/** Splash → loading menu matching iOS LoadingMenu flow. */
export class LoadingMenu {
  root: HTMLElement;
  private selectedSlot: string | null = null;
  private onAction: (action: MenuAction) => void;
  private assetsReady = false;

  constructor(parent: HTMLElement, onAction: (action: MenuAction) => void) {
    this.onAction = onAction;
    this.root = document.createElement('div');
    this.root.id = 'loading-menu';
    this.root.className = 'loading-menu';
    parent.appendChild(this.root);
    void this.showSplashAndPreload();
  }

  private async showSplashAndPreload(): Promise<void> {
    this.root.innerHTML = `
      <div class="splash">
        <img class="splash-img" src="/assets/splash.png" alt="FactoryForge" />
        <div class="splash-overlay">
          <div class="splash-title">FactoryForge</div>
          <div class="splash-sub">Loading assets…</div>
          <div class="splash-bar"><span id="splash-fill"></span></div>
          <div class="splash-pct" id="splash-pct">0%</div>
        </div>
      </div>
    `;
    const fill = this.root.querySelector('#splash-fill') as HTMLElement;
    const pct = this.root.querySelector('#splash-pct') as HTMLElement;

    const start = performance.now();
    await assets.preload((loaded, total) => {
      const p = Math.round((loaded / total) * 100);
      fill.style.width = `${p}%`;
      fill.style.transform = 'none';
      fill.style.animation = 'none';
      pct.textContent = `${p}%`;
    });
    this.assetsReady = true;

    // Keep splash visible at least ~1.5s for brand moment
    const elapsed = performance.now() - start;
    const wait = Math.max(0, 1500 - elapsed);
    window.setTimeout(() => this.showMenu(), wait);
  }

  showMenu(): void {
    audio.ui();
    const saves = listSaves();
    this.root.innerHTML = `
      <div class="menu-screen">
        <div class="menu-bg"></div>
        <img class="menu-splash-bg" src="/assets/splash.png" alt="" />
        <div class="menu-card">
          <div class="menu-header">
            <img src="/assets/new_game.png" alt="" class="menu-icon" />
            <div>
              <h1 class="menu-brand">FactoryForge</h1>
              <p class="menu-tagline">Build factories. Launch rockets. Win.</p>
            </div>
          </div>

          <div class="menu-saves" id="save-list">
            ${
              saves.length
                ? saves
                    .map(
                      (s) =>
                        `<button type="button" class="save-slot" data-slot="${s}">${s}</button>`,
                    )
                    .join('')
                : `<p class="menu-empty">No saved games yet</p>`
            }
          </div>

          <div class="menu-actions">
            <button type="button" class="menu-btn primary" data-act="new">
              <img src="/assets/new_game.png" alt="" /> New Game
            </button>
            <button type="button" class="menu-btn" data-act="load" ${saves.length ? '' : 'disabled'}>
              <img src="/assets/load_game.png" alt="" /> Load
            </button>
            <button type="button" class="menu-btn" data-act="delete" ${saves.length ? '' : 'disabled'}>
              <img src="/assets/delete_game.png" alt="" /> Delete
            </button>
          </div>

          <div class="menu-modes">
            <button type="button" class="menu-btn" data-act="pvai">Play vs AI</button>
            <button type="button" class="menu-btn" data-act="pvp">Multiplayer Lobby</button>
            <button type="button" class="menu-btn" data-act="autoplay">
              <img src="/assets/menu.png" alt="" /> AutoPlay
            </button>
            <button type="button" class="menu-btn" data-act="help">
              <img src="/assets/help.png" alt="" /> Help
            </button>
          </div>

          <div id="menu-help" class="menu-help hidden">
            <h3>How to play</h3>
            <ul>
              <li><b>WASD</b> move · <b>Wheel</b> zoom · <b>RMB/MMB</b> pan</li>
              <li><b>B</b> build · <b>I</b> inventory · <b>C</b> craft · <b>T</b> research</li>
              <li>Mine ore, smelt plates, automate with belts &amp; inserters</li>
              <li>Power machines with boilers + steam engines</li>
              <li>Research tech, defend biters, launch a rocket with a satellite to win</li>
            </ul>
            <button type="button" class="menu-btn" data-act="close-help">Close</button>
          </div>
        </div>
      </div>
    `;

    this.root.querySelector('#save-list')?.addEventListener('click', (e) => {
      const btn = (e.target as HTMLElement).closest('.save-slot') as HTMLElement | null;
      if (!btn) return;
      this.root.querySelectorAll('.save-slot').forEach((el) => el.classList.remove('selected'));
      btn.classList.add('selected');
      this.selectedSlot = btn.dataset.slot ?? null;
      audio.ui();
    });

    this.root.addEventListener('click', (e) => {
      const btn = (e.target as HTMLElement).closest('[data-act]') as HTMLElement | null;
      if (!btn) return;
      if (!this.assetsReady) return;
      const act = btn.dataset.act;
      audio.ui();
      if (act === 'new') this.onAction({ type: 'new' });
      if (act === 'load' && this.selectedSlot) {
        const save = readSave(this.selectedSlot);
        if (save) this.onAction({ type: 'load', save, slot: this.selectedSlot });
      }
      if (act === 'delete' && this.selectedSlot) {
        deleteSave(this.selectedSlot);
        this.showMenu();
      }
      if (act === 'pvai') this.onAction({ type: 'pvai' });
      if (act === 'pvp') this.onAction({ type: 'pvp' });
      if (act === 'autoplay') this.onAction({ type: 'autoplay' });
      if (act === 'help') this.root.querySelector('#menu-help')?.classList.remove('hidden');
      if (act === 'close-help') this.root.querySelector('#menu-help')?.classList.add('hidden');
    });
  }

  hide(): void {
    this.root.classList.add('hidden');
  }

  show(): void {
    this.root.classList.remove('hidden');
    this.showMenu();
  }

  destroy(): void {
    this.root.remove();
  }
}
