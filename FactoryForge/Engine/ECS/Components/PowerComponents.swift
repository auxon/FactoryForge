import Foundation

// MARK: - Power Production

/// Component for power-generating entities
class GeneratorComponent: BuildingComponent {
    /// Maximum power output in kW
    var powerOutput: Float

    /// Current power being generated
    var currentOutput: Float

    /// Fuel category this generator accepts
    var fuelCategory: String

    /// Fuel burning progress
    var burnProgress: Float

    /// Current fuel item being burned
    var currentFuel: String?

    /// Fuel value remaining
    var fuelRemaining: Float

    init(buildingId: String, powerOutput: Float, fuelCategory: String = "chemical") {
        self.powerOutput = powerOutput
        self.currentOutput = 0
        self.fuelCategory = fuelCategory
        self.burnProgress = 0
        self.currentFuel = nil
        self.fuelRemaining = 0
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId, powerOutput, currentOutput, fuelCategory, burnProgress, currentFuel, fuelRemaining
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        powerOutput = try container.decode(Float.self, forKey: .powerOutput)
        currentOutput = try container.decode(Float.self, forKey: .currentOutput)
        fuelCategory = try container.decode(String.self, forKey: .fuelCategory)
        burnProgress = try container.decode(Float.self, forKey: .burnProgress)
        currentFuel = try container.decodeIfPresent(String.self, forKey: .currentFuel)
        fuelRemaining = try container.decode(Float.self, forKey: .fuelRemaining)
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(powerOutput, forKey: .powerOutput)
        try container.encode(currentOutput, forKey: .currentOutput)
        try container.encode(fuelCategory, forKey: .fuelCategory)
        try container.encode(burnProgress, forKey: .burnProgress)
        try container.encode(currentFuel, forKey: .currentFuel)
        try container.encode(fuelRemaining, forKey: .fuelRemaining)
        try super.encode(to: encoder)
    }
}

/// Component for solar panels
class SolarPanelComponent: BuildingComponent {
    /// Maximum power output during daytime
    var powerOutput: Float

    /// Current power being generated (varies with time of day)
    var currentOutput: Float

    init(buildingId: String, powerOutput: Float = 60) {
        self.powerOutput = powerOutput
        self.currentOutput = powerOutput  // Assume daytime by default
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId, powerOutput, currentOutput
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        powerOutput = try container.decode(Float.self, forKey: .powerOutput)
        currentOutput = try container.decode(Float.self, forKey: .currentOutput)
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(powerOutput, forKey: .powerOutput)
        try container.encode(currentOutput, forKey: .currentOutput)
        try super.encode(to: encoder)
    }
}

/// Component for accumulators (batteries)
class AccumulatorComponent: BuildingComponent {
    /// Maximum energy storage in kJ
    var capacity: Float

    /// Current stored energy
    var storedEnergy: Float

    /// Maximum charge/discharge rate in kW
    var chargeRate: Float

    /// Current mode
    var mode: AccumulatorMode

    var chargePercentage: Float {
        return capacity > 0 ? storedEnergy / capacity : 0
    }

    init(buildingId: String, capacity: Float = 5000, chargeRate: Float = 300) {
        self.capacity = capacity
        self.storedEnergy = 0
        self.chargeRate = chargeRate
        self.mode = .idle
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId, capacity, storedEnergy, chargeRate, mode
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        capacity = try container.decode(Float.self, forKey: .capacity)
        storedEnergy = try container.decode(Float.self, forKey: .storedEnergy)
        chargeRate = try container.decode(Float.self, forKey: .chargeRate)
        mode = try container.decode(AccumulatorMode.self, forKey: .mode)
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(capacity, forKey: .capacity)
        try container.encode(storedEnergy, forKey: .storedEnergy)
        try container.encode(chargeRate, forKey: .chargeRate)
        try container.encode(mode, forKey: .mode)
        try super.encode(to: encoder)
    }
}

enum AccumulatorMode: Codable {
    case charging
    case discharging
    case idle
}

// MARK: - Power Consumption

/// Component for power-consuming entities
struct PowerConsumerComponent: Component {
    /// Power consumption in kW
    var consumption: Float
    
    /// Current power satisfaction (0-1)
    var satisfaction: Float
    
    /// Power network ID this consumer belongs to
    var networkId: Int?
    
    init(consumption: Float) {
        self.consumption = consumption
        self.satisfaction = 1.0
        self.networkId = nil
    }
    
    /// Effective speed multiplier based on power satisfaction
    var effectiveSpeed: Float {
        return satisfaction
    }
}

// MARK: - Power Distribution

/// Component for power poles
class PowerPoleComponent: BuildingComponent {
    /// Wire reach distance
    var wireReach: Float

    /// Supply area radius
    var supplyArea: Float

    /// Connected poles
    var connections: [Entity]

    /// Power network ID
    var networkId: Int?

    init(buildingId: String, wireReach: Float = 7.5, supplyArea: Float = 2.5) {
        self.wireReach = wireReach
        self.supplyArea = supplyArea
        self.connections = []
        self.networkId = nil
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId, wireReach, supplyArea, connections, networkId
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wireReach = try container.decode(Float.self, forKey: .wireReach)
        supplyArea = try container.decode(Float.self, forKey: .supplyArea)
        connections = try container.decode([Entity].self, forKey: .connections)
        networkId = try container.decodeIfPresent(Int.self, forKey: .networkId)
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(wireReach, forKey: .wireReach)
        try container.encode(supplyArea, forKey: .supplyArea)
        try container.encode(connections, forKey: .connections)
        try container.encode(networkId, forKey: .networkId)
        try super.encode(to: encoder)
    }
}

