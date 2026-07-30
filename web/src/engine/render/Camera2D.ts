export class Camera2D {
  x = 0;
  y = 0;
  zoom = 1.15;
  minZoom = 0.2;
  maxZoom = 10;
  pixelsPerTile = 32;
  followLerp = 8;

  setFollow(targetX: number, targetY: number, dt: number, enabled: boolean): void {
    if (!enabled) return;
    const t = 1 - Math.exp(-this.followLerp * dt);
    this.x += (targetX - this.x) * t;
    this.y += (targetY - this.y) * t;
  }

  zoomBy(delta: number): void {
    this.zoom = Math.min(this.maxZoom, Math.max(this.minZoom, this.zoom * (1 - delta * 0.001)));
  }

  pan(dx: number, dy: number): void {
    const scale = 1 / (this.zoom * this.pixelsPerTile);
    this.x -= dx * scale * this.pixelsPerTile;
    this.y += dy * scale * this.pixelsPerTile;
  }

  screenToWorld(sx: number, sy: number, viewW: number, viewH: number): { x: number; y: number } {
    const halfW = viewW / (2 * this.zoom * this.pixelsPerTile);
    const halfH = viewH / (2 * this.zoom * this.pixelsPerTile);
    const ndcX = sx / viewW - 0.5;
    const ndcY = 0.5 - sy / viewH;
    return {
      x: this.x + ndcX * 2 * halfW,
      y: this.y + ndcY * 2 * halfH,
    };
  }
}
