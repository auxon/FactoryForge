import Foundation

/// Unit types inspired by RTS + DnD + Pokemon
enum UnitType: String, Codable {
    // RTS-style units
    case militia = "Militia"           // Basic cheap unit, low damage, fast production
    case soldier = "Soldier"          // Balanced unit with firearms
    case heavyInfantry = "Heavy Infantry"  // Tanky unit, slow but strong
    case scout = "Scout"              // Fast reconnaissance unit
    case engineer = "Engineer"        // Can repair buildings and place explosives

    // DnD-style units
    case warrior = "Warrior"          // High HP, melee focused
    case ranger = "Ranger"            // Long range, high mobility
    case mage = "Mage"                // Magical attacks, area damage
    case paladin = "Paladin"          // Healing and protection
    case rogue = "Rogue"              // Stealth and backstab damage

    // Pokemon-style units (creatures)
    case fireElemental = "Fire Elemental"    // Fire attacks, weak to water
    case waterSpirit = "Water Spirit"        // Water attacks, weak to electric
    case earthGolem = "Earth Golem"          // Ground attacks, tanky
    case airSprite = "Air Sprite"            // Flying attacks, fast
    case shadowBeast = "Shadow Beast"        // Dark attacks, stealth
    case lightSeraph = "Light Seraph"        // Holy attacks, healing

    var displayName: String { rawValue }

    var baseStats: UnitStats {
        switch self {
        case .militia:
            return UnitStats(health: 50, attack: 8, defense: 2, speed: 3, range: 1)
        case .soldier:
            return UnitStats(health: 80, attack: 15, defense: 4, speed: 2.5, range: 8)
        case .heavyInfantry:
            return UnitStats(health: 150, attack: 25, defense: 8, speed: 1.5, range: 1)
        case .scout:
            return UnitStats(health: 40, attack: 6, defense: 1, speed: 5, range: 3)
        case .engineer:
            return UnitStats(health: 60, attack: 4, defense: 3, speed: 2.5, range: 1)

        case .warrior:
            return UnitStats(health: 120, attack: 20, defense: 6, speed: 2, range: 1)
        case .ranger:
            return UnitStats(health: 70, attack: 18, defense: 2, speed: 4, range: 12)
        case .mage:
            return UnitStats(health: 50, attack: 30, defense: 1, speed: 2, range: 6, mana: 100)
        case .paladin:
            return UnitStats(health: 100, attack: 15, defense: 5, speed: 2.5, range: 2, mana: 80)
        case .rogue:
            return UnitStats(health: 60, attack: 25, defense: 2, speed: 3.5, range: 1)

        case .fireElemental:
            return UnitStats(health: 80, attack: 20, defense: 3, speed: 3, range: 4, mana: 60)
        case .waterSpirit:
            return UnitStats(health: 70, attack: 18, defense: 2, speed: 3.5, range: 5, mana: 70)
        case .earthGolem:
            return UnitStats(health: 200, attack: 15, defense: 12, speed: 1, range: 2)
        case .airSprite:
            return UnitStats(health: 50, attack: 12, defense: 1, speed: 6, range: 6, mana: 50)
        case .shadowBeast:
            return UnitStats(health: 90, attack: 22, defense: 4, speed: 3.5, range: 1)
        case .lightSeraph:
            return UnitStats(health: 75, attack: 16, defense: 3, speed: 3, range: 8, mana: 90)
        }
    }

    var productionCost: [ItemStack] {
        switch self {
        case .militia:
            return [ItemStack(itemId: "iron-plate", count: 2)]
        case .soldier:
            return [ItemStack(itemId: "iron-plate", count: 5), ItemStack(itemId: "copper-plate", count: 3)]
        case .heavyInfantry:
            return [ItemStack(itemId: "iron-plate", count: 10), ItemStack(itemId: "steel-plate", count: 5)]
        case .scout:
            return [ItemStack(itemId: "iron-plate", count: 3)]
        case .engineer:
            return [ItemStack(itemId: "iron-plate", count: 4), ItemStack(itemId: "electronic-circuit", count: 2)]

        case .warrior:
            return [ItemStack(itemId: "iron-plate", count: 8), ItemStack(itemId: "iron-gear-wheel", count: 4)]
        case .ranger:
            return [ItemStack(itemId: "iron-plate", count: 6), ItemStack(itemId: "copper-plate", count: 4)]
        case .mage:
            return [ItemStack(itemId: "iron-plate", count: 4), ItemStack(itemId: "electronic-circuit", count: 6)]
        case .paladin:
            return [ItemStack(itemId: "steel-plate", count: 6), ItemStack(itemId: "electronic-circuit", count: 4)]
        case .rogue:
            return [ItemStack(itemId: "iron-plate", count: 5), ItemStack(itemId: "coal", count: 3)]

        case .fireElemental:
            return [ItemStack(itemId: "coal", count: 20), ItemStack(itemId: "electronic-circuit", count: 3)]
        case .waterSpirit:
            return [ItemStack(itemId: "electronic-circuit", count: 5), ItemStack(itemId: "copper-plate", count: 2)]
        case .earthGolem:
            return [ItemStack(itemId: "stone", count: 50), ItemStack(itemId: "iron-plate", count: 15)]
        case .airSprite:
            return [ItemStack(itemId: "electronic-circuit", count: 4), ItemStack(itemId: "plastic-bar", count: 2)]
        case .shadowBeast:
            return [ItemStack(itemId: "coal", count: 15), ItemStack(itemId: "sulfur", count: 5)]
        case .lightSeraph:
            return [ItemStack(itemId: "electronic-circuit", count: 8), ItemStack(itemId: "advanced-circuit", count: 2)]
        }
    }

    var productionTime: Float {
        switch self {
        case .militia: return 10
        case .soldier: return 20
        case .heavyInfantry: return 45
        case .scout: return 15
        case .engineer: return 25

        case .warrior: return 30
        case .ranger: return 25
        case .mage: return 40
        case .paladin: return 50
        case .rogue: return 20

        case .fireElemental: return 35
        case .waterSpirit: return 30
        case .earthGolem: return 60
        case .airSprite: return 25
        case .shadowBeast: return 40
        case .lightSeraph: return 55
        }
    }

    var textureId: String {
        switch self {
        case .militia: return "militia"
        case .soldier: return "soldier"
        case .heavyInfantry: return "heavy_infantry"
        case .scout: return "scout"
        case .engineer: return "engineer"

        case .warrior: return "warrior"
        case .ranger: return "ranger"
        case .mage: return "mage"
        case .paladin: return "paladin"
        case .rogue: return "rogue"

        case .fireElemental: return "fire_elemental"
        case .waterSpirit: return "water_spirit"
        case .earthGolem: return "earth_golem"
        case .airSprite: return "air_sprite"
        case .shadowBeast: return "shadow_beast"
        case .lightSeraph: return "light_seraph"
        }
    }

    var damageType: DamageType {
        switch self {
        case .militia, .soldier, .heavyInfantry, .scout, .engineer, .warrior, .ranger, .rogue:
            return .physical
        case .mage, .paladin:
            return .magical
        case .fireElemental:
            return .fire
        case .waterSpirit:
            return .water
        case .earthGolem:
            return .earth
        case .airSprite:
            return .air
        case .shadowBeast:
            return .dark
        case .lightSeraph:
            return .light
        }
    }

    var abilities: [UnitAbility] {
        switch self {
        case .militia:
            return [.charge]
        case .soldier:
            return [.shoot, .grenade]
        case .heavyInfantry:
            return [.shieldWall, .taunt]
        case .scout:
            return [.sneak, .scoutVision]
        case .engineer:
            return [.repair, .explosive]

        case .warrior:
            return [.berserk, .shieldBash]
        case .ranger:
            return [.snipe, .camouflage]
        case .mage:
            return [.fireball, .teleport, .manaShield]
        case .paladin:
            return [.heal, .divineShield, .smite]
        case .rogue:
            return [.backstab, .poison, .vanish]

        case .fireElemental:
            return [.fireBreath, .immolate]
        case .waterSpirit:
            return [.waterBlast, .heal]
        case .earthGolem:
            return [.earthquake, .stoneSkin]
        case .airSprite:
            return [.gust, .haste]
        case .shadowBeast:
            return [.shadowStrike, .fear]
        case .lightSeraph:
            return [.holyLight, .purify, .barrier]
        }
    }

    var unitClass: UnitClass {
        switch self {
        case .militia, .soldier, .heavyInfantry, .scout, .engineer:
            return .military
        case .warrior, .ranger, .mage, .paladin, .rogue:
            return .fantasy
        case .fireElemental, .waterSpirit, .earthGolem, .airSprite, .shadowBeast, .lightSeraph:
            return .elemental
        }
    }
}

enum UnitClass: String, Codable {
    case military = "Military"
    case fantasy = "Fantasy"
    case elemental = "Elemental"
}

enum DamageType: String, Codable {
    case physical = "Physical"
    case magical = "Magical"
    case fire = "Fire"
    case water = "Water"
    case earth = "Earth"
    case air = "Air"
    case electric = "Electric"
    case light = "Light"
    case dark = "Dark"
}

enum UnitAbility: String, Codable {
    // Military abilities
    case shoot = "Shoot"
    case grenade = "Grenade"
    case charge = "Charge"
    case shieldWall = "Shield Wall"
    case taunt = "Taunt"
    case sneak = "Sneak"
    case scoutVision = "Scout Vision"
    case repair = "Repair"
    case explosive = "Explosive"

    // Fantasy abilities
    case berserk = "Berserk"
    case shieldBash = "Shield Bash"
    case snipe = "Snipe"
    case camouflage = "Camouflage"
    case fireball = "Fireball"
    case teleport = "Teleport"
    case manaShield = "Mana Shield"
    case heal = "Heal"
    case divineShield = "Divine Shield"
    case smite = "Smite"
    case backstab = "Backstab"
    case poison = "Poison"
    case vanish = "Vanish"

    // Elemental abilities
    case fireBreath = "Fire Breath"
    case immolate = "Immolate"
    case waterBlast = "Water Blast"
    case earthquake = "Earthquake"
    case stoneSkin = "Stone Skin"
    case gust = "Gust"
    case haste = "Haste"
    case shadowStrike = "Shadow Strike"
    case fear = "Fear"
    case holyLight = "Holy Light"
    case purify = "Purify"
    case barrier = "Barrier"

    var cooldown: Float {
        switch self {
        case .shoot, .charge, .sneak, .repair: return 1.0
        case .grenade, .taunt, .scoutVision, .shieldBash, .camouflage, .backstab, .gust: return 3.0
        case .shieldWall, .explosive, .berserk, .snipe, .poison, .vanish, .fireBreath, .waterBlast, .shadowStrike: return 5.0
        case .fireball, .teleport, .manaShield, .heal, .divineShield, .smite, .immolate, .earthquake, .stoneSkin, .haste, .fear, .holyLight, .purify, .barrier: return 8.0
        }
    }

    var range: Float {
        switch self {
        case .shoot, .snipe, .fireball, .holyLight: return 8.0
        case .grenade, .gust: return 6.0
        case .teleport: return 12.0
        case .charge, .shieldWall, .taunt, .berserk, .shieldBash, .camouflage, .backstab, .poison, .vanish, .fireBreath, .immolate, .waterBlast, .earthquake, .stoneSkin, .haste, .shadowStrike, .fear, .purify, .barrier, .sneak, .scoutVision, .repair, .explosive, .manaShield, .heal, .divineShield, .smite: return 1.0
        }
    }

    var manaCost: Float {
        switch self {
        case .fireball, .teleport, .manaShield, .heal, .divineShield, .smite, .immolate, .haste, .holyLight, .purify, .barrier: return 20.0
        case .waterBlast, .earthquake, .stoneSkin, .fear: return 15.0
        case .shadowStrike: return 10.0
        default: return 0.0
        }
    }
}

struct UnitStats: Codable {
    var health: Float
    var attack: Float
    var defense: Float
    var speed: Float
    var range: Float
    var mana: Float = 0
    var experience: Float = 0
    var level: Int = 1

    static func + (lhs: UnitStats, rhs: UnitStats) -> UnitStats {
        return UnitStats(
            health: lhs.health + rhs.health,
            attack: lhs.attack + rhs.attack,
            defense: lhs.defense + rhs.defense,
            speed: lhs.speed + rhs.speed,
            range: lhs.range + rhs.range,
            mana: lhs.mana + rhs.mana,
            experience: lhs.experience,
            level: lhs.level
        )
    }
}

/// Component for controllable combat units
final class UnitComponent: Component {
    var type: UnitType
    var stats: UnitStats
    var currentHealth: Float
    var currentMana: Float
    var experience: Float = 0
    var level: Int = 1

    // Combat state
    var isSelected: Bool = false
    var targetEntity: Entity?
    var commandQueue: [UnitCommand] = []
    var currentCommand: UnitCommand?

    // Ability state
    var abilityCooldowns: [UnitAbility: Float] = [:]
    var statusEffects: [StatusEffect] = []

    // AI state
    var aggressionLevel: Float = 0.5  // 0 = passive, 1 = aggressive
    var lastAttackTime: TimeInterval = 0
    var lastMoveTime: TimeInterval = 0

    init(type: UnitType) {
        self.type = type
        self.stats = type.baseStats
        self.currentHealth = stats.health
        self.currentMana = stats.mana

        // Initialize ability cooldowns
        for ability in type.abilities {
            abilityCooldowns[ability] = 0
        }
    }

    func update(deltaTime: Float) {
        // Update ability cooldowns
        for (ability, cooldown) in abilityCooldowns {
            if cooldown > 0 {
                abilityCooldowns[ability] = max(0, cooldown - deltaTime)
            }
        }

        // Update status effects
        for i in (0..<statusEffects.count).reversed() {
            statusEffects[i].duration -= deltaTime
            if statusEffects[i].duration <= 0 {
                statusEffects.remove(at: i)
            }
        }
    }

    func canUseAbility(_ ability: UnitAbility) -> Bool {
        return abilityCooldowns[ability] ?? 0 <= 0 && currentMana >= ability.manaCost
    }

    func useAbility(_ ability: UnitAbility) {
        abilityCooldowns[ability] = ability.cooldown
        currentMana -= ability.manaCost
    }

    func gainExperience(_ amount: Float) {
        experience += amount
        let newLevel = Int(experience / 100) + 1
        if newLevel > level {
            levelUp(to: newLevel)
        }
    }

    private func levelUp(to newLevel: Int) {
        let oldLevel = level
        level = newLevel

        // Increase stats per level
        let levelsGained = newLevel - oldLevel
        stats = stats + UnitStats(
            health: 10 * Float(levelsGained),
            attack: 2 * Float(levelsGained),
            defense: 1 * Float(levelsGained),
            speed: 0.1 * Float(levelsGained),
            range: 0,
            mana: 5 * Float(levelsGained)
        )

        // Restore full health/mana on level up
        currentHealth = stats.health
        currentMana = stats.mana
    }

    func applyStatusEffect(_ effect: StatusEffect) {
        // Remove existing effects of the same type
        statusEffects.removeAll { $0.type == effect.type }
        statusEffects.append(effect)
    }

    func getModifiedStats() -> UnitStats {
        var modified = stats

        for effect in statusEffects {
            switch effect.type {
            case .strengthBoost:
                modified.attack *= 1.5
            case .defenseBoost:
                modified.defense *= 1.5
            case .speedBoost:
                modified.speed *= 1.5
            case .poison:
                modified.attack *= 0.7
            case .slow:
                modified.speed *= 0.5
            case .stun:
                modified.speed = 0
            case .burn:
                modified.health -= effect.magnitude
            case .freeze:
                modified.speed = 0
            case .healing:
                modified.health += effect.magnitude
            }
        }

        return modified
    }
}

/// Commands that units can execute
enum UnitCommand: Codable {
    case move(to: IntVector2)
    case attack(entity: Entity)
    case attackGround(position: IntVector2)
    case patrol(from: IntVector2, to: IntVector2)
    case holdPosition
    case useAbility(ability: UnitAbility, target: CommandTarget?)

    enum CommandTarget: Codable {
        case entity(Entity)
        case position(IntVector2)
    }
}

/// Status effects for units
struct StatusEffect: Codable {
    enum EffectType: String, Codable {
        case strengthBoost = "Strength Boost"
        case defenseBoost = "Defense Boost"
        case speedBoost = "Speed Boost"
        case poison = "Poison"
        case slow = "Slow"
        case stun = "Stun"
        case burn = "Burn"
        case freeze = "Freeze"
        case healing = "Healing"
    }

    var type: EffectType
    var duration: Float
    var magnitude: Float = 1.0

    static func strengthBoost(duration: Float) -> StatusEffect {
        StatusEffect(type: .strengthBoost, duration: duration, magnitude: 1.5)
    }

    static func defenseBoost(duration: Float) -> StatusEffect {
        StatusEffect(type: .defenseBoost, duration: duration, magnitude: 1.5)
    }

    static func speedBoost(duration: Float) -> StatusEffect {
        StatusEffect(type: .speedBoost, duration: duration, magnitude: 1.5)
    }

    static func poison(duration: Float) -> StatusEffect {
        StatusEffect(type: .poison, duration: duration, magnitude: 0.1)
    }

    static func slow(duration: Float) -> StatusEffect {
        StatusEffect(type: .slow, duration: duration, magnitude: 0.5)
    }

    static func stun(duration: Float) -> StatusEffect {
        StatusEffect(type: .stun, duration: duration)
    }

    static func burn(duration: Float) -> StatusEffect {
        StatusEffect(type: .burn, duration: duration, magnitude: 0.05)
    }

    static func freeze(duration: Float) -> StatusEffect {
        StatusEffect(type: .freeze, duration: duration)
    }

    static func healing(duration: Float) -> StatusEffect {
        StatusEffect(type: .healing, duration: duration, magnitude: 0.1)
    }
}

/// Component for unit production buildings
final class UnitProductionComponent: Component {
    var productionQueue: [UnitProductionOrder] = []
    var currentProduction: UnitProductionOrder?
    var productionProgress: Float = 0

    func startProduction(unitType: UnitType, count: Int = 1) {
        for _ in 0..<count {
            productionQueue.append(UnitProductionOrder(unitType: unitType))
        }
    }

    func update(deltaTime: Float) {
        if currentProduction == nil && !productionQueue.isEmpty {
            currentProduction = productionQueue.removeFirst()
            productionProgress = 0
        }

        if let production = currentProduction {
            productionProgress += deltaTime
            if productionProgress >= production.unitType.productionTime {
                // Production complete
                currentProduction = nil
                productionProgress = 0
            }
        }
    }

    func getProductionProgress() -> Float {
        guard let production = currentProduction else { return 0 }
        return productionProgress / production.unitType.productionTime
    }

    func getCurrentProduction() -> UnitType? {
        return currentProduction?.unitType
    }
}

struct UnitProductionOrder: Codable {
    let unitType: UnitType
    let startTime: TimeInterval

    init(unitType: UnitType, startTime: TimeInterval = Date().timeIntervalSince1970) {
        self.unitType = unitType
        self.startTime = startTime
    }
}