import Foundation
import QuartzCore

/// Main game loop that coordinates all game systems
@available(iOS 17.0, *)
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

    // Time controls for auto-play
    private(set) var gameSpeed: Double = 1.0  // 1.0 = normal speed

    private let miningSystem: MiningSystem
    let beltSystem: BeltSystem  // Internal access for save system to register belts after loading
    private let inserterSystem: InserterSystem
    private let craftingSystem: CraftingSystem
    private let powerSystem: PowerSystem
    let researchSystem: ResearchSystem // Public for UI access
    private let pollutionSystem: PollutionSystem
    private let enemyAISystem: EnemyAISystem
    private let combatSystem: CombatSystem
    let entityCleanupSystem: EntityCleanupSystem
    let autoPlaySystem: AutoPlaySystem
    let rocketSystem: RocketSystem
    
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

    // Chunks that have had trees spawned
    private var treeSpawnedChunks: Set<ChunkCoord> = []

    // Chunk loading optimization
    private var lastChunkUpdatePosition: Vector2 = .zero
    private let chunkUpdateThreshold: Float = 2.0  // Only update chunks if player moved more than 2 units

    // Performance profiling
    private var frameCount: Int = 0
    private var lastProfileTime: TimeInterval = 0
    private let profileInterval: TimeInterval = 5.0  // Profile every 5 seconds
    
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
        player = Player(world: world, itemRegistry: itemRegistry)

        // Initialize game systems
        miningSystem = MiningSystem(world: world, chunkManager: chunkManager, itemRegistry: itemRegistry)
        beltSystem = BeltSystem(world: world)
        inserterSystem = InserterSystem(world: world, beltSystem: beltSystem, itemRegistry: itemRegistry)
        craftingSystem = CraftingSystem(world: world, recipeRegistry: recipeRegistry, itemRegistry: itemRegistry)
        powerSystem = PowerSystem(world: world)
        researchSystem = ResearchSystem(world: world, technologyRegistry: technologyRegistry)
        pollutionSystem = PollutionSystem(world: world, chunkManager: chunkManager)
        enemyAISystem = EnemyAISystem(world: world, chunkManager: chunkManager, player: player)
        combatSystem = CombatSystem(world: world)
        combatSystem.setRenderer(renderer)
        entityCleanupSystem = EntityCleanupSystem(world: world, chunkManager: chunkManager)
        rocketSystem = RocketSystem(world: world, itemRegistry: itemRegistry)

        // Auto-play system for automated testing
        autoPlaySystem = AutoPlaySystem()

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
            combatSystem,
            rocketSystem,
            entityCleanupSystem,
            autoPlaySystem
        ]

        // Initialize save system
        saveSystem = SaveSystem()

        // Initialize UI
        uiSystem = UISystem(gameLoop: self, renderer: renderer)

        // Load registries from JSON
        loadGameData()
        
        // Note: Don't load chunks here - they will be loaded when:
        // 1. For saved games: After saveSystem.load() sets the save slot and loads chunks from disk
        // 2. For new games: When GameLoop.update() is first called (which calls chunkManager.update())
        // This prevents chunks from being regenerated before the save slot is set when loading a game

        // Set up auto-play system reference (after all properties are initialized)
        autoPlaySystem.setGameLoop(self)
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

        let realDeltaTime = Time.shared.deltaTime
        let gameSpeedFloat = Float(gameSpeed)
        let deltaTime = realDeltaTime * gameSpeedFloat

        playTime += Double(realDeltaTime)  // Track real time, not scaled time (no conversion needed)

        frameCount += 1

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

        // Update chunk loading based on player position (only if moved significantly)
        let playerPos = player.position
        let distanceMoved = (playerPos - lastChunkUpdatePosition).lengthSquared
        if distanceMoved > chunkUpdateThreshold * chunkUpdateThreshold {
            chunkManager.update(playerPosition: playerPos)
            lastChunkUpdatePosition = playerPos

            // Invalidate mining system cache when chunks change
            miningSystem.invalidateResourceCache()
        }

        // Fixed timestep updates for game systems (limit to prevent spiral of death)
        var fixedUpdateCount = 0
        let maxFixedUpdates = 5  // Maximum fixed updates per frame
        while Time.shared.consumeFixedUpdate() && fixedUpdateCount < maxFixedUpdates {
            for system in systems {
                system.update(deltaTime: Time.shared.fixedDeltaTime)
            }
            fixedUpdateCount += 1
        }

        // Update UI (skip if game is effectively paused to save performance)
        if gameSpeed > 0.01 {
            uiSystem?.update(deltaTime: deltaTime)
        }

        // Update renderer camera to follow player (only if not manually panning and player is alive)
        if !isPlayerDead {
            let shouldFollowPlayer = inputManager?.isDragging == false
            if shouldFollowPlayer {
                renderer?.camera.target = player.position
            }
        }
        renderer?.camera.update(deltaTime: deltaTime)

        // Call update callback
        onUpdate?()
    }

    // MARK: - Time Controls (Auto-Play)

    /// Set the game speed multiplier
    /// - Parameter speed: Speed multiplier (0.0 = paused, 1.0 = normal, 2.0 = 2x speed, etc.)
    func setGameSpeed(_ speed: Double) {
        gameSpeed = max(0.0, speed)  // Prevent negative speeds
        print("🎮 Game speed set to \(gameSpeed)x")
    }

    /// Pause the game (speed = 0)
    func pauseGame() {
        setGameSpeed(0.0)
    }

    /// Resume normal speed (speed = 1)
    func resumeGame() {
        setGameSpeed(1.0)
    }

    /// Speed up game by a multiplier
    func speedUp(by multiplier: Double = 2.0) {
        setGameSpeed(gameSpeed * multiplier)
    }

    /// Slow down game by a divisor
    func slowDown(by divisor: Double = 2.0) {
        setGameSpeed(gameSpeed / divisor)
    }

    // MARK: - Auto-Play Interface

    /// Start an auto-play scenario
    func startAutoPlayScenario(_ scenario: GameScenario) {
        autoPlaySystem.startScenario(scenario)
    }

    /// Stop auto-play
    func stopAutoPlay() {
        autoPlaySystem.stopAutoPlay()
    }

    /// Check if auto-play is currently active
    var isAutoPlaying: Bool {
        return autoPlaySystem.isAutoPlaying
    }

    /// Get the name of the current scenario
    var currentScenarioName: String? {
        return autoPlaySystem.currentScenarioName
    }

    // Input manager reference (set by GameViewController)
    weak var inputManager: InputManager?
    
    /// Spawn smoke particles for active buildings
    private func spawnBuildingSmoke(renderer: MetalRenderer) {
        // Check visible area to only spawn smoke for buildings that are on screen
        let visibleRect = renderer.camera.visibleRect

        // Stone furnaces - spawn smoke when smelting
        world.forEach(FurnaceComponent.self) { entity, furnace in
            guard let position = world.get(PositionComponent.self, for: entity)?.worldPosition else { return }
            guard visibleRect.contains(position) else { return }

            // Only spawn smoke for stone furnaces (burner furnaces)
            if let buildingDef = buildingRegistry.getByTexture(world.get(SpriteComponent.self, for: entity)?.textureId ?? ""),
               buildingDef.id == "stone-furnace",
               furnace.smeltingProgress > 0 {
                // Spawn smoke in the tile above the building center
                renderer.particleRenderer.spawnSmoke(at: position + Vector2(1, 1.5), count: 1)
            }
        }

        // Burner miners - spawn smoke when active
        world.forEach(MinerComponent.self) { entity, miner in
            guard let position = world.get(PositionComponent.self, for: entity)?.worldPosition else { return }
            guard visibleRect.contains(position) else { return }

            // Only spawn smoke for burner miners
            if let buildingDef = buildingRegistry.getByTexture(world.get(SpriteComponent.self, for: entity)?.textureId ?? ""),
               buildingDef.id == "burner-mining-drill",
               miner.isActive {
                // Spawn smoke in the tile above the building center
                renderer.particleRenderer.spawnMiningParticles(at: position + Vector2(1, 1.5), color: Color.black, count: 5)
            }
        }

        // Boilers - spawn smoke when generating power
        world.forEach(GeneratorComponent.self) { entity, generator in
            guard let position = world.get(PositionComponent.self, for: entity)?.worldPosition else { return }
            guard visibleRect.contains(position) else { return }

            // Only spawn smoke for boilers
            if let buildingDef = buildingRegistry.getByTexture(world.get(SpriteComponent.self, for: entity)?.textureId ?? ""),
               buildingDef.id == "boiler",
               generator.currentOutput > 0 {
                // Spawn smoke in the tile above the building center
                renderer.particleRenderer.spawnSmoke(at: position + Vector2(1, 2), count: 2)
            }
        }

        // Chemical plants - spawn smoke when crafting
        world.forEach(AssemblerComponent.self) { entity, assembler in
            guard let position = world.get(PositionComponent.self, for: entity)?.worldPosition else { return }
            guard visibleRect.contains(position) else { return }

            // Only spawn smoke for chemical plants
            if let buildingDef = buildingRegistry.getByTexture(world.get(SpriteComponent.self, for: entity)?.textureId ?? ""),
               buildingDef.id == "chemical-plant",
               assembler.craftingProgress > 0 {
                // Spawn smoke in the tile above the building center
                renderer.particleRenderer.spawnSmoke(at: position + Vector2(1, 2), count: 1)
            }
        }
    }

    /// Render the game state
    func render(renderer: MetalRenderer) {
        // Spawn smoke particles for active buildings
        spawnBuildingSmoke(renderer: renderer)

        // Render world tiles
        chunkManager.render(renderer: renderer, camera: renderer.camera)

        // Note: Entities (including player) are rendered by SpriteRenderer
        // which queries the world for PositionComponent + SpriteComponent

        // Note: Player entity is rendered by SpriteRenderer which queries world entities
        // The player sprite component is already in the world, so it will be rendered automatically

        // Note: UI is rendered by MetalRenderer before this call to allow loading menu to render first
    }
    
    // MARK: - Game Actions
    
    func placeInserter(_ buildingId: String, at position: IntVector2, direction: Direction, offset: Vector2 = .zero) -> Bool {
        print("GameLoop: placeInserter called - buildingId: \(buildingId), position: \(position)")
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

        // Add inserter-specific components
        addInserterComponents(entity: entity, buildingDef: buildingDef, type: .input) // Default to unified inserter behavior
        
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

        // For buildings that are placed as items, also consume the building item itself
        // (e.g., placing a stone-furnace consumes 1 stone-furnace item)
        var totalCost = buildingDef.cost
        if let itemDef = itemRegistry.get(buildingId),
           itemDef.placedAs == buildingId {
            // This building is placed as an item, so consume one of the item
            totalCost.append(ItemStack(itemId: buildingId, count: 1, maxStack: itemDef.stackSize))
        }

        // Check if player has all required items (including the building item)
        guard player.inventory.has(items: totalCost) else { return false }

        // Remove items from player inventory (must reassign since InventoryComponent is a struct)
        var playerInventory = player.inventory
        playerInventory.remove(items: totalCost)
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

    private func spawnTreesForLoadedChunks() {
        // Spawn trees for all currently loaded chunks that can support trees
        for chunk in chunkManager.allLoadedChunks {
            print("GameLoop: Init check chunk (\(chunk.coord.x), \(chunk.coord.y)) biome: \(chunk.biome)")
            let shouldSpawnTrees = chunk.biome != .volcanic
            if shouldSpawnTrees && !treeSpawnedChunks.contains(chunk.coord) {
                print("GameLoop: Spawning trees for initial chunk (\(chunk.coord.x), \(chunk.coord.y))")
                let _ = spawnTreesForChunk(chunk)
                treeSpawnedChunks.insert(chunk.coord)

                // Special case: spawn extra trees near player in chunk (0,0)
                if chunk.coord == ChunkCoord(x: 0, y: 0) {
                    spawnTreesNearPlayer(chunk)
                }
            }
        }
    }

    private func spawnTreesNearPlayer(_ chunk: Chunk) {
        let playerPos = world.get(PositionComponent.self, for: player.playerEntity)?.tilePosition ?? IntVector2(x: 0, y: 0)

        // Spawn trees in a small radius around the player
        let nearPlayerPositions = [
            IntVector2(x: playerPos.x + 3, y: playerPos.y + 3),
            IntVector2(x: playerPos.x - 3, y: playerPos.y + 3),
            IntVector2(x: playerPos.x + 3, y: playerPos.y - 3),
            IntVector2(x: playerPos.x - 3, y: playerPos.y - 3),
            IntVector2(x: playerPos.x + 5, y: playerPos.y),
            IntVector2(x: playerPos.x - 5, y: playerPos.y),
            IntVector2(x: playerPos.x, y: playerPos.y + 5),
            IntVector2(x: playerPos.x, y: playerPos.y - 5),
        ]

        for position in nearPlayerPositions {
            // Check if position is in this chunk and on grass
            let chunkOrigin = chunk.worldOrigin
            let localX = Int(position.x - chunkOrigin.x)
            let localY = Int(position.y - chunkOrigin.y)

            if localX >= 0 && localX < Chunk.size && localY >= 0 && localY < Chunk.size {
                if let tile = chunkManager.getTile(at: position), tile.type == .grass {
                    spawnTree(at: position)
                }
            }
        }
    }

    private func spawnTreesForNewChunks() -> Int {
        var totalTreesSpawned = 0
        // Check for newly loaded chunks that need trees
        for chunk in chunkManager.allLoadedChunks {
            // print("GameLoop: Checking chunk (\(chunk.coord.x), \(chunk.coord.y)) biome: \(chunk.biome)")
            // Spawn trees in biomes that can support trees (most biomes except volcanic)
            let shouldSpawnTrees = chunk.biome != .volcanic
            if shouldSpawnTrees && !treeSpawnedChunks.contains(chunk.coord) {
                let treesInChunk = spawnTreesForChunk(chunk)
                totalTreesSpawned += treesInChunk
                treeSpawnedChunks.insert(chunk.coord)
            }
        }
        return totalTreesSpawned
    }

    private func spawnTreesForChunk(_ chunk: Chunk) -> Int {
        let chunkOrigin = chunk.worldOrigin
        var treesSpawned = 0

        // Spawn trees randomly throughout the chunk
        let treeCount = chunk.biome == .forest ? 8 : 4  // More trees in forests, fewer elsewhere
        for _ in 0..<treeCount {
            let localX = Int.random(in: 0..<Chunk.size)
            let localY = Int.random(in: 0..<Chunk.size)

            let worldX = chunkOrigin.x + Int32(localX)
            let worldY = chunkOrigin.y + Int32(localY)
            let position = IntVector2(x: worldX, y: worldY)

            // Spawn on any tile in forest chunks (trees can grow on various terrain)
            if chunkManager.getTile(at: position) != nil {
                spawnTree(at: position)
                treesSpawned += 1
            }
        }
        return treesSpawned
    }


    private func spawnTree(at position: IntVector2) {
        let entity = world.spawn()

        // Position component
        world.add(PositionComponent(tilePosition: position, direction: .south, offset: .zero), to: entity)

        // Health component (trees can be damaged)
        world.add(HealthComponent(maxHealth: 50), to: entity)

        // Tree component (defines wood yield)
        world.add(TreeComponent(woodYield: 4), to: entity)

        // Sprite component for rendering
        world.add(SpriteComponent(textureId: "tree", size: Vector2(1, 1), layer: .entity, centered: true), to: entity)
    }

    func canPlaceBuilding(_ buildingId: String, at position: IntVector2, direction: Direction, ignoringEntity: Entity? = nil) -> Bool {
        guard let buildingDef = buildingRegistry.get(buildingId) else {
            return false
        }
        return canPlaceBuilding(buildingDef, at: position, ignoringEntity: ignoringEntity)
    }

    private func canPlaceBuilding(_ building: BuildingDefinition, at position: IntVector2, ignoringEntity: Entity? = nil) -> Bool {
        // Special case for mining drills: allow placement near trees
        if building.type == .miner {
            // Check for trees in an expanded area around the mining drill
            // This accounts for visual trees that might not be exactly on tile positions
            let searchRadius = 2  // Check 5x5 area (position ±2)

            for dy in -searchRadius...searchRadius {
                for dx in -searchRadius...searchRadius {
                    let checkPos = position + IntVector2(Int(dx), Int(dy))
                    let entitiesAtPos = world.getAllEntitiesAt(position: checkPos)
                    for entity in entitiesAtPos {
                        if world.has(TreeComponent.self, for: entity) {
                            let tree = world.get(TreeComponent.self, for: entity)!
                            // Only allow placement on trees that have wood left
                            if tree.woodYield > 0 {
                                return true
                            }
                        }
                    }
                }
            }
            // No trees found in the expanded search area
        }

        // Standard building placement validation
        for dy in 0..<building.height {
            for dx in 0..<building.width {
                let checkPos = position + IntVector2(Int(dx), Int(dy))

                // Check if tile exists and is buildable
                guard let tile = chunkManager.getTile(at: checkPos), tile.isBuildable else {
                    return false
                }

                // Check for conflicting entities at this position
                if world.hasEntityAt(position: checkPos) {
                    guard let entity = world.getEntityAt(position: checkPos) else {
                        continue  // Entity disappeared, allow placement
                    }

                    // Skip the entity we're ignoring (e.g., when moving buildings)
                    if let ignoringEntity = ignoringEntity, entity == ignoringEntity {
                        continue
                    }

                    // Allow placement on player (player can be walked over)
                    if let collision = world.get(CollisionComponent.self, for: entity),
                       collision.layer.contains(.player) {
                        continue
                    }

                    // Special placement rules for different building types
                    switch building.type {
                    case .belt:
                        // Belts can be placed on top of buildings
                        // Belt bridges can also be placed on top of belts and buildings
                        if building.id == "belt-bridge" {
                            continue  // Allow belt bridges over anything
                        }
                        continue

                    case .inserter, .powerPole:
                        // Inserters and poles are buildings, placeable on empty ground like other buildings
                        break

                    default:
                        break
                    }

                    // Block placement on other entities
                    return false
                }
            }
        }

        return true
    }

    /// Check if an entity is a building (furnace, assembler, etc.)
    private func isBuilding(_ entity: Entity) -> Bool {
        return world.has(FurnaceComponent.self, for: entity) ||
               world.has(AssemblerComponent.self, for: entity) ||
               world.has(MinerComponent.self, for: entity) ||
               world.has(GeneratorComponent.self, for: entity) ||
               world.has(ChestComponent.self, for: entity) ||
               world.has(LabComponent.self, for: entity) ||
               world.has(SolarPanelComponent.self, for: entity) ||
               world.has(AccumulatorComponent.self, for: entity)
    }
    
    private func addBuildingComponents(entity: Entity, buildingDef: BuildingDefinition, position: IntVector2, direction: Direction) {
        // Add render component - belts should appear above ground but below buildings
        // Belt bridges should appear elevated above other belts
        let renderLayer: RenderLayer
        if buildingDef.type == .belt && buildingDef.id == "belt-bridge" {
            renderLayer = .building  // Belt bridges appear above other belts
        } else if buildingDef.type == .belt {
            renderLayer = .groundDecoration
        } else {
            renderLayer = .building
        }
        // Belts and inserters should be centered on the tile where they're placed
        // This ensures they appear exactly where the user taps
        let isBelt = buildingDef.type == .belt
        let isInserter = buildingDef.type == .inserter

        // Use building dimensions for sprite size
        let spriteSize = Vector2(Float(buildingDef.width), Float(buildingDef.height))

        world.add(SpriteComponent(
            textureId: buildingDef.textureId,
            size: spriteSize,
            layer: renderLayer,
            centered: isBelt || isInserter
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
            // Furnace needs 2 input slots and 2 output slots (4 total)
            world.add(InventoryComponent(slots: 4, allowedItems: nil), to: entity)
            
        case .assembler:
            world.add(AssemblerComponent(
                craftingSpeed: buildingDef.craftingSpeed,
                craftingCategory: buildingDef.craftingCategory
            ), to: entity)
            world.add(InventoryComponent(slots: 8, allowedItems: nil), to: entity)
            world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)
            
        case .belt:
            // Determine belt type based on building ID
            let beltType: BeltType
            switch buildingDef.id {
            case "underground-belt":
                beltType = .underground
            case "splitter":
                beltType = .splitter
            case "merger":
                beltType = .merger
            case "belt-bridge":
                beltType = .bridge
            default:
                beltType = .normal
            }

            world.add(BeltComponent(
                speed: buildingDef.beltSpeed,
                direction: direction,
                type: beltType
            ), to: entity)

            // Add belt animation only for animated belt types (transport, fast, express)
            // Static belt buildings (merger, splitter, underground) keep their original textures
            if beltType == .normal, var sprite = world.get(SpriteComponent.self, for: entity) {
                // Create animation frames using north direction, cycling through 4 frames
                let beltFrames = (1...16).map { frameIndex in
                    let actualFrame = ((frameIndex - 1) % 4) + 1  // Cycle through frames 1-4
                    return "transport_belt_north_\(String(format: "%03d", actualFrame))"
                }
                let beltAnimation = SpriteAnimation(
                    frames: beltFrames,
                    frameTime: 0.1,  // 16 frames × 0.1s = 1.6 seconds per loop
                    isLooping: true
                )
                sprite.animation = beltAnimation
                sprite.textureId = beltFrames[0]  // Start with first frame
                world.add(sprite, to: entity)
            }

            beltSystem.registerBelt(entity: entity, at: position, direction: direction, type: beltType)
            
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
                extractionRate: buildingDef.extractionRate,
                resourceType: "crude-oil"
            ), to: entity)
            world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)
            world.add(InventoryComponent(slots: buildingDef.inventorySlots, allowedItems: nil), to: entity)

        case .waterPump:
            world.add(PumpjackComponent(
                extractionRate: buildingDef.extractionRate,
                resourceType: "water"
            ), to: entity)
            world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)
            world.add(InventoryComponent(slots: buildingDef.inventorySlots, allowedItems: nil), to: entity)

        case .oilRefinery:
            world.add(AssemblerComponent(craftingSpeed: buildingDef.craftingSpeed, craftingCategory: "oil-processing"), to: entity)
            world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)
            world.add(InventoryComponent(slots: buildingDef.inventorySlots, allowedItems: nil), to: entity)

        case .chemicalPlant:
            world.add(AssemblerComponent(craftingSpeed: buildingDef.craftingSpeed, craftingCategory: "chemistry"), to: entity)
            world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)
            world.add(InventoryComponent(slots: buildingDef.inventorySlots, allowedItems: nil), to: entity)

        case .rocketSilo:
            world.add(RocketSiloComponent(), to: entity)
            world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)
            world.add(InventoryComponent(slots: buildingDef.inventorySlots, allowedItems: nil), to: entity)

        case .centrifuge:
            world.add(AssemblerComponent(craftingSpeed: buildingDef.craftingSpeed, craftingCategory: "centrifuging"), to: entity)
            world.add(PowerConsumerComponent(consumption: buildingDef.powerConsumption), to: entity)
            world.add(InventoryComponent(slots: buildingDef.inventorySlots, allowedItems: nil), to: entity)

        case .nuclearReactor:
            world.add(GeneratorComponent(
                powerOutput: buildingDef.powerProduction,
                fuelCategory: buildingDef.fuelCategory ?? "nuclear"
            ), to: entity)
            world.add(InventoryComponent(slots: 1, allowedItems: ["uranium-fuel-cell"]), to: entity)
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
        guard var belt = world.get(BeltComponent.self, for: entity) else {
            return false
        }

        // Rotate direction clockwise
        let newDirection = belt.direction.clockwise
        belt.direction = newDirection

        // Update belt component
        world.add(belt, to: entity)

        // Update belt system with new direction
        beltSystem.updateBeltDirection(entity: entity, newDirection: newDirection)

        // Update sprite animation/texture based on belt type
        if var sprite = world.get(SpriteComponent.self, for: entity) {
            if belt.type == .normal {
                // Transport belts: use animated frames
                let beltFrames = (1...16).map { frameIndex in
                    let actualFrame = ((frameIndex - 1) % 4) + 1  // Cycle through frames 1-4
                    return "transport_belt_north_\(String(format: "%03d", actualFrame))"
                }
                let beltAnimation = SpriteAnimation(
                    frames: beltFrames,
                    frameTime: 0.1,  // 16 frames × 0.1s = 1.6 seconds per loop
                    isLooping: true
                )
                sprite.animation = beltAnimation
                sprite.textureId = beltFrames[0]  // Start with first frame
            } else {
                // Splitters, mergers, underground belts: keep original static texture
                // Just ensure the textureId matches the belt type
                switch belt.type {
                case .splitter:
                    sprite.textureId = "splitter"
                case .merger:
                    sprite.textureId = "merger"
                case .underground:
                    sprite.textureId = "underground_belt"
                case .bridge:
                    sprite.textureId = "belt_bridge"
                default:
                    break
                }
                // Remove any animation for static belt types
                sprite.animation = nil
            }
            world.add(sprite, to: entity)
        } else {
            print("⚠️ No sprite component found for belt entity during rotation")
        }

        return true
    }
    
    func setInserterConnection(entity: Entity, inputTarget: Entity? = nil, inputPosition: IntVector2? = nil, outputTarget: Entity? = nil, outputPosition: IntVector2? = nil, clearInput: Bool = false, clearOutput: Bool = false) -> Bool {
        guard var inserter = world.get(InserterComponent.self, for: entity),
              let inserterPos = world.get(PositionComponent.self, for: entity) else {
            return false
        }
        
        // Handle explicit clearing
        if clearInput {
            inserter.inputTarget = nil
            inserter.inputPosition = nil
        }
        // Only update input if inputTarget or inputPosition is provided (and not explicitly clearing)
        else if inputTarget != nil || inputPosition != nil {
            if let inputTarget = inputTarget {
                guard world.isAlive(inputTarget) else { return false }
                if let targetPos = world.get(PositionComponent.self, for: inputTarget) {
                    let targetOrigin = targetPos.tilePosition
                    let inserterTile = inserterPos.tilePosition
                    
                    // Get entity size for multi-tile entities
                    let sprite = world.get(SpriteComponent.self, for: inputTarget)
                    let width = sprite != nil ? Int32(ceil(sprite!.size.x)) : 1
                    let height = sprite != nil ? Int32(ceil(sprite!.size.y)) : 1
                    
                    // Check if ANY tile of the target entity is within 1 tile of the inserter
                    var isWithinRange = false
                    for y in targetOrigin.y..<(targetOrigin.y + height) {
                        for x in targetOrigin.x..<(targetOrigin.x + width) {
                            let targetTile = IntVector2(x: x, y: y)
                            let distance = abs(targetTile.x - inserterTile.x) + abs(targetTile.y - inserterTile.y)
                            if distance <= 2 {
                                isWithinRange = true
                                break
                            }
                        }
                        if isWithinRange { break }
                    }
                    
                    guard isWithinRange else { return false }
                }
                inserter.inputTarget = inputTarget
                inserter.inputPosition = nil // Clear position if setting entity
            } else if let inputPosition = inputPosition {
                let distance = abs(inputPosition.x - inserterPos.tilePosition.x) + abs(inputPosition.y - inserterPos.tilePosition.y)
                guard distance <= 2 else { return false }

                // Validate that there's actually a belt at the input position
                let entitiesAtPos = world.getAllEntitiesAt(position: inputPosition)
                let hasBelt = entitiesAtPos.contains { world.has(BeltComponent.self, for: $0) }
                guard hasBelt else { return false }

                inserter.inputPosition = inputPosition
                inserter.inputTarget = nil // Clear entity if setting position
            }
        }
        
        // Handle explicit clearing
        if clearOutput {
            inserter.outputTarget = nil
            inserter.outputPosition = nil
        }
        // Only update output if outputTarget or outputPosition is provided (and not explicitly clearing)
        else if outputTarget != nil || outputPosition != nil {
            if let outputTarget = outputTarget {
                guard world.isAlive(outputTarget) else { return false }
                if let targetPos = world.get(PositionComponent.self, for: outputTarget) {
                    let targetOrigin = targetPos.tilePosition
                    let inserterTile = inserterPos.tilePosition
                    
                    // Get entity size for multi-tile entities
                    let sprite = world.get(SpriteComponent.self, for: outputTarget)
                    let width = sprite != nil ? Int32(ceil(sprite!.size.x)) : 1
                    let height = sprite != nil ? Int32(ceil(sprite!.size.y)) : 1
                    
                    // Check if ANY tile of the target entity is within 1 tile of the inserter
                    var isWithinRange = false
                    for y in targetOrigin.y..<(targetOrigin.y + height) {
                        for x in targetOrigin.x..<(targetOrigin.x + width) {
                            let targetTile = IntVector2(x: x, y: y)
                            let distance = abs(targetTile.x - inserterTile.x) + abs(targetTile.y - inserterTile.y)
                            if distance <= 2 {
                                isWithinRange = true
                                break
                            }
                        }
                        if isWithinRange { break }
                    }
                    
                    guard isWithinRange else { return false }
                }
                inserter.outputTarget = outputTarget
                inserter.outputPosition = nil // Clear position if setting entity
            } else if let outputPosition = outputPosition {
                let distance = abs(outputPosition.x - inserterPos.tilePosition.x) + abs(outputPosition.y - inserterPos.tilePosition.y)
                guard distance <= 2 else { return false }

                // Validate that there's actually a belt at the output position
                let entitiesAtPos = world.getAllEntitiesAt(position: outputPosition)
                let hasBelt = entitiesAtPos.contains { world.has(BeltComponent.self, for: $0) }
                guard hasBelt else { return false }

                inserter.outputPosition = outputPosition
                inserter.outputTarget = nil // Clear entity if setting position
            }
        }
        
        world.add(inserter, to: entity)
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
        if let autosaveSlot = saveSystem.currentAutosaveSlot {
            saveSystem.save(gameLoop: self, slotName: autosaveSlot)
        } else {
            print("GameLoop: No autosave slot set, cannot save")
        }
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

    // MARK: - IAP Integration

    /// Adds items to the player's inventory (used for IAP deliveries)
    func addItemToInventory(itemId: String, quantity: Int) {
        if let itemDef = itemRegistry.get(itemId) {
            player.inventory.add(itemId: itemId, count: quantity, maxStack: itemDef.stackSize)
        }
    }
}

