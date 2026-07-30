import * as THREE from 'three';
import { ProceduralAtlas } from './ProceduralAtlas';

/** 1024×1024 sheets sliced into 4×4 frames of 256×256 (matches iOS TextureAtlas). */
const SHEET_4X4 = new Set([
  'player_down',
  'player_left',
  'player_right',
  'player_up',
  'biter',
  'biter_left',
  'biter_right',
  'inserters_sheet',
  'transport_belt_animation',
]);

/** Skip border crop (full-bleed UI / splash / already-cropped frames). */
const NO_BORDER_CROP = new Set([
  'splash',
  'solid_white',
  'new_game',
  'save_game',
  'load_game',
  'delete_game',
  'build',
  'menu',
  'help',
  'research',
  'inventory',
  'gear',
  'rotate',
  'move',
  'buy',
  'recycle',
  'trash',
  'cancel_button',
  'clear',
  'disable_audio',
  'right_arrow',
]);

/** Same as iOS TextureAtlas: crop 20% from each side to remove transparent padding. */
const BORDER_CROP = 0.2;

/** Maps game texture IDs to `/assets/*.png`, with sprite-sheet frame extraction. */
export class AssetCatalog {
  private loader = new THREE.TextureLoader();
  private textures = new Map<string, THREE.Texture>();
  private loading = new Map<string, Promise<THREE.Texture>>();
  private fallback = new ProceduralAtlas();
  private available = new Set<string>();
  ready = false;

  private static readonly ALIASES: Record<string, string> = {
    player: 'player_down_0',
    wall: 'stone_wall',
    enemy: 'biter_0',
    unit: 'player_right_0',
    default: 'building_placeholder',
    'water-pump': 'water_pump',
    'offshore-pump': 'offshore_pump',
    'fluid-tank': 'fluid_tank',
    'underground-pipe': 'underground_pipe',
    'nuclear-reactor': 'nuclear_reactor',
    'rocket-silo': 'rocket_silo',
    'rocket-parts': 'rocket_parts',
    'rocket-fuel': 'rocket_fuel',
    'space-science-pack': 'space_science_pack',
    'low-density-structure': 'low_density_structure',
    'solid-fuel': 'solid_fuel',
    'plastic-bar': 'plastic_bar',
    'heavy-oil': 'heavy_oil',
    'light-oil': 'light_oil',
    'petroleum-gas': 'petroleum_gas',
    'sulfuric-acid': 'sulfuric_acid',
    'uranium-235': 'uranium_235',
    'uranium-238': 'uranium_238',
    'nuclear-fuel': 'nuclear_fuel',
  };

  filenameFor(id: string): string {
    if (AssetCatalog.ALIASES[id]) return AssetCatalog.ALIASES[id]!;
    return id.replace(/-/g, '_');
  }

  urlFor(id: string): string {
    const file = this.filenameFor(id);
    const sheet = file.replace(/_\d+$/, '');
    if (SHEET_4X4.has(sheet) && /_\d+$/.test(file)) {
      return `/assets/${sheet}.png`;
    }
    return `/assets/${file}.png`;
  }

  iconUrl(id: string): string {
    return this.urlFor(id);
  }

  async preload(onProgress?: (loaded: number, total: number) => void): Promise<void> {
    let files: string[] = [];
    try {
      const res = await fetch('/assets/manifest.json');
      files = (await res.json()) as string[];
      files = files.filter(
        (f) => !f.startsWith('AppIcon') && !f.includes(' copy') && !f.includes('copper_ore '),
      );
    } catch {
      files = ['grass', 'dirt', 'water', 'sand', 'stone', 'tree', 'player_down', 'transport_belt', 'splash'];
    }

    let loaded = 0;
    const total = files.length;
    await Promise.all(
      files.map(async (name) => {
        try {
          const raw = await this.loadFile(name);
          if (SHEET_4X4.has(name)) {
            this.textures.set(name, raw);
            this.available.add(name);
            await this.sliceSheet4x4(name, raw);
          } else {
            const processed = this.cropBorderAndNormalize(name, raw);
            this.textures.set(name, processed);
            this.available.add(name);
            if (processed !== raw) raw.dispose();
          }
        } catch {
          /* missing */
        }
        loaded++;
        onProgress?.(loaded, total);
      }),
    );
    this.ready = true;
  }

  /**
   * Match iOS packSpriteIntoAtlas border crop: remove ~20% padding from each side
   * so tiles abut without black/transparent gutters.
   */
  private cropBorderAndNormalize(name: string, tex: THREE.Texture): THREE.Texture {
    if (NO_BORDER_CROP.has(name)) return this.configureTex(tex);

    const img = tex.image as HTMLImageElement | ImageBitmap | HTMLCanvasElement;
    const w = 'naturalWidth' in img && img.naturalWidth ? img.naturalWidth : (img as HTMLImageElement).width;
    const h = 'naturalHeight' in img && img.naturalHeight ? img.naturalHeight : (img as HTMLImageElement).height;
    if (!w || !h || w < 48 || h < 48) return this.configureTex(tex);

    const sx = Math.floor(w * BORDER_CROP);
    const sy = Math.floor(h * BORDER_CROP);
    const sw = Math.max(1, w - sx * 2);
    const sh = Math.max(1, h - sy * 2);

    const outSize = 64;
    const canvas = document.createElement('canvas');
    canvas.width = outSize;
    canvas.height = outSize;
    const ctx = canvas.getContext('2d', { alpha: true })!;
    ctx.imageSmoothingEnabled = false;
    ctx.clearRect(0, 0, outSize, outSize);
    // Terrain only: opaque underfill so leftover alpha can't open tile seams.
    // Buildings/entities keep true transparency.
    const terrainFill: Record<string, string> = {
      grass: '#3a6b34',
      dirt: '#6b5428',
      sand: '#c2b280',
      water: '#1e5a8a',
      stone: '#6e6e6e',
    };
    const fill = terrainFill[name];
    if (fill) {
      ctx.fillStyle = fill;
      ctx.fillRect(0, 0, outSize, outSize);
    }
    ctx.drawImage(img as CanvasImageSource, sx, sy, sw, sh, 0, 0, outSize, outSize);

    const out = new THREE.CanvasTexture(canvas);
    return this.configureTex(out);
  }

  private configureTex(tex: THREE.Texture): THREE.Texture {
    tex.magFilter = THREE.NearestFilter;
    tex.minFilter = THREE.NearestFilter;
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.wrapS = THREE.ClampToEdgeWrapping;
    tex.wrapT = THREE.ClampToEdgeWrapping;
    tex.generateMipmaps = false;
    tex.anisotropy = 1;
    tex.needsUpdate = true;
    return tex;
  }

  /** Extract 16 frames from a 1024×1024 sheet into `name_0` … `name_15`. */
  private async sliceSheet4x4(name: string, sheetTex: THREE.Texture): Promise<void> {
    const img = sheetTex.image as HTMLImageElement | ImageBitmap;
    const w = 'width' in img ? img.width : 0;
    const h = 'height' in img ? img.height : 0;
    if (w !== 1024 || h !== 1024) {
      this.textures.set(`${name}_0`, this.configureTex(sheetTex));
      this.available.add(`${name}_0`);
      return;
    }

    const frameSize = 256;
    const cols = 4;
    for (let frameIndex = 0; frameIndex < 16; frameIndex++) {
      const row = Math.floor(frameIndex / cols);
      const col = frameIndex % cols;
      const canvas = document.createElement('canvas');
      canvas.width = frameSize;
      canvas.height = frameSize;
      const ctx = canvas.getContext('2d')!;
      ctx.imageSmoothingEnabled = false;
      ctx.clearRect(0, 0, frameSize, frameSize);
      ctx.drawImage(
        img as CanvasImageSource,
        col * frameSize,
        row * frameSize,
        frameSize,
        frameSize,
        0,
        0,
        frameSize,
        frameSize,
      );
      const frameTex = new THREE.CanvasTexture(canvas);
      const frameName = `${name}_${frameIndex}`;
      this.textures.set(frameName, this.configureTex(frameTex));
      this.available.add(frameName);
    }
  }

  private loadFile(filename: string): Promise<THREE.Texture> {
    const existing = this.loading.get(filename);
    if (existing) return existing;
    const p = new Promise<THREE.Texture>((resolve, reject) => {
      this.loader.load(
        `/assets/${filename}.png`,
        (tex) => resolve(tex),
        undefined,
        () => reject(new Error(`Failed ${filename}`)),
      );
    });
    this.loading.set(filename, p);
    return p;
  }

  get(id: string): THREE.Texture {
    const file = this.filenameFor(id);
    const tex = this.textures.get(file);
    if (tex) return tex;
    if (SHEET_4X4.has(file)) {
      const f0 = this.textures.get(`${file}_0`);
      if (f0) return f0;
    }
    if (!this.loading.has(file) && !/_\d+$/.test(file)) {
      void this.loadFile(file)
        .then(async (t) => {
          if (SHEET_4X4.has(file)) {
            this.textures.set(file, t);
            this.available.add(file);
            await this.sliceSheet4x4(file, t);
          } else {
            const processed = this.cropBorderAndNormalize(file, t);
            this.textures.set(file, processed);
            this.available.add(file);
          }
        })
        .catch(() => undefined);
    }
    return this.fallback.get(file);
  }

  hasPng(id: string): boolean {
    return this.available.has(this.filenameFor(id));
  }
}

export const assets = new AssetCatalog();

export function playerFrames(dir: 'down' | 'up' | 'left' | 'right'): string[] {
  return Array.from({ length: 16 }, (_, i) => `player_${dir}_${i}`);
}
