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
    private let buildingRegistry: BuildingRegistry

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

    init(world: World, buildingRegistry: BuildingRegistry) {
        self.world = world
        self.buildingRegistry = buildingRegistry
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
            // Also periodically mark all fluid consumers as dirty to update consumption
            // This ensures boilers start consuming when fuel is added
            for network in networks.values {
                for consumerEntity in network.consumers {
                    if let consumer = world.get(FluidConsumerComponent.self, for: consumerEntity),
                       consumer.buildingId == "boiler" {
                        // Mark boilers as dirty periodically to check fuel status
                        markEntityDirty(consumerEntity)
                    }
                }
            }
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

    /// Resets all internal state (used when loading saved games)
    func reset() {
        networks.removeAll()
        nextNetworkId = 1
        dirtyEntities.removeAll()
        dirtyNetworks.removeAll()
        entityPositions.removeAll()
        entityConnections.removeAll()
        networksByPosition.removeAll()
    }

    /// Updates networks based on dirty entities
    private func updateNetworks() {
        // Track entities already processed in this call to prevent infinite loops
        var processedEntities = Set<Entity>()

        while !dirtyEntities.isEmpty {
            let entitiesToProcess = Array(dirtyEntities)
            dirtyEntities.removeAll()

            print("FluidNetworkSystem: Processing \(entitiesToProcess.count) dirty entities")

            // If we have no networks yet, do a full rebuild
            if networks.isEmpty && !entitiesToProcess.isEmpty {
                print("FluidNetworkSystem: Rebuilding all networks")
                rebuildAllNetworks()
                return
            }

            // Process each dirty entity (skip if already processed)
            for entity in entitiesToProcess {
                if processedEntities.contains(entity) {
                    print("FluidNetworkSystem: Skipping already processed entity \(entity.id)")
                    continue
                }

                processedEntities.insert(entity)

                if world.isAlive(entity) {
                    print("FluidNetworkSystem: Entity \(entity.id) is alive, handling as addition")
                    // Entity was added or modified
                    handleEntityAdded(entity)
                } else {
                    print("FluidNetworkSystem: Entity \(entity.id) is dead, handling as removal")
                    // Entity was removed
                    handleEntityRemoved(entity)
                }
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
        print("handleEntityRemoved: Removing entity \(entity.id)")

        // Remove connections from all fluid entities to this entity
        removeConnectionsTo(entity)

        // Re-establish connections for ALL fluid entities to recalculate their connection lists
        // This is necessary because connection storage might not be symmetric
        print("handleEntityRemoved: Re-establishing connections for all fluid entities")
        for fluidEntity in world.entities {
            if isFluidEntity(fluidEntity) && world.isAlive(fluidEntity) && fluidEntity != entity {
                establishConnections(for: fluidEntity)
            }
        }

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
        // Since connection storage might not be symmetric, scan ALL fluid entities
        // and remove the target entity from their connections
        for entity in world.entities {
            if isFluidEntity(entity) && world.isAlive(entity) {
                removeConnection(from: entity, to: targetEntity)
            }
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
        print("establishConnections: Starting for entity \(entity.id)")

        // Get position of the entity
        guard let position = world.get(PositionComponent.self, for: entity)?.tilePosition else {
            print("establishConnections: No position for entity \(entity.id)")
            return
        }

        print("establishConnections: Entity at position \(position)")

        // Get building size to handle multi-tile buildings
        let buildingSize = getBuildingSize(for: entity)
        print("establishConnections: Building size \(buildingSize)")

        // Collect all positions to check adjacent to (for multi-tile buildings)
        var positionsToCheckAdjacentTo = [position]

        // For multi-tile buildings, check adjacent to all occupied tiles
        if buildingSize.width > 1 || buildingSize.height > 1 {
            for x in 0..<buildingSize.width {
                for y in 0..<buildingSize.height {
                    let occupiedPos = position + IntVector2(x: Int32(x), y: Int32(y))
                    positionsToCheckAdjacentTo.append(occupiedPos)
                }
            }
        }

        // Check all adjacent positions around each occupied position
        var adjacentPositions = Set<IntVector2>()
        for checkPos in positionsToCheckAdjacentTo {
            adjacentPositions.insert(checkPos + IntVector2(x: 0, y: 1))   // North
            adjacentPositions.insert(checkPos + IntVector2(x: 1, y: 0))   // East
            adjacentPositions.insert(checkPos + IntVector2(x: 0, y: -1))  // South
            adjacentPositions.insert(checkPos + IntVector2(x: -1, y: 0))  // West
        }

        // Remove positions that are occupied by this entity itself
        adjacentPositions = adjacentPositions.filter { adjPos in
            let entitiesAtPos = world.getAllEntitiesAt(position: adjPos)
            return !entitiesAtPos.contains(entity)
        }

        let adjacentPositionsList = Array(adjacentPositions)

        var newConnections: [Entity] = []

        print("establishConnections: Checking \(adjacentPositionsList.count) adjacent positions for entity \(entity.id)")
        for adjacentPos in adjacentPositionsList {
            // Find entities at this position - use fallback if spatial query fails
            var entitiesAtPos = world.getAllEntitiesAt(position: adjacentPos)

            // Fallback: if no entities found, manually check all entities (spatial index bug workaround)
            if entitiesAtPos.isEmpty {
                for otherEntity in world.entities {
                    if let pos = world.get(PositionComponent.self, for: otherEntity)?.tilePosition,
                       pos == adjacentPos {
                        entitiesAtPos.append(otherEntity)
                    }
                }
            }

            print("establishConnections: Position \(adjacentPos) has \(entitiesAtPos.count) entities")
            if entitiesAtPos.count > 0 {
                print("establishConnections: Found entities at \(adjacentPos): \(entitiesAtPos.map { "\($0.id)" }.joined(separator: ", "))")
            }
            for adjacentEntity in entitiesAtPos {
                // Check if this entity can connect to our entity
                if canConnect(entity, to: adjacentEntity) {
                    print("establishConnections: Can connect to adjacent entity \(adjacentEntity.id)")
                    newConnections.append(adjacentEntity)
                    // Also add the connection to the adjacent entity
                    addConnection(from: adjacentEntity, to: entity)
                    addConnection(from: entity, to: adjacentEntity)
                    // Mark the adjacent entity as dirty so its connections get updated too
                    markEntityDirty(adjacentEntity)
                } else {
                    print("establishConnections: Cannot connect to adjacent entity \(adjacentEntity.id)")
                }
            }
        }

        // Check what components exist
        let hasPipe = world.has(PipeComponent.self, for: entity)
        let hasProducer = world.has(FluidProducerComponent.self, for: entity)
        let hasConsumer = world.has(FluidConsumerComponent.self, for: entity)
        let hasTank = world.has(FluidTankComponent.self, for: entity)
        let hasPump = world.has(FluidPumpComponent.self, for: entity)
        print("establishConnections: Entity \(entity.id) has components - pipe:\(hasPipe), producer:\(hasProducer), consumer:\(hasConsumer), tank:\(hasTank), pump:\(hasPump)")

        // Update this entity's connections on ALL fluid components
        var updatedComponents = 0
        print("establishConnections: Updating components for entity \(entity.id)")

        if let pipe = world.get(PipeComponent.self, for: entity) {
            print("establishConnections: Found pipe component, setting \(newConnections.count) connections")
            pipe.connections = newConnections
            world.add(pipe, to: entity)
            updatedComponents += 1
        }
        if let producer = world.get(FluidProducerComponent.self, for: entity) {
            print("establishConnections: Found producer component, setting \(newConnections.count) connections")
            producer.connections = newConnections
            world.add(producer, to: entity)
            updatedComponents += 1
        }
        if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
            print("establishConnections: Found consumer component, setting \(newConnections.count) connections")
            consumer.connections = newConnections
            world.add(consumer, to: entity)
            updatedComponents += 1
        }
        if let tank = world.get(FluidTankComponent.self, for: entity) {
            print("establishConnections: Found tank component, setting \(newConnections.count) connections")
            tank.connections = newConnections
            world.add(tank, to: entity)
            updatedComponents += 1
        }
        if let pump = world.get(FluidPumpComponent.self, for: entity) {
            print("establishConnections: Found pump component, setting \(newConnections.count) connections")
            pump.connections = newConnections
            world.add(pump, to: entity)
            updatedComponents += 1
        }

        print("establishConnections: Updated \(updatedComponents) components for entity \(entity.id)")
    }

    /// Gets the building size for multi-tile building connection checking
    private func getBuildingSize(for entity: Entity) -> (width: Int, height: Int) {
        // Try to get building ID from any fluid component
        var buildingId: String?

        if let producer = world.get(FluidProducerComponent.self, for: entity) {
            buildingId = producer.buildingId
        } else if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
            buildingId = consumer.buildingId
        } else if let tank = world.get(FluidTankComponent.self, for: entity) {
            buildingId = tank.buildingId
        } else if let pump = world.get(FluidPumpComponent.self, for: entity) {
            buildingId = pump.buildingId
        }

        if let buildingId = buildingId, let buildingDef = buildingRegistry.get(buildingId) {
            return (width: buildingDef.width, height: buildingDef.height)
        }

        // Default to 1x1 for pipes and other single-tile entities
        return (width: 1, height: 1)
    }

    /// Adds a connection from one entity to another
    private func addConnection(from entity: Entity, to connectedEntity: Entity) {
        print("addConnection: Adding connection from \(entity.id) to \(connectedEntity.id)")
        if world.has(PipeComponent.self, for: entity) {
            if let pipe = world.get(PipeComponent.self, for: entity) {
                if !pipe.connections.contains(connectedEntity) {
                    pipe.connections.append(connectedEntity)
                    world.add(pipe, to: entity)
                    print("addConnection: Added to pipe connections, now has \(pipe.connections.count)")
                } else {
                    print("addConnection: Pipe already connected")
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
        }
        if let producer = world.get(FluidProducerComponent.self, for: entity) {
            return producer.networkId
        }
        if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
            return consumer.networkId
        }
        if let tank = world.get(FluidTankComponent.self, for: entity) {
            return tank.networkId
        }
        if let pump = world.get(FluidPumpComponent.self, for: entity) {
            return pump.networkId
        }
        return nil
    }

    /// Sets the network ID for an entity
    private func setEntityNetworkId(_ entity: Entity, networkId: Int) {
        if let pipe = world.get(PipeComponent.self, for: entity) {
            pipe.networkId = networkId
            world.add(pipe, to: entity)
        }
        if let producer = world.get(FluidProducerComponent.self, for: entity) {
            producer.networkId = networkId
            world.add(producer, to: entity)
        }
        if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
            consumer.networkId = networkId
            world.add(consumer, to: entity)
        }
        if let tank = world.get(FluidTankComponent.self, for: entity) {
            tank.networkId = networkId
            world.add(tank, to: entity)
        }
        if let pump = world.get(FluidPumpComponent.self, for: entity) {
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

    /// Checks if an entity can accept more fluid (for flow simulation)
    private func canAcceptFluid(entity: Entity, fluidType: FluidType?) -> Bool {
        // Allow flow to pipes and tanks, but not to producers/consumers directly
        // Producers inject fluid, consumers consume fluid, flow is between storage entities
        return world.has(PipeComponent.self, for: entity) || world.has(FluidTankComponent.self, for: entity)
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

        print("updateFlowCalculations: Network \(network.id) - Production: \(totalProduction) L/s, Consumption: \(totalConsumption) L/s, Net flow: \(netFlow) L/s")
        print("updateFlowCalculations: Production rates: \(productionRates.map { "\($0.key.id): \($0.value)" }.joined(separator: ", "))")
        print("updateFlowCalculations: Consumption rates: \(consumptionRates.map { "\($0.key.id): \($0.value)" }.joined(separator: ", "))")

        // Step 1.5: Inject produced fluid into the network
        injectProducedFluid(productionRates: productionRates, network: network)

        // Step 1.6: Handle fluid consumption from the network
        consumeFluidFromNetwork(consumptionRates: consumptionRates, network: network)

        // Early exit optimization: if net flow is negligible, skip detailed calculations
        if abs(netFlow) < 0.01 && network.pipes.count > 10 {
            // For large networks with minimal flow, just update capacity
            network.updateCapacity(world)
            return
        }

        // Step 2: Calculate pressure distribution across the network
        let pressureMap = calculatePressureDistribution(in: network, netFlow: netFlow)
        print("updateFlowCalculations: Pressure map for network \(network.id): \(pressureMap.map { "\($0.key.id): \($0.value)" }.joined(separator: ", "))")

        // Step 3: Calculate flow rates between connected components (skip for very small networks)
        let flowRates: [EntityPair: Float]
        if network.pipes.count > 1 {
            flowRates = calculateFlowRates(in: network, pressureMap: pressureMap, deltaTime: deltaTime)
            print("FluidNetworkSystem: Calculated \(flowRates.count) flow rates for network \(network.id)")
        } else {
            flowRates = [:]  // No flow calculations needed for single-pipe networks
            print("FluidNetworkSystem: Skipping flow calculation for small network \(network.id) with \(network.pipes.count) pipes")
        }

        // Step 4: Apply fluid transfers based on calculated flow rates
        if !flowRates.isEmpty {
            print("FluidNetworkSystem: Applying \(flowRates.count) fluid transfers for network \(network.id)")
            applyFluidTransfers(in: network, flowRates: flowRates, deltaTime: deltaTime)
        } else {
            print("FluidNetworkSystem: No flow rates to apply for network \(network.id)")
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
                    if var inventory = world.get(InventoryComponent.self, for: producerEntity),
                       let tank = world.get(FluidTankComponent.self, for: producerEntity) {

                        let hasFuel = inventory.slots.contains { $0 != nil } // Check if any fuel slot has fuel
                        let hasWater = tank.tanks.contains { $0.type == .water && $0.amount > 0.1 } // Need minimum water

                        if hasFuel && hasWater {
                            productionThisTick = producer.productionRate * deltaTime
                            // Consume water at the same rate as steam production
                            let waterConsumed = productionThisTick
                            _ = removeFluidFromTank(producerEntity, amount: waterConsumed, fluidType: .water)

                            // Consume fuel (simplified - consume 1 fuel per second of operation)
                            // In a real implementation, this would check fuel energy values
                            for i in 0..<inventory.slots.count {
                                if inventory.slots[i] != nil {
                                    // Consume one unit of fuel
                                    var updatedStack = inventory.slots[i]!
                                    updatedStack.count -= 1
                                    if updatedStack.count <= 0 {
                                        inventory.slots[i] = nil
                                    } else {
                                        inventory.slots[i] = updatedStack
                                    }
                                    break // Only consume from one slot per tick
                                }
                            }
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
                    updatedProducer.isActive = true
                    world.add(updatedProducer, to: producerEntity)
                    
                    // For boilers, add steam to the tank and inject into pipes
                    if producer.buildingId == "boiler" {
                        _ = addFluidToEntity(producerEntity, amount: productionThisTick, fluidType: .steam)
                        injectProducedFluid(productionRates: [producerEntity: productionThisTick], network: network)
                    }
                    
                } else {
                    // Not producing - mark as inactive
                    let updatedProducer = producer
                    updatedProducer.currentProduction = 0
                    updatedProducer.isActive = false
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
                // Boilers don't need power (they use fuel), steam engines produce power (don't consume it)
                let powerSatisfaction = world.get(PowerConsumerComponent.self, for: consumerEntity)?.satisfaction ?? 1.0
                let hasPower = consumer.buildingId == "boiler" || consumer.buildingId == "steam-engine" || powerSatisfaction > 0.5

                print("calculateConsumptionRates: Consumer \(consumerEntity.id) (\(consumer.buildingId)) hasPower: \(hasPower)")

                if hasPower {
                    // Special handling for boilers - need fuel to consume water
                    var canConsume = true
                    var skipInputCheck = false

                    if consumer.buildingId == "boiler" {
                        print("calculateConsumptionRates: Processing boiler \(consumerEntity.id)")
                        // Check if boiler has fuel
                        if let inventory = world.get(InventoryComponent.self, for: consumerEntity) {
                            let hasFuel = inventory.slots.contains { $0 != nil }
                            canConsume = hasFuel
                            print("calculateConsumptionRates: Boiler \(consumerEntity.id) hasFuel: \(hasFuel), skipInputCheck will be set to: \(hasFuel)")
                            // For boilers with fuel, allow consumption even without current fluid (to start flow)
                            if hasFuel {
                                skipInputCheck = true
                                print("calculateConsumptionRates: Boiler \(consumerEntity.id) skipInputCheck set to true")
                            }
                        } else {
                            canConsume = false
                            print("calculateConsumptionRates: Boiler \(consumerEntity.id) no inventory component")
                        }
                    } else {
                        print("calculateConsumptionRates: Consumer \(consumerEntity.id) buildingId '\(consumer.buildingId)' is not 'boiler'")
                    }

                    if canConsume {
                        // Check if consumer has input available (skip for boilers with fuel)
                        print("calculateConsumptionRates: Consumer \(consumerEntity.id) skipInputCheck: \(skipInputCheck)")
                        let hasInput = skipInputCheck || hasInputAvailable(consumerEntity: consumerEntity, network: network)
                        print("calculateConsumptionRates: Consumer \(consumerEntity.id) hasInput: \(hasInput) (skipCheck: \(skipInputCheck))")
                        if hasInput {
                            let consumptionThisTick = consumer.consumptionRate * deltaTime * powerSatisfaction
                            consumptionRates[consumerEntity] = consumptionThisTick
                            print("calculateConsumptionRates: Consumer \(consumerEntity.id) consuming \(consumptionThisTick) L/s")

                            let updatedConsumer = consumer
                            updatedConsumer.currentConsumption = consumptionThisTick
                            world.add(updatedConsumer, to: consumerEntity)
                        } else {
                            print("calculateConsumptionRates: Consumer \(consumerEntity.id) no input available")
                        }
                    } else {
                        print("calculateConsumptionRates: Consumer \(consumerEntity.id) cannot consume (fuel/water requirements not met)")
                    }
                } else {
                    print("calculateConsumptionRates: Consumer \(consumerEntity.id) no power")
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
            print("hasInputAvailable: Consumer \(consumerEntity.id) needs \(String(describing: consumer.inputType)), has \(consumer.connections.count) connections")
            for connectedEntity in consumer.connections {
                if let pipe = world.get(PipeComponent.self, for: connectedEntity) {
                    // Check if pipe has the required fluid type and amount
                    let minAmount: Float = (consumer.buildingId == "boiler") ? 0.001 : 0.01
                    print("hasInputAvailable: Pipe \(connectedEntity.id) has \(String(describing: pipe.fluidType)) \(pipe.fluidAmount)L, needs \(String(describing: consumer.inputType)) > \(minAmount)L")
                    if (pipe.fluidType == consumer.inputType || consumer.inputType == .steam) && pipe.fluidAmount > minAmount { // Minimum amount
                        return true
                    }
                } else if let tank = world.get(FluidTankComponent.self, for: connectedEntity) {
                    // Check if tank has the required fluid
                    for tankStack in tank.tanks {
                        print("hasInputAvailable: Tank \(connectedEntity.id) has \(tankStack.type) \(tankStack.amount)L")
                        if tankStack.type == consumer.inputType && tankStack.amount > 0.01 as Float {
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
            // Start with base pressure from fill levels
            for pipeEntity in network.pipes {
                if let pipe = world.get(PipeComponent.self, for: pipeEntity) {
                    let fillRatio = pipe.maxCapacity > 0 ? pipe.fluidAmount / pipe.maxCapacity : 0
                    // Overfilled pipes have exponentially higher pressure
                    let pressureMultiplier = fillRatio > 1.0 ? 50.0 + (fillRatio - 1.0) * 200.0 : 50.0
                    pressureMap[pipeEntity] = fillRatio * pressureMultiplier
                }
            }

            for tankEntity in network.tanks {
                if let tank = world.get(FluidTankComponent.self, for: tankEntity) {
                    let totalFluid = tank.tanks.reduce(0) { $0 + $1.amount }
                    let fillRatio = tank.maxCapacity > 0 ? totalFluid / tank.maxCapacity : 0
                    pressureMap[tankEntity] = fillRatio * 100.0
                }
            }

            // Set high pressure at producers, low pressure at consumers
            for producerEntity in network.producers {
                pressureMap[producerEntity] = 100.0  // High pressure source
            }

            for consumerEntity in network.consumers {
                pressureMap[consumerEntity] = 0.0  // Low pressure sink
            }

            // Propagate pressure through the network using iterative relaxation
            let iterations = 5  // Number of relaxation iterations
            for _ in 0..<iterations {
                var newPressures = pressureMap

                // For each pipe, average pressure with connected neighbors
                for pipeEntity in network.pipes {
                    guard let currentPressure = pressureMap[pipeEntity] else { continue }

                    var neighborPressures: [Float] = []
                    let connections = getEntityConnections(pipeEntity)

                    for connectedEntity in connections {
                        if let neighborPressure = pressureMap[connectedEntity] {
                            neighborPressures.append(neighborPressure)
                        }
                    }

                    if !neighborPressures.isEmpty {
                        let avgNeighborPressure = neighborPressures.reduce(0, +) / Float(neighborPressures.count)
                        // Blend current pressure with neighbor average (relaxation factor)
                        newPressures[pipeEntity] = currentPressure * 0.7 + avgNeighborPressure * 0.3
                    }
                }

                pressureMap = newPressures
            }

            // Add network-wide pressure adjustment
            let networkPressureAdjustment = netFlow * 2.0
            for (entity, pressure) in pressureMap {
                pressureMap[entity] = pressure + networkPressureAdjustment
            }
        }

        return pressureMap
    }

    /// Calculate flow rates between connected components based on pressure gradients
    private func calculateFlowRates(in network: FluidNetwork, pressureMap: [Entity: Float], deltaTime: Float) -> [EntityPair: Float] {
        var flowRates: [EntityPair: Float] = [:]

        print("calculateFlowRates: Network \(network.id) has \(network.pipes.count) pipes, pressureMap has \(pressureMap.count) entries")

        // Check all pipes and their connections
        for pipeEntity in network.pipes {
            guard let pipe = world.get(PipeComponent.self, for: pipeEntity),
                  let pipePressure = pressureMap[pipeEntity] else {
                print("calculateFlowRates: Pipe \(pipeEntity.id) missing pressure or component")
                continue
            }

            print("calculateFlowRates: Pipe \(pipeEntity.id) has pressure \(pipePressure) and \(pipe.connections.count) connections")

            for connectedEntity in pipe.connections {
                // Skip connections to producers - they inject fluid separately
                if network.producers.contains(connectedEntity) {
                    continue
                }
                // Allow connections to consumers - flow can transfer fluid to them

                guard let connectedPressure = pressureMap[connectedEntity] else {
                    print("calculateFlowRates: Connected entity \(connectedEntity.id) missing pressure")
                    continue
                }

                // Calculate pressure gradient
                let pressureDiff = pipePressure - connectedPressure

                print("calculateFlowRates: Pressure diff between \(pipeEntity.id) and \(connectedEntity.id): \(pressureDiff)")

                // Only flow if there's a significant pressure difference
                if abs(pressureDiff) > 0.1 {
                    // Calculate flow rate based on pressure difference and pipe properties
                    let baseFlowRate = pressureDiff * 2.0 // Pressure difference drives flow

                    // Apply fluid viscosity effects (higher viscosity = slower flow)
                    var viscosityMultiplier: Float = 1.0
                    if let fluidType = pipe.fluidType {
                        viscosityMultiplier = 1.0 / FluidProperties.getProperties(for: fluidType).viscosity
                    }

                    // Apply pipe capacity limits
                    let maxFlowRate = pipe.maxCapacity * 2.0 // Max 200% of capacity per second for fast flow

                    let flowRate = min(abs(baseFlowRate) * viscosityMultiplier, maxFlowRate)
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
        // First, reset all pipe flow rates to 0
        for pipeEntity in network.pipes {
            if let pipe = world.get(PipeComponent.self, for: pipeEntity) {
                let updatedPipe = pipe
                updatedPipe.flowRate = 0
                world.add(updatedPipe, to: pipeEntity)
            }
        }

        // Calculate net flow rates for each pipe
        var netFlowRates: [Entity: Float] = [:]
        for (entityPair, flowRate) in flowRates {
            let transferRate = abs(flowRate)
            let fromEntity = entityPair.from
            let toEntity = entityPair.to

            // From entity loses fluid, to entity gains fluid
            netFlowRates[fromEntity, default: 0] -= transferRate
            netFlowRates[toEntity, default: 0] += transferRate
        }

        // Apply net flow rates to pipes
        for (pipeEntity, netFlowRate) in netFlowRates {
            if let pipe = world.get(PipeComponent.self, for: pipeEntity) {
                let updatedPipe = pipe
                updatedPipe.flowRate = netFlowRate
                world.add(updatedPipe, to: pipeEntity)
                print("FluidNetworkSystem: Set net flow rate \(netFlowRate) L/s on pipe \(pipeEntity.id)")
            }
        }

        // Now apply the actual fluid transfers
        for (entityPair, flowRate) in flowRates {
            let transferAmount = abs(flowRate) * deltaTime  // Convert flow rate to transfer amount

            // Determine transfer direction based on flow rate sign
            let (fromEntity, toEntity) = if flowRate > 0 {
                // Positive flow: from pipe to connected (pipe has higher pressure)
                (entityPair.from, entityPair.to)
            } else {
                // Negative flow: from connected to pipe (connected has higher pressure)
                (entityPair.to, entityPair.from)
            }

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

        print("FluidNetworkSystem: Transferred \(removedAmount) L \(fluidType) from \(fromEntity.id) to \(toEntity.id)")

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

    /// Remove fluid from a pipe (special version for boilers that ignores fluid type)
    private func removeFluidFromPipeIgnoringType(_ pipeEntity: Entity, amount: Float, requiredType: FluidType) -> Float {
        guard let originalPipe = world.get(PipeComponent.self, for: pipeEntity) else { return 0 }

        // For boilers, allow consuming water even if pipe contains steam
        let removed = min(amount, originalPipe.fluidAmount)
        if removed > 0 {
            let pipe = originalPipe
            pipe.fluidAmount -= removed
            // If pipe becomes empty, clear the fluid type
            if pipe.fluidAmount <= 0 {
                pipe.fluidType = nil
            }
            world.add(pipe, to: pipeEntity)
            print("FluidNetworkSystem: Removed \(removed) L \(requiredType) from pipe \(pipeEntity.id) (ignoring type), now has \(pipe.fluidAmount)L")
            return removed
        }
        return 0
    }

    /// Remove fluid from a pipe
    private func removeFluidFromPipe(_ pipeEntity: Entity, amount: Float, fluidType: FluidType) -> Float {
        guard let originalPipe = world.get(PipeComponent.self, for: pipeEntity) else { return 0 }

        // Check if pipe has the correct fluid type (ignore for steam since pipes may have mixed fluids)
        if originalPipe.fluidType == fluidType || fluidType == .steam {
            let pipe = originalPipe
            let removed = min(amount, pipe.fluidAmount)
            pipe.fluidAmount -= removed
            // If pipe becomes empty, clear the fluid type
            if pipe.fluidAmount <= 0 {
                pipe.fluidType = nil
            }
            world.add(pipe, to: pipeEntity)
            print("FluidNetworkSystem: Removed \(removed) L \(fluidType) from pipe \(pipeEntity.id), now has \(pipe.fluidAmount)L")
            return removed
        }
        return 0
    }

    /// Add fluid to a pipe
    private func addFluidToPipe(_ pipeEntity: Entity, amount: Float, fluidType: FluidType) -> Float {
        guard let originalPipe = world.get(PipeComponent.self, for: pipeEntity) else { return 0 }

        // Pipes can accept any fluid type if they have space (fluids can mix/displace)
        let maxAllowed = originalPipe.maxCapacity * 1.5
        let hasSpace = originalPipe.fluidAmount < maxAllowed

        if hasSpace {
            let updatedPipe = originalPipe
            // Allow some overfill to simulate pressurization (up to 150% capacity)
            let maxAllowed = updatedPipe.maxCapacity * 1.5
            let space = maxAllowed - updatedPipe.fluidAmount
            let added = min(amount, space)
            updatedPipe.fluidAmount += added

            // Set fluid type to the new fluid (injection can change fluid type)
            updatedPipe.fluidType = fluidType

            world.add(updatedPipe, to: pipeEntity)
            print("FluidNetworkSystem: Added \(added) L \(fluidType) to pipe \(pipeEntity.id), now has \(updatedPipe.fluidAmount)L / \(updatedPipe.maxCapacity)L")
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
                var stack = tank.tanks[i]
                let space = stack.maxAmount - stack.amount
                let added = min(amount, space)
                stack.amount += added
                tank.tanks[i] = stack
                world.add(tank, to: tankEntity)
                return added
            }
        }

        // Create new stack if possible
        let tank = originalTank
        let added = min(amount, tank.maxCapacity)
        let newStack = FluidStack(type: fluidType, amount: added, maxAmount: tank.maxCapacity)
        tank.tanks.append(newStack)
        world.add(tank, to: tankEntity)
        return added
    }

    /// Inject produced fluid into the network from producers
    private func injectProducedFluid(productionRates: [Entity: Float], network: FluidNetwork) {
        print("FluidNetworkSystem: Injecting produced fluid for \(productionRates.count) producers")
        for (producerEntity, productionAmount) in productionRates {
            guard let producer = world.get(FluidProducerComponent.self, for: producerEntity) else { continue }

            print("FluidNetworkSystem: Producer \(producerEntity.id) producing \(productionAmount) L of \(producer.outputType)")

            // Determine the fluid type being produced
            let fluidType = producer.outputType

            // Try to add fluid to connected pipes first, then tanks
            var remainingAmount = productionAmount

            // First, try connected pipes
            for connectedEntity in producer.connections {
                if remainingAmount <= 0 { break }
                if world.has(PipeComponent.self, for: connectedEntity) {
                    let added = addFluidToEntity(connectedEntity, amount: remainingAmount, fluidType: fluidType)
                    remainingAmount -= added
                    print("FluidNetworkSystem: Added \(added) L to pipe \(connectedEntity.id), remaining: \(remainingAmount)")
                }
            }

            // Then try connected tanks
            for connectedEntity in producer.connections {
                if remainingAmount <= 0 { break }
                if world.has(FluidTankComponent.self, for: connectedEntity) {
                    let added = addFluidToEntity(connectedEntity, amount: remainingAmount, fluidType: fluidType)
                    remainingAmount -= added
                    print("FluidNetworkSystem: Added \(added) L to tank \(connectedEntity.id), remaining: \(remainingAmount)")
                }
            }

            // If still fluid left and producer has a tank, add to own tank
            if remainingAmount > 0 {
                let added = addFluidToEntity(producerEntity, amount: remainingAmount, fluidType: fluidType)
                print("FluidNetworkSystem: Added \(added) L to producer's own tank, final remaining: \(remainingAmount - added)")
            }
        }
    }

    /// Consume fluid from the network for consumers
    private func consumeFluidFromNetwork(consumptionRates: [Entity: Float], network: FluidNetwork) {
        print("FluidNetworkSystem: Consuming fluid for \(consumptionRates.count) consumers in network \(network.id)")
        for (consumerEntity, consumptionAmount) in consumptionRates {
            guard let consumer = world.get(FluidConsumerComponent.self, for: consumerEntity) else { continue }

            print("FluidNetworkSystem: Consumer \(consumerEntity.id) consuming \(consumptionAmount) L of \(String(describing: consumer.inputType))")

            // Determine the fluid type being consumed
            let fluidType = consumer.inputType

            // Try to consume fluid from connected pipes first, then tanks
            var remainingAmount = consumptionAmount

            // Special handling for boilers - water goes to tank instead of being consumed
            if consumer.buildingId == "boiler" && fluidType == .water {
                // For boilers, consume water into internal tank
                var addedToTank = 0.0

                // First, try connected pipes
                for connectedEntity in consumer.connections {
                    if remainingAmount <= 0 { break }
                    if world.has(PipeComponent.self, for: connectedEntity) {
                        let removed = removeFluidFromPipeIgnoringType(connectedEntity, amount: remainingAmount, requiredType: fluidType!)
                        if removed > 0 {
                            // Add to boiler's tank instead of consuming
                            let added = addFluidToEntity(consumerEntity, amount: removed, fluidType: fluidType!)
                            addedToTank += Double(added)
                            remainingAmount -= removed
                            print("FluidNetworkSystem: Moved \(removed) L water from pipe \(connectedEntity.id) to boiler tank \(consumerEntity.id)")
                        }
                    }
                }

                // Then try connected tanks
                for connectedEntity in consumer.connections {
                    if remainingAmount <= 0 { break }
                    if world.has(FluidTankComponent.self, for: connectedEntity) {
                        let removed = removeFluidFromEntity(connectedEntity, amount: remainingAmount, fluidType: fluidType!)
                        if removed > 0 {
                            // Add to boiler's tank
                            let added = addFluidToEntity(consumerEntity, amount: removed, fluidType: fluidType!)
                            addedToTank += Double(added)
                            remainingAmount -= removed
                            print("FluidNetworkSystem: Moved \(removed) L water from tank \(connectedEntity.id) to boiler tank \(consumerEntity.id)")
                        }
                    }
                }

                print("FluidNetworkSystem: Boiler \(consumerEntity.id) consumed \(addedToTank) L water into tank")
            } else {
                // Normal consumption - remove from network
                // First, try connected pipes
                for connectedEntity in consumer.connections {
                    if remainingAmount <= 0 { break }
                    if world.has(PipeComponent.self, for: connectedEntity) {
                        let removed = removeFluidFromEntity(connectedEntity, amount: remainingAmount, fluidType: fluidType!)
                        remainingAmount -= removed
                        print("FluidNetworkSystem: Removed \(removed) L from pipe \(connectedEntity.id), remaining: \(remainingAmount)")
                    }
                }

                // Then try connected tanks
                for connectedEntity in consumer.connections {
                    if remainingAmount <= 0 { break }
                    if world.has(FluidTankComponent.self, for: connectedEntity) {
                        let removed = removeFluidFromEntity(connectedEntity, amount: remainingAmount, fluidType: fluidType!)
                        remainingAmount -= removed
                        print("FluidNetworkSystem: Removed \(removed) L from tank \(connectedEntity.id), remaining: \(remainingAmount)")
                    }
                }

                // If still need fluid and consumer has a tank, consume from own tank
                if remainingAmount > 0 {
                    let removed = removeFluidFromEntity(consumerEntity, amount: remainingAmount, fluidType: fluidType!)
                    print("FluidNetworkSystem: Removed \(removed) L from consumer's own tank, final remaining: \(remainingAmount - removed)")
                }
            }
        }
    }

    /// Handle direct transfers from producers to consumers (bypassing pipe network)
    private func handleDirectTransfers(in network: FluidNetwork, deltaTime: Float) {
        // For now, producers and consumers handle their own transfers through the existing logic
        // This could be enhanced to allow direct producer->consumer transfers when they're connected
    }

    /// Get all connections for an entity
    private func getEntityConnections(_ entity: Entity) -> [Entity] {
        var connections: [Entity] = []

        if let pipe = world.get(PipeComponent.self, for: entity) {
            connections.append(contentsOf: pipe.connections)
        }
        if let producer = world.get(FluidProducerComponent.self, for: entity) {
            connections.append(contentsOf: producer.connections)
        }
        if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
            connections.append(contentsOf: consumer.connections)
        }
        if let tank = world.get(FluidTankComponent.self, for: entity) {
            connections.append(contentsOf: tank.connections)
        }
        if let pump = world.get(FluidPumpComponent.self, for: entity) {
            connections.append(contentsOf: pump.connections)
        }

        return connections
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
