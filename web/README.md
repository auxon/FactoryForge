# FactoryForge Web

Three.js (WebGPU + WebGL2 fallback) port of FactoryForge with keyboard/mouse controls, full single-player systems, PvAI, AutoPlay, and WebSocket multiplayer.

## Assets

Game sprites are copied from `FactoryForge/Assets/` into `public/assets/`.

```bash
powershell -File scripts/sync-assets.ps1
```

The splash screen loads `/assets/splash.png` and preloads all PNGs listed in `public/assets/manifest.json`. The renderer uses these via `AssetCatalog` (nearest filtering), falling back to procedural textures only if a file is missing.

### Multiplayer server

```bash
npm run server
```

In-game: Menu → Lobby → Connect Multiplayer (`ws://localhost:8080`).

## Controls

| Action | Input |
|--------|--------|
| Move | WASD / arrows |
| Zoom | Mouse wheel / trackpad |
| Pan camera | MMB or RMB drag |
| Mine / select / place | LMB |
| Shoot | Double-click or F |
| Rotate building | R / Q / E |
| Inventory / Craft / Build / Research | I / C / B / T |
| Toggle 2D/3D view | V |
| Pause | Space / P |
| Deselect / cancel | Esc |

## Architecture

- `src/engine` — ECS, GameLoop (60 Hz fixed), input, render
- `src/game` — systems (mining→rockets), world, AI, multiplayer helpers
- `shared/data` — items, recipes, techs, building_configs JSON
- `shared/net` — `NetworkMessage` protocol
- `server` — authoritative WebSocket host

## Parity checklist

See in-game Menu help and iOS `FactoryForge/Docs/INSTRUCTIONS.md`. Win by launching a rocket with a satellite (space science).
