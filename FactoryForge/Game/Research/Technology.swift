import Foundation

/// Definition of a technology that can be researched
struct Technology: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let prerequisites: [String]
    let cost: [ScienceCost]
    let researchTime: Float
    let unlocks: TechnologyUnlocks
    let order: String
    let tier: Int
    
    init(
        id: String,
        name: String,
        description: String = "",
        prerequisites: [String] = [],
        cost: [ScienceCost],
        researchTime: Float = 30,
        unlocks: TechnologyUnlocks = TechnologyUnlocks(),
        order: String = "a",
        tier: Int = 1
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.prerequisites = prerequisites
        self.cost = cost
        self.researchTime = researchTime
        self.unlocks = unlocks
        self.order = order
        self.tier = tier
    }
}

/// Science pack cost for research
struct ScienceCost: Codable {
    let packId: String
    let count: Int
    
    init(_ packId: String, count: Int) {
        self.packId = packId
        self.count = count
    }
}

/// Things unlocked by a technology
struct TechnologyUnlocks: Codable {
    var recipes: [String]
    var bonuses: [TechnologyBonus]
    
    init(recipes: [String] = [], bonuses: [TechnologyBonus] = []) {
        self.recipes = recipes
        self.bonuses = bonuses
    }
}

/// A bonus provided by technology
struct TechnologyBonus: Codable {
    let type: BonusType
    let modifier: Float
    
    enum BonusType: String, Codable {
        case miningSpeed
        case craftingSpeed
        case inserterStackSize
        case turretDamage
        case turretRange
        case bulletDamage
        case characterInventorySlots
        case researchSpeed
    }
}

