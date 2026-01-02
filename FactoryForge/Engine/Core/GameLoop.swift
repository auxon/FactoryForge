import Foundation

/// Main game loop that coordinates all game systems
final class GameLoop {
    // Core systems
    let world: World
    let chunkManager: ChunkManager
    let itemRegistry: ItemRegistry
    let recipeRegistry: RecipeRegistry
    let buildingRegistry: BuildingRegistry
    let technologyRegistry: TechnologyRegistry
    
    // Game systems
    private var systems: [System] = []
    private let miningSystem: MiningSystem
    private let beltSystem: BeltSystem
    private let inserterSystem: InserterSystem
    private let craftingSystem: CraftingSystem
    private let powerSystem: PowerSystem
    let researchSystem: ResearchSystem // Public for UI access
    private let pollutionSystem: PollutionSystem
    private let enemyAISystem: EnemyAISystem
    private let combatSystem: CombatSystem
    
    // Player
    let player: Player
    
    // UI state
    var uiSystem: UISystem?

    // Callbacks
    var onReturnToMenu: (() -> Void)?
    var onPlayerDeath: (() -> Void)?
    var onUpdate: (() -> Void)?
    
    // Save system
    let saveSystem: SaveSystem
    
    // Rendering reference
    weak var renderer: MetalRenderer?
    
    // State
    private(set) var isRunning: Bool = true
    var playTime: TimeInterval = 0

    // Player death state
    private(set) var isPlayerDead: Bool = false
    
    init(renderer: MetalRenderer, seed: UInt64? = nil) {
        self.renderer = renderer
        
        // Initialize registries
        itemRegistry = ItemRegistry()
        recipeRegistry = RecipeRegistry(itemRegistry: itemRegistry)
        buildingRegistry = BuildingRegistry()
        technologyRegistry = TechnologyRegistry()
        
        // Initialize world
        world = World()
        let worldSeed = seed ?? UInt64.random(in: 0...UInt64.max)
        print("GameLoop: Using seed for world generation: \(worldSeed)")
        chunkManager = ChunkManager(seed: worldSeed)
        
        // Initialize player
        player = Player(world: world)
        
        // Initialize game systems
        miningSystem = MiningSystem(world: world, chunkManager: chunkManager)
        beltSystem = BeltSystem(world: world)
        inserterSystem = InserterSystem(world: world, beltSystem: beltSystem, itemRegistry: itemRegistry)
        craftingSystem = CraftingSystem(world: world, recipeRegistry: recipeRegistry)
        powerSystem = PowerSystem(world: world)
        researchSystem = ResearchSystem(world: world, technologyRegistry: technologyRegistry)
        pollutionSystem = PollutionSystem(world: world, chunkManager: chunkManager)
        enemyAISystem = EnemyAISystem(world: world, chunkManager: chunkManager, player: player)
        combatSystem = CombatSystem(world: world)
        combatSystem.setRenderer(renderer)
        
        // Register systems in update order
        systems = [
            miningSystem,
            beltSystem,
            inserterSystem,
            craftingSystem,
            powerSystem,
            researchSystem,
            pollutionSystem,
            enemyAISystem,
            combatSystem
        ]
        
        // Initialize save system
        saveSystem = SaveSystem()
        
        // Initialize UI
        uiSystem = UISystem(gameLoop: self, renderer: renderer)
        
        // Load registries from JSON
        loadGameData()
        
        // Generate initial world around player
        chunkManager.update(playerPosition: player.position)
    }
    
    private func loadGameData() {
        itemRegistry.loadItems()
        recipeRegistry.loadRecipes()
        buildingRegistry.loadBuildings()
        technologyRegistry.loadTechnologies()
    }
    
    /// Main update loop - called every frame
    func update() {
        guard isRunning else { return }
        
        Time.shared.update()
        let deltaTime = Time.shared.deltaTime
        
        playTime += Double(deltaTime)

        // Check for player death
        if !isPlayerDead && player.isDead {
            handlePlayerDeath()
        }

        // Don't update game systems while player is dead
        if isPlayerDead {
            return
        }

        // Update player
        player.update(deltaTime: deltaTime)

        // Update chunk loading based on player position
        chunkManager.update(playerPosition: player.position)
        
        // Fixed timestep updates for game systems
        while Time.shared.consumeFixedUpdate() {
            for system in systems {
                system.update(deltaTime: Time.shared.fixedDeltaTime)
            }
        }
        
        // Update UI
        uiSystem?.update(deltaTime: deltaTime)

        // Update renderer camera to follow player (only if not manually panning and player is alive)
        if let inputManager = inputManager, !inputManager.isDragging && !isPlayerDead {
            renderer?.camera.target = player.position
        }
        renderer?.camera.update(deltaTime: deltaTime)

        // Call update callback
        onUpdate?()
    }
    
    // Input manager reference (set by GameViewController)
    weak var inputManager: InputManager?
    
    /// Render the game state
    func render(renderer: MetalRenderer) {
        // Render world tiles
        chunkManager.render(renderer: renderer, camera: renderer.camera)
        
        // Note: Entities (including player) are rendered by SpriteRenderer 
        // which queries the world for PositionComponent + SpriteComponent
        
        // Note: Player entity is rendered by SpriteRenderer which queries world entities
        // The player sprite component is already in the world, so it will be rendered automatically
        
        // Note: UI is rendered by MetalRenderer before this call to allow loading menu to render first
    }
    
    // MARK: - Game Actions
    
    /// Places an inserter with the specified type
    func changeInserterType(entity: Entity, newType: InserterType) {
        guard world.has(InserterComponent.self, for: entity) else { return }

        // Update the inserter component with the new type
        if var inserter = world.get(InserterComponent.self, for: entity) {
            inserter.type = newType
            world.remove(InserterComponent.self, from: entity)
            world.add(inserter, to: entity)
        }
    }

    func placeInserter(_ buildingId: String, at position: IntVector2, direction: Direction, offset: Vector2 = .zero, type: InserterType) -> Bool {
        print("GameLoop: placeInserter called - buildingId: \(buildingId), position: \(position), type: \(type)")
        guard let buildingDef = buildingRegistry.get(buildingId) else {
            print("GameLoop: placeInserter failed - buildingDef not found for: \(buildingId)")
            return false
        }
        guard canPlaceBuilding(buildingDef, at: position) else {
            print("GameLoop: placeInserter failed - cannot place building at: \(position)")
            return false
        }

        // Check if player has required items
        guard player.inventory.has(items: buildingDef.cost) else {
            print("GameLoop: placeInserter failed - player doesn't have required items: \(buildingDef.cost)")
            return false
        }

        // Remove items from player inventory (must reassign since InventoryComponent is a struct)
        var playerInventory = player.inventory
        playerInventory.remove(items: buildingDef.cost)
        player.inventory = playerInventory

        // Create the inserter entity
        let entity = world.spawn()
        print("GameLoop: Created inserter entity: \(entity)")

        // Add position component with offset to center at tap location
        world.add(PositionComponent(tilePosition: position, direction: direction, offset: offset), to: entity)
        print("GameLoop: Added PositionComponent to inserter entity \(entity) at tilePosition: \(position)")

        // Add inserter-specific components with the specified type
        addInserterComponents(entity: entity, buildingDef: buildingDef, type: type)
        
        // Verify the position was set correctly
        if let pos = world.get(PositionComponent.self, for: entity) {
            print("GameLoop: Verified inserter entity \(entity) position: \(pos.tilePosition)")
        } else {
            print("GameLoop: ERROR - Inserter entity \(entity) has no PositionComponent after placement!")
        }

        // Update chunk's entity list
        if let chunk = chunkManager.getChunk(at: position) {
            chunk.addEntity(entity, at: position)
        }

        // Trigger power network rebuild if needed
        if buildingDef.powerConsumption > 0 {
            powerSystem.markNetworksDirty()
        }

        print("GameLoop: placeInserter succeeded - entity: \(entity)")
        return true
    }

    func placeBuilding(_ buildingId: String, at position: IntVector2, direction: Direction, offset: Vector2 = .zero) -> Bool {
        guard let buildingDef = buildingRegistry.get(buildingId) else {
            return false
        }
        guard canPlaceBuilding(buildingDef, at: position) else { return false }

        // Check if player has required items
        guard player.inventory.has(items: buildingDef.cost) else { return false }

        // Remove items from player inventory (must reassign since InventoryComponent is a struct)
        var playerInventory = player.inventory
        playerInventory.remove(items: buildingDef.cost)
        player.inventory = playerInventory
        
        // Create the building entity
        let entity = world.spawn()
        
        // Add position component with offset to center at tap location
        world.add(PositionComponent(tilePosition: position, direction: direction, offset: offset), to: entity)
        
        // Add building-specific components based on type
        addBuildingComponents(entity: entity, buildingDef: buildingDef, position: position, direction: direction)
        
        // Update chunk's entity list
        if let chunk = chunkManager.getChunk(at: position) {
            chunk.addEntity(entity, at: position)
        }
        
        // Trigger power network rebuild if needed
        if buildingDef.type == .powerPole || buildingDef.powerConsumption > 0 || buildingDef.powerProduction > 0 {
            powerSystem.markNetworksDirty()
        }

        return true
    }
    
    func canPlaceBuilding(_ buildingId: String, at position: IntVector2, direction: Direction, ignoringEntity: Entity? = nil) -> Bool {
        guard let buildingDef = buildingRegistry.get(buildingId) else { return false }
        return canPlaceBuilding(buildingDef, at: position, ignoringEntity: ignoringEntity)
    }

    private func canPlaceBuilding(_ building: BuildingDefinition, at position: IntVector2, ignoringEntity: Entity? = nil) -> Bool {

        // Debug: Check where the player is
        for entity in world.query(PositionComponent.self) {
            if let _ = world.get(PositionComponent.self, for: entity),
               let collision = world.get(CollisionComponent.self, for: entity),
               collision.layer == .player {
                break
            }
        }

        for dy in 0..<building.height {
            for dx in 0..<building.width {
                let checkPos = position + IntVector2(Int(dx), Int(dy))

                // Check if tile is buildable
                guard let tile = chunkManager.getTile(at: checkPos) else {
                    return false
                }
                guard tile.isBuildable else {
                    return false
                }

                // Check if there's already a building here
                if world.hasEntityAt(position: checkPos) {
                    // Get the entity and check what it is
                    guard let entity = world.getEntityAt(position: checkPos) else {
                        // hasEntityAt returned true but getEntityAt returned nil - this shouldn't happen
                        // but allow placement to be safe
                        print("GameLoop: WARNING - hasEntityAt returned true but getEntityAt returned nil at \(checkPos)")
                        continue
                    }
                    
                    // If this is the entity we're ignoring (e.g., when moving a building), skip it
                    if let ignoringEntity = ignoringEntity, entity == ignoringEntity {
                        continue
                    }

                    // Check if the entity has a collision component
                    if let collision = world.get(CollisionComponent.self, for: entity) {
                        if collision.layer == .player {
                            // Allow placement - ignore player
                            continue
                        }
                    } else {
                        print("GameLoop: Entity has no collision component")
                    }

                    // Check if it's a building or machine
                    let hasBuildingComponents = world.has(PositionComponent.self, for: entity) &&
                                               world.has(SpriteComponent.self, for: entity)
                    print("GameLoop: Entity appears to be a building/machine: \(hasBuildingComponents)")

                    // For belts, allow placement on top of buildings too (for belt networks)
                    if building.type == .belt {
                        continue
                    }
                    
                    // Allow inserters and poles to be placed on belts
                    if building.type == .inserter || building.type == .powerPole {
                        if world.has(BeltComponent.self, for: entity) {
                            continue  // Allow inserter/pole on belt
                        }
                        // Also allow inserter/pole on another inserter/pole (for flexibility)
                        if world.has(InserterComponent.self, for: entity) || world.has(PowerPoleComponent.self, for: entity) {
                            continue
                        }
                        
                        // For inserters and poles, allow placement on top of buildings
                        // Check if the entity is a building (has building components like furnace, assembler, etc.)
                        let isBuilding = world.has(FurnaceComponent.self, for: entity) ||
                                        world.has(AssemblerComponent.self, for: entity) ||
                                        world.has(MinerComponent.self, for: entity) ||
                                        world.has(GeneratorComponent.self, for: entity) ||
                                        world.has(ChestComponent.self, for: entity) ||
                                        world.has(LabComponent.self, for: entity) ||
                                        world.has(SolarPanelComponent.self, for: entity) ||
                                        world.has(AccumulatorComponent.self, for: entity)
                        
                        if isBuilding {
                            // Allow inserters/poles to be placed on top of buildings
                            print("GameLoop: Allowing inserter/pole placement on top of building at \(checkPos)")
                            continue
                        }
                        
                        // For other entities, check if we're adjacent or overlapping
                        if let entityPos = world.get(PositionComponent.self, for: entity),
                           let sprite = world.get(SpriteComponent.self, for: entity) {
                            let origin = entityPos.tilePosition
                            // Use exact same calculation as getEntityAt
                            let width = Int32(ceil(sprite.size.x))
                            let height = Int32(ceil(sprite.size.y))
                            
                            // Check if checkPos is actually within the entity's bounds
                            // This matches the exact logic in World.getEntityAt
                            let isWithinBounds = checkPos.x >= origin.x && 
                                                 checkPos.x < origin.x + width &&
                                                 checkPos.y >= origin.y && 
                                                 checkPos.y < origin.y + height
                            
                            // Allow placement if adjacent or overlapping for inserters/poles
                            print("GameLoop: Allowing inserter/pole placement (adjacent or overlapping) at \(checkPos), entity at \(origin) size \(width)x\(height)")
                            continue
                        } else {
                            // If entity doesn't have position/sprite, allow placement
                            // (This handles edge cases where entities might not have all components)
                            print("GameLoop: Entity at \(checkPos) doesn't have position/sprite components, allowing inserter/pole placement")
                            continue
                        }
                    }

                    // Block placement on other entities
                    return false
                }
            }
        }
        return true
    }
    
    private func addBuildingComponents(entity: Entity, buildingDef: BuildingDefinition, position: IntVector2, direction: Direction) {
        // Add render component - belts should appear under buildings
        let renderLayer: RenderLayer = (buildingDef.type == .belt) ? .groundDecoration : .building
        // Belts should be centered on the tile where they're placed
        let isBelt = buildingDef.type == .belt
        world.add(SpriteComponent(
            textureId: buildingDef.textureId,
            size: Vector2(Float(buildingDef.width), Float(buildingDef.height)),
            layer: renderLayer,
            centered: isBelt
        ), to: entity)
        
        // Add health component
        world.add(HealthComponent(maxHealth: buildingDef.maxHealth), to: entity)
        
        // Add building-type specific components
        switch buildingDef.type {
        case .miner:
            world.add(MinerComponent(
                miningSpeed: buildingDef.miningSpeed,
                resourceOutput: buildingDef.resourceOutput
            ), to: entity)
            world.add(InventoryComponent(slots: 1, allowedItems: nil), to: entity)
            // Only add power consumer for electric miners (burner miners use fuel)
            if buildingDef.powerConsumption > 0 {
                world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)
            }
            
        case .furnace:
            world.add(FurnaceComponent(
                smeltingSpeed: buildingDef.craftingSpeed
            ), to: entity)
            // Furnace needs slots for: input ore, fuel, and output
            world.add(InventoryComponent(slots: 4, allowedItems: nil), to: entity)
            
        case .assembler:
            world.add(AssemblerComponent(
                craftingSpeed: buildingDef.craftingSpeed,
                craftingCategory: buildingDef.craftingCategory
            ), to: entity)
            world.add(InventoryComponent(slots: 8, allowedItems: nil), to: entity)
            world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)
            
        case .belt:
            world.add(BeltComponent(
                speed: buildingDef.beltSpeed,
                direction: direction
            ), to: entity)
            beltSystem.registerBelt(entity: entity, at: position, direction: direction)
            
        case .inserter:
            addInserterComponents(entity: entity, buildingDef: buildingDef, type: .input) // Default to input for regular placement
            
            // Set up inserter animation with sprite sheet frames
            if var sprite = world.get(SpriteComponent.self, for: entity) {
                // Create animation with all 16 frames from the sprite sheet
                let inserterFrames = (0..<16).map { "inserter_\($0)" }
                var inserterAnimation = SpriteAnimation(
                    frames: inserterFrames,
                    frameTime: 0.5 / 16.0,  // 0.5 seconds total for all frames
                    isLooping: true
                )
                inserterAnimation.pause()  // Start paused - will play when powered
                sprite.animation = inserterAnimation
                sprite.textureId = "inserter_0"  // Start with first frame
                world.add(sprite, to: entity)
            }
            
        case .powerPole:
            world.add(PowerPoleComponent(
                wireReach: buildingDef.wireReach,
                supplyArea: buildingDef.supplyArea
            ), to: entity)
            
        case .generator:
            // Boilers need powerProduction set, but steam engines produce power
            // For now, set a default power output for generators
            let powerOutput = buildingDef.powerProduction > 0 ? buildingDef.powerProduction : 1800.0  // Default 1.8 MW for boilers
            world.add(GeneratorComponent(
                powerOutput: powerOutput,
                fuelCategory: buildingDef.fuelCategory ?? "chemical"
            ), to: entity)
            // Boilers should only accept fuel items (coal, wood, solid-fuel)
            world.add(InventoryComponent(slots: 1, allowedItems: ItemRegistry.allowedFuel), to: entity)
            print("GameLoop: Added GeneratorComponent to entity \(entity) with powerOutput: \(powerOutput)")
            
        case .solarPanel:
            world.add(SolarPanelComponent(
                powerOutput: buildingDef.powerProduction
            ), to: entity)
            
        case .accumulator:
            world.add(AccumulatorComponent(
                capacity: buildingDef.accumulatorCapacity,
                chargeRate: buildingDef.accumulatorChargeRate
            ), to: entity)
            
        case .lab:
            world.add(LabComponent(
                researchSpeed: buildingDef.researchSpeed
            ), to: entity)
            world.add(InventoryComponent(slots: 6, allowedItems: ItemRegistry.allowedSciencePacks), to: entity)
            world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)
            
        case .turret:
            world.add(TurretComponent(
                range: buildingDef.turretRange,
                damage: buildingDef.turretDamage,
                fireRate: buildingDef.turretFireRate
            ), to: entity)
            world.add(InventoryComponent(slots: 1, allowedItems: ItemRegistry.allowedAmmo), to: entity)
            
        case .wall:
            world.add(WallComponent(), to: entity)
            
        case .chest:
            world.add(ChestComponent(), to: entity)
            world.add(InventoryComponent(slots: buildingDef.inventorySlots, allowedItems: nil), to: entity)
            
        case .pipe:
            world.add(PipeComponent(direction: direction), to: entity)
            
        case .pumpjack:
            world.add(PumpjackComponent(
                extractionRate: buildingDef.extractionRate
            ), to: entity)
            world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)
        }
    }

    private func addInserterComponents(entity: Entity, buildingDef: BuildingDefinition, type: InserterType) {
        world.add(InserterComponent(
            type: type,
            speed: buildingDef.inserterSpeed,
            stackSize: buildingDef.inserterStackSize,
            direction: .north // Direction will be set by position component
        ), to: entity)
        world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)

        // Add sprite component first (like other buildings)
        var sprite = SpriteComponent(
            textureId: "inserter",  // Start with first frame
            size: Vector2(Float(buildingDef.width), Float(buildingDef.height)),
            layer: .building,
            centered: true
        )
        
        // Create animation with all 16 frames from the sprite sheet
        // Frames are named "inserter_0" through "inserter_15" (extracted from inserters_sheet)
        let inserterFrames = (0..<16).map { "inserter_\($0)" }
        var inserterAnimation = SpriteAnimation(
            frames: inserterFrames,
            frameTime: 0.5 / 16.0,  // 0.5 seconds total for all frames
            isLooping: true
        )
        inserterAnimation.pause()  // Start paused - will play when powered
        sprite.animation = inserterAnimation
        
        // Add sprite component with animation
        world.add(sprite, to: entity)
        
        // Add health component (like other buildings)
        world.add(HealthComponent(maxHealth: buildingDef.maxHealth), to: entity)
    }

    func removeBuilding(at position: IntVector2) -> Bool {
        guard let entity = world.getEntityAt(position: position) else { return false }
        
        // Get items to return to player
        if let inventory = world.get(InventoryComponent.self, for: entity) {
            for stack in inventory.getAll() {
                player.inventory.add(stack)
            }
        }
        
        // Recycle building into recipe ingredients
        if let sprite = world.get(SpriteComponent.self, for: entity),
           let buildingDef = buildingRegistry.getByTexture(sprite.textureId) {
            
            // Find the item that corresponds to this building
            var itemId: String? = nil
            for item in itemRegistry.all {
                if item.placedAs == buildingDef.id {
                    itemId = item.id
                    break
                }
            }
            
            // Try to find a recipe that produces this item
            var recycledItems: [ItemStack] = []
            if let itemId = itemId {
                let recipes = recipeRegistry.recipes(producing: itemId)
                if let recipe = recipes.first {
                    // Return the recipe inputs (recycled ingredients)
                    recycledItems = recipe.inputs
                    print("GameLoop: Recycling \(buildingDef.name) into recipe ingredients: \(recycledItems)")
                }
            }
            
            // If no recipe found, fall back to building cost
            if recycledItems.isEmpty {
                recycledItems = buildingDef.cost
                print("GameLoop: No recipe found for \(buildingDef.name), returning building cost: \(recycledItems)")
            }
            
            // Add recycled items to player inventory
            for stack in recycledItems {
                player.inventory.add(stack)
            }
        }
        
        // Remove from belt system if needed
        if world.has(BeltComponent.self, for: entity) {
            beltSystem.unregisterBelt(at: position)
        }
        
        // Remove from chunk
        if let chunk = chunkManager.getChunk(at: position) {
            chunk.removeEntity(entity)
        }
        
        // Despawn entity
        world.despawn(entity)
        
        // Trigger power network rebuild
        powerSystem.markNetworksDirty()
        
        return true
    }
    
    func removeBuilding(entity: Entity) -> Bool {
        // Validate entity is still alive
        guard world.isAlive(entity) else {
            print("GameLoop: removeBuilding(entity: \(entity)) - entity is not alive")
            return false
        }
        
        guard let position = world.get(PositionComponent.self, for: entity) else {
            print("GameLoop: removeBuilding(entity: \(entity)) - entity has no position")
            return false
        }
        
        let tilePosition = position.tilePosition
        print("GameLoop: removeBuilding(entity: \(entity)) - deleting entity directly, position: \(tilePosition)")

        // Return items from entity's inventory to player
        if let inventory = world.get(InventoryComponent.self, for: entity) {
            for stack in inventory.getAll() {
                player.inventory.add(stack)
            }
        }

        // Recycle building into recipe ingredients
        if let sprite = world.get(SpriteComponent.self, for: entity) {
            var textureId = sprite.textureId
            var buildingDef: BuildingDefinition?
            
            // Handle inserter texture IDs
            if world.has(InserterComponent.self, for: entity),
               let inserter = world.get(InserterComponent.self, for: entity) {
                if abs(inserter.speed - 0.83) < 0.01 {
                    buildingDef = buildingRegistry.get("inserter")
                } else if abs(inserter.speed - 1.2) < 0.01 {
                    buildingDef = buildingRegistry.get("long-handed-inserter")
                } else if abs(inserter.speed - 2.31) < 0.01 {
                    buildingDef = buildingRegistry.get("fast-inserter")
                }
            } else if textureId.contains("_belt_") {
                // Extract base belt texture ID
                let parts = textureId.split(separator: "_")
                if let beltIndex = parts.firstIndex(where: { $0 == "belt" }) {
                    textureId = parts[0...beltIndex].joined(separator: "_")
                }
                buildingDef = buildingRegistry.getByTexture(textureId)
            } else {
                buildingDef = buildingRegistry.getByTexture(textureId)
            }
            
            // Recycle building into recipe ingredients
            if let buildingDef = buildingDef {
                // Find the item that corresponds to this building
                var itemId: String? = nil
                for item in itemRegistry.all {
                    if item.placedAs == buildingDef.id {
                        itemId = item.id
                        break
                    }
                }
                
                // Try to find a recipe that produces this item
                var recycledItems: [ItemStack] = []
                if let itemId = itemId {
                    let recipes = recipeRegistry.recipes(producing: itemId)
                    if let recipe = recipes.first {
                        // Return the recipe inputs (recycled ingredients)
                        recycledItems = recipe.inputs
                        print("GameLoop: Recycling \(buildingDef.name) into recipe ingredients: \(recycledItems)")
                    }
                }
                
                // If no recipe found, fall back to building cost
                if recycledItems.isEmpty {
                    recycledItems = buildingDef.cost
                    print("GameLoop: No recipe found for \(buildingDef.name), returning building cost: \(recycledItems)")
                }
                
                // Add recycled items to player inventory
                for stack in recycledItems {
                    player.inventory.add(stack)
                }
            }
        }

        // Remove from belt system if needed
        if world.has(BeltComponent.self, for: entity) {
            beltSystem.unregisterBelt(at: tilePosition)
        }

        // Remove from chunk
        if let chunk = chunkManager.getChunk(at: tilePosition) {
            chunk.removeEntity(entity)
        }

        // Despawn the entity directly (not by position lookup, which could find a different entity)
        world.despawn(entity)

        // Trigger power network rebuild
        powerSystem.markNetworksDirty()

        return true
    }
    
    func moveBuilding(entity: Entity, to newPosition: IntVector2) -> Bool {
        guard let oldPosition = world.get(PositionComponent.self, for: entity) else { return false }
        guard let sprite = world.get(SpriteComponent.self, for: entity) else { return false }
        
        // Get building definition to check placement validity
        var buildingDef: BuildingDefinition?
        
        // For inserters, we need to identify the type by speed since they all use the same texture
        if world.has(InserterComponent.self, for: entity),
           let inserter = world.get(InserterComponent.self, for: entity) {
            // Match inserter type by speed
            // Basic inserter: 0.83, Long-handed: 1.2, Fast: 2.31
            if abs(inserter.speed - 0.83) < 0.01 {
                buildingDef = buildingRegistry.get("inserter")
            } else if abs(inserter.speed - 1.2) < 0.01 {
                buildingDef = buildingRegistry.get("long-handed-inserter")
            } else if abs(inserter.speed - 2.31) < 0.01 {
                buildingDef = buildingRegistry.get("fast-inserter")
            } else {
                // Fallback to basic inserter
                buildingDef = buildingRegistry.get("inserter")
            }
        } else {
            // For other buildings, use texture ID matching
            var textureId = sprite.textureId
            
            if textureId.contains("_belt_") {
                // Extract base belt texture ID from directional texture
                // e.g., "transport_belt_north_001" -> "transport_belt"
                // e.g., "fast_transport_belt_north_001" -> "fast_transport_belt"
                // e.g., "express_transport_belt_north_001" -> "express_transport_belt"
                let parts = textureId.split(separator: "_")
                // Find where "belt" appears, then take everything up to and including "belt"
                if let beltIndex = parts.firstIndex(where: { $0 == "belt" }) {
                    textureId = parts[0...beltIndex].joined(separator: "_")
                }
            }
            
            buildingDef = buildingRegistry.getByTexture(textureId)
        }
        
        guard let buildingDef = buildingDef else {
            print("GameLoop: moveBuilding - failed to find building definition for entity \(entity)")
            return false
        }
        
        // If moving to the same position, allow it (no-op)
        if oldPosition.tilePosition == newPosition {
            return true
        }
        
        // Check if new position is valid
        // Pass the entity being moved as ignoringEntity so it doesn't block its own move
        // This handles the case where a multi-tile building's old position overlaps its new position
        guard canPlaceBuilding(buildingDef, at: newPosition, ignoringEntity: entity) else {
            print("GameLoop: moveBuilding - cannot place building at \(newPosition)")
            return false
        }
        
        // Get old position
        let oldTilePos = oldPosition.tilePosition
        
        // Update position component
        var newPos = oldPosition
        newPos.tilePosition = newPosition
        world.add(newPos, to: entity)
        
        // Remove from old chunk
        if let oldChunk = chunkManager.getChunk(at: oldTilePos) {
            oldChunk.removeEntity(entity)
        }
        
        // Remove from belt system if needed
        if world.has(BeltComponent.self, for: entity) {
            beltSystem.unregisterBelt(at: oldTilePos)
        }
        
        // Add to new chunk
        if let newChunk = chunkManager.getChunk(at: newPosition) {
            newChunk.addEntity(entity, at: newPosition)
        }
        
        // Re-register belt if needed
        if world.has(BeltComponent.self, for: entity),
           let belt = world.get(BeltComponent.self, for: entity) {
            beltSystem.registerBelt(entity: entity, at: newPosition, direction: belt.direction)
        }
        
        // Trigger power network rebuild
        powerSystem.markNetworksDirty()
        
        return true
    }
    
    func rotateBelt(entity: Entity) -> Bool {
        // Check if entity is a belt
        guard var belt = world.get(BeltComponent.self, for: entity),
              let position = world.get(PositionComponent.self, for: entity) else {
            return false
        }
        
        // Rotate direction clockwise
        belt.direction = belt.direction.clockwise
        
        // Update belt component
        world.add(belt, to: entity)
        
        // Re-register belt in belt system with new direction
        beltSystem.unregisterBelt(at: position.tilePosition)
        beltSystem.registerBelt(entity: entity, at: position.tilePosition, direction: belt.direction)
        
        return true
    }
    
    func setRecipe(for entity: Entity, recipeId: String) {
        guard let recipe = recipeRegistry.get(recipeId) else { return }
        
        if var assembler = world.get(AssemblerComponent.self, for: entity) {
            assembler.recipe = recipe
            assembler.craftingProgress = 0
            world.add(assembler, to: entity)
        } else if var furnace = world.get(FurnaceComponent.self, for: entity) {
            furnace.recipe = recipe
            furnace.smeltingProgress = 0
            world.add(furnace, to: entity)
        }
    }
    
    // MARK: - Player Death

    private func handlePlayerDeath() {
        isPlayerDead = true

        // Clear any ongoing crafting when player dies
        player.cancelCrafting()

        // Hide player sprite during death
        if var sprite = world.get(SpriteComponent.self, for: player.playerEntity) {
            sprite.tint = Color(r: 1.0, g: 0.3, b: 0.3, a: 0.5)  // Red tint, semi-transparent
            world.add(sprite, to: player.playerEntity)
        }

        // Notify GameViewController to show game over screen
        onPlayerDeath?()

        // Optional: Play death sound
        AudioManager.shared.playTurretFireSound()
    }

    private func showGameOverScreen() {
        // For now, we'll pause the game and show a simple game over state
        // The UI will be handled by modifying the HUD to show game over overlay
        // TODO: This should show "GAME OVER" text and "MENU" button
    }

    // Called when player chooses to return to menu
    func returnToMenu() {
        // Reset death state
        isPlayerDead = false

        // Reset player state for next game
        player.heal(player.maxHealth)
        player.position = Vector2(0, 0)

        if var sprite = world.get(SpriteComponent.self, for: player.playerEntity) {
            sprite.tint = .white
            world.add(sprite, to: player.playerEntity)
        }

        if var health = world.get(HealthComponent.self, for: player.playerEntity) {
            health.immunityTimer = 0
            world.add(health, to: player.playerEntity)
        }

        // Notify GameViewController to return to menu
        onReturnToMenu?()
    }

    // MARK: - Lifecycle

    func pause() {
        Time.shared.isPaused = true
        isRunning = false
    }

    func resume() {
        Time.shared.isPaused = false
        isRunning = true
    }
    
    func save() {
        saveSystem.save(gameLoop: self)
    }
    
    func load(saveData: GameSave) {
        saveSystem.load(saveData: saveData, into: self)
    }
    
    // MARK: - Public Accessors
    
    func isRecipeUnlocked(_ recipeId: String) -> Bool {
        return researchSystem.isRecipeUnlocked(recipeId)
    }
    
    func isTechnologyResearched(_ techId: String) -> Bool {
        return researchSystem.completedTechnologies.contains(techId)
    }
}

