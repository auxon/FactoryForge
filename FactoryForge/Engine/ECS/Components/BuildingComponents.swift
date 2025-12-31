import Foundation

// MARK: - Mining

/// Component for mining drills
struct MinerComponent: Component {
    /// Mining speed in items per second
    var miningSpeed: Float
    
    /// Resource being mined (nil if not on a resource)
    var resourceOutput: String?
    
    /// Mining progress (0-1)
    var progress: Float
    
    /// Whether the miner is currently active
    var isActive: Bool
    
    init(miningSpeed: Float = 0.5, resourceOutput: String? = nil) {
        self.miningSpeed = miningSpeed
        self.resourceOutput = resourceOutput
        self.progress = 0
        self.isActive = true
    }
}

// MARK: - Smelting

/// Component for furnaces
struct FurnaceComponent: Component {
    /// Smelting speed multiplier
    var smeltingSpeed: Float
    
    /// Current recipe being smelted
    var recipe: Recipe?
    
    /// Smelting progress (0-1)
    var smeltingProgress: Float
    
    /// Fuel remaining
    var fuelRemaining: Float
    
    init(smeltingSpeed: Float = 1.0) {
        self.smeltingSpeed = smeltingSpeed
        self.recipe = nil
        self.smeltingProgress = 0
        self.fuelRemaining = 0
    }
}

// MARK: - Assembling

/// Component for assemblers
struct AssemblerComponent: Component {
    /// Crafting speed multiplier
    var craftingSpeed: Float
    
    /// Allowed crafting categories
    var craftingCategory: String
    
    /// Current recipe
    var recipe: Recipe?
    
    /// Crafting progress (0-1)
    var craftingProgress: Float
    
    init(craftingSpeed: Float = 1.0, craftingCategory: String = "crafting") {
        self.craftingSpeed = craftingSpeed
        self.craftingCategory = craftingCategory
        self.recipe = nil
        self.craftingProgress = 0
    }
}

// MARK: - Logistics

/// Component for transport belts
struct BeltComponent: Component {
    /// Belt speed in tiles per second
    var speed: Float
    
    /// Belt direction
    var direction: Direction
    
    /// Items on the left lane
    var leftLane: [BeltItem]
    
    /// Items on the right lane
    var rightLane: [BeltItem]
    
    /// Connected belt on input side
    var inputConnection: Entity?
    
    /// Connected belt on output side
    var outputConnection: Entity?
    
    init(speed: Float = 1.0, direction: Direction = .north) {
        self.speed = speed
        self.direction = direction
        self.leftLane = []
        self.rightLane = []
        self.inputConnection = nil
        self.outputConnection = nil
    }
    
    /// Adds an item to the belt
    mutating func addItem(_ itemId: String, lane: BeltLane, position: Float = 0) -> Bool {
        let item = BeltItem(itemId: itemId, progress: position)
        
        switch lane {
        case .left:
            if canAddTo(lane: &leftLane, at: position) {
                leftLane.append(item)
                leftLane.sort { $0.progress < $1.progress }
                return true
            }
        case .right:
            if canAddTo(lane: &rightLane, at: position) {
                rightLane.append(item)
                rightLane.sort { $0.progress < $1.progress }
                return true
            }
        }
        return false
    }
    
    private func canAddTo(lane: inout [BeltItem], at position: Float) -> Bool {
        let minSpacing: Float = 0.25
        for item in lane {
            if abs(item.progress - position) < minSpacing {
                return false
            }
        }
        return true
    }
    
    /// Takes an item from the end of the belt
    mutating func takeItem(from lane: BeltLane) -> BeltItem? {
        switch lane {
        case .left:
            if let last = leftLane.last, last.progress >= 0.9 {
                return leftLane.removeLast()
            }
        case .right:
            if let last = rightLane.last, last.progress >= 0.9 {
                return rightLane.removeLast()
            }
        }
        return nil
    }
}

/// An item on a belt
struct BeltItem: Codable {
    var itemId: String
    var progress: Float  // 0 = start of belt, 1 = end of belt
}

enum BeltLane: Codable {
    case left
    case right
}

/// Component for inserters
struct InserterComponent: Component {
    /// Type of inserter (input or output)
    var type: InserterType

    /// Rotation speed in degrees per second
    var speed: Float

    /// Number of items to pick up at once
    var stackSize: Int

    /// Direction (from which side it picks up)
    var direction: Direction
    
    /// Current rotation angle
    var armAngle: Float
    
    /// Item currently being held
    var heldItem: ItemStack?
    
    /// Current state
    var state: InserterState
    
    /// Entity we picked up from (to avoid dropping back to it)
    var sourceEntity: Entity?
    
    /// Target position for the arm
    var targetAngle: Float {
        switch state {
        case .pickingUp:
            return .pi  // Facing input
        case .droppingOff, .idle:
            return 0    // Facing output
        case .rotating:
            return heldItem != nil ? 0 : .pi
        }
    }
    
    init(type: InserterType = .input, speed: Float = 2.0, stackSize: Int = 1, direction: Direction = .north) {
        self.type = type
        self.speed = speed
        self.stackSize = stackSize
        self.direction = direction
        self.armAngle = 0
        self.heldItem = nil
        self.state = .idle
        self.sourceEntity = nil
    }
}

enum InserterType: Codable {
    case input  // Picks up from sources, drops to machines
    case output // Picks up from machine outputs, drops to destinations
}

enum InserterState: Codable {
    case idle
    case pickingUp
    case rotating
    case droppingOff
}

// MARK: - Storage

/// Component for chests
struct ChestComponent: Component {
    // Just a marker - uses InventoryComponent for storage
}

// MARK: - Fluids

/// Component for pipes
struct PipeComponent: Component {
    var direction: Direction
    var fluidType: String?
    var fluidAmount: Float
    var maxCapacity: Float
    
    init(direction: Direction, maxCapacity: Float = 100) {
        self.direction = direction
        self.fluidType = nil
        self.fluidAmount = 0
        self.maxCapacity = maxCapacity
    }
}

/// Component for pumpjacks
struct PumpjackComponent: Component {
    var extractionRate: Float
    var oilRemaining: Float
    
    init(extractionRate: Float = 1.0, oilRemaining: Float = 0) {
        self.extractionRate = extractionRate
        self.oilRemaining = oilRemaining
    }
}

// MARK: - Research

/// Component for labs
struct LabComponent: Component {
    var researchSpeed: Float
    var isResearching: Bool
    
    init(researchSpeed: Float = 1.0) {
        self.researchSpeed = researchSpeed
        self.isResearching = false
    }
}

// MARK: - Defense

/// Component for walls
struct WallComponent: Component {
    // Marker component - uses HealthComponent for durability
}

