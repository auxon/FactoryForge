# Automated Building Guide

This document captures the testing process and solutions discovered for automated building and furnace setup in FactoryForge.

## Problem Encountered

### Issue: Furnace Stopped Smelting After Manual Recipe Selection

**Symptoms:**
- Furnace was working initially
- User manually set a recipe in the furnace UI
- Furnace stopped smelting after recipe was set
- Rebuilding the furnace didn't immediately fix the issue

**Root Cause:**
- When a recipe is manually set, it may block auto-selection if the recipe is invalid or cannot start
- Furnaces should auto-select recipes based on input items, but manual selection can override this
- Output slots may be full, blocking new smelting operations

## Key Discoveries

### 1. Stone Furnace Building Cost

**Important:** The stone-furnace costs **5 iron-plate**, NOT 5 stone as some documentation suggests.

- **Building Config:** `building_configs/furnaces.json` shows cost: `{"itemId": "iron-plate", "count": 5}`
- **Recipe Registry:** Confirms `stone-furnace` recipe requires 5 iron-plate
- **Documentation Discrepancy:** Some docs (e.g., `Docs/Crafting.md`) incorrectly state 5 stone

### 2. Manual Crafting of Iron Plates

**Critical Finding:** Iron plates CAN be manually crafted by the player without a furnace!

- **Recipe:** `iron-plate` (category: `.smelting`)
- **Input:** 1 iron-ore
- **Craft Time:** 3.2 seconds per plate
- **Command:** `{"command":"craft","parameters":{"recipeId":"iron-plate","count":1}}`

This is essential for the bootstrap problem: you need iron plates to build a furnace, but normally need a furnace to make iron plates.

### 3. Furnace Recipe Selection

**Auto-Selection:**
- Furnaces auto-select recipes based on input items when `furnace.recipe == nil`
- Code in `CraftingSystem.swift` line 137-138: `if furnace.recipe == nil { furnace.recipe = autoSelectSmeltingRecipe(...) }`

**Manual Selection:**
- Manual recipe selection can override auto-selection
- If a wrong recipe is set, it may block smelting
- Solution: Open furnace UI and explicitly click the correct recipe button (e.g., "Iron Plate")

### 4. Furnace Output Collection

**Important:** According to `Docs/How to Use a Furnace.md`:
- Output items accumulate in the output slot (right side)
- **Manual collection required:** Click the output slot to transfer items to player inventory
- Full output slots can block new smelting operations

## Solution Process

### Step 1: Manual Crafting of Iron Plates

```python
# Craft 5 iron plates (need 5 for stone-furnace)
for i in range(5):
    cmd = '{"command":"craft","requestId":"iron_plate_' + str(i) + '","parameters":{"recipeId":"iron-plate","count":1}}'
    # Wait ~3.2 seconds per plate = ~16 seconds total
```

**Result:** Player can manually craft iron plates without a furnace, solving the bootstrap problem.

### Step 2: Build Stone Furnace

```python
# Build furnace near player position
cmd = '{"command":"build","parameters":{"buildingId":"stone-furnace","x":X,"y":Y,"direction":"north"}}'
```

**Requirements:**
- 5 iron-plate in inventory
- Valid build location (clear terrain, no existing buildings)

### Step 3: Setup Furnace for Smelting

```python
# Add iron ore to input slot (slot 1)
cmd = '{"command":"add_machine_item","parameters":{"x":X,"y":Y,"slot":1,"itemId":"iron-ore","count":20}}'

# Add coal to fuel slot (slot 0)
cmd = '{"command":"add_machine_item","parameters":{"x":X,"y":Y,"slot":0,"itemId":"coal","count":50}}'
```

**Slot Layout:**
- Slot 0: Fuel (coal, wood, etc.)
- Slot 1: Input ore/material
- Output slots: Right side (manual collection required)

### Step 4: Recipe Selection

**Manual Steps (User Action Required):**
1. Open furnace UI (tap the furnace)
2. Click the "Iron Plate" recipe button at the bottom
3. Wait for smelting to start
4. Collect plates from output slot when ready

**Why Manual Selection:**
- Ensures correct recipe is set
- Clears any stuck/invalid recipe state
- Unblocks smelting if output slot was full

## Building Placement

### Finding Valid Locations

**Common Issues:**
- "Insufficient resources" - Check inventory for required materials
- "Cannot place building at position" - Terrain or existing building conflict
- Build command returns success but building doesn't appear - Verify with `get_game_state`

**Solution:**
```python
# Try multiple positions near player
test_positions = [
    (px + 2, py), (px - 2, py), (px, py + 2), (px, py - 2),
    (px + 1, py + 1), (px - 1, py - 1)
]
```

### Verification

Always verify building placement:
```python
state_resp = get_game_state()
entities = state_data.get('world', {}).get('entities', [])
# Check if building exists at expected position
```

## Testing Commands Reference

### Check Current State
```bash
# Get inventory
curl -X POST http://localhost:8083/command \
  -H "Content-Type: application/json" \
  -d '{"command":"get_inventory","parameters":{}}'

# Get game state
curl -X POST http://localhost:8083/command \
  -H "Content-Type: application/json" \
  -d '{"command":"get_game_state","parameters":{}}'

# Get player position
curl -X POST http://localhost:8083/command \
  -H "Content-Type: application/json" \
  -d '{"command":"get_player_position","parameters":{}}'
```

### Manual Crafting
```bash
# Craft iron plate
curl -X POST http://localhost:8083/command \
  -H "Content-Type: application/json" \
  -d '{"command":"craft","parameters":{"recipeId":"iron-plate","count":1}}'
```

### Building
```bash
# Build stone-furnace
curl -X POST http://localhost:8083/command \
  -H "Content-Type: application/json" \
  -d '{"command":"build","parameters":{"buildingId":"stone-furnace","x":2,"y":0,"direction":"north"}}'
```

### Machine Setup
```bash
# Add item to machine slot
curl -X POST http://localhost:8083/command \
  -H "Content-Type: application/json" \
  -d '{"command":"add_machine_item","parameters":{"x":2,"y":0,"slot":1,"itemId":"iron-ore","count":20}}'

# Open machine UI
curl -X POST http://localhost:8083/command \
  -H "Content-Type: application/json" \
  -d '{"command":"open_machine_ui","parameters":{"x":2,"y":0}}'
```

## Lessons Learned

1. **Bootstrap Problem:** Manual crafting solves the chicken-and-egg problem of needing iron plates to build a furnace that makes iron plates.

2. **Documentation Accuracy:** Always verify building costs in code (`building_configs/`) rather than relying solely on documentation.

3. **Recipe Management:** Furnaces auto-select recipes, but manual selection may be needed to fix stuck states.

4. **Output Collection:** Machine outputs don't automatically transfer to player inventory - manual collection from output slots is required.

5. **State Verification:** Always verify building placement with `get_game_state` rather than trusting build command success messages.

6. **Error Messages:** "Insufficient resources" means missing materials, not terrain issues. Check inventory first.

## Next Steps for Automation

To fully automate furnace setup:
1. Implement recipe setting command (if not available)
2. Implement output slot collection command (if not available)
3. Add automatic retry logic for building placement
4. Create state machine for bootstrap sequence (craft plates → build furnace → setup furnace → collect output)

## Related Files

- `FactoryForge/building_configs/furnaces.json` - Furnace building definitions
- `FactoryForge/Game/Systems/CraftingSystem.swift` - Furnace smelting logic
- `FactoryForge/Docs/How to Use a Furnace.md` - Furnace usage guide
- `FactoryForge/Docs/Crafting.md` - Crafting system overview
- `FactoryForge/Engine/Network/GameNetworkManager.swift` - MCP command implementations
