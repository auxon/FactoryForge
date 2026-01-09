import Foundation

/// Manages game save/load functionality
final class SaveSystem {
    private let saveDirectory: URL?
    private let autosaveInterval: TimeInterval = 300  // 5 minutes
    private var lastAutosaveTime: TimeInterval = 0
    private var displayNames: [String: String] = [:] // Maps slot name to display name
    var currentAutosaveSlot: String? // Current game's autosave slot name
    
    init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if let documentsDir = paths.first {
            saveDirectory = documentsDir.appendingPathComponent("saves")
            try? FileManager.default.createDirectory(at: saveDirectory!, withIntermediateDirectories: true)
            loadDisplayNames()
        } else {
            saveDirectory = nil
        }
    }
    
    // MARK: - Save
    
    func save(gameLoop: GameLoop, slotName: String) {
        // Set the save slot in chunk manager so chunks are saved to the correct directory
        gameLoop.chunkManager.setSaveSlot(slotName)
        
        // Save all loaded chunks to disk before saving the game state
        gameLoop.chunkManager.saveAllChunks()
        
        let saveData = createSaveData(from: gameLoop)
        
        guard let directory = saveDirectory else {
            print("Save directory not available")
            return
        }
        
        let saveURL = directory.appendingPathComponent("\(slotName).json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(saveData)
            try data.write(to: saveURL)
            print("Game saved to \(saveURL)")
        } catch {
            print("Failed to save game: \(error)")
        }
    }
    
    private func createSaveData(from gameLoop: GameLoop) -> GameSave {
        return GameSave(
            version: 1,
            seed: gameLoop.chunkManager.seed,
            playTime: gameLoop.playTime,
            playerData: gameLoop.player.getState(),
            worldData: gameLoop.world.serialize(),
            researchData: (findResearchSystem(in: gameLoop))?.getState() ?? ResearchState(currentResearchId: nil, progress: [:], completed: [], unlockedRecipes: []),
            timestamp: Date()
        )
    }
    
    private func findResearchSystem(in gameLoop: GameLoop) -> ResearchSystem? {
        return gameLoop.researchSystem
    }
    
    // MARK: - Load
    
    func load(saveData: GameSave, into gameLoop: GameLoop, slotName: String? = nil) {
        // Update ChunkManager seed FIRST, before loading any chunks
        // This ensures chunks are generated/loaded with the correct seed
        if saveData.seed != gameLoop.chunkManager.seed {
            gameLoop.chunkManager.updateSeed(saveData.seed)
        }
        
        // Set the save slot in chunk manager so chunks are loaded from the correct directory
        if let slotName = slotName {
            gameLoop.chunkManager.setSaveSlot(slotName)
            print("SaveSystem: Loading chunks from slot: \(slotName)")
        }
        
        // Clear all loaded chunks so they will be loaded fresh from disk
        // Don't save dirty chunks - they may have been incorrectly regenerated before the save slot was set
        // This prevents overwriting the correct saved chunks with incorrectly generated ones
        gameLoop.chunkManager.clearLoadedChunks(saveDirty: false)
        
        // Load world state FIRST (this clears the world, including the player's entity)
        gameLoop.world.deserialize(saveData.worldData)

        // Trees are now spawned automatically for forest chunks when loaded
        // No need to spawn initial trees here
        
        // Remove any player entity that might have been deserialized from the world
        // (the player entity is managed separately by the Player class)
        removePlayerEntityFromWorld(gameLoop.world)
        
        // Recreate the player entity (since it was cleared during deserialize)
        recreatePlayerEntity(gameLoop.player, in: gameLoop.world)
        
        // Load player state (position, inventory, health)
        gameLoop.player.loadState(saveData.playerData)
        
        // IMPORTANT: Force load chunks around player position immediately after loading entities
        // This ensures saved chunks are loaded from disk before any updates can regenerate them
        // Use forceLoadChunksAround to ensure we load from disk, not regenerate
        gameLoop.chunkManager.forceLoadChunksAround(position: gameLoop.player.position)
        
        // Also ensure chunks around all entity positions are loaded
        // Collect entity positions and load chunks for each
        var chunksNeeded: Set<ChunkCoord> = []
        for entity in gameLoop.world.entities {
            if let position = gameLoop.world.get(PositionComponent.self, for: entity) {
                let chunkCoord = Chunk.worldToChunk(position.tilePosition)
                // Add surrounding chunks too
                for dy in -1...1 {
                    for dx in -1...1 {
                        chunksNeeded.insert(ChunkCoord(x: chunkCoord.x + Int32(dx), y: chunkCoord.y + Int32(dy)))
                    }
                }
            }
        }
        
        // Load any missing chunks
        for coord in chunksNeeded {
            if gameLoop.chunkManager.getChunkByCoord(coord) == nil {
                // Force load by calling update with a position in that chunk
                let worldPos = Vector2(
                    x: Float(coord.x * Int32(Chunk.size)) + Float(Chunk.size / 2),
                    y: Float(coord.y * Int32(Chunk.size)) + Float(Chunk.size / 2)
                )
                gameLoop.chunkManager.forceLoadChunksAround(position: worldPos)
            }
        }
        
        // Load research state
        gameLoop.researchSystem.loadState(saveData.researchData)
        
        // Register all belts in BeltSystem after deserialization
        // Belts are loaded from save but not automatically registered in the belt system's internal graph
        registerAllBelts(in: gameLoop)
        
        // Load play time
        gameLoop.playTime = saveData.playTime
        
        print("Game loaded from save")
    }
    
    /// Registers all belt entities in the BeltSystem after loading a saved game
    private func registerAllBelts(in gameLoop: GameLoop) {
        var beltCount = 0
        for entity in gameLoop.world.entities {
            if let position = gameLoop.world.get(PositionComponent.self, for: entity),
               let belt = gameLoop.world.get(BeltComponent.self, for: entity) {
                gameLoop.beltSystem.registerBelt(entity: entity, at: position.tilePosition, direction: belt.direction)
                beltCount += 1
            }
        }
        print("SaveSystem: Registered \(beltCount) belts after loading save")
    }
    
    private func removePlayerEntityFromWorld(_ world: World) {
        // Find and remove any entity with player sprite or player collision layer
        // (they shouldn't be in world saves - player is managed separately)
        var entitiesToRemove: [Entity] = []
        for entity in world.entities {
            var isPlayer = false
            
            // Check by collision layer (most reliable)
            if let collision = world.get(CollisionComponent.self, for: entity),
               collision.layer == .player {
                isPlayer = true
            }
            
            // Also check by sprite texture (for old saves that might not have collision component)
            if let sprite = world.get(SpriteComponent.self, for: entity),
               sprite.textureId.hasPrefix("player") {
                isPlayer = true
            }
            
            if isPlayer {
                entitiesToRemove.append(entity)
            }
        }
        
        // Remove all player entities
        for entity in entitiesToRemove {
            world.despawn(entity)
        }
        
        if !entitiesToRemove.isEmpty {
            print("Removed \(entitiesToRemove.count) player entity/entities from loaded world")
        }
    }
    
    private func recreatePlayerEntity(_ player: Player, in world: World) {
        // Use reflection or a public method to recreate the player entity
        // For now, we'll need to add a method to Player to recreate its entity
        player.recreateEntity(in: world)
    }
    
    func loadFromSlot(_ slotName: String) -> GameSave? {
        guard let directory = saveDirectory else { return nil }
        
        let saveURL = directory.appendingPathComponent("\(slotName).json")
        
        do {
            let data = try Data(contentsOf: saveURL)
            let decoder = JSONDecoder()
            return try decoder.decode(GameSave.self, from: data)
        } catch {
            print("Failed to load save: \(error)")
            return nil
        }
    }
    
    // MARK: - Autosave

    func checkAutosave(gameLoop: GameLoop) {
        guard let autosaveSlot = currentAutosaveSlot else {
            print("SaveSystem: No autosave slot set, skipping autosave")
            return
        }

        let currentTime = gameLoop.playTime

        if currentTime - lastAutosaveTime >= autosaveInterval {
            save(gameLoop: gameLoop, slotName: autosaveSlot)
            lastAutosaveTime = currentTime
            print("SaveSystem: Autosaved to slot: \(autosaveSlot)")
        }
    }
    
    // MARK: - Save Slots
    
    func getSaveSlots() -> [SaveSlotInfo] {
        // Reload display names to ensure we have the latest changes
        loadDisplayNames()

        guard let directory = saveDirectory else { return [] }

        var slots: [SaveSlotInfo] = []

        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])

            for file in files where file.pathExtension == "json" {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                let modDate = attributes[.modificationDate] as? Date ?? Date()

                // Try to read save info
                if let data = try? Data(contentsOf: file),
                   let save = try? JSONDecoder().decode(GameSave.self, from: data) {
                    let slotName = file.deletingPathExtension().lastPathComponent
                    let displayName = displayNames[slotName]
                    slots.append(SaveSlotInfo(
                        name: slotName,
                        displayName: displayName,
                        playTime: save.playTime,
                        timestamp: save.timestamp,
                        modificationDate: modDate
                    ))
                }
            }
        } catch {
            print("Failed to list saves: \(error)")
        }

        return slots.sorted { $0.modificationDate > $1.modificationDate }
    }
    
    func deleteSave(_ slotName: String) {
        guard let directory = saveDirectory else { return }

        let saveURL = directory.appendingPathComponent("\(slotName).json")
        try? FileManager.default.removeItem(at: saveURL)

        // Remove display name
        displayNames.removeValue(forKey: slotName)
        saveDisplayNames()
    }

    func setDisplayName(_ displayName: String, for slotName: String) {
        displayNames[slotName] = displayName
        saveDisplayNames()
    }

    /// Starts a new game session with a unique autosave slot
    func startNewGameSession() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        currentAutosaveSlot = "autosave_\(timestamp)"
        lastAutosaveTime = 0 // Reset autosave timer for new game
    }

    /// Sets the autosave slot for loading an existing game
    func setAutosaveSlot(_ slotName: String) {
        currentAutosaveSlot = slotName
        lastAutosaveTime = 0 // Reset autosave timer
    }

    private func loadDisplayNames() {
        guard let directory = saveDirectory else { return }

        let displayNamesURL = directory.appendingPathComponent("display_names.json")

        do {
            let data = try Data(contentsOf: displayNamesURL)
            displayNames = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            // File doesn't exist or couldn't be read, start with empty dictionary
            displayNames = [:]
        }
    }

    private func saveDisplayNames() {
        guard let directory = saveDirectory else { return }

        let displayNamesURL = directory.appendingPathComponent("display_names.json")

        do {
            let data = try JSONEncoder().encode(displayNames)
            try data.write(to: displayNamesURL)
        } catch {
            print("Failed to save display names: \(error)")
        }
    }
}

// MARK: - Save Data Structures

struct GameSave: Codable {
    let version: Int
    let seed: UInt64
    let playTime: TimeInterval
    let playerData: PlayerState
    let worldData: WorldData
    let researchData: ResearchState
    let timestamp: Date
}

struct SaveSlotInfo {
    let name: String
    let displayName: String? // Custom display name, falls back to filename if nil
    let playTime: TimeInterval
    let timestamp: Date
    let modificationDate: Date

    var formattedPlayTime: String {
        let hours = Int(playTime) / 3600
        let minutes = (Int(playTime) % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }

    var effectiveDisplayName: String {
        return displayName ?? name
    }
}

