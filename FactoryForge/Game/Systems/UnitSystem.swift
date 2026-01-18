import Foundation

/// System that manages controllable combat units, their AI, commands, and production
final class UnitSystem: System {
    let priority = SystemPriority.combat.rawValue - 1  // Run before combat system

    private let world: World
    private let chunkManager: ChunkManager
    private let itemRegistry: ItemRegistry

    init(world: World, chunkManager: ChunkManager, itemRegistry: ItemRegistry) {
        self.world = world
        self.chunkManager = chunkManager
        self.itemRegistry = itemRegistry
    }

    func update(deltaTime: Float) {
        // Update unit production
        updateUnitProduction(deltaTime: deltaTime)

        // Update unit AI and commands
        updateUnitAI(deltaTime: deltaTime)

        // Update unit animations and movement
        updateUnitMovement(deltaTime: deltaTime)
    }

    // MARK: - Unit Production

    private func updateUnitProduction(deltaTime: Float) {
        world.forEach(UnitProductionComponent.self) { entity, production in
            production.update(deltaTime: deltaTime)

            // Check if production is complete
            if let currentUnitType = production.getCurrentProduction(),
               production.getProductionProgress() >= 1.0 {

                // Spawn the unit near the production building
                if let position = world.get(PositionComponent.self, for: entity) {
                    spawnUnit(currentUnitType, near: position.worldPosition)
                    production.currentProduction = nil
                }
            }

            // Start next production if available
            if production.currentProduction == nil && !production.productionQueue.isEmpty {
                production.currentProduction = production.productionQueue.removeFirst()
                production.productionProgress = 0
            }
        }
    }

    private func spawnUnit(_ unitType: UnitType, near position: Vector2) {
        let entity = world.spawn()

        // Find a valid spawn position near the building
        let spawnOffset = Vector2(Float.random(in: -2...2), Float.random(in: -2...2))
        let spawnPosition = position + spawnOffset
        let tilePosition = IntVector2(from: spawnPosition)

        world.add(PositionComponent(tilePosition: tilePosition), to: entity)
        world.add(UnitComponent(type: unitType), to: entity)

        // Add sprite component
        world.add(SpriteComponent(
            textureId: unitType.textureId,
            size: Vector2(1, 1),
            layer: .entity,
            centered: true
        ), to: entity)

        // Add health component
        let stats = unitType.baseStats
        world.add(HealthComponent(maxHealth: stats.health), to: entity)

        // Add velocity for movement
        world.add(VelocityComponent(), to: entity)

        // Add collision component
        world.add(CollisionComponent(radius: 0.4, layer: .player, mask: [.enemy, .building]), to: entity)

        // Register with chunk
        if let chunk = chunkManager.getChunk(at: tilePosition) {
            chunk.addEntity(entity, at: tilePosition)
        }

        print("UnitSystem: Spawned \(unitType.displayName) at \(tilePosition)")
    }

    // MARK: - Unit AI and Commands

    private func updateUnitAI(deltaTime: Float) {
        world.forEach(UnitComponent.self) { entity, unit in
            unit.update(deltaTime: deltaTime)

            // Execute current command
            if let command = unit.currentCommand {
                executeCommand(command, for: entity, unit: unit)
            } else if !unit.commandQueue.isEmpty {
                // Get next command
                unit.currentCommand = unit.commandQueue.removeFirst()
            } else {
                // No commands - perform default AI behavior
                performDefaultAI(for: entity, unit: unit)
            }

            // Update target acquisition
            updateTargetAcquisition(for: entity, unit: unit)
        }
    }

    private func executeCommand(_ command: UnitCommand, for entity: Entity, unit: UnitComponent) {
        switch command {
        case .move(let targetPosition):
            executeMoveCommand(to: targetPosition, for: entity, unit: unit)

        case .attack(let targetEntity):
            executeAttackCommand(target: targetEntity, for: entity, unit: unit)

        case .attackGround(let position):
            executeAttackGroundCommand(at: position, for: entity, unit: unit)

        case .patrol(let from, let to):
            executePatrolCommand(from: from, to: to, for: entity, unit: unit)

        case .holdPosition:
            executeHoldPositionCommand(for: entity, unit: unit)

        case .useAbility(let ability, let target):
            executeAbilityCommand(ability: ability, target: target, for: entity, unit: unit)
        }
    }

    private func executeMoveCommand(to targetPosition: IntVector2, for entity: Entity, unit: UnitComponent) {
        guard let position = world.get(PositionComponent.self, for: entity),
              let velocityPtr = world.getMutable(VelocityComponent.self, for: entity) else { return }

        let currentPos = position.worldPosition
        let targetPos = targetPosition.toVector2 + Vector2(0.5, 0.5)  // Center of tile
        let direction = (targetPos - currentPos).normalized
        let distance = currentPos.distance(to: targetPos)

        if distance < 0.5 {
            // Reached destination
            unit.currentCommand = nil
            velocityPtr.pointee.velocity = .zero
        } else {
            // Move towards target with terrain speed modifiers
            let modifiedStats = unit.getModifiedStats()
            let terrain = getUnitTerrain(entity)
            let terrainModifier = getTerrainMovementModifier(for: unit, on: terrain ?? .grass)
            velocityPtr.pointee.velocity = direction * modifiedStats.speed * terrainModifier
        }
    }

    private func executeAttackCommand(target targetEntity: Entity, for entity: Entity, unit: UnitComponent) {
        guard world.isAlive(targetEntity) else {
            unit.currentCommand = nil
            return
        }

        guard let targetPos = world.get(PositionComponent.self, for: targetEntity)?.worldPosition,
              let position = world.get(PositionComponent.self, for: entity) else { return }

        let distance = position.worldPosition.distance(to: targetPos)
        let modifiedStats = unit.getModifiedStats()

        if distance <= modifiedStats.range {
            // In range - attack
            performAttack(on: targetEntity, by: entity, unit: unit)
        } else {
            // Move closer
            let targetTile = IntVector2(from: targetPos)
            executeMoveCommand(to: targetTile, for: entity, unit: unit)
        }
    }

    private func executeAttackGroundCommand(at position: IntVector2, for entity: Entity, unit: UnitComponent) {
        guard let currentPos = world.get(PositionComponent.self, for: entity)?.worldPosition else { return }

        let distance = currentPos.distance(to: position.toVector2 + Vector2(0.5, 0.5))
        let modifiedStats = unit.getModifiedStats()

        if distance <= modifiedStats.range {
            // In range - attack ground
            performAttackGround(at: position, by: entity, unit: unit)
            unit.currentCommand = nil
        } else {
            // Move closer
            executeMoveCommand(to: position, for: entity, unit: unit)
        }
    }

    private func executePatrolCommand(from startPosition: IntVector2, to endPosition: IntVector2, for entity: Entity, unit: UnitComponent) {
        guard let position = world.get(PositionComponent.self, for: entity) else { return }

        let currentTile = position.tilePosition
        let currentTileVec = currentTile.toVector2
        let startVec = startPosition.toVector2
        let endVec = endPosition.toVector2
        let distanceToStart = currentTileVec.distance(to: startVec)
        let distanceToEnd = currentTileVec.distance(to: endVec)

        // Choose target based on current position
        let targetPosition = distanceToStart < distanceToEnd ? endPosition : startPosition
        executeMoveCommand(to: targetPosition, for: entity, unit: unit)

        // If reached target, switch patrol direction
        if unit.currentCommand == nil {
            let newCommand: UnitCommand = distanceToStart < distanceToEnd ?
                .patrol(from: endPosition, to: startPosition) :
                .patrol(from: startPosition, to: endPosition)
            unit.commandQueue.append(newCommand)
        }
    }

    private func executeHoldPositionCommand(for entity: Entity, unit: UnitComponent) {
        // Clear velocity to stop moving
        if let velocityPtr = world.getMutable(VelocityComponent.self, for: entity) {
            velocityPtr.pointee.velocity = .zero
        }

        // Attack nearby enemies if aggressive enough
        if unit.aggressionLevel > 0.3 {
            updateTargetAcquisition(for: entity, unit: unit)
            if unit.targetEntity != nil {
                unit.currentCommand = .attack(entity: unit.targetEntity!)
            }
        }
    }

    private func executeAbilityCommand(ability: UnitAbility, target: UnitCommand.CommandTarget?, for entity: Entity, unit: UnitComponent) {
        guard unit.canUseAbility(ability) else {
            unit.currentCommand = nil
            return
        }

        // Check range if target is specified
        if let target = target {
            let targetPosition: Vector2
            switch target {
            case .entity(let targetEntity):
                guard let pos = world.get(PositionComponent.self, for: targetEntity)?.worldPosition else {
                    unit.currentCommand = nil
                    return
                }
                targetPosition = pos
            case .position(let pos):
                targetPosition = pos.toVector2 + Vector2(0.5, 0.5)
            }

            guard let currentPos = world.get(PositionComponent.self, for: entity)?.worldPosition else {
                unit.currentCommand = nil
                return
            }

            let distance = currentPos.distance(to: targetPosition)
            if distance > ability.range {
                // Move closer first
                let targetTile = IntVector2(from: targetPosition)
                executeMoveCommand(to: targetTile, for: entity, unit: unit)
                return
            }
        }

        // Execute ability
        performAbility(ability, target: target, by: entity, unit: unit)
        unit.currentCommand = nil
    }

    private func performDefaultAI(for entity: Entity, unit: UnitComponent) {
        // Default behavior based on unit type and aggression
        if unit.aggressionLevel > 0.5 {
            // Aggressive units seek out enemies
            if let target = findNearbyEnemy(for: entity, unit: unit) {
                unit.commandQueue.append(.attack(entity: target))
            }
        } else if unit.aggressionLevel > 0.2 {
            // Moderately aggressive units defend their position
            if let threat = findNearbyThreat(for: entity, unit: unit) {
                unit.commandQueue.append(.attack(entity: threat))
            }
        }
        // Passive units (aggression < 0.2) do nothing
    }

    private func updateTargetAcquisition(for entity: Entity, unit: UnitComponent) {
        guard unit.targetEntity == nil || !isValidTarget(unit.targetEntity!, for: unit) else { return }

        unit.targetEntity = findNearbyEnemy(for: entity, unit: unit)
    }

    private func findNearbyEnemy(for entity: Entity, unit: UnitComponent) -> Entity? {
        guard let position = world.get(PositionComponent.self, for: entity) else { return nil }

        let searchRadius: Float = 8.0  // Units can detect enemies from far away
        let candidates = world.getEntitiesNear(position: position.worldPosition, radius: searchRadius)

        var closestEnemy: Entity?
        var closestDistance = Float.infinity

        for candidate in candidates {
            guard world.has(EnemyComponent.self, for: candidate) else { continue }
            guard let health = world.get(HealthComponent.self, for: candidate), !health.isDead else { continue }
            guard let enemyPos = world.get(PositionComponent.self, for: candidate) else { continue }

            let distance = position.worldPosition.distance(to: enemyPos.worldPosition)
            if distance < closestDistance {
                closestDistance = distance
                closestEnemy = candidate
            }
        }

        return closestEnemy
    }

    private func findNearbyThreat(for entity: Entity, unit: UnitComponent) -> Entity? {
        return findNearbyEnemy(for: entity, unit: unit)
    }

    private func isValidTarget(_ target: Entity, for unit: UnitComponent) -> Bool {
        guard world.isAlive(target) else { return false }
        guard let health = world.get(HealthComponent.self, for: target), !health.isDead else { return false }
        return true
    }

    // MARK: - Combat Actions

    private func performAttack(on target: Entity, by attacker: Entity, unit: UnitComponent) {
        guard let attackerPos = world.get(PositionComponent.self, for: attacker)?.worldPosition,
              let targetPos = world.get(PositionComponent.self, for: target)?.worldPosition else { return }

        let distance = attackerPos.distance(to: targetPos)
        let modifiedStats = unit.getModifiedStats()

        guard distance <= modifiedStats.range else { return }

        // Check attack cooldown
        let currentTime = Date().timeIntervalSince1970
        if currentTime - unit.lastAttackTime < 1.0 { return }  // 1 second cooldown
        unit.lastAttackTime = currentTime

        // Calculate damage
        var damage = modifiedStats.attack

        // Apply type effectiveness with terrain modifiers (Pokemon+RTS style)
        if let targetUnit = world.get(UnitComponent.self, for: target) {
            // Get terrain for both units
            let attackerTerrain = getUnitTerrain(attacker)
            let defenderTerrain = getUnitTerrain(target)
            damage *= calculateTypeEffectiveness(unit.type.damageType, vs: targetUnit.type.damageType, attackerTerrain: attackerTerrain, defenderTerrain: defenderTerrain)
        } else if world.has(EnemyComponent.self, for: target) {
            // Damage vs enemies (biters) - most units are effective
            damage *= 1.0
        }

        // Apply strategic positioning bonus
        if let attackerPos = world.get(PositionComponent.self, for: attacker)?.tilePosition {
            damage *= getTerrainPositioningBonus(for: unit, at: attackerPos, chunkManager: chunkManager)
        }

        // Apply damage
        applyDamage(damage, to: target, from: attacker, damageType: unit.type.damageType)

        // Grant experience
        unit.gainExperience(10)

        // Visual effect
        spawnAttackEffect(from: attackerPos, to: targetPos, damageType: unit.type.damageType)

        print("UnitSystem: \(unit.type.displayName) attacked for \(damage) damage")
    }

    private func performAttackGround(at position: IntVector2, by attacker: Entity, unit: UnitComponent) {
        // Find enemies in area
        let centerPos = position.toVector2 + Vector2(0.5, 0.5)
        let areaRadius: Float = 2.0
        let nearbyEntities = world.getEntitiesNear(position: centerPos, radius: areaRadius)

        let modifiedStats = unit.getModifiedStats()
        var damageDealt = false

        for entity in nearbyEntities {
            guard world.has(EnemyComponent.self, for: entity) else { continue }
            guard let entityPos = world.get(PositionComponent.self, for: entity)?.worldPosition else { continue }

            let distance = centerPos.distance(to: entityPos)
            if distance <= areaRadius {
                let damage = modifiedStats.attack * 0.7  // Reduced damage for area attack
                applyDamage(damage, to: entity, from: attacker, damageType: unit.type.damageType)
                damageDealt = true
            }
        }

        if damageDealt {
            unit.gainExperience(15)
            spawnAreaAttackEffect(at: centerPos, damageType: unit.type.damageType)
        }
    }

    private func performAbility(_ ability: UnitAbility, target: UnitCommand.CommandTarget?, by entity: Entity, unit: UnitComponent) {
        unit.useAbility(ability)

        switch ability {
        case .charge:
            performChargeAbility(by: entity, unit: unit)
        case .shoot:
            performShootAbility(target: target, by: entity, unit: unit)
        case .grenade:
            performGrenadeAbility(target: target, by: entity, unit: unit)
        case .shieldWall:
            performShieldWallAbility(by: entity, unit: unit)
        case .taunt:
            performTauntAbility(by: entity, unit: unit)
        case .berserk:
            performBerserkAbility(by: entity, unit: unit)
        case .shieldBash:
            performShieldBashAbility(target: target, by: entity, unit: unit)
        case .snipe:
            performSnipeAbility(target: target, by: entity, unit: unit)
        case .camouflage:
            performCamouflageAbility(by: entity, unit: unit)
        case .fireball:
            performFireballAbility(target: target, by: entity, unit: unit)
        case .teleport:
            performTeleportAbility(target: target, by: entity, unit: unit)
        case .manaShield:
            performManaShieldAbility(by: entity, unit: unit)
        case .heal:
            performHealAbility(target: target, by: entity, unit: unit)
        case .divineShield:
            performDivineShieldAbility(by: entity, unit: unit)
        case .smite:
            performSmiteAbility(target: target, by: entity, unit: unit)
        case .backstab:
            performBackstabAbility(target: target, by: entity, unit: unit)
        case .poison:
            performPoisonAbility(target: target, by: entity, unit: unit)
        case .vanish:
            performVanishAbility(by: entity, unit: unit)
        case .fireBreath:
            performFireBreathAbility(by: entity, unit: unit)
        case .immolate:
            performImmolateAbility(by: entity, unit: unit)
        case .waterBlast:
            performWaterBlastAbility(by: entity, unit: unit)
        case .earthquake:
            performEarthquakeAbility(by: entity, unit: unit)
        case .stoneSkin:
            performStoneSkinAbility(by: entity, unit: unit)
        case .gust:
            performGustAbility(by: entity, unit: unit)
        case .haste:
            performHasteAbility(by: entity, unit: unit)
        case .shadowStrike:
            performShadowStrikeAbility(target: target, by: entity, unit: unit)
        case .fear:
            performFearAbility(by: entity, unit: unit)
        case .holyLight:
            performHolyLightAbility(by: entity, unit: unit)
        case .purify:
            performPurifyAbility(target: target, by: entity, unit: unit)
        case .barrier:
            performBarrierAbility(by: entity, unit: unit)
        case .sneak, .scoutVision, .repair, .explosive:
            // These abilities need specific implementations
            break
        }

        print("UnitSystem: \(unit.type.displayName) used ability \(ability.rawValue)")
    }

    // MARK: - Ability Implementations

    private func performChargeAbility(by entity: Entity, unit: UnitComponent) {
        unit.applyStatusEffect(.speedBoost(duration: 5.0))
        unit.commandQueue.insert(.move(to: findChargeTarget(for: entity)), at: 0)
    }

    private func performShootAbility(target: UnitCommand.CommandTarget?, by entity: Entity, unit: UnitComponent) {
        if let target = target {
            performAttackOnTarget(target, by: entity, unit: unit, damageMultiplier: 1.2)
        }
    }

    private func performGrenadeAbility(target: UnitCommand.CommandTarget?, by entity: Entity, unit: UnitComponent) {
        if let target = target {
            let position: IntVector2
            switch target {
            case .entity(let targetEntity):
                guard let pos = world.get(PositionComponent.self, for: targetEntity)?.tilePosition else { return }
                position = pos
            case .position(let pos):
                position = pos
            }
            performAttackGround(at: position, by: entity, unit: unit)
        }
    }

    private func performShieldWallAbility(by entity: Entity, unit: UnitComponent) {
        unit.applyStatusEffect(.defenseBoost(duration: 10.0))
        // Also protect nearby allies
        applyAreaBuff(.defenseBoost(duration: 10.0), center: entity, radius: 3.0, sourceUnit: unit)
    }

    private func performTauntAbility(by entity: Entity, unit: UnitComponent) {
        // Force nearby enemies to attack this unit
        let nearbyEnemies = findNearbyEnemies(for: entity, radius: 5.0)
        for enemy in nearbyEnemies {
            if let enemyPtr = world.getMutable(EnemyComponent.self, for: enemy) {
                enemyPtr.pointee.targetEntity = entity
            }
        }
    }

    private func performBerserkAbility(by entity: Entity, unit: UnitComponent) {
        unit.applyStatusEffect(.strengthBoost(duration: 8.0))
        unit.applyStatusEffect(.speedBoost(duration: 8.0))
        // Take damage from rage
        if let healthPtr = world.getMutable(HealthComponent.self, for: entity) {
            _ = healthPtr.pointee.takeDamage(unit.stats.health * 0.1)
        }
    }

    private func performShieldBashAbility(target: UnitCommand.CommandTarget?, by entity: Entity, unit: UnitComponent) {
        if let target = target {
            performAttackOnTarget(target, by: entity, unit: unit, damageMultiplier: 1.5)
            // Stun target
            applyStatusToTarget(target, .stun(duration: 2.0))
        }
    }

    private func performSnipeAbility(target: UnitCommand.CommandTarget?, by entity: Entity, unit: UnitComponent) {
        if let target = target {
            performAttackOnTarget(target, by: entity, unit: unit, damageMultiplier: 2.0, rangeMultiplier: 2.0)
        }
    }

    private func performCamouflageAbility(by entity: Entity, unit: UnitComponent) {
        // Become temporarily harder to detect (slight speed boost)
        unit.applyStatusEffect(.speedBoost(duration: 15.0))
    }

    private func performFireballAbility(target: UnitCommand.CommandTarget?, by entity: Entity, unit: UnitComponent) {
        if let target = target {
            performAttackOnTarget(target, by: entity, unit: unit, damageMultiplier: 2.5, isMagical: true)
            // Apply burn to target
            applyStatusToTarget(target, .burn(duration: 5.0))
        }
    }

    private func performTeleportAbility(target: UnitCommand.CommandTarget?, by entity: Entity, unit: UnitComponent) {
        if let target = target, case .position(let position) = target {
            // Instantly move to position
            var pos = world.get(PositionComponent.self, for: entity) ?? PositionComponent(tilePosition: .zero)
            pos.tilePosition = position
            world.add(pos, to: entity)
        }
    }

    private func performManaShieldAbility(by entity: Entity, unit: UnitComponent) {
        unit.applyStatusEffect(.defenseBoost(duration: 10.0))
        // Convert some mana to shield
        let shieldAmount = min(unit.currentMana * 0.5, 50)
        unit.currentMana -= shieldAmount
        // Implementation would need a shield component
    }

    private func performHealAbility(target: UnitCommand.CommandTarget?, by entity: Entity, unit: UnitComponent) {
        let targetEntity = getTargetEntity(target) ?? entity
        if let healthPtr = world.getMutable(HealthComponent.self, for: targetEntity) {
            _ = healthPtr.pointee.heal(unit.stats.attack)  // Heal for attack power
            spawnHealEffect(at: world.get(PositionComponent.self, for: targetEntity)?.worldPosition ?? .zero)
        }
    }

    private func performDivineShieldAbility(by entity: Entity, unit: UnitComponent) {
        unit.applyStatusEffect(.defenseBoost(duration: 15.0))
        // Immune to next attack
        unit.applyStatusEffect(.defenseBoost(duration: 15.0))
    }

    private func performSmiteAbility(target: UnitCommand.CommandTarget?, by entity: Entity, unit: UnitComponent) {
        if let target = target {
            performAttackOnTarget(target, by: entity, unit: unit, damageMultiplier: 3.0, isMagical: true)
        }
    }

    private func performBackstabAbility(target: UnitCommand.CommandTarget?, by entity: Entity, unit: UnitComponent) {
        if let target = target {
            performAttackOnTarget(target, by: entity, unit: unit, damageMultiplier: 2.5)
        }
    }

    private func performPoisonAbility(target: UnitCommand.CommandTarget?, by entity: Entity, unit: UnitComponent) {
        if let target = target {
            performAttackOnTarget(target, by: entity, unit: unit, damageMultiplier: 0.8)
            applyStatusToTarget(target, .poison(duration: 8.0))
        }
    }

    private func performVanishAbility(by entity: Entity, unit: UnitComponent) {
        // Become temporarily faster and harder to hit
        unit.applyStatusEffect(.speedBoost(duration: 10.0))
        unit.applyStatusEffect(.speedBoost(duration: 10.0))
    }

    private func performFireBreathAbility(by entity: Entity, unit: UnitComponent) {
        guard let position = world.get(PositionComponent.self, for: entity)?.worldPosition else { return }
        let direction = getUnitFacingDirection(entity)

        // Damage in a cone in front of the unit
        let coneAngle: Float = .pi / 3  // 60 degrees
        let range: Float = 4.0
        let nearbyEntities = world.getEntitiesNear(position: position, radius: range)

        for targetEntity in nearbyEntities {
            guard let targetPos = world.get(PositionComponent.self, for: targetEntity)?.worldPosition else { continue }
            let toTarget = (targetPos - position).normalized
            let angle = acos(direction.dot(toTarget))

            if angle <= coneAngle / 2 {
                applyDamage(unit.stats.attack * 1.5, to: targetEntity, from: entity, damageType: .fire)
                applyStatusToTarget(.entity(targetEntity), .burn(duration: 3.0))
            }
        }
    }

    private func performImmolateAbility(by entity: Entity, unit: UnitComponent) {
        unit.applyStatusEffect(.burn(duration: 6.0))  // Damage self
        // Damage nearby enemies
        applyAreaDamage(unit.stats.attack, center: entity, radius: 3.0, damageType: .fire, source: entity)
        applyAreaStatus(.burn(duration: 4.0), center: entity, radius: 3.0)
    }

    private func performWaterBlastAbility(by entity: Entity, unit: UnitComponent) {
        performAreaAttack(entity: entity, unit: unit, radius: 3.0, damageMultiplier: 1.3, statusEffect: .freeze(duration: 2.0))
    }

    private func performEarthquakeAbility(by entity: Entity, unit: UnitComponent) {
        performAreaAttack(entity: entity, unit: unit, radius: 4.0, damageMultiplier: 1.8, statusEffect: .slow(duration: 5.0))
        // Also damage buildings
        damageNearbyBuildings(center: entity, radius: 4.0, damage: unit.stats.attack * 0.5)
    }

    private func performStoneSkinAbility(by entity: Entity, unit: UnitComponent) {
        unit.applyStatusEffect(.defenseBoost(duration: 12.0))
    }

    private func performGustAbility(by entity: Entity, unit: UnitComponent) {
        // Push enemies away
        let nearbyEnemies = findNearbyEnemies(for: entity, radius: 3.0)
        guard let position = world.get(PositionComponent.self, for: entity)?.worldPosition else { return }

        for enemy in nearbyEnemies {
            if let enemyPosPtr = world.getMutable(PositionComponent.self, for: enemy) {
                let enemyWorldPos = enemyPosPtr.pointee.worldPosition
                let direction = (enemyWorldPos - position).normalized
                enemyPosPtr.pointee.offset += direction * 2.0  // Push 2 units away
            }
        }
    }

    private func performHasteAbility(by entity: Entity, unit: UnitComponent) {
        unit.applyStatusEffect(.speedBoost(duration: 8.0))
    }

    private func performShadowStrikeAbility(target: UnitCommand.CommandTarget?, by entity: Entity, unit: UnitComponent) {
        if let target = target {
            performAttackOnTarget(target, by: entity, unit: unit, damageMultiplier: 2.2, ignoreDefense: true)
        }
    }

    private func performFearAbility(by entity: Entity, unit: UnitComponent) {
        let nearbyEnemies = findNearbyEnemies(for: entity, radius: 4.0)
        for enemy in nearbyEnemies {
            // Make enemies flee
            if let enemyPtr = world.getMutable(EnemyComponent.self, for: enemy) {
                enemyPtr.pointee.state = .fleeing
            }
        }
    }

    private func performHolyLightAbility(by entity: Entity, unit: UnitComponent) {
        // Heal all nearby allies
        applyAreaHeal(unit.stats.attack * 0.8, center: entity, radius: 5.0)
    }

    private func performPurifyAbility(target: UnitCommand.CommandTarget?, by entity: Entity, unit: UnitComponent) {
        let targetEntity = getTargetEntity(target) ?? entity
        // Remove negative status effects
        if let targetUnit = world.get(UnitComponent.self, for: targetEntity) {
            targetUnit.statusEffects.removeAll { effect in
                switch effect.type {
                case .poison, .slow, .burn, .freeze: return true
                default: return false
                }
            }
            world.add(targetUnit, to: targetEntity)
        }
    }

    private func performBarrierAbility(by entity: Entity, unit: UnitComponent) {
        // Create a protective barrier around the unit
        unit.applyStatusEffect(.defenseBoost(duration: 10.0))
        // Also protect nearby allies
        applyAreaBuff(.defenseBoost(duration: 10.0), center: entity, radius: 4.0, sourceUnit: unit)
    }

    // MARK: - Helper Methods

    private func findChargeTarget(for entity: Entity) -> IntVector2 {
        // Find the farthest enemy to charge at
        guard let position = world.get(PositionComponent.self, for: entity)?.worldPosition else {
            return IntVector2(x: 0, y: 0)
        }

        let nearbyEnemies = findNearbyEnemies(for: entity, radius: 10.0)
        var farthestPosition = position

        for enemy in nearbyEnemies {
            if let enemyPos = world.get(PositionComponent.self, for: enemy)?.worldPosition {
                if position.distance(to: enemyPos) > position.distance(to: farthestPosition) {
                    farthestPosition = enemyPos
                }
            }
        }

        return IntVector2(from: farthestPosition)
    }

    private func findNearbyEnemies(for entity: Entity, radius: Float) -> [Entity] {
        guard let position = world.get(PositionComponent.self, for: entity)?.worldPosition else { return [] }
        let candidates = world.getEntitiesNear(position: position, radius: radius)

        return candidates.filter { world.has(EnemyComponent.self, for: $0) }
    }

    private func getUnitFacingDirection(_ entity: Entity) -> Vector2 {
        // For now, assume units face north. Could be improved with direction tracking
        return Vector2(0, 1)
    }

    private func getTargetEntity(_ target: UnitCommand.CommandTarget?) -> Entity? {
        guard let target = target else { return nil }
        switch target {
        case .entity(let entity): return entity
        case .position: return nil
        }
    }

    private func performAttackOnTarget(_ target: UnitCommand.CommandTarget, by entity: Entity, unit: UnitComponent, damageMultiplier: Float = 1.0, rangeMultiplier: Float = 1.0, isMagical: Bool = false, ignoreDefense: Bool = false) {
        guard let targetEntity = getTargetEntity(target) else { return }
        performAttack(on: targetEntity, by: entity, unit: unit)
    }

    private func applyStatusToTarget(_ target: UnitCommand.CommandTarget, _ effect: StatusEffect) {
        guard let targetEntity = getTargetEntity(target) else { return }
        if let targetUnit = world.get(UnitComponent.self, for: targetEntity) {
            targetUnit.applyStatusEffect(effect)
            world.add(targetUnit, to: targetEntity)
        }
    }

    private func performAreaAttack(entity: Entity, unit: UnitComponent, radius: Float, damageMultiplier: Float = 1.0, statusEffect: StatusEffect? = nil) {
        applyAreaDamage(unit.stats.attack * damageMultiplier, center: entity, radius: radius, damageType: unit.type.damageType, source: entity)
        if let effect = statusEffect {
            applyAreaStatus(effect, center: entity, radius: radius)
        }
    }

    private func applyAreaDamage(_ damage: Float, center: Entity, radius: Float, damageType: DamageType, source: Entity) {
        let nearbyEntities = findNearbyEnemies(for: center, radius: radius)
        guard let centerPos = world.get(PositionComponent.self, for: center)?.worldPosition else { return }

        for entity in nearbyEntities {
            guard let entityPos = world.get(PositionComponent.self, for: entity)?.worldPosition else { continue }
            let distance = centerPos.distance(to: entityPos)
            if distance <= radius {
                let falloff = 1 - (distance / radius) * 0.5  // Less falloff than grenades
                applyDamage(damage * falloff, to: entity, from: source, damageType: damageType)
            }
        }
    }

    private func applyAreaStatus(_ effect: StatusEffect, center: Entity, radius: Float) {
        let nearbyEntities = findNearbyEnemies(for: center, radius: radius)
        guard let centerPos = world.get(PositionComponent.self, for: center)?.worldPosition else { return }

        for entity in nearbyEntities {
            guard let entityPos = world.get(PositionComponent.self, for: entity)?.worldPosition else { continue }
            let distance = centerPos.distance(to: entityPos)
            if distance <= radius {
                if let targetUnit = world.get(UnitComponent.self, for: entity) {
                    targetUnit.applyStatusEffect(effect)
                    world.add(targetUnit, to: entity)
                }
            }
        }
    }

    private func applyAreaBuff(_ effect: StatusEffect, center: Entity, radius: Float, sourceUnit: UnitComponent) {
        let nearbyEntities = world.getEntitiesNear(position: world.get(PositionComponent.self, for: center)?.worldPosition ?? .zero, radius: radius)

        for entity in nearbyEntities {
            guard let targetUnit = world.get(UnitComponent.self, for: entity),
                  targetUnit.type.unitClass == sourceUnit.type.unitClass else { continue }  // Only buff same unit class

            let updatedUnit = targetUnit
            updatedUnit.applyStatusEffect(effect)
            world.add(updatedUnit, to: entity)
        }
    }

    private func applyAreaHeal(_ healAmount: Float, center: Entity, radius: Float) {
        let nearbyEntities = world.getEntitiesNear(position: world.get(PositionComponent.self, for: center)?.worldPosition ?? .zero, radius: radius)

        for entity in nearbyEntities {
            if world.has(UnitComponent.self, for: entity) || !world.has(EnemyComponent.self, for: entity) {
                if let healthPtr = world.getMutable(HealthComponent.self, for: entity) {
                    _ = healthPtr.pointee.heal(healAmount)
                }
            }
        }
    }

    private func damageNearbyBuildings(center: Entity, radius: Float, damage: Float) {
        guard let centerPos = world.get(PositionComponent.self, for: center)?.worldPosition else { return }
        let nearbyEntities = world.getEntitiesNear(position: centerPos, radius: radius)

        for entity in nearbyEntities {
            if isBuilding(entity) {
                applyDamage(damage, to: entity, from: center, damageType: .earth)
            }
        }
    }

    private func isBuilding(_ entity: Entity) -> Bool {
        return world.has(FurnaceComponent.self, for: entity) ||
               world.has(AssemblerComponent.self, for: entity) ||
               world.has(MinerComponent.self, for: entity) ||
               world.has(ChestComponent.self, for: entity) ||
               world.has(LabComponent.self, for: entity)
    }

    private func calculateTypeEffectiveness(_ attackerType: DamageType, vs defenderType: DamageType, attackerTerrain: TileType? = nil, defenderTerrain: TileType? = nil) -> Float {
        var multiplier: Float = 1.0

        // Pokemon-style type effectiveness
        switch (attackerType, defenderType) {
        case (.fire, .water), (.earth, .air):
            multiplier *= 0.5  // Not very effective
        case (.fire, .earth), (.water, .fire), (.earth, .electric), (.air, .earth):
            multiplier *= 2.0  // Super effective
        case (.light, .dark), (.dark, .light):
            multiplier *= 2.0  // Holy vs dark, etc.
        default:
            break  // Normal effectiveness
        }

        // Terrain-based modifiers
        if let attackerTerrain = attackerTerrain {
            multiplier *= getTerrainAttackModifier(attackerType, on: attackerTerrain)
        }

        if let defenderTerrain = defenderTerrain {
            multiplier *= getTerrainDefenseModifier(defenderType, on: defenderTerrain)
        }

        return multiplier
    }

    private func getTerrainAttackModifier(_ damageType: DamageType, on terrain: TileType) -> Float {
        // Terrain can boost or weaken attacks
        switch (damageType, terrain) {
        case (.fire, .sand), (.fire, .dirt):
            return 1.25  // Fire stronger on dry terrain
        case (.fire, .water), (.fire, .grass):
            return 0.8   // Fire weaker on wet/grassy terrain
        case (.water, .water):
            return 1.3   // Water stronger near water
        case (.water, .sand), (.water, .stone):
            return 0.9   // Water weaker on dry/hard terrain
        case (.earth, .stone), (.earth, .dirt):
            return 1.2   // Earth stronger on stone/dirt
        case (.earth, .grass), (.earth, .water):
            return 0.85  // Earth weaker on soft terrain
        case (.air, .grass), (.air, .tree):
            return 1.15  // Air stronger with wind cover
        case (.light, .grass):
            return 1.1   // Light stronger in natural areas
        case (.dark, .stone), (.dark, .tree):
            return 1.2   // Dark stronger in shadowed areas
        default:
            return 1.0
        }
    }

    private func getTerrainDefenseModifier(_ damageType: DamageType, on terrain: TileType) -> Float {
        // Terrain can provide defense bonuses
        switch (damageType, terrain) {
        case (.physical, .stone), (.physical, .tree):
            return 0.9   // Physical attacks weaker against hard cover
        case (.fire, .stone):
            return 1.1   // Fire attacks stronger against stone (melting?)
        case (.water, .grass):
            return 0.95  // Water slightly weaker against plants
        case (.earth, .stone):
            return 0.8   // Earth attacks weaker against stone
        case (.air, .tree):
            return 0.85  // Air attacks weaker against trees
        case (.light, .tree), (.light, .stone):
            return 0.9   // Light slightly weaker in covered areas
        case (.dark, .grass):
            return 1.1   // Dark attacks stronger in open areas
        default:
            return 1.0
        }
    }

    private func getTerrainMovementModifier(for unit: UnitComponent, on terrain: TileType) -> Float {
        // Terrain affects movement speed
        switch (unit.type.damageType, terrain) {
        case (.earth, .stone), (.earth, .dirt):
            return 1.1   // Earth units faster on earth terrain
        case (.air, .grass), (.air, .tree):
            return 1.2   // Air units faster in open/windy areas
        case (.water, .water):
            return 1.15  // Water units faster in water
        case (.fire, .sand):
            return 1.05  // Fire units slightly faster on sand
        case (_, .water):
            return 0.3   // Most units slow in water
        case (_, .tree):
            return 0.8   // Trees provide some cover but slow movement
        case (.physical, .grass):
            return 0.95  // Slightly slower on grass
        default:
            return 1.0
        }
    }

    private func getTerrainPositioningBonus(for unit: UnitComponent, at position: IntVector2, chunkManager: ChunkManager) -> Float {
        // Strategic positioning bonuses
        guard let tile = chunkManager.getTile(at: position) else { return 1.0 }

        var bonus: Float = 1.0

        // Height advantage (being on higher ground)
        let height = getTileHeight(tile.type)
        if height > 0 {
            bonus *= 1.05  // 5% damage bonus from high ground
        }

        // Cover bonus
        if providesCover(tile.type) {
            bonus *= 1.1  // 10% defense bonus from cover
        }

        // Elemental terrain synergy
        bonus *= getTerrainSynergyBonus(unit.type.damageType, on: tile.type)

        return bonus
    }

    private func getTileHeight(_ terrain: TileType) -> Float {
        switch terrain {
        case .stone: return 2.0  // Hills
        case .tree: return 1.0   // Slight elevation
        case .grass, .dirt: return 0.5  // Slight rise
        default: return 0.0
        }
    }

    private func providesCover(_ terrain: TileType) -> Bool {
        switch terrain {
        case .tree, .stone: return true
        default: return false
        }
    }

    private func getTerrainSynergyBonus(_ unitType: DamageType, on terrain: TileType) -> Float {
        // Synergy bonuses for units on their preferred terrain
        switch (unitType, terrain) {
        case (.fire, .sand), (.fire, .dirt):
            return 1.1   // Fire units stronger on dry terrain
        case (.water, .water):
            return 1.15  // Water units much stronger near water
        case (.earth, .stone), (.earth, .dirt):
            return 1.1   // Earth units stronger on earth terrain
        case (.air, .grass):
            return 1.05  // Air units slightly stronger in open areas
        case (.light, .grass):
            return 1.05  // Light units stronger in natural areas
        case (.dark, .tree), (.dark, .stone):
            return 1.1   // Dark units stronger in shadowed areas
        default:
            return 1.0
        }
    }

    private func applyDamage(_ damage: Float, to entity: Entity, from source: Entity?, damageType: DamageType) {
        guard var health = world.get(HealthComponent.self, for: entity) else { return }

        var finalDamage = damage

        // Apply armor/defense
        if let armor = world.get(ArmorComponent.self, for: entity) {
            finalDamage = armor.calculateDamage(damage, type: damageType)
        }

        // Apply unit defense if it's a unit
        if let unit = world.get(UnitComponent.self, for: entity) {
            let modifiedStats = unit.getModifiedStats()
            finalDamage *= (100.0 / (100.0 + modifiedStats.defense))
        }

        health.takeDamage(finalDamage)
        world.add(health, to: entity)

        // Experience for attacker
        if let source = source, let sourceUnit = world.get(UnitComponent.self, for: source) {
            sourceUnit.gainExperience(Float(finalDamage))
            world.add(sourceUnit, to: source)
        }
    }

    // MARK: - Visual Effects

    private func spawnAttackEffect(from: Vector2, to: Vector2, damageType: DamageType) {
        // Create a simple attack effect line
        // Implementation would add particle effect here with appropriate color based on damageType
        print("UnitSystem: Spawned attack effect from \(from) to \(to) with type \(damageType)")
    }

    private func spawnAreaAttackEffect(at position: Vector2, damageType: DamageType) {
        // Implementation would add area effect particles here
        print("UnitSystem: Spawned area attack effect at \(position)")
    }

    private func spawnHealEffect(at position: Vector2) {
        // Implementation would add healing particles here
        print("UnitSystem: Spawned heal effect at \(position)")
    }

    // MARK: - Terrain Helpers

    private func getUnitTerrain(_ entity: Entity) -> TileType? {
        guard let position = world.get(PositionComponent.self, for: entity)?.tilePosition else { return nil }
        return chunkManager.getTile(at: position)?.type
    }

    // MARK: - Unit Movement

    private func updateUnitMovement(deltaTime: Float) {
        world.forEach(VelocityComponent.self) { entity, velocity in
            guard let position = world.get(PositionComponent.self, for: entity) else { return }

            if velocity.velocity.lengthSquared > 0.001 {
                // Update position
                var newPos = position
                newPos.offset = position.offset + velocity.velocity * deltaTime

                // Handle tile transitions
                while newPos.offset.x >= 1 {
                    newPos.offset.x -= 1
                    newPos.tilePosition.x += 1
                }
                while newPos.offset.x < 0 {
                    newPos.offset.x += 1
                    newPos.tilePosition.x -= 1
                }
                while newPos.offset.y >= 1 {
                    newPos.offset.y -= 1
                    newPos.tilePosition.y += 1
                }
                while newPos.offset.y < 0 {
                    newPos.offset.y += 1
                    newPos.tilePosition.y -= 1
                }

                world.add(newPos, to: entity)

                // Update chunk membership
                if position.tilePosition != newPos.tilePosition {
                    if let oldChunk = chunkManager.getChunk(at: position.tilePosition) {
                        oldChunk.removeEntity(entity)
                    }
                    if let newChunk = chunkManager.getChunk(at: newPos.tilePosition) {
                        newChunk.addEntity(entity, at: newPos.tilePosition)
                    }
                }
            }
        }
    }
}
