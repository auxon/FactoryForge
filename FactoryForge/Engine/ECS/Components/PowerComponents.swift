import Foundation

// MARK: - Power Production

/// Component for power-generating entities
struct GeneratorComponent: Component {
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
    
    init(powerOutput: Float, fuelCategory: String = "chemical") {
        self.powerOutput = powerOutput
        self.currentOutput = 0
        self.fuelCategory = fuelCategory
        self.burnProgress = 0
        self.currentFuel = nil
        self.fuelRemaining = 0
    }
}

/// Component for solar panels
struct SolarPanelComponent: Component {
    /// Maximum power output during daytime
    var powerOutput: Float
    
    /// Current power being generated (varies with time of day)
    var currentOutput: Float
    
    init(powerOutput: Float = 60) {
        self.powerOutput = powerOutput
        self.currentOutput = powerOutput  // Assume daytime by default
    }
}

/// Component for accumulators (batteries)
struct AccumulatorComponent: Component {
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
    
    init(capacity: Float = 5000, chargeRate: Float = 300) {
        self.capacity = capacity
        self.storedEnergy = 0
        self.chargeRate = chargeRate
        self.mode = .idle
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
struct PowerPoleComponent: Component {
    /// Wire reach distance
    var wireReach: Float
    
    /// Supply area radius
    var supplyArea: Float
    
    /// Connected poles
    var connections: [Entity]
    
    /// Power network ID
    var networkId: Int?
    
    init(wireReach: Float = 7.5, supplyArea: Float = 2.5) {
        self.wireReach = wireReach
        self.supplyArea = supplyArea
        self.connections = []
        self.networkId = nil
    }
}

