import Foundation
import QuartzCore

/// System that handles mining drills extracting resources
final class MiningSystem: System {
    let priority = SystemPriority.mining.rawValue
    
    private let world: World
    private let chunkManager: ChunkManager

    // Cache for performance optimization
    private var resourceCache: [IntVector2: ResourceDeposit] = [:]
    private var treeCache: [IntVector2: Entity] = [:]
    private var cacheValid: Bool = false
    private let cacheUpdateInterval: TimeInterval = 0.5  // Update cache every 0.5 seconds
    private var lastCacheUpdate: TimeInterval = 0

    init(world: World, chunkManager: ChunkManager) {
        self.world = world
        self.chunkManager = chunkManager
    }

    /// Called when chunks are loaded/unloaded to invalidate resource cache
    func invalidateResourceCache() {
        cacheValid = false
        resourceCache.removeAll(keepingCapacity: true)
        treeCache.removeAll(keepingCapacity: true)
    }
    
    func update(deltaTime: Float) {
        let startTime = CACurrentMediaTime()
        let currentTime = Time.shared.totalTime

        // Update resource/tree cache periodically for performance
        if !cacheValid || Double(currentTime) - lastCacheUpdate > cacheUpdateInterval {
            updateResourceCache()
            lastCacheUpdate = Double(currentTime)
        }

        // Collect all modifications to apply after iteration
        var minerModifications: [(Entity, MinerComponent)] = []
        var inventoryModifications: [(Entity, InventoryComponent)] = []
        
        world.forEach(MinerComponent.self) { [self] entity, miner in
            guard let position = world.get(PositionComponent.self, for: entity) else { return }
            guard var inventory = world.get(InventoryComponent.self, for: entity) else { return }
            
            var updatedMiner = miner
            
            // Check power for electric miners only
            let isBurnerMiner = world.get(PowerConsumerComponent.self, for: entity) == nil
            
            if !isBurnerMiner {
                // Electric miner - check power
            if let power = world.get(PowerConsumerComponent.self, for: entity) {
                    if power.satisfaction <= 0 {
                        updatedMiner.isActive = false
                        minerModifications.append((entity, updatedMiner))
                        return
                    } else {
                        // Ensure miner is active if powered
                        updatedMiner.isActive = true
                    }
                }
                
                guard updatedMiner.isActive else {
                    minerModifications.append((entity, updatedMiner))
                    return
                }
            } else {
                // Burner miners are always active (no fuel requirement)
                updatedMiner.isActive = true
            }
            
            // Try to find a resource or tree to mine
            var targetResource: ResourceDeposit? = nil
            var targetTree: Entity? = nil
            var outputItemId: String = ""

            // First, try to find a tile resource (for electric miners)
            targetResource = findResource(at: position.tilePosition)

            // If no tile resource found, or if this is a burner miner, try to find a tree
            if targetResource == nil || isBurnerMiner {
                targetTree = findTree(at: position.tilePosition)
            }

            // If neither resource nor tree found, deactivate miner
            if targetResource == nil && targetTree == nil {
                updatedMiner.isActive = false
                minerModifications.append((entity, updatedMiner))
                return
            }

            updatedMiner.isActive = true  // Ensure it's active if target found

            // Determine output item
            if let resource = targetResource {
                outputItemId = resource.type.outputItem
            } else if targetTree != nil {
                outputItemId = "wood"
            }

            updatedMiner.resourceOutput = outputItemId

            // Check if output inventory has space
            guard inventory.canAccept(itemId: outputItemId) else {
                minerModifications.append((entity, updatedMiner))
                return
            }

            // Calculate speed multiplier (power satisfaction for electric miners, 1.0 for burner miners)
            var speedMultiplier: Float = 1.0
            if let power = world.get(PowerConsumerComponent.self, for: entity) {
                speedMultiplier = power.satisfaction
            }

            // Progress mining
            var miningTime: Float
            if let resource = targetResource {
                // Tile resource mining time
                miningTime = 1.0 / (updatedMiner.miningSpeed * resource.richness * speedMultiplier)
            } else {
                // Tree mining time (fixed, not based on richness)
                miningTime = 1.0 / (updatedMiner.miningSpeed * speedMultiplier)
            }

            updatedMiner.progress += deltaTime / miningTime

            // Complete mining
            if updatedMiner.progress >= 1.0 {
                updatedMiner.progress = 0

                if let _ = targetResource {
                    // Extract from tile resource
                    let mined = chunkManager.mineResource(at: position.tilePosition)
                    if mined > 0 {
                        // Add to output inventory
                        inventory.add(itemId: outputItemId, count: mined)
                        inventoryModifications.append((entity, inventory))
                    }
                } else if let treeEntity = targetTree, var tree = world.get(TreeComponent.self, for: treeEntity) {
                    // Double-check tree has wood left (safety check)
                    if tree.woodYield > 0 {
                        // Harvest 1 wood from the tree
                        tree.woodYield -= 1
                        inventory.add(itemId: "wood", count: 1)
                        inventoryModifications.append((entity, inventory))

                        // Damage the tree's health
                        if let health = world.get(HealthComponent.self, for: treeEntity) {
                            var updatedHealth = health
                            updatedHealth.current -= 10  // Fixed damage per mining operation

                            if updatedHealth.isDead || tree.woodYield <= 0 {
                                // Tree is depleted - mark for removal
                                tree.markedForRemoval = true
                                print("MiningSystem: Tree depleted, marking for removal")
                            }

                            world.add(updatedHealth, to: treeEntity)
                        }

                        // Update tree component
                        world.add(tree, to: treeEntity)
                    } else {
                        // Tree has no wood left - should have been marked for removal already
                        print("MiningSystem: WARNING - Tree with no wood found, should have been removed")
                        tree.markedForRemoval = true
                        world.add(tree, to: treeEntity)
                    }
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

        // Remove destroyed trees
        var treesToRemove: [Entity] = []
        world.forEach(TreeComponent.self) { entity, tree in
            if tree.markedForRemoval {
                print("MiningSystem: Removing destroyed tree entity \(entity)")
                treesToRemove.append(entity)
            }
        }
        for entity in treesToRemove {
            world.despawn(entity)
        }

        // Profile mining system performance
        let endTime = CACurrentMediaTime()
        let duration = Float(endTime - startTime)
        if Int(Time.shared.frameCount) % 60 == 0 {
            print(String(format: "MiningSystem: %.2fms", duration*1000))
        }
    }
    
    private func updateResourceCache() {
        resourceCache.removeAll(keepingCapacity: true)
        treeCache.removeAll(keepingCapacity: true)

        // Only cache resources and trees near active miners to save performance
        world.forEach(MinerComponent.self) { [self] entity, miner in
            guard let position = world.get(PositionComponent.self, for: entity)?.tilePosition else { return }

            // Cache resources in 3x3 area around this miner
            for dy in -1...1 {
                for dx in -1...1 {
                    let checkPos = IntVector2(x: position.x + Int32(dx), y: position.y + Int32(dy))
                    if let resource = chunkManager.getResource(at: checkPos), !resource.isEmpty {
                        resourceCache[checkPos] = resource
                    }
                }
            }

            // Cache trees in 2x2 area around this miner (reduced from 5x5 for performance)
            let treeRadius: Int32 = 1  // Reduced from 2 for performance
            for dy in -treeRadius...treeRadius {
                for dx in -treeRadius...treeRadius {
                    let checkPos = IntVector2(x: position.x + dx, y: position.y + dy)
                    let entitiesAtPos = world.getAllEntitiesAt(position: checkPos)
                    for entity in entitiesAtPos {
                        if let tree = world.get(TreeComponent.self, for: entity), tree.woodYield > 0 {
                            treeCache[checkPos] = entity
                            break  // Only cache one tree per position
                        }
                    }
                }
            }
        }

        cacheValid = true
    }

    private func findResource(at position: IntVector2) -> ResourceDeposit? {
        // Use cached resources for better performance
        for dy in -1...1 {
            for dx in -1...1 {
                let checkPos = IntVector2(x: position.x + Int32(dx), y: position.y + Int32(dy))
                if let resource = resourceCache[checkPos], !resource.isEmpty {
                    return resource
                }
            }
        }
        return nil
    }

    private func findTree(at position: IntVector2) -> Entity? {
        // Use cached trees for better performance (reduced radius from 2 to 1)
        let miningRadius: Int32 = 1  // Reduced from 2 for performance

        for dy in -miningRadius...miningRadius {
            for dx in -miningRadius...miningRadius {
                let checkPos = IntVector2(x: position.x + dx, y: position.y + dy)
                if let treeEntity = treeCache[checkPos] {
                    // Double-check tree is still valid and has wood
                    if let tree = world.get(TreeComponent.self, for: treeEntity), tree.woodYield > 0 {
                        return treeEntity
                    }
                }
            }
        }

        return nil
    }
}

