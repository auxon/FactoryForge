# FactoryForge Sprite Requirements

This document lists all sprites needed for the FactoryForge game. Each sprite should be 32x32 pixels, pixel art style, suitable for a Factorio-inspired factory automation game.

## Naming Convention
- Files should be named with underscores: `sprite_name.png`
- Item IDs use hyphens in code but files use underscores (e.g., `iron-ore` → `iron_ore.png`)

## Sprite Categories

### TERRAIN TILES (32x32)
- `grass.png` - Green grass texture
- `dirt.png` - Brown dirt/earth texture
- `stone.png` - Gray stone/rock texture
- `water.png` - Blue water texture
- `sand.png` - Light tan sand texture
- `iron_ore.png` - Dark gray metallic ore with rust
- `copper_ore.png` - Orange-brown copper ore
- `coal.png` - Black coal chunks
- `tree.png` - Top-down tree view (circular foliage, trunk)

### BUILDINGS - MINING
- `burner_mining_drill.png` - 2x2 tiles, early game mining drill, brown/rusty
- `electric_mining_drill.png` - 3x3 tiles, blue/white electric drill

### BUILDINGS - SMELTING
- `stone_furnace.png` - 2x2 tiles, primitive stone furnace
- `steel_furnace.png` - 2x2 tiles, metal furnace
- `electric_furnace.png` - 3x3 tiles, electric furnace

### BUILDINGS - CRAFTING
- `assembling_machine_1.png` - 3x3 tiles, basic assembler
- `assembling_machine_2.png` - 3x3 tiles, advanced assembler
- `assembling_machine_3.png` - 3x3 tiles, top-tier assembler

### BUILDINGS - LOGISTICS - BELTS
- `transport_belt.png` - Yellow conveyor belt
- `fast_transport_belt.png` - Blue conveyor belt
- `express_transport_belt.png` - Purple conveyor belt

### BUILDINGS - LOGISTICS - INSERTERS
- `inserter.png` - Yellow inserter arm
- `long_handed_inserter.png` - Blue inserter with longer reach
- `fast_inserter.png` - Red/orange fast inserter

### BUILDINGS - LOGISTICS - STORAGE
- `wooden_chest.png` - Wooden storage chest
- `iron_chest.png` - Iron storage chest
- `steel_chest.png` - Steel storage chest

### BUILDINGS - POWER GENERATION
- `boiler.png` - Steam boiler, 2x3 tiles
- `steam_engine.png` - Large steam engine, 3x5 tiles
- `solar_panel.png` - Blue solar panel array, 3x3 tiles
- `accumulator.png` - Energy storage, 2x2 tiles

### BUILDINGS - POWER DISTRIBUTION
- `small_electric_pole.png` - Small wooden pole
- `medium_electric_pole.png` - Medium metal pole
- `big_electric_pole.png` - Large transmission pole, 2x2 tiles

### BUILDINGS - RESEARCH
- `lab.png` - Research laboratory, 3x3 tiles

### BUILDINGS - COMBAT
- `gun_turret.png` - Gun turret, 2x2 tiles
- `laser_turret.png` - Laser turret, 2x2 tiles
- `stone_wall.png` - Defense wall
- `radar.png` - Radar installation, 2x2 tiles

### BUILDINGS - FLUIDS
- `pipe.png` - Pipe segment

### ITEMS - RAW MATERIALS
- `iron_ore.png` - Small icon of iron ore (item icon)
- `copper_ore.png` - Small icon of copper ore (item icon)
- `coal.png` - Small icon of coal (item icon)
- `stone.png` - Small icon of stone (item icon)
- `wood.png` - Small icon of wood logs (item icon)
- `crude_oil.png` - Small icon of oil barrel (item icon)
- `uranium_ore.png` - Small icon of uranium ore (item icon)

### ITEMS - INTERMEDIATE PRODUCTS
- `iron_plate.png` - Gray metal plate icon
- `copper_plate.png` - Orange/reddish metal plate icon
- `steel_plate.png` - Dark gray/blue steel plate icon
- `stone_brick.png` - Gray rectangular brick icon
- `iron_gear_wheel.png` - Gray gear/cog icon
- `copper_cable.png` - Orange/red wire/cable coil icon
- `electronic_circuit.png` - Green circuit board icon
- `advanced_circuit.png` - Blue/purple circuit board icon
- `processing_unit.png` - Purple/blue processor chip icon
- `engine_unit.png` - Gray mechanical engine component icon
- `electric_engine_unit.png` - Blue electric motor component icon

### ITEMS - SCIENCE PACKS
- `automation_science_pack.png` - Red science flask/vial
- `logistic_science_pack.png` - Green science flask/vial
- `military_science_pack.png` - Gray/military colored science flask
- `chemical_science_pack.png` - Blue science flask
- `production_science_pack.png` - Purple science flask
- `utility_science_pack.png` - Yellow science flask

### ITEMS - COMBAT
- `firearm_magazine.png` - Gray/bronze bullet magazine
- `piercing_rounds_magazine.png` - Gray/steel advanced ammo clip
- `grenade.png` - Green military grenade

### ENTITIES
- `player.png` - Player character (already exists, may need frames)
- `biter.png` - Alien creature/enemy
- `spawner.png` - Enemy spawner structure
- `bullet.png` - Small bullet/projectile

### UI ELEMENTS
- `solid_white.png` - Pure white square (for UI backgrounds/bars)
- `building_placeholder.png` - Gray placeholder box

## Notes

1. **Multi-tile Buildings**: Buildings that span multiple tiles (e.g., 2x2, 3x3) should be generated at their full size:
   - 2x2 building = 64x64 pixels
   - 3x3 building = 96x96 pixels
   - 3x5 building = 96x160 pixels

2. **Items vs Buildings**: Some items place buildings (e.g., `iron_chest` item places `iron_chest` building). These can share the same sprite file name.

3. **Style**: Clean pixel art, consistent with Factorio aesthetic. Use consistent lighting (top-down, light from above), shadow direction, and color palette.

4. **Color Palette**:
   - Metals: grays, silvers, blues
   - Resources: browns, yellows, blacks, oranges
   - Buildings: industrial grays, oranges, greens
   - Power: blues, whites
   - Science: various colors (red, green, blue, purple, yellow)

5. **File Format**: PNG with transparency support

## Total Sprite Count

- Terrain: 9 sprites
- Buildings: ~25 sprites (some multi-tile)
- Items: ~35 sprites
- Entities: 4 sprites (player already exists)
- UI: 2 sprites

**Total: ~75 sprite files needed**

