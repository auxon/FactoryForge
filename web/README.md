# FactoryForge Web — Three.js port

Total port of the Swift iOS game **FactoryForge** (Factorio-like factory
automation) to the web: **Vite + TypeScript + Three.js**. Lives in `web/`
beside the Swift code.

## Run

```bash
cd web
npm install
npm run dev      # http://localhost:5174
npm run build    # type-check + production bundle
```

## Verified data parity (against Swift source)

| Registry | Swift | Web | Check |
|---|---|---|---|
| Items | 88 | 88 | `ITEMS.length` |
| Recipes (unique ids) | 58 | 58 | ids diffed identical |
| Buildings | 47 | 47 | `BUILDINGS.length` |
| Technologies | 35 | 35 | `TECHNOLOGIES.length` |
| Fluids | 8 | 8 | `FLUIDS.length` |

(Note: an early map said "59 recipes" — the Swift file has 60
`register(` line hits including the function def; unique ids = 58,
diffed byte-identical against `RecipeRegistry.swift`.)

Sources: `src/data/{items,recipes,buildings,tech,fluids}.ts` ported from
`ItemRegistry`, `RecipeRegistry`, `building_configs/*.json` + embedded
`lab`/`offshore-pump`, `TechTree.swift`, `FluidData.swift` — same ids,
costs, times, speeds, tech prerequisites/costs.

## Simulation (`src/sim/`)

Fixed `1/60` timestep (max 5/frame), system order
mining → belts → inserters → crafting → power → research → enemies →
combat → rocket, per the Swift priorities. Belt speeds (1.875/3.75/5.625),
miner speeds (0.5/0.75), furnace/assembler speeds, fuel seconds
(coal 4 / wood 2 / solid-fuel 12), turret stats, rocket assembly
(100 parts + 50 fuel + 1 satellite → 10 s launch → +1000 space science),
grace period 5 min before biters attack. Hand-craft queue, 70-slot
inventory, localStorage saves (`ff-<slot>`).

Deliberate simplifications vs Swift: single power-grid model via pole
flood-fill (no per-wire voltage), inserter auto source-behind/target-ahead
(no connection dialog), fluid networks abstracted to machine buffers for
the core loop (oil/chem recipes present, full pipe pressure model TODO),
no multiplayer / AI players / PvP / replay / IAP.

Headless test: `smoke.ts` (`esbuild smoke.ts --bundle ... && node`)
covers mine → smelt → hand-craft → belts → research → rocket win.
All green.

## Render (`src/render/view.ts`)

Tilted perspective camera following the player (wheel zoom, right-drag
pan, Q/E orbit, F refollow), low-poly machines color-coded by category,
instanced ore patches/trees, animated belt items, power-status lamps,
ghost placement preview with validity coloring, selection highlight.

## Controls

WASD/arrows move · click ore/tree: hand-mine · Space: attack · click
machine: open it · Build (B) → pick → click to place, drag paints
belts/pipes · R rotate · Esc cancel · C craft · V bags · G research ·
Load all / Take all moves items between bags and machines.
