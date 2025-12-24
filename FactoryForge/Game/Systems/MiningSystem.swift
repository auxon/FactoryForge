import Foundation

/// System that handles mining drills extracting resources
final class MiningSystem: System {
    let priority = SystemPriority.mining.rawValue
    
    private let world: World
    private let chunkManager: ChunkManager
    
    init(world: World, chunkManager: ChunkManager) {
        self.world = world
        self.chunkManager = chunkManager
    }
    
    func update(deltaTime: Float) {
        world.forEach(MinerComponent.self) { [self] entity, miner in
            guard miner.isActive else { return }
            guard let position = world.get(PositionComponent.self, for: entity) else { return }
            guard var inventory = world.get(InventoryComponent.self, for: entity) else { return }
            
            // Check power for electric miners
            var speedMultiplier: Float = 1.0
            if let power = world.get(PowerConsumerComponent.self, for: entity) {
                speedMultiplier = power.satisfaction
                if speedMultiplier <= 0 { return }
            }
            
            // Find resource at miner position
            guard let resource = findResource(at: position.tilePosition) else {
                miner.isActive = false
                return
            }
            
            miner.resourceOutput = resource.type.outputItem
            
            // Check if output inventory has space
            guard inventory.canAccept(itemId: resource.type.outputItem) else { return }
            
            // Progress mining
            let miningTime = 1.0 / (miner.miningSpeed * resource.richness * speedMultiplier)
            miner.progress += deltaTime / miningTime
            
            // Complete mining
            if miner.progress >= 1.0 {
                miner.progress = 0
                
                // Extract from resource
                let mined = chunkManager.mineResource(at: position.tilePosition)
                if mined > 0 {
                    // Add to output inventory
                    inventory.add(itemId: resource.type.outputItem, count: 1)
                    world.add(inventory, to: entity)
                }
            }
        }
    }
    
    private func findResource(at position: IntVector2) -> ResourceDeposit? {
        // Check the tile and surrounding tiles for resource
        for dy in -1...1 {
            for dx in -1...1 {
                let checkPos = IntVector2(x: position.x + Int32(dx), y: position.y + Int32(dy))
                if let resource = chunkManager.getResource(at: checkPos), !resource.isEmpty {
                    return resource
                }
            }
        }
        return nil
    }
}

