import Foundation

/// Manages game save/load functionality
final class SaveSystem {
    private let saveDirectory: URL?
    private let autosaveInterval: TimeInterval = 300  // 5 minutes
    private var lastAutosaveTime: TimeInterval = 0
    
    init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if let documentsDir = paths.first {
            saveDirectory = documentsDir.appendingPathComponent("saves")
            try? FileManager.default.createDirectory(at: saveDirectory!, withIntermediateDirectories: true)
        } else {
            saveDirectory = nil
        }
    }
    
    // MARK: - Save
    
    func save(gameLoop: GameLoop, slotName: String = "autosave") {
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
    
    func load(saveData: GameSave, into gameLoop: GameLoop) {
        // Load world state FIRST (this clears the world, including the player's entity)
        gameLoop.world.deserialize(saveData.worldData)
        
        // Remove any player entity that might have been deserialized from the world
        // (the player entity is managed separately by the Player class)
        removePlayerEntityFromWorld(gameLoop.world)
        
        // Recreate the player entity (since it was cleared during deserialize)
        recreatePlayerEntity(gameLoop.player, in: gameLoop.world)
        
        // Load player state (position, inventory, health)
        gameLoop.player.loadState(saveData.playerData)
        
        // Load research state
        gameLoop.researchSystem.loadState(saveData.researchData)
        
        // Load play time
        gameLoop.playTime = saveData.playTime
        
        print("Game loaded from save")
    }
    
    private func removePlayerEntityFromWorld(_ world: World) {
        // Find and remove any entity with player collision layer (they shouldn't be in world saves)
        var entitiesToRemove: [Entity] = []
        for entity in world.entities {
            if let collision = world.get(CollisionComponent.self, for: entity),
               collision.layer == .player {
                entitiesToRemove.append(entity)
            }
        }
        for entity in entitiesToRemove {
            world.despawn(entity)
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
        let currentTime = gameLoop.playTime
        
        if currentTime - lastAutosaveTime >= autosaveInterval {
            save(gameLoop: gameLoop, slotName: "autosave")
            lastAutosaveTime = currentTime
        }
    }
    
    // MARK: - Save Slots
    
    func getSaveSlots() -> [SaveSlotInfo] {
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
                    slots.append(SaveSlotInfo(
                        name: file.deletingPathExtension().lastPathComponent,
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
    let playTime: TimeInterval
    let timestamp: Date
    let modificationDate: Date
    
    var formattedPlayTime: String {
        let hours = Int(playTime) / 3600
        let minutes = (Int(playTime) % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }
}

