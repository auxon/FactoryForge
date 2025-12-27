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
        chunkManager = ChunkManager(seed: seed ?? UInt64.random(in: 0...UInt64.max))
        
        // Initialize player
        player = Player(world: world)
        
        // Initialize game systems
        miningSystem = MiningSystem(world: world, chunkManager: chunkManager)
        beltSystem = BeltSystem(world: world)
        inserterSystem = InserterSystem(world: world, beltSystem: beltSystem)
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
    
    func placeBuilding(_ buildingId: String, at position: IntVector2, direction: Direction, offset: Vector2 = .zero) -> Bool {
        print("GameLoop: placeBuilding called for \(buildingId) at tile (\(position.x), \(position.y)) with offset (\(offset.x), \(offset.y))")
        guard let buildingDef = buildingRegistry.get(buildingId) else {
            print("GameLoop: placeBuilding failed - unknown building \(buildingId)")
            return false
        }
        guard canPlaceBuilding(buildingDef, at: position) else { return false }

        // Check if player has required items
        guard player.inventory.has(items: buildingDef.cost) else { return false }
        
        // Remove items from player inventory
        player.inventory.remove(items: buildingDef.cost)
        
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

        print("GameLoop: placeBuilding succeeded for \(buildingId)")
        return true
    }
    
    func canPlaceBuilding(_ buildingId: String, at position: IntVector2, direction: Direction) -> Bool {
        guard let buildingDef = buildingRegistry.get(buildingId) else { return false }
        return canPlaceBuilding(buildingDef, at: position)
    }

    private func canPlaceBuilding(_ building: BuildingDefinition, at position: IntVector2) -> Bool {
        print("GameLoop: canPlaceBuilding called for \(building.id) at tile (\(position.x), \(position.y))")

        // Debug: Check where the player is
        for entity in world.query(PositionComponent.self) {
            if let pos = world.get(PositionComponent.self, for: entity),
               let collision = world.get(CollisionComponent.self, for: entity),
               collision.layer == .player {
                print("GameLoop: Player found at tile (\(pos.tilePosition.x), \(pos.tilePosition.y))")
                break
            }
        }

        print("GameLoop: Checking \(building.width)x\(building.height) building tiles:")
        for dy in 0..<building.height {
            for dx in 0..<building.width {
                let checkPos = position + IntVector2(Int(dx), Int(dy))

                // Check if tile is buildable
                guard let tile = chunkManager.getTile(at: checkPos) else {
                    print("GameLoop: No tile found at (\(checkPos.x), \(checkPos.y))")
                    return false
                }
                guard tile.isBuildable else {
                    print("GameLoop: Tile at (\(checkPos.x), \(checkPos.y)) is not buildable")
                    return false
                }

                        print("GameLoop: Checking tile (\(checkPos.x), \(checkPos.y))")

                // Check if there's already a building here
                if world.hasEntityAt(position: checkPos) {
                    print("GameLoop: Entity found at tile (\(checkPos.x), \(checkPos.y))")
                    // Get the entity and check what it is
                    if let entity = world.getEntityAt(position: checkPos) {
                        print("GameLoop: Found entity \(entity.id) at tile (\(checkPos.x), \(checkPos.y))")

                        // Check if the entity has a collision component
                        if let collision = world.get(CollisionComponent.self, for: entity) {
                            print("GameLoop: Entity has collision layer: \(collision.layer), rawValue: \(collision.layer.rawValue)")
                            print("GameLoop: .player rawValue: \(CollisionLayer.player.rawValue)")
                            print("GameLoop: layer == .player: \(collision.layer == .player)")
                            if collision.layer == .player {
                                // Allow placement - ignore player
                                print("GameLoop: Allowing building placement over player at tile (\(checkPos.x), \(checkPos.y))")
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
                            print("GameLoop: Allowing belt placement over building at tile (\(checkPos.x), \(checkPos.y))")
                            continue
                        }
                    }

                    // Block placement on other entities
                    print("GameLoop: Blocking building placement due to entity at tile (\(checkPos.x), \(checkPos.y))")
                    print("GameLoop: canPlaceBuilding returning false")
                    return false
                }
            }
        }
        print("GameLoop: canPlaceBuilding returning true")
        return true
    }
    
    private func addBuildingComponents(entity: Entity, buildingDef: BuildingDefinition, position: IntVector2, direction: Direction) {
        // Add render component - belts should appear under buildings
        let renderLayer: RenderLayer = (buildingDef.type == .belt) ? .groundDecoration : .building
        world.add(SpriteComponent(
            textureId: buildingDef.textureId,
            size: Vector2(Float(buildingDef.width), Float(buildingDef.height)),
            layer: renderLayer
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
            world.add(InventoryComponent(slots: 1, filter: nil), to: entity)
            world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)
            
        case .furnace:
            world.add(FurnaceComponent(
                smeltingSpeed: buildingDef.craftingSpeed
            ), to: entity)
            // Furnace needs slots for: input ore, fuel, and output
            world.add(InventoryComponent(slots: 4, filter: nil), to: entity)
            
        case .assembler:
            world.add(AssemblerComponent(
                craftingSpeed: buildingDef.craftingSpeed,
                craftingCategory: buildingDef.craftingCategory
            ), to: entity)
            world.add(InventoryComponent(slots: 8, filter: nil), to: entity)
            world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)
            
        case .belt:
            world.add(BeltComponent(
                speed: buildingDef.beltSpeed,
                direction: direction
            ), to: entity)
            beltSystem.registerBelt(entity: entity, at: position, direction: direction)
            
        case .inserter:
            world.add(InserterComponent(
                speed: buildingDef.inserterSpeed,
                stackSize: buildingDef.inserterStackSize,
                direction: direction
            ), to: entity)
            world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)
            
        case .powerPole:
            world.add(PowerPoleComponent(
                wireReach: buildingDef.wireReach,
                supplyArea: buildingDef.supplyArea
            ), to: entity)
            
        case .generator:
            world.add(GeneratorComponent(
                powerOutput: buildingDef.powerProduction,
                fuelCategory: buildingDef.fuelCategory ?? "chemical"
            ), to: entity)
            world.add(InventoryComponent(slots: 1, filter: nil), to: entity)
            
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
            world.add(InventoryComponent(slots: 6, filter: ItemRegistry.sciencePackFilter), to: entity)
            world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)
            
        case .turret:
            world.add(TurretComponent(
                range: buildingDef.turretRange,
                damage: buildingDef.turretDamage,
                fireRate: buildingDef.turretFireRate
            ), to: entity)
            world.add(InventoryComponent(slots: 1, filter: ItemRegistry.ammoFilter), to: entity)
            
        case .wall:
            world.add(WallComponent(), to: entity)
            
        case .chest:
            world.add(ChestComponent(), to: entity)
            world.add(InventoryComponent(slots: buildingDef.inventorySlots, filter: nil), to: entity)
            
        case .pipe:
            world.add(PipeComponent(direction: direction), to: entity)
            
        case .pumpjack:
            world.add(PumpjackComponent(
                extractionRate: buildingDef.extractionRate
            ), to: entity)
            world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)
        }
    }
    
    func removeBuilding(at position: IntVector2) -> Bool {
        guard let entity = world.getEntityAt(position: position) else { return false }
        
        // Get items to return to player
        if let inventory = world.get(InventoryComponent.self, for: entity) {
            for stack in inventory.getAll() {
                player.inventory.add(stack)
            }
        }
        
        // Get building cost to return
        if let sprite = world.get(SpriteComponent.self, for: entity),
           let buildingDef = buildingRegistry.getByTexture(sprite.textureId) {
            for stack in buildingDef.cost {
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

