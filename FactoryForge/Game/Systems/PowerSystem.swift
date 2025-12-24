import Foundation

/// System that manages power networks
final class PowerSystem: System {
    let priority = SystemPriority.power.rawValue
    
    private let world: World
    
    /// Power networks
    private var networks: [PowerNetwork] = []
    
    /// Whether networks need rebuilding
    private var networksDirty = true
    
    init(world: World) {
        self.world = world
    }
    
    func markNetworksDirty() {
        networksDirty = true
    }
    
    func update(deltaTime: Float) {
        if networksDirty {
            rebuildNetworks()
            networksDirty = false
        }
        
        // Update each network
        for i in 0..<networks.count {
            updateNetwork(&networks[i], deltaTime: deltaTime)
        }
    }
    
    // MARK: - Network Building
    
    private func rebuildNetworks() {
        networks.removeAll()
        
        // Find all power poles
        var unvisited = Set<Entity>()
        for entity in world.query(PowerPoleComponent.self) {
            unvisited.insert(entity)
        }
        
        // Build networks using flood fill
        var networkId = 0
        while !unvisited.isEmpty {
            let startPole = unvisited.removeFirst()
            var network = PowerNetwork(id: networkId)
            
            // Flood fill to find all connected poles
            var queue: [Entity] = [startPole]
            var visited = Set<Entity>()
            
            while !queue.isEmpty {
                let pole = queue.removeFirst()
                guard !visited.contains(pole) else { continue }
                visited.insert(pole)
                unvisited.remove(pole)
                
                guard let poleComp = world.get(PowerPoleComponent.self, for: pole),
                      let polePos = world.get(PositionComponent.self, for: pole) else { continue }
                
                network.poles.append(pole)
                
                // Update pole's network ID
                var updatedPole = poleComp
                updatedPole.networkId = networkId
                world.add(updatedPole, to: pole)
                
                // Find entities in supply area
                let supplyRadius = poleComp.supplyArea
                let nearbyEntities = world.getEntitiesNear(position: polePos.worldPosition, radius: supplyRadius)
                
                for entity in nearbyEntities {
                    // Check if it's a generator
                    if world.has(GeneratorComponent.self, for: entity) {
                        if !network.generators.contains(entity) {
                            network.generators.append(entity)
                        }
                    }
                    if world.has(SolarPanelComponent.self, for: entity) {
                        if !network.generators.contains(entity) {
                            network.generators.append(entity)
                        }
                    }
                    if world.has(AccumulatorComponent.self, for: entity) {
                        if !network.accumulators.contains(entity) {
                            network.accumulators.append(entity)
                        }
                    }
                    
                    // Check if it's a consumer
                    if var consumer = world.get(PowerConsumerComponent.self, for: entity) {
                        if !network.consumers.contains(entity) {
                            network.consumers.append(entity)
                            consumer.networkId = networkId
                            world.add(consumer, to: entity)
                        }
                    }
                }
                
                // Find connected poles
                for otherPole in unvisited {
                    guard let otherPos = world.get(PositionComponent.self, for: otherPole) else { continue }
                    let distance = polePos.worldPosition.distance(to: otherPos.worldPosition)
                    if distance <= poleComp.wireReach {
                        queue.append(otherPole)
                        
                        // Update pole connections
                        var connections = poleComp.connections
                        if !connections.contains(otherPole) {
                            connections.append(otherPole)
                            updatedPole.connections = connections
                            world.add(updatedPole, to: pole)
                        }
                    }
                }
            }
            
            networks.append(network)
            networkId += 1
        }
    }
    
    // MARK: - Network Update
    
    private func updateNetwork(_ network: inout PowerNetwork, deltaTime: Float) {
        // Calculate total production
        var totalProduction: Float = 0
        
        for generator in network.generators {
            if let genComp = world.get(GeneratorComponent.self, for: generator) {
                totalProduction += genComp.currentOutput
            }
            if let solarComp = world.get(SolarPanelComponent.self, for: generator) {
                totalProduction += solarComp.currentOutput
            }
        }
        
        // Calculate total consumption
        var totalConsumption: Float = 0
        
        for consumer in network.consumers {
            if let consumerComp = world.get(PowerConsumerComponent.self, for: consumer) {
                totalConsumption += consumerComp.consumption
            }
        }
        
        network.totalProduction = totalProduction
        network.totalConsumption = totalConsumption
        
        // Calculate satisfaction
        var availablePower = totalProduction
        
        // Draw from accumulators if needed
        if availablePower < totalConsumption {
            let deficit = totalConsumption - availablePower
            for accumulator in network.accumulators {
                if var accComp = world.get(AccumulatorComponent.self, for: accumulator) {
                    let discharge = min(accComp.storedEnergy, deficit * deltaTime, accComp.chargeRate * deltaTime)
                    accComp.storedEnergy -= discharge
                    availablePower += discharge / deltaTime
                    accComp.mode = .discharging
                    world.add(accComp, to: accumulator)
                }
            }
        }
        
        // Charge accumulators if excess power
        if availablePower > totalConsumption {
            let excess = availablePower - totalConsumption
            for accumulator in network.accumulators {
                if var accComp = world.get(AccumulatorComponent.self, for: accumulator) {
                    let charge = min(accComp.capacity - accComp.storedEnergy, excess * deltaTime, accComp.chargeRate * deltaTime)
                    accComp.storedEnergy += charge
                    accComp.mode = charge > 0 ? .charging : .idle
                    world.add(accComp, to: accumulator)
                }
            }
        }
        
        // Calculate and apply satisfaction
        let satisfaction = totalConsumption > 0 ? min(availablePower / totalConsumption, 1.0) : 1.0
        network.satisfaction = satisfaction
        
        for consumer in network.consumers {
            if var consumerComp = world.get(PowerConsumerComponent.self, for: consumer) {
                consumerComp.satisfaction = satisfaction
                world.add(consumerComp, to: consumer)
            }
        }
        
        // Update generators
        updateGenerators(network: network, deltaTime: deltaTime)
    }
    
    private func updateGenerators(network: PowerNetwork, deltaTime: Float) {
        // Update fuel-based generators
        for generator in network.generators {
            if var genComp = world.get(GeneratorComponent.self, for: generator),
               var inventory = world.get(InventoryComponent.self, for: generator) {
                
                // Consume fuel if needed
                if genComp.fuelRemaining <= 0 {
                    if consumeFuel(inventory: &inventory, generator: &genComp) {
                        world.add(inventory, to: generator)
                    } else {
                        genComp.currentOutput = 0
                        world.add(genComp, to: generator)
                        continue
                    }
                }
                
                // Burn fuel based on demand
                if network.satisfaction < 1.0 || network.accumulators.contains(where: { acc in
                    guard let comp = world.get(AccumulatorComponent.self, for: acc) else { return false }
                    return comp.chargePercentage < 1.0
                }) {
                    genComp.fuelRemaining -= deltaTime
                    genComp.currentOutput = genComp.powerOutput
                } else {
                    genComp.currentOutput = 0
                }
                
                world.add(genComp, to: generator)
            }
            
            // Update solar panels (time-based output)
            if var solarComp = world.get(SolarPanelComponent.self, for: generator) {
                // Simplified day/night cycle
                let timeOfDay = fmodf(Time.shared.totalTime / 60, 1.0)  // 60 second day cycle
                let daylight = max(0, sinf(timeOfDay * .pi))
                solarComp.currentOutput = solarComp.powerOutput * daylight
                world.add(solarComp, to: generator)
            }
        }
    }
    
    private func consumeFuel(inventory: inout InventoryComponent, generator: inout GeneratorComponent) -> Bool {
        let fuels: [(String, Float)] = [
            ("coal", 4.0),
            ("wood", 2.0),
            ("solid-fuel", 12.0)
        ]
        
        for (fuelId, fuelValue) in fuels {
            if inventory.has(itemId: fuelId) {
                inventory.remove(itemId: fuelId, count: 1)
                generator.fuelRemaining = fuelValue
                generator.currentFuel = fuelId
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Public Interface
    
    func getNetworkInfo(for entity: Entity) -> PowerNetworkInfo? {
        guard let consumer = world.get(PowerConsumerComponent.self, for: entity),
              let networkId = consumer.networkId,
              networkId < networks.count else { return nil }
        
        let network = networks[networkId]
        return PowerNetworkInfo(
            production: network.totalProduction,
            consumption: network.totalConsumption,
            satisfaction: network.satisfaction
        )
    }
}

// MARK: - Power Network

struct PowerNetwork {
    let id: Int
    var poles: [Entity] = []
    var generators: [Entity] = []
    var consumers: [Entity] = []
    var accumulators: [Entity] = []
    var totalProduction: Float = 0
    var totalConsumption: Float = 0
    var satisfaction: Float = 1.0
}

struct PowerNetworkInfo {
    let production: Float
    let consumption: Float
    let satisfaction: Float
}

