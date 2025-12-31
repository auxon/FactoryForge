import Foundation

/// System that handles inserter item transfers
final class InserterSystem: System {
    let priority = SystemPriority.logistics.rawValue + 50
    
    private let world: World
    private let beltSystem: BeltSystem
    
    init(world: World, beltSystem: BeltSystem) {
        self.world = world
        self.beltSystem = beltSystem
    }
    
    func update(deltaTime: Float) {
        let allInserters = world.query(InserterComponent.self)
        let allMiners = world.query(MinerComponent.self)
        print("InserterSystem: update called, found \(allInserters.count) inserter(s), \(allMiners.count) miner(s)")
        
        // Log all miner positions for debugging
        for minerEntity in allMiners {
            if let pos = world.get(PositionComponent.self, for: minerEntity),
               let inventory = world.get(InventoryComponent.self, for: minerEntity) {
                let itemCount = inventory.slots.compactMap { $0 }.reduce(0) { $0 + $1.count }
                print("InserterSystem: Miner entity \(minerEntity) at \(pos.tilePosition) has \(itemCount) items in inventory")
            }
        }
        
        world.forEach(InserterComponent.self) { [self] entity, inserter in
            guard let position = world.get(PositionComponent.self, for: entity) else {
                print("InserterSystem: Inserter \(entity) has no PositionComponent")
                return
            }
            let power = world.get(PowerConsumerComponent.self, for: entity)
            // Check if inserter is on a power network and has satisfaction > 0
            // Consumers not on a network have networkId = nil and should be considered unpowered
            let hasPower = power != nil && power!.networkId != nil && power!.satisfaction > 0
            
            print("InserterSystem: Processing inserter \(entity) at \(position.tilePosition), hasPower=\(hasPower), power=\(power != nil ? "exists" : "nil"), networkId=\(power?.networkId != nil ? "\(power!.networkId!)" : "nil"), satisfaction=\(power?.satisfaction ?? 0)")
            
            // Update inserter animation (pause if no power, play if powered)
            updateInserterAnimation(entity: entity, deltaTime: deltaTime, hasPower: hasPower)
            
            // Only process inserter logic if powered
            guard hasPower, let power = power else {
                print("InserterSystem: Inserter at \(position.tilePosition) skipped - no power")
                return
            }
            
            let speedMultiplier = power.satisfaction
            
            print("InserterSystem: Inserter at \(position.tilePosition) state=\(inserter.state), heldItem=\(inserter.heldItem != nil ? "exists" : "nil")")
            
            switch inserter.state {
            case .idle:
                // If holding an item, try to drop it off first
                if inserter.heldItem != nil {
                    print("InserterSystem: Inserter at \(position.tilePosition) in idle state but holding item, transitioning to droppingOff")
                    inserter.state = .droppingOff
                    break
                }
                
                // Check if we can pick something up from any adjacent tile
                if inserter.heldItem == nil {
                    // Check all 4 adjacent directions AND diagonals (8 directions total)
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
                    
                    print("InserterSystem: Inserter at \(position.tilePosition) in idle state, checking 8 directions for items")
                    for offset in offsets {
                        let sourcePos = position.tilePosition + offset
                        print("InserterSystem: Checking position \(sourcePos)")
                        if canPickUp(from: sourcePos) {
                            print("InserterSystem: Inserter at \(position.tilePosition) can pick up from \(sourcePos), transitioning to pickingUp")
                            inserter.state = .pickingUp
                            break
                        }
                    }
                } else {
                    print("InserterSystem: Inserter at \(position.tilePosition) in idle state but already holding item")
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
                
                print("InserterSystem: Inserter at \(position.tilePosition) in pickingUp state, armAngle=\(inserter.armAngle), targetAngle=\(targetAngle), angleDiff=\(angleDiff)")
                
                if abs(angleDiff) < rotationSpeed {
                    inserter.armAngle = targetAngle
                    print("InserterSystem: Inserter at \(position.tilePosition) arm reached target, trying to pick up")
                    
                    // Try to pick up item
                    if let item = tryPickUp(inserter: &inserter, position: position) {
                        if let sourceEntity = inserter.sourceEntity {
                            print("InserterSystem: Inserter at \(position.tilePosition) successfully picked up \(item.itemId) from source entity \(sourceEntity.id)")
                        } else {
                            print("InserterSystem: Inserter at \(position.tilePosition) successfully picked up \(item.itemId) from belt")
                        }
                        inserter.heldItem = item
                        inserter.state = .rotating
                    } else {
                        print("InserterSystem: Inserter at \(position.tilePosition) failed to pick up, returning to idle")
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
                
                // Normalize angle difference to [-pi, pi] range for shortest path
                var angleDiff = targetAngle - inserter.armAngle
                
                // Normalize to [-pi, pi]
                if angleDiff > .pi {
                    angleDiff -= 2 * .pi
                } else if angleDiff < -.pi {
                    angleDiff += 2 * .pi
                }
                
                print("InserterSystem: Inserter at \(position.tilePosition) in rotating state, armAngle=\(inserter.armAngle), targetAngle=\(targetAngle), angleDiff=\(angleDiff), rotationSpeed=\(rotationSpeed)")
                
                // Check if we're close enough to snap to target
                if abs(angleDiff) <= rotationSpeed || abs(angleDiff) < 0.01 || abs(inserter.armAngle - targetAngle) < 0.01 {
                    inserter.armAngle = targetAngle
                    print("InserterSystem: Inserter at \(position.tilePosition) arm reached target (0), transitioning to droppingOff")
                    inserter.state = .droppingOff
                } else {
                    // Calculate new angle
                    let newAngle = inserter.armAngle + (angleDiff > 0 ? rotationSpeed : -rotationSpeed)
                    
                    // If we've passed the target, snap to it
                    if (angleDiff > 0 && newAngle > targetAngle) || (angleDiff < 0 && newAngle < targetAngle) {
                        inserter.armAngle = targetAngle
                        inserter.state = .droppingOff
                    } else {
                        inserter.armAngle = newAngle
                        // Normalize armAngle to [0, 2*pi] range only if we haven't reached target
                        if inserter.armAngle < 0 {
                            inserter.armAngle += 2 * .pi
                        } else if inserter.armAngle >= 2 * .pi {
                            inserter.armAngle -= 2 * .pi
                        }
                    }
                }
                
            case .droppingOff:
                // Try to drop item
                if let item = inserter.heldItem {
                    print("InserterSystem: Inserter at \(position.tilePosition) trying to drop off \(item.itemId)")
                    if tryDropOff(inserter: inserter, position: position, item: item) {
                        print("InserterSystem: Inserter at \(position.tilePosition) successfully dropped off item")
                        inserter.heldItem = nil
                        inserter.sourceEntity = nil  // Clear source entity after dropping off
                        inserter.state = .idle
                        inserter.armAngle = 0
                    } else {
                        print("InserterSystem: Inserter at \(position.tilePosition) failed to drop off, returning to idle with item still held")
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
                    print("InserterSystem: canPickUp from \(position): found belt item")
                    return true
                }
            }
        }
        
        // Check if there's an entity with inventory that has items
        // For multi-tile buildings, check ALL nearby entities for adjacency (not just ones where position is within bounds)
        // because the miner might be adjacent but the checked position might be outside its bounds
        let nearbyEntities = world.getEntitiesNear(position: Vector2(Float(position.x) + 0.5, Float(position.y) + 0.5), radius: 2.0)
        print("InserterSystem: canPickUp from \(position): checking \(nearbyEntities.count) nearby entities")
        
        // Log all nearby entities for debugging
        for entity in nearbyEntities {
            if let entityPos = world.get(PositionComponent.self, for: entity) {
                let distance = abs(entityPos.tilePosition.x - position.x) + abs(entityPos.tilePosition.y - position.y)
                let hasMiner = world.has(MinerComponent.self, for: entity)
                let hasFurnace = world.has(FurnaceComponent.self, for: entity)
                let hasInventory = world.has(InventoryComponent.self, for: entity)
                let inventory = world.get(InventoryComponent.self, for: entity)
                let itemCount = inventory?.slots.compactMap { $0 }.reduce(0) { $0 + $1.count } ?? 0
                print("InserterSystem: canPickUp from \(position): nearby entity \(entity) at \(entityPos.tilePosition), distance=\(distance), hasMiner=\(hasMiner), hasFurnace=\(hasFurnace), hasInventory=\(hasInventory), itemCount=\(itemCount)")
            }
        }
        
        // First, try to find any miner or building with inventory that's adjacent (within 1 tile)
        for entity in nearbyEntities {
            if let entityPos = world.get(PositionComponent.self, for: entity) {
                let distance = abs(entityPos.tilePosition.x - position.x) + abs(entityPos.tilePosition.y - position.y)
                
                // Check if entity is adjacent (within 1 tile in any direction, including diagonals)
                if distance <= 1 {
                    let hasMiner = world.has(MinerComponent.self, for: entity)
                    let hasFurnace = world.has(FurnaceComponent.self, for: entity)
                    
                    // Check for inventory on any building (miner, furnace, etc.)
                    if let inventory = world.get(InventoryComponent.self, for: entity) {
                        let itemCount = inventory.slots.compactMap { $0 }.reduce(0) { $0 + $1.count }
                        print("InserterSystem: canPickUp from \(position): adjacent entity \(entity) at \(entityPos.tilePosition), hasMiner=\(hasMiner), hasFurnace=\(hasFurnace), has inventory with \(itemCount) items, isEmpty=\(inventory.isEmpty)")
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
                    if let inventory = world.get(InventoryComponent.self, for: entity),
                       !inventory.isEmpty {
                        return true
                    }
                }
            }
        }
        
        // Fallback: try getEntityAt (for single-tile entities)
        if let entity = world.getEntityAt(position: position) {
            if let inventory = world.get(InventoryComponent.self, for: entity) {
                let itemCount = inventory.slots.compactMap { $0 }.reduce(0) { $0 + $1.count }
                print("InserterSystem: canPickUp from \(position): getEntityAt found entity \(entity) with inventory (\(itemCount) items), isEmpty=\(inventory.isEmpty)")
                if !inventory.isEmpty {
                    return true
                }
            } else {
                print("InserterSystem: canPickUp from \(position): getEntityAt found entity \(entity) but no InventoryComponent")
            }
        } else {
            print("InserterSystem: canPickUp from \(position): getEntityAt found no entity")
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
        
        print("InserterSystem: tryPickUp called for inserter at \(position.tilePosition)")
        for offset in offsets {
            let sourcePos = position.tilePosition + offset
            
            // Try to pick from belt first
            if let item = tryPickFromBelt(at: sourcePos, stackSize: inserter.stackSize) {
                print("InserterSystem: tryPickUp picked from belt at \(sourcePos)")
                inserter.sourceEntity = nil  // Belts don't have entities to track
                return item
            }
            
            // Try to pick from inventory
            var sourceEntity: Entity? = nil
            if let item = tryPickFromInventory(at: sourcePos, stackSize: inserter.stackSize, sourceEntity: &sourceEntity) {
                print("InserterSystem: tryPickUp picked from inventory at \(sourcePos)")
                inserter.sourceEntity = sourceEntity  // Track source entity
                return item
            }
        }
        
        print("InserterSystem: tryPickUp failed to pick up from any adjacent position")
        return nil
    }
    
    private func tryPickFromBelt(at position: IntVector2, stackSize: Int) -> ItemStack? {
        // Try left lane first, then right
        for lane in [BeltLane.left, BeltLane.right] {
            if let beltItem = beltSystem.takeItem(at: position, lane: lane) {
                return ItemStack(itemId: beltItem.itemId, count: 1)
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
                            print("InserterSystem: tryPickFromInventory picked item \(item.itemId) from entity \(entity) at \(entityPos.tilePosition)")
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
            print("InserterSystem: tryPickFromInventory picked item \(item.itemId) from entity \(entity) at position \(position)")
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
        
        if let sourceEntity = inserter.sourceEntity {
            print("InserterSystem: tryDropOff called for inserter at \(position.tilePosition) with item \(item.itemId), excluding source entity \(sourceEntity.id)")
        } else {
            print("InserterSystem: tryDropOff called for inserter at \(position.tilePosition) with item \(item.itemId), no source entity to exclude")
        }
        for offset in offsets {
            let targetPos = position.tilePosition + offset
            
            // Try to drop on belt first (belts don't have entities, so no need to exclude)
            if tryDropOnBelt(at: targetPos, item: item) {
                print("InserterSystem: tryDropOff successfully dropped on belt at \(targetPos)")
                return true
            }
            
            // Try to drop in inventory (exclude source entity)
            if tryDropInInventory(at: targetPos, item: item, excludeEntity: inserter.sourceEntity) {
                print("InserterSystem: tryDropOff successfully dropped in inventory at \(targetPos)")
                return true
            }
        }
        
        print("InserterSystem: tryDropOff failed to drop off at any adjacent position")
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
        // Check adjacent entities (for multi-tile buildings like furnaces)
        let nearbyEntities = world.getEntitiesNear(position: Vector2(Float(position.x) + 0.5, Float(position.y) + 0.5), radius: 2.0)
        for entity in nearbyEntities {
            // Skip the source entity to avoid dropping back to where we picked up from
            if let excludeEntity = excludeEntity, entity.id == excludeEntity.id && entity.generation == excludeEntity.generation {
                continue
            }
            
            if let entityPos = world.get(PositionComponent.self, for: entity) {
                let distance = abs(entityPos.tilePosition.x - position.x) + abs(entityPos.tilePosition.y - position.y)
                
                // Check if entity is adjacent (within 1 tile in any direction, including diagonals)
                if distance <= 1 {
                    if var inventory = world.get(InventoryComponent.self, for: entity) {
                        // Check if inventory can accept the item
                        if inventory.canAccept(itemId: item.itemId) {
                            let remaining = inventory.add(item)
                            print("InserterSystem: tryDropInInventory dropped item \(item.itemId) to entity \(entity) at \(entityPos.tilePosition), remaining=\(remaining)")
                            world.add(inventory, to: entity)
                            return remaining == 0
                        }
                    }
                }
            }
        }
        
        // Fallback: try getEntityAt (for single-tile entities)
        guard let entity = world.getEntityAt(position: position) else { return false }
        // Skip the source entity
        if let excludeEntity = excludeEntity, entity.id == excludeEntity.id && entity.generation == excludeEntity.generation {
            return false
        }
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

