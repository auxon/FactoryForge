import Foundation

/// Represents a single tile in the game world
struct Tile: Codable {
    /// The type of terrain
    var type: TileType
    
    /// Variation for visual diversity
    var variation: UInt8
    
    /// Resource deposit on this tile (if any)
    var resource: ResourceDeposit?
    
    /// Whether this tile can have buildings placed on it
    var isBuildable: Bool {
        guard type.isBuildable else { return false }
        return resource == nil || resource!.allowsBuilding
    }
    
    /// Whether entities can walk on this tile
    var isWalkable: Bool {
        return type.isWalkable
    }
    
    init(type: TileType, variation: UInt8 = 0, resource: ResourceDeposit? = nil) {
        self.type = type
        self.variation = variation
        self.resource = resource
    }
    
    /// Creates a tile instance for rendering
    func toInstance(at position: IntVector2) -> TileInstance {
        return TileInstance(
            position: position,
            textureIndex: type.rawValue,
            variation: variation,
            tint: resource?.tint ?? .white
        )
    }
}

/// A resource deposit on a tile
struct ResourceDeposit: Codable {
    /// Type of resource
    var type: ResourceType
    
    /// Amount remaining
    var amount: Int
    
    /// Original amount (for percentage calculations)
    let originalAmount: Int
    
    /// Richness affects mining speed
    var richness: Float
    
    var isEmpty: Bool {
        return amount <= 0
    }
    
    var percentRemaining: Float {
        return originalAmount > 0 ? Float(amount) / Float(originalAmount) : 0
    }
    
    var allowsBuilding: Bool {
        // Oil deposits don't allow regular buildings
        return type != .oil
    }
    
    var tint: Color {
        // Color tint based on resource type, with alpha based on remaining amount
        let percent = percentRemaining
        let alpha = 0.3 + percent * 0.7  // More visible alpha range

        switch type {
        case .ironOre:
            return Color(r: 0.7, g: 0.7, b: 0.8, a: alpha)  // Light gray-blue
        case .copperOre:
            return Color(r: 0.8, g: 0.6, b: 0.4, a: alpha)  // Copper brown
        case .coal:
            return Color(r: 0.3, g: 0.3, b: 0.3, a: alpha)  // Dark gray
        case .stone:
            return Color(r: 0.6, g: 0.6, b: 0.6, a: alpha)  // Medium gray
        case .uraniumOre:
            return Color(r: 0.2, g: 0.8, b: 0.4, a: alpha)  // Green
        case .oil:
            return Color(r: 0.4, g: 0.2, b: 0.6, a: alpha)  // Purple
        case .wood:
            return Color(r: 0.6, g: 0.4, b: 0.2, a: alpha)  // Brown wood
        }
    }
    
    init(type: ResourceType, amount: Int, richness: Float = 1.0) {
        self.type = type
        self.amount = amount
        self.originalAmount = amount
        self.richness = richness
    }
    
    /// Mines from this deposit
    /// - Returns: Amount actually mined
    @discardableResult
    mutating func mine(amount: Int = 1) -> Int {
        let mined = min(amount, self.amount)
        self.amount -= mined
        return mined
    }
}

/// Types of resources that can be mined
enum ResourceType: String, Codable, CaseIterable {
    case ironOre = "iron-ore"
    case copperOre = "copper-ore"
    case coal = "coal"
    case stone = "stone"
    case uraniumOre = "uranium-ore"
    case oil = "crude-oil"
    case wood = "wood"
    
    var displayName: String {
        switch self {
        case .ironOre: return "Iron Ore"
        case .copperOre: return "Copper Ore"
        case .coal: return "Coal"
        case .stone: return "Stone"
        case .uraniumOre: return "Uranium Ore"
        case .oil: return "Crude Oil"
        case .wood: return "Wood"
        }
    }
    
    var tileType: TileType {
        switch self {
        case .ironOre: return .ironOre
        case .copperOre: return .copperOre
        case .coal: return .coal
        case .stone: return .stone
        case .uraniumOre: return .stone  // Uranium uses stone texture with tint
        case .oil: return .sand
        case .wood: return .tree
        }
    }
    
    var outputItem: String {
        return rawValue
    }
    
    var color: Color {
        switch self {
        case .ironOre: return Color(r: 0.4, g: 0.5, b: 0.6, a: 1)
        case .copperOre: return Color(r: 0.8, g: 0.4, b: 0.2, a: 1)
        case .coal: return Color(r: 0.2, g: 0.2, b: 0.2, a: 1)
        case .stone: return Color(r: 0.6, g: 0.55, b: 0.5, a: 1)
        case .uraniumOre: return Color(r: 0.3, g: 0.8, b: 0.3, a: 1)
        case .oil: return Color(r: 0.1, g: 0.1, b: 0.1, a: 1)
        case .wood: return Color(r: 0.6, g: 0.4, b: 0.2, a: 1)  // Brown wood color
        }
    }
    
    /// Typical amount per deposit tile
    var typicalAmount: ClosedRange<Int> {
        switch self {
        case .ironOre, .copperOre, .coal, .stone, .wood:
            return 2000...10000
        case .uraniumOre:
            return 500...2000
        case .oil:
            return 10000...50000
        }
    }
    
    /// Minimum distance from spawn for this resource to appear
    var minimumSpawnDistance: Float {
        switch self {
        case .ironOre, .copperOre, .coal, .stone, .wood:
            return 0
        case .uraniumOre:
            return 200
        case .oil:
            return 100
        }
    }
}

