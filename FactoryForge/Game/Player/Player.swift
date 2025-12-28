import Foundation

/// The player character
final class Player {
    private var world: World
    private var entity: Entity

    /// The player's entity (for external systems)
    var playerEntity: Entity { entity }

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
    
    /// Combat
    private var attackCooldown: Float = 0
    private let attackCooldownTime: Float = 0.5  // Can attack every 0.5 seconds
    private let playerDamage: Float = 5.0  // Damage per shot
    private let attackRange: Float = 10.0  // Attack range in tiles
    
    /// Crafting queue
    private var craftingQueue: [CraftingQueueItem] = []
    private var currentCraft: CraftingQueueItem?
    private var craftingProgress: Float = 0
    
    /// Player animations for different directions
    private var playerAnimationLeft: SpriteAnimation?
    private var playerAnimationRight: SpriteAnimation?
    
    init(world: World) {
        self.world = world
        self.entity = world.spawn()
        self.inventory = InventoryComponent(slots: 40)
        
        // Set up player entity
        setupPlayerEntity()
    }
    
    /// Recreates the player entity (used when loading a game after world deserialization)
    func recreateEntity(in world: World) {
        self.world = world
        self.entity = world.spawn()
        setupPlayerEntity()
    }
    
    private func setupPlayerEntity() {
        // Set up player entity
        world.add(PositionComponent(tilePosition: .zero), to: entity)
        
        // Create player animation with all 16 frames for both directions
        let playerFramesRight = (0..<16).map { "player_\($0)" }
        let playerFramesLeft = (0..<16).map { "player_left_\($0)" }
        
        var playerAnimationRight = SpriteAnimation(
            frames: playerFramesRight,
            frameTime: 0.08,  // 80ms per frame for smooth walking animation
            isLooping: true
        )
        playerAnimationRight.pause()  // Start paused, will play when moving
        
        var playerAnimationLeft = SpriteAnimation(
            frames: playerFramesLeft,
            frameTime: 0.08,
            isLooping: true
        )
        playerAnimationLeft.pause()
        
        var spriteComponent = SpriteComponent(
            textureId: "player_0",  // Default to first frame
            size: Vector2(1.0, 1.0),  // Normal tile size
            tint: .white,
            layer: .entity,
            centered: true
        )
        spriteComponent.animation = playerAnimationRight
        
        // Store references to both animations for switching directions
        self.playerAnimationRight = playerAnimationRight
        self.playerAnimationLeft = playerAnimationLeft
        
        world.add(spriteComponent, to: entity)
        world.add(HealthComponent(maxHealth: 250, immunityDuration: 0.5), to: entity)
        world.add(VelocityComponent(), to: entity)
        world.add(CollisionComponent(radius: 0.4, layer: .player, mask: [.enemy, .building]), to: entity)
        
        // Give starting items
        giveStartingItems()
    }
    
    private func giveStartingItems() {
        inventory.add(itemId: "iron-plate", count: 10)  // Enough to build both burner miner and stone furnace
        inventory.add(itemId: "burner-mining-drill", count: 1)
        inventory.add(itemId: "stone-furnace", count: 1)
        inventory.add(itemId: "firearm-magazine", count: 10)  // Starting ammo for self-defense
    }
    
    // MARK: - Update
    
    func update(deltaTime: Float) {
        // Update movement
        updateMovement(deltaTime: deltaTime)
        
        // Update crafting
        updateCrafting(deltaTime: deltaTime)
        
        // Update attack cooldown
        if attackCooldown > 0 {
            attackCooldown = max(0, attackCooldown - deltaTime)
        }
        
        // Update health immunity
        if var health = world.get(HealthComponent.self, for: entity) {
            health.update(deltaTime: deltaTime)
            world.add(health, to: entity)
        }
        
        // Update player animation
        updateAnimation(deltaTime: deltaTime)
    }
    
    private func updateMovement(deltaTime: Float) {
        guard moveDirection.lengthSquared > 0.001 else { return }

        // moveDirection already has magnitude (0-1) from joystick, just scale by speed
        let velocity = moveDirection * moveSpeed

        if var pos = world.get(PositionComponent.self, for: entity),
           let collision = world.get(CollisionComponent.self, for: entity) {
            let newPos = pos.worldPosition + velocity * deltaTime

            // Check for collisions before moving
            let playerRadius = collision.radius
            if !world.checkCollision(at: newPos, radius: playerRadius, layer: .player, excluding: entity) {
                // No collision, move to new position
                // Convert world position to tile coordinates (centered on 0.5)
                let adjustedPos = newPos - Vector2(0.5, 0.5)
                pos.tilePosition = IntVector2(from: adjustedPos)
                pos.offset = adjustedPos - pos.tilePosition.toVector2
                world.add(pos, to: entity)
            }
            // If collision detected, don't move (player stops)
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
    
    // MARK: - Combat
    
    /// Attempts to attack an enemy at the given world position
    /// Returns true if attack was successful
    func attack(at targetPosition: Vector2) -> Bool {
        print("Player attack called at position: \(targetPosition)")
        // Check cooldown
        guard attackCooldown <= 0 else {
            print("Attack on cooldown: \(attackCooldown)")
            return false
        }
        
        // Check if player has ammo
        let hasFirearm = inventory.has(itemId: "firearm-magazine")
        let hasPiercing = inventory.has(itemId: "piercing-rounds-magazine")
        guard hasFirearm || hasPiercing else {
            print("No ammo: firearm=\(hasFirearm), piercing=\(hasPiercing)")
            return false  // No ammo
        }
        
        // Get player position
        guard let playerPos = world.get(PositionComponent.self, for: entity) else { return false }
        
        // Check range
        let distance = playerPos.worldPosition.distance(to: targetPosition)
        print("Attack distance: \(distance), range: \(attackRange)")
        guard distance <= attackRange else {
            print("Target out of range")
            return false
        }
        
        // Find enemy at target position
        let nearbyEnemies = world.getEntitiesNear(position: targetPosition, radius: 1.0)
        var targetEnemy: Entity?
        
        for enemy in nearbyEnemies {
            guard world.has(EnemyComponent.self, for: enemy) else { continue }
            guard let health = world.get(HealthComponent.self, for: enemy), !health.isDead else { continue }
            
            if let enemyPos = world.get(PositionComponent.self, for: enemy) {
                let enemyDistance = playerPos.worldPosition.distance(to: enemyPos.worldPosition)
                if enemyDistance <= attackRange {
                    targetEnemy = enemy
                    break
                }
            }
        }
        
        guard let enemy = targetEnemy else {
            print("No enemy found at target position")
            return false
        }
        print("Found enemy to attack: \(enemy)")
        
        // Consume ammo
        if inventory.has(itemId: "piercing-rounds-magazine") {
            inventory.remove(itemId: "piercing-rounds-magazine", count: 1)
        } else {
            inventory.remove(itemId: "firearm-magazine", count: 1)
        }
        
        // Create projectile
        let projectile = world.spawn()
        let direction = (targetPosition - playerPos.worldPosition).normalized
        let startPos = playerPos.worldPosition + direction * 0.5
        
        world.add(PositionComponent(tilePosition: IntVector2(from: startPos)), to: projectile)
        world.add(SpriteComponent(textureId: "bullet", size: Vector2(0.2, 0.2), layer: .projectile, centered: true), to: projectile)
        world.add(VelocityComponent(velocity: direction * 30), to: projectile)
        
        var projectileComp = ProjectileComponent(damage: playerDamage, speed: 30)
        projectileComp.target = enemy
        projectileComp.source = entity
        world.add(projectileComp, to: projectile)
        
        // Set cooldown
        attackCooldown = attackCooldownTime
        
        // Play sound
        // AudioManager.shared.playTurretFireSound() // Temporarily disabled for debugging

        print("Player attack successful - projectile created")
        return true
    }
    
    var canAttack: Bool {
        return attackCooldown <= 0 && (inventory.has(itemId: "firearm-magazine") || inventory.has(itemId: "piercing-rounds-magazine"))
    }
    
    // MARK: - Animation
    
    private func updateAnimation(deltaTime: Float) {
        guard var sprite = world.get(SpriteComponent.self, for: entity),
              var animation = sprite.animation else { return }
        
        let isMoving = moveDirection.lengthSquared > 0.001
        
        if isMoving {
            // Determine direction and switch animation if needed
            let isMovingLeft = moveDirection.x < -0.01
            let currentFirstFrame = animation.frames.first ?? ""
            let isUsingLeftAnimation = currentFirstFrame == "player_left_0"
            
            // Switch animation set if direction changed
            if isMovingLeft && !isUsingLeftAnimation {
                // Switch to left animation
                if var leftAnim = playerAnimationLeft {
                    leftAnim.currentFrame = animation.currentFrame  // Preserve frame
                    leftAnim.elapsedTime = animation.elapsedTime
                    leftAnim.isPlaying = animation.isPlaying
                    animation = leftAnim
                    sprite.animation = animation
                    // Immediately update texture to match current frame
                    if let currentFrame = animation.update(deltaTime: 0) {
                        sprite.textureId = currentFrame
                        // print("Switched to LEFT animation, frame: \(currentFrame)")
                    }
                } else {
                    print("ERROR: playerAnimationLeft is nil!")
                }
            } else if !isMovingLeft && isUsingLeftAnimation {
                // Switch to right animation
                if var rightAnim = playerAnimationRight {
                    rightAnim.currentFrame = animation.currentFrame
                    rightAnim.elapsedTime = animation.elapsedTime
                    rightAnim.isPlaying = animation.isPlaying
                    animation = rightAnim
                    sprite.animation = animation
                    // Immediately update texture to match current frame
                    if let currentFrame = animation.update(deltaTime: 0) {
                        sprite.textureId = currentFrame
                        // print("Switched to RIGHT animation, frame: \(currentFrame)")
                    }
                } else {
                    print("ERROR: playerAnimationRight is nil!")
                }
            }
            
            // Play animation when moving
            if !animation.isPlaying {
                animation.play()
            }
            // Update animation frame
            if let currentFrame = animation.update(deltaTime: deltaTime) {
                sprite.textureId = currentFrame
            }
        } else {
            // Stop animation when not moving, reset to first frame
            if animation.isPlaying {
                animation.pause()
                animation.reset()
            }
            // Default to right-facing first frame
            sprite.textureId = animation.frames.first ?? "player_0"
        }
        
        sprite.animation = animation
        world.add(sprite, to: entity)
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

