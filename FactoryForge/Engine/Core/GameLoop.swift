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
    private let researchSystem: ResearchSystem
    private let pollutionSystem: PollutionSystem
    private let enemyAISystem: EnemyAISystem
    private let combatSystem: CombatSystem
    
    // Player
    let player: Player
    
    // UI state
    var uiSystem: UISystem?
    
    // Save system
    let saveSystem: SaveSystem
    
    // Rendering reference
    weak var renderer: MetalRenderer?
    
    // State
    private(set) var isRunning: Bool = true
    private(set) var playTime: TimeInterval = 0
    
    init(renderer: MetalRenderer) {
        self.renderer = renderer
        
        // Initialize registries
        itemRegistry = ItemRegistry()
        recipeRegistry = RecipeRegistry(itemRegistry: itemRegistry)
        buildingRegistry = BuildingRegistry()
        technologyRegistry = TechnologyRegistry()
        
        // Initialize world
        world = World()
        chunkManager = ChunkManager(seed: UInt64.random(in: 0...UInt64.max))
        
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
        
        // Update renderer camera to follow player
        renderer?.camera.target = player.position
        renderer?.camera.update(deltaTime: deltaTime)
    }
    
    /// Render the game state
    func render(renderer: MetalRenderer) {
        // Render world tiles
        chunkManager.render(renderer: renderer, camera: renderer.camera)
        
        // Render all entities
        world.render(renderer: renderer)
        
        // Render player
        player.render(renderer: renderer)
        
        // Render UI
        uiSystem?.render(renderer: renderer)
    }
    
    // MARK: - Game Actions
    
    func placeBuilding(_ buildingId: String, at position: IntVector2, direction: Direction) -> Bool {
        guard let buildingDef = buildingRegistry.get(buildingId) else { return false }
        guard canPlaceBuilding(buildingDef, at: position) else { return false }
        
        // Check if player has required items
        guard player.inventory.has(items: buildingDef.cost) else { return false }
        
        // Remove items from player inventory
        player.inventory.remove(items: buildingDef.cost)
        
        // Create the building entity
        let entity = world.spawn()
        
        // Add position component
        world.add(PositionComponent(tilePosition: position, direction: direction), to: entity)
        
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
    
    private func canPlaceBuilding(_ building: BuildingDefinition, at position: IntVector2) -> Bool {
        for dy in 0..<building.height {
            for dx in 0..<building.width {
                let checkPos = position + IntVector2(Int(dx), Int(dy))
                
                // Check if tile is buildable
                guard let tile = chunkManager.getTile(at: checkPos) else { return false }
                guard tile.isBuildable else { return false }
                
                // Check if there's already a building here
                if world.hasEntityAt(position: checkPos) {
                    return false
                }
            }
        }
        return true
    }
    
    private func addBuildingComponents(entity: Entity, buildingDef: BuildingDefinition, position: IntVector2, direction: Direction) {
        // Add render component
        world.add(SpriteComponent(
            textureId: buildingDef.textureId,
            size: Vector2(Float(buildingDef.width), Float(buildingDef.height)),
            layer: .building
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
            world.add(InventoryComponent(slots: 2, filter: nil), to: entity)
            
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

