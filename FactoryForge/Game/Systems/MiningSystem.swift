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
        // Collect all modifications to apply after iteration
        var minerModifications: [(Entity, MinerComponent)] = []
        var inventoryModifications: [(Entity, InventoryComponent)] = []
        
        world.forEach(MinerComponent.self) { [self] entity, miner in
            guard let position = world.get(PositionComponent.self, for: entity) else { return }
            guard var inventory = world.get(InventoryComponent.self, for: entity) else { return }
            
            var updatedMiner = miner
            
            // Handle fuel consumption for burner miners
            let isBurnerMiner = world.get(PowerConsumerComponent.self, for: entity) == nil
            var hasFuel = true
            
            if isBurnerMiner {
                // Burner miner - check current fuel status
                hasFuel = updatedMiner.fuelRemaining > 0
                
                // If we're active but no fuel, try to consume fuel
                if updatedMiner.isActive && !hasFuel {
                    if consumeFuel(inventory: &inventory, miner: &updatedMiner) {
                        hasFuel = true
                        inventoryModifications.append((entity, inventory))
                    } else {
                        // No fuel available, deactivate miner
                        updatedMiner.isActive = false
                        minerModifications.append((entity, updatedMiner))
                        return
                    }
                }
                
                // Decrement fuel only when actively mining
                // 25% slower fuel consumption: multiply deltaTime by 0.75
                if hasFuel && updatedMiner.isActive {
                    updatedMiner.fuelRemaining -= deltaTime * 0.75
                    // If fuel runs out, deactivate
                    if updatedMiner.fuelRemaining <= 0 {
                        updatedMiner.fuelRemaining = 0
                        updatedMiner.isActive = false
                    }
                }
                
                // Only process if we have fuel
                if !hasFuel {
                    updatedMiner.isActive = false
                    minerModifications.append((entity, updatedMiner))
                    return
                }
            } else {
                // Electric miner - check power
                if let power = world.get(PowerConsumerComponent.self, for: entity) {
                    if power.satisfaction <= 0 {
                        updatedMiner.isActive = false
                        minerModifications.append((entity, updatedMiner))
                        return
                    }
                }
            }
            
            guard updatedMiner.isActive else {
                minerModifications.append((entity, updatedMiner))
                return
            }
            
            // Find resource at miner position
            guard let resource = findResource(at: position.tilePosition) else {
                updatedMiner.isActive = false
                minerModifications.append((entity, updatedMiner))
                return
            }
            
            updatedMiner.isActive = true  // Ensure it's active if resource found
            updatedMiner.resourceOutput = resource.type.outputItem
            
            // Check if output inventory has space
            guard inventory.canAccept(itemId: resource.type.outputItem) else { 
                minerModifications.append((entity, updatedMiner))
                return 
            }
            
            // Calculate speed multiplier (power satisfaction for electric miners, 1.0 for burner miners)
            var speedMultiplier: Float = 1.0
            if let power = world.get(PowerConsumerComponent.self, for: entity) {
                speedMultiplier = power.satisfaction
            }
            
            // Progress mining
            let miningTime = 1.0 / (updatedMiner.miningSpeed * resource.richness * speedMultiplier)
            updatedMiner.progress += deltaTime / miningTime
            
            // Complete mining
            if updatedMiner.progress >= 1.0 {
                updatedMiner.progress = 0
                
                // Extract from resource
                let mined = chunkManager.mineResource(at: position.tilePosition)
                if mined > 0 {
                    // Add to output inventory
                    inventory.add(itemId: resource.type.outputItem, count: 1)
                    inventoryModifications.append((entity, inventory))
                }
            }
            
            // Save miner component (progress, isActive, etc. need to persist)
            minerModifications.append((entity, updatedMiner))
        }
        
        // Apply all modifications after iteration completes
        for (entity, miner) in minerModifications {
            world.add(miner, to: entity)
        }
        for (entity, inventory) in inventoryModifications {
            world.add(inventory, to: entity)
        }
        
    }
    
    private func consumeFuel(inventory: inout InventoryComponent, miner: inout MinerComponent) -> Bool {
        let fuels: [(String, Float)] = [
            ("coal", 4.0),
            ("wood", 2.0),
            ("solid-fuel", 12.0)
        ]
        
        for (fuelId, fuelValue) in fuels {
            if inventory.has(itemId: fuelId) {
                inventory.remove(itemId: fuelId, count: 1)
                miner.fuelRemaining = fuelValue
                return true
            }
        }
        
        return false
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

