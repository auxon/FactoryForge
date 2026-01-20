import Foundation
import QuartzCore

/// System that handles enemy AI and spawning
final class EnemyAISystem: System {
    let priority = SystemPriority.enemyAI.rawValue

    private let world: World
    private let chunkManager: ChunkManager
    private weak var player: Player?

    /// Evolution factor (0-1) affects enemy strength
    private(set) var evolutionFactor: Float = 0

    /// Total pollution absorbed (drives evolution)
    private var totalPollutionAbsorbed: Float = 0

    /// Attack wave cooldown
    private var attackWaveCooldown: Float = 0
    private let attackWaveInterval: Float = 300  // 5 minutes

    // Throttling for performance
    private var lastEnemyUpdate: TimeInterval = 0
    private var lastEvolutionUpdate: TimeInterval = 0
    private let enemyUpdateInterval: TimeInterval = 0.1  // Update enemies every 100ms
    private let evolutionUpdateInterval: TimeInterval = 1.0  // Update evolution every second
    private var lastRegistrationSweep: TimeInterval = 0
    private let registrationInterval: TimeInterval = 1.0
    private var nextTargetScanTime: [Entity: TimeInterval] = [:]
    private let targetScanInterval: TimeInterval = 0.5
    private let targetScanJitter: TimeInterval = 0.2
    private var cachedAvailableEnemyTypes: [EnemyType] = []
    private var cachedEnemyTypeTier: Int = -1

    /// Active biter objects for animation management
    private var activeBiters: [Entity: Biter] = [:]

    /// Global enemy count limit to prevent overwhelming spawns
    private let maxGlobalEnemies = 50

    init(world: World, chunkManager: ChunkManager, player: Player) {
        self.world = world
        self.chunkManager = chunkManager
        self.player = player
    }

    private func cleanupDeadBiters() {
        // Remove biters that no longer have health components (dead)
        activeBiters = activeBiters.filter { entity, biter in
            return world.has(HealthComponent.self, for: entity)
        }
    }
    
    /// Registers existing enemies that don't have Biter objects yet
    /// This is needed for enemies loaded from save files or created without Biter objects
    private func registerExistingEnemies() {
        // First pass: collect entities that need component additions
        var entitiesNeedingVelocity: [Entity] = []
        var entitiesNeedingCollision: [Entity] = []
        var entitiesNeedingStateUpdate: [Entity] = []
        var entitiesNeedingEnemyUpdate: [Entity] = []
        var entitiesToRegister: [(entity: Entity, enemy: EnemyComponent)] = []

        world.forEach(EnemyComponent.self) { [self] entity, enemy in
            // Skip if already registered
            guard activeBiters[entity] == nil else { return }

            // Skip if entity doesn't have required components
            guard world.has(PositionComponent.self, for: entity) else { return }

            print("EnemyAISystem: Registering existing enemy \(entity.id), state: \(enemy.state)")

            // Collect entities that need components added
            if !world.has(VelocityComponent.self, for: entity) {
                entitiesNeedingVelocity.append(entity)
            }

            if !world.has(CollisionComponent.self, for: entity) {
                entitiesNeedingCollision.append(entity)
            }

            var needsStateUpdate = false
            var needsEnemyUpdate = false
            var updatedEnemy = enemy

            // Check if enemy needs state update
            if updatedEnemy.state == .idle {
                print("EnemyAISystem: Switching enemy \(entity.id) from idle to wandering")
                updatedEnemy.state = .wandering
                needsStateUpdate = true
            }

            // Ensure enemy has proper follow distance and attack range
            if updatedEnemy.maxFollowDistance == 0 {
                updatedEnemy.maxFollowDistance = 15.0
                needsEnemyUpdate = true
            }
            if updatedEnemy.attackRange == 0 {
                updatedEnemy.attackRange = 1.0
                needsEnemyUpdate = true
            }

            if needsStateUpdate || needsEnemyUpdate {
                entitiesNeedingEnemyUpdate.append(entity)
            }

            // Collect entity for registration
            entitiesToRegister.append((entity: entity, enemy: updatedEnemy))
        }

        // Second pass: add missing components (outside of iteration)
        for entity in entitiesNeedingVelocity {
            print("EnemyAISystem: Adding missing VelocityComponent to enemy \(entity.id)")
            world.add(VelocityComponent(), to: entity)
        }

        for entity in entitiesNeedingCollision {
            print("EnemyAISystem: Adding missing CollisionComponent to enemy \(entity.id)")
            world.add(CollisionComponent(radius: 0.4, layer: .enemy, mask: .player), to: entity)
        }

        for entity in entitiesNeedingEnemyUpdate {
            if let enemy = world.get(EnemyComponent.self, for: entity) {
                var updatedEnemy = enemy
                if updatedEnemy.state == .idle {
                    updatedEnemy.state = .wandering
                }
                if updatedEnemy.maxFollowDistance == 0 {
                    updatedEnemy.maxFollowDistance = 15.0
                }
                if updatedEnemy.attackRange == 0 {
                    updatedEnemy.attackRange = 1.0
                }
                world.add(updatedEnemy, to: entity)
            }
        }

        // Third pass: register biters (outside of iteration)
        for (entity, enemy) in entitiesToRegister {
            // Create Biter wrapper for existing entity (doesn't create new entity)
            let biter = Biter(world: world, existingEntity: entity)

            // Register the biter (using the existing entity)
            activeBiters[entity] = biter
            print("EnemyAISystem: Successfully registered enemy \(entity.id) with Biter wrapper")
        }
    }
    
    func update(deltaTime: Float) {
        let currentTime = Time.shared.totalTime
        let currentTimeSeconds = Double(currentTime)

        // Register any existing enemies that don't have Biter objects
        if currentTimeSeconds - lastRegistrationSweep >= registrationInterval {
            registerExistingEnemies()
            lastRegistrationSweep = currentTimeSeconds
        }

        // Clean up dead biters
        cleanupDeadBiters()

        // Create spawners for newly loaded chunks
        createSpawnersForLoadedChunks()

        // Update spawners (runs every frame for responsiveness)
        updateSpawners(deltaTime: deltaTime)

        // Check for attack waves (runs every frame for timing)
        updateAttackWaves(deltaTime: deltaTime)

        // Update enemy AI (throttled for performance)
        if currentTimeSeconds - lastEnemyUpdate > enemyUpdateInterval {
            updateEnemies(
                deltaTime: deltaTime * Float(enemyUpdateInterval / (currentTimeSeconds - lastEnemyUpdate)),
                currentTimeSeconds: currentTimeSeconds
            )
            lastEnemyUpdate = currentTimeSeconds
        }

        // Update evolution (throttled for performance)
        if currentTimeSeconds - lastEvolutionUpdate > evolutionUpdateInterval {
            updateEvolution(deltaTime: deltaTime * Float(evolutionUpdateInterval / (currentTimeSeconds - lastEvolutionUpdate)))
            lastEvolutionUpdate = currentTimeSeconds
        }
    }
    
    // Track which chunks have had spawners created
    private var chunksWithSpawners: Set<ChunkCoord> = []
    
    private func createSpawnersForLoadedChunks() {
        for chunk in chunkManager.allLoadedChunks {
            // Skip if we've already created spawners for this chunk
            guard !chunksWithSpawners.contains(chunk.coord) else { continue }
            
            // Create spawners for each position
            for spawnerPos in chunk.spawnerPositions {
                createSpawner(at: spawnerPos)
            }
            
            chunksWithSpawners.insert(chunk.coord)
        }
    }
    
    private func createSpawner(at position: IntVector2) {
        // print("EnemyAISystem: Creating spawner at position \(position)")

        // Check if spawner already exists at this position
        if let existingEntity = world.getEntityAt(position: position),
           world.has(SpawnerComponent.self, for: existingEntity) {
            // print("EnemyAISystem: Spawner already exists at \(position)")
            return // Spawner already exists
        }

        // Create spawner entity
        let spawner = world.spawn()
        
        world.add(PositionComponent(tilePosition: position), to: spawner)
        world.add(SpriteComponent(
            textureId: "spawner",
            size: Vector2(2.0, 2.0),
            layer: .building
        ), to: spawner)
        world.add(HealthComponent(maxHealth: 350), to: spawner)
        
        // Create spawner with all currently available enemy types
        var spawnerComp = SpawnerComponent(maxEnemies: 5, spawnCooldown: 20)
        spawnerComp.enemyTypes = getAvailableEnemyTypes()
        world.add(spawnerComp, to: spawner)
        
        // Add to chunk's entity list
        if let chunk = chunkManager.getChunk(at: position) {
            chunk.addEntity(spawner, at: position)
        }
    }
    
    // MARK: - Spawners
    
    private func updateSpawners(deltaTime: Float) {
        // let spawnerCount = world.query(SpawnerComponent.self).count
        // print("EnemyAISystem: Updating \(spawnerCount) spawners")

        // Collect spawner modifications
        var spawnerModifications: [(Entity, SpawnerComponent)] = []

        world.forEach(SpawnerComponent.self) { [self] entity, spawner in
            var spawner = spawner
            spawner.update(deltaTime: deltaTime)
            
            // Update spawner's available enemy types based on current evolution
            let availableTypes = getAvailableEnemyTypes()
            if spawner.enemyTypes != availableTypes {
                spawner.enemyTypes = availableTypes
            }

            guard let position = world.get(PositionComponent.self, for: entity) else { return }

            // Absorb pollution
            let pollution = chunkManager.getPollution(at: position.tilePosition)
            if pollution > 0 {
                let absorbed = min(pollution * 0.1 * deltaTime, pollution)
                spawner.absorbPollution(absorbed)
                totalPollutionAbsorbed += absorbed
                chunkManager.addPollution(at: position.tilePosition, amount: -absorbed)
            }

            // Spawn enemies if possible
            if spawner.canSpawn {
                spawnEnemy(from: entity, spawner: &spawner, position: position)
            }

            // Trigger attack wave if threshold reached
            if spawner.shouldTriggerAttack() {
                triggerAttackWave(from: position.worldPosition)
            }

            spawnerModifications.append((entity, spawner))
        }

        // Apply spawner modifications
        for (entity, spawner) in spawnerModifications {
            world.add(spawner, to: entity)
        }
    }

    private func spawnEnemy(from spawnerEntity: Entity, spawner: inout SpawnerComponent, position: PositionComponent) {
        // Check global enemy limit
        let currentEnemyCount = world.query(EnemyComponent.self).count
        guard currentEnemyCount < maxGlobalEnemies else {
            // print("EnemyAISystem: Global enemy limit reached (\(currentEnemyCount)/\(maxGlobalEnemies)), skipping spawn")
            return
        }

        // print("EnemyAISystem: Spawning enemy from spawner at position \(position.worldPosition)")

        // Select enemy type based on evolution
        let enemyType = selectEnemyType(for: spawner)
        
        // Find spawn position near spawner
        let angle = Float.random(in: 0...(.pi * 2))
        let distance = Float.random(in: 2...5)
        let spawnOffset = Vector2(cosf(angle) * distance, sinf(angle) * distance)
        let spawnPos = position.worldPosition + spawnOffset
        
        // Create biter object
        let biter = Biter(world: world)

        // Set initial position
        biter.position = spawnPos
        let spawnTile = IntVector2(from: spawnPos)

        // Add health component
        let scaledHealth = enemyType.baseHealth * (1 + evolutionFactor)
        world.add(HealthComponent(maxHealth: scaledHealth), to: biter.biterEntity)

        // Add enemy component
        var enemyComp = EnemyComponent(type: enemyType)
        enemyComp.damage *= (1 + evolutionFactor * 0.5)
        enemyComp.speed *= (1 + evolutionFactor * 0.2)
        enemyComp.attackRange *= 1.0  // Keep base attack range (1.0 total for biters)
        enemyComp.maxFollowDistance = 15.0  // Reasonable follow distance
        enemyComp.spawnerEntity = spawnerEntity  // Track which spawner created this enemy
        enemyComp.state = .wandering  // Start wandering to actively seek targets
        world.add(enemyComp, to: biter.biterEntity)

        // Add velocity and collision components
        world.add(VelocityComponent(), to: biter.biterEntity)
        world.add(CollisionComponent(radius: 0.4, layer: .enemy, mask: .player), to: biter.biterEntity)

        if let chunk = chunkManager.getChunk(at: spawnTile) {
            chunk.addEntity(biter.biterEntity, at: spawnTile)
        }

        // Store the biter object for animation updates
        activeBiters[biter.biterEntity] = biter
        
        spawner.spawn()
    }
    
    private func selectEnemyType(for spawner: SpawnerComponent) -> EnemyType {
        var availableTypes = getAvailableEnemyTypes()
        
        // Filter by spawner's allowed types if specified
        let allowed = Set(spawner.enemyTypes)
        if !allowed.isEmpty {
            availableTypes = availableTypes.filter { allowed.contains($0) }
        }
        
        return availableTypes.randomElement() ?? .smallBiter
    }
    
    /// Returns all enemy types currently available based on evolution factor
    private func getAvailableEnemyTypes() -> [EnemyType] {
        let tier = enemyTypeTier(for: evolutionFactor)
        if tier == cachedEnemyTypeTier {
            return cachedAvailableEnemyTypes
        }

        var availableTypes: [EnemyType] = [.smallBiter, .mediumBiter]  // Start with medium biters available
        
        if evolutionFactor > 0.1 {
            availableTypes.append(.smallSpitter)
        }
        if evolutionFactor > 0.3 {
            availableTypes.append(.bigBiter)
            availableTypes.append(.mediumSpitter)
        }
        if evolutionFactor > 0.6 {
            availableTypes.append(.behemothBiter)
            availableTypes.append(.bigSpitter)
        }
        if evolutionFactor > 0.9 {
            availableTypes.append(.behemothSpitter)
        }
        
        cachedEnemyTypeTier = tier
        cachedAvailableEnemyTypes = availableTypes
        return availableTypes
    }
    
    // MARK: - Enemy AI
    
    private func updateEnemies(deltaTime: Float, currentTimeSeconds: TimeInterval) {
        // Collect all modifications to apply after iteration
        var enemyModifications: [(Entity, EnemyComponent)] = []
        var velocityModifications: [(Entity, VelocityComponent)] = []

        // Process each enemy entity
        world.forEach(EnemyComponent.self) { [self] entity, enemy in
            enemy.update(deltaTime: deltaTime)

            guard let position = world.get(PositionComponent.self, for: entity),
                  var velocity = world.get(VelocityComponent.self, for: entity) else { return }

            // print("EnemyAISystem: Processing enemy \(entity.id), state: \(enemy.state)")

            switch enemy.state {
            case EnemyState.idle:
                // Look for targets
                if shouldScanForTarget(entity: entity, currentTimeSeconds: currentTimeSeconds),
                   let target = findTarget(for: entity, position: position, enemy: enemy) {
                    enemy.targetEntity = target
                    enemy.state = EnemyState.attacking
                    enemyModifications.append((entity, enemy))  // Collect for later
                }

            case EnemyState.wandering:
                // Random movement - increased frequency for more active behavior
                if Float.random(in: 0...1) < 0.3 {  // 30% chance per frame to change direction
                    velocity.velocity = Vector2(
                        Float.random(in: -1...1),
                        Float.random(in: -1...1)
                    ).normalized * enemy.speed * 0.7  // More active wandering
                }
                velocityModifications.append((entity, velocity))  // Collect for later

                // Update biter animation
                if let biter = activeBiters[entity] {
                    biter.updateAnimation(velocity: velocity.velocity)
                }

                // While wandering, periodically check for targets
                if shouldScanForTarget(entity: entity, currentTimeSeconds: currentTimeSeconds),
                   let target = findTarget(for: entity, position: position, enemy: enemy) {
                    enemy.targetEntity = target
                    enemy.state = EnemyState.attacking
                    enemy.timeSinceAttack = enemy.attackCooldown  // Allow immediate attack when switching to attacking
                    enemyModifications.append((entity, enemy))  // Collect for later
                }

            case EnemyState.attacking:
                // print("EnemyAISystem: Enemy \(entity.id) is in ATTACKING state")
                // Move toward target
                if let target = enemy.targetEntity,
                   let targetPos = world.get(PositionComponent.self, for: target) {
                    let distance = position.worldPosition.distance(to: targetPos.worldPosition)
                    // print("EnemyAISystem: Enemy \(entity.id) distance to target: \(distance), attackRange: \(enemy.attackRange)")

                    // Check if target is too far away
                    if distance > enemy.maxFollowDistance {
                        // print("EnemyAISystem: Enemy \(entity.id) giving up pursuit")
                        enemy.targetEntity = nil
                        enemy.state = EnemyState.returning
                        enemyModifications.append((entity, enemy))  // Collect for later
                        break
                    }

                    if distance <= enemy.attackRange {
                        // print("EnemyAISystem: Enemy \(entity.id) IN ATTACK RANGE!")
                        // Attack
                        velocity.velocity = Vector2.zero
                        velocityModifications.append((entity, velocity))  // Collect for later

                        // Update biter animation (stopped moving)
                        if let biter = activeBiters[entity] {
                            biter.updateAnimation(velocity: Vector2.zero)
                        }

                        if enemy.canAttack {
                            // print("EnemyAISystem: Enemy \(entity.id) ATTACKING!")
                            attackTarget(enemy: &enemy, target: target)
                            enemyModifications.append((entity, enemy))  // Collect after attack
                        } else {
                            // print("EnemyAISystem: Enemy \(entity.id) on cooldown (\(enemy.timeSinceAttack)/\(enemy.attackCooldown))")
                        }
                    } else {
                        // Move toward target
                        let direction = (targetPos.worldPosition - position.worldPosition).normalized
                        velocity.velocity = direction * enemy.speed
                        velocityModifications.append((entity, velocity))  // Collect for later

                        // Update biter animation
                        if let biter = activeBiters[entity] {
                            biter.updateAnimation(velocity: velocity.velocity)
                        }
                    }
                } else {
                    // Lost target
                    // print("EnemyAISystem: Enemy \(entity.id) lost target")
                    enemy.targetEntity = nil
                    enemy.state = EnemyState.idle
                    enemyModifications.append((entity, enemy))  // Collect for later
                }

            case EnemyState.returning:
                var foundTarget: Entity?

                if shouldScanForTarget(entity: entity, currentTimeSeconds: currentTimeSeconds) {
                    let nearbyTargets = world.getEntitiesNear(position: position.worldPosition, radius: 10.0)
                    for candidate in nearbyTargets {
                        if world.has(EnemyComponent.self, for: candidate) { continue }
                        if world.has(SpawnerComponent.self, for: candidate) { continue }
                        if candidate == player?.playerEntity { continue }
                        guard world.has(HealthComponent.self, for: candidate) else { continue }
                        if isTargetableBuilding(candidate) {
                            foundTarget = candidate
                            break
                        }
                    }
                }
                
                // Also check for player
                if foundTarget == nil, let player = player {
                    if let playerPos = world.get(PositionComponent.self, for: player.playerEntity) {
                        let distanceToPlayer = position.worldPosition.distance(to: playerPos.worldPosition)
                        if distanceToPlayer <= 10.0 {
                            foundTarget = player.playerEntity
                        }
                    }
                }

                if let target = foundTarget {
                    enemy.targetEntity = target
                    enemy.state = EnemyState.attacking
                    enemyModifications.append((entity, enemy))  // Collect for later
                    break
                }

                // Return to spawner
                if let spawnerEntity = enemy.spawnerEntity,
                   let spawnerPos = world.get(PositionComponent.self, for: spawnerEntity) {
                    let direction = (spawnerPos.worldPosition - position.worldPosition).normalized
                    let distance = position.worldPosition.distance(to: spawnerPos.worldPosition)

                    if distance < 2.0 {
                        enemy.state = EnemyState.idle
                        enemyModifications.append((entity, enemy))  // Collect for later
                    } else {
                        velocity.velocity = direction * enemy.speed * 0.8
                        velocityModifications.append((entity, velocity))  // Collect for later

                        if let biter = activeBiters[entity] {
                            biter.updateAnimation(velocity: velocity.velocity)
                        }
                    }
                } else {
                    enemy.state = EnemyState.idle
                    enemyModifications.append((entity, enemy))  // Collect for later
                }

            case EnemyState.fleeing:
                if let playerPos = player?.position {
                    let direction = (position.worldPosition - playerPos).normalized
                    velocity.velocity = direction * enemy.speed * 1.5
                    velocityModifications.append((entity, velocity))  // Collect for later
                }
                break
            }
        }
        
        // Apply all modifications after iteration completes
        for (entity, enemy) in enemyModifications {
            world.add(enemy, to: entity)
        }
        
        for (entity, velocity) in velocityModifications {
            world.add(velocity, to: entity)
            
            // Apply velocity to position
            if let position = world.get(PositionComponent.self, for: entity),
               velocity.velocity.lengthSquared > 0.001 {
                var pos = position
                let oldTilePos = pos.tilePosition
                pos.offset = pos.offset + velocity.velocity * deltaTime

                // Handle tile transitions
                while pos.offset.x >= 1 {
                    pos.offset.x -= 1
                    pos.tilePosition.x += 1
                }
                while pos.offset.x < 0 {
                    pos.offset.x += 1
                    pos.tilePosition.x -= 1
                }
                while pos.offset.y >= 1 {
                    pos.offset.y -= 1
                    pos.tilePosition.y += 1
                }
                while pos.offset.y < 0 {
                    pos.offset.y += 1
                    pos.tilePosition.y -= 1
                }

                world.add(pos, to: entity)

                if oldTilePos != pos.tilePosition {
                    if let oldChunk = chunkManager.getChunk(at: oldTilePos) {
                        oldChunk.removeEntity(entity)
                    }
                    if let newChunk = chunkManager.getChunk(at: pos.tilePosition) {
                        newChunk.addEntity(entity, at: pos.tilePosition)
                    }
                }
            }
        }
    }
    
    private func findTarget(for entity: Entity, position: PositionComponent, enemy: EnemyComponent) -> Entity? {
        let searchRadius: Float = 15  // Search radius should be close to attack range to avoid premature attacking state

        // Prioritize player if in range
        if let player = player {
            // print("EnemyAISystem: Player exists, playerEntity: \(player.playerEntity.id)")
            if let playerPos = world.get(PositionComponent.self, for: player.playerEntity) {
                let distanceToPlayer = position.worldPosition.distance(to: playerPos.worldPosition)
                if distanceToPlayer <= searchRadius {
                    return player.playerEntity
                }
            } else {
                // print("EnemyAISystem: Player exists but no position component")
            }
        } else {
            //print("EnemyAISystem: No player reference")
        }
        
        // Otherwise find nearest valid target (only buildings and player)
        let nearbyEntities = world.getEntitiesNear(position: position.worldPosition, radius: searchRadius)
        
        var closestTarget: Entity?
        var closestDistance: Float = Float.infinity
        
        for candidate in nearbyEntities {
            // Skip if it's an enemy or spawner
            if world.has(EnemyComponent.self, for: candidate) { continue }
            if world.has(SpawnerComponent.self, for: candidate) { continue }
            
            // Skip player entity (already checked above)
            if candidate == player?.playerEntity { continue }
            
            // Must have health
            guard world.has(HealthComponent.self, for: candidate) else { continue }
            
            guard isTargetableBuilding(candidate) else { continue }
            
            guard let candidatePos = world.get(PositionComponent.self, for: candidate) else { continue }
            
            let distance = position.worldPosition.distance(to: candidatePos.worldPosition)
            if distance < closestDistance {
                closestDistance = distance
                closestTarget = candidate
            }
        }
        
        return closestTarget
    }
    
    private func attackTarget(enemy: inout EnemyComponent, target: Entity) {
        guard var health = world.get(HealthComponent.self, for: target) else { return }

        let damageDealt = health.takeDamage(enemy.damage)
        enemy.attack()

        #if DEBUG
        print("Enemy \(enemy.type) attacked target \(target.id) for \(damageDealt) damage! Target health: \(health.current)/\(health.max)")
        #endif

        if health.isDead {
            #if DEBUG
            print("Target \(target.id) died from enemy attack!")
            #endif
            world.despawnDeferred(target)
            enemy.targetEntity = nil
            enemy.state = EnemyState.idle
        } else {
            world.add(health, to: target)
        }
    }
    
    // MARK: - Attack Waves
    
    private func updateAttackWaves(deltaTime: Float) {
        attackWaveCooldown -= deltaTime
        
        if attackWaveCooldown <= 0 {
            attackWaveCooldown = attackWaveInterval
            
            // Trigger attack wave from a random direction
            if let playerPos = player?.position {
                let angle = Float.random(in: 0...(.pi * 2))
                let distance: Float = 50
                let waveOrigin = playerPos + Vector2(cosf(angle), sinf(angle)) * distance
                triggerAttackWave(from: waveOrigin)
            }
        }
    }
    
    private func triggerAttackWave(from origin: Vector2) {
        guard (player?.position) != nil else { return }

        // Check global enemy limit
        let currentEnemyCount = world.query(EnemyComponent.self).count
        guard currentEnemyCount < maxGlobalEnemies else {
            // print("EnemyAISystem: Global enemy limit reached (\(currentEnemyCount)/\(maxGlobalEnemies)), skipping attack wave")
            return
        }

        // Determine wave size based on pollution and evolution (smaller waves)
        let waveSize = Int(3 + evolutionFactor * 5)
        
        for _ in 0..<waveSize {
            let offset = Vector2(
                Float.random(in: -5...5),
                Float.random(in: -5...5)
            )
            let spawnPos = origin + offset
            
            // Create biter object (like spawnEnemy does)
            let biter = Biter(world: world)
            biter.position = spawnPos
            
            // Select enemy type based on evolution (same as spawnEnemy)
            let tempSpawner = SpawnerComponent(maxEnemies: 10, spawnCooldown: 10)
            let enemyType = selectEnemyType(for: tempSpawner)
            let scaledHealth = enemyType.baseHealth * (1 + evolutionFactor)
            world.add(HealthComponent(maxHealth: scaledHealth), to: biter.biterEntity)
            
            // Add enemy component
            var enemyComp = EnemyComponent(type: enemyType)
            enemyComp.damage *= (1 + evolutionFactor * 0.5)
            enemyComp.speed *= (1 + evolutionFactor * 0.2)
            // Attack range is set by enemy type (biters = 1.0, spitters = 13-16)
            enemyComp.maxFollowDistance = 15.0
            enemyComp.state = .attacking
            // Set player as target for attack wave enemies
            if let playerEntity = player?.playerEntity {
                enemyComp.targetEntity = playerEntity
            }
            world.add(enemyComp, to: biter.biterEntity)
            
            // Add velocity and collision components
            world.add(VelocityComponent(), to: biter.biterEntity)
            world.add(CollisionComponent(radius: 0.4, layer: .enemy, mask: .player), to: biter.biterEntity)
            
            // Store the biter object for animation updates
            activeBiters[biter.biterEntity] = biter
        }
    }
    
    // MARK: - Evolution
    
    private func updateEvolution(deltaTime: Float) {
        // Evolution increases slowly over time and from pollution
        let pollutionEvolution = totalPollutionAbsorbed * 0.00001

        evolutionFactor = min(1.0, (Time.shared.totalTime / (60 * 60 * 4)) * 0.5 + pollutionEvolution * 0.5)
    }

    private func enemyTypeTier(for evolution: Float) -> Int {
        var tier = 0
        if evolution > 0.1 { tier += 1 }
        if evolution > 0.3 { tier += 1 }
        if evolution > 0.6 { tier += 1 }
        if evolution > 0.9 { tier += 1 }
        return tier
    }

    private func shouldScanForTarget(entity: Entity, currentTimeSeconds: TimeInterval) -> Bool {
        if let nextScan = nextTargetScanTime[entity], currentTimeSeconds < nextScan {
            return false
        }
        nextTargetScanTime[entity] = currentTimeSeconds + targetScanInterval + Double.random(in: 0...targetScanJitter)
        return true
    }

    private func isTargetableBuilding(_ entity: Entity) -> Bool {
        return world.has(FurnaceComponent.self, for: entity) ||
            world.has(AssemblerComponent.self, for: entity) ||
            world.has(MinerComponent.self, for: entity) ||
            world.has(GeneratorComponent.self, for: entity) ||
            world.has(ChestComponent.self, for: entity) ||
            world.has(LabComponent.self, for: entity) ||
            world.has(TurretComponent.self, for: entity) ||
            world.has(PowerPoleComponent.self, for: entity) ||
            world.has(SolarPanelComponent.self, for: entity) ||
            world.has(AccumulatorComponent.self, for: entity) ||
            world.has(BeltComponent.self, for: entity) ||
            world.has(InserterComponent.self, for: entity)
    }
}
