import Foundation

/// The player character
final class Player {
    private let world: World
    private let entity: Entity
    
    /// Player inventory
    var inventory: InventoryComponent
    
    /// Player position
    var position: Vector2 {
        get {
            return world.get(PositionComponent.self, for: entity)?.worldPosition ?? .zero
        }
        set {
            var pos = world.get(PositionComponent.self, for: entity) ?? PositionComponent(tilePosition: .zero)
            pos.tilePosition = IntVector2(from: newValue)
            pos.offset = Vector2(
                newValue.x - floorf(newValue.x),
                newValue.y - floorf(newValue.y)
            )
            world.add(pos, to: entity)
        }
    }
    
    /// Player health
    var health: Float {
        get { world.get(HealthComponent.self, for: entity)?.current ?? 0 }
    }
    
    var maxHealth: Float {
        get { world.get(HealthComponent.self, for: entity)?.max ?? 0 }
    }
    
    /// Movement
    private var moveDirection: Vector2 = .zero
    private let moveSpeed: Float = 5.0
    
    /// Crafting queue
    private var craftingQueue: [CraftingQueueItem] = []
    private var currentCraft: CraftingQueueItem?
    private var craftingProgress: Float = 0
    
    init(world: World) {
        self.world = world
        self.entity = world.spawn()
        self.inventory = InventoryComponent(slots: 40)
        
        // Set up player entity
        world.add(PositionComponent(tilePosition: .zero), to: entity)
            world.add(SpriteComponent(
                textureId: "player",
                size: Vector2(1.0, 1.0),  // Normal tile size
                tint: .white,
                layer: .entity,
                centered: true
            ), to: entity)
        world.add(HealthComponent(maxHealth: 250, immunityDuration: 0.5), to: entity)
        world.add(VelocityComponent(), to: entity)
        world.add(CollisionComponent(radius: 0.4, layer: .player, mask: [.enemy, .building]), to: entity)
        
        // Give starting items
        giveStartingItems()
    }
    
    private func giveStartingItems() {
        inventory.add(itemId: "iron-plate", count: 8)
        inventory.add(itemId: "burner-mining-drill", count: 1)
        inventory.add(itemId: "stone-furnace", count: 1)
    }
    
    // MARK: - Update
    
    func update(deltaTime: Float) {
        // Update movement
        updateMovement(deltaTime: deltaTime)
        
        // Update crafting
        updateCrafting(deltaTime: deltaTime)
        
        // Update health immunity
        if var health = world.get(HealthComponent.self, for: entity) {
            health.update(deltaTime: deltaTime)
            world.add(health, to: entity)
        }
    }
    
    private func updateMovement(deltaTime: Float) {
        guard moveDirection.lengthSquared > 0.001 else { return }

        // moveDirection already has magnitude (0-1) from joystick, just scale by speed
        let velocity = moveDirection * moveSpeed

        if var pos = world.get(PositionComponent.self, for: entity) {
            let newPos = pos.worldPosition + velocity * deltaTime

            // Convert world position to tile coordinates (centered on 0.5)
            let adjustedPos = newPos - Vector2(0.5, 0.5)
            pos.tilePosition = IntVector2(from: adjustedPos)
            pos.offset = adjustedPos - pos.tilePosition.toVector2

            // Check for walkable tile
            // TODO: Add proper collision detection

            world.add(pos, to: entity)
        }
    }
    
    // MARK: - Movement

    func setMoveDirection(_ direction: Vector2) {
        moveDirection = direction
    }
    
    func stopMoving() {
        moveDirection = .zero
    }
    
    // MARK: - Crafting
    
    private func updateCrafting(deltaTime: Float) {
        guard let craft = currentCraft else {
            // Start next craft in queue
            if !craftingQueue.isEmpty {
                currentCraft = craftingQueue.removeFirst()
                craftingProgress = 0
            }
            return
        }
        
        craftingProgress += deltaTime / craft.recipe.craftTime
        
        if craftingProgress >= 1.0 {
            // Complete crafting
            for output in craft.recipe.outputs {
                inventory.add(output)
            }
            
            currentCraft = nil
            craftingProgress = 0
            
            AudioManager.shared.playCraftingCompleteSound()
        }
    }
    
    func craft(recipe: Recipe, count: Int = 1) -> Bool {
        // Check if we have all inputs
        var requiredItems: [String: Int] = [:]
        for input in recipe.inputs {
            requiredItems[input.itemId, default: 0] += input.count * count
        }
        
        for (itemId, needed) in requiredItems {
            if inventory.count(of: itemId) < needed {
                return false
            }
        }
        
        // Consume inputs
        for input in recipe.inputs {
            inventory.remove(itemId: input.itemId, count: input.count * count)
        }
        
        // Queue crafting
        for _ in 0..<count {
            craftingQueue.append(CraftingQueueItem(recipe: recipe))
        }
        
        return true
    }
    
    func cancelCrafting() {
        // Return items for current craft
        if let craft = currentCraft {
            for input in craft.recipe.inputs {
                inventory.add(input)
            }
            currentCraft = nil
            craftingProgress = 0
        }
        
        // Return items for queued crafts
        for craft in craftingQueue {
            for input in craft.recipe.inputs {
                inventory.add(input)
            }
        }
        craftingQueue.removeAll()
    }
    
    var craftingQueueCount: Int {
        return craftingQueue.count + (currentCraft != nil ? 1 : 0)
    }
    
    var currentCraftingProgress: Float {
        return craftingProgress
    }
    
    var currentCraftingRecipe: Recipe? {
        return currentCraft?.recipe
    }
    
    // MARK: - Rendering
    
    func render(renderer: MetalRenderer) {
        guard let position = world.get(PositionComponent.self, for: entity),
              let sprite = world.get(SpriteComponent.self, for: entity) else { return }
        
        let textureRect = renderer.textureAtlas.getTextureRect(for: sprite.textureId)
        
        renderer.queueSprite(SpriteInstance(
            position: position.worldPosition,
            size: sprite.size,
            rotation: 0,
            textureRect: textureRect,
            color: sprite.tint,
            layer: sprite.layer
        ))
    }
    
    // MARK: - Damage
    
    func takeDamage(_ damage: Float) {
        guard var health = world.get(HealthComponent.self, for: entity) else { return }
        health.takeDamage(damage)
        world.add(health, to: entity)
    }
    
    func heal(_ amount: Float) {
        guard var health = world.get(HealthComponent.self, for: entity) else { return }
        health.heal(amount)
        world.add(health, to: entity)
    }
    
    var isDead: Bool {
        return health <= 0
    }
    
    // MARK: - Serialization
    
    func getState() -> PlayerState {
        return PlayerState(
            position: position,
            inventory: inventory,
            health: health
        )
    }
    
    func loadState(_ state: PlayerState) {
        position = state.position
        inventory = state.inventory
        
        if var healthComp = world.get(HealthComponent.self, for: entity) {
            healthComp.current = state.health
            world.add(healthComp, to: entity)
        }
    }
}

struct CraftingQueueItem {
    let recipe: Recipe
}

struct PlayerState: Codable {
    let position: Vector2
    let inventory: InventoryComponent
    let health: Float
}

