import Foundation

/// System that handles pollution generation and spread
final class PollutionSystem: System {
    let priority = SystemPriority.pollution.rawValue

    private let world: World
    private let chunkManager: ChunkManager

    /// Pollution generation rates by building type
    private let pollutionRates: [String: Float] = [
        "burner-mining-drill": 10,
        "stone-furnace": 2,
        "steel-furnace": 4,
        "electric-furnace": 1,
        "boiler": 30,
        "assembling-machine-1": 4,
        "assembling-machine-2": 3,
        "assembling-machine-3": 2
    ]

    /// Cache of entities that produce pollution (updated periodically)
    private var pollutionEntities: [Entity] = []
    private var lastCacheUpdate: TimeInterval = 0
    private let cacheUpdateInterval: TimeInterval = 1.0  // Update cache every second
    
    init(world: World, chunkManager: ChunkManager) {
        self.world = world
        self.chunkManager = chunkManager
    }
    
    func update(deltaTime: Float) {
        // Update pollution entity cache periodically
        let currentTime = Time.shared.totalTime
        if Double(currentTime) - lastCacheUpdate > cacheUpdateInterval {
            updatePollutionEntityCache()
            lastCacheUpdate = Double(currentTime)
        }

        // Generate pollution from buildings
        generatePollution(deltaTime: deltaTime)

        // Spread pollution between chunks
        chunkManager.spreadPollution(deltaTime: deltaTime)
    }
    
    private func updatePollutionEntityCache() {
        pollutionEntities = []
        // Query entities that produce pollution (only buildings with pollution rates)
        for entity in world.query(PositionComponent.self, SpriteComponent.self) {
            guard let sprite = world.get(SpriteComponent.self, for: entity) else { continue }
            // Only cache entities that actually produce pollution
            if pollutionRates[sprite.textureId] != nil {
                pollutionEntities.append(entity)
            }
        }
    }

    private func generatePollution(deltaTime: Float) {
        // Use cached pollution entities instead of querying all entities
        for entity in pollutionEntities {
            guard let position = world.get(PositionComponent.self, for: entity),
                  let sprite = world.get(SpriteComponent.self, for: entity) else { continue }

            // Get pollution rate for this building type
            let pollutionRate = pollutionRates[sprite.textureId] ?? 0
            guard pollutionRate > 0 else { continue }

            // Check if building is active (has power or fuel)
            var isActive = true

            if let power = world.get(PowerConsumerComponent.self, for: entity) {
                isActive = power.satisfaction > 0
            }

            if let miner = world.get(MinerComponent.self, for: entity) {
                isActive = miner.isActive && miner.progress > 0
            }

            if let furnace = world.get(FurnaceComponent.self, for: entity) {
                isActive = furnace.smeltingProgress > 0
            }

            if let assembler = world.get(AssemblerComponent.self, for: entity) {
                isActive = assembler.craftingProgress > 0
            }

            if isActive {
                let pollutionAmount = pollutionRate * deltaTime / 60.0  // Per minute rate
                chunkManager.addPollution(at: position.tilePosition, amount: pollutionAmount)
            }
        }
    }
    
    /// Gets the pollution level at a world position
    func getPollution(at position: IntVector2) -> Float {
        return chunkManager.getPollution(at: position)
    }
    
    /// Gets the total pollution in the world
    func getTotalPollution() -> Float {
        var total: Float = 0
        for chunk in chunkManager.allLoadedChunks {
            total += chunk.pollution
        }
        return total
    }
}

