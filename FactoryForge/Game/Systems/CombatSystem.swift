import Foundation

/// System that handles combat between turrets, enemies, and projectiles
final class CombatSystem: System {
    let priority = SystemPriority.combat.rawValue
    
    private let world: World
    private let chunkManager: ChunkManager
    private weak var renderer: MetalRenderer?
    
    init(world: World, chunkManager: ChunkManager) {
        self.world = world
        self.chunkManager = chunkManager
    }
    
    func setRenderer(_ renderer: MetalRenderer?) {
        self.renderer = renderer
    }
    
    private func getRenderer() -> MetalRenderer? {
        return renderer
    }
    
    func update(deltaTime: Float) {
        // Update turrets
        updateTurrets(deltaTime: deltaTime)
        
        // Update projectiles
        updateProjectiles(deltaTime: deltaTime)
        
        // Process pending despawns
        world.processPending()
    }
    
    // MARK: - Turrets
    
    private func updateTurrets(deltaTime: Float) {
        world.forEach(TurretComponent.self) { [self] entity, turret in
            turret.update(deltaTime: deltaTime)
            
            guard let position = world.get(PositionComponent.self, for: entity) else { return }
            
            // Check for ammo (gun turrets only)
            if let inventory = world.get(InventoryComponent.self, for: entity) {
                if inventory.isEmpty {
                    // No ammo
                    turret.targetEntity = nil
                    return
                }
            }
            
            // Check power for laser turrets
            if let power = world.get(PowerConsumerComponent.self, for: entity) {
                if power.satisfaction < 0.5 {
                    turret.targetEntity = nil
                    return
                }
            }
            
            // Find or validate target
            if let target = turret.targetEntity {
                if !isValidTarget(target, from: position.worldPosition, range: turret.range) {
                    turret.targetEntity = nil
                }
            }
            
            if turret.targetEntity == nil {
                turret.targetEntity = findTarget(from: position.worldPosition, range: turret.range)
            }
            
            // Aim and fire
            if let target = turret.targetEntity,
               let targetPos = world.get(PositionComponent.self, for: target) {
                
                let direction = targetPos.worldPosition - position.worldPosition
                turret.targetRotation = atan2f(direction.y, direction.x)
                
                // Fire if ready and aimed
                let aimError = abs(turret.rotation - turret.targetRotation)
                if turret.isReady && aimError < 0.1 {
                    fire(turret: &turret, entity: entity, position: position, target: target, targetPos: targetPos)
                }
            }
        }
    }
    
    private func isValidTarget(_ target: Entity, from position: Vector2, range: Float) -> Bool {
        guard world.isAlive(target) else { return false }
        guard let health = world.get(HealthComponent.self, for: target), !health.isDead else { return false }
        guard let targetPos = world.get(PositionComponent.self, for: target) else { return false }
        
        let distance = position.distance(to: targetPos.worldPosition)
        return distance <= range
    }
    
    private func findTarget(from position: Vector2, range: Float) -> Entity? {
        let candidates = world.getEntitiesNear(position: position, radius: range)
        
        var closestEnemy: Entity?
        var closestDistance: Float = Float.infinity
        
        for candidate in candidates {
            guard world.has(EnemyComponent.self, for: candidate) else { continue }
            guard let health = world.get(HealthComponent.self, for: candidate), !health.isDead else { continue }
            guard let candidatePos = world.get(PositionComponent.self, for: candidate) else { continue }
            
            let distance = position.distance(to: candidatePos.worldPosition)
            if distance < closestDistance {
                closestDistance = distance
                closestEnemy = candidate
            }
        }
        
        return closestEnemy
    }
    
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
    
    private func fire(turret: inout TurretComponent, entity: Entity, position: PositionComponent, target: Entity, targetPos: PositionComponent) {
        turret.fire()
        
        // Consume ammo for gun turrets
        if var inventory = world.get(InventoryComponent.self, for: entity) {
            inventory.remove(itemId: "firearm-magazine", count: 1)
            if inventory.count(of: "firearm-magazine") == 0 {
                inventory.remove(itemId: "piercing-rounds-magazine", count: 1)
            }
            world.add(inventory, to: entity)
        }
        
        // Create projectile
        let projectile = world.spawn()
        
        let direction = (targetPos.worldPosition - position.worldPosition).normalized
        let startPos = position.worldPosition + direction * 0.5

        let startTile = IntVector2(from: startPos)
        world.add(PositionComponent(tilePosition: startTile), to: projectile)
        world.add(SpriteComponent(textureId: getBulletSprite(for: direction), size: Vector2(0.2, 0.2), layer: .projectile, centered: true), to: projectile)
        world.add(VelocityComponent(velocity: direction * 30), to: projectile)
        if let chunk = chunkManager.getChunk(at: startTile) {
            chunk.addEntity(projectile, at: startTile)
        }
        
        var projectileComp = ProjectileComponent(damage: turret.damage, speed: 30)
        projectileComp.target = target
        projectileComp.source = entity
        world.add(projectileComp, to: projectile)
        
        // Play sound
        AudioManager.shared.playTurretFireSound()
    }
    
    // MARK: - Projectiles
    
    private func updateProjectiles(deltaTime: Float) {
        // print("CombatSystem: updating projectiles")
        world.forEach(ProjectileComponent.self) { [self] entity, projectile in
            // print("CombatSystem: processing projectile \(entity)")
            var proj = projectile
            proj.lifetime -= deltaTime
            
            if proj.lifetime <= 0 {
                print("Projectile \(entity) expired (lifetime reached 0), target was: \(proj.target?.id ?? 0)")
                if let position = world.get(PositionComponent.self, for: entity),
                   let chunk = chunkManager.getChunk(at: position.tilePosition) {
                    chunk.removeEntity(entity)
                }
                world.despawnDeferred(entity)
                return
            }
            
            guard var position = world.get(PositionComponent.self, for: entity),
                  let velocity = world.get(VelocityComponent.self, for: entity) else { return }
            
            // Simple check: if projectile has been alive for a while and target is still very far, despawn
            // This prevents projectiles from chasing targets across the entire map
            // Projectiles at speed 30 can travel ~150 units in 5 seconds
            // If we're past 3 seconds and target is still >200 units away, give up
            let maxReasonableDistance: Float = 200.0
            if proj.lifetime < 2.0 {  // Less than 2 seconds left
                if let target = proj.target,
                   let targetPos = world.get(PositionComponent.self, for: target) {
                    let distanceToTarget = position.worldPosition.distance(to: targetPos.worldPosition)
                    if distanceToTarget > maxReasonableDistance {
                        print("Projectile \(entity) target too far (\(distanceToTarget) > \(maxReasonableDistance)) with low lifetime, despawning")
                        if let chunk = chunkManager.getChunk(at: position.tilePosition) {
                            chunk.removeEntity(entity)
                        }
                        world.despawnDeferred(entity)
                        return
                    }
                }
            }
            
            // Move projectile
            let oldTilePos = position.tilePosition
            position.offset = position.offset + velocity.velocity * deltaTime
            
            // Handle tile transitions
            while position.offset.x >= 1 {
                position.offset.x -= 1
                position.tilePosition.x += 1
            }
            while position.offset.x < 0 {
                position.offset.x += 1
                position.tilePosition.x -= 1
            }
            while position.offset.y >= 1 {
                position.offset.y -= 1
                position.tilePosition.y += 1
            }
            while position.offset.y < 0 {
                position.offset.y += 1
                position.tilePosition.y -= 1
            }
            
            world.add(position, to: entity)

            if oldTilePos != position.tilePosition {
                if let oldChunk = chunkManager.getChunk(at: oldTilePos) {
                    oldChunk.removeEntity(entity)
                }
                if let newChunk = chunkManager.getChunk(at: position.tilePosition) {
                    newChunk.addEntity(entity, at: position.tilePosition)
                }
            }
            
            // Check for collision with target
            if let target = proj.target {
                // Check if target is still valid (alive and has position)
                guard world.isAlive(target),
                      let targetHealth = world.get(HealthComponent.self, for: target),
                      !targetHealth.isDead,
                      let targetPos = world.get(PositionComponent.self, for: target) else {
                    // Target is dead or invalid, despawn projectile
                    print("Projectile \(entity) target \(target) is dead or invalid, despawning")
                    if let position = world.get(PositionComponent.self, for: entity),
                       let chunk = chunkManager.getChunk(at: position.tilePosition) {
                        chunk.removeEntity(entity)
                    }
                    world.despawnDeferred(entity)
                    return
                }
                
                let distance = position.worldPosition.distance(to: targetPos.worldPosition)
                
                // Check if target is too far away (beyond reasonable travel distance)
                // Projectile speed is 30 units/sec, so in 5 seconds it can travel 150 units
                // If target is more than 200 units away and we're past half lifetime, give up
                let maxReasonableDistance: Float = 200.0
                if distance > maxReasonableDistance && proj.lifetime < 2.5 {
                    // Only log if distance is extremely far to avoid spam
                    if distance > 1000.0 {
                        print("Projectile \(entity) target \(target) extremely far (\(distance) > \(maxReasonableDistance)), despawning")
                    }
                    if let chunk = chunkManager.getChunk(at: position.tilePosition) {
                        chunk.removeEntity(entity)
                    }
                    world.despawnDeferred(entity)
                    return
                }
                
                if distance < 0.5 {
                    // Hit target
                    print("Projectile \(entity) hit target \(target), distance: \(distance)")
                    applyDamage(proj.damage, to: target, from: proj.source)
                    if let chunk = chunkManager.getChunk(at: position.tilePosition) {
                        chunk.removeEntity(entity)
                    }
                    world.despawnDeferred(entity)
                    return
                }
            } else {
                // No target - despawn after a short time if no nearby targets
                // This handles projectiles that lost their target
                if proj.lifetime < 1.0 {
                    // Silently despawn projectiles without targets (reduces log spam)
                    if let chunk = chunkManager.getChunk(at: position.tilePosition) {
                        chunk.removeEntity(entity)
                    }
                    world.despawnDeferred(entity)
                    return
                }
            }
            
            // Check for collision with any valid target
            let nearbyEntities = world.getEntitiesNear(position: position.worldPosition, radius: 0.5)
            if !nearbyEntities.isEmpty && proj.target == nil {
                print("Projectile \(entity) found \(nearbyEntities.count) nearby entities (no specific target)")
            }
            for nearbyEntity in nearbyEntities {
                guard nearbyEntity != proj.source else { continue }

                // Determine if this entity is a valid target for this projectile
                let isValidTarget = isValidProjectileTarget(nearbyEntity, for: proj)
                if isValidTarget {
                    print("CombatSystem: Projectile \(entity) hit entity \(nearbyEntity) for \(proj.damage) damage")
                    applyDamage(proj.damage, to: nearbyEntity, from: proj.source)

                    // Apply splash damage
                    if proj.splashRadius > 0 {
                        applySplashDamage(proj.damage * 0.5, at: position.worldPosition, radius: proj.splashRadius, source: proj.source)
                    }

                    world.despawnDeferred(entity)
                    return
                }
            }
        }
    }
    
    private func applyDamage(_ damage: Float, to entity: Entity, from source: Entity?) {
        guard var health = world.get(HealthComponent.self, for: entity) else { return }
        
        // Check if source and target are on same team (friendly fire check)
        if let source = source,
           let sourceOwnership = world.get(OwnershipComponent.self, for: source),
           let targetOwnership = world.get(OwnershipComponent.self, for: entity) {
            
            // Same team - check friendly fire rules
            if let sourceTeamId = sourceOwnership.teamId,
               let targetTeamId = targetOwnership.teamId,
               sourceTeamId == targetTeamId {
                // Same team - allow friendly fire for now (can be disabled later via game rules)
                // TODO: Check game rules for friendly fire setting
            }
        }
        
        // Apply armor if present
        var finalDamage = damage
        if let armor = world.get(ArmorComponent.self, for: entity) {
            finalDamage = armor.calculateDamage(damage, type: .physical)
        }
        
        health.takeDamage(finalDamage)
        
        if health.isDead {
            // Notify spawner if this was a spawned enemy
            if let enemyComp = world.get(EnemyComponent.self, for: entity),
               let spawnerEntity = enemyComp.spawnerEntity,
               var spawner = world.get(SpawnerComponent.self, for: spawnerEntity) {
                spawner.enemyDied()
                world.add(spawner, to: spawnerEntity)
            }
            
            // Spawn death particles
            if let position = world.get(PositionComponent.self, for: entity),
               let renderer = getRenderer() {
                spawnDeathParticles(at: position.worldPosition, renderer: renderer)
            }
            
            world.despawnDeferred(entity)
        } else {
            world.add(health, to: entity)
            
            // Spawn hit particles
            if let position = world.get(PositionComponent.self, for: entity),
               let renderer = getRenderer() {
                spawnHitParticles(at: position.worldPosition, renderer: renderer)
            }
        }
    }
    
    private func applySplashDamage(_ damage: Float, at position: Vector2, radius: Float, source: Entity?) {
        let nearbyEntities = world.getEntitiesNear(position: position, radius: radius)
        
        for entity in nearbyEntities {
            guard entity != source else { continue }
            guard world.has(EnemyComponent.self, for: entity) else { continue }
            guard let entityPos = world.get(PositionComponent.self, for: entity) else { continue }
            
            let distance = position.distance(to: entityPos.worldPosition)
            let falloff = 1 - (distance / radius)
            let splashDamage = damage * falloff
            
            applyDamage(splashDamage, to: entity, from: source)
        }
    }

    private func isValidProjectileTarget(_ entity: Entity, for projectile: ProjectileComponent) -> Bool {
        // If projectile has a specific target, only that target is valid
        if let target = projectile.target {
            return entity == target
        }

        // Otherwise, check based on projectile source
        if let source = projectile.source {
            // If source is player (no EnemyComponent), projectile hits enemies
            if !world.has(EnemyComponent.self, for: source) {
                return world.has(EnemyComponent.self, for: entity)
            }
            // If source is enemy (has EnemyComponent), projectile hits player and buildings
            else {
                return !world.has(EnemyComponent.self, for: entity) && world.has(HealthComponent.self, for: entity)
            }
        }

        // If no source, assume it can hit anything with health (fallback)
        return world.has(HealthComponent.self, for: entity)
    }

    // MARK: - Visual Effects
    
    private func spawnHitParticles(at position: Vector2, renderer: MetalRenderer) {
        // Spawn a few small particles for hit effect
        for _ in 0..<3 {
            let angle = Float.random(in: 0...(Float.pi * 2))
            let speed = Float.random(in: 2...4)
            let velocity = Vector2(cosf(angle), sinf(angle)) * speed
            let offset = Vector2(Float.random(in: -0.2...0.2), Float.random(in: -0.2...0.2))
            
            let particle = ParticleInstance(
                position: position + offset,
                velocity: velocity,
                size: 0.1,
                rotation: 0,
                color: Color(r: 1.0, g: 0.8, b: 0.0, a: 1.0),
                life: 0.2,
                maxLife: 0.2
            )
            renderer.queueParticle(particle)
        }
    }
    
    private func spawnDeathParticles(at position: Vector2, renderer: MetalRenderer) {
        // Spawn more particles for death effect
        for _ in 0..<8 {
            let angle = Float.random(in: 0...(Float.pi * 2))
            let speed = Float.random(in: 3...6)
            let velocity = Vector2(cosf(angle), sinf(angle)) * speed
            let offset = Vector2(Float.random(in: -0.3...0.3), Float.random(in: -0.3...0.3))
            
            let particle = ParticleInstance(
                position: position + offset,
                velocity: velocity,
                size: 0.15,
                rotation: 0,
                color: Color(r: 0.8, g: 0.2, b: 0.2, a: 1.0),
                life: 0.5,
                maxLife: 0.5
            )
            renderer.queueParticle(particle)
        }
    }
}
