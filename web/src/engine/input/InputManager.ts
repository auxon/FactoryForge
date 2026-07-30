import type { Direction } from '../../game/components';

export type BuildMode = 'none' | 'placing' | 'removing' | 'selecting' | 'moving' | 'connectingInserter';

/** Physical key codes (layout-independent). */
const MOVE_CODES = new Set([
  'KeyW',
  'KeyA',
  'KeyS',
  'KeyD',
  'ArrowUp',
  'ArrowDown',
  'ArrowLeft',
  'ArrowRight',
]);

export class InputManager {
  keys = new Set<string>();
  moveX = 0;
  moveY = 0;
  mouseX = 0;
  mouseY = 0;
  worldX = 0;
  worldY = 0;
  leftDown = false;
  rightDown = false;
  middleDown = false;
  justClicked = false;
  justRightClicked = false;
  justDoubleClicked = false;
  wheelDelta = 0;
  buildMode: BuildMode = 'none';
  placeBuildingId: string | null = null;
  placeDirection: Direction = 0;
  cameraPanActive = false;
  boxSelecting = false;
  boxStartX = 0;
  boxStartY = 0;
  pausePressed = false;
  rotatePressed = false;
  deselectPressed = false;
  toggleInventory = false;
  toggleCraft = false;
  toggleBuild = false;
  toggleResearch = false;
  toggleView3D = false;
  attackPressed = false;
  stopUnitsPressed = false;
  private lastClickTime = 0;
  private canvas: HTMLElement | null = null;

  private trackKey(e: KeyboardEvent, down: boolean): void {
    const code = e.code;
    const key = e.key.length === 1 ? e.key.toLowerCase() : e.key.toLowerCase();
    if (down) {
      this.keys.add(code);
      this.keys.add(key);
    } else {
      this.keys.delete(code);
      this.keys.delete(key);
    }
  }

  private pressed(...ids: string[]): boolean {
    return ids.some((id) => this.keys.has(id));
  }

  attach(canvas: HTMLElement): () => void {
    this.canvas = canvas;
    canvas.setAttribute('tabindex', '0');
    canvas.style.outline = 'none';

    const onKeyDown = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement)?.tagName;
      if (tag === 'INPUT' || tag === 'TEXTAREA') return;

      this.trackKey(e, true);
      if (MOVE_CODES.has(e.code) || e.code === 'Space') e.preventDefault();

      if (e.code === 'Space' || e.code === 'KeyP') this.pausePressed = true;
      if (e.code === 'KeyR') this.rotatePressed = true;
      if (e.code === 'Escape') this.deselectPressed = true;
      if (e.code === 'KeyI') this.toggleInventory = true;
      if (e.code === 'KeyC') this.toggleCraft = true;
      if (e.code === 'KeyB') this.toggleBuild = true;
      if (e.code === 'KeyT') this.toggleResearch = true;
      if (e.code === 'KeyV') this.toggleView3D = true;
      if (e.code === 'KeyF') this.attackPressed = true;
      if (e.code === 'KeyH') this.stopUnitsPressed = true;
      if (e.code === 'KeyQ') this.placeDirection = ((this.placeDirection + 3) % 4) as Direction;
      if (e.code === 'KeyE') this.placeDirection = ((this.placeDirection + 1) % 4) as Direction;
    };
    const onKeyUp = (e: KeyboardEvent) => {
      this.trackKey(e, false);
    };
    const onBlur = () => {
      this.keys.clear();
      this.moveX = 0;
      this.moveY = 0;
    };
    const onMouseMove = (e: MouseEvent) => {
      const rect = canvas.getBoundingClientRect();
      this.mouseX = e.clientX - rect.left;
      this.mouseY = e.clientY - rect.top;
      if (this.middleDown || (this.rightDown && this.buildMode === 'none')) {
        this.cameraPanActive = true;
      }
    };
    const onMouseDown = (e: MouseEvent) => {
      canvas.focus();
      if (e.button === 0) {
        this.leftDown = true;
        const now = performance.now();
        if (now - this.lastClickTime < 300) this.justDoubleClicked = true;
        else this.justClicked = true;
        this.lastClickTime = now;
        if (!this.pressed('Space', ' ')) {
          this.boxSelecting = true;
          this.boxStartX = this.mouseX;
          this.boxStartY = this.mouseY;
        }
      }
      if (e.button === 1) this.middleDown = true;
      if (e.button === 2) {
        this.rightDown = true;
        this.justRightClicked = true;
      }
    };
    const onMouseUp = (e: MouseEvent) => {
      if (e.button === 0) {
        this.leftDown = false;
        this.boxSelecting = false;
      }
      if (e.button === 1) this.middleDown = false;
      if (e.button === 2) this.rightDown = false;
    };
    const onWheel = (e: WheelEvent) => {
      e.preventDefault();
      this.wheelDelta += e.deltaY;
    };
    const onContext = (e: Event) => e.preventDefault();

    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);
    window.addEventListener('blur', onBlur);
    canvas.addEventListener('mousemove', onMouseMove);
    canvas.addEventListener('mousedown', onMouseDown);
    window.addEventListener('mouseup', onMouseUp);
    canvas.addEventListener('wheel', onWheel, { passive: false });
    canvas.addEventListener('contextmenu', onContext);

    return () => {
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('keyup', onKeyUp);
      window.removeEventListener('blur', onBlur);
      canvas.removeEventListener('mousemove', onMouseMove);
      canvas.removeEventListener('mousedown', onMouseDown);
      window.removeEventListener('mouseup', onMouseUp);
      canvas.removeEventListener('wheel', onWheel);
      canvas.removeEventListener('contextmenu', onContext);
    };
  }

  focusGame(): void {
    this.canvas?.focus();
  }

  updateMovement(): void {
    let x = 0;
    let y = 0;
    // Screen-up = decreasing world Y with our ortho + camera-follow feel (matches prior working mapping).
    if (this.pressed('KeyW', 'w', 'ArrowUp', 'arrowup')) y -= 1;
    if (this.pressed('KeyS', 's', 'ArrowDown', 'arrowdown')) y += 1;
    if (this.pressed('KeyA', 'a', 'ArrowLeft', 'arrowleft')) x -= 1;
    if (this.pressed('KeyD', 'd', 'ArrowRight', 'arrowright')) x += 1;
    const len = Math.hypot(x, y) || 1;
    this.moveX = x / len;
    this.moveY = y / len;
  }

  consumeFrameFlags(): void {
    this.justClicked = false;
    this.justRightClicked = false;
    this.justDoubleClicked = false;
    this.wheelDelta = 0;
    this.pausePressed = false;
    this.rotatePressed = false;
    this.deselectPressed = false;
    this.toggleInventory = false;
    this.toggleCraft = false;
    this.toggleBuild = false;
    this.toggleResearch = false;
    this.toggleView3D = false;
    this.attackPressed = false;
    this.stopUnitsPressed = false;
    this.cameraPanActive = false;
  }
}
