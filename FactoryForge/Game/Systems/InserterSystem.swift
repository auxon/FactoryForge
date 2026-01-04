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
        // // print("InserterSystem:update called, found \(allInserters.count) inserter(s), \(allMiners.count) miner(s)")

        // Log all miner positions for debugging
        for minerEntity in allMiners {
            if let _ = world.get(PositionComponent.self, for: minerEntity),
               let inventory = world.get(InventoryComponent.self, for: minerEntity) {
                _ = inventory.slots.compactMap { $0 }.reduce(0) { $0 + $1.count }
                // // print("InserterSystem:Miner entity \(minerEntity) at \(pos.tilePosition) has \(itemCount) items in inventory")
            }
        }
        
        world.forEach(InserterComponent.self) { [self] entity, inserter in
            guard let position = world.get(PositionComponent.self, for: entity) else {
                // // print("InserterSystem:Inserter \(entity) has no PositionComponent")
                return
            }
            let power = world.get(PowerConsumerComponent.self, for: entity)
            // Check if inserter is on a power network and has satisfaction > 0
            // Consumers not on a network have networkId = nil and should be considered unpowered
            let hasPower = power != nil && power!.networkId != nil && power!.satisfaction > 0
            
            // Print debug for all inserters (but limit frequency to avoid spam)
            // Only print if inserter has held item, is dropping off, or is in pickingUp state
            if inserter.heldItem != nil || inserter.state == .droppingOff || inserter.state == .pickingUp {
                // // print("InserterSystem:Processing inserter \(entity) at \(position.tilePosition), hasPower=\(hasPower), state=\(inserter.state), type=\(inserter.type), heldItem=\(inserter.heldItem != nil ? "\(inserter.heldItem!.itemId) x\(inserter.heldItem!.count)" : "nil")")
            }
            
            // Update inserter animation (pause if no power, play if powered)
            updateInserterAnimation(entity: entity, deltaTime: deltaTime, hasPower: hasPower)
            
            // Only process inserter logic if powered
            guard hasPower, let power = power else {
                // // print("InserterSystem:Inserter at \(position.tilePosition) skipped - no power")
                return
            }
            
            let speedMultiplier = power.satisfaction
            
            // Validate configured connections at the start of each update
            var updatedInserter = inserter
            
            // Validate input target connection
            if let inputTarget = updatedInserter.inputTarget {
                if !world.isAlive(inputTarget) {
                    updatedInserter.inputTarget = nil
                } else if let targetPos = world.get(PositionComponent.self, for: inputTarget) {
                    let distance = abs(targetPos.tilePosition.x - position.tilePosition.x) + abs(targetPos.tilePosition.y - position.tilePosition.y)
                    if distance > 1 {
                        updatedInserter.inputTarget = nil
                    }
                } else {
                    updatedInserter.inputTarget = nil
                }
            }
            
            // Validate input position connection
            if let inputPos = updatedInserter.inputPosition {
                let distance = abs(inputPos.x - position.tilePosition.x) + abs(inputPos.y - position.tilePosition.y)
                if distance > 1 {
                    updatedInserter.inputPosition = nil
                }
            }
            
            // Validate output target connection
            if let outputTarget = updatedInserter.outputTarget {
                if !world.isAlive(outputTarget) {
                    updatedInserter.outputTarget = nil
                } else if let targetPos = world.get(PositionComponent.self, for: outputTarget) {
                    let distance = abs(targetPos.tilePosition.x - position.tilePosition.x) + abs(targetPos.tilePosition.y - position.tilePosition.y)
                    if distance > 1 {
                        updatedInserter.outputTarget = nil
                    }
                } else {
                    updatedInserter.outputTarget = nil
                }
            }
            
            // Validate output position connection
            if let outputPos = updatedInserter.outputPosition {
                let distance = abs(outputPos.x - position.tilePosition.x) + abs(outputPos.y - position.tilePosition.y)
                if distance > 1 {
                    updatedInserter.outputPosition = nil
                }
            }
            
            inserter = updatedInserter
            
            // // print("InserterSystem:Inserter at \(position.tilePosition) state=\(inserter.state), heldItem=\(inserter.heldItem != nil ? "\(inserter.heldItem!.itemId) x\(inserter.heldItem!.count)" : "nil")")
            
            switch inserter.state {
            case .idle:
                // If holding an item, try to drop it off first
                if inserter.heldItem != nil {
                    // // print("InserterSystem:Inserter at \(position.tilePosition) in idle state but holding item \(inserter.heldItem!.itemId), transitioning to droppingOff")
                    inserter.state = .droppingOff
                    break
                }

                // Unified inserter: can pick up from sources (belts, miners) or machine outputs
                // ONLY use configured input connections - no auto-detection
                if inserter.heldItem == nil {
                    // Check configured input connection first
                    if let inputTarget = inserter.inputTarget {
                        // print("InserterSystem:[idle] Checking inputTarget entity \(inputTarget.id) for items")
                        // Validate target is still alive and adjacent
                        if world.isAlive(inputTarget) {
                            if let targetPos = world.get(PositionComponent.self, for: inputTarget) {
                                let distance = abs(targetPos.tilePosition.x - position.tilePosition.x) + abs(targetPos.tilePosition.y - position.tilePosition.y)
                                if distance <= 1 {
                                    // Check if target is a belt entity first
                                    if world.has(BeltComponent.self, for: inputTarget) {
                                        // print("InserterSystem:[idle] inputTarget is a belt entity, checking for items")
                                        if let belt = world.get(BeltComponent.self, for: inputTarget) {
                                            let hasReadyItem = belt.leftLane.contains { $0.progress >= 0.9 } || belt.rightLane.contains { $0.progress >= 0.9 }
                                            // print("InserterSystem:[idle] Belt has leftLane=\(leftLaneItems) items, rightLane=\(rightLaneItems) items, hasReadyItem=\(hasReadyItem)")
                                            if hasReadyItem {
                                                // print("InserterSystem:[idle] Belt has ready item, transitioning to pickingUp")
                                                inserter.state = .pickingUp
                                            }
                                        }
                                    } else {
                                        // Check if we can pick up from this configured target (non-belt entities)
                                        // Check inventory first, then machine output slots
                                        var canPick = false
                                        if let inventory = world.get(InventoryComponent.self, for: inputTarget) {
                                            canPick = !inventory.isEmpty
                                        }
                                        if !canPick {
                                            // Check machine output slots (second half of inventory)
                                            if let inventory = world.get(InventoryComponent.self, for: inputTarget) {
                                                let outputStartIndex = inventory.slots.count / 2
                                                canPick = (outputStartIndex..<inventory.slots.count).contains { inventory.slots[$0] != nil }
                                            }
                                        }
                                        if canPick {
                                            inserter.state = .pickingUp
                                        }
                                    }
                                } else {
                                    // print("InserterSystem:[idle] inputTarget too far away (distance=\(distance) > 1)")
                                }
                            } else {
                                // print("InserterSystem:[idle] inputTarget has no PositionComponent")
                            }
                        } else {
                            // print("InserterSystem:[idle] inputTarget entity is not alive")
                        }
                    } else if let inputPos = inserter.inputPosition {
                        // Check configured input position (for belts)
                        // print("InserterSystem:Checking canPickUp from configured inputPosition \(inputPos)")
                        if canPickUp(from: inputPos) {
                            // print("InserterSystem:canPickUp returned true, transitioning to pickingUp")
                            inserter.state = .pickingUp
                        } else {
                            // print("InserterSystem:canPickUp returned false for inputPosition \(inputPos)")
                        }
                    }
                    // If no configured input connection, inserter remains idle
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
                
                // // print("InserterSystem:Inserter at \(position.tilePosition) in pickingUp state, armAngle=\(inserter.armAngle), targetAngle=\(targetAngle), angleDiff=\(angleDiff)")
                
                if abs(angleDiff) < rotationSpeed {
                    inserter.armAngle = targetAngle
                    // // print("InserterSystem:Inserter at \(position.tilePosition) arm reached target, trying to pick up")
                    
                    // Try to pick up item
                    if let item = tryPickUp(inserter: &inserter, position: position) {
                        if inserter.sourceEntity != nil {
                            // // print("InserterSystem:Inserter at \(position.tilePosition) successfully picked up \(item.itemId) from source entity")
                        } else {
                            // // print("InserterSystem:Inserter at \(position.tilePosition) successfully picked up \(item.itemId) from belt")
                        }
                        inserter.heldItem = item
                        inserter.state = .rotating
                    } else {
                        // // print("InserterSystem:Inserter at \(position.tilePosition) failed to pick up, returning to idle")
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
                
                // // print("InserterSystem:Inserter at \(position.tilePosition) in rotating state, armAngle=\(inserter.armAngle) (normalized: \(normalizedArmAngle)), targetAngle=\(targetAngle), angleDiff=\(angleDiff), rotationSpeed=\(rotationSpeed)")
                
                // Check if we're close enough to snap to target
                // Also check if we're very close to 0 or 2π (which are the same)
                let distanceToZero = min(abs(normalizedArmAngle), abs(normalizedArmAngle - 2 * .pi))
                // Snap if: within one rotation step, or very close to target, or close to 0/2π
                // Use a larger threshold to ensure we snap when close
                if abs(angleDiff) <= rotationSpeed * 2 || abs(angleDiff) < 0.3 || distanceToZero < 0.3 {
                    inserter.armAngle = targetAngle
                    // // print("InserterSystem:Inserter at \(position.tilePosition) arm reached target (0), transitioning to droppingOff (angleDiff=\(angleDiff), distanceToZero=\(distanceToZero))")
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
                        // // print("InserterSystem:Inserter at \(position.tilePosition) arm passed target, snapping to 0 and transitioning to droppingOff")
                    }
                }
                
            case .droppingOff:
                // Try to drop item
                if let item = inserter.heldItem {
                    // // print("InserterSystem:Inserter at \(position.tilePosition) trying to drop off \(item.itemId)")
                    if tryDropOff(inserter: inserter, position: position, item: item) {
                        // // print("InserterSystem:Inserter at \(position.tilePosition) successfully dropped off item")
                        inserter.heldItem = nil
                        inserter.sourceEntity = nil  // Clear source entity after dropping off
                        inserter.state = .idle
                        inserter.armAngle = 0
                    } else {
                        // // print("InserterSystem:Inserter at \(position.tilePosition) failed to drop off")
                        // Can't drop off (output is full) - keep holding the item and wait
                        // Don't clear heldItem - this allows the inserter to retry when space becomes available
                        // The inserter will stay in .droppingOff state and retry next frame
                        // Don't reset armAngle - keep it at 0 (facing output) while waiting
                    }
                } else {
                    inserter.state = .idle
                }
            }
        }
    }
    
    // MARK: - Pick Up Logic
    
    /// Checks if there's something to pick up from a position
    /// For belts, checks the exact position and all 8 adjacent positions (including diagonals)
    private func canPickUp(from position: IntVector2) -> Bool {
        // Check if there's an item on a belt (check both lanes)
        // First try the exact position
        var beltEntity = beltSystem.getBeltAt(position: position)
        
        // Fallback: if not found, check world entities at this position
        if beltEntity == nil {
            if let entityAtPos = world.getEntityAt(position: position),
               world.has(BeltComponent.self, for: entityAtPos) {
                beltEntity = entityAtPos
                // print("InserterSystem:canPickUp from \(position): belt not in beltGraph, but found via world.getEntityAt")
            }
        }
        
        // If no belt found at exact position, check all 8 adjacent positions (including diagonals)
        if beltEntity == nil {
            let adjacentOffsets: [IntVector2] = [
                IntVector2(0, 1),   // North
                IntVector2(1, 1),   // Northeast
                IntVector2(1, 0),   // East
                IntVector2(1, -1),  // Southeast
                IntVector2(0, -1),  // South
                IntVector2(-1, -1), // Southwest
                IntVector2(-1, 0),  // West
                IntVector2(-1, 1)   // Northwest
            ]
            
            for offset in adjacentOffsets {
                let adjacentPos = position + offset
                beltEntity = beltSystem.getBeltAt(position: adjacentPos)
                
                if beltEntity == nil {
                    if let entityAtPos = world.getEntityAt(position: adjacentPos),
                       world.has(BeltComponent.self, for: entityAtPos) {
                        beltEntity = entityAtPos
                        // print("InserterSystem:canPickUp from \(position): belt found at adjacent position \(adjacentPos)")
                        break
                    }
                } else {
                    // print("InserterSystem:canPickUp from \(position): belt found at adjacent position \(adjacentPos) via beltGraph")
                    break
                }
            }
        }
        
        // Check if there's an entity with inventory that has items
        // For multi-tile buildings, check ALL nearby entities for adjacency (not just ones where position is within bounds)
        // because the miner might be adjacent but the checked position might be outside its bounds
        let nearbyEntities = world.getEntitiesNear(position: Vector2(Float(position.x) + 0.5, Float(position.y) + 0.5), radius: 2.0)
        // // print("InserterSystem:canPickUp from \(position): checking \(nearbyEntities.count) nearby entities")
        
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
                        // // print("InserterSystem:canPickUp from \(position): skipping entity \(entity) at \(entityPos.tilePosition) (has inserter adjacent - drop-off target)")
                        continue
                    }

                    // Check for inventory on buildings that are pickup sources (miners, etc.)
                    if let inventory = world.get(InventoryComponent.self, for: entity) {
                        _ = inventory.slots.compactMap { $0 }.reduce(0) { $0 + $1.count }
                        // // print("InserterSystem:canPickUp from \(position): adjacent entity \(entity) at \(entityPos.tilePosition), hasMiner=\(hasMiner), hasFurnace=\(hasFurnace), has inventory with \(itemCount) items, isEmpty=\(inventory.isEmpty)")
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
                    // // print("InserterSystem:canPickUp from \(position): getEntityAt found entity \(entity) with inventory (\(itemCount) items), isEmpty=\(inventory.isEmpty)")
                    if !inventory.isEmpty {
                        return true
                    }
                } else {
                    // // print("InserterSystem:canPickUp from \(position): getEntityAt found entity \(entity) but no InventoryComponent")
                }
            } else {
                // // print("InserterSystem:canPickUp from \(position): getEntityAt found entity \(entity) but it's a drop-off target")
            }
        } else {
            // // print("InserterSystem:canPickUp from \(position): getEntityAt found no entity")
        }
        
        return false
    }
    
    private func tryPickUp(inserter: inout InserterComponent, position: PositionComponent) -> ItemStack? {
        let item: ItemStack? = nil
 
        // Check configured input connection first
        if let inputTarget = inserter.inputTarget {
            // Validate target is still alive and adjacent
            if world.isAlive(inputTarget) {
                if let targetPos = world.get(PositionComponent.self, for: inputTarget) {
                    let distance = abs(targetPos.tilePosition.x - position.tilePosition.x) + abs(targetPos.tilePosition.y - position.tilePosition.y)
                    if distance <= 1 {
                        // Check if inputTarget is a belt - if so, pick from the belt, not inventory
                        if world.has(BeltComponent.self, for: inputTarget) {
                            // print("InserterSystem:inputTarget is a belt entity, using tryPickFromBeltEntity")
                            if let pickedItem = tryPickFromBeltEntity(entity: inputTarget) {
                                // print("InserterSystem:Successfully picked up \(pickedItem.itemId) from belt entity")
                                inserter.sourceEntity = nil  // Belts don't have entities to track
                                return pickedItem
                            } else {
                                // print("InserterSystem:Failed to pick up from belt entity")
                            }
                        } else {
                            // print("InserterSystem:inputTarget is adjacent (distance=\(distance)), checking inventory")
                            // Directly access the configured target entity's inventory
                            if var inventory = world.get(InventoryComponent.self, for: inputTarget) {
                                if let item = inventory.takeOne() {
                                    // print("InserterSystem:Successfully picked up \(item.itemId) from inputTarget")
                                    inserter.sourceEntity = inputTarget
                                    world.add(inventory, to: inputTarget)
                                    return item
                                } else {
                                    // print("InserterSystem:inputTarget inventory is empty")
                                }
                            } else {
                                // print("InserterSystem:inputTarget has no InventoryComponent")
                            }
                            // Also try machine output (for machines with separate output slots)
                            if let pickedItem = tryPickFromMachineOutput(entity: inputTarget, stackSize: inserter.stackSize) {
                                // print("InserterSystem:Successfully picked up from machine output")
                                inserter.sourceEntity = inputTarget
                                return pickedItem
                            }
                        }
                    } else {
                        // print("InserterSystem:inputTarget too far away (distance=\(distance))")
                    }
                } else {
                    // print("InserterSystem:inputTarget has no PositionComponent")
                }
            } else {
                // print("InserterSystem:inputTarget entity is not alive")
            }
        } else {
            // print("InserterSystem:No inputTarget configured")
        }
        
        // Check configured input position (for belts)
        // Check the exact position first, then all 8 adjacent positions including diagonals
        if item == nil, let inputPos = inserter.inputPosition {
            // print("InserterSystem:Trying to pick from belt at configured inputPosition \(inputPos)")
            // First try the exact configured position
            if let pickedItem = tryPickFromBelt(at: inputPos, stackSize: inserter.stackSize) {
                // print("InserterSystem:Successfully picked up from belt at exact position")
                inserter.sourceEntity = nil  // Belts don't have entities to track
                return pickedItem
            }
            
            // print("InserterSystem:No item found at exact position, checking adjacent positions")
            // If not found at exact position, check all 8 adjacent positions (including diagonals)
            let adjacentOffsets: [IntVector2] = [
                IntVector2(0, 1),   // North
                IntVector2(1, 1),   // Northeast
                IntVector2(1, 0),   // East
                IntVector2(1, -1),  // Southeast
                IntVector2(0, -1),  // South
                IntVector2(-1, -1), // Southwest
                IntVector2(-1, 0),  // West
                IntVector2(-1, 1)   // Northwest
            ]
            
            for offset in adjacentOffsets {
                let adjacentPos = inputPos + offset
                // Validate that this adjacent position is within 1 tile of the inserter (including diagonals)
                // This ensures we only check positions that the inserter can actually reach
                let distanceFromInserter = abs(adjacentPos.x - position.tilePosition.x) + abs(adjacentPos.y - position.tilePosition.y)
                if distanceFromInserter <= 1 {
                    if let pickedItem = tryPickFromBelt(at: adjacentPos, stackSize: inserter.stackSize) {
                        // Found a belt at an adjacent position, use it
                        // print("InserterSystem:Successfully picked up from belt at adjacent position \(adjacentPos)")
                        inserter.sourceEntity = nil  // Belts don't have entities to track
                        // Update inputPosition to the actual belt position so we remember it
                        inserter.inputPosition = adjacentPos
                        return pickedItem
                    }
                }
            }
            // print("InserterSystem:Failed to pick up from belt at inputPosition \(inputPos) or adjacent positions")
        }
        
        // Only use configured input connections - no auto-detection
        // If no configured connection or connection failed, return nil
        return nil
    }
    
    /// Picks an item directly from a belt entity (when we have the entity reference)
    private func tryPickFromBeltEntity(entity: Entity) -> ItemStack? {
        guard world.has(BeltComponent.self, for: entity),
              var belt = world.get(BeltComponent.self, for: entity) else {
            // print("InserterSystem:tryPickFromBeltEntity - entity does not have BeltComponent")
            return nil
        }
        
        // Try left lane first, then right
        for lane in [BeltLane.left, BeltLane.right] {
            if let beltItem = belt.takeItem(from: lane) {
                world.add(belt, to: entity)
                let maxStack = itemRegistry.get(beltItem.itemId)?.stackSize ?? 100
                // print("InserterSystem:Successfully picked up \(beltItem.itemId) from belt entity \(entity.id) lane \(lane == .left ? "left" : "right")")
                return ItemStack(itemId: beltItem.itemId, count: 1, maxStack: maxStack)
            }
        }
        
        // print("InserterSystem:tryPickFromBeltEntity - belt entity \(entity.id) has no items ready")
        return nil
    }
    
    private func tryPickFromBelt(at position: IntVector2, stackSize: Int) -> ItemStack? {
        // First try BeltSystem's takeItem (fast lookup)
        // Try left lane first, then right
        for lane in [BeltLane.left, BeltLane.right] {
            if let beltItem = beltSystem.takeItem(at: position, lane: lane) {
                let maxStack = itemRegistry.get(beltItem.itemId)?.stackSize ?? 100
                return ItemStack(itemId: beltItem.itemId, count: 1, maxStack: maxStack)
            }
        }
        
        // Fallback: if BeltSystem didn't find it, check world entities at this position
        // This handles cases where belts aren't registered in beltGraph (e.g., after loading saved games)
        if let beltEntity = world.getEntityAt(position: position),
           world.has(BeltComponent.self, for: beltEntity),
           var belt = world.get(BeltComponent.self, for: beltEntity) {
            // Try to take from belt directly
            for lane in [BeltLane.left, BeltLane.right] {
                if let beltItem = belt.takeItem(from: lane) {
                    world.add(belt, to: beltEntity)
                    let maxStack = itemRegistry.get(beltItem.itemId)?.stackSize ?? 100
                    return ItemStack(itemId: beltItem.itemId, count: 1, maxStack: maxStack)
                }
            }
        }
        
        return nil
    }
    
    private func canPickUpFromEntity(_ entity: Entity) -> Bool {
        if let inventory = world.get(InventoryComponent.self, for: entity) {
            return !inventory.isEmpty
        }
        return false
    }
    
    private func tryPickFromMachineOutput(entity: Entity, stackSize: Int) -> ItemStack? {
        guard var inventory = world.get(InventoryComponent.self, for: entity) else { return nil }
        
        // For machines, check output slots (second half of inventory)
        let outputStartIndex = inventory.slots.count / 2
        for index in outputStartIndex..<inventory.slots.count {
            if var stack = inventory.slots[index] {
                // Take one item from this slot
                let taken = ItemStack(itemId: stack.itemId, count: 1, maxStack: stack.maxStack)
                stack.count -= 1
                if stack.count == 0 {
                    inventory.slots[index] = nil
                } else {
                    inventory.slots[index] = stack
                }
                world.add(inventory, to: entity)
                return taken
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
                            // // print("InserterSystem:tryPickFromInventory picked item \(item.itemId) from entity \(entity) at \(entityPos.tilePosition)")
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
            // // print("InserterSystem:tryPickFromInventory picked item \(item.itemId) from entity \(entity) at position \(position)")
            sourceEntity = entity  // Track source entity
            world.add(inventory, to: entity)
            return item
        }
        
        return nil
    }
    
    // MARK: - Drop Off Logic
    
    private func tryDropOff(inserter: InserterComponent, position: PositionComponent, item: ItemStack) -> Bool {
        var success = false
        
        // print("InserterSystem:tryDropOff called for inserter at \(position.tilePosition) with item \(item.itemId), outputTarget=\(inserter.outputTarget?.id ?? 0), outputPosition=\(inserter.outputPosition != nil ? "(\(inserter.outputPosition!.x), \(inserter.outputPosition!.y))" : "nil")")
        
        // Check configured output connection first
        if let outputTarget = inserter.outputTarget {
            // Connection should already be validated, but check one more time
            if world.isAlive(outputTarget) {
                if let targetPos = world.get(PositionComponent.self, for: outputTarget) {
                    // Validate adjacency one more time
                    let distance = abs(targetPos.tilePosition.x - position.tilePosition.x) + abs(targetPos.tilePosition.y - position.tilePosition.y)
                    if distance <= 1 {
                        // Check if outputTarget is a belt - if so, drop on the belt, not in inventory
                        let hasBelt = world.has(BeltComponent.self, for: outputTarget)
                        let hasInventory = world.has(InventoryComponent.self, for: outputTarget)
                        // print("InserterSystem:outputTarget entity check - hasBelt=\(hasBelt), hasInventory=\(hasInventory)")
                        
                        if hasBelt {
                            // print("InserterSystem:outputTarget is a belt entity, dropping directly to belt")
                            if tryDropOnBeltEntity(entity: outputTarget, item: item) {
                                // print("InserterSystem:Successfully dropped to outputTarget belt entity")
                                success = true
                            } else {
                                // print("InserterSystem:Failed to drop to outputTarget belt entity")
                            }
                        } else if hasInventory {
                            // Try to drop to this configured target (for entities with inventory)
                            // print("InserterSystem:outputTarget has inventory, using tryDropInInventory")
                            if tryDropInInventory(at: targetPos.tilePosition, item: item, excludeEntity: inserter.sourceEntity, targetEntity: outputTarget) {
                                // print("InserterSystem:Successfully dropped to outputTarget entity")
                                success = true
                            } else {
                                // print("InserterSystem:Failed to drop to outputTarget entity")
                            }
                        } else {
                            // print("InserterSystem:outputTarget has neither BeltComponent nor InventoryComponent")
                        }
                    } else {
                        // print("InserterSystem:outputTarget too far away (distance=\(distance))")
                    }
                } else {
                    // print("InserterSystem:outputTarget has no PositionComponent")
                }
            } else {
                // print("InserterSystem:outputTarget entity is not alive")
            }
        }
        
        // Check configured output position (for belts)
        // Check the exact position first, then all 8 adjacent positions including diagonals
        if !success, let outputPos = inserter.outputPosition {
            // print("InserterSystem:Trying to drop on belt at configured position \(outputPos)")
            // First try the exact configured position
            if tryDropOnBelt(at: outputPos, item: item, inserterPosition: position.tilePosition) {
                // print("InserterSystem:Successfully dropped on belt at exact position")
                success = true
            } else {
                // print("InserterSystem:Failed to drop at exact position, checking adjacent positions")
                // If not found at exact position, check all 8 adjacent positions (including diagonals)
                let adjacentOffsets: [IntVector2] = [
                    IntVector2(0, 1),   // North
                    IntVector2(1, 1),   // Northeast
                    IntVector2(1, 0),   // East
                    IntVector2(1, -1),  // Southeast
                    IntVector2(0, -1),  // South
                    IntVector2(-1, -1), // Southwest
                    IntVector2(-1, 0),  // West
                    IntVector2(-1, 1)   // Northwest
                ]
                
                for offset in adjacentOffsets {
                    let adjacentPos = outputPos + offset
                    // Validate that this adjacent position is within 1 tile of the inserter (including diagonals)
                    let distanceFromInserter = abs(adjacentPos.x - position.tilePosition.x) + abs(adjacentPos.y - position.tilePosition.y)
                    if distanceFromInserter <= 1 {
                        if tryDropOnBelt(at: adjacentPos, item: item, inserterPosition: position.tilePosition) {
                            // print("InserterSystem:Successfully dropped on belt at adjacent position \(adjacentPos)")
                            success = true
                            break
                        }
                    }
                }
                if !success {
                    // print("InserterSystem:Failed to drop on belt at any position")
                }
            }
        } else if !success {
            // print("InserterSystem:No outputTarget or outputPosition configured")
        }
        
        // Only use configured output connections - no auto-detection
        // If no configured connection or connection failed, return false
        // print("InserterSystem:tryDropOff returning \(success)")
        return success
    }
    
    /// Drops an item directly on a belt entity (when we have the entity reference)
    private func tryDropOnBeltEntity(entity: Entity, item: ItemStack) -> Bool {
        guard world.has(BeltComponent.self, for: entity),
              var belt = world.get(BeltComponent.self, for: entity) else {
            // print("InserterSystem:tryDropOnBeltEntity - entity does not have BeltComponent")
            return false
        }
        
        // Check which lane has space
        for lane in [BeltLane.left, BeltLane.right] {
            if belt.addItem(item.itemId, lane: lane, position: 0) {
                world.add(belt, to: entity)
                // print("InserterSystem:Successfully dropped \(item.itemId) on belt entity \(entity.id) via direct access")
                return true
            }
        }
        
        // print("InserterSystem:tryDropOnBeltEntity - belt entity \(entity.id) has no space in either lane")
        return false
    }
    
    /// Drops an item on a belt at a specific position (searches for the belt)
    private func tryDropOnBelt(at position: IntVector2, item: ItemStack, inserterPosition: IntVector2) -> Bool {
        // First try BeltSystem's addItem (fast lookup)
        // Check which lane has space
        for lane in [BeltLane.left, BeltLane.right] {
            if beltSystem.hasSpace(at: position, lane: lane) {
                if beltSystem.addItem(item.itemId, at: position, lane: lane) {
                    // print("InserterSystem:Successfully dropped \(item.itemId) on belt at \(position) via beltSystem")
                    return true
                }
            }
        }
        
        // Fallback: if BeltSystem didn't find it, check world entities at this position
        // This handles cases where belts aren't registered in beltGraph (e.g., after loading saved games)
        if let beltEntity = world.getEntityAt(position: position),
           world.has(BeltComponent.self, for: beltEntity),
           var belt = world.get(BeltComponent.self, for: beltEntity) {
            // Check which lane has space
            for lane in [BeltLane.left, BeltLane.right] {
                if belt.addItem(item.itemId, lane: lane, position: 0) {
                    world.add(belt, to: beltEntity)
                    // print("InserterSystem:Successfully dropped \(item.itemId) on belt at \(position) via world entity")
                    return true
                }
            }
            // print("InserterSystem:Belt found at \(position) but no space in either lane")
        } else {
            // Also check all entities at this position (might be multiple if belt is under a building)
            let entitiesAtPos = world.getAllEntitiesAt(position: position)
            for beltEntity in entitiesAtPos {
                if world.has(BeltComponent.self, for: beltEntity),
                   var belt = world.get(BeltComponent.self, for: beltEntity) {
                    // Check which lane has space
                    for lane in [BeltLane.left, BeltLane.right] {
                        if belt.addItem(item.itemId, lane: lane, position: 0) {
                            world.add(belt, to: beltEntity)
                            // print("InserterSystem:Successfully dropped \(item.itemId) on belt at \(position) via getAllEntitiesAt")
                            return true
                        }
                    }
                }
            }
            // print("InserterSystem:No belt found at \(position) (checked getEntityAt and getAllEntitiesAt)")
        }
        
        return false
    }
    
    private func tryDropInInventory(at position: IntVector2, item: ItemStack, excludeEntity: Entity?, targetEntity: Entity) -> Bool {
        // Only drop to the specific configured target entity
        // This ensures inserters only output to the entity selected via inserterConnectionDialog
        
        // Skip if this is the source entity (don't drop back to where we picked up from)
        if let excludeEntity = excludeEntity, targetEntity.id == excludeEntity.id && targetEntity.generation == excludeEntity.generation {
            return false
        }
        
        // Validate the target entity is still alive
        guard world.isAlive(targetEntity) else { return false }
        
        // Get the target entity's position
        guard let targetPos = world.get(PositionComponent.self, for: targetEntity) else { return false }
        
        // Check if the target entity is adjacent to the position we're checking
        // For multi-tile buildings, check if the position is within or adjacent to the building
        var isAdjacent = false
        if let sprite = world.get(SpriteComponent.self, for: targetEntity) {
            // Building occupies multiple tiles based on sprite size
            let buildingWidth = Int(ceil(sprite.size.x))
            let buildingHeight = Int(ceil(sprite.size.y))

            // Check if position is within or adjacent to any tile of the building
            for dy in 0..<buildingHeight {
                for dx in 0..<buildingWidth {
                    let buildingTileX = targetPos.tilePosition.x + Int32(dx)
                    let buildingTileY = targetPos.tilePosition.y + Int32(dy)
                    let distance = abs(buildingTileX - position.x) + abs(buildingTileY - position.y)
                    if distance <= 1 {
                        isAdjacent = true
                        break
                    }
                }
                if isAdjacent { break }
            }
        } else {
            // Single-tile entity - check if position is adjacent (within 1 tile including diagonals)
            let distance = abs(targetPos.tilePosition.x - position.x) + abs(targetPos.tilePosition.y - position.y)
            isAdjacent = distance <= 1
        }
        
        guard isAdjacent else { return false }
        
        // Check if entity has inventory that can accept the item
        guard var inventory = world.get(InventoryComponent.self, for: targetEntity) else { return false }
        guard inventory.canAccept(itemId: item.itemId) else { return false }
        
        // Drop the item
        let remaining = inventory.add(item)
        world.add(inventory, to: targetEntity)
        return remaining == 0
    }

    /// Checks if there's something to pick up from machine output at a position
    private func canPickUpFromMachineOutput(at position: IntVector2) -> Bool {
        // Check if there's an entity with inventory that has output items
        // For multi-tile buildings, check ALL nearby entities for adjacency
        let nearbyEntities = world.getEntitiesNear(position: Vector2(Float(position.x) + 0.5, Float(position.y) + 0.5), radius: 2.0)
        // // print("InserterSystem:canPickUpFromMachineOutput at \(position): checking \(nearbyEntities.count) nearby entities")

        // First, try to find any machine with output items that's adjacent
        for entity in nearbyEntities {
            if let entityPos = world.get(PositionComponent.self, for: entity) {
                let distance = abs(entityPos.tilePosition.x - position.x) + abs(entityPos.tilePosition.y - position.y)

                // Check if entity is adjacent (within 1 tile in any direction, including diagonals)
                if distance <= 1 {
                    // Check for inventory on machines (furnaces, assemblers)
                    if let inventory = world.get(InventoryComponent.self, for: entity) {
                        // For machines, check output slots (second half of inventory)
                        let outputStartIndex = inventory.slots.count / 2
                        let hasOutputItems = (outputStartIndex..<inventory.slots.count).contains { index in
                            inventory.slots[index] != nil
                        }
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

        // // print("InserterSystem:hasInserterAdjacent for entity at \(entityPos.tilePosition) (size: \(positionsToCheck.count) tiles)")

        // Check all 8 adjacent positions for each tile the building occupies
        let offsets = [
            IntVector2(0, 1), IntVector2(1, 1), IntVector2(1, 0), IntVector2(1, -1),
            IntVector2(0, -1), IntVector2(-1, -1), IntVector2(-1, 0), IntVector2(-1, 1)
        ]
        for buildingPos in positionsToCheck {
            // print("InserterSystem: checking building tile \(buildingPos)")
            for offset in offsets {
                let checkPos = buildingPos + offset

                // Skip positions that are within the building's own bounds
                if positionsToCheck.contains(checkPos) {
                    // print("InserterSystem:   skipping position \(checkPos) (within building bounds)")
                    continue
                }

                // print("InserterSystem:   checking position \(checkPos) for inserter")
                if let entityAtPos = world.getEntityAt(position: checkPos) {
                    // print("InserterSystem:     found entity \(entityAtPos) at \(checkPos)")
                    if world.has(InserterComponent.self, for: entityAtPos) {
                        // print("InserterSystem:     entity has InserterComponent - INSERTER CONNECTED!")
                        return true
                    } else {
                        // print("InserterSystem:     entity does NOT have InserterComponent")
                    }
                } else {
                    // print("InserterSystem:     no entity at \(checkPos)")
                }
            }
        }

        // print("InserterSystem: no inserters found adjacent")
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

