# FactoryForge Web — Parity Checklist

Mapped against iOS `FactoryForge/Docs/INSTRUCTIONS.md` and the Complete Parity plan.

## Core loop
- [x] Procedural chunks / resources / trees
- [x] Player move (WASD), mine, chop
- [x] Inventory + hand crafting
- [x] Place / rotate / remove buildings
- [x] Belts + inserters
- [x] Furnaces + assemblers + chests
- [x] Power poles, boilers, steam engines, solar, accumulators
- [x] Research / tech tree / labs
- [x] Fluids (pipes, pumps, boilers/steam, pumpjack oil)
- [x] Oil refinery / chemical plant shells
- [x] Pollution + biters + turrets + walls
- [x] Player shoot (F / double-click)
- [x] Units + unit production buildings
- [x] Rocket silo + satellite → space science victory
- [x] Save / load / autosave (localStorage)
- [x] AutoPlay scenarios + game speed
- [x] PvAI + lobby UI
- [x] Fog of war helper
- [x] WebSocket multiplayer (handshake / snapshot / delta / command / ping)
- [x] Hybrid 2D ortho + 3D perspective toggle (V)

## Controls (web equivalents)
- [x] WASD move, wheel zoom, MMB/RMB pan
- [x] LMB select/mine/place, R rotate, Esc cancel
- [x] I/C/B/T menus, P pause, V view mode

## Intentionally out of scope
- [ ] StoreKit IAP
- [ ] CoreMotion tilt / shake / haptics
- [ ] iOS MCP debug bridge as gameplay dependency
- [ ] Full PNG sprite atlas (procedural colors until assets copied from iOS bundle)

## Asset note
Copy PNGs from the iOS app bundle into `web/public/assets/` per `FactoryForge/Assets/SPRITE_LIST.md` when available; `ColorAtlas` provides fallbacks.
