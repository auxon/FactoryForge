import Foundation

/// System that handles inserter item transfers between machines and belts
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
        var inserterUpdates: [Entity: InserterComponent] = [:]

        world.forEach(InserterComponent.self) { [self] entity, inserter in
            guard let position = world.get(PositionComponent.self, for: entity) else { return }

            // Check power status
            let power = world.get(PowerConsumerComponent.self, for: entity)
            let hasPower = power != nil && power!.networkId != nil && power!.satisfaction > 0

            // Update animation
            updateInserterAnimation(entity: entity, deltaTime: deltaTime, hasPower: hasPower)

            // Skip if no power
            guard hasPower else { return }

            // Update inserter speed if needed (migration)
            var updatedInserter = inserter
            if updatedInserter.speed != 4.0 {
                updatedInserter.speed = 4.0
            }

            // Validate connections
            updatedInserter = validateConnections(updatedInserter, inserterPosition: position.tilePosition)

            // Process state machine
            let result = processState(updatedInserter, entity: entity, position: position, deltaTime: deltaTime, power: power)
            updatedInserter = result.inserter

            // Collect update to apply later
            inserterUpdates[entity] = updatedInserter
        }

        // Apply all updates after iteration to avoid concurrency violations
        for (entity, updatedInserter) in inserterUpdates {
            world.add(updatedInserter, to: entity)
        }
    }

    // MARK: - Connection Validation

    private func validateConnections(_ inserter: InserterComponent, inserterPosition: IntVector2) -> InserterComponent {
        var updatedInserter = inserter

        // Validate input target
        if let inputTarget = updatedInserter.inputTarget {
            if !world.isAlive(inputTarget) {
                updatedInserter.inputTarget = nil
            } else if let targetPos = world.get(PositionComponent.self, for: inputTarget) {
                if !isWithinRange(inserterPosition, targetPosition: targetPos.tilePosition) {
                    updatedInserter.inputTarget = nil
                }
            } else {
                updatedInserter.inputTarget = nil
            }
        }

        // Validate input position (belt)
        if let inputPos = updatedInserter.inputPosition {
            if !isWithinRange(inserterPosition, targetPosition: inputPos) {
                updatedInserter.inputPosition = nil
            } else {
                // Check if belt still exists
                let entitiesAtPos = world.getAllEntitiesAt(position: inputPos)
                let hasBelt = entitiesAtPos.contains { world.has(BeltComponent.self, for: $0) }
                if !hasBelt {
                    updatedInserter.inputPosition = nil
                }
            }
        }

        // Validate output target
        if let outputTarget = updatedInserter.outputTarget {
            if !world.isAlive(outputTarget) {
                updatedInserter.outputTarget = nil
            } else if let targetPos = world.get(PositionComponent.self, for: outputTarget) {
                if !isWithinRange(inserterPosition, targetPosition: targetPos.tilePosition) {
                    updatedInserter.outputTarget = nil
                }
            } else {
                updatedInserter.outputTarget = nil
            }
        }

        // Validate output position (belt)
        if let outputPos = updatedInserter.outputPosition {
            if !isWithinRange(inserterPosition, targetPosition: outputPos) {
                updatedInserter.outputPosition = nil
            } else {
                // Check if belt still exists
                let entitiesAtPos = world.getAllEntitiesAt(position: outputPos)
                let hasBelt = entitiesAtPos.contains { world.has(BeltComponent.self, for: $0) }
                if !hasBelt {
                    updatedInserter.outputPosition = nil
                }
            }
        }

        return updatedInserter
    }

    private func isWithinRange(_ pos1: IntVector2, targetPosition pos2: IntVector2) -> Bool {
        let distance = abs(pos2.x - pos1.x) + abs(pos2.y - pos1.y)
        return distance <= 4
    }

    // MARK: - State Processing

    private struct StateResult {
        let inserter: InserterComponent
    }

    private func processState(_ inserter: InserterComponent, entity: Entity, position: PositionComponent, deltaTime: Float, power: PowerConsumerComponent?) -> StateResult {
        var updatedInserter = inserter

        switch inserter.state {
        case .idle:
            updatedInserter = processIdleState(updatedInserter, position: position)

        case .pickingUp:
            updatedInserter = processPickingUpState(updatedInserter, position: position, deltaTime: deltaTime, power: power)

        case .rotating:
            updatedInserter = processRotatingState(updatedInserter, position: position, deltaTime: deltaTime, power: power)

        case .droppingOff:
            updatedInserter = processDroppingOffState(updatedInserter, position: position, deltaTime: deltaTime)
        }

        return StateResult(inserter: updatedInserter)
    }

    // MARK: - State Processing Helpers

    private func processIdleState(_ inserter: InserterComponent, position: PositionComponent) -> InserterComponent {
        var updatedInserter = inserter

        // If holding an item, try to drop it off first
        if updatedInserter.heldItem != nil {
            updatedInserter.state = .droppingOff
            updatedInserter.dropTimeout = 0
            return updatedInserter
        }

        // Check configured input connections
        if updatedInserter.heldItem == nil {
            if let inputTarget = updatedInserter.inputTarget, canPickUpFromTarget(inputTarget) {
                updatedInserter.state = .pickingUp
            } else if let inputPos = updatedInserter.inputPosition, canPickUp(from: inputPos) {
                updatedInserter.state = .pickingUp
            }
        }

        return updatedInserter
    }

    private func canPickUpFromTarget(_ target: Entity) -> Bool {
        // Check if target is a belt
        if world.has(BeltComponent.self, for: target) {
            if let belt = world.get(BeltComponent.self, for: target) {
                let hasReadyItem = belt.leftLane.contains { $0.progress >= 0.9 } || belt.rightLane.contains { $0.progress >= 0.9 }
                return hasReadyItem
            }
        } else {
            // Check if target is a machine with output items
            if let inventory = world.get(InventoryComponent.self, for: target) {
                let hasFurnace = world.has(FurnaceComponent.self, for: target)
                let hasAssembler = world.has(AssemblerComponent.self, for: target)
                let isMachine = hasFurnace || hasAssembler

                if isMachine {
                    let outputStartIndex = hasFurnace ? 2 : inventory.slots.count / 2
                    let outputEndIndex = hasFurnace ? 3 : inventory.slots.count - 1
                    return (outputStartIndex...outputEndIndex).contains { inventory.slots[$0] != nil }
                } else {
                    // For non-machines (miners, chests)
                    return !inventory.isEmpty
                }
            }
        }

        return false
    }

    private func processPickingUpState(_ inserter: InserterComponent, position: PositionComponent, deltaTime: Float, power: PowerConsumerComponent?) -> InserterComponent {
        var updatedInserter = inserter

        // Get power for speed multiplier
        let speedMultiplier = power?.satisfaction ?? 1.0

        // Rotate arm towards source
        let rotationSpeed = updatedInserter.speed * speedMultiplier * deltaTime * Float.pi * 2
        let targetAngle: Float = Float.pi

        // Calculate angle difference
        var angleDiff = targetAngle - updatedInserter.armAngle
        while angleDiff > Float.pi { angleDiff -= 2 * Float.pi }
        while angleDiff < -Float.pi { angleDiff += 2 * Float.pi }

        // Check if arm reached target
        if abs(angleDiff) < rotationSpeed {
            updatedInserter.armAngle = targetAngle

            // Try to pick up item
            if let item = tryPickUp(inserter: &updatedInserter, position: position) {
                updatedInserter.heldItem = item
                updatedInserter.state = .rotating
            } else {
                // Nothing to pick up, return to idle
                updatedInserter.armAngle = 0
                updatedInserter.state = .idle
            }
        } else {
            // Continue rotating
            updatedInserter.armAngle += angleDiff > 0 ? rotationSpeed : -rotationSpeed

            // Normalize angle
            while updatedInserter.armAngle < 0 { updatedInserter.armAngle += 2 * Float.pi }
            while updatedInserter.armAngle >= 2 * Float.pi { updatedInserter.armAngle -= 2 * Float.pi }
        }

        return updatedInserter
    }

    private func processRotatingState(_ inserter: InserterComponent, position: PositionComponent, deltaTime: Float, power: PowerConsumerComponent?) -> InserterComponent {
        var updatedInserter = inserter

        // Get power for speed multiplier
        let speedMultiplier = power?.satisfaction ?? 1.0

        // Rotate arm towards target (0 degrees)
        let rotationSpeed = updatedInserter.speed * speedMultiplier * deltaTime * Float.pi * 2
        let targetAngle: Float = 0

        // Normalize current angle
        var normalizedAngle = updatedInserter.armAngle
        while normalizedAngle < 0 { normalizedAngle += 2 * Float.pi }
        while normalizedAngle >= 2 * Float.pi { normalizedAngle -= 2 * Float.pi }

        // Calculate angle difference
        var angleDiff = targetAngle - normalizedAngle
        while angleDiff > Float.pi { angleDiff -= 2 * Float.pi }
        while angleDiff < -Float.pi { angleDiff += 2 * Float.pi }

        // Check if arm reached target
        if abs(angleDiff) < rotationSpeed * 2 || abs(angleDiff) < 0.3 || abs(normalizedAngle) < 0.3 {
            updatedInserter.armAngle = targetAngle
            updatedInserter.state = .droppingOff
            updatedInserter.dropTimeout = 0
        } else {
            // Continue rotating
            let newAngle = normalizedAngle + (angleDiff > 0 ? rotationSpeed : -rotationSpeed)

            // Normalize
            var finalAngle = newAngle
            while finalAngle < 0 { finalAngle += 2 * Float.pi }
            while finalAngle >= 2 * Float.pi { finalAngle -= 2 * Float.pi }

            updatedInserter.armAngle = finalAngle
        }

        return updatedInserter
    }

    private func processDroppingOffState(_ inserter: InserterComponent, position: PositionComponent, deltaTime: Float) -> InserterComponent {
        var updatedInserter = inserter

        if let item = updatedInserter.heldItem {
            if tryDropOff(inserter: updatedInserter, position: position, item: item) {
                updatedInserter.heldItem = nil
                updatedInserter.sourceEntity = nil
                updatedInserter.dropTimeout = 0
                updatedInserter.state = .idle
                updatedInserter.armAngle = 0
            } else {
                // Can't drop, increment timeout
                updatedInserter.dropTimeout += deltaTime

                // If timeout exceeded, put item back to source
                let dropTimeoutLimit: Float = 10.0
                if updatedInserter.dropTimeout >= dropTimeoutLimit {
                    if let sourceEntity = updatedInserter.sourceEntity, tryPutBackToSource(inserter: &updatedInserter, sourceEntity: sourceEntity, item: item) {
                        updatedInserter.heldItem = nil
                        updatedInserter.sourceEntity = nil
                        updatedInserter.dropTimeout = 0
                        updatedInserter.state = .idle
                        updatedInserter.armAngle = 0
                    } else {
                        // Couldn't put back, keep trying
                        updatedInserter.dropTimeout = 0
                    }
                }
            }
        } else {
            updatedInserter.state = .idle
            updatedInserter.dropTimeout = 0
        }

        return updatedInserter
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
                        break
                    }
                } else {
                    break
                }
            }
        }
        
        // Check if there's an entity with inventory that has items
        // For multi-tile buildings, check ALL nearby entities for adjacency (not just ones where position is within bounds)
        // because the miner might be adjacent but the checked position might be outside its bounds
        let nearbyEntities = world.getEntitiesNear(position: Vector2(Float(position.x) + 0.5, Float(position.y) + 0.5), radius: 2.0)
        
        // First, try to find any miner or building with inventory that's adjacent (within 1 tile)
        for entity in nearbyEntities {
            if let entityPos = world.get(PositionComponent.self, for: entity) {
                let distance = abs(entityPos.tilePosition.x - position.x) + abs(entityPos.tilePosition.y - position.y)
                
                // Check if entity is adjacent (within 1 tile in any direction, including diagonals)
                if distance <= 2 {
                    _ = world.has(MinerComponent.self, for: entity)
                    _ = world.has(FurnaceComponent.self, for: entity)

                    // Don't pick up from entities that have inserters adjacent (drop-off targets)
                    // But allow pickup from miners, which are always valid sources
                    let hasInserterAdjacent = self.hasInserterAdjacent(to: entity)
                    if hasInserterAdjacent && !world.has(MinerComponent.self, for: entity) {
                        continue
                    }

                    // Check for inventory on buildings that are pickup sources (miners, etc.)
                    if let inventory = world.get(InventoryComponent.self, for: entity) {
                        _ = inventory.slots.compactMap { $0 }.reduce(0) { $0 + $1.count }
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
                    if !inventory.isEmpty {
                        return true
                    }
                } else {
                }
            } else {
            }
        } else {
        }
        
        return false
    }
    
    private func tryPickUp(inserter: inout InserterComponent, position: PositionComponent) -> ItemStack? {
 
        // Check configured input connection first
        if let inputTarget = inserter.inputTarget {
            // Validate target is still alive and adjacent
            if world.isAlive(inputTarget) {
                if let targetPos = world.get(PositionComponent.self, for: inputTarget) {
                    let distance = abs(targetPos.tilePosition.x - position.tilePosition.x) + abs(targetPos.tilePosition.y - position.tilePosition.y)
                    if distance <= 4 {
                        // Check if inputTarget is a belt - if so, pick from the belt, not inventory
                        if world.has(BeltComponent.self, for: inputTarget) {
                            if let pickedItem = tryPickFromBeltEntity(entity: inputTarget) {
                                inserter.sourceEntity = nil  // Belts don't have entities to track
                                return pickedItem
                            } else {
                            }
                        } else {
                            // Check if target is a machine (furnace, assembler) that has separate input/output slots
                            let hasFurnace = world.has(FurnaceComponent.self, for: inputTarget)
                            let hasAssembler = world.has(AssemblerComponent.self, for: inputTarget)
                            let isMachine = hasFurnace || hasAssembler

                            if isMachine {
                                // For machines, only pick from output slots
                                if let pickedItem = tryPickFromMachineOutput(entity: inputTarget, stackSize: inserter.stackSize) {
                                    inserter.sourceEntity = inputTarget
                                    return pickedItem
                                } else {
                                }
                            } else {
                                // For non-machines (miners, chests, etc.), pick from any slot
                                if var inventory = world.get(InventoryComponent.self, for: inputTarget) {
                                    if let item = inventory.takeOne() {
                                        inserter.sourceEntity = inputTarget
                                        world.add(inventory, to: inputTarget)
                                        return item
                                    }
                                }
                            }
                        }
                    } else {
                    }
                } else {
                }
            } else {
            }
        } else {
        }
        
        // Check configured input position (for belts)
        // Check the exact position first, then all 8 adjacent positions including diagonals
        if let inputPos = inserter.inputPosition {
            // First try the exact configured position
            if let pickedItem = tryPickFromBelt(at: inputPos, stackSize: inserter.stackSize) {
                inserter.sourceEntity = nil  // Belts don't have entities to track
                return pickedItem
            }
            
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
                if distanceFromInserter <= 2 {
                    if let pickedItem = tryPickFromBelt(at: adjacentPos, stackSize: inserter.stackSize) {
                        // Found a belt at an adjacent position, use it
                        inserter.sourceEntity = nil  // Belts don't have entities to track
                        // Update inputPosition to the actual belt position so we remember it
                        inserter.inputPosition = adjacentPos
                        return pickedItem
                    }
                }
            }
        }
        
        // Only use configured input connections - no auto-detection
        // If no configured connection or connection failed, return nil
        return nil
    }

    /// Try to put an item back to its source entity
    private func tryPutBackToSource(inserter: inout InserterComponent, sourceEntity: Entity, item: ItemStack) -> Bool {
        // Only put back if the source can accept the item
        guard var inventory = world.get(InventoryComponent.self, for: sourceEntity) else { return false }

        // Check if source is a machine with input/output slots
        let isMachine = world.has(FurnaceComponent.self, for: sourceEntity) ||
                       world.has(AssemblerComponent.self, for: sourceEntity)

        if isMachine {
            // For machines, we picked from output slots, so prefer to put back to output slots
            let outputStartIndex = inventory.slots.count / 2
            var remaining = item.count

            // First, try to add to existing output stacks
            for i in outputStartIndex..<inventory.slots.count {
                if var slot = inventory.slots[i], slot.itemId == item.itemId && slot.count < slot.maxStack {
                    let space = slot.maxStack - slot.count
                    let toAdd = min(space, remaining)
                    slot.count += toAdd
                    inventory.slots[i] = slot
                    remaining -= toAdd
                    if remaining == 0 { break }
                }
            }

            // Then add to empty output slots
            if remaining > 0 {
                for i in outputStartIndex..<inventory.slots.count {
                    if inventory.slots[i] == nil {
                        let toAdd = min(item.maxStack, remaining)
                        inventory.slots[i] = ItemStack(itemId: item.itemId, count: toAdd, maxStack: item.maxStack)
                        remaining -= toAdd
                        if remaining == 0 { break }
                    }
                }
            }

            // If output slots are full, fall back to any available slot (including input slots)
            // This prevents item loss when the machine is overproducing
            if remaining > 0 {
                let fallbackRemaining = inventory.add(ItemStack(itemId: item.itemId, count: remaining, maxStack: item.maxStack))
                remaining = fallbackRemaining
            }

            world.add(inventory, to: sourceEntity)
            return remaining == 0
        } else {
            // For regular entities, just add back normally
            guard inventory.canAccept(itemId: item.itemId) else { return false }

            let remaining = inventory.add(item)
            world.add(inventory, to: sourceEntity)
            return remaining == 0
        }
    }

    /// Picks an item directly from a belt entity (when we have the entity reference)
    private func tryPickFromBeltEntity(entity: Entity) -> ItemStack? {
        guard world.has(BeltComponent.self, for: entity),
              var belt = world.get(BeltComponent.self, for: entity) else {
            return nil
        }
        
        // Try left lane first, then right
        for lane in [BeltLane.left, BeltLane.right] {
            if let beltItem = belt.takeItem(from: lane) {
                world.add(belt, to: entity)
                let maxStack = itemRegistry.get(beltItem.itemId)?.stackSize ?? 100
                return ItemStack(itemId: beltItem.itemId, count: 1, maxStack: maxStack)
            }
        }
        
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
        let hasFurnace = world.has(FurnaceComponent.self, for: entity)
        let hasAssembler = world.has(AssemblerComponent.self, for: entity)
        if !hasFurnace && !hasAssembler {
            return nil
        }

        guard var inventory = world.get(InventoryComponent.self, for: entity) else {
            return nil
        }

        let outputStartIndex = hasFurnace ? 2 : inventory.slots.count / 2
        let outputEndIndex = hasFurnace ? 3 : inventory.slots.count - 1

        for index in outputStartIndex...outputEndIndex {
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
                if distance <= 2 {
                    if var inventory = world.get(InventoryComponent.self, for: entity) {
                        if let item = inventory.takeOne() {
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
            sourceEntity = entity  // Track source entity
            world.add(inventory, to: entity)
            return item
        }
        
        return nil
    }
    
    // MARK: - Drop Off Logic
    
    private func tryDropOff(inserter: InserterComponent, position: PositionComponent, item: ItemStack) -> Bool {
        var success = false


        // Check configured output connection first
        if let outputTarget = inserter.outputTarget {
            // Connection should already be validated, but check one more time
            if world.isAlive(outputTarget) {
                if let targetPos = world.get(PositionComponent.self, for: outputTarget) {
                    // Validate adjacency one more time
                    let distance = abs(targetPos.tilePosition.x - position.tilePosition.x) + abs(targetPos.tilePosition.y - position.tilePosition.y)
                    if distance <= 2 {
                        // Check if outputTarget is a belt - if so, drop on the belt, not in inventory
                        let hasBelt = world.has(BeltComponent.self, for: outputTarget)
                        let hasInventory = world.has(InventoryComponent.self, for: outputTarget)

                        if hasBelt {
                            if tryDropOnBeltEntity(entity: outputTarget, item: item) {
                                success = true
                            } else {
                            }
                        } else if hasInventory {
                            // Try to drop to this configured target (for entities with inventory)
                            if tryDropInInventory(at: position.tilePosition, item: item, excludeEntity: inserter.sourceEntity, targetEntity: outputTarget) {
                                success = true
                            } else {
                            }
                        } else {
                        }
                    } else {
                    }
                } else {
                }
            } else {
            }
        }
        
        // Check configured output position (for belts)
        // Check the exact position first, then all 8 adjacent positions including diagonals
        if !success, let outputPos = inserter.outputPosition {
            // First try the exact configured position
            if tryDropOnBelt(at: outputPos, item: item, inserterPosition: position.tilePosition) {
                success = true
            } else {
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
                            success = true
                            break
                        }
                    }
                }
                if !success {
                }
            }
        } else if !success {
        }
        
        // Only use configured output connections - no auto-detection
        // If no configured connection or connection failed, return false
        return success
    }
    
    /// Drops an item directly on a belt entity (when we have the entity reference)
    private func tryDropOnBeltEntity(entity: Entity, item: ItemStack) -> Bool {
        guard world.has(BeltComponent.self, for: entity),
              var belt = world.get(BeltComponent.self, for: entity) else {
            return false
        }
        
        // Check which lane has space
        for lane in [BeltLane.left, BeltLane.right] {
            if belt.addItem(item.itemId, lane: lane, position: 0) {
                world.add(belt, to: entity)
                return true
            }
        }
        
        return false
    }
    
    /// Drops an item on a belt at a specific position (searches for the belt)
    private func tryDropOnBelt(at position: IntVector2, item: ItemStack, inserterPosition: IntVector2) -> Bool {
        // First try BeltSystem's addItem (fast lookup)
        // Check which lane has space
        for lane in [BeltLane.left, BeltLane.right] {
            if beltSystem.hasSpace(at: position, lane: lane) {
                if beltSystem.addItem(item.itemId, at: position, lane: lane) {
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
                    return true
                }
            }
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
                            return true
                        }
                    }
                }
            }
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
        guard world.isAlive(targetEntity) else {
            return false
        }

        // Get the target entity's position
        guard let targetPos = world.get(PositionComponent.self, for: targetEntity) else {
            return false
        }

        
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
                    if distance <= 2 {
                        isAdjacent = true
                        break
                    }
                }
                if isAdjacent { break }
            }
        } else {
            // Single-tile entity - check if position is adjacent (within 1 tile including diagonals)
            let distance = abs(targetPos.tilePosition.x - position.x) + abs(targetPos.tilePosition.y - position.y)
            isAdjacent = distance <= 2
        }

        guard isAdjacent else {
            return false
        }
        
        // Check if entity has inventory that can accept the item
        guard var inventory = world.get(InventoryComponent.self, for: targetEntity) else { return false }

        // Check if target is a machine (furnace, assembler) that has separate input/output slots
        let isMachine = world.has(FurnaceComponent.self, for: targetEntity) ||
                       world.has(AssemblerComponent.self, for: targetEntity)


        if isMachine {
            // For machines, only drop to input slots (first half of inventory)
            let inputSlotCount = inventory.slots.count / 2

            // Check if input slots can accept the item
            var canAcceptInInput = false
            for i in 0..<inputSlotCount {
                if inventory.slots[i] == nil || (inventory.slots[i]?.itemId == item.itemId && inventory.slots[i]!.count < inventory.slots[i]!.maxStack) {
                    canAcceptInInput = true
                    break
                }
            }
            guard canAcceptInInput else { return false }

            // Add to first available input slot
            for i in 0..<inputSlotCount {
                if inventory.slots[i] == nil {
                    inventory.slots[i] = ItemStack(itemId: item.itemId, count: item.count, maxStack: item.maxStack)
                    world.add(inventory, to: targetEntity)
                    return true
                } else if inventory.slots[i]?.itemId == item.itemId && inventory.slots[i]!.count < inventory.slots[i]!.maxStack {
                    let canAdd = min(item.count, inventory.slots[i]!.maxStack - inventory.slots[i]!.count)
                    inventory.slots[i]!.count += canAdd
                    world.add(inventory, to: targetEntity)
                    let success = canAdd == item.count
                    return success
                }
            }
            return false
        } else {
            // For non-machines, add to any slot
            let canAccept = inventory.canAccept(itemId: item.itemId)
            guard canAccept else { return false }

            // Drop the item
            let remaining = inventory.add(item)
            world.add(inventory, to: targetEntity)
            let success = remaining == 0
            return success
        }
    }

    /// Checks if there's something to pick up from machine output at a position
    private func canPickUpFromMachineOutput(at position: IntVector2) -> Bool {
        // Check if there's an entity with inventory that has output items
        // For multi-tile buildings, check ALL nearby entities for adjacency
        let nearbyEntities = world.getEntitiesNear(position: Vector2(Float(position.x) + 0.5, Float(position.y) + 0.5), radius: 2.0)

        // First, try to find any machine with output items that's adjacent
        for entity in nearbyEntities {
            if let entityPos = world.get(PositionComponent.self, for: entity) {
                let distance = abs(entityPos.tilePosition.x - position.x) + abs(entityPos.tilePosition.y - position.y)

                // Check if entity is adjacent (within 1 tile in any direction, including diagonals)
                if distance <= 2 {
                    // Check for inventory on machines (furnaces, assemblers)
                    if let inventory = world.get(InventoryComponent.self, for: entity) {
                    // For machines, check output slots
                    let hasFurnace = world.has(FurnaceComponent.self, for: entity)
                    let outputStartIndex = hasFurnace ? 2 : inventory.slots.count / 2
                    let outputEndIndex = hasFurnace ? 3 : inventory.slots.count - 1
                    let hasOutputItems = (outputStartIndex...outputEndIndex).contains { index in
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


        // Check all 8 adjacent positions for each tile the building occupies
        let offsets = [
            IntVector2(0, 1), IntVector2(1, 1), IntVector2(1, 0), IntVector2(1, -1),
            IntVector2(0, -1), IntVector2(-1, -1), IntVector2(-1, 0), IntVector2(-1, 1)
        ]
        for buildingPos in positionsToCheck {
            for offset in offsets {
                let checkPos = buildingPos + offset

                // Skip positions that are within the building's own bounds
                if positionsToCheck.contains(checkPos) {
                    continue
                }

                if let entityAtPos = world.getEntityAt(position: checkPos) {
                    if world.has(InserterComponent.self, for: entityAtPos) {
                        return true
                    } else {
                    }
                } else {
                }
            }
        }

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

