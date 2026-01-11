import Foundation

// Import fluid data structures
import Foundation

/// Represents a pair of entities for flow calculations
private struct EntityPair: Hashable {
    let from: Entity
    let to: Entity

    static func == (lhs: EntityPair, rhs: EntityPair) -> Bool {
        return lhs.from.id == rhs.from.id && lhs.from.generation == rhs.from.generation &&
               lhs.to.id == rhs.to.id && lhs.to.generation == rhs.to.generation
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(from.id)
        hasher.combine(from.generation)
        hasher.combine(to.id)
        hasher.combine(to.generation)
    }
}

/// System that manages fluid networks, connections, and flow calculations
final class FluidNetworkSystem: System {
    let priority = SystemPriority.logistics.rawValue

    private let world: World

    /// All fluid networks in the game
    private var networks: [Int: FluidNetwork] = [:]

    /// Next network ID to assign
    private var nextNetworkId: Int = 1

    /// Entities that need network updates
    private var dirtyEntities: Set<Entity> = []

    /// Networks that need flow recalculation
    private var dirtyNetworks: Set<Int> = []

    /// Performance optimization: Cache entity positions for faster lookups
    private var entityPositions: [Entity: IntVector2] = [:]

    /// Performance optimization: Cache entity connections for faster access
    private var entityConnections: [Entity: [Entity]] = [:]

    /// Performance optimization: Track networks by position for spatial queries
    private var networksByPosition: [IntVector2: Int] = [:]

    /// Performance optimization: Limit network size to prevent performance issues
    private let maxNetworkSize = 200  // Maximum entities per network

    /// Performance optimization: Update frequency control
    private var updateCounter: Int = 0
    private let updateFrequency = 3  // Update every 3 frames for less critical calculations

    init(world: World) {
        self.world = world
    }

    func update(deltaTime: Float) {
        updateCounter += 1

        // Process dirty entities (pipes/buildings that were added/removed/modified)
        if !dirtyEntities.isEmpty {
            updateNetworks()
            dirtyEntities.removeAll()
        }

        // Process dirty networks (need flow recalculation)
        // For performance, only update flow calculations every few frames for large networks
        if !dirtyNetworks.isEmpty {
            let largeNetworks = dirtyNetworks.filter { networkId in
                networks[networkId]?.pipes.count ?? 0 > 50
            }
            let smallNetworks = dirtyNetworks.subtracting(largeNetworks)

            // Always update small networks immediately
            updateFlowCalculations(for: smallNetworks, deltaTime: deltaTime)

            // Update large networks less frequently
            if updateCounter % updateFrequency == 0 {
                updateFlowCalculations(for: largeNetworks, deltaTime: deltaTime)
            }

            // Clear processed networks
            dirtyNetworks.subtract(smallNetworks)
            if updateCounter % updateFrequency == 0 {
                dirtyNetworks.subtract(largeNetworks)
            }
        }

        // Periodic cleanup and optimization
        if updateCounter % 60 == 0 {  // Every second at 60 FPS
            performPeriodicOptimization()
        }
    }

    // MARK: - Network Management

    /// Registers an entity that needs network updates
    func markEntityDirty(_ entity: Entity) {
        dirtyEntities.insert(entity)
    }

    /// Marks a network as needing flow recalculation
    func markNetworkDirty(_ networkId: Int) {
        dirtyNetworks.insert(networkId)
    }

    /// Updates networks based on dirty entities
    private func updateNetworks() {
        // If we have no networks yet, do a full rebuild
        if networks.isEmpty && !dirtyEntities.isEmpty {
            rebuildAllNetworks()
            return
        }

        // Process each dirty entity
        for entity in dirtyEntities {
            if world.isAlive(entity) {
                // Entity was added or modified
                handleEntityAdded(entity)
            } else {
                // Entity was removed
                handleEntityRemoved(entity)
            }
        }
    }

    /// Rebuilds all networks from scratch (used for initial setup)
    private func rebuildAllNetworks() {
        // Find all fluid entities (pipes for now - producers/consumers/tanks to be added later)
        let fluidEntities = findAllFluidEntities()

        // Clear existing networks
        networks.removeAll()

        // Reset network IDs on all entities
        for entity in fluidEntities {
            resetEntityNetworkId(entity)
        }

        // Discover networks using flood-fill
        for entity in fluidEntities {
            if getEntityNetworkId(entity) == nil {
                // Entity not in a network yet, start a new network
                let networkId = createNewNetworkId()
                let network = discoverNetwork(from: entity, networkId: networkId)
                if !network.isEmpty {
                    networks[networkId] = network
                }
            }
        }
    }

    /// Handles when a fluid entity is added or modified
    private func handleEntityAdded(_ entity: Entity) {
        // Establish connections for this entity
        establishConnections(for: entity)

        // Check if this entity connects to existing networks
        let connectedNetworkIds = findConnectedNetworkIds(for: entity)

        if connectedNetworkIds.isEmpty {
            // Entity doesn't connect to any existing networks, create a new one
            let networkId = createNewNetworkId()
            let network = discoverNetwork(from: entity, networkId: networkId)
            if !network.isEmpty {
                networks[networkId] = network
            }
        } else if connectedNetworkIds.count == 1 {
            // Entity connects to exactly one existing network, add it to that network
            let networkId = connectedNetworkIds.first!
            if var network = networks[networkId] {
                network.addEntity(entity, world: world)
                networks[networkId] = network
                markNetworkDirty(networkId)
            }
        } else {
            // Entity connects multiple networks, merge them
            mergeNetworks(connectedNetworkIds, with: entity)
            // Mark all affected networks as dirty
            for networkId in connectedNetworkIds {
                markNetworkDirty(networkId)
            }
        }
    }

    /// Handles when a fluid entity is removed
    private func handleEntityRemoved(_ entity: Entity) {
        // Remove connections from other entities to this entity
        removeConnectionsTo(entity)

        guard let networkId = getEntityNetworkId(entity) else {
            return // Entity wasn't in any network
        }

        guard var network = networks[networkId] else {
            return // Network doesn't exist
        }

        // Remove entity from network
        network.removeEntity(entity)
        networks[networkId] = network

        // Check if network is now empty
        if network.isEmpty {
            networks.removeValue(forKey: networkId)
            return
        }

        // Check if network needs to be split
        let remainingEntities = network.pipes + network.producers + network.consumers + network.tanks + network.pumps
        if remainingEntities.count > 1 {
            // Check if the network is still connected
            let connectedComponents = findConnectedComponents(in: remainingEntities)

            if connectedComponents.count > 1 {
                // Network split into multiple components, split the network
                splitNetwork(networkId, into: connectedComponents)
                // Mark all new networks as dirty
                for componentEntities in connectedComponents {
                    if let firstEntity = componentEntities.first,
                       let newNetworkId = getEntityNetworkId(firstEntity) {
                        markNetworkDirty(newNetworkId)
                    }
                }
            } else {
                // Network still connected, just mark as dirty
                markNetworkDirty(networkId)
            }
        }
    }

    /// Removes all connections to a specific entity
    private func removeConnectionsTo(_ targetEntity: Entity) {
        // Get all entities that might be connected to this entity
        // For efficiency, we'll check entities that were connected to it
        var entitiesToCheck: [Entity] = []

        // Get connections from the target entity
        if let pipe = world.get(PipeComponent.self, for: targetEntity) {
            entitiesToCheck.append(contentsOf: pipe.connections)
        } else if let producer = world.get(FluidProducerComponent.self, for: targetEntity) {
            entitiesToCheck.append(contentsOf: producer.connections)
        } else if let consumer = world.get(FluidConsumerComponent.self, for: targetEntity) {
            entitiesToCheck.append(contentsOf: consumer.connections)
        } else if let tank = world.get(FluidTankComponent.self, for: targetEntity) {
            entitiesToCheck.append(contentsOf: tank.connections)
        } else if let pump = world.get(FluidPumpComponent.self, for: targetEntity) {
            entitiesToCheck.append(contentsOf: pump.connections)
        } else if let pump = world.get(FluidPumpComponent.self, for: targetEntity) {
            entitiesToCheck.append(contentsOf: pump.connections)
        }

        // Remove the target entity from each connected entity's connections
        for entity in entitiesToCheck {
            removeConnection(from: entity, to: targetEntity)
        }
    }

    /// Finds network IDs that the given entity connects to (optimized with caching)
    private func findConnectedNetworkIds(for entity: Entity) -> Set<Int> {
        var connectedNetworkIds = Set<Int>()

        // Use cached position if available, otherwise get from world
        guard let position = entityPositions[entity] ?? world.get(PositionComponent.self, for: entity)?.tilePosition else {
            return connectedNetworkIds
        }

        // Check all adjacent positions
        let adjacentPositions = [
            position + IntVector2(x: 0, y: 1),   // North
            position + IntVector2(x: 1, y: 0),   // East
            position + IntVector2(x: 0, y: -1),  // South
            position + IntVector2(x: -1, y: 0)   // West
        ]

        // Performance optimization: Check spatial index first for adjacent positions
        for adjacentPos in adjacentPositions {
            if let networkId = networksByPosition[adjacentPos] {
                // Quick check: if we already know this position belongs to a network
                connectedNetworkIds.insert(networkId)
            } else {
                // Fallback: check entities at this position
                let entitiesAtPos = world.getAllEntitiesAt(position: adjacentPos)
                for adjacentEntity in entitiesAtPos {
                    // Check if this entity can connect to our entity
                    if canConnect(entity, to: adjacentEntity) {
                        // Check what network this adjacent entity belongs to
                        if let networkId = getEntityNetworkId(adjacentEntity) {
                            connectedNetworkIds.insert(networkId)
                            // Cache this for future lookups
                            networksByPosition[adjacentPos] = networkId
                        }
                    }
                }
            }
        }

        return connectedNetworkIds
    }

    /// Merges multiple networks into one
    private func mergeNetworks(_ networkIds: Set<Int>, with newEntity: Entity) {
        // Sort network IDs to ensure deterministic behavior
        let sortedIds = networkIds.sorted()
        let primaryNetworkId = sortedIds[0]

        // Get the primary network
        guard var primaryNetwork = networks[primaryNetworkId] else {
            return
        }

        // Add the new entity to the primary network
        primaryNetwork.addEntity(newEntity, world: world)

        // Merge all other networks into the primary network
        for networkId in sortedIds[1..<sortedIds.count] {
            if let otherNetwork = networks[networkId] {
                primaryNetwork.merge(with: otherNetwork, world: world)

                // Remove the merged network
                networks.removeValue(forKey: networkId)
            }
        }

        // Update the primary network
        networks[primaryNetworkId] = primaryNetwork

        // Mark the merged network as dirty
        markNetworkDirty(primaryNetworkId)
    }

    /// Finds connected components within a set of entities
    private func findConnectedComponents(in entities: [Entity]) -> [[Entity]] {
        var components: [[Entity]] = []
        var visited = Set<Entity>()

        for entity in entities {
            if !visited.contains(entity) {
                // Start a new component
                var component: [Entity] = []
                var queue = [entity]

                while !queue.isEmpty {
                    let currentEntity = queue.removeFirst()

                    if visited.contains(currentEntity) {
                        continue
                    }
                    visited.insert(currentEntity)
                    component.append(currentEntity)

                    // Find connected entities
                    let connectedEntities = findConnectedEntities(from: currentEntity)
                    for connectedEntity in connectedEntities {
                        if entities.contains(connectedEntity) && !visited.contains(connectedEntity) {
                            queue.append(connectedEntity)
                        }
                    }
                }

                if !component.isEmpty {
                    components.append(component)
                }
            }
        }

        return components
    }

    /// Splits a network into multiple networks based on connected components
    private func splitNetwork(_ networkId: Int, into components: [[Entity]]) {
        guard networks[networkId] != nil else {
            return
        }

        // Remove the original network
        networks.removeValue(forKey: networkId)

        // Create new networks for each component
        for componentEntities in components {
            let newNetworkId = createNewNetworkId()
            var newNetwork = FluidNetwork(id: newNetworkId)

            // Add entities to the new network
            for entity in componentEntities {
                newNetwork.addEntity(entity, world: world)
            }

            if !newNetwork.isEmpty {
                networks[newNetworkId] = newNetwork
            }
        }
    }

    // MARK: - Connection Establishment

    /// Establishes connections for a newly added entity
    private func establishConnections(for entity: Entity) {
        // Get position of the entity
        guard let position = world.get(PositionComponent.self, for: entity)?.tilePosition else {
            return
        }

        // Check all adjacent positions
        let adjacentPositions = [
            position + IntVector2(x: 0, y: 1),   // North
            position + IntVector2(x: 1, y: 0),   // East
            position + IntVector2(x: 0, y: -1),  // South
            position + IntVector2(x: -1, y: 0)   // West
        ]

        var newConnections: [Entity] = []

        for adjacentPos in adjacentPositions {
            // Find entities at this position
            let entitiesAtPos = world.getAllEntitiesAt(position: adjacentPos)
            for adjacentEntity in entitiesAtPos {
                // Check if this entity can connect to our entity
                if canConnect(entity, to: adjacentEntity) {
                    newConnections.append(adjacentEntity)
                    // Also add the connection to the adjacent entity
                    addConnection(from: adjacentEntity, to: entity)
                }
            }
        }

        // Update this entity's connections
        if world.has(PipeComponent.self, for: entity) {
            if let pipe = world.get(PipeComponent.self, for: entity) {
                pipe.connections = newConnections
                world.add(pipe, to: entity)
            }
        } else if world.has(FluidProducerComponent.self, for: entity) {
            if let producer = world.get(FluidProducerComponent.self, for: entity) {
                producer.connections = newConnections
                world.add(producer, to: entity)
            }
        } else if world.has(FluidConsumerComponent.self, for: entity) {
            if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
                consumer.connections = newConnections
                world.add(consumer, to: entity)
            }
        } else if world.has(FluidTankComponent.self, for: entity) {
            if let tank = world.get(FluidTankComponent.self, for: entity) {
                tank.connections = newConnections
                world.add(tank, to: entity)
            }
        } else if world.has(FluidPumpComponent.self, for: entity) {
            if let pump = world.get(FluidPumpComponent.self, for: entity) {
                pump.connections = newConnections
                world.add(pump, to: entity)
            }
        } else if world.has(FluidPumpComponent.self, for: entity) {
            if let pump = world.get(FluidPumpComponent.self, for: entity) {
                pump.connections = newConnections
                world.add(pump, to: entity)
            }
        }
    }

    /// Adds a connection from one entity to another
    private func addConnection(from entity: Entity, to connectedEntity: Entity) {
        if world.has(PipeComponent.self, for: entity) {
            if let pipe = world.get(PipeComponent.self, for: entity) {
                if !pipe.connections.contains(connectedEntity) {
                    pipe.connections.append(connectedEntity)
                    world.add(pipe, to: entity)
                }
            }
        } else if world.has(FluidProducerComponent.self, for: entity) {
            if let producer = world.get(FluidProducerComponent.self, for: entity) {
                if !producer.connections.contains(connectedEntity) {
                    producer.connections.append(connectedEntity)
                    world.add(producer, to: entity)
                }
            }
        } else if world.has(FluidConsumerComponent.self, for: entity) {
            if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
                if !consumer.connections.contains(connectedEntity) {
                    consumer.connections.append(connectedEntity)
                    world.add(consumer, to: entity)
                }
            }
        } else if world.has(FluidTankComponent.self, for: entity) {
            if let tank = world.get(FluidTankComponent.self, for: entity) {
                if !tank.connections.contains(connectedEntity) {
                    tank.connections.append(connectedEntity)
                    world.add(tank, to: entity)
                }
            }
        } else if world.has(FluidPumpComponent.self, for: entity) {
            if let pump = world.get(FluidPumpComponent.self, for: entity) {
                if !pump.connections.contains(connectedEntity) {
                    pump.connections.append(connectedEntity)
                    world.add(pump, to: entity)
                }
            }
        }
    }

    /// Removes a connection between entities
    private func removeConnection(from entity: Entity, to connectedEntity: Entity) {
        if world.has(PipeComponent.self, for: entity) {
            if let pipe = world.get(PipeComponent.self, for: entity) {
                pipe.connections.removeAll { $0 == connectedEntity }
                world.add(pipe, to: entity)
            }
        } else if world.has(FluidProducerComponent.self, for: entity) {
            if let producer = world.get(FluidProducerComponent.self, for: entity) {
                producer.connections.removeAll { $0 == connectedEntity }
                world.add(producer, to: entity)
            }
        } else if world.has(FluidConsumerComponent.self, for: entity) {
            if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
                consumer.connections.removeAll { $0 == connectedEntity }
                world.add(consumer, to: entity)
            }
        } else if world.has(FluidTankComponent.self, for: entity) {
            if let tank = world.get(FluidTankComponent.self, for: entity) {
                tank.connections.removeAll { $0 == connectedEntity }
                world.add(tank, to: entity)
            }
        } else if world.has(FluidPumpComponent.self, for: entity) {
            if let pump = world.get(FluidPumpComponent.self, for: entity) {
                pump.connections.removeAll { $0 == connectedEntity }
                world.add(pump, to: entity)
            }
        }
    }

    /// Finds all entities that participate in fluid networks
    private func findAllFluidEntities() -> [Entity] {
        var entities: [Entity] = []

        // Find all fluid entities
        for entity in world.entities {
            if world.has(PipeComponent.self, for: entity) ||
               world.has(FluidProducerComponent.self, for: entity) ||
               world.has(FluidConsumerComponent.self, for: entity) ||
               world.has(FluidTankComponent.self, for: entity) ||
               world.has(FluidPumpComponent.self, for: entity) {
                entities.append(entity)
            }
        }

        return entities
    }

    /// Resets an entity's network ID to nil
    private func resetEntityNetworkId(_ entity: Entity) {
        if let pipe = world.get(PipeComponent.self, for: entity) {
            pipe.networkId = nil
            world.add(pipe, to: entity)
        } else if let producer = world.get(FluidProducerComponent.self, for: entity) {
            producer.networkId = nil
            world.add(producer, to: entity)
        } else if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
            consumer.networkId = nil
            world.add(consumer, to: entity)
        } else if let tank = world.get(FluidTankComponent.self, for: entity) {
            tank.networkId = nil
            world.add(tank, to: entity)
        } else if let pump = world.get(FluidPumpComponent.self, for: entity) {
            pump.networkId = nil
            world.add(pump, to: entity)
        }
    }

    /// Gets the network ID for an entity
    private func getEntityNetworkId(_ entity: Entity) -> Int? {
        if let pipe = world.get(PipeComponent.self, for: entity) {
            return pipe.networkId
        } else if let producer = world.get(FluidProducerComponent.self, for: entity) {
            return producer.networkId
        } else if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
            return consumer.networkId
        } else if let tank = world.get(FluidTankComponent.self, for: entity) {
            return tank.networkId
        } else if let pump = world.get(FluidPumpComponent.self, for: entity) {
            return pump.networkId
        }
        return nil
    }

    /// Sets the network ID for an entity
    private func setEntityNetworkId(_ entity: Entity, networkId: Int) {
        if let pipe = world.get(PipeComponent.self, for: entity) {
            pipe.networkId = networkId
            world.add(pipe, to: entity)
        } else if let producer = world.get(FluidProducerComponent.self, for: entity) {
            producer.networkId = networkId
            world.add(producer, to: entity)
        } else if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
            consumer.networkId = networkId
            world.add(consumer, to: entity)
        } else if let tank = world.get(FluidTankComponent.self, for: entity) {
            tank.networkId = networkId
            world.add(tank, to: entity)
        } else if let pump = world.get(FluidPumpComponent.self, for: entity) {
            pump.networkId = networkId
            world.add(pump, to: entity)
        }
    }

    /// Creates a new unique network ID
    private func createNewNetworkId() -> Int {
        let id = nextNetworkId
        nextNetworkId += 1
        return id
    }

    // MARK: - Network Discovery (Flood-Fill Algorithm)

    /// Discovers a complete fluid network starting from an entity
    private func discoverNetwork(from startEntity: Entity, networkId: Int) -> FluidNetwork {
        var network = FluidNetwork(id: networkId)
        var visited = Set<Entity>()
        var queue = [startEntity]

        while !queue.isEmpty {
            let entity = queue.removeFirst()

            // Skip if already visited
            if visited.contains(entity) {
                continue
            }
            visited.insert(entity)

            // Add entity to network
            network.addEntity(entity, world: world)

            // Set network ID on entity
            setEntityNetworkId(entity, networkId: networkId)

            // Find connected entities
            let connectedEntities = findConnectedEntities(from: entity)
            for connectedEntity in connectedEntities {
                if !visited.contains(connectedEntity) {
                    queue.append(connectedEntity)
                }
            }
        }

        return network
    }

    /// Finds entities connected to the given entity (optimized with caching)
    private func findConnectedEntities(from entity: Entity) -> [Entity] {
        // Use cached connections if available and valid
        if let cachedConnections = entityConnections[entity] {
            // Verify cached connections are still valid (entities still exist and are connected)
            let validConnections = cachedConnections.filter { connectedEntity in
                world.isAlive(connectedEntity) && canConnect(entity, to: connectedEntity)
            }
            if validConnections.count == cachedConnections.count {
                // All cached connections are still valid, use them
                return validConnections
            }
        }

        // Fallback: calculate connections from scratch
        var connected: [Entity] = []

        // Get position of the entity (use cache if available)
        guard let position = entityPositions[entity] ?? world.get(PositionComponent.self, for: entity)?.tilePosition else {
            return connected
        }

        // Check all adjacent positions
        let adjacentPositions = [
            position + IntVector2(x: 0, y: 1),   // North
            position + IntVector2(x: 1, y: 0),   // East
            position + IntVector2(x: 0, y: -1),  // South
            position + IntVector2(x: -1, y: 0)   // West
        ]

        for adjacentPos in adjacentPositions {
            // Find entities at this position
            let entitiesAtPos = world.getAllEntitiesAt(position: adjacentPos)
            for adjacentEntity in entitiesAtPos {
                // Check if this entity can connect to our entity
                if canConnect(entity, to: adjacentEntity) {
                    connected.append(adjacentEntity)
                }
            }
        }

        // Cache the connections for future use
        entityConnections[entity] = connected

        return connected
    }

    /// Checks if two entities can connect via fluid flow
    private func canConnect(_ entity1: Entity, to entity2: Entity) -> Bool {
        // Both must be fluid-capable entities
        let isFluidEntity1 = isFluidEntity(entity1)
        let isFluidEntity2 = isFluidEntity(entity2)

        if !isFluidEntity1 || !isFluidEntity2 {
            return false
        }

        // Get positions
        guard let pos1 = world.get(PositionComponent.self, for: entity1)?.tilePosition,
              let pos2 = world.get(PositionComponent.self, for: entity2)?.tilePosition else {
            return false
        }

        // Check if entities are adjacent (including diagonally for now - can be refined later)
        let deltaX = abs(pos1.x - pos2.x)
        let deltaY = abs(pos1.y - pos2.y)

        // Must be adjacent (not the same position)
        if deltaX > 1 || deltaY > 1 || (deltaX == 0 && deltaY == 0) {
            return false
        }

        // Pipes can connect to any adjacent fluid entities
        if world.has(PipeComponent.self, for: entity1) || world.has(PipeComponent.self, for: entity2) {
            return true
        }

        // For building-to-building connections, check if they have compatible interfaces
        // For now, allow connections between any fluid buildings (simplified)
        // TODO: Add direction-based connection rules for specific buildings
        return true
    }

    /// Checks if an entity is capable of fluid operations
    private func isFluidEntity(_ entity: Entity) -> Bool {
        return world.has(PipeComponent.self, for: entity) ||
               world.has(FluidProducerComponent.self, for: entity) ||
               world.has(FluidConsumerComponent.self, for: entity) ||
               world.has(FluidTankComponent.self, for: entity) ||
               world.has(FluidPumpComponent.self, for: entity)
    }

    // MARK: - Flow Calculations

    /// Updates flow calculations for dirty networks
    private func updateFlowCalculations(_ deltaTime: Float) {
        for networkId in dirtyNetworks {
            if var network = networks[networkId] {
                calculateNetworkFlow(&network, deltaTime: deltaTime)
                networks[networkId] = network
            }
        }
    }

    /// Calculates fluid flow within a network using advanced pressure simulation
    private func calculateNetworkFlow(_ network: inout FluidNetwork, deltaTime: Float) {
        // Early exit optimization: skip calculation if network has no producers/consumers
        let hasActivity = !network.producers.isEmpty || !network.consumers.isEmpty
        if !hasActivity {
            // No production or consumption, just update basic capacity
            network.updateCapacity(world)
            return
        }

        // Step 1: Calculate production and consumption rates
        let productionRates = calculateProductionRates(for: network, deltaTime: deltaTime)
        let consumptionRates = calculateConsumptionRates(for: network, deltaTime: deltaTime)

        let totalProduction = productionRates.values.reduce(0, +)
        let totalConsumption = consumptionRates.values.reduce(0, +)
        let netFlow = totalProduction - totalConsumption

        // Early exit optimization: if net flow is negligible, skip detailed calculations
        if abs(netFlow) < 0.01 && network.pipes.count > 10 {
            // For large networks with minimal flow, just update capacity
            network.updateCapacity(world)
            return
        }

        // Step 2: Calculate pressure distribution across the network
        let pressureMap = calculatePressureDistribution(in: network, netFlow: netFlow)

        // Step 3: Calculate flow rates between connected components (skip for very small networks)
        let flowRates: [EntityPair: Float]
        if network.pipes.count > 1 {
            flowRates = calculateFlowRates(in: network, pressureMap: pressureMap, deltaTime: deltaTime)
        } else {
            flowRates = [:]  // No flow calculations needed for single-pipe networks
        }

        // Step 4: Apply fluid transfers based on calculated flow rates
        if !flowRates.isEmpty {
            applyFluidTransfers(in: network, flowRates: flowRates, deltaTime: deltaTime)
        }

        // Step 5: Update network pressure and capacity
        network.pressure = calculateNetworkPressure(network: network, pressureMap: pressureMap)
        network.updateCapacity(world)
    }

    /// Update flow calculations for specific networks (performance optimization)
    private func updateFlowCalculations(for networkIds: Set<Int>, deltaTime: Float) {
        for networkId in networkIds {
            if var network = networks[networkId] {
                // Skip flow calculations for networks that are too large (performance safeguard)
                let networkSize = network.pipes.count + network.producers.count + network.consumers.count + network.tanks.count
                if networkSize > maxNetworkSize {
                    // For very large networks, do simplified calculations only
                    performSimplifiedFlowCalculation(for: &network, deltaTime: deltaTime)
                } else {
                    calculateNetworkFlow(&network, deltaTime: deltaTime)
                }
                networks[networkId] = network
            }
        }
    }

    /// Simplified flow calculation for very large networks (performance optimization)
    private func performSimplifiedFlowCalculation(for network: inout FluidNetwork, deltaTime: Float) {
        // Simplified calculation: just update basic pressure without detailed flow simulation
        if network.totalCapacity > 0 {
            let fillRate = network.totalFluid / network.totalCapacity
            network.pressure = fillRate * 100.0

            // Basic flow rate approximation - no detailed flow simulation for large networks
            for pipeEntity in network.pipes {
                if let pipe = world.get(PipeComponent.self, for: pipeEntity) {
                    pipe.flowRate = 0  // Simplified: assume minimal flow in large networks
                    world.add(pipe, to: pipeEntity)
                }
            }
        }

        network.updateCapacity(world)
    }

    /// Periodic optimization and cleanup
    private func performPeriodicOptimization() {
        // Clean up empty networks
        let emptyNetworkIds = networks.filter { $0.value.isEmpty }.keys
        for networkId in emptyNetworkIds {
            networks.removeValue(forKey: networkId)
        }

        // Clean up stale caches
        let allFluidEntities = findAllFluidEntities()
        let validEntities = Set(allFluidEntities)

        entityPositions = entityPositions.filter { validEntities.contains($0.key) }
        entityConnections = entityConnections.filter { validEntities.contains($0.key) }
        // Note: networksByPosition is cleaned up naturally as entities move/remove

        // Update caches for better performance
        updateCaches(for: allFluidEntities)
    }

    /// Update performance caches
    private func updateCaches(for entities: [Entity]) {
        for entity in entities {
            // Cache position (use cached value if available)
            if let position = entityPositions[entity] ?? world.get(PositionComponent.self, for: entity)?.tilePosition {
                entityPositions[entity] = position
                if let networkId = getEntityNetworkId(entity) {
                    networksByPosition[position] = networkId
                }
            }

            // Cache connections (use cached value if available)
            if entityConnections[entity] == nil {
                if let pipe = world.get(PipeComponent.self, for: entity) {
                    entityConnections[entity] = pipe.connections
                } else if let producer = world.get(FluidProducerComponent.self, for: entity) {
                    entityConnections[entity] = producer.connections
                } else if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
                    entityConnections[entity] = consumer.connections
                } else if let tank = world.get(FluidTankComponent.self, for: entity) {
                    entityConnections[entity] = tank.connections
                }
            }
        }
    }

    /// Calculate production rates for all producers in the network
    private func calculateProductionRates(for network: FluidNetwork, deltaTime: Float) -> [Entity: Float] {
        var productionRates: [Entity: Float] = [:]

        for producerEntity in network.producers {
            if let producer = world.get(FluidProducerComponent.self, for: producerEntity) {
                var productionThisTick: Float = 0

                // Special handling for boilers - need fuel + water
                if producer.buildingId == "boiler" {
                    if let generator = world.get(GeneratorComponent.self, for: producerEntity),
                       let tank = world.get(FluidTankComponent.self, for: producerEntity) {

                        let hasFuel = generator.fuelRemaining > 0 || generator.currentFuel != nil
                        let hasWater = tank.tanks.contains { $0.type == .water && $0.amount > 10 } // Need minimum water

                        if hasFuel && hasWater {
                            productionThisTick = producer.productionRate * deltaTime
                            // Consume water at the same rate as steam production
                            let waterConsumed = productionThisTick
                            _ = removeFluidFromTank(producerEntity, amount: waterConsumed, fluidType: .water)
                        }
                    }
                } else {
                    // Other producers - check power and output capacity
                    let powerSatisfaction = world.get(PowerConsumerComponent.self, for: producerEntity)?.satisfaction ?? 1.0
                    let hasPower = producer.powerConsumption == 0 || powerSatisfaction > 0.5

                    if hasPower {
                        // Check if producer can output (connected pipes have space)
                        let canOutput = hasOutputCapacity(producerEntity: producerEntity, network: network)
                        if canOutput {
                            productionThisTick = producer.productionRate * deltaTime * powerSatisfaction
                        }
                    }
                }

                if productionThisTick > 0 {
                    productionRates[producerEntity] = productionThisTick
                    let updatedProducer = producer
                    updatedProducer.currentProduction = productionThisTick
                    world.add(updatedProducer, to: producerEntity)
                }
            }
        }

        return productionRates
    }

    /// Calculate consumption rates for all consumers in the network
    private func calculateConsumptionRates(for network: FluidNetwork, deltaTime: Float) -> [Entity: Float] {
        var consumptionRates: [Entity: Float] = [:]

        for consumerEntity in network.consumers {
            if let consumer = world.get(FluidConsumerComponent.self, for: consumerEntity) {
                let powerSatisfaction = world.get(PowerConsumerComponent.self, for: consumerEntity)?.satisfaction ?? 1.0
                let hasPower = consumer.buildingId == "steam-engine" || powerSatisfaction > 0.5

                if hasPower {
                    // Check if consumer has input available
                    let hasInput = hasInputAvailable(consumerEntity: consumerEntity, network: network)
                    if hasInput {
                        let consumptionThisTick = consumer.consumptionRate * deltaTime * powerSatisfaction
                        consumptionRates[consumerEntity] = consumptionThisTick

                        let updatedConsumer = consumer
                        updatedConsumer.currentConsumption = consumptionThisTick
                        world.add(updatedConsumer, to: consumerEntity)
                    }
                }
            }
        }

        return consumptionRates
    }

    /// Check if a producer has capacity to output fluid
    private func hasOutputCapacity(producerEntity: Entity, network: FluidNetwork) -> Bool {
        // Check if connected pipes/tanks have space for the produced fluid
        if let producer = world.get(FluidProducerComponent.self, for: producerEntity) {
            for connectedEntity in producer.connections {
                if let pipe = world.get(PipeComponent.self, for: connectedEntity) {
                    // Check if pipe has space and can accept this fluid type
                    if pipe.fluidAmount < pipe.maxCapacity &&
                       (pipe.fluidType == nil || pipe.fluidType == producer.outputType) {
                        return true
                    }
                } else if let tank = world.get(FluidTankComponent.self, for: connectedEntity) {
                    // Check if tank has space for this fluid type
                    let totalCapacity = tank.maxCapacity
                    let currentAmount = tank.tanks.reduce(0) { $0 + $1.amount }
                    if currentAmount < totalCapacity {
                        return true
                    }
                }
            }
        }
        return false
    }

    /// Check if a consumer has fluid available for consumption
    private func hasInputAvailable(consumerEntity: Entity, network: FluidNetwork) -> Bool {
        if let consumer = world.get(FluidConsumerComponent.self, for: consumerEntity) {
            for connectedEntity in consumer.connections {
                if let pipe = world.get(PipeComponent.self, for: connectedEntity) {
                    // Check if pipe has the required fluid type and amount
                    if pipe.fluidType == consumer.inputType && pipe.fluidAmount > 10 { // Minimum amount
                        return true
                    }
                } else if let tank = world.get(FluidTankComponent.self, for: connectedEntity) {
                    // Check if tank has the required fluid
                    for tankStack in tank.tanks {
                        if tankStack.type == consumer.inputType && tankStack.amount > 10 {
                            return true
                        }
                    }
                }
            }
        }
        return false
    }

    /// Calculate pressure distribution across the network (optimized for performance)
    private func calculatePressureDistribution(in network: FluidNetwork, netFlow: Float) -> [Entity: Float] {
        var pressureMap: [Entity: Float] = [:]

        // Performance optimization: For very large networks, use simplified pressure calculation
        let networkSize = network.pipes.count + network.tanks.count
        let useSimplified = networkSize > 100

        if useSimplified {
            // Simplified calculation for large networks
            let avgFillRatio = network.totalCapacity > 0 ? network.totalFluid / network.totalCapacity : 0
            let basePressure = avgFillRatio * 100.0 + netFlow * 5.0

            // Apply same pressure to all components (approximation)
            for pipeEntity in network.pipes {
                pressureMap[pipeEntity] = basePressure
            }
            for tankEntity in network.tanks {
                pressureMap[tankEntity] = basePressure
            }
            for producerEntity in network.producers {
                pressureMap[producerEntity] = basePressure + 20.0  // Producers add pressure
            }
            for consumerEntity in network.consumers {
                pressureMap[consumerEntity] = basePressure - 20.0  // Consumers reduce pressure
            }
        } else {
            // Detailed calculation for smaller networks
            // Calculate base pressure for each component based on fill level
            for pipeEntity in network.pipes {
                if let pipe = world.get(PipeComponent.self, for: pipeEntity) {
                    let fillRatio = pipe.maxCapacity > 0 ? pipe.fluidAmount / pipe.maxCapacity : 0
                    pressureMap[pipeEntity] = fillRatio * 100.0
                }
            }

            for tankEntity in network.tanks {
                if let tank = world.get(FluidTankComponent.self, for: tankEntity) {
                    let totalFluid = tank.tanks.reduce(0) { $0 + $1.amount }
                    let fillRatio = tank.maxCapacity > 0 ? totalFluid / tank.maxCapacity : 0
                    pressureMap[tankEntity] = fillRatio * 100.0
                }
            }

            // Adjust pressure based on producers and consumers
            for producerEntity in network.producers {
                if pressureMap[producerEntity] != nil {
                    // Producers add pressure (tend to push fluid out)
                    pressureMap[producerEntity]! += 20.0
                }
            }

            for consumerEntity in network.consumers {
                if pressureMap[consumerEntity] != nil {
                    // Consumers reduce pressure (tend to pull fluid in)
                    pressureMap[consumerEntity]! -= 20.0
                }
            }

            // Add network-wide pressure adjustment
            let networkPressureAdjustment = netFlow * 5.0 // Net flow affects overall network pressure
            for (entity, pressure) in pressureMap {
                pressureMap[entity] = pressure + networkPressureAdjustment
            }
        }

        return pressureMap
    }

    /// Calculate flow rates between connected components based on pressure gradients
    private func calculateFlowRates(in network: FluidNetwork, pressureMap: [Entity: Float], deltaTime: Float) -> [EntityPair: Float] {
        var flowRates: [EntityPair: Float] = [:]

        // Check all pipes and their connections
        for pipeEntity in network.pipes {
            guard let pipe = world.get(PipeComponent.self, for: pipeEntity),
                  let pipePressure = pressureMap[pipeEntity] else { continue }

            for connectedEntity in pipe.connections {
                guard let connectedPressure = pressureMap[connectedEntity] else { continue }

                // Calculate pressure gradient
                let pressureDiff = pipePressure - connectedPressure

                // Only flow if there's a significant pressure difference
                if abs(pressureDiff) > 5.0 {
                    // Calculate flow rate based on pressure difference and pipe properties
                    let baseFlowRate = pressureDiff * 2.0 // Pressure difference drives flow

                    // Apply fluid viscosity effects (higher viscosity = slower flow)
                    var viscosityMultiplier: Float = 1.0
                    if let fluidType = pipe.fluidType {
                        viscosityMultiplier = 1.0 / FluidProperties.getProperties(for: fluidType).viscosity
                    }

                    // Apply pipe capacity limits
                    let maxFlowRate = pipe.maxCapacity * 0.1 // Max 10% of capacity per second

                    let flowRate = min(abs(baseFlowRate) * viscosityMultiplier * deltaTime, maxFlowRate)
                    let actualFlowRate = pressureDiff > 0 ? flowRate : -flowRate

                    let entityPair = EntityPair(from: pipeEntity, to: connectedEntity)
                    flowRates[entityPair] = actualFlowRate
                }
            }
        }

        return flowRates
    }

    /// Apply calculated fluid transfers
    private func applyFluidTransfers(in network: FluidNetwork, flowRates: [EntityPair: Float], deltaTime: Float) {
        for (entityPair, flowRate) in flowRates {
            let fromEntity = entityPair.from
            let toEntity = entityPair.to
            let transferAmount = abs(flowRate)

            // Get fluid type from source
            var fluidType: FluidType? = nil
            if let pipe = world.get(PipeComponent.self, for: fromEntity) {
                fluidType = pipe.fluidType
            } else if let tank = world.get(FluidTankComponent.self, for: fromEntity) {
                // For tanks, we'd need to determine which fluid to transfer
                // For simplicity, transfer the first available fluid
                fluidType = tank.tanks.first?.type
            }

            guard let transferFluidType = fluidType else { continue }

            // Transfer from source to destination
            _ = transferFluid(from: fromEntity, to: toEntity, amount: transferAmount, fluidType: transferFluidType)

            // Update flow rate indicators
            if let pipe = world.get(PipeComponent.self, for: fromEntity) {
                let updatedPipe = pipe
                updatedPipe.flowRate = flowRate
                world.add(updatedPipe, to: fromEntity)
            }
        }

        // Handle special producer/consumer transfers (bypass normal pipe flow)
        handleDirectTransfers(in: network, deltaTime: deltaTime)
    }

    /// Transfer fluid between two entities
    private func transferFluid(from fromEntity: Entity, to toEntity: Entity, amount: Float, fluidType: FluidType) -> Float {
        // Remove from source
        let removedAmount = removeFluidFromEntity(fromEntity, amount: amount, fluidType: fluidType)
        if removedAmount <= 0 { return 0 }

        // Add to destination
        let addedAmount = addFluidToEntity(toEntity, amount: removedAmount, fluidType: fluidType)

        return addedAmount
    }

    /// Remove fluid from an entity
    private func removeFluidFromEntity(_ entity: Entity, amount: Float, fluidType: FluidType) -> Float {
        if world.has(PipeComponent.self, for: entity) {
            return removeFluidFromPipe(entity, amount: amount, fluidType: fluidType)
        } else if world.has(FluidTankComponent.self, for: entity) {
            return removeFluidFromTank(entity, amount: amount, fluidType: fluidType)
        }
        return 0
    }

    /// Add fluid to an entity
    private func addFluidToEntity(_ entity: Entity, amount: Float, fluidType: FluidType) -> Float {
        if world.has(PipeComponent.self, for: entity) {
            return addFluidToPipe(entity, amount: amount, fluidType: fluidType)
        } else if world.has(FluidTankComponent.self, for: entity) {
            return addFluidToTank(entity, amount: amount, fluidType: fluidType)
        }
        return 0
    }

    /// Remove fluid from a pipe
    private func removeFluidFromPipe(_ pipeEntity: Entity, amount: Float, fluidType: FluidType) -> Float {
        guard let originalPipe = world.get(PipeComponent.self, for: pipeEntity) else { return 0 }

        // Check if pipe has the correct fluid type
        if originalPipe.fluidType == fluidType {
            let pipe = originalPipe
            let removed = min(amount, pipe.fluidAmount)
            pipe.fluidAmount -= removed
            world.add(pipe, to: pipeEntity)
            return removed
        }
        return 0
    }

    /// Add fluid to a pipe
    private func addFluidToPipe(_ pipeEntity: Entity, amount: Float, fluidType: FluidType) -> Float {
        guard let originalPipe = world.get(PipeComponent.self, for: pipeEntity) else { return 0 }

        // If pipe is empty or has the same fluid type, add fluid
        if originalPipe.fluidType == nil || originalPipe.fluidType == fluidType {
            let pipe = originalPipe
            let space = pipe.maxCapacity - pipe.fluidAmount
            let added = min(amount, space)
            pipe.fluidAmount += added
            pipe.fluidType = fluidType  // Set fluid type if it was empty
            world.add(pipe, to: pipeEntity)
            return added
        }
        return 0  // Cannot add different fluid type to pipe
    }

    /// Remove fluid from a tank
    private func removeFluidFromTank(_ tankEntity: Entity, amount: Float, fluidType: FluidType) -> Float {
        guard let originalTank = world.get(FluidTankComponent.self, for: tankEntity) else { return 0 }

        for i in 0..<originalTank.tanks.count {
            if originalTank.tanks[i].type == fluidType {
                let tank = originalTank
                let removed = tank.tanks[i].remove(amount: amount)
                world.add(tank, to: tankEntity)
                return removed
            }
        }
        return 0
    }

    /// Add fluid to a tank
    private func addFluidToTank(_ tankEntity: Entity, amount: Float, fluidType: FluidType) -> Float {
        guard let originalTank = world.get(FluidTankComponent.self, for: tankEntity) else { return 0 }

        // Find existing stack or create new one
        for i in 0..<originalTank.tanks.count {
            if originalTank.tanks[i].type == fluidType {
                let tank = originalTank
                let added = tank.tanks[i].add(amount: amount)
                world.add(tank, to: tankEntity)
                return added
            }
        }

        // Create new stack if possible
        let tank = originalTank
        var newStack = FluidStack(type: fluidType, amount: 0, maxAmount: tank.maxCapacity)
        let added = newStack.add(amount: amount)
        tank.tanks.append(newStack)
        world.add(tank, to: tankEntity)
        return added
    }

    /// Handle direct transfers from producers to consumers (bypassing pipe network)
    private func handleDirectTransfers(in network: FluidNetwork, deltaTime: Float) {
        // For now, producers and consumers handle their own transfers through the existing logic
        // This could be enhanced to allow direct producer->consumer transfers when they're connected
    }

    /// Calculate overall network pressure
    private func calculateNetworkPressure(network: FluidNetwork, pressureMap: [Entity: Float]) -> Float {
        if pressureMap.isEmpty { return 0 }

        let totalPressure = pressureMap.values.reduce(0, +)
        return totalPressure / Float(pressureMap.count)
    }


    // MARK: - Public Interface

    /// Gets the network for a given network ID
    func getNetwork(_ networkId: Int) -> FluidNetwork? {
        return networks[networkId]
    }

    /// Gets all networks
    func getAllNetworks() -> [FluidNetwork] {
        return Array(networks.values)
    }

    /// Gets the network ID for an entity
    func getNetworkId(for entity: Entity) -> Int? {
        return getEntityNetworkId(entity)
    }

    /// Forces a complete network rebuild
    func rebuildNetworks() {
        // Mark all fluid entities as dirty
        let fluidEntities = findAllFluidEntities()
        dirtyEntities.formUnion(fluidEntities)
    }

    /// Get performance statistics for monitoring
    func getPerformanceStats() -> [String: Any] {
        let totalEntities = networks.values.reduce(0) { $0 + $1.pipes.count + $1.producers.count + $1.consumers.count + $1.tanks.count }
        let totalNetworks = networks.count
        let avgNetworkSize = totalNetworks > 0 ? Double(totalEntities) / Double(totalNetworks) : 0

        let largeNetworks = networks.values.filter { network in
            network.pipes.count + network.producers.count + network.consumers.count + network.tanks.count > 50
        }.count

        return [
            "total_entities": totalEntities,
            "total_networks": totalNetworks,
            "avg_network_size": avgNetworkSize,
            "large_networks": largeNetworks,
            "max_network_size": maxNetworkSize,
            "cache_size_positions": entityPositions.count,
            "cache_size_connections": entityConnections.count,
            "dirty_entities": dirtyEntities.count,
            "dirty_networks": dirtyNetworks.count
        ]
    }
}
