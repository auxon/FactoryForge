import Foundation

// MARK: - Base Building Component

/// Base component for all buildings, providing common building identification
class BuildingComponent: Component {
    /// The building ID that identifies this building type in the registry
    var buildingId: String

    init(buildingId: String) {
        self.buildingId = buildingId
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Try to decode buildingId, but allow it to be missing for backward compatibility
        buildingId = try container.decodeIfPresent(String.self, forKey: .buildingId) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(buildingId, forKey: .buildingId)
    }
}

// MARK: - Mining

/// Component for mining drills
class MinerComponent: BuildingComponent {
    /// Mining speed in items per second
    var miningSpeed: Float

    /// Resource being mined (nil if not on a resource)
    var resourceOutput: String?

    /// Mining progress (0-1)
    var progress: Float

    /// Whether the miner is currently active
    var isActive: Bool

    /// Fuel remaining (for burner miners)
    var fuelRemaining: Float

    init(buildingId: String = "", miningSpeed: Float = 0.5, resourceOutput: String? = nil) {
        self.miningSpeed = miningSpeed
        self.resourceOutput = resourceOutput
        self.progress = 0
        self.isActive = true
        self.fuelRemaining = 0
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId, miningSpeed, resourceOutput, progress, isActive, fuelRemaining
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedMiningSpeed = try container.decode(Float.self, forKey: .miningSpeed)
        miningSpeed = decodedMiningSpeed
        resourceOutput = try container.decodeIfPresent(String.self, forKey: .resourceOutput)
        progress = try container.decode(Float.self, forKey: .progress)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        fuelRemaining = try container.decode(Float.self, forKey: .fuelRemaining)

        try super.init(from: decoder)

        // For backward compatibility, always infer buildingId based on properties
        buildingId = decodedMiningSpeed >= 0.7 ? "electric-mining-drill" : "burner-mining-drill"
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(miningSpeed, forKey: .miningSpeed)
        try container.encode(resourceOutput, forKey: .resourceOutput)
        try container.encode(progress, forKey: .progress)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(fuelRemaining, forKey: .fuelRemaining)
        try super.encode(to: encoder)
    }
}

// MARK: - Smelting

/// Component for furnaces
class FurnaceComponent: BuildingComponent {
    /// Smelting speed multiplier
    var smeltingSpeed: Float

    /// Current recipe being smelted
    var recipe: Recipe?

    /// Smelting progress (0-1)
    var smeltingProgress: Float

    /// Fuel remaining
    var fuelRemaining: Float

    init(buildingId: String = "", smeltingSpeed: Float = 1.0) {
        self.smeltingSpeed = smeltingSpeed
        self.recipe = nil
        self.smeltingProgress = 0
        self.fuelRemaining = 0
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId, smeltingSpeed, recipe, smeltingProgress, fuelRemaining
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSmeltingSpeed = try container.decode(Float.self, forKey: .smeltingSpeed)
        smeltingSpeed = decodedSmeltingSpeed
        recipe = try container.decodeIfPresent(Recipe.self, forKey: .recipe)
        smeltingProgress = try container.decode(Float.self, forKey: .smeltingProgress)
        fuelRemaining = try container.decode(Float.self, forKey: .fuelRemaining)

        try super.init(from: decoder)

        // For backward compatibility, always infer buildingId based on properties
        if decodedSmeltingSpeed >= 2.0 {
            buildingId = "electric-furnace"  // Prioritize electric over steel for slot compatibility
        } else {
            buildingId = "stone-furnace"
        }
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(buildingId, forKey: .buildingId)
        try container.encode(smeltingSpeed, forKey: .smeltingSpeed)
        try container.encode(recipe, forKey: .recipe)
        try container.encode(smeltingProgress, forKey: .smeltingProgress)
        try container.encode(fuelRemaining, forKey: .fuelRemaining)
    }
}

// MARK: - Assembling

/// Component for assemblers
class AssemblerComponent: BuildingComponent {
    /// Crafting speed multiplier
    var craftingSpeed: Float

    /// Allowed crafting categories
    var craftingCategory: String

    /// Current recipe
    var recipe: Recipe?

    /// Crafting progress (0-1)
    var craftingProgress: Float

    init(buildingId: String = "", craftingSpeed: Float = 1.0, craftingCategory: String = "crafting") {
        self.craftingSpeed = craftingSpeed
        self.craftingCategory = craftingCategory
        self.recipe = nil
        self.craftingProgress = 0
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId, craftingSpeed, craftingCategory, recipe, craftingProgress
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedCraftingSpeed = try container.decode(Float.self, forKey: .craftingSpeed)
        craftingSpeed = decodedCraftingSpeed
        craftingCategory = try container.decode(String.self, forKey: .craftingCategory)
        recipe = try container.decodeIfPresent(Recipe.self, forKey: .recipe)
        craftingProgress = try container.decode(Float.self, forKey: .craftingProgress)

        try super.init(from: decoder)

        // For backward compatibility, always infer buildingId based on properties
        if decodedCraftingSpeed >= 1.25 {
            buildingId = "assembling-machine-3"
        } else if decodedCraftingSpeed >= 0.75 {
            buildingId = "assembling-machine-2"
        } else {
            buildingId = "assembling-machine-1"
        }
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(craftingSpeed, forKey: .craftingSpeed)
        try container.encode(craftingCategory, forKey: .craftingCategory)
        try container.encode(recipe, forKey: .recipe)
        try container.encode(craftingProgress, forKey: .craftingProgress)
        try super.encode(to: encoder)
    }
}

// MARK: - Logistics

/// Component for transport belts
/// Different types of belt entities
enum BeltType: Codable {
    case normal
    case fast
    case express
    case underground
    case splitter
    case merger
    case bridge
}

class BeltComponent: BuildingComponent {
    /// Belt speed in tiles per second
    var speed: Float

    /// Belt direction
    var direction: Direction

    /// Type of belt
    var type: BeltType

    /// Items on the left lane
    var leftLane: [BeltItem]

    /// Items on the right lane
    var rightLane: [BeltItem]

    /// Connected belt on input side
    var inputConnection: Entity?

    /// Connected belt on output side
    var outputConnection: Entity?

    /// For underground belts: separate input and output positions
    var undergroundInputPosition: IntVector2?
    var undergroundOutputPosition: IntVector2?

    /// For splitters/mergers: multiple input/output connections
    var inputConnections: [Entity]
    var outputConnections: [Entity]

    init(buildingId: String = "", speed: Float = 1.0, direction: Direction = .north, type: BeltType = .normal) {
        self.speed = speed
        self.direction = direction
        self.type = type
        self.leftLane = []
        self.rightLane = []
        self.inputConnection = nil
        self.outputConnection = nil
        self.undergroundInputPosition = nil
        self.undergroundOutputPosition = nil
        self.inputConnections = []
        self.outputConnections = []
        super.init(buildingId: buildingId)
    }

    // Custom Codable conformance for backward compatibility
    enum CodingKeys: String, CodingKey {
        case buildingId, speed, direction, type, leftLane, rightLane
        case inputConnection, outputConnection
        case undergroundInputPosition, undergroundOutputPosition
        case inputConnections, outputConnections
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        speed = try container.decode(Float.self, forKey: .speed)
        direction = try container.decode(Direction.self, forKey: .direction)

        // New fields with backward compatibility - default to .normal if not present
        type = try container.decodeIfPresent(BeltType.self, forKey: .type) ?? .normal

        leftLane = try container.decode([BeltItem].self, forKey: .leftLane)
        rightLane = try container.decode([BeltItem].self, forKey: .rightLane)

        inputConnection = try container.decodeIfPresent(Entity.self, forKey: .inputConnection)
        outputConnection = try container.decodeIfPresent(Entity.self, forKey: .outputConnection)

        // New fields with defaults for backward compatibility
        undergroundInputPosition = try container.decodeIfPresent(IntVector2.self, forKey: .undergroundInputPosition)
        undergroundOutputPosition = try container.decodeIfPresent(IntVector2.self, forKey: .undergroundOutputPosition)
        inputConnections = try container.decodeIfPresent([Entity].self, forKey: .inputConnections) ?? []
        outputConnections = try container.decodeIfPresent([Entity].self, forKey: .outputConnections) ?? []

        // For backward compatibility, buildingId is optional and defaults to empty string
        let buildingId = try container.decodeIfPresent(String.self, forKey: .buildingId) ?? ""
        super.init(buildingId: buildingId)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(speed, forKey: .speed)
        try container.encode(direction, forKey: .direction)
        try container.encode(type, forKey: .type)
        try container.encode(leftLane, forKey: .leftLane)
        try container.encode(rightLane, forKey: .rightLane)
        try container.encode(inputConnection, forKey: .inputConnection)
        try container.encode(outputConnection, forKey: .outputConnection)
        try container.encode(undergroundInputPosition, forKey: .undergroundInputPosition)
        try container.encode(undergroundOutputPosition, forKey: .undergroundOutputPosition)
        try container.encode(inputConnections, forKey: .inputConnections)
        try container.encode(outputConnections, forKey: .outputConnections)
        try super.encode(to: encoder)
    }
    
    /// Adds an item to the belt
    func addItem(_ itemId: String, lane: BeltLane, position: Float = 0) -> Bool {
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
    func takeItem(from lane: BeltLane) -> BeltItem? {
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

    /// For splitters: distributes items to output lanes in round-robin fashion
    func addItemToSplitter(_ itemId: String) -> Bool {
        guard type == .splitter else { return false }

        // Alternate between left and right lanes for even distribution
        let leftCount = leftLane.count
        let rightCount = rightLane.count

        if leftCount <= rightCount {
            // Add to left lane
            return addItem(itemId, lane: .left, position: 0)
        } else {
            // Add to right lane
            return addItem(itemId, lane: .right, position: 0)
        }
    }

    /// For mergers: combines items from multiple inputs
    func takeItemFromMerger() -> BeltItem? {
        guard type == .merger else { return nil }

        // Check both lanes and take from the one with items ready
        if let item = takeItem(from: .left) {
            return item
        }
        if let item = takeItem(from: .right) {
            return item
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
class InserterComponent: BuildingComponent {
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

    /// Configured input target entity (belt, miner, machine output)
    var inputTarget: Entity?

    /// Configured output target entity (belt, machine input)
    var outputTarget: Entity?

    /// Configured input position (for belts when no entity at that position)
    var inputPosition: IntVector2?

    /// Configured output position (for belts)
    var outputPosition: IntVector2?

    /// Time spent trying to drop current item (for timeout logic)
    var dropTimeout: Float = 0

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

    init(buildingId: String, type: InserterType = .input, speed: Float = 2.0, stackSize: Int = 1, direction: Direction = .north) {
        self.type = type
        self.speed = speed
        self.stackSize = stackSize
        self.direction = direction
        self.armAngle = 0
        self.heldItem = nil
        self.state = .idle
        self.sourceEntity = nil
        self.inputTarget = nil
        self.outputTarget = nil
        self.inputPosition = nil
        self.outputPosition = nil
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId, type, speed, stackSize, direction, armAngle, heldItem, state, sourceEntity, inputTarget, outputTarget, inputPosition, outputPosition, dropTimeout
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(InserterType.self, forKey: .type)
        speed = try container.decode(Float.self, forKey: .speed)
        stackSize = try container.decode(Int.self, forKey: .stackSize)
        direction = try container.decode(Direction.self, forKey: .direction)
        armAngle = try container.decode(Float.self, forKey: .armAngle)
        heldItem = try container.decodeIfPresent(ItemStack.self, forKey: .heldItem)
        state = try container.decode(InserterState.self, forKey: .state)
        sourceEntity = try container.decodeIfPresent(Entity.self, forKey: .sourceEntity)
        inputTarget = try container.decodeIfPresent(Entity.self, forKey: .inputTarget)
        outputTarget = try container.decodeIfPresent(Entity.self, forKey: .outputTarget)
        inputPosition = try container.decodeIfPresent(IntVector2.self, forKey: .inputPosition)
        outputPosition = try container.decodeIfPresent(IntVector2.self, forKey: .outputPosition)
        dropTimeout = try container.decode(Float.self, forKey: .dropTimeout)
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(speed, forKey: .speed)
        try container.encode(stackSize, forKey: .stackSize)
        try container.encode(direction, forKey: .direction)
        try container.encode(armAngle, forKey: .armAngle)
        try container.encode(heldItem, forKey: .heldItem)
        try container.encode(state, forKey: .state)
        try container.encode(sourceEntity, forKey: .sourceEntity)
        try container.encode(inputTarget, forKey: .inputTarget)
        try container.encode(outputTarget, forKey: .outputTarget)
        try container.encode(inputPosition, forKey: .inputPosition)
        try container.encode(outputPosition, forKey: .outputPosition)
        try container.encode(dropTimeout, forKey: .dropTimeout)
        try super.encode(to: encoder)
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
class ChestComponent: BuildingComponent {
    // Just a marker - uses InventoryComponent for storage

    override init(buildingId: String) {
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId
    }

    required init(from decoder: Decoder) throws {
        // For backward compatibility, buildingId is optional and defaults to empty string
        let buildingId = try decoder.container(keyedBy: CodingKeys.self).decodeIfPresent(String.self, forKey: .buildingId) ?? ""
        super.init(buildingId: buildingId)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }
}

// MARK: - Fluids

/// Component for fluid producers (oil wells, boilers, water pumps)
class FluidProducerComponent: BuildingComponent {
    var outputType: FluidType
    var productionRate: Float  // L/s
    var currentProduction: Float
    var powerConsumption: Float
    var isActive: Bool = false  // Whether the producer is actively producing
    var fuelConsumptionAccumulator: Float = 0  // Tracks fuel consumption over time for boilers
    var connections: [Entity] = []
    var networkId: Int?

    init(buildingId: String, outputType: FluidType, productionRate: Float, powerConsumption: Float = 0) {
        self.outputType = outputType
        self.productionRate = productionRate
        self.currentProduction = 0
        self.powerConsumption = powerConsumption
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId, outputType, productionRate, currentProduction, powerConsumption, isActive, fuelConsumptionAccumulator, connections, networkId
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputType = try container.decode(FluidType.self, forKey: .outputType)
        productionRate = try container.decode(Float.self, forKey: .productionRate)
        currentProduction = try container.decode(Float.self, forKey: .currentProduction)
        powerConsumption = try container.decode(Float.self, forKey: .powerConsumption)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        fuelConsumptionAccumulator = try container.decodeIfPresent(Float.self, forKey: .fuelConsumptionAccumulator) ?? 0
        connections = try container.decodeIfPresent([Entity].self, forKey: .connections) ?? []
        networkId = try container.decodeIfPresent(Int.self, forKey: .networkId)
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(outputType, forKey: .outputType)
        try container.encode(productionRate, forKey: .productionRate)
        try container.encode(currentProduction, forKey: .currentProduction)
        try container.encode(powerConsumption, forKey: .powerConsumption)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(fuelConsumptionAccumulator, forKey: .fuelConsumptionAccumulator)
        try container.encode(connections, forKey: .connections)
        try container.encode(networkId, forKey: .networkId)
        try super.encode(to: encoder)
    }
}

/// Component for fluid consumers (steam engines, chemical plants)
class FluidConsumerComponent: BuildingComponent {
    var inputType: FluidType?
    var consumptionRate: Float  // L/s
    var currentConsumption: Float
    var efficiency: Float  // 0-1
    var connections: [Entity] = []
    var networkId: Int?

    init(buildingId: String, inputType: FluidType? = nil, consumptionRate: Float, efficiency: Float = 1.0) {
        self.inputType = inputType
        self.consumptionRate = consumptionRate
        self.currentConsumption = 0
        self.efficiency = efficiency
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId, inputType, consumptionRate, currentConsumption, efficiency, connections, networkId
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inputType = try container.decodeIfPresent(FluidType.self, forKey: .inputType)
        consumptionRate = try container.decode(Float.self, forKey: .consumptionRate)
        currentConsumption = try container.decode(Float.self, forKey: .currentConsumption)
        efficiency = try container.decode(Float.self, forKey: .efficiency)
        connections = try container.decodeIfPresent([Entity].self, forKey: .connections) ?? []
        networkId = try container.decodeIfPresent(Int.self, forKey: .networkId)
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(inputType, forKey: .inputType)
        try container.encode(consumptionRate, forKey: .consumptionRate)
        try container.encode(currentConsumption, forKey: .currentConsumption)
        try container.encode(efficiency, forKey: .efficiency)
        try container.encode(connections, forKey: .connections)
        try container.encode(networkId, forKey: .networkId)
        try super.encode(to: encoder)
    }
}

/// Component for fluid pumps (directional fluid movement)
class FluidPumpComponent: BuildingComponent {
    var inputConnection: Entity?
    var outputConnection: Entity?
    var flowRate: Float  // L/s
    var powerConsumption: Float
    var isActive: Bool
    var connections: [Entity] = []
    var networkId: Int?

    init(buildingId: String, flowRate: Float, powerConsumption: Float = 0) {
        self.flowRate = flowRate
        self.powerConsumption = powerConsumption
        self.isActive = true
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId, inputConnection, outputConnection, flowRate, powerConsumption, isActive, connections, networkId
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inputConnection = try container.decodeIfPresent(Entity.self, forKey: .inputConnection)
        outputConnection = try container.decodeIfPresent(Entity.self, forKey: .outputConnection)
        flowRate = try container.decode(Float.self, forKey: .flowRate)
        powerConsumption = try container.decode(Float.self, forKey: .powerConsumption)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        connections = try container.decodeIfPresent([Entity].self, forKey: .connections) ?? []
        networkId = try container.decodeIfPresent(Int.self, forKey: .networkId)
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(inputConnection, forKey: .inputConnection)
        try container.encode(outputConnection, forKey: .outputConnection)
        try container.encode(flowRate, forKey: .flowRate)
        try container.encode(powerConsumption, forKey: .powerConsumption)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(connections, forKey: .connections)
        try container.encode(networkId, forKey: .networkId)
        try super.encode(to: encoder)
    }
}

/// Component for fluid tanks (storage tanks, chemical plant tanks)
class FluidTankComponent: BuildingComponent {
    var tanks: [FluidStack] = []
    var maxCapacity: Float
    var connections: [Entity] = []
    var networkId: Int?

    init(buildingId: String, maxCapacity: Float) {
        self.maxCapacity = maxCapacity
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId, tanks, maxCapacity, connections, networkId
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tanks = try container.decode([FluidStack].self, forKey: .tanks)
        maxCapacity = try container.decode(Float.self, forKey: .maxCapacity)
        connections = try container.decodeIfPresent([Entity].self, forKey: .connections) ?? []
        networkId = try container.decodeIfPresent(Int.self, forKey: .networkId)
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tanks, forKey: .tanks)
        try container.encode(maxCapacity, forKey: .maxCapacity)
        try container.encode(connections, forKey: .connections)
        try container.encode(networkId, forKey: .networkId)
        try super.encode(to: encoder)
    }
}

/// Component for pipes
class PipeComponent: BuildingComponent {
    var direction: Direction
    var fluidType: FluidType?
    var fluidAmount: Float
    var maxCapacity: Float

    // New properties for fluid mechanics
    var connections: [Entity] = []  // Connected pipes and buildings
    var flowRate: Float = 0  // Current flow rate L/s
    var pressure: Float = 0  // System pressure
    var networkId: Int?  // Which fluid network this belongs to

    // Manual connection control - directions that have been manually disconnected
    var manuallyDisconnectedDirections: Set<Direction> = []

    init(buildingId: String, direction: Direction, maxCapacity: Float = 100) {
        self.direction = direction
        self.fluidType = nil
        self.fluidAmount = 0
        self.maxCapacity = maxCapacity
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId, direction, fluidType, fluidAmount, maxCapacity, connections, flowRate, pressure, networkId, manuallyDisconnectedDirections
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        direction = try container.decode(Direction.self, forKey: .direction)
        fluidType = try container.decodeIfPresent(FluidType.self, forKey: .fluidType)
        fluidAmount = try container.decode(Float.self, forKey: .fluidAmount)
        maxCapacity = try container.decode(Float.self, forKey: .maxCapacity)

        // New properties with backward compatibility
        connections = try container.decodeIfPresent([Entity].self, forKey: .connections) ?? []
        flowRate = try container.decodeIfPresent(Float.self, forKey: .flowRate) ?? 0
        pressure = try container.decodeIfPresent(Float.self, forKey: .pressure) ?? 0
        networkId = try container.decodeIfPresent(Int.self, forKey: .networkId)
        manuallyDisconnectedDirections = try container.decodeIfPresent(Set<Direction>.self, forKey: .manuallyDisconnectedDirections) ?? []

        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(direction, forKey: .direction)
        try container.encode(fluidType, forKey: .fluidType)
        try container.encode(fluidAmount, forKey: .fluidAmount)
        try container.encode(maxCapacity, forKey: .maxCapacity)
        try container.encode(connections, forKey: .connections)
        try container.encode(flowRate, forKey: .flowRate)
        try container.encode(pressure, forKey: .pressure)
        try container.encode(networkId, forKey: .networkId)
        try container.encode(manuallyDisconnectedDirections, forKey: .manuallyDisconnectedDirections)
        try super.encode(to: encoder)
    }
}

/// Component for pumpjacks
class PumpjackComponent: BuildingComponent {
    var extractionRate: Float
    var oilRemaining: Float

    /// The resource this pumpjack extracts
    var resourceType: String

    /// Extraction progress (0-1)
    var progress: Float

    /// Whether the pumpjack is currently active
    var isActive: Bool

    init(buildingId: String = "", extractionRate: Float = 1.0, oilRemaining: Float = 0, resourceType: String = "crude-oil") {
        self.extractionRate = extractionRate
        self.oilRemaining = oilRemaining
        self.resourceType = resourceType
        self.progress = 0
        self.isActive = true
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId, extractionRate, oilRemaining, resourceType, progress, isActive
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        extractionRate = try container.decode(Float.self, forKey: .extractionRate)
        oilRemaining = try container.decode(Float.self, forKey: .oilRemaining)
        resourceType = try container.decode(String.self, forKey: .resourceType)
        progress = try container.decode(Float.self, forKey: .progress)
        isActive = try container.decode(Bool.self, forKey: .isActive)

        try super.init(from: decoder)

        // For backward compatibility, infer buildingId if it's empty
        if buildingId.isEmpty {
            // Pumpjacks typically extract crude-oil
            buildingId = "pumpjack"
        }
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(extractionRate, forKey: .extractionRate)
        try container.encode(oilRemaining, forKey: .oilRemaining)
        try container.encode(resourceType, forKey: .resourceType)
        try container.encode(progress, forKey: .progress)
        try container.encode(isActive, forKey: .isActive)
        try super.encode(to: encoder)
    }
}

// MARK: - Research

/// Component for labs
class LabComponent: BuildingComponent {
    var researchSpeed: Float
    var isResearching: Bool

    init(buildingId: String = "", researchSpeed: Float = 1.0) {
        self.researchSpeed = researchSpeed
        self.isResearching = false
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId, researchSpeed, isResearching
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        researchSpeed = try container.decode(Float.self, forKey: .researchSpeed)
        isResearching = try container.decode(Bool.self, forKey: .isResearching)

        try super.init(from: decoder)

        // For backward compatibility, infer buildingId if it's empty
        if buildingId.isEmpty {
            buildingId = "lab"
        }
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(researchSpeed, forKey: .researchSpeed)
        try container.encode(isResearching, forKey: .isResearching)
        try super.encode(to: encoder)
    }
}

// MARK: - Defense

/// Component for walls
class WallComponent: BuildingComponent {
    // Marker component - uses HealthComponent for durability

    override init(buildingId: String = "") {
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId
    }

    required init(from decoder: Decoder) throws {
        // For backward compatibility, buildingId is optional and defaults to empty string
        let buildingId = try decoder.container(keyedBy: CodingKeys.self).decodeIfPresent(String.self, forKey: .buildingId) ?? ""
        super.init(buildingId: buildingId)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }
}

