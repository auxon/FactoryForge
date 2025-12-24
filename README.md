# FactoryForge

A Factorio-inspired factory automation game for iOS, built with Swift and Metal.

## Features

### Core Gameplay
- **Resource Mining**: Extract iron ore, copper ore, coal, stone, and uranium from procedurally generated deposits
- **Crafting System**: Craft items by hand or use assembling machines for automation
- **Logistics**: Transport items using belts and inserters in a two-lane system
- **Power Network**: Generate electricity with boilers/steam engines or solar panels, distribute via power poles
- **Research**: Unlock new technologies and recipes through science packs
- **Combat**: Defend your factory from biters with turrets and walls

### Technical Features
- **Pure Metal Rendering**: High-performance GPU-accelerated rendering with instanced drawing
- **Entity Component System**: Efficient ECS architecture for managing thousands of entities
- **Chunk-Based World**: Infinite procedural world with efficient streaming
- **Touch Controls**: Optimized for iPhone with gestures for building, panning, and zooming

## Project Structure

```
FactoryForge/
├── App/                    # Application entry point
│   ├── AppDelegate.swift
│   ├── GameViewController.swift
│   └── Info.plist
├── Engine/
│   ├── Core/              # Core engine systems
│   │   ├── GameLoop.swift
│   │   ├── Time.swift
│   │   └── Math.swift
│   ├── ECS/               # Entity Component System
│   │   ├── Entity.swift
│   │   ├── Component.swift
│   │   ├── System.swift
│   │   ├── World.swift
│   │   └── Components/
│   ├── Rendering/         # Metal rendering
│   │   ├── MetalRenderer.swift
│   │   ├── TextureAtlas.swift
│   │   ├── TileMapRenderer.swift
│   │   ├── SpriteRenderer.swift
│   │   ├── ParticleRenderer.swift
│   │   └── Shaders/
│   ├── Input/             # Touch input handling
│   │   ├── InputManager.swift
│   │   └── TouchHandler.swift
│   └── Audio/             # Audio management
│       └── AudioManager.swift
├── Game/
│   ├── World/             # World generation and management
│   │   ├── Chunk.swift
│   │   ├── ChunkManager.swift
│   │   ├── WorldGenerator.swift
│   │   ├── Tile.swift
│   │   └── Biome.swift
│   ├── Items/             # Item definitions
│   │   ├── Item.swift
│   │   └── ItemRegistry.swift
│   ├── Recipes/           # Crafting recipes
│   │   ├── Recipe.swift
│   │   └── RecipeRegistry.swift
│   ├── Buildings/         # Building definitions
│   │   ├── Building.swift
│   │   └── BuildingRegistry.swift
│   ├── Systems/           # Game systems
│   │   ├── MiningSystem.swift
│   │   ├── BeltSystem.swift
│   │   ├── InserterSystem.swift
│   │   ├── CraftingSystem.swift
│   │   ├── PowerSystem.swift
│   │   ├── ResearchSystem.swift
│   │   ├── PollutionSystem.swift
│   │   ├── EnemyAISystem.swift
│   │   └── CombatSystem.swift
│   ├── Research/          # Technology tree
│   │   ├── Technology.swift
│   │   └── TechTree.swift
│   └── Player/            # Player management
│       └── Player.swift
├── UI/                    # User interface
│   ├── UISystem.swift
│   ├── HUD.swift
│   ├── InventoryUI.swift
│   ├── CraftingMenu.swift
│   ├── BuildMenu.swift
│   ├── ResearchUI.swift
│   └── MachineUI.swift
└── Data/                  # Save/load and settings
    ├── SaveSystem.swift
    └── GameData.swift
```

## Building

1. Open `FactoryForge.xcodeproj` in Xcode 15+
2. Select an iOS device or simulator as the target
3. Build and run (⌘+R)

## Requirements

- iOS 15.0+
- Xcode 15.0+
- Device with Metal support

## Architecture

### Entity Component System (ECS)
The game uses a custom ECS architecture for efficient entity management:
- **Entities**: Unique identifiers with generation counters for safe references
- **Components**: Data-only structs stored in sparse sets for cache-friendly iteration
- **Systems**: Process entities with specific component combinations each frame

### Rendering Pipeline
- Instanced rendering for tiles and sprites (single draw call for thousands of objects)
- Texture atlas to minimize texture binds
- GPU-driven particle system for smoke, explosions, and effects
- Separate render passes for tiles, sprites, particles, and UI

### Game Systems
All game logic is implemented as systems that process entities each frame:
1. **Mining**: Extracts resources from ore deposits
2. **Belt**: Moves items along transport belts with two-lane logic
3. **Inserter**: Transfers items between belts and inventories
4. **Crafting**: Processes recipes in assemblers and furnaces
5. **Power**: Manages electrical networks and power distribution
6. **Research**: Handles technology progression
7. **Pollution**: Spreads pollution and triggers enemy aggression
8. **Enemy AI**: Controls enemy spawning and attack behavior
9. **Combat**: Manages turret targeting and projectile damage

## Controls

- **Tap**: Place building / Select entity
- **Pan**: Move camera
- **Pinch**: Zoom camera
- **Long Press**: Open context menu
- **Two-finger Rotate**: Rotate building before placement

## License

This project is for educational purposes.
