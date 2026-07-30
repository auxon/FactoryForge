import { GameLoop } from './engine/core/GameLoop';
import { Camera2D } from './engine/render/Camera2D';
import { OrthoSpriteView } from './engine/render/OrthoSpriteView';
import { Perspective3DView } from './engine/render3d/Perspective3DView';
import { InputManager } from './engine/input/InputManager';
import { Hud } from './ui/Hud';
import { LoadingMenu, type MenuAction } from './ui/LoadingMenu';
import { NetClient } from './game/multiplayer/NetClient';
import { audio } from './engine/audio/AudioManager';
import type { PositionComponent } from './game/components';
import type { GameSave } from '@shared/save/types';

type AppPhase = 'menu' | 'playing';

async function main(): Promise<void> {
  const canvas = document.querySelector<HTMLCanvasElement>('#game-canvas')!;
  const uiRoot = document.querySelector<HTMLElement>('#ui-root')!;

  let phase: AppPhase = 'menu';
  let game: GameLoop | null = null;
  const camera = new Camera2D();
  const input = new InputManager();
  const detachInput = input.attach(canvas);

  const view2d = new OrthoSpriteView();
  const view3d = new Perspective3DView();
  const canvas3d = document.createElement('canvas');
  canvas3d.id = 'game-canvas-3d';
  canvas3d.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;display:none';
  canvas.parentElement!.appendChild(canvas3d);

  await view2d.init(canvas);
  await view3d.init(canvas3d);
  view2d.setEnabled(false);
  view3d.setEnabled(false);
  canvas.style.display = 'none';

  // Placeholder game for Hud construction; replaced on start
  game = new GameLoop();
  game.setGameSpeed(0);
  const hud = new Hud(uiRoot, game, input);
  hud.setInGame(false);
  const net = new NetClient();

  const resize = () => {
    const w = window.innerWidth;
    const h = window.innerHeight;
    canvas.width = w;
    canvas.height = h;
    canvas3d.width = w;
    canvas3d.height = h;
    view2d.resize(w, h);
    view3d.resize(w, h);
  };
  window.addEventListener('resize', resize);
  resize();

  let use3d = false;
  uiRoot.addEventListener('toggle-view', ((e: CustomEvent<boolean>) => {
    if (phase !== 'playing') return;
    use3d = e.detail;
    view2d.setEnabled(!use3d);
    view3d.setEnabled(use3d);
  }) as EventListener);

  uiRoot.addEventListener('mp-connect', ((e: CustomEvent<string>) => {
    net.connect(e.detail);
    net.onMessage = (msg) => {
      if (msg.type === 'handshake') {
        hud.showMessage('Multiplayer', `Connected as player ${msg.playerId}, seed ${msg.seed}`);
      }
    };
    setInterval(() => net.ping(), 2000);
  }) as EventListener);

  const startPlaying = (opts?: { save?: GameSave; pvai?: boolean; autoplay?: boolean }) => {
    loadingMenu.hide();
    // Fresh world unless loading
    if (opts?.save) {
      game = new GameLoop(opts.save.seed);
      hud.setGame(game);
      game.loadSave(opts.save);
    } else {
      game = new GameLoop();
      hud.setGame(game);
    }
    game.setGameSpeed(1);
    game.onVictory = (reason) => hud.showMessage('Victory', reason);
    game.onDeath = () => hud.showMessage('Game Over', 'You died. Open Menu → New Game to retry.');

    if (opts?.pvai) game.startPvAI();
    if (opts?.autoplay) {
      game.autoPlaySystem.start('basic_mining');
      game.setGameSpeed(2);
    }

    const player = game.localPlayer;
    if (player) {
      const pos = game.world.getByName<PositionComponent>('position', player.entity)!;
      camera.x = pos.tileX + pos.offsetX;
      camera.y = pos.tileY + pos.offsetY;
      camera.zoom = 1.15;
    }

    phase = 'playing';
    canvas.style.display = 'block';
    canvas.focus();
    view2d.setEnabled(!use3d);
    view3d.setEnabled(use3d);
    hud.setInGame(true);
  };

  const loadingMenu = new LoadingMenu(uiRoot, (action: MenuAction) => {
    if (action.type === 'new') startPlaying();
    if (action.type === 'load') startPlaying({ save: action.save });
    if (action.type === 'pvai') startPlaying({ pvai: true });
    if (action.type === 'pvp') {
      startPlaying();
      hud.toggle('lobby');
    }
    if (action.type === 'autoplay') startPlaying({ autoplay: true });
    if (action.type === 'help') {
      /* handled inside menu */
    }
  });

  let lastPanX = 0;
  let lastPanY = 0;

  const loop = () => {
    if (phase === 'playing' && game) {
      input.updateMovement();

      if (input.pausePressed) game.togglePause();
      if (input.rotatePressed) {
        if (input.buildMode === 'placing') {
          input.placeDirection = ((input.placeDirection + 1) % 4) as 0 | 1 | 2 | 3;
        } else game.rotateSelected();
      }
      if (input.deselectPressed) {
        game.selectedEntities = [];
        input.buildMode = 'none';
        input.placeBuildingId = null;
        hud.hideAll();
      }
      if (input.toggleView3D) {
        use3d = !use3d;
        hud.view3d = use3d;
        view2d.setEnabled(!use3d);
        view3d.setEnabled(use3d);
      }
      if (input.wheelDelta) camera.zoomBy(input.wheelDelta);
      if (input.middleDown || input.rightDown) {
        const dx = input.mouseX - lastPanX;
        const dy = input.mouseY - lastPanY;
        if (lastPanX || lastPanY) camera.pan(dx, dy);
      }
      lastPanX = input.mouseX;
      lastPanY = input.mouseY;

      const world = camera.screenToWorld(input.mouseX, input.mouseY, window.innerWidth, window.innerHeight);
      input.worldX = world.x;
      input.worldY = world.y;

      if (input.justClicked) {
        if (input.buildMode === 'placing' && input.placeBuildingId) {
          const tx = Math.floor(world.x);
          const ty = Math.floor(world.y);
          const ok = game.placeBuilding(input.placeBuildingId, tx, ty, input.placeDirection);
          if (ok) {
            audio.place();
            if (net.connected) {
              net.sendCommand({
                type: 'build',
                buildingId: input.placeBuildingId,
                position: { x: tx, y: ty },
                direction: input.placeDirection,
              });
            }
          }
        } else if (input.buildMode === 'removing') {
          game.removeBuildingAt(Math.floor(world.x), Math.floor(world.y));
        } else {
          game.selectAt(world.x, world.y);
          const e = game.world.entityAt(Math.floor(world.x), Math.floor(world.y));
          if (e && (game.world.hasByName('inventory', e) || game.world.hasByName('assembler', e))) {
            hud.openMachineIfSelected();
          } else if (!e) {
            game.tryMineOrInteract(world.x, world.y);
            audio.mine();
            game.commandSelectedUnits('move', world.x, world.y);
          } else if (game.world.hasByName('enemy', e)) {
            game.commandSelectedUnits('attack', world.x, world.y, e.id);
          }
        }
      }
      if (input.justDoubleClicked || input.attackPressed) {
        const player = game.localPlayer;
        if (player) {
          game.combatSystem.playerShoot(player.entity, world.x, world.y, game.localPlayerId);
          audio.shoot();
        }
      }
      if (input.justRightClicked) {
        input.buildMode = 'none';
        input.placeBuildingId = null;
      }
      if (input.stopUnitsPressed) game.commandSelectedUnits('stop');

      game.frame(input.moveX, input.moveY);

      const player = game.localPlayer;
      if (player) {
        const pos = game.world.getByName<PositionComponent>('position', player.entity)!;
        camera.setFollow(
          pos.tileX + pos.offsetX,
          pos.tileY + pos.offsetY,
          1 / 60,
          !input.middleDown && !input.rightDown,
        );
      }

      if (use3d) view3d.render(game.world, game.chunkManager, camera, 1 / 60);
      else view2d.render(game.world, game.chunkManager, camera, 1 / 60);

      hud.update();
      input.consumeFrameFlags();
    } else {
      // Keep splash/menu responsive; clear input edge flags
      input.consumeFrameFlags();
    }
    requestAnimationFrame(loop);
  };

  void import('./game/data/SaveStore').then(({ writeSave }) => {
    setInterval(() => {
      if (phase === 'playing' && game) writeSave('autosave', game.serializeSave());
    }, 300_000);
  });

  requestAnimationFrame(loop);

  window.addEventListener('beforeunload', () => {
    detachInput();
    view2d.dispose();
    view3d.dispose();
  });
}

main().catch((err) => {
  console.error(err);
  document.body.innerHTML = `<pre style="color:#fff;padding:24px">Failed to start FactoryForge:\n${err}</pre>`;
});
