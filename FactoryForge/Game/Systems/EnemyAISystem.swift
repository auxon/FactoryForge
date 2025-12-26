import Foundation

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
    
    init(world: World, chunkManager: ChunkManager, player: Player) {
        self.world = world
        self.chunkManager = chunkManager
        self.player = player
    }
    
    func update(deltaTime: Float) {
        // Create spawners for newly loaded chunks
        createSpawnersForLoadedChunks()
        
        // Update spawners
        updateSpawners(deltaTime: deltaTime)
        
        // Update enemy AI
        updateEnemies(deltaTime: deltaTime)
        
        // Check for attack waves
        updateAttackWaves(deltaTime: deltaTime)
        
        // Update evolution
        updateEvolution(deltaTime: deltaTime)
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
        // Check if spawner already exists at this position
        if let existingEntity = world.getEntityAt(position: position),
           world.has(SpawnerComponent.self, for: existingEntity) {
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
        world.add(SpawnerComponent(maxEnemies: 10, spawnCooldown: 10), to: spawner)
        
        // Add to chunk's entity list
        if let chunk = chunkManager.getChunk(at: position) {
            chunk.addEntity(spawner, at: position)
        }
    }
    
    // MARK: - Spawners
    
    private func updateSpawners(deltaTime: Float) {
        world.forEach(SpawnerComponent.self) { [self] entity, spawner in
            spawner.update(deltaTime: deltaTime)
            
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
        }
    }
    
    private func spawnEnemy(from spawnerEntity: Entity, spawner: inout SpawnerComponent, position: PositionComponent) {
        // Select enemy type based on evolution
        let enemyType = selectEnemyType(for: spawner)
        
        // Find spawn position near spawner
        let angle = Float.random(in: 0...(.pi * 2))
        let distance = Float.random(in: 2...5)
        let spawnOffset = Vector2(cosf(angle) * distance, sinf(angle) * distance)
        let spawnPos = position.worldPosition + spawnOffset
        
        // Create enemy entity
        let enemy = world.spawn()
        
        world.add(PositionComponent(
            tilePosition: IntVector2(from: spawnPos),
            offset: Vector2(spawnPos.x.truncatingRemainder(dividingBy: 1),
                           spawnPos.y.truncatingRemainder(dividingBy: 1))
        ), to: enemy)
        
        world.add(SpriteComponent(
            textureId: "biter",
            size: Vector2(0.8, 0.8),
            layer: .enemy,
            centered: true
        ), to: enemy)
        
        let scaledHealth = enemyType.baseHealth * (1 + evolutionFactor)
        world.add(HealthComponent(maxHealth: scaledHealth), to: enemy)
        
        var enemyComp = EnemyComponent(type: enemyType)
        enemyComp.damage *= (1 + evolutionFactor * 0.5)
        enemyComp.speed *= (1 + evolutionFactor * 0.2)
        enemyComp.spawnerEntity = spawnerEntity  // Track which spawner created this enemy
        world.add(enemyComp, to: enemy)
        
        world.add(VelocityComponent(), to: enemy)
        world.add(CollisionComponent(radius: 0.4, layer: .enemy, mask: .player), to: enemy)
        
        spawner.spawn()
    }
    
    private func selectEnemyType(for spawner: SpawnerComponent) -> EnemyType {
        var availableTypes: [EnemyType] = [.smallBiter]
        
        if evolutionFactor > 0.2 {
            availableTypes.append(.mediumBiter)
            availableTypes.append(.smallSpitter)
        }
        if evolutionFactor > 0.5 {
            availableTypes.append(.bigBiter)
            availableTypes.append(.mediumSpitter)
        }
        if evolutionFactor > 0.8 {
            availableTypes.append(.behemothBiter)
            availableTypes.append(.bigSpitter)
        }
        if evolutionFactor > 0.95 {
            availableTypes.append(.behemothSpitter)
        }
        
        // Filter by spawner's allowed types if specified
        let allowed = Set(spawner.enemyTypes)
        if !allowed.isEmpty {
            availableTypes = availableTypes.filter { allowed.contains($0) }
        }
        
        return availableTypes.randomElement() ?? .smallBiter
    }
    
    // MARK: - Enemy AI
    
    private func updateEnemies(deltaTime: Float) {
        world.forEach(EnemyComponent.self) { [self] entity, enemy in
            enemy.update(deltaTime: deltaTime)
            
            guard let position = world.get(PositionComponent.self, for: entity),
                  var velocity = world.get(VelocityComponent.self, for: entity) else { return }
            
            switch enemy.state {
            case .idle:
                // Look for targets
                if let target = findTarget(for: entity, position: position, enemy: enemy) {
                    enemy.targetEntity = target
                    enemy.state = .attacking
                }
                
            case .wandering:
                // Random movement
                if Float.random(in: 0...1) < 0.01 {
                    velocity.velocity = Vector2(
                        Float.random(in: -1...1),
                        Float.random(in: -1...1)
                    ).normalized * enemy.speed * 0.3
                }
                world.add(velocity, to: entity)
                
            case .attacking:
                // Move toward target
                if let target = enemy.targetEntity,
                   let targetPos = world.get(PositionComponent.self, for: target) {
                    let distance = position.worldPosition.distance(to: targetPos.worldPosition)

                    // Check if target is too far away
                    if distance > enemy.maxFollowDistance {
                        // Give up pursuit and return to spawner
                        enemy.targetEntity = nil
                        enemy.state = .returning
                        break
                    }

                    if distance <= enemy.attackRange {
                        // Attack
                        velocity.velocity = .zero
                        if enemy.canAttack {
                            attackTarget(enemy: &enemy, target: target)
                        }
                    } else {
                        // Move toward target
                        let direction = (targetPos.worldPosition - position.worldPosition).normalized
                        velocity.velocity = direction * enemy.speed
                    }
                    world.add(velocity, to: entity)
                } else {
                    // Lost target
                    enemy.targetEntity = nil
                    enemy.state = .idle
                }
                
            case .returning:
                // Check if player is nearby (smaller radius) and switch back to attacking
                let nearbyTargets = world.getEntitiesNear(position: position.worldPosition, radius: 10.0)
                var foundTarget: Entity?

                for candidate in nearbyTargets {
                    if world.has(EnemyComponent.self, for: candidate) { continue }
                    if world.has(SpawnerComponent.self, for: candidate) { continue }

                    if world.has(HealthComponent.self, for: candidate) {
                        foundTarget = candidate
                        break
                    }
                }

                if let target = foundTarget {
                    enemy.targetEntity = target
                    enemy.state = .attacking
                    break
                }

                // Return to spawner
                if let spawnerEntity = enemy.spawnerEntity,
                   let spawnerPos = world.get(PositionComponent.self, for: spawnerEntity) {
                    let direction = (spawnerPos.worldPosition - position.worldPosition).normalized
                    let distance = position.worldPosition.distance(to: spawnerPos.worldPosition)

                    if distance < 2.0 {
                        // Close enough to spawner, go idle
                        enemy.state = .idle
                    } else {
                        // Move toward spawner
                        velocity.velocity = direction * enemy.speed * 0.8  // Slower return speed
                        world.add(velocity, to: entity)
                    }
                } else {
                    // No spawner, just go idle
                    enemy.state = .idle
                }
                
            case .fleeing:
                // Run away from player
                if let playerPos = player?.position {
                    let direction = (position.worldPosition - playerPos).normalized
                    velocity.velocity = direction * enemy.speed * 1.5
                    world.add(velocity, to: entity)
                }
                break
            }
            
            // Apply velocity
            if velocity.velocity.lengthSquared > 0.001 {
                var pos = position
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
            }
        }
    }
    
    private func findTarget(for entity: Entity, position: PositionComponent, enemy: EnemyComponent) -> Entity? {
        let searchRadius: Float = 20
        
        // Prioritize player if in range
        if let player = player,
           let playerPos = world.get(PositionComponent.self, for: player.playerEntity) {
            let distanceToPlayer = position.worldPosition.distance(to: playerPos.worldPosition)
            if distanceToPlayer <= searchRadius {
                return player.playerEntity
            }
        }
        
        // Otherwise find nearest valid target
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
        
        health.takeDamage(enemy.damage)
        enemy.attack()
        
        if health.isDead {
            world.despawnDeferred(target)
            enemy.targetEntity = nil
            enemy.state = .idle
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
        guard let playerPos = player?.position else { return }
        
        // Determine wave size based on pollution and evolution
        let waveSize = Int(5 + evolutionFactor * 15)
        
        for _ in 0..<waveSize {
            let offset = Vector2(
                Float.random(in: -5...5),
                Float.random(in: -5...5)
            )
            let spawnPos = origin + offset
            
            // Create attacking enemy
            let enemy = world.spawn()
            
            world.add(PositionComponent(tilePosition: IntVector2(from: spawnPos)), to: enemy)
            world.add(SpriteComponent(textureId: "biter", size: Vector2(0.8, 0.8), layer: .enemy, centered: true), to: enemy)
            
            let enemyType = EnemyType.smallBiter
            world.add(HealthComponent(maxHealth: enemyType.baseHealth * (1 + evolutionFactor)), to: enemy)
            
            var enemyComp = EnemyComponent(type: enemyType)
            enemyComp.state = .attacking
            // Set player as target for attack wave enemies
            if let playerEntity = player?.playerEntity {
                enemyComp.targetEntity = playerEntity
            }
            world.add(enemyComp, to: enemy)
            
            world.add(VelocityComponent(), to: enemy)
            world.add(CollisionComponent(radius: 0.4, layer: .enemy, mask: .player), to: enemy)
        }
    }
    
    // MARK: - Evolution
    
    private func updateEvolution(deltaTime: Float) {
        // Evolution increases slowly over time and from pollution
        let pollutionEvolution = totalPollutionAbsorbed * 0.00001

        evolutionFactor = min(1.0, (Time.shared.totalTime / (60 * 60 * 4)) * 0.5 + pollutionEvolution * 0.5)
    }
}

