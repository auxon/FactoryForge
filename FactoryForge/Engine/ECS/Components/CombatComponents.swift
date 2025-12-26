import Foundation

// MARK: - Turrets

/// Component for turrets
struct TurretComponent: Component {
    /// Attack range in tiles
    var range: Float
    
    /// Damage per shot
    var damage: Float
    
    /// Shots per second
    var fireRate: Float
    
    /// Time since last shot
    var cooldown: Float
    
    /// Current target entity
    var targetEntity: Entity?
    
    /// Turret rotation angle
    var rotation: Float
    
    /// Target rotation angle
    var targetRotation: Float
    
    /// Rotation speed in radians per second
    var rotationSpeed: Float
    
    init(range: Float = 18, damage: Float = 6, fireRate: Float = 10) {
        self.range = range
        self.damage = damage
        self.fireRate = fireRate
        self.cooldown = 0
        self.targetEntity = nil
        self.rotation = 0
        self.targetRotation = 0
        self.rotationSpeed = .pi * 2  // Full rotation per second
    }
    
    var isReady: Bool {
        return cooldown <= 0
    }
    
    mutating func fire() {
        cooldown = 1.0 / fireRate
    }
    
    mutating func update(deltaTime: Float) {
        cooldown = max(0, cooldown - deltaTime)
        
        // Rotate toward target
        let angleDiff = (targetRotation - rotation).truncatingRemainder(dividingBy: .pi * 2)
        let shortestAngle = angleDiff > .pi ? angleDiff - .pi * 2 : (angleDiff < -.pi ? angleDiff + .pi * 2 : angleDiff)
        let rotationAmount = min(abs(shortestAngle), rotationSpeed * deltaTime)
        rotation += shortestAngle > 0 ? rotationAmount : -rotationAmount
    }
}

// MARK: - Enemies

/// Component for enemy entities
struct EnemyComponent: Component {
    /// Enemy type
    var type: EnemyType

    /// Movement speed in tiles per second
    var speed: Float

    /// Attack damage
    var damage: Float

    /// Attack range
    var attackRange: Float

    /// Attack cooldown
    var attackCooldown: Float

    /// Time since last attack
    var timeSinceAttack: Float

    /// Current target (building to attack)
    var targetEntity: Entity?

    /// Current AI state
    var state: EnemyState

    /// Spawner that created this enemy (for tracking)
    var spawnerEntity: Entity?

    /// Maximum distance enemy will follow a target before giving up
    var maxFollowDistance: Float
    
    init(type: EnemyType) {
        self.type = type
        self.speed = type.baseSpeed
        self.damage = type.baseDamage
        self.attackRange = type.baseAttackRange
        self.attackCooldown = type.baseAttackCooldown
        self.timeSinceAttack = 0
        self.targetEntity = nil
        self.state = .idle
        self.spawnerEntity = nil
        self.maxFollowDistance = 10.0
    }
    
    var canAttack: Bool {
        return timeSinceAttack >= attackCooldown
    }
    
    mutating func attack() {
        timeSinceAttack = 0
    }
    
    mutating func update(deltaTime: Float) {
        timeSinceAttack += deltaTime
    }
}

enum EnemyType: String, Codable {
    case smallBiter
    case mediumBiter
    case bigBiter
    case behemothBiter
    case smallSpitter
    case mediumSpitter
    case bigSpitter
    case behemothSpitter
    
    var baseSpeed: Float {
        switch self {
        case .smallBiter: return 3.0
        case .mediumBiter: return 2.5
        case .bigBiter: return 2.0
        case .behemothBiter: return 1.5
        case .smallSpitter: return 2.5
        case .mediumSpitter: return 2.0
        case .bigSpitter: return 1.5
        case .behemothSpitter: return 1.0
        }
    }
    
    var baseDamage: Float {
        switch self {
        case .smallBiter: return 7
        case .mediumBiter: return 15
        case .bigBiter: return 30
        case .behemothBiter: return 90
        case .smallSpitter: return 10
        case .mediumSpitter: return 20
        case .bigSpitter: return 40
        case .behemothSpitter: return 75
        }
    }
    
    var baseHealth: Float {
        switch self {
        case .smallBiter: return 15
        case .mediumBiter: return 75
        case .bigBiter: return 375
        case .behemothBiter: return 3000
        case .smallSpitter: return 10
        case .mediumSpitter: return 50
        case .bigSpitter: return 200
        case .behemothSpitter: return 1500
        }
    }
    
    var baseAttackRange: Float {
        switch self {
        case .smallBiter, .mediumBiter, .bigBiter, .behemothBiter:
            return 1.0
        case .smallSpitter:
            return 13
        case .mediumSpitter:
            return 14
        case .bigSpitter:
            return 15
        case .behemothSpitter:
            return 16
        }
    }
    
    var baseAttackCooldown: Float {
        switch self {
        case .smallBiter: return 0.5
        case .mediumBiter: return 0.5
        case .bigBiter: return 0.5
        case .behemothBiter: return 0.5
        case .smallSpitter: return 2.0
        case .mediumSpitter: return 2.0
        case .bigSpitter: return 2.0
        case .behemothSpitter: return 2.0
        }
    }
    
    var isRanged: Bool {
        switch self {
        case .smallSpitter, .mediumSpitter, .bigSpitter, .behemothSpitter:
            return true
        default:
            return false
        }
    }
}

enum EnemyState: Codable {
    case idle
    case wandering
    case attacking
    case returning
    case fleeing
}

// MARK: - Spawners

/// Component for enemy spawners (nests)
struct SpawnerComponent: Component {
    /// Maximum number of enemies this spawner can have active
    var maxEnemies: Int
    
    /// Currently spawned enemies
    var spawnedCount: Int
    
    /// Time between spawns
    var spawnCooldown: Float
    
    /// Time since last spawn
    var timeSinceSpawn: Float
    
    /// Types of enemies this spawner can create
    var enemyTypes: [EnemyType]
    
    /// Pollution absorbed
    var absorbedPollution: Float
    
    /// Pollution threshold to trigger attack wave
    var pollutionThreshold: Float
    
    init(maxEnemies: Int = 10, spawnCooldown: Float = 10) {
        self.maxEnemies = maxEnemies
        self.spawnedCount = 0
        self.spawnCooldown = spawnCooldown
        self.timeSinceSpawn = 0
        self.enemyTypes = [.smallBiter]
        self.absorbedPollution = 0
        self.pollutionThreshold = 100
    }
    
    var canSpawn: Bool {
        return spawnedCount < maxEnemies && timeSinceSpawn >= spawnCooldown
    }
    
    mutating func spawn() {
        spawnedCount += 1
        timeSinceSpawn = 0
    }
    
    mutating func enemyDied() {
        spawnedCount = max(0, spawnedCount - 1)
    }
    
    mutating func update(deltaTime: Float) {
        timeSinceSpawn += deltaTime
    }
    
    mutating func absorbPollution(_ amount: Float) {
        absorbedPollution += amount
    }
    
    mutating func shouldTriggerAttack() -> Bool {
        if absorbedPollution >= pollutionThreshold {
            absorbedPollution = 0
            return true
        }
        return false
    }
}

// MARK: - Projectiles

/// Component for projectiles
struct ProjectileComponent: Component {
    /// Damage on hit
    var damage: Float
    
    /// Damage type
    var damageType: DamageType
    
    /// Target entity
    var target: Entity?
    
    /// Target position (for area damage)
    var targetPosition: Vector2?
    
    /// Movement speed
    var speed: Float
    
    /// Splash damage radius (0 = no splash)
    var splashRadius: Float
    
    /// Lifetime remaining
    var lifetime: Float
    
    /// Source entity (to prevent self-damage)
    var source: Entity?
    
    init(damage: Float, damageType: DamageType = .physical, speed: Float = 20,
         splashRadius: Float = 0, lifetime: Float = 5) {
        self.damage = damage
        self.damageType = damageType
        self.target = nil
        self.targetPosition = nil
        self.speed = speed
        self.splashRadius = splashRadius
        self.lifetime = lifetime
        self.source = nil
    }
}

