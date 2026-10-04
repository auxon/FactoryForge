#!/usr/bin/env python3
"""Generate tileable steampunk PBR textures for FactoryForge machinery."""
from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "tex")
SIZE = 512


def _fade(t: np.ndarray) -> np.ndarray:
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


def value_noise(w: int, h: int, freq: float, seed: int) -> np.ndarray:
    rng = np.random.RandomState(seed)
    gw = int(math.ceil(freq)) + 2
    gh = int(math.ceil(freq * h / w)) + 2
    grid = rng.rand(gh, gw).astype(np.float32)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    fx = xs * freq / w
    fy = ys * freq / h
    x0 = np.floor(fx).astype(np.int32)
    y0 = np.floor(fy).astype(np.int32)
    tx = _fade(fx - x0)
    ty = _fade(fy - y0)
    x0 %= gw - 1
    y0 %= gh - 1
    x1 = (x0 + 1) % (gw - 1)
    y1 = (y0 + 1) % (gh - 1)
    n00 = grid[y0, x0]
    n10 = grid[y0, x1]
    n01 = grid[y1, x0]
    n11 = grid[y1, x1]
    return (n00 * (1 - tx) + n10 * tx) * (1 - ty) + (n01 * (1 - tx) + n11 * tx) * ty


def fbm(w: int, h: int, freq: float, octaves: int, seed: int) -> np.ndarray:
    acc = np.zeros((h, w), dtype=np.float32)
    amp = 1.0
    norm = 0.0
    for i in range(octaves):
        acc += value_noise(w, h, freq * (2 ** i), seed + i * 17) * amp
        norm += amp
        amp *= 0.5
    return acc / max(norm, 1e-6)


def warp(n: np.ndarray, amount: float = 8.0) -> np.ndarray:
    h, w = n.shape
    xs = (np.arange(w)[None, :] + (n - 0.5) * amount) % w
    ys = (np.arange(h)[:, None] + (n.T[:h, :w] - 0.5) * amount) % h
    return n[ys.astype(np.int32), xs.astype(np.int32)]


def scratches(w: int, h: int, seed: int, n: int = 80, width: float = 0.6) -> np.ndarray:
    rng = np.random.RandomState(seed)
    img = np.zeros((h, w), dtype=np.float32)
    yy, xx = np.mgrid[0:h, 0:w]
    for _ in range(n):
        x0, y0 = rng.uniform(0, w), rng.uniform(0, h)
        ang = rng.uniform(0, math.pi)
        length = rng.uniform(20, 180)
        dx, dy = math.cos(ang), math.sin(ang)
        t = (xx - x0) * dx + (yy - y0) * dy
        d = np.abs((xx - x0) * -dy + (yy - y0) * dx)
        mask = (t > 0) & (t < length) & (d < width + rng.uniform(0, 0.8))
        img[mask] = np.maximum(img[mask], 1.0 - d[mask] / (width + 0.4))
    return np.clip(img, 0, 1)


def tile_seams(w: int, h: int, tiles: int, grout: int = 3) -> np.ndarray:
    img = np.ones((h, w), dtype=np.float32)
    tw, th = w // tiles, h // tiles
    for i in range(tiles + 1):
        img[:, max(0, i * tw - grout): i * tw + grout] *= 0.15
        img[max(0, i * th - grout): i * th + grout, :] *= 0.15
    return img


def brick_mask(w: int, h: int, bx: int = 8, by: int = 12) -> np.ndarray:
    img = np.ones((h, w), dtype=np.float32)
    tw, th = w // bx, h // by
    grout = 3
    yy, xx = np.mgrid[0:h, 0:w]
    row = yy // th
    ox = (row % 2) * (tw // 2)
    local_x = (xx - ox) % tw
    local_y = yy % th
    img[(local_x < grout) | (local_y < grout)] = 0.18
    return img


def height_to_normal(height: np.ndarray, strength: float = 4.0) -> np.ndarray:
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    n = np.dstack((-dx, -dy, np.ones_like(height)))
    mag = np.linalg.norm(n, axis=2, keepdims=True)
    n = n / np.maximum(mag, 1e-6)
    return ((n + 1.0) * 0.5).astype(np.float32)


def to_rgb(var: np.ndarray | float, color: tuple[float, float, float]) -> np.ndarray:
    """var is 0..1 modulation around `color` (the midtone), not a multiplier."""
    c = np.array(color, dtype=np.float32)
    if np.isscalar(var):
        v = float(var)
        return np.clip(c * (0.55 + 0.9 * v), 0, 1)
    v = var[..., None]
    return np.clip(c * (0.55 + 0.9 * v), 0, 1)


def plate_grid(w: int, h: int, n: int = 6, grout: int = 2) -> np.ndarray:
    img = np.ones((h, w), dtype=np.float32)
    tw, th = w // n, h // n
    for i in range(n + 1):
        img[:, max(0, i * tw - grout): i * tw + grout] *= 0.62
        img[max(0, i * th - grout): i * th + grout, :] *= 0.62
    return img


def mix(a: np.ndarray, b: np.ndarray, t: np.ndarray) -> np.ndarray:
    t = t[..., None] if t.ndim == 2 and a.ndim == 3 else t
    return a * (1 - t) + b * t


def save_rgb(path: str, arr: np.ndarray, jpeg: bool = True) -> None:
    img = np.clip(arr * 255.0, 0, 255).astype(np.uint8)
    if jpeg and path.endswith(".jpg"):
        Image.fromarray(img, "RGB").save(path, quality=86, optimize=True)
    else:
        Image.fromarray(img, "RGB").save(path)


def save_gray(path: str, arr: np.ndarray) -> None:
    img = np.clip(arr * 255.0, 0, 255).astype(np.uint8)
    Image.fromarray(img, "L").save(path, quality=86, optimize=True)


def iron(w: int, h: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    n1 = fbm(w, h, 6, 5, 11)
    n2 = fbm(w, h, 18, 4, 29)
    dirt = fbm(w, h, 4, 4, 47)
    sc = scratches(w, h, 91, 110, 0.55)
    rust = np.clip(fbm(w, h, 8, 4, 73) - 0.58, 0, 1) * 1.4
    plates = plate_grid(w, h, 5, 2)
    height = 0.5 + n1 * 0.16 + n2 * 0.08 - sc * 0.1 - rust * 0.06 + plates * 0.12
    base = to_rgb(0.62 + n1 * 0.25, (0.62, 0.58, 0.52))
    dark = to_rgb(0.4 + n2 * 0.15, (0.38, 0.34, 0.30))
    rust_c = to_rgb(0.7 + n2 * 0.15, (0.62, 0.32, 0.12))
    albedo = mix(mix(base, dark, dirt * 0.4), rust_c, np.clip(rust, 0, 1) * 0.55)
    albedo = mix(albedo, albedo * 0.72, (1 - plates) * 0.8)
    albedo = mix(albedo, albedo * 0.7, sc * 0.5)
    rough = np.clip(0.42 + n2 * 0.22 + rust * 0.18 - sc * 0.06, 0.25, 0.88)
    return albedo, height_to_normal(height, 6.5), rough


def brass(w: int, h: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    n1 = fbm(w, h, 5, 5, 3)
    n2 = fbm(w, h, 22, 4, 19)
    tarnish = np.clip(fbm(w, h, 3.5, 5, 41) - 0.42, 0, 1)
    sc = scratches(w, h, 7, 70, 0.4)
    plates = plate_grid(w, h, 4, 1)
    height = 0.52 + n1 * 0.12 + n2 * 0.06 - tarnish * 0.08 - sc * 0.06 + plates * 0.08
    polish = to_rgb(0.78 + n1 * 0.18, (0.90, 0.70, 0.28))
    aged = to_rgb(0.55 + n2 * 0.15, (0.62, 0.42, 0.16))
    green = to_rgb(0.45, (0.32, 0.48, 0.28))
    albedo = mix(mix(polish, aged, tarnish * 0.55), green, tarnish * tarnish * 0.22)
    albedo = mix(albedo, albedo * 0.78, (1 - plates) * 0.6)
    albedo = mix(albedo, albedo * 0.75, sc * 0.5)
    rough = np.clip(0.22 + tarnish * 0.32 + n2 * 0.1 + sc * 0.06, 0.12, 0.7)
    return albedo, height_to_normal(height, 4.2), rough


def rust(w: int, h: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    n1 = warp(fbm(w, h, 7, 5, 13), 14)
    flake = fbm(w, h, 16, 4, 59)
    sc = scratches(w, h, 23, 40, 0.8)
    height = 0.42 + n1 * 0.26 + flake * 0.12
    orange = to_rgb(0.72 + n1 * 0.22, (0.72, 0.38, 0.14))
    brown = to_rgb(0.5 + flake * 0.18, (0.42, 0.22, 0.10))
    dark = to_rgb(0.35, (0.22, 0.14, 0.08))
    albedo = mix(mix(orange, brown, flake * 0.55), dark, sc * 0.35)
    rough = np.clip(0.68 + flake * 0.18, 0.5, 0.95)
    return albedo, height_to_normal(height, 8.0), rough


def copper(w: int, h: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    n1 = fbm(w, h, 6, 5, 31)
    patina = np.clip(fbm(w, h, 4, 5, 67) - 0.5, 0, 1) * 1.3
    sc = scratches(w, h, 37, 50, 0.45)
    height = 0.5 + n1 * 0.12 - patina * 0.08
    metal = to_rgb(0.7 + n1 * 0.2, (0.82, 0.42, 0.22))
    verdi = to_rgb(0.5 + n1 * 0.12, (0.22, 0.52, 0.40))
    albedo = mix(metal, verdi, np.clip(patina, 0, 1) * 0.55)
    albedo = mix(albedo, albedo * 0.75, sc * 0.45)
    rough = np.clip(0.28 + patina * 0.3 + n1 * 0.1, 0.16, 0.75)
    return albedo, height_to_normal(height, 4.0), rough


def wood(w: int, h: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    grain = np.sin((xx * 0.085 + fbm(w, h, 3, 4, 5) * 18)) * 0.5 + 0.5
    rings = np.sin(xx * 0.02 + fbm(w, h, 2, 3, 8) * 6) * 0.5 + 0.5
    plank = tile_seams(w, h, 4, 4)
    n = fbm(w, h, 10, 4, 21)
    height = 0.45 + grain * 0.18 + n * 0.08 + plank * 0.12
    light = to_rgb(0.65 + grain * 0.25, (0.58, 0.38, 0.18))
    dark = to_rgb(0.4 + rings * 0.15, (0.32, 0.18, 0.08))
    albedo = mix(light, dark, 0.4 + n * 0.2)
    albedo = mix(albedo, to_rgb(0.25, (0.16, 0.10, 0.05)), 1 - plank)
    rough = np.clip(0.58 + n * 0.18 + (1 - plank) * 0.12, 0.42, 0.9)
    return albedo, height_to_normal(height, 5.5), rough


def brick(w: int, h: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    mask = brick_mask(w, h, 6, 10)
    n = fbm(w, h, 12, 4, 44)
    soot = fbm(w, h, 3, 4, 88)
    height = 0.35 + mask * 0.35 + n * 0.1
    clay = to_rgb(0.7 + n * 0.2, (0.68, 0.32, 0.20))
    soot_c = to_rgb(0.35 + soot * 0.1, (0.22, 0.16, 0.12))
    mortar = to_rgb(0.55 + n * 0.08, (0.55, 0.48, 0.40))
    albedo = mix(clay, soot_c, np.clip(soot - 0.35, 0, 1) * 0.4)
    albedo = mix(mortar, albedo, mask)
    rough = np.clip(0.72 + n * 0.12, 0.55, 0.95)
    return albedo, height_to_normal(height, 7.0), rough


def concrete(w: int, h: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    n1 = fbm(w, h, 5, 5, 2)
    n2 = fbm(w, h, 20, 4, 14)
    stain = np.clip(fbm(w, h, 3, 4, 33) - 0.55, 0, 1)
    height = 0.5 + n1 * 0.16 + n2 * 0.08 - stain * 0.06
    base = to_rgb(0.7 + n1 * 0.15, (0.58, 0.54, 0.48))
    dirt = to_rgb(0.45, (0.40, 0.30, 0.20))
    albedo = mix(base, dirt, stain * 0.55 + n2 * 0.12)
    rough = np.clip(0.78 + n2 * 0.1, 0.65, 0.95)
    return albedo, height_to_normal(height, 5.0), rough


def soot(w: int, h: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    n1 = fbm(w, h, 4, 5, 77)
    n2 = fbm(w, h, 16, 4, 99)
    sc = scratches(w, h, 55, 40, 0.7)
    plates = plate_grid(w, h, 5, 2)
    height = 0.42 + n1 * 0.18 + n2 * 0.08 + plates * 0.1
    albedo = to_rgb(0.45 + n1 * 0.2, (0.28, 0.24, 0.20))
    albedo = mix(albedo, to_rgb(0.5, (0.36, 0.22, 0.12)), n2 * 0.3)
    albedo = mix(albedo, albedo * 0.75, (1 - plates) * 0.7)
    albedo = mix(albedo, albedo * 1.15, sc * 0.35)
    rough = np.clip(0.58 + n2 * 0.18, 0.4, 0.9)
    return albedo, height_to_normal(height, 4.5), rough


def leather(w: int, h: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    n1 = fbm(w, h, 8, 5, 17)
    n2 = fbm(w, h, 24, 3, 27)
    height = 0.5 + n1 * 0.2 + n2 * 0.08
    albedo = to_rgb(0.28 + n1 * 0.12, (0.28, 0.14, 0.07))
    albedo = mix(albedo, to_rgb(0.12, (0.08, 0.04, 0.02)), n2 * 0.4)
    rough = np.clip(0.68 + n1 * 0.15, 0.5, 0.9)
    return albedo, height_to_normal(height, 3.5), rough


def chitin(w: int, h: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Overlapping beetle-plate scales: readable mid-brown, not black."""
    n1 = fbm(w, h, 5, 5, 61)
    n2 = fbm(w, h, 16, 4, 83)
    sc = scratches(w, h, 103, 50, 0.45)
    scales = plate_grid(w, h, 7, 2)
    # staggered second grid for scale overlap
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    stagger = ((yy + (xx // (w // 7)) * (h // 14)) % (h // 7)) / (h / 7)
    height = 0.48 + n1 * 0.16 + n2 * 0.08 + scales * 0.14 - stagger * 0.06
    base = to_rgb(0.58 + n1 * 0.22, (0.48, 0.32, 0.18))
    dark = to_rgb(0.38 + n2 * 0.12, (0.28, 0.16, 0.10))
    sheen = to_rgb(0.62, (0.36, 0.42, 0.22))
    albedo = mix(mix(base, dark, (1 - scales) * 0.7), sheen, n2 * 0.18)
    albedo = mix(albedo, albedo * 0.78, sc * 0.45)
    rough = np.clip(0.48 + n2 * 0.2 - scales * 0.08 + sc * 0.1, 0.3, 0.88)
    return albedo, height_to_normal(height, 6.0), rough


def flesh(w: int, h: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    n1 = warp(fbm(w, h, 4, 5, 21), 10)
    n2 = fbm(w, h, 14, 4, 39)
    height = 0.5 + n1 * 0.18 + n2 * 0.08
    pink = to_rgb(0.7 + n1 * 0.2, (0.72, 0.28, 0.26))
    raw = to_rgb(0.5 + n2 * 0.15, (0.48, 0.12, 0.12))
    pale = to_rgb(0.62, (0.78, 0.48, 0.42))
    albedo = mix(mix(pink, raw, n1 * 0.45), pale, n2 * 0.18)
    rough = np.clip(0.38 + n2 * 0.22, 0.22, 0.72)
    return albedo, height_to_normal(height, 3.2), rough


def bone(w: int, h: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    n1 = fbm(w, h, 6, 5, 9)
    n2 = fbm(w, h, 20, 4, 15)
    sc = scratches(w, h, 27, 40, 0.7)
    height = 0.5 + n1 * 0.14 + n2 * 0.08 - sc * 0.08
    ivory = to_rgb(0.78 + n1 * 0.16, (0.82, 0.74, 0.58))
    stain = to_rgb(0.5, (0.48, 0.32, 0.18))
    albedo = mix(ivory, stain, n2 * 0.28 + sc * 0.2)
    rough = np.clip(0.55 + n2 * 0.18, 0.4, 0.85)
    return albedo, height_to_normal(height, 4.0), rough


KINDS = {
    "iron": iron,
    "brass": brass,
    "rust": rust,
    "copper": copper,
    "wood": wood,
    "brick": brick,
    "concrete": concrete,
    "soot": soot,
    "leather": leather,
    "chitin": chitin,
    "flesh": flesh,
    "bone": bone,
}


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    w = h = SIZE
    for name, fn in KINDS.items():
        albedo, normal, rough = fn(w, h)
        save_rgb(os.path.join(OUT, f"{name}_d.jpg"), albedo)
        save_rgb(os.path.join(OUT, f"{name}_n.png"), normal, jpeg=False)
        save_gray(os.path.join(OUT, f"{name}_r.jpg"), rough)
        print(f"wrote {name}")
    print("textures ready in", OUT)


if __name__ == "__main__":
    main()
