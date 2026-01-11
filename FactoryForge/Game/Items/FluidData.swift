import Foundation

// This file contains only fluid-related data structures.
// ECS types (Entity, World, Component) are imported from the Engine/ECS module.

/// Types of fluids in the game
enum FluidType: String, Codable {
    case water
    case steam
    case crudeOil = "crude-oil"
    case heavyOil = "heavy-oil"
    case lightOil = "light-oil"
    case petroleumGas = "petroleum-gas"
    case sulfuricAcid = "sulfuric-acid"
    case lubricant
}

/// Physical properties of fluids
struct FluidProperties {
    let density: Float  // kg/L
    let viscosity: Float  // Flow resistance (higher = more viscous)
    let temperature: Float  // °C
    let energyValue: Float  // Energy content per liter for steam, etc.

    // Static properties for each fluid type
    static let properties: [FluidType: FluidProperties] = [
        .water: FluidProperties(density: 1.0, viscosity: 1.0, temperature: 15.0, energyValue: 0),
        .steam: FluidProperties(density: 0.5, viscosity: 0.8, temperature: 165.0, energyValue: 500), // ~500 kJ/L steam energy (Factorio balanced)
        .crudeOil: FluidProperties(density: 0.85, viscosity: 12.0, temperature: 20.0, energyValue: 0), // Very viscous
        .heavyOil: FluidProperties(density: 0.95, viscosity: 20.0, temperature: 20.0, energyValue: 0), // Extremely viscous
        .lightOil: FluidProperties(density: 0.75, viscosity: 3.0, temperature: 20.0, energyValue: 0),  // Moderately viscous
        .petroleumGas: FluidProperties(density: 0.25, viscosity: 0.3, temperature: 20.0, energyValue: 0), // Flows easily
        .sulfuricAcid: FluidProperties(density: 1.8, viscosity: 2.5, temperature: 20.0, energyValue: 0), // Corrosive but flows well
        .lubricant: FluidProperties(density: 0.9, viscosity: 6.0, temperature: 20.0, energyValue: 0)   // Viscous but flows better than oil
    ]

    static func getProperties(for fluidType: FluidType) -> FluidProperties {
        return properties[fluidType] ?? properties[.water]!
    }
}

/// A stack of fluid with type, amount, and temperature
struct FluidStack: Codable {
    let type: FluidType
    var amount: Float  // Liters
    let temperature: Float
    let maxAmount: Float

    init(type: FluidType, amount: Float = 0, temperature: Float? = nil, maxAmount: Float = 100) {
        self.type = type
        self.amount = amount
        self.temperature = temperature ?? FluidProperties.getProperties(for: type).temperature
        self.maxAmount = maxAmount
    }

    /// Returns the available space in this stack
    var availableSpace: Float {
        return max(0, maxAmount - amount)
    }

    /// Returns true if the stack is full
    var isFull: Bool {
        return amount >= maxAmount
    }

    /// Returns true if the stack is empty
    var isEmpty: Bool {
        return amount <= 0
    }

    /// Adds fluid to this stack, returns the amount that couldn't be added
    mutating func add(amount: Float) -> Float {
        let space = availableSpace
        let added = min(amount, space)
        self.amount += added
        return amount - added
    }

    /// Removes fluid from this stack, returns the amount actually removed
    mutating func remove(amount: Float) -> Float {
        let removed = min(amount, self.amount)
        self.amount -= removed
        return removed
    }

    /// Creates a copy of this stack
    func copy() -> FluidStack {
        return FluidStack(type: type, amount: amount, temperature: temperature, maxAmount: maxAmount)
    }
}

/// Represents a network of connected fluid pipes and buildings
struct FluidNetwork: Codable {
    var id: Int
    var fluidType: FluidType?
    var pipes: [Entity] = []
    var producers: [Entity] = []
    var consumers: [Entity] = []
    var tanks: [Entity] = []
    var pumps: [Entity] = []
    var totalCapacity: Float = 0
    var totalFluid: Float = 0
    var pressure: Float = 0

    /// Returns true if this network contains any fluid
    var hasFluid: Bool {
        return totalFluid > 0
    }

    /// Returns the fill percentage (0-1)
    var fillPercentage: Float {
        return totalCapacity > 0 ? totalFluid / totalCapacity : 0
    }

    /// Returns true if this network is empty
    var isEmpty: Bool {
        return pipes.isEmpty && producers.isEmpty && consumers.isEmpty && tanks.isEmpty && pumps.isEmpty
    }

    /// Adds an entity to the appropriate list based on its components
    mutating func addEntity(_ entity: Entity, world: World) {
        if world.has(PipeComponent.self, for: entity) {
            if !pipes.contains(entity) {
                pipes.append(entity)
            }
        } else if world.has(FluidProducerComponent.self, for: entity) {
            if !producers.contains(entity) {
                producers.append(entity)
            }
        } else if world.has(FluidConsumerComponent.self, for: entity) {
            if !consumers.contains(entity) {
                consumers.append(entity)
            }
        } else if world.has(FluidTankComponent.self, for: entity) {
            if !tanks.contains(entity) {
                tanks.append(entity)
            }
        } else if world.has(FluidPumpComponent.self, for: entity) {
            if !pumps.contains(entity) {
                pumps.append(entity)
            }
        }
        updateCapacity(world)
    }

    /// Removes an entity from all lists
    mutating func removeEntity(_ entity: Entity) {
        pipes.removeAll { $0 == entity }
        producers.removeAll { $0 == entity }
        consumers.removeAll { $0 == entity }
        tanks.removeAll { $0 == entity }
        pumps.removeAll { $0 == entity }
    }

    /// Updates total capacity and fluid amounts from all entities
    mutating func updateCapacity(_ world: World) {
        totalCapacity = 0
        totalFluid = 0

        // Calculate from pipes
        for pipeEntity in pipes {
            if let pipe = world.get(PipeComponent.self, for: pipeEntity) {
                totalCapacity += pipe.maxCapacity
                totalFluid += pipe.fluidAmount
            }
        }

        // Calculate from tanks
        for tankEntity in tanks {
            if let tank = world.get(FluidTankComponent.self, for: tankEntity) {
                for stack in tank.tanks {
                    totalCapacity += stack.maxAmount
                    totalFluid += stack.amount
                }
            }
        }
    }

    /// Merges another network into this one
    mutating func merge(with other: FluidNetwork, world: World) {
        pipes.append(contentsOf: other.pipes)
        producers.append(contentsOf: other.producers)
        consumers.append(contentsOf: other.consumers)
        tanks.append(contentsOf: other.tanks)
        pumps.append(contentsOf: other.pumps)

        // Update network IDs for all entities
        for entity in other.pipes + other.producers + other.consumers + other.tanks + other.pumps {
            if var pipe = world.get(PipeComponent.self, for: entity) {
                pipe.networkId = id
                world.add(pipe, to: entity)
            } else if var producer = world.get(FluidProducerComponent.self, for: entity) {
                producer.networkId = id
                world.add(producer, to: entity)
            } else if var consumer = world.get(FluidConsumerComponent.self, for: entity) {
                consumer.networkId = id
                world.add(consumer, to: entity)
            } else if var tank = world.get(FluidTankComponent.self, for: entity) {
                tank.networkId = id
                world.add(tank, to: entity)
            } else if var pump = world.get(FluidPumpComponent.self, for: entity) {
                pump.networkId = id
                world.add(pump, to: entity)
            }
        }

        updateCapacity(world)
    }
}