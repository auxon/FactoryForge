import Foundation
import QuartzCore

/// System that handles mining drills extracting resources
final class MiningSystem: System {
    let priority = SystemPriority.mining.rawValue

    private let world: World
    private let chunkManager: ChunkManager
    private let itemRegistry: ItemRegistry
    private let buildingRegistry: BuildingRegistry

    // Cache for performance optimization
    private var resourceCache: [IntVector2: ResourceDeposit] = [:]
    private var treeCache: [IntVector2: Entity] = [:]
    private var minerResourceTargets: [Entity: IntVector2] = [:]
    private var minerTreeTargets: [Entity: Entity] = [:]
    private var minerNoResourceUntil: [Entity: TimeInterval] = [:]
    private var minerNoTreeUntil: [Entity: TimeInterval] = [:]
    private var minerNextScanTime: [Entity: TimeInterval] = [:]
    private var minerScanCursor: Int = 0
    private var cacheValid: Bool = false
    private let cacheUpdateInterval: TimeInterval = 0.5  // Update cache every 0.5 seconds
    private var lastCacheUpdate: TimeInterval = 0
    private var treeRemovalDirty: Bool = false
    private var lastTreeRemovalScan: TimeInterval = 0
    private let treeRemovalScanInterval: TimeInterval = 1.0
    private let noTargetCooldown: TimeInterval = 0.5
    private let minerScanInterval: TimeInterval = 0.2
    private let maxMinersPerUpdate: Int = 8

    init(world: World, chunkManager: ChunkManager, itemRegistry: ItemRegistry, buildingRegistry: BuildingRegistry) {
        self.world = world
        self.chunkManager = chunkManager
        self.itemRegistry = itemRegistry
        self.buildingRegistry = buildingRegistry
    }

    /// Called when chunks are loaded/unloaded to invalidate resource cache
    func invalidateResourceCache() {
        cacheValid = false
        resourceCache.removeAll(keepingCapacity: true)
        treeCache.removeAll(keepingCapacity: true)
        minerResourceTargets.removeAll(keepingCapacity: true)
        minerTreeTargets.removeAll(keepingCapacity: true)
        minerNoResourceUntil.removeAll(keepingCapacity: true)
        minerNoTreeUntil.removeAll(keepingCapacity: true)
        minerNextScanTime.removeAll(keepingCapacity: true)
    }
    
    func update(deltaTime: Float) {
        let currentTime = Time.shared.totalTime
        let currentTimeSeconds = Double(currentTime)

        // Update resource/tree cache periodically for performance
        if !cacheValid {
            updateResourceCache()
            lastCacheUpdate = Double(currentTime)
        }

        // Collect all modifications to apply after iteration
        var minerModifications: [(Entity, MinerComponent)] = []
        var pumpjackModifications: [(Entity, PumpjackComponent)] = []
        var inventoryModifications: [(Entity, InventoryComponent)] = []

        // Process regular miners (time-sliced)
        let miners = Array(world.query(MinerComponent.self))
        let minerCount = miners.count
        let minersToProcess = min(minerCount, maxMinersPerUpdate)
        if minersToProcess > 0 {
            for i in 0..<minersToProcess {
                let index = (minerScanCursor + i) % minerCount
                let entity = miners[index]
                guard let miner = world.get(MinerComponent.self, for: entity) else { continue }
                guard let position = world.get(PositionComponent.self, for: entity) else { continue }
                guard var inventory = world.get(InventoryComponent.self, for: entity) else { continue }

                var updatedMiner = miner

                if let nextScan = minerNextScanTime[entity], currentTimeSeconds < nextScan {
                    minerModifications.append((entity, updatedMiner))
                    continue
                }

                // Check power for electric miners only; fuel for burner miners
                let isBurnerMiner = world.get(PowerConsumerComponent.self, for: entity) == nil

                if !isBurnerMiner {
                    // Electric miner - check power
                    if let power = world.get(PowerConsumerComponent.self, for: entity) {
                        if power.satisfaction <= 0 {
                            updatedMiner.isActive = false
                            minerModifications.append((entity, updatedMiner))
                            minerNextScanTime[entity] = currentTimeSeconds + minerScanInterval
                            continue
                        } else {
                            // Ensure miner is active if powered
                            updatedMiner.isActive = true
                        }
                    }

                    if !updatedMiner.isActive {
                        minerModifications.append((entity, updatedMiner))
                        minerNextScanTime[entity] = currentTimeSeconds + minerScanInterval
                        continue
                    }
                } else {
                    // Burner miner - require fuel in fuel slot
                    var hasFuel = updatedMiner.fuelRemaining > 0
                    if !hasFuel {
                        guard let buildingDef = buildingRegistry.get(updatedMiner.buildingId) else {
                            updatedMiner.isActive = false
                            minerModifications.append((entity, updatedMiner))
                            minerNextScanTime[entity] = currentTimeSeconds + minerScanInterval
                            continue
                        }
                        hasFuel = consumeMinerFuel(inventory: &inventory, miner: &updatedMiner, fuelSlots: buildingDef.fuelSlots)
                        if hasFuel { inventoryModifications.append((entity, inventory)) }
                    }
                    if !hasFuel {
                        updatedMiner.isActive = false
                        minerModifications.append((entity, updatedMiner))
                        minerNextScanTime[entity] = currentTimeSeconds + minerScanInterval
                        continue
                    }
                    updatedMiner.isActive = true
                }

                // Try to find a resource or tree to mine
                var targetResource: ResourceDeposit? = nil
                var targetTree: Entity? = nil
                var outputItemId: String = ""

                // First, try to find a tile resource (for electric miners)
                targetResource = resolveResourceTarget(for: entity, at: position.tilePosition, currentTimeSeconds: currentTimeSeconds)

                // If no tile resource found, or if this is a burner miner, try to find a tree
                if targetResource == nil || isBurnerMiner {
                    targetTree = resolveTreeTarget(for: entity, at: position.tilePosition, currentTimeSeconds: currentTimeSeconds)
                }

                // If neither resource nor tree found, deactivate miner
                if targetResource == nil && targetTree == nil {
                    updatedMiner.isActive = false
                    minerModifications.append((entity, updatedMiner))
                    minerNextScanTime[entity] = currentTimeSeconds + minerScanInterval
                    continue
                }

                updatedMiner.isActive = true  // Ensure it's active if target found

                // Determine output item
                if let resource = targetResource {
                    outputItemId = resource.type.outputItem
                } else if targetTree != nil {
                    outputItemId = "wood"
                }

                updatedMiner.resourceOutput = outputItemId

                guard let buildingDef = buildingRegistry.get(updatedMiner.buildingId) else {
                    minerModifications.append((entity, updatedMiner))
                    minerNextScanTime[entity] = currentTimeSeconds + minerScanInterval
                    continue
                }
                let outputStart = buildingDef.fuelSlots + buildingDef.inputSlots
                let outputEnd = outputStart + buildingDef.outputSlots

                // Check if output slots have space (mined output goes to output slots only, not fuel)
                if !minerOutputSlotsCanAccept(inventory, outputStart: outputStart, outputEnd: outputEnd, itemId: outputItemId) {
                    minerModifications.append((entity, updatedMiner))
                    minerNextScanTime[entity] = currentTimeSeconds + minerScanInterval
                    continue
                }

                // Calculate speed multiplier (power satisfaction for electric miners, 1.0 for burner miners)
                var speedMultiplier: Float = 1.0
                if let power = world.get(PowerConsumerComponent.self, for: entity) {
                    speedMultiplier = power.satisfaction
                }

                // Burner miners: consume fuel while mining; stop if no fuel
                if isBurnerMiner {
                    updatedMiner.fuelRemaining -= deltaTime
                    if updatedMiner.fuelRemaining <= 0 {
                        let consumed = consumeMinerFuel(inventory: &inventory, miner: &updatedMiner, fuelSlots: buildingDef.fuelSlots)
                        if consumed {
                            inventoryModifications.append((entity, inventory))
                        } else {
                            updatedMiner.isActive = false
                            minerModifications.append((entity, updatedMiner))
                            minerNextScanTime[entity] = currentTimeSeconds + minerScanInterval
                            continue
                        }
                    }
                }

                // Progress mining
                let miningTime: Float
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
                        // Mine at resource position (may be adjacent to miner)
                        let minePos = minerResourceTargets[entity] ?? position.tilePosition
                        let mined = chunkManager.mineResource(at: minePos)
                        if mined > 0 {
                            addMinedOutputToOutputSlots(&inventory, outputStart: outputStart, outputEnd: outputEnd, outputItemId: outputItemId, count: mined)
                            inventoryModifications.append((entity, inventory))
                        }
                        updateResourceCacheAfterMining(entity: entity, minerPosition: minePos)
                    } else if let treeEntity = targetTree, var tree = world.get(TreeComponent.self, for: treeEntity) {
                        // Double-check tree has wood left (safety check)
                        if tree.woodYield > 0 {
                            // Harvest 1 wood from the tree
                            tree.woodYield -= 1
                            addMinedOutputToOutputSlots(&inventory, outputStart: outputStart, outputEnd: outputEnd, outputItemId: "wood", count: 1)
                            inventoryModifications.append((entity, inventory))

                            // Damage the tree's health
                            if let health = world.get(HealthComponent.self, for: treeEntity) {
                                var updatedHealth = health
                                updatedHealth.current -= 10  // Fixed damage per mining operation

                                if updatedHealth.isDead || tree.woodYield <= 0 {
                                    // Tree is depleted - mark for removal
                                    tree.markedForRemoval = true
                                    treeRemovalDirty = true
                                    print("MiningSystem: Tree depleted, marking for removal")
                                    if let treePos = world.get(PositionComponent.self, for: treeEntity)?.tilePosition {
                                        treeCache.removeValue(forKey: treePos)
                                    }
                                    if minerTreeTargets[entity] == treeEntity {
                                        minerTreeTargets.removeValue(forKey: entity)
                                    }
                                }

                                world.add(updatedHealth, to: treeEntity)
                            }

                            // Update tree component
                            world.add(tree, to: treeEntity)
                        } else {
                            // Tree has no wood left - should have been marked for removal already
                            print("MiningSystem: WARNING - Tree with no wood found, should have been removed")
                            tree.markedForRemoval = true
                            treeRemovalDirty = true
                            if let treePos = world.get(PositionComponent.self, for: treeEntity)?.tilePosition {
                                treeCache.removeValue(forKey: treePos)
                            }
                            if minerTreeTargets[entity] == treeEntity {
                                minerTreeTargets.removeValue(forKey: entity)
                            }
                            world.add(tree, to: treeEntity)
                        }
                    }
                }

                // Save miner component (progress, isActive, etc. need to persist)
                minerModifications.append((entity, updatedMiner))
                minerNextScanTime[entity] = currentTimeSeconds + minerScanInterval
            }
            minerScanCursor = (minerScanCursor + minersToProcess) % minerCount
        }

        // Process pumpjacks (oil wells and water pumps)
        world.forEach(PumpjackComponent.self) { [self] entity, pumpjack in
            guard let position = world.get(PositionComponent.self, for: entity) else { return }

            let updatedPumpjack = pumpjack
            let tilePos = position.tilePosition
            let usesFluidOutput = world.has(FluidProducerComponent.self, for: entity)

            // Determine what resource this pumpjack extracts and if it requires deposits
            let resourceItem = pumpjack.resourceType
            let requiresDeposit = (resourceItem == "crude-oil")  // Only oil requires deposits

            // Check power for pumpjacks
            if let power = world.get(PowerConsumerComponent.self, for: entity) {
                if power.satisfaction <= 0 {
                    updatedPumpjack.isActive = false
                    pumpjackModifications.append((entity, updatedPumpjack))
                    return
                } else {
                    updatedPumpjack.isActive = true
                }
            }

            guard updatedPumpjack.isActive else {
                pumpjackModifications.append((entity, updatedPumpjack))
                return
            }

            // Check resource availability (deposits for oil, always available for water)
            if requiresDeposit {
                guard let deposit = chunkManager.getResource(at: tilePos),
                      deposit.type.outputItem == resourceItem,
                      deposit.amount > 0 else {
                    updatedPumpjack.isActive = false
                    pumpjackModifications.append((entity, updatedPumpjack))
                    return
                }
            }

            if !usesFluidOutput {
                guard let inventory = world.get(InventoryComponent.self, for: entity) else { return }
                // Check if output inventory has space for the resource
                guard inventory.canAccept(itemId: resourceItem) else {
                    pumpjackModifications.append((entity, updatedPumpjack))
                    return
                }
            }

            // Calculate extraction time based on extraction rate
            let extractionTime = 1.0 / updatedPumpjack.extractionRate

            // Get power satisfaction multiplier
            var speedMultiplier: Float = 1.0
            if let power = world.get(PowerConsumerComponent.self, for: entity) {
                speedMultiplier = power.satisfaction
            }

            // Progress oil extraction
            updatedPumpjack.progress += deltaTime / extractionTime * speedMultiplier

            // Complete extraction
            if updatedPumpjack.progress >= 1.0 {
                updatedPumpjack.progress = 0

                if !usesFluidOutput {
                    guard var inventory = world.get(InventoryComponent.self, for: entity) else { return }
                    // Extract resource (deposits are infinite in Factorio, so we don't reduce the deposit amount)
                    if let itemDef = itemRegistry.get(resourceItem) {
                        inventory.add(itemId: resourceItem, count: 1, maxStack: itemDef.stackSize)
                    }
                    inventoryModifications.append((entity, inventory))
                }
            }

            pumpjackModifications.append((entity, updatedPumpjack))
        }

        // Apply all modifications after iteration completes
        for (entity, miner) in minerModifications {
            world.add(miner, to: entity)
        }
        for (entity, pumpjack) in pumpjackModifications {
            world.add(pumpjack, to: entity)
        }
        for (entity, inventory) in inventoryModifications {
            world.add(inventory, to: entity)
        }

        // Remove destroyed trees only when needed or periodically.
        if treeRemovalDirty || currentTimeSeconds - lastTreeRemovalScan > treeRemovalScanInterval {
            var treesToRemove: [Entity] = []
            world.forEach(TreeComponent.self) { entity, tree in
                if tree.markedForRemoval {
                    print("MiningSystem: Removing destroyed tree entity \(entity)")
                    treesToRemove.append(entity)
                }
            }
            for entity in treesToRemove {
                if let treePos = world.get(PositionComponent.self, for: entity)?.tilePosition {
                    treeCache.removeValue(forKey: treePos)
                }
                if let affectedMiner = minerTreeTargets.first(where: { $0.value == entity })?.key {
                    minerTreeTargets.removeValue(forKey: affectedMiner)
                }
                world.despawn(entity)
            }
            treeRemovalDirty = false
            lastTreeRemovalScan = currentTimeSeconds
        }
    }
    
    private func updateResourceCache() {
        resourceCache.removeAll(keepingCapacity: true)
        treeCache.removeAll(keepingCapacity: true)

        // Cache resources near miners; cache trees globally to avoid per-tile scans.
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
        }

        world.forEach(TreeComponent.self) { [self] entity, tree in
            guard tree.woodYield > 0 else { return }
            guard let position = world.get(PositionComponent.self, for: entity)?.tilePosition else { return }
            treeCache[position] = entity
        }

        cacheValid = true
    }

    private func resolveResourceTarget(for minerEntity: Entity, at position: IntVector2, currentTimeSeconds: TimeInterval) -> ResourceDeposit? {
        if let cooldownUntil = minerNoResourceUntil[minerEntity], currentTimeSeconds < cooldownUntil {
            return nil
        }

        if let cachedPos = minerResourceTargets[minerEntity] {
            if isWithinRadius(cachedPos, center: position, radius: 1) {
                if let cachedResource = resourceCache[cachedPos], !cachedResource.isEmpty {
                    minerNoResourceUntil.removeValue(forKey: minerEntity)
                    return cachedResource
                }
                if let resource = chunkManager.getResource(at: cachedPos), !resource.isEmpty {
                    resourceCache[cachedPos] = resource
                    minerNoResourceUntil.removeValue(forKey: minerEntity)
                    return resource
                }
            }
            minerResourceTargets.removeValue(forKey: minerEntity)
            resourceCache.removeValue(forKey: cachedPos)
        }

        for dy in -1...1 {
            for dx in -1...1 {
                let checkPos = IntVector2(x: position.x + Int32(dx), y: position.y + Int32(dy))
                if let cachedResource = resourceCache[checkPos], !cachedResource.isEmpty {
                    minerResourceTargets[minerEntity] = checkPos
                    minerNoResourceUntil.removeValue(forKey: minerEntity)
                    return cachedResource
                }
                if let resource = chunkManager.getResource(at: checkPos), !resource.isEmpty {
                    resourceCache[checkPos] = resource
                    minerResourceTargets[minerEntity] = checkPos
                    minerNoResourceUntil.removeValue(forKey: minerEntity)
                    return resource
                }
            }
        }
        minerNoResourceUntil[minerEntity] = currentTimeSeconds + noTargetCooldown
        return nil
    }

    private func resolveTreeTarget(for minerEntity: Entity, at position: IntVector2, currentTimeSeconds: TimeInterval) -> Entity? {
        if let cooldownUntil = minerNoTreeUntil[minerEntity], currentTimeSeconds < cooldownUntil {
            return nil
        }

        if let cachedTree = minerTreeTargets[minerEntity] {
            if let tree = world.get(TreeComponent.self, for: cachedTree),
               tree.woodYield > 0,
               let treePos = world.get(PositionComponent.self, for: cachedTree)?.tilePosition,
               isWithinRadius(treePos, center: position, radius: 1) {
                minerNoTreeUntil.removeValue(forKey: minerEntity)
                return cachedTree
            }
            if let treePos = world.get(PositionComponent.self, for: cachedTree)?.tilePosition {
                treeCache.removeValue(forKey: treePos)
            }
            minerTreeTargets.removeValue(forKey: minerEntity)
        }

        let radius: Int32 = 1
        for dy in -radius...radius {
            for dx in -radius...radius {
                let checkPos = IntVector2(x: position.x + dx, y: position.y + dy)
                if let treeEntity = treeCache[checkPos] {
                    if let tree = world.get(TreeComponent.self, for: treeEntity),
                       tree.woodYield > 0 {
                        minerTreeTargets[minerEntity] = treeEntity
                        minerNoTreeUntil.removeValue(forKey: minerEntity)
                        return treeEntity
                    }
                    treeCache.removeValue(forKey: checkPos)
                }
            }
        }
        minerNoTreeUntil[minerEntity] = currentTimeSeconds + noTargetCooldown
        return nil
    }

    private func updateResourceCacheAfterMining(entity: Entity, minerPosition: IntVector2) {
        let positionsToUpdate: [IntVector2] = {
            if let targetPos = minerResourceTargets[entity], targetPos != minerPosition {
                return [minerPosition, targetPos]
            }
            return [minerPosition]
        }()

        for pos in positionsToUpdate {
            if let resource = chunkManager.getResource(at: pos), !resource.isEmpty {
                resourceCache[pos] = resource
            } else {
                resourceCache.removeValue(forKey: pos)
                if minerResourceTargets[entity] == pos {
                    minerResourceTargets.removeValue(forKey: entity)
                }
            }
        }
    }

    /// True if any output slot is empty or has same item with room to stack.
    private func minerOutputSlotsCanAccept(_ inventory: InventoryComponent, outputStart: Int, outputEnd: Int, itemId: String) -> Bool {
        if let allowed = inventory.allowedItems, !allowed.contains(itemId) { return false }
        let end = min(outputEnd, inventory.slots.count)
        for i in outputStart..<end {
            guard let stack = inventory.slots[i] else { return true }
            if stack.itemId == itemId, stack.count < stack.maxStack { return true }
        }
        return false
    }

    /// Add mined output only to output slots (so it doesn't stack into fuel).
    private func addMinedOutputToOutputSlots(_ inventory: inout InventoryComponent, outputStart: Int, outputEnd: Int, outputItemId: String, count: Int) {
        guard let itemDef = itemRegistry.get(outputItemId) else { return }
        var remaining = count
        let end = min(outputEnd, inventory.slots.count)
        for i in outputStart..<end {
            if remaining <= 0 { break }
            if var stack = inventory.slots[i], stack.itemId == outputItemId, stack.count < stack.maxStack {
                let toAdd = min(stack.maxStack - stack.count, remaining)
                stack.count += toAdd
                inventory.slots[i] = stack
                remaining -= toAdd
            }
        }
        for i in outputStart..<end {
            if remaining <= 0 { break }
            if inventory.slots[i] == nil {
                let toAdd = min(itemDef.stackSize, remaining)
                inventory.slots[i] = ItemStack(itemId: outputItemId, count: toAdd, maxStack: itemDef.stackSize)
                remaining -= toAdd
            }
        }
    }

    private func isWithinRadius(_ pos: IntVector2, center: IntVector2, radius: Int32) -> Bool {
        return abs(pos.x - center.x) <= radius && abs(pos.y - center.y) <= radius
    }

    /// Consume one fuel item from fuel slots only (coal, wood, solid-fuel). Same fuels as furnaces.
    /// - Returns: true if fuel was consumed
    private func consumeMinerFuel(inventory: inout InventoryComponent, miner: inout MinerComponent, fuelSlots: Int) -> Bool {
        let fuels: [(String, Float)] = [
            ("coal", 4.0),
            ("wood", 2.0),
            ("solid-fuel", 12.0)
        ]
        let end = min(fuelSlots, inventory.slots.count)
        for (fuelId, burnTime) in fuels {
            for i in 0..<end {
                if var stack = inventory.slots[i], stack.itemId == fuelId, stack.count > 0 {
                    stack.count -= 1
                    if stack.count == 0 {
                        inventory.slots[i] = nil
                    } else {
                        inventory.slots[i] = stack
                    }
                    miner.fuelRemaining = burnTime
                    return true
                }
            }
        }
        return false
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
