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
        world.forEach(InserterComponent.self) { [self] entity, inserter in
            guard let position = world.get(PositionComponent.self, for: entity) else { return }
            guard let power = world.get(PowerConsumerComponent.self, for: entity), power.satisfaction > 0 else { return }
            
            let speedMultiplier = power.satisfaction
            
            switch inserter.state {
            case .idle:
                // Check if we can pick something up
                if inserter.heldItem == nil {
                    inserter.state = .pickingUp
                }
                
            case .pickingUp:
                // Rotate arm towards source
                let rotationSpeed = inserter.speed * speedMultiplier * deltaTime * .pi * 2
                let angleDiff = .pi - inserter.armAngle
                
                if abs(angleDiff) < rotationSpeed {
                    inserter.armAngle = .pi
                    
                    // Try to pick up item
                    if let item = tryPickUp(inserter: inserter, position: position) {
                        inserter.heldItem = item
                        inserter.state = .rotating
                    }
                } else {
                    inserter.armAngle += angleDiff > 0 ? rotationSpeed : -rotationSpeed
                }
                
            case .rotating:
                // Rotate arm towards target
                let rotationSpeed = inserter.speed * speedMultiplier * deltaTime * .pi * 2
                let targetAngle: Float = 0
                let angleDiff = targetAngle - inserter.armAngle
                
                if abs(angleDiff) < rotationSpeed {
                    inserter.armAngle = 0
                    inserter.state = .droppingOff
                } else {
                    inserter.armAngle += angleDiff > 0 ? rotationSpeed : -rotationSpeed
                }
                
            case .droppingOff:
                // Try to drop item
                if let item = inserter.heldItem {
                    if tryDropOff(inserter: inserter, position: position, item: item) {
                        inserter.heldItem = nil
                        inserter.state = .idle
                    }
                } else {
                    inserter.state = .idle
                }
            }
        }
    }
    
    // MARK: - Pick Up Logic
    
    private func tryPickUp(inserter: InserterComponent, position: PositionComponent) -> ItemStack? {
        let sourcePos = position.tilePosition - inserter.direction.intVector
        
        // Try to pick from belt
        if let item = tryPickFromBelt(at: sourcePos, stackSize: inserter.stackSize) {
            return item
        }
        
        // Try to pick from inventory
        if let item = tryPickFromInventory(at: sourcePos, stackSize: inserter.stackSize) {
            return item
        }
        
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
    
    private func tryPickFromInventory(at position: IntVector2, stackSize: Int) -> ItemStack? {
        guard let entity = world.getEntityAt(position: position) else { return nil }
        guard var inventory = world.get(InventoryComponent.self, for: entity) else { return nil }
        
        // Take items from inventory
        if let item = inventory.takeOne() {
            world.add(inventory, to: entity)
            return item
        }
        
        return nil
    }
    
    // MARK: - Drop Off Logic
    
    private func tryDropOff(inserter: InserterComponent, position: PositionComponent, item: ItemStack) -> Bool {
        let targetPos = position.tilePosition + inserter.direction.intVector
        
        // Try to drop on belt
        if tryDropOnBelt(at: targetPos, item: item) {
            return true
        }
        
        // Try to drop in inventory
        if tryDropInInventory(at: targetPos, item: item) {
            return true
        }
        
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
    
    private func tryDropInInventory(at position: IntVector2, item: ItemStack) -> Bool {
        guard let entity = world.getEntityAt(position: position) else { return false }
        guard var inventory = world.get(InventoryComponent.self, for: entity) else { return false }
        
        // Check if inventory can accept the item
        if inventory.canAccept(itemId: item.itemId) {
            let remaining = inventory.add(item)
            world.add(inventory, to: entity)
            return remaining == 0
        }
        
        return false
    }
}

