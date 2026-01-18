import Foundation

/// Health and damage tracking for destructible entities
struct HealthComponent: Component {
    /// Current health
    var current: Float
    
    /// Maximum health
    var max: Float
    
    /// Whether the entity is invulnerable
    var invulnerable: Bool
    
    /// Time remaining for damage immunity (after taking damage)
    var immunityTimer: Float
    
    /// Damage immunity duration after taking damage
    var immunityDuration: Float
    
    /// Whether the entity is dead
    var isDead: Bool {
        return current <= 0
    }


    /// Health as a percentage (0-1)
    var percentage: Float {
        return max > 0 ? current / max : 0
    }
    
    init(maxHealth: Float, invulnerable: Bool = false, immunityDuration: Float = 0) {
        self.current = maxHealth
        self.max = maxHealth
        self.invulnerable = invulnerable
        self.immunityTimer = 0
        self.immunityDuration = immunityDuration
    }
    
    /// Deals damage to the entity
    /// - Returns: Actual damage dealt
    @discardableResult
    mutating func takeDamage(_ damage: Float) -> Float {
        guard !invulnerable && immunityTimer <= 0 else { return 0 }
        
        let actualDamage = min(damage, current)
        current -= actualDamage
        
        if immunityDuration > 0 {
            immunityTimer = immunityDuration
        }
        
        return actualDamage
    }
    
    /// Heals the entity
    /// - Returns: Actual health restored
    @discardableResult
    mutating func heal(_ amount: Float) -> Float {
        let actualHeal = min(amount, max - current)
        current += actualHeal
        return actualHeal
    }
    
    /// Updates timers
    mutating func update(deltaTime: Float) {
        if immunityTimer > 0 {
            immunityTimer -= deltaTime
        }
    }
    
    /// Resets health to maximum
    mutating func reset() {
        current = max
        immunityTimer = 0
    }
}

/// Tree component for harvestable trees
struct TreeComponent: Component {
    /// Amount of wood this tree will drop when harvested
    var woodYield: Int

    /// Whether this tree has been marked for removal
    var markedForRemoval: Bool

    init(woodYield: Int = 800) {
        self.woodYield = woodYield
        self.markedForRemoval = false
    }
}
    

/// Armor/resistance component
struct ArmorComponent: Component, Codable {
    /// Flat damage reduction
    var flatReduction: Float

    /// Percentage damage reduction (0-1)
    var percentReduction: Float

    /// Damage type resistances
    var resistances: [DamageType: Float]

    init(flatReduction: Float = 0, percentReduction: Float = 0, resistances: [DamageType: Float] = [:]) {
        self.flatReduction = flatReduction
        self.percentReduction = percentReduction
        self.resistances = resistances
    }

    /// Calculates final damage after armor
    func calculateDamage(_ damage: Float, type: DamageType) -> Float {
        var finalDamage = damage

        // Apply flat reduction
        finalDamage -= flatReduction

        // Apply percentage reduction
        finalDamage *= (1 - percentReduction)

        // Apply type-specific resistance
        if let resistance = resistances[type] {
            finalDamage *= (1 - resistance)
        }

        return max(0, finalDamage)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case flatReduction, percentReduction, resistances
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        flatReduction = try container.decode(Float.self, forKey: .flatReduction)
        percentReduction = try container.decode(Float.self, forKey: .percentReduction)

        // Decode resistances dictionary
        let resistancesData = try container.decode([String: Float].self, forKey: .resistances)
        resistances = [:]
        for (key, value) in resistancesData {
            if let damageType = DamageType(rawValue: key) {
                resistances[damageType] = value
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(flatReduction, forKey: .flatReduction)
        try container.encode(percentReduction, forKey: .percentReduction)

        // Encode resistances dictionary
        var resistancesData: [String: Float] = [:]
        for (key, value) in resistances {
            resistancesData[key.rawValue] = value
        }
        try container.encode(resistancesData, forKey: .resistances)
    }
}

