import Foundation

/// System that handles inserter item transfers
final class InserterSystem: System {
    let priority = SystemPriority.logistics.rawValue + 50
    
    private let world: World
    private let beltSystem: BeltSystem
    private let itemRegistry: ItemRegistry

    init(world: World, beltSystem: BeltSystem, itemRegistry: ItemRegistry) {
        self.world = world
        self.beltSystem = beltSystem
        self.itemRegistry = itemRegistry
    }
    
    func update(deltaTime: Float) {
        _ = world.query(InserterComponent.self)
        let allMiners = world.query(MinerComponent.self)
        // print("InserterSystem: update called, found \(allInserters.count) inserter(s), \(allMiners.count) miner(s)")

        // Log all miner positions for debugging
        for minerEntity in allMiners {
            if let _ = world.get(PositionComponent.self, for: minerEntity),
               let inventory = world.get(InventoryComponent.self, for: minerEntity) {
                _ = inventory.slots.compactMap { $0 }.reduce(0) { $0 + $1.count }
                // print("InserterSystem: Miner entity \(minerEntity) at \(pos.tilePosition) has \(itemCount) items in inventory")
            }
        }
        
        world.forEach(InserterComponent.self) { [self] entity, inserter in
            guard let position = world.get(PositionComponent.self, for: entity) else {
                // print("InserterSystem: Inserter \(entity) has no PositionComponent")
                return
            }
            let power = world.get(PowerConsumerComponent.self, for: entity)
            // Check if inserter is on a power network and has satisfaction > 0
            // Consumers not on a network have networkId = nil and should be considered unpowered
            let hasPower = power != nil && power!.networkId != nil && power!.satisfaction > 0
            
            // print("InserterSystem: Processing inserter \(entity) at \(position.tilePosition), hasPower=\(hasPower), power=\(power != nil ? "exists" : "nil"), networkId=\(power?.networkId != nil ? "\(power!.networkId!)" : "nil"), satisfaction=\(power?.satisfaction ?? 0)")
            
            // Update inserter animation (pause if no power, play if powered)
            updateInserterAnimation(entity: entity, deltaTime: deltaTime, hasPower: hasPower)
            
            // Only process inserter logic if powered
            guard hasPower, let power = power else {
                // print("InserterSystem: Inserter at \(position.tilePosition) skipped - no power")
                return
            }
            
            let speedMultiplier = power.satisfaction
            
            // print("InserterSystem: Inserter at \(position.tilePosition) state=\(inserter.state), heldItem=\(inserter.heldItem != nil ? "exists" : "nil")")
            
            switch inserter.state {
            case .idle:
                // If holding an item, try to drop it off first
                if inserter.heldItem != nil {
                    // print("InserterSystem: Inserter at \(position.tilePosition) in idle state but holding item, transitioning to droppingOff")
                    inserter.state = .droppingOff
                    break
                }

                // Check if we can pick something up based on inserter type
                if inserter.heldItem == nil {
                    switch inserter.type {
                    case .input:
                        // Input inserters pick up from sources (belts, miners)
                        // Check all 8 adjacent directions
                        let offsets = [
                            IntVector2(0, 1), IntVector2(1, 1), IntVector2(1, 0), IntVector2(1, -1),
                            IntVector2(0, -1), IntVector2(-1, -1), IntVector2(-1, 0), IntVector2(-1, 1)
                        ]

                        // print("InserterSystem: Input inserter at \(position.tilePosition) checking for pickup sources")
                        for offset in offsets {
                            let sourcePos = position.tilePosition + offset
                            // print("InserterSystem: Checking position \(sourcePos)")
                            if canPickUp(from: sourcePos) {
                                // print("InserterSystem: Inserter at \(position.tilePosition) can pick up from \(sourcePos), transitioning to pickingUp")
                                inserter.state = .pickingUp
                                break
                            }
                        }

                    case .output:
                        // Output inserters pick up from machine outputs (furnaces, assemblers)
                        // Check adjacent machines for output items
                        let offsets = [
                            IntVector2(0, 1), IntVector2(1, 1), IntVector2(1, 0), IntVector2(1, -1),
                            IntVector2(0, -1), IntVector2(-1, -1), IntVector2(-1, 0), IntVector2(-1, 1)
                        ]

                        // print("InserterSystem: Output inserter at \(position.tilePosition) checking for machine outputs")
                        for offset in offsets {
                            let checkPos = position.tilePosition + offset
                            if canPickUpFromMachineOutput(at: checkPos) {
                                // print("InserterSystem: Output inserter at \(position.tilePosition) can pick up from machine at \(checkPos), transitioning to pickingUp")
                                inserter.state = .pickingUp
                                break
                            }
                        }
                    }
                } else {
                    // print("InserterSystem: Inserter at \(position.tilePosition) in idle state but already holding item")
                }

            case .pickingUp:
                // Rotate arm towards source (.pi radians = 180 degrees)
                let rotationSpeed = inserter.speed * speedMultiplier * deltaTime * .pi * 2
                let targetAngle: Float = .pi
                
                // Normalize angle difference to [-pi, pi] range for shortest path
                var angleDiff = targetAngle - inserter.armAngle
                while angleDiff > .pi {
                    angleDiff -= 2 * .pi
                }
                while angleDiff < -.pi {
                    angleDiff += 2 * .pi
                }
                
                // print("InserterSystem: Inserter at \(position.tilePosition) in pickingUp state, armAngle=\(inserter.armAngle), targetAngle=\(targetAngle), angleDiff=\(angleDiff)")
                
                if abs(angleDiff) < rotationSpeed {
                    inserter.armAngle = targetAngle
                    // print("InserterSystem: Inserter at \(position.tilePosition) arm reached target, trying to pick up")
                    
                    // Try to pick up item
                    if let item = tryPickUp(inserter: &inserter, position: position) {
                        if inserter.sourceEntity != nil {
                            // print("InserterSystem: Inserter at \(position.tilePosition) successfully picked up \(item.itemId) from source entity")
                        } else {
                            // print("InserterSystem: Inserter at \(position.tilePosition) successfully picked up \(item.itemId) from belt")
                        }
                        inserter.heldItem = item
                        inserter.state = .rotating
                    } else {
                        // print("InserterSystem: Inserter at \(position.tilePosition) failed to pick up, returning to idle")
                        // Nothing to pick up, return to idle
                        inserter.armAngle = 0
                        inserter.state = .idle
                    }
                } else {
                    inserter.armAngle += angleDiff > 0 ? rotationSpeed : -rotationSpeed
                    // Normalize armAngle to [0, 2*pi] range
                    while inserter.armAngle < 0 {
                        inserter.armAngle += 2 * .pi
                    }
                    while inserter.armAngle >= 2 * .pi {
                        inserter.armAngle -= 2 * .pi
                    }
                }
                
            case .rotating:
                // Rotate arm towards target (0 radians = 0 degrees)
                let rotationSpeed = inserter.speed * speedMultiplier * deltaTime * .pi * 2
                let targetAngle: Float = 0
                
                // Normalize armAngle to [0, 2*pi] first
                var normalizedArmAngle = inserter.armAngle
                while normalizedArmAngle < 0 {
                    normalizedArmAngle += 2 * .pi
                }
                while normalizedArmAngle >= 2 * .pi {
                    normalizedArmAngle -= 2 * .pi
                }
                
                // Calculate angle difference
                var angleDiff = targetAngle - normalizedArmAngle
                
                // Normalize to [-pi, pi] for shortest path
                // If the absolute difference is > π, take the shorter path by wrapping
                while angleDiff > .pi {
                    angleDiff -= 2 * .pi
                }
                while angleDiff < -.pi {
                    angleDiff += 2 * .pi
                }
                
                // print("InserterSystem: Inserter at \(position.tilePosition) in rotating state, armAngle=\(inserter.armAngle) (normalized: \(normalizedArmAngle)), targetAngle=\(targetAngle), angleDiff=\(angleDiff), rotationSpeed=\(rotationSpeed)")
                
                // Check if we're close enough to snap to target
                // Also check if we're very close to 0 or 2π (which are the same)
                let distanceToZero = min(abs(normalizedArmAngle), abs(normalizedArmAngle - 2 * .pi))
                // Snap if: within one rotation step, or very close to target, or close to 0/2π
                // Use a larger threshold to ensure we snap when close
                if abs(angleDiff) <= rotationSpeed * 2 || abs(angleDiff) < 0.3 || distanceToZero < 0.3 {
                    inserter.armAngle = targetAngle
                    // print("InserterSystem: Inserter at \(position.tilePosition) arm reached target (0), transitioning to droppingOff (angleDiff=\(angleDiff), distanceToZero=\(distanceToZero))")
                    inserter.state = .droppingOff
                } else {
                    // Calculate new angle using normalized value
                    let newAngle = normalizedArmAngle + (angleDiff > 0 ? rotationSpeed : -rotationSpeed)
                    
                    // Normalize new angle to [0, 2*pi]
                    var finalAngle = newAngle
                    while finalAngle < 0 {
                        finalAngle += 2 * .pi
                    }
                    while finalAngle >= 2 * .pi {
                        finalAngle -= 2 * .pi
                    }
                    
                    inserter.armAngle = finalAngle
                    
                    // Check if we've passed the target by comparing the new angle difference
                    let newNormalizedAngle = finalAngle
                    var newAngleDiff = targetAngle - newNormalizedAngle
                    if newAngleDiff > .pi {
                        newAngleDiff -= 2 * .pi
                    } else if newAngleDiff < -.pi {
                        newAngleDiff += 2 * .pi
                    }
                    
                    // If we've crossed the target (sign changed or we're very close), snap to it
                    if abs(newAngleDiff) < 0.01 || 
                       (angleDiff > 0 && newAngleDiff < 0) || 
                       (angleDiff < 0 && newAngleDiff > 0) ||
                       (abs(newNormalizedAngle) < 0.01) {
                        inserter.armAngle = targetAngle
                        inserter.state = .droppingOff
                        print("InserterSystem: Inserter at \(position.tilePosition) arm passed target, snapping to 0 and transitioning to droppingOff")
                    }
                }
                
            case .droppingOff:
                // Try to drop item
                if let item = inserter.heldItem {
                    // print("InserterSystem: Inserter at \(position.tilePosition) trying to drop off \(item.itemId)")
                    if tryDropOff(inserter: inserter, position: position, item: item) {
                        // print("InserterSystem: Inserter at \(position.tilePosition) successfully dropped off item")
                        inserter.heldItem = nil
                        inserter.sourceEntity = nil  // Clear source entity after dropping off
                        inserter.state = .idle
                        inserter.armAngle = 0
                    } else {
                        // print("InserterSystem: Inserter at \(position.tilePosition) failed to drop off, returning to idle with item still held")
                        // Can't drop off, return to idle with item still held
                        // (This shouldn't happen often, but prevents getting stuck)
                        inserter.state = .idle
                    }
                } else {
                    inserter.state = .idle
                }
            }
        }
    }
    
    // MARK: - Pick Up Logic
    
    /// Checks if there's something to pick up from a position
    private func canPickUp(from position: IntVector2) -> Bool {
        // Check if there's an item on a belt (check both lanes)
        if let beltEntity = beltSystem.getBeltAt(position: position),
           let belt = world.get(BeltComponent.self, for: beltEntity) {
            // Check if either lane has an item near the end (ready to be picked up)
            for laneItems in [belt.leftLane, belt.rightLane] {
                if let lastItem = laneItems.last, lastItem.progress >= 0.9 {
                    // print("InserterSystem: canPickUp from \(position): found belt item")
                    return true
                }
            }
        }
        
        // Check if there's an entity with inventory that has items
        // For multi-tile buildings, check ALL nearby entities for adjacency (not just ones where position is within bounds)
        // because the miner might be adjacent but the checked position might be outside its bounds
        let nearbyEntities = world.getEntitiesNear(position: Vector2(Float(position.x) + 0.5, Float(position.y) + 0.5), radius: 2.0)
        // print("InserterSystem: canPickUp from \(position): checking \(nearbyEntities.count) nearby entities")
        
        // Log all nearby entities for debugging
        for entity in nearbyEntities {
            if let entityPos = world.get(PositionComponent.self, for: entity) {
                _ = abs(entityPos.tilePosition.x - position.x) + abs(entityPos.tilePosition.y - position.y)
                _ = world.has(MinerComponent.self, for: entity)
                _ = world.has(FurnaceComponent.self, for: entity)
                _ = world.has(InventoryComponent.self, for: entity)
                let inventory = world.get(InventoryComponent.self, for: entity)
                _ = inventory?.slots.compactMap { $0 }.reduce(0) { $0 + $1.count } ?? 0
                // print("InserterSystem: canPickUp from \(position): nearby entity \(entity) at \(entityPos.tilePosition), distance=\(distance), hasMiner=\(hasMiner), hasFurnace=\(hasFurnace), hasInventory=\(hasInventory), itemCount=\(itemCount)")
            }
        }
        
        // First, try to find any miner or building with inventory that's adjacent (within 1 tile)
        for entity in nearbyEntities {
            if let entityPos = world.get(PositionComponent.self, for: entity) {
                let distance = abs(entityPos.tilePosition.x - position.x) + abs(entityPos.tilePosition.y - position.y)
                
                // Check if entity is adjacent (within 1 tile in any direction, including diagonals)
                if distance <= 1 {
                    _ = world.has(MinerComponent.self, for: entity)
                    _ = world.has(FurnaceComponent.self, for: entity)

                    // Don't pick up from entities that have inserters adjacent (drop-off targets)
                    // But allow pickup from miners, which are always valid sources
                    let hasInserterAdjacent = self.hasInserterAdjacent(to: entity)
                    if hasInserterAdjacent && !world.has(MinerComponent.self, for: entity) {
                        // print("InserterSystem: canPickUp from \(position): skipping entity \(entity) at \(entityPos.tilePosition) (has inserter adjacent - drop-off target)")
                        continue
                    }

                    // Check for inventory on buildings that are pickup sources (miners, etc.)
                    if let inventory = world.get(InventoryComponent.self, for: entity) {
                        _ = inventory.slots.compactMap { $0 }.reduce(0) { $0 + $1.count }
                        // print("InserterSystem: canPickUp from \(position): adjacent entity \(entity) at \(entityPos.tilePosition), hasMiner=\(hasMiner), hasFurnace=\(hasFurnace), has inventory with \(itemCount) items, isEmpty=\(inventory.isEmpty)")
                        if !inventory.isEmpty {
                            return true
                        }
                    }
                }
            }
        }
        
        // Fallback: Check if position is within entity bounds (for multi-tile buildings)
        for entity in nearbyEntities {
            if let entityPos = world.get(PositionComponent.self, for: entity),
               let sprite = world.get(SpriteComponent.self, for: entity) {
                let origin = entityPos.tilePosition
                let width = Int32(sprite.size.x)
                let height = Int32(sprite.size.y)

                // Check if the pickup position is within this entity's bounds
                if position.x >= origin.x && position.x < origin.x + width &&
                   position.y >= origin.y && position.y < origin.y + height {
                    // Don't pick up from drop-off targets, but allow miners
                    let hasInserterAdjacent = self.hasInserterAdjacent(to: entity)
                    let isMiner = world.has(MinerComponent.self, for: entity)
                    if !hasInserterAdjacent || isMiner {
                        if let inventory = world.get(InventoryComponent.self, for: entity),
                           !inventory.isEmpty {
                            return true
                        }
                    }
                }
            }
        }

        // Fallback: try getEntityAt (for single-tile entities)
        if let entity = world.getEntityAt(position: position) {
            // Don't pick up from drop-off targets, but allow miners
            let hasInserterAdjacent = self.hasInserterAdjacent(to: entity)
            let isMiner = world.has(MinerComponent.self, for: entity)
            if !hasInserterAdjacent || isMiner {
                if let inventory = world.get(InventoryComponent.self, for: entity) {
                    _ = inventory.slots.compactMap { $0 }.reduce(0) { $0 + $1.count }
                    // print("InserterSystem: canPickUp from \(position): getEntityAt found entity \(entity) with inventory (\(itemCount) items), isEmpty=\(inventory.isEmpty)")
                    if !inventory.isEmpty {
                        return true
                    }
                } else {
                    // print("InserterSystem: canPickUp from \(position): getEntityAt found entity \(entity) but no InventoryComponent")
                }
            } else {
                // print("InserterSystem: canPickUp from \(position): getEntityAt found entity \(entity) but it's a drop-off target")
            }
        } else {
            // print("InserterSystem: canPickUp from \(position): getEntityAt found no entity")
        }
        
        return false
    }
    
    private func tryPickUp(inserter: inout InserterComponent, position: PositionComponent) -> ItemStack? {
        // Check all 8 adjacent directions (including diagonals)
        let offsets = [
            IntVector2(0, 1),    // North
            IntVector2(1, 1),     // Northeast
            IntVector2(1, 0),     // East
            IntVector2(1, -1),   // Southeast
            IntVector2(0, -1),   // South
            IntVector2(-1, -1),  // Southwest
            IntVector2(-1, 0),    // West
            IntVector2(-1, 1)     // Northwest
        ]
        
        // print("InserterSystem: tryPickUp called for inserter at \(position.tilePosition)")
        for offset in offsets {
            let sourcePos = position.tilePosition + offset
            
            // Try to pick from belt first
            if let item = tryPickFromBelt(at: sourcePos, stackSize: inserter.stackSize) {
                // print("InserterSystem: tryPickUp picked from belt at \(sourcePos)")
                inserter.sourceEntity = nil  // Belts don't have entities to track
                return item
            }
            
            // Try to pick from inventory
            var sourceEntity: Entity? = nil
            if let item = tryPickFromInventory(at: sourcePos, stackSize: inserter.stackSize, sourceEntity: &sourceEntity) {
                // print("InserterSystem: tryPickUp picked from inventory at \(sourcePos)")
                inserter.sourceEntity = sourceEntity  // Track source entity
                return item
            }
        }
        
        // print("InserterSystem: tryPickUp failed to pick up from any adjacent position")
        return nil
    }
    
    private func tryPickFromBelt(at position: IntVector2, stackSize: Int) -> ItemStack? {
        // Try left lane first, then right
        for lane in [BeltLane.left, BeltLane.right] {
            if let beltItem = beltSystem.takeItem(at: position, lane: lane) {
                let maxStack = itemRegistry.get(beltItem.itemId)?.stackSize ?? 100
                return ItemStack(itemId: beltItem.itemId, count: 1, maxStack: maxStack)
            }
        }
        return nil
    }
    
    private func tryPickFromInventory(at position: IntVector2, stackSize: Int, sourceEntity: inout Entity?) -> ItemStack? {
        // Check adjacent entities (for multi-tile buildings like miners)
        let nearbyEntities = world.getEntitiesNear(position: Vector2(Float(position.x) + 0.5, Float(position.y) + 0.5), radius: 2.0)
        for entity in nearbyEntities {
            if let entityPos = world.get(PositionComponent.self, for: entity) {
                let distance = abs(entityPos.tilePosition.x - position.x) + abs(entityPos.tilePosition.y - position.y)
                
                // Check if entity is adjacent (within 1 tile in any direction, including diagonals)
                if distance <= 1 {
                    if var inventory = world.get(InventoryComponent.self, for: entity) {
                        if let item = inventory.takeOne() {
                            // print("InserterSystem: tryPickFromInventory picked item \(item.itemId) from entity \(entity) at \(entityPos.tilePosition)")
                            sourceEntity = entity  // Track source entity
                            world.add(inventory, to: entity)
                            return item
                        }
                    }
                }
            }
        }
        
        // Fallback: try getEntityAt (for single-tile entities)
        guard let entity = world.getEntityAt(position: position) else { return nil }
        guard var inventory = world.get(InventoryComponent.self, for: entity) else { return nil }
        
        // Take items from inventory
        if let item = inventory.takeOne() {
            // print("InserterSystem: tryPickFromInventory picked item \(item.itemId) from entity \(entity) at position \(position)")
            sourceEntity = entity  // Track source entity
            world.add(inventory, to: entity)
            return item
        }
        
        return nil
    }
    
    // MARK: - Drop Off Logic
    
    private func tryDropOff(inserter: InserterComponent, position: PositionComponent, item: ItemStack) -> Bool {
        // Check all 8 adjacent directions (including diagonals)
        let offsets = [
            IntVector2(0, 1),    // North
            IntVector2(1, 1),     // Northeast
            IntVector2(1, 0),     // East
            IntVector2(1, -1),   // Southeast
            IntVector2(0, -1),   // South
            IntVector2(-1, -1),  // Southwest
            IntVector2(-1, 0),    // West
            IntVector2(-1, 1)     // Northwest
        ]
        
        if inserter.sourceEntity != nil {
            // print("InserterSystem: tryDropOff called for inserter at \(position.tilePosition) with item \(item.itemId), excluding source entity")
        } else {
            // print("InserterSystem: tryDropOff called for inserter at \(position.tilePosition) with item \(item.itemId), no source entity to exclude")
        }
        for offset in offsets {
            let targetPos = position.tilePosition + offset
            
            // Try to drop on belt first (belts don't have entities, so no need to exclude)
            if tryDropOnBelt(at: targetPos, item: item) {
                // print("InserterSystem: tryDropOff successfully dropped on belt at \(targetPos)")
                return true
            }
            
            // Try to drop in inventory (exclude source entity)
            if tryDropInInventory(at: targetPos, item: item, excludeEntity: inserter.sourceEntity) {
                // print("InserterSystem: tryDropOff successfully dropped in inventory at \(targetPos)")
                return true
            }
        }
        
        // print("InserterSystem: tryDropOff failed to drop off at any adjacent position")
        return false
    }
    
    private func tryDropOnBelt(at position: IntVector2, item: ItemStack) -> Bool {
        // Check which lane has space
        for lane in [BeltLane.left, BeltLane.right] {
            if beltSystem.hasSpace(at: position, lane: lane) {
                return beltSystem.addItem(item.itemId, at: position, lane: lane)
            }
        }
        return false
    }
    
    private func tryDropInInventory(at position: IntVector2, item: ItemStack, excludeEntity: Entity?) -> Bool {
        // Check adjacent entities only (for multi-tile buildings like furnaces)
        // Use small radius to find multi-tile buildings, but filter to adjacent only
        let searchPos = Vector2(Float(position.x) + 0.5, Float(position.y) + 0.5)
        let nearbyEntities = world.getEntitiesNear(position: searchPos, radius: 2.0)
        // print("InserterSystem: Searching for drop targets near \(searchPos) with radius 2.0")
        // print("InserterSystem: Inserter is at \(position), trying to drop \(item.itemId)")
        
        // Check item types for debugging
        let isFuel = item.itemId == "coal" || item.itemId == "wood" || item.itemId == "solid-fuel"
        let isOre = item.itemId == "iron-ore" || item.itemId == "copper-ore" || item.itemId == "stone"

        // Only consider directly connected targets (via inserter adjacency)
        var inserterConnectedTargets: [Entity] = []
        
        // Filter to only adjacent entities and categorize them
        for entity in nearbyEntities {
            // Skip the source entity to avoid dropping back to where we picked up from
            if let excludeEntity = excludeEntity, entity.id == excludeEntity.id && entity.generation == excludeEntity.generation {
                continue
            }
            
            // Check if entity is adjacent (within 1 tile in any direction, including diagonals)
            guard let entityPos = world.get(PositionComponent.self, for: entity) else { continue }

            // For multi-tile buildings, check if inserter is adjacent to any tile occupied by the building
            var isAdjacent = false
            if let sprite = world.get(SpriteComponent.self, for: entity) {
                // Building occupies multiple tiles based on sprite size
                let buildingWidth = Int(ceil(sprite.size.x))
                let buildingHeight = Int(ceil(sprite.size.y))

                // Check if inserter is adjacent to any tile of the building
                for dy in 0..<buildingHeight {
                    for dx in 0..<buildingWidth {
                        let buildingTileX = entityPos.tilePosition.x + Int32(dx)
                        let buildingTileY = entityPos.tilePosition.y + Int32(dy)
                        let distance = abs(buildingTileX - position.x) + abs(buildingTileY - position.y)
                        if distance <= 1 {
                            isAdjacent = true
                            break
                        }
                    }
                    if isAdjacent { break }
                }
            } else {
                // Single-tile entity - use simple distance check
                let distance = abs(entityPos.tilePosition.x - position.x) + abs(entityPos.tilePosition.y - position.y)
                isAdjacent = distance <= 1
            }

            // Only consider adjacent entities
            guard isAdjacent else { continue }
            
            // Check if entity has inventory that can accept the item
            guard let inventory = world.get(InventoryComponent.self, for: entity) else { continue }
            guard inventory.canAccept(itemId: item.itemId) else { continue }
            
            // print("InserterSystem:     adjacent entity \(entity) at \(entityPos.tilePosition) can accept \(item.itemId)")
            
            let hasInserter = self.hasInserterAdjacent(to: entity)

            // Only consider entities with inserters adjacent (direct connections only)
            if hasInserter {
                inserterConnectedTargets.append(entity)
                print("InserterSystem:       -> inserter-connected target")
            }
        }
        
        // Debug: print all targets found
        print("InserterSystem: tryDropInInventory at \(position) for item \(item.itemId) (isFuel: \(isFuel), isOre: \(isOre)):")
        print("InserterSystem:   found \(nearbyEntities.count) nearby entities, \(inserterConnectedTargets.count) inserter-connected")

        // Only try inserter-connected targets (direct connections only)
        let targetsToTry = inserterConnectedTargets
        for entity in targetsToTry {
            guard let entityPos = world.get(PositionComponent.self, for: entity),
                  var inventory = world.get(InventoryComponent.self, for: entity) else { continue }
            
            let itemCountBefore = inventory.count(of: item.itemId)
            let remaining = inventory.add(item)
            let itemCountAfter = inventory.count(of: item.itemId)
            let hasBelt = hasInserterAdjacent(to: entity)
            print("InserterSystem: tryDropInInventory dropped item \(item.itemId) to entity \(entity) at \(entityPos.tilePosition) (belt-connected: \(hasBelt)), count before=\(itemCountBefore), after=\(itemCountAfter), remaining=\(remaining)")
            world.add(inventory, to: entity)
            return remaining == 0
        }
        
        // Fallback: try getEntityAt (for single-tile entities at this position)
        guard let entity = world.getEntityAt(position: position) else { return false }
        // Skip the source entity
        if let excludeEntity = excludeEntity, entity.id == excludeEntity.id && entity.generation == excludeEntity.generation {
            return false
        }

        // Check adjacency for the fallback entity
        guard let entityPos = world.get(PositionComponent.self, for: entity) else { return false }
        var isAdjacent = false
        if let sprite = world.get(SpriteComponent.self, for: entity) {
            // Building occupies multiple tiles based on sprite size
            let buildingWidth = Int(ceil(sprite.size.x))
            let buildingHeight = Int(ceil(sprite.size.y))

            // Check if position is within the building's occupied tiles
            for dy in 0..<buildingHeight {
                for dx in 0..<buildingWidth {
                    let buildingTileX = entityPos.tilePosition.x + Int32(dx)
                    let buildingTileY = entityPos.tilePosition.y + Int32(dy)
                    if buildingTileX == position.x && buildingTileY == position.y {
                        isAdjacent = true
                        break
                    }
                }
                if isAdjacent { break }
            }
        } else {
            // Single-tile entity - check exact position match
            isAdjacent = entityPos.tilePosition.x == position.x && entityPos.tilePosition.y == position.y
        }

        guard isAdjacent else { return false }

        guard var inventory = world.get(InventoryComponent.self, for: entity) else { return false }

        // Check if inventory can accept the item
        if inventory.canAccept(itemId: item.itemId) {
            let remaining = inventory.add(item)
            print("InserterSystem: tryDropInInventory dropped item \(item.itemId) to entity \(entity) at position \(position), remaining=\(remaining)")
            world.add(inventory, to: entity)
            return remaining == 0
        }
        
        return false
    }

    /// Checks if there's something to pick up from machine output at a position
    private func canPickUpFromMachineOutput(at position: IntVector2) -> Bool {
        // Check if there's an entity with inventory that has output items
        // For multi-tile buildings, check ALL nearby entities for adjacency
        let nearbyEntities = world.getEntitiesNear(position: Vector2(Float(position.x) + 0.5, Float(position.y) + 0.5), radius: 2.0)
        print("InserterSystem: canPickUpFromMachineOutput at \(position): checking \(nearbyEntities.count) nearby entities")

        // First, try to find any machine with output items that's adjacent
        for entity in nearbyEntities {
            if let entityPos = world.get(PositionComponent.self, for: entity) {
                let distance = abs(entityPos.tilePosition.x - position.x) + abs(entityPos.tilePosition.y - position.y)

                // Check if entity is adjacent (within 1 tile in any direction, including diagonals)
                if distance <= 1 {
                    let hasFurnace = world.has(FurnaceComponent.self, for: entity)
                    let hasAssembler = world.has(AssemblerComponent.self, for: entity)

                    // Check for inventory on machines (furnaces, assemblers)
                    if let inventory = world.get(InventoryComponent.self, for: entity) {
                        // For machines, check output slots (second half of inventory)
                        let outputStartIndex = inventory.slots.count / 2
                        let hasOutputItems = (outputStartIndex..<inventory.slots.count).contains { index in
                            inventory.slots[index] != nil
                        }

                        print("InserterSystem: canPickUpFromMachineOutput at \(position): adjacent machine \(entity) at \(entityPos.tilePosition), hasFurnace=\(hasFurnace), hasAssembler=\(hasAssembler), hasOutputItems=\(hasOutputItems)")
                        if hasOutputItems {
                            return true
                        }
                    }
                }
            }
        }

        return false
    }

    // MARK: - Helpers

    private func hasInserterAdjacent(to entity: Entity) -> Bool {
        guard let entityPos = world.get(PositionComponent.self, for: entity) else { return false }

        // For multi-tile buildings, check all tiles they occupy
        var positionsToCheck: [IntVector2] = []

        // Get building size from sprite component
        if let sprite = world.get(SpriteComponent.self, for: entity) {
            let width = Int(sprite.size.x)
            let height = Int(sprite.size.y)
            for x in 0..<width {
                for y in 0..<height {
                    positionsToCheck.append(IntVector2(x: entityPos.tilePosition.x + Int32(x), y: entityPos.tilePosition.y + Int32(y)))
                }
            }
        } else {
            // Single tile entity
            positionsToCheck.append(entityPos.tilePosition)
        }

        print("InserterSystem: hasInserterAdjacent for entity at \(entityPos.tilePosition) (size: \(positionsToCheck.count) tiles)")

        // Check all 8 adjacent positions for each tile the building occupies
        let offsets = [
            IntVector2(0, 1), IntVector2(1, 1), IntVector2(1, 0), IntVector2(1, -1),
            IntVector2(0, -1), IntVector2(-1, -1), IntVector2(-1, 0), IntVector2(-1, 1)
        ]
        for buildingPos in positionsToCheck {
            print("InserterSystem:   checking building tile \(buildingPos)")
            for offset in offsets {
                let checkPos = buildingPos + offset

                // Skip positions that are within the building's own bounds
                if positionsToCheck.contains(checkPos) {
                    print("InserterSystem:     skipping position \(checkPos) (within building bounds)")
                    continue
                }

                print("InserterSystem:     checking position \(checkPos) for inserter")
                if let entityAtPos = world.getEntityAt(position: checkPos) {
                    print("InserterSystem:       found entity \(entityAtPos) at \(checkPos)")
                    if world.has(InserterComponent.self, for: entityAtPos) {
                        print("InserterSystem:       entity has InserterComponent - INSERTER CONNECTED!")
                        return true
                    } else {
                        print("InserterSystem:       entity does NOT have InserterComponent")
                    }
                } else {
                    print("InserterSystem:       no entity at \(checkPos)")
                }
            }
        }

        print("InserterSystem:   no inserters found adjacent")
        return false
    }

    // MARK: - Animation

    private func updateInserterAnimation(entity: Entity, deltaTime: Float, hasPower: Bool) {
        guard var sprite = world.get(SpriteComponent.self, for: entity),
              var animation = sprite.animation else { return }
        
        // Pause animation if no power, play if powered
        if hasPower {
            if !animation.isPlaying {
                animation.play()
            }
            // Update animation frame when powered
            if let currentFrame = animation.update(deltaTime: deltaTime) {
                sprite.textureId = currentFrame
            }
        } else {
            // Pause animation when no power
            if animation.isPlaying {
                animation.pause()
            }
            // Keep current frame (don't update)
        }
        
        sprite.animation = animation
        world.add(sprite, to: entity)
    }
}

