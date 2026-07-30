import * as THREE from 'three';

/** Canvas-generated pixel textures so the world reads as a factory game, not flat color blocks. */
export class ProceduralAtlas {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private map = new Map<string, THREE.CanvasTexture>();
  private cell = 32;

  constructor() {
    const size = 512;
    this.canvas = document.createElement('canvas');
    this.canvas.width = size;
    this.canvas.height = size;
    this.ctx = this.canvas.getContext('2d')!;
    this.ctx.imageSmoothingEnabled = false;
  }

  get(id: string): THREE.CanvasTexture {
    let tex = this.map.get(id);
    if (tex) return tex;
    tex = this.bake(id);
    this.map.set(id, tex);
    return tex;
  }

  private bake(id: string): THREE.CanvasTexture {
    const c = document.createElement('canvas');
    c.width = this.cell;
    c.height = this.cell;
    const g = c.getContext('2d')!;
    g.imageSmoothingEnabled = false;
    drawSprite(g, id, this.cell);
    const tex = new THREE.CanvasTexture(c);
    tex.magFilter = THREE.NearestFilter;
    tex.minFilter = THREE.NearestFilter;
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.needsUpdate = true;
    return tex;
  }
}

function noise(g: CanvasRenderingContext2D, n: number, color: string, size: number): void {
  g.fillStyle = color;
  for (let i = 0; i < n; i++) {
    const x = Math.floor(Math.random() * size);
    const y = Math.floor(Math.random() * size);
    g.fillRect(x, y, 1 + (Math.random() > 0.7 ? 1 : 0), 1);
  }
}

function drawSprite(g: CanvasRenderingContext2D, id: string, s: number): void {
  // deterministic-ish seed from id
  let h = 0;
  for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) | 0;
  const rnd = () => {
    h = (h * 1664525 + 1013904223) | 0;
    return (h >>> 0) / 4294967296;
  };

  const fill = (color: string) => {
    g.fillStyle = color;
    g.fillRect(0, 0, s, s);
  };

  if (id === 'grass') {
    fill('#3a6b34');
    noise(g, 40, '#4c8a42', s);
    noise(g, 20, '#2d5528', s);
    // subtle tile edge
    g.strokeStyle = '#2a4f26';
    g.strokeRect(0.5, 0.5, s - 1, s - 1);
    return;
  }
  if (id === 'dirt') {
    fill('#6b5428');
    noise(g, 35, '#7d6432', s);
    noise(g, 20, '#55401c', s);
    g.strokeStyle = '#443318';
    g.strokeRect(0.5, 0.5, s - 1, s - 1);
    return;
  }
  if (id === 'sand') {
    fill('#c2b280');
    noise(g, 30, '#d4c496', s);
    noise(g, 15, '#a89868', s);
    return;
  }
  if (id === 'water') {
    fill('#1e5a8a');
    noise(g, 25, '#2a6fa3', s);
    noise(g, 15, '#154a72', s);
    g.fillStyle = '#3a8bc4';
    for (let i = 0; i < 4; i++) g.fillRect(4 + i * 6, 10 + ((i * 3) % 8), 5, 2);
    return;
  }
  if (id === 'stone') {
    fill('#6e6e6e');
    noise(g, 40, '#808080', s);
    noise(g, 25, '#555', s);
    return;
  }
  if (id.includes('ore') || id === 'coal' || id === 'crude-oil') {
    const base =
      id === 'iron-ore'
        ? '#5c4033'
        : id === 'copper-ore'
          ? '#8b4513'
          : id === 'coal'
            ? '#1a1a1a'
            : id === 'uranium-ore'
              ? '#3d5c1a'
              : '#2a1840';
    const spark =
      id === 'iron-ore'
        ? '#a08070'
        : id === 'copper-ore'
          ? '#e07030'
          : id === 'coal'
            ? '#444'
            : id === 'uranium-ore'
              ? '#b8ff40'
              : '#6a40a0';
    fill(base);
    g.fillStyle = spark;
    for (let i = 0; i < 18; i++) {
      g.fillRect(Math.floor(rnd() * (s - 2)), Math.floor(rnd() * (s - 2)), 2, 2);
    }
    return;
  }
  if (id === 'player') {
    fill('#1a1a1a00');
    g.clearRect(0, 0, s, s);
    g.fillStyle = '#4fc3f7';
    g.fillRect(10, 6, 12, 20);
    g.fillStyle = '#fff';
    g.fillRect(12, 8, 8, 6);
    g.fillStyle = '#0288d1';
    g.fillRect(8, 24, 6, 6);
    g.fillRect(18, 24, 6, 6);
    return;
  }
  if (id === 'tree') {
    g.clearRect(0, 0, s, s);
    g.fillStyle = '#5d4037';
    g.fillRect(14, 18, 4, 12);
    g.fillStyle = '#2e7d32';
    g.beginPath();
    g.arc(16, 14, 10, 0, Math.PI * 2);
    g.fill();
    g.fillStyle = '#43a047';
    g.beginPath();
    g.arc(12, 12, 5, 0, Math.PI * 2);
    g.fill();
    return;
  }
  if (id === 'biter' || id === 'enemy') {
    g.clearRect(0, 0, s, s);
    g.fillStyle = '#c62828';
    g.fillRect(6, 10, 20, 14);
    g.fillStyle = '#ff8a80';
    g.fillRect(10, 12, 4, 4);
    g.fillRect(18, 12, 4, 4);
    g.fillStyle = '#8b0000';
    g.fillRect(4, 22, 6, 4);
    g.fillRect(22, 22, 6, 4);
    return;
  }
  if (id.includes('belt')) {
    const col = id.includes('express') ? '#42a5f5' : id.includes('fast') ? '#ef5350' : '#fdd835';
    fill('#3e2723');
    g.fillStyle = col;
    g.fillRect(2, 10, 28, 12);
    g.fillStyle = '#fff8';
    for (let i = 0; i < 4; i++) g.fillRect(4 + i * 7, 12, 3, 8);
    return;
  }
  if (id.includes('inserter')) {
    g.clearRect(0, 0, s, s);
    g.fillStyle = '#424242';
    g.fillRect(12, 12, 8, 8);
    g.fillStyle = '#66bb6a';
    g.fillRect(14, 4, 4, 12);
    g.fillRect(10, 4, 12, 4);
    return;
  }
  if (id.includes('furnace')) {
    fill('#5d4037');
    g.fillStyle = '#3e2723';
    g.fillRect(6, 8, 20, 18);
    g.fillStyle = '#ff5722';
    g.fillRect(12, 14, 8, 8);
    g.fillStyle = '#9e9e9e';
    g.fillRect(10, 4, 12, 4);
    return;
  }
  if (id.includes('drill') || id.includes('miner')) {
    fill('#455a64');
    g.fillStyle = '#78909c';
    g.fillRect(4, 4, 24, 24);
    g.fillStyle = '#ffc107';
    g.beginPath();
    g.arc(16, 16, 6, 0, Math.PI * 2);
    g.fill();
    return;
  }
  if (id.includes('assembl')) {
    fill('#ef6c00');
    g.fillStyle = '#ffe0b2';
    g.fillRect(6, 6, 20, 20);
    g.fillStyle = '#e65100';
    g.fillRect(10, 10, 12, 12);
    return;
  }
  if (id.includes('pole')) {
    g.clearRect(0, 0, s, s);
    g.fillStyle = '#bdbdbd';
    g.fillRect(14, 4, 4, 24);
    g.fillStyle = '#ffeb3b';
    g.fillRect(8, 6, 16, 3);
    return;
  }
  if (id === 'boiler' || id === 'steam-engine') {
    fill('#546e7a');
    g.fillStyle = '#90a4ae';
    g.fillRect(4, 8, 24, 16);
    g.fillStyle = '#eceff1';
    g.fillRect(8, 4, 6, 8);
    return;
  }
  if (id === 'pipe' || id.includes('pipe') || id === 'fluid-tank') {
    fill('#607d8b');
    g.fillStyle = '#90a4ae';
    g.fillRect(0, 12, 32, 8);
    g.fillRect(12, 0, 8, 32);
    return;
  }
  if (id.includes('chest')) {
    fill('#6d4c41');
    g.fillStyle = '#a1887f';
    g.fillRect(6, 8, 20, 16);
    g.fillStyle = '#ffc107';
    g.fillRect(14, 14, 4, 4);
    return;
  }
  if (id === 'lab') {
    fill('#6a1b9a');
    g.fillStyle = '#ce93d8';
    g.fillRect(6, 6, 20, 20);
    g.fillStyle = '#ea80fc';
    g.fillRect(12, 10, 8, 12);
    return;
  }
  if (id.includes('turret') || id === 'stone-wall' || id === 'wall') {
    fill('#5d4037');
    g.fillStyle = '#8d6e63';
    g.fillRect(4, 4, 24, 24);
    if (id.includes('turret')) {
      g.fillStyle = '#c62828';
      g.fillRect(12, 8, 8, 16);
    }
    return;
  }
  if (id === 'rocket-silo') {
    fill('#37474f');
    g.fillStyle = '#90a4ae';
    g.fillRect(4, 4, 24, 24);
    g.fillStyle = '#fff';
    g.beginPath();
    g.moveTo(16, 6);
    g.lineTo(22, 26);
    g.lineTo(10, 26);
    g.fill();
    return;
  }
  if (id === 'unit') {
    g.clearRect(0, 0, s, s);
    g.fillStyle = '#1565c0';
    g.fillRect(8, 8, 16, 16);
    return;
  }

  // default building
  fill('#757575');
  g.fillStyle = '#9e9e9e';
  g.fillRect(4, 4, 24, 24);
  g.fillStyle = '#bdbdbd';
  g.fillRect(8, 8, 16, 16);
  void rnd;
}
