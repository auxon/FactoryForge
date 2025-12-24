import Foundation

/// Definition of a building type
struct BuildingDefinition: Identifiable, Codable {
    let id: String
    let name: String
    let type: BuildingType
    let width: Int
    let height: Int
    let maxHealth: Float
    let textureId: String
    let cost: [ItemStack]
    
    // Mining
    var miningSpeed: Float = 0
    var resourceOutput: String?
    
    // Crafting
    var craftingSpeed: Float = 1
    var craftingCategory: String = "crafting"
    
    // Belt
    var beltSpeed: Float = 0
    
    // Inserter
    var inserterSpeed: Float = 0
    var inserterStackSize: Int = 1
    
    // Power
    var powerConsumption: Float = 0
    var powerProduction: Float = 0
    var wireReach: Float = 0
    var supplyArea: Float = 0
    var fuelCategory: String?
    
    // Storage
    var inventorySlots: Int = 0
    
    // Research
    var researchSpeed: Float = 1
    
    // Combat
    var turretRange: Float = 0
    var turretDamage: Float = 0
    var turretFireRate: Float = 0
    
    // Accumulator
    var accumulatorCapacity: Float = 0
    var accumulatorChargeRate: Float = 0
    
    // Fluid extraction
    var extractionRate: Float = 0
    
    init(
        id: String,
        name: String,
        type: BuildingType,
        width: Int = 1,
        height: Int = 1,
        maxHealth: Float = 100,
        textureId: String? = nil,
        cost: [ItemStack] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.width = width
        self.height = height
        self.maxHealth = maxHealth
        self.textureId = textureId ?? "building_placeholder"
        self.cost = cost
    }
}

/// Types of buildings
enum BuildingType: String, Codable, CaseIterable {
    case miner
    case furnace
    case assembler
    case belt
    case inserter
    case powerPole
    case generator
    case solarPanel
    case accumulator
    case lab
    case turret
    case wall
    case chest
    case pipe
    case pumpjack
}

