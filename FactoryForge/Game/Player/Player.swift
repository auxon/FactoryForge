import Foundation

/// The player character
final class Player {
    private var world: World
    private var itemRegistry: ItemRegistry
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
    private var playerAnimationUp: SpriteAnimation?
    private var playerAnimationDown: SpriteAnimation?
    
    init(world: World, itemRegistry: ItemRegistry) {
        self.world = world
        self.itemRegistry = itemRegistry
        self.entity = world.spawn()
        self.inventory = InventoryComponent(slots: 70, allowedItems: nil)

        // Set up player entity
        setupPlayerEntity()
    }
    
    /// Recreates the player entity (used when loading a game after world deserialization)
    func recreateEntity(in world: World, itemRegistry: ItemRegistry) {
        self.world = world
        self.itemRegistry = itemRegistry
        self.entity = world.spawn()
        setupPlayerEntity()
    }
    
    private func setupPlayerEntity() {
        // Set up player entity
        world.add(PositionComponent(tilePosition: .zero), to: entity)
        
        // Create player animation with all 16 frames for both directions
        let playerFramesRight = (0..<16).map { "player_right_\($0)" }
        let playerFramesLeft = (0..<16).map { "player_left_\($0)" }
        let playerFramesUp = (0..<16).map { "player_up_\($0)" }
        let playerFramesDown = (0..<16).map { "player_down_\($0)" }

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
        
        var playerAnimationUp = SpriteAnimation(
            frames: playerFramesUp,
            frameTime: 0.08,
            isLooping: true
        )
        playerAnimationUp.pause()
        
        var playerAnimationDown = SpriteAnimation(
            frames: playerFramesDown,
            frameTime: 0.08,
            isLooping: true
        )
        playerAnimationDown.pause()
        
        var spriteComponent = SpriteComponent(
            textureId: "player_down_0",  // Default to first frame
            size: Vector2(1.0, 1.0),  // Normal tile size
            tint: .white,
            layer: .entity,
            centered: true
        )
        spriteComponent.animation = playerAnimationRight
        
        // Store references to both animations for switching directions
        self.playerAnimationRight = playerAnimationRight
        self.playerAnimationLeft = playerAnimationLeft
        self.playerAnimationUp = playerAnimationUp
        self.playerAnimationDown = playerAnimationDown
        
        world.add(spriteComponent, to: entity)
        world.add(HealthComponent(maxHealth: 250, immunityDuration: 0.5), to: entity)
        world.add(VelocityComponent(), to: entity)
        world.add(CollisionComponent(radius: 0.4, layer: .player, mask: [.enemy, .building]), to: entity)
        
        // Give starting items
        giveStartingItems()
    }
    
    private func giveStartingItems() {
        let startingItems = [
            ("iron-plate", 10),  // 5 for stone furnace + 5 for burner mining drill
            // Give player what is necessary to test the fluid system:
            // - Pipes, water pump, boiler, steam engine, fluid tank
            // Sufficient iron plates & other required intermediates too

            // for fluid networks
            ("pumpjack", 1),
            ("pipe", 100),  // Increased for oil processing buildings
            // Water pump for extracting water from water tiles
            ("water-pump", 2),  // Extra for oil processing
            // Boiler for steam production
            ("boiler", 2),
            // Steam engine for power generation
            ("steam-engine", 2),
            // Fluid tank for fluid storage/buffering
            ("fluid-tank", 4),
            // Extra iron plates for building more pipes/structures
            ("iron-plate", 200),
            // Electronic circuits for water pump & expansion
            ("electronic-circuit", 50),
            // Stone furnace (needed for boiler in recipes)
            ("stone-furnace", 4),
            // Iron gear wheels (water pump, steam engine)
            ("iron-gear-wheel", 100),
            // Wood and coal for boiler fuel testing
            ("wood", 50),
            ("coal", 100),  // Extra for chemical processes
            // Some copper and steel plates for broader test coverage
            ("copper-plate", 100),
            ("steel-plate", 150),  // Extra for oil buildings
            // Stone bricks for oil refinery construction
            ("stone-brick", 50),

            // OIL PROCESSING BUILDINGS
            // Pumpjack: 5 Steel Plates, 10 Iron Gear Wheels, 5 Electronic Circuits, 10 Pipes
            ("pumpjack", 2),  // Oil wells for crude oil extraction
            // Oil Refinery: 15 Steel Plates, 10 Iron Gear Wheels, 10 Electronic Circuits, 10 Pipes, 10 Stone Bricks
            ("oil-refinery", 2),  // Oil refineries for processing crude oil
            // Chemical Plant: 5 Steel Plates, 5 Iron Gear Wheels, 5 Electronic Circuits, 5 Pipes
            ("chemical-plant", 2),  // Chemical plants for advanced processing

            // OIL PRODUCTS (increased amounts for comprehensive testing)
            // Petroleum gas for chemical plant testing
            ("petroleum-gas", 200),
            // Light oil for chemical plant testing
            ("light-oil", 200),
            // Heavy oil for chemical plant testing
            ("heavy-oil", 200),
            // Lubricant for chemical plant testing
            ("lubricant", 100),
            // Sulfuric acid for chemical plant testing
            ("sulfuric-acid", 100),
            // Crude oil for oil processing testing
            ("crude-oil", 200),

            // CHEMICAL PRODUCTS
            ("plastic-bar", 100),  // For advanced circuits and other uses
            ("sulfur", 50),        // For sulfuric acid and chemical science packs

            // ADVANCED COMPONENTS
            ("advanced-circuit", 50),  // For chemical science packs and other uses
            ("processing-unit", 20),   // For advanced buildings and research
            ("engine-unit", 20),       // For chemical science packs

            // PRODUCTION FACILITIES
            ("assembling-machine-1", 4),  // For basic crafting
            ("assembling-machine-2", 4),  // For advanced crafting
            ("assembling-machine-3", 2),  // For advanced crafting
            ("electric-mining-drill", 4), // For resource extraction

            // POWER INFRASTRUCTURE
            ("small-electric-pole", 20),
            ("medium-electric-pole", 10),
            ("big-electric-pole", 5),
            ("solar-panel", 10),
            ("accumulator", 10),

            // RESEARCH FACILITIES
            ("lab", 2),  // For research and science pack consumption
            // Science packs for research
            ("automation-science-pack", 100),
            ("logistic-science-pack", 100),
            ("chemical-science-pack", 50),

            // LOGISTICS
            ("transport-belt", 200),
            ("fast-transport-belt", 100),
            ("inserter", 20),
            ("fast-inserter", 20),
            ("stack-inserter", 10),
            ("wooden-chest", 20),
            ("iron-chest", 20),
            ("steel-chest", 10),
        ]

        for (itemId, count) in startingItems {
            if let itemDef = itemRegistry.get(itemId) {
                inventory.add(itemId: itemId, count: count, maxStack: itemDef.stackSize)
            } else {
                inventory.add(itemId: itemId, count: count, maxStack: 100) // fallback
            }
        }

    }
    
    // MARK: - Update
    
    func update(deltaTime: Float) {
        // Update movement
        updateMovement(deltaTime: deltaTime)
        
        // Update crafting
        updateCrafting(deltaTime: deltaTime)
        
        // Update health immunity and regeneration
        if var health = world.get(HealthComponent.self, for: entity) {
            health.update(deltaTime: deltaTime)

            // Regenerate health if not at full health
            if health.current < health.max {
                let regenRate: Float = 1.0  // Health per second
                health.heal(regenRate * deltaTime)
            }

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
    
    /// Check if a specific recipe is currently being crafted or queued
    func isCrafting(recipe: Recipe) -> Bool {
        // Check current craft
        if let current = currentCraft, current.recipe.id == recipe.id {
            return true
        }
        // Check queue
        return craftingQueue.contains { $0.recipe.id == recipe.id }
    }

    /// Get crafting progress for a specific recipe (0-1, or nil if not crafting)
    func getCraftingProgress(recipe: Recipe) -> Float? {
        if let current = currentCraft, current.recipe.id == recipe.id {
            return craftingProgress
        }
        return nil
    }

    /// Get the number of queued crafts for a specific recipe
    func getQueuedCount(recipe: Recipe) -> Int {
        return craftingQueue.filter { $0.recipe.id == recipe.id }.count
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
    
    /// Determines which bullet sprite to use based on direction
    private func getBulletSprite(for direction: Vector2) -> String {
        // Check if movement is primarily vertical or horizontal
        if abs(direction.y) > abs(direction.x) {
            // Primarily vertical
            return direction.y > 0 ? "bullet_up" : "bullet_down"
        } else {
            // Primarily horizontal
            return direction.x > 0 ? "bullet_right" : "bullet_left"
        }
    }
    
    /// Attempts to attack a specific enemy entity
    /// Returns true if attack was successful
    func attackEnemy(enemy: Entity) -> Bool {
        print("Player attackEnemy called on entity: \(enemy)")

        // Check if player has ammo
        let hasFirearm = inventory.has(itemId: "firearm-magazine")
        let hasPiercing = inventory.has(itemId: "piercing-rounds-magazine")
        print("Player ammo check: firearm=\(hasFirearm), piercing=\(hasPiercing)")
        guard hasFirearm || hasPiercing else {
            print("Player attackEnemy FAILED: no ammo")
            return false
        }

        // Get enemy position and check range
        guard let enemyPos = world.get(PositionComponent.self, for: enemy) else {
            print("Player attackEnemy FAILED: enemy has no position")
            return false
        }

        guard let playerPos = world.get(PositionComponent.self, for: entity) else {
            print("Player attackEnemy FAILED: player has no position")
            return false
        }

        let distance = playerPos.worldPosition.distance(to: enemyPos.worldPosition)
        print("Player attackEnemy range check: distance=\(distance), range=\(attackRange)")
        guard distance <= attackRange else {
            print("Player attackEnemy FAILED: enemy out of range")
            return false
        }

        // Check if enemy is valid target
        guard world.has(EnemyComponent.self, for: enemy) else {
            print("Player attackEnemy FAILED: target is not an enemy")
            return false
        }

        guard let health = world.get(HealthComponent.self, for: enemy), !health.isDead else {
            print("Player attackEnemy FAILED: enemy is dead or has no health")
            return false
        }

        print("Player attackEnemy SUCCESS: attacking enemy \(enemy)")

        // Consume ammo
        if inventory.has(itemId: "piercing-rounds-magazine") {
            inventory.remove(itemId: "piercing-rounds-magazine", count: 1)
        } else {
            inventory.remove(itemId: "firearm-magazine", count: 1)
        }

        // Create projectile
        print("Player attackEnemy: creating projectile")
        let projectile = world.spawn()
        let direction = (enemyPos.worldPosition - playerPos.worldPosition).normalized
        let startPos = playerPos.worldPosition + direction * 0.5

        world.add(PositionComponent(tilePosition: IntVector2(from: startPos)), to: projectile)
        world.add(SpriteComponent(textureId: getBulletSprite(for: direction), size: Vector2(0.2, 0.2), layer: .projectile, centered: true), to: projectile)
        world.add(VelocityComponent(velocity: direction * 30), to: projectile)

        var projectileComp = ProjectileComponent(damage: playerDamage, speed: 30)
        projectileComp.target = enemy
        projectileComp.source = entity
        world.add(projectileComp, to: projectile)

        print("Player attackEnemy: projectile created with ID \(projectile), targeting enemy \(enemy)")

        // Play sound
        AudioManager.shared.playPlayerFireSound()

        return true
    }

    /// Attempts to attack an enemy at the given world position
    /// Returns true if attack was successful
    func attack(at targetPosition: Vector2) -> Bool {
        print("Player attack called at position: \(targetPosition)")
        
        // Check if player has ammo
        let hasFirearm = inventory.has(itemId: "firearm-magazine")
        let hasPiercing = inventory.has(itemId: "piercing-rounds-magazine")
        print("Player ammo check: firearm=\(hasFirearm), piercing=\(hasPiercing)")
        guard hasFirearm || hasPiercing else {
            print("Player attack FAILED: no ammo")
            return false  // No ammo
        }
        
        // Get player position
        guard let playerPos = world.get(PositionComponent.self, for: entity) else { return false }
        
        // Check range
        let distance = playerPos.worldPosition.distance(to: targetPosition)
        print("Player attack range check: distance=\(distance), range=\(attackRange)")
        guard distance <= attackRange else {
            print("Player attack FAILED: target out of range")
            return false
        }
        
        // Find enemy at target position
        let nearbyEnemies = world.getEntitiesNear(position: targetPosition, radius: 2.0)
        print("Player attack: found \(nearbyEnemies.count) nearby entities")
        var targetEnemy: Entity?

        for enemy in nearbyEnemies {
            guard world.has(EnemyComponent.self, for: enemy) else {
                print("Entity \(enemy) is not an enemy")
                continue
            }
            guard let health = world.get(HealthComponent.self, for: enemy), !health.isDead else {
                print("Entity \(enemy) has no health or is dead")
                continue
            }

            if let enemyPos = world.get(PositionComponent.self, for: enemy) {
                let enemyDistance = playerPos.worldPosition.distance(to: enemyPos.worldPosition)
                print("Enemy \(enemy) at distance \(enemyDistance)")
                if enemyDistance <= attackRange {
                    targetEnemy = enemy
                    print("Player attack: selected enemy \(enemy) at distance \(enemyDistance)")
                    break
                } else {
                    print("Enemy \(enemy) too far (\(enemyDistance) > \(attackRange))")
                }
            }
        }

        guard let enemy = targetEnemy else {
            print("Player attack FAILED: no valid enemy found at target position")
            return false
        }
        print("Player attack SUCCESS: attacking enemy \(enemy)")
        
        // Consume ammo
        if inventory.has(itemId: "piercing-rounds-magazine") {
            inventory.remove(itemId: "piercing-rounds-magazine", count: 1)
        } else {
            inventory.remove(itemId: "firearm-magazine", count: 1)
        }
        
        // Create projectile
        print("Player attack: creating projectile")
        let projectile = world.spawn()
        let direction = (targetPosition - playerPos.worldPosition).normalized
        let startPos = playerPos.worldPosition + direction * 0.5

        world.add(PositionComponent(tilePosition: IntVector2(from: startPos)), to: projectile)
        world.add(SpriteComponent(textureId: getBulletSprite(for: direction), size: Vector2(0.2, 0.2), layer: .projectile, centered: true), to: projectile)
        world.add(VelocityComponent(velocity: direction * 30), to: projectile)

        var projectileComp = ProjectileComponent(damage: playerDamage, speed: 30)
        projectileComp.target = enemy
        projectileComp.source = entity
        world.add(projectileComp, to: projectile)

        print("Player attack: projectile created with ID \(projectile), targeting enemy \(enemy)")
        
        // Play sound
        AudioManager.shared.playPlayerFireSound()

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
            let isMovingLeft = moveDirection.x < -0.1
            let isMovingUp = moveDirection.y > 0.1
            let isMovingDown = moveDirection.y < -0.1
            let isMovingRight = moveDirection.x > 0.1

            let currentFirstFrame = animation.frames.first ?? ""
            let isUsingLeftAnimation = currentFirstFrame == "player_left_0"
            let isUsingUpAnimation = currentFirstFrame == "player_up_0"
            let isUsingDownAnimation = currentFirstFrame == "player_down_0"
            let isUsingRightAnimation = currentFirstFrame == "player_right_0"
            
            if isMovingUp && !isUsingUpAnimation {
                // Switch to up animation
                if var upAnim = playerAnimationUp {
                    upAnim.currentFrame = animation.currentFrame
                    upAnim.elapsedTime = animation.elapsedTime
                    upAnim.isPlaying = animation.isPlaying
                    animation = upAnim
                    sprite.animation = animation
                    // Immediately update texture to match current frame
                    if let currentFrame = animation.update(deltaTime: 0) {
                        sprite.textureId = currentFrame
                        // print("Switched to UP animation, frame: \(currentFrame)")
                    }
                } else {
                    print("ERROR: playerAnimationUp is nil!")
                }
            }
            if isMovingDown && !isUsingDownAnimation {
                // Switch to down animation
                if var downAnim = playerAnimationDown {
                    downAnim.currentFrame = animation.currentFrame
                    downAnim.elapsedTime = animation.elapsedTime
                    downAnim.isPlaying = animation.isPlaying
                    animation = downAnim
                    sprite.animation = animation
                    // Immediately update texture to match current frame
                    if let currentFrame = animation.update(deltaTime: 0) {
                        sprite.textureId = currentFrame
                        // print("Switched to DOWN animation, frame: \(currentFrame)")
                    }
                } else {
                    print("ERROR: playerAnimationDown is nil!")
                }
            }
            if isMovingRight && !isUsingRightAnimation {
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
            sprite.textureId = animation.frames.first ?? "player_down_0"
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

