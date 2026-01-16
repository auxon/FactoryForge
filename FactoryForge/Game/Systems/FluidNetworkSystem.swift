import Foundation
import QuartzCore

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
    private let itemRegistry: ItemRegistry

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
    private var boilerUpdateAccumulator: Float = 0
    private let boilerUpdateInterval: Float = 0.1  // 10 Hz for boiler networks
    private var flowUpdateCursorByNetwork: [Int: Int] = [:]
    private let maxPipesPerFlowUpdate: Int = 64


    init(world: World, buildingRegistry: BuildingRegistry, itemRegistry: ItemRegistry) {
        self.world = world
        self.buildingRegistry = buildingRegistry
        self.itemRegistry = itemRegistry
    }

    func update(deltaTime: Float) {
        updateCounter += 1

        #if DEBUG
        let updateStart = CACurrentMediaTime()
        var updateTimings: [String: Double] = [:]
        #endif

        // Process dirty entities (pipes/buildings that were added/removed/modified)
        if !dirtyEntities.isEmpty {
            #if DEBUG
            let start = CACurrentMediaTime()
            #endif
            updateNetworks()
            #if DEBUG
            updateTimings["updateNetworks"] = CACurrentMediaTime() - start
            #endif
            dirtyEntities.removeAll()
        }

        // Special case: Process networks containing boilers on a short interval
        // This keeps boiler consumption responsive without heavy per-frame cost.
        boilerUpdateAccumulator += deltaTime
        if boilerUpdateAccumulator >= boilerUpdateInterval {
            let accumulatedDelta = boilerUpdateAccumulator
            boilerUpdateAccumulator = 0
            let boilerNetworks = getNetworksWithBoilers()
            if !boilerNetworks.isEmpty {
                #if DEBUG
                let start = CACurrentMediaTime()
                #endif
                updateFlowCalculations(for: boilerNetworks, deltaTime: accumulatedDelta)
                #if DEBUG
                updateTimings["boilerFlow"] = CACurrentMediaTime() - start
                #endif
            }
        }

        // Process dirty networks (need flow recalculation)
        // For performance, only update flow calculations every few frames for large networks

        if !dirtyNetworks.isEmpty {
            #if DEBUG
            let start = CACurrentMediaTime()
            #endif
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
            #if DEBUG
            updateTimings["dirtyFlow"] = CACurrentMediaTime() - start
            #endif
        }

        // Periodic cleanup and optimization
        if updateCounter % 240 == 0 {  // Every ~4 seconds at 60 FPS
            #if DEBUG
            let start = CACurrentMediaTime()
            #endif
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
            #if DEBUG
            updateTimings["periodic"] = CACurrentMediaTime() - start
            #endif
        }
        #if DEBUG
        let totalElapsed = CACurrentMediaTime() - updateStart
        if totalElapsed >= 0.025 {
            let details = updateTimings
                .map { "\($0.key)=\(String(format: "%.2f", $0.value * 1000))ms" }
                .sorted()
                .joined(separator: ", ")
            print("FluidNetworkSystem: update \(String(format: "%.2f", totalElapsed * 1000))ms | \(details)")
        }
        #endif
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


            // If we have no networks yet, do a full rebuild
            if networks.isEmpty && !entitiesToProcess.isEmpty {
                rebuildAllNetworks()
                return
            }

            // Process each dirty entity (skip if already processed)
            for entity in entitiesToProcess {
                if processedEntities.contains(entity) {
                    continue
                }

                processedEntities.insert(entity)

                if world.isAlive(entity) {
                    // Entity was added or modified
                    handleEntityAdded(entity)
                } else {
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

        // Remove connections from all fluid entities to this entity
        removeConnectionsTo(entity)

        // Re-establish connections for ALL fluid entities to recalculate their connection lists
        // This is necessary because connection storage might not be symmetric
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
        // print("establishConnections: Starting for entity \(entity.id)")

        // Get position of the entity
        guard let position = world.get(PositionComponent.self, for: entity)?.tilePosition else {
            // print("establishConnections: No position for entity \(entity.id)")
            return
        }

        // print("establishConnections: Entity at position \(position)")

        // Get building size to handle multi-tile buildings
        let buildingSize = getBuildingSize(for: entity)
        // print("establishConnections: Building size \(buildingSize)")

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

        // print("establishConnections: Checking \(adjacentPositionsList.count) adjacent positions for entity \(entity.id)")
        for adjacentPos in adjacentPositionsList {
            // Calculate which direction this adjacent position represents
            let directionOffset = adjacentPos - position
            _ = directionFromOffset(directionOffset)

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

            // print("establishConnections: Position \(adjacentPos) has \(entitiesAtPos.count) entities")
            if entitiesAtPos.count > 0 {
                // print("establishConnections: Found entities at \(adjacentPos): \(entitiesAtPos.map { "\($0.id)" }.joined(separator: ", "))")
            }
            for adjacentEntity in entitiesAtPos {
                // Check if this entity can connect to our entity
                if canConnect(entity, to: adjacentEntity) {
                    // print("establishConnections: Can connect to adjacent entity \(adjacentEntity.id)")
                    newConnections.append(adjacentEntity)
                    // Also add the connection to the adjacent entity
                    addConnection(from: adjacentEntity, to: entity)
                    addConnection(from: entity, to: adjacentEntity)
                } else {
                    // print("establishConnections: Cannot connect to adjacent entity \(adjacentEntity.id)")
                }
            }
        }

        // Check what components exist (not used in current logic, but kept for future debugging)

        // Update this entity's connections on ALL fluid components
        var updatedComponents = 0

        if let pipe = world.get(PipeComponent.self, for: entity) {
            pipe.connections = newConnections
            world.add(pipe, to: entity)
            updatedComponents += 1
        }
        if let producer = world.get(FluidProducerComponent.self, for: entity) {
            producer.connections = newConnections
            world.add(producer, to: entity)
            updatedComponents += 1
        }
        if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
            consumer.connections = newConnections
            world.add(consumer, to: entity)
            updatedComponents += 1
        }
        if let tank = world.get(FluidTankComponent.self, for: entity) {
            tank.connections = newConnections
            world.add(tank, to: entity)
            updatedComponents += 1
        }
        if let pump = world.get(FluidPumpComponent.self, for: entity) {
            pump.connections = newConnections
            world.add(pump, to: entity)
            updatedComponents += 1
        }
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
        if let pipe = world.get(PipeComponent.self, for: entity) {
            if !pipe.connections.contains(connectedEntity) {
                pipe.connections.append(connectedEntity)
                world.add(pipe, to: entity)
            }
        }
        if let producer = world.get(FluidProducerComponent.self, for: entity) {
            if !producer.connections.contains(connectedEntity) {
                producer.connections.append(connectedEntity)
                world.add(producer, to: entity)
            }
        }
        if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
            if !consumer.connections.contains(connectedEntity) {
                consumer.connections.append(connectedEntity)
                world.add(consumer, to: entity)
            }
        }
        if let tank = world.get(FluidTankComponent.self, for: entity) {
            if !tank.connections.contains(connectedEntity) {
                tank.connections.append(connectedEntity)
                world.add(tank, to: entity)
            }
        }
        if let pump = world.get(FluidPumpComponent.self, for: entity) {
            if !pump.connections.contains(connectedEntity) {
                pump.connections.append(connectedEntity)
                world.add(pump, to: entity)
            }
        }
    }

    /// Removes a connection between entities
    private func removeConnection(from entity: Entity, to connectedEntity: Entity) {
        if let pipe = world.get(PipeComponent.self, for: entity) {
            pipe.connections.removeAll { $0 == connectedEntity }
            world.add(pipe, to: entity)
        }
        if let producer = world.get(FluidProducerComponent.self, for: entity) {
            producer.connections.removeAll { $0 == connectedEntity }
            world.add(producer, to: entity)
        }
        if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
            consumer.connections.removeAll { $0 == connectedEntity }
            world.add(consumer, to: entity)
        }
        if let tank = world.get(FluidTankComponent.self, for: entity) {
            tank.connections.removeAll { $0 == connectedEntity }
            world.add(tank, to: entity)
        }
        if let pump = world.get(FluidPumpComponent.self, for: entity) {
            pump.connections.removeAll { $0 == connectedEntity }
            world.add(pump, to: entity)
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

        guard let adjacency = adjacencyBetween(entity1, entity2) else {
            return false
        }

        let directionToEntity2 = adjacency.directionFromEntity1
        let directionToEntity1 = adjacency.directionFromEntity2

        // Pipes only connect on allowed sides, and respect manual disconnects
        if let pipe1 = world.get(PipeComponent.self, for: entity1) {
            if pipe1.manuallyDisconnectedDirections.contains(directionToEntity2) {
                return false
            }
            if !pipe1.allowedDirections.contains(directionToEntity2) {
                return false
            }
        }

        if let pipe2 = world.get(PipeComponent.self, for: entity2) {
            if pipe2.manuallyDisconnectedDirections.contains(directionToEntity1) {
                return false
            }
            if !pipe2.allowedDirections.contains(directionToEntity1) {
                return false
            }
        }

        // For building-to-building connections, check if they have compatible interfaces
        // For now, allow connections between any fluid buildings (simplified)
        // TODO: Add direction-based connection rules for specific buildings
        return true
    }

    private func adjacencyBetween(_ entity1: Entity, _ entity2: Entity) -> (directionFromEntity1: Direction, directionFromEntity2: Direction)? {
        let tiles1 = getOccupiedTiles(for: entity1)
        let tiles2 = getOccupiedTiles(for: entity2)
        guard !tiles1.isEmpty && !tiles2.isEmpty else { return nil }

        for tile1 in tiles1 {
            for tile2 in tiles2 {
                let offset = tile2 - tile1
                let isCardinal = (abs(offset.x) + abs(offset.y)) == 1
                if !isCardinal {
                    continue
                }
                let directionToEntity2 = directionFromOffset(offset)
                return (directionToEntity2, directionToEntity2.opposite)
            }
        }

        return nil
    }

    private func getOccupiedTiles(for entity: Entity) -> [IntVector2] {
        guard let position = world.get(PositionComponent.self, for: entity)?.tilePosition else {
            return []
        }

        let size = getBuildingSize(for: entity)
        if size.width == 1 && size.height == 1 {
            return [position]
        }

        var tiles: [IntVector2] = []
        tiles.reserveCapacity(size.width * size.height)
        for x in 0..<size.width {
            for y in 0..<size.height {
                tiles.append(position + IntVector2(x: Int32(x), y: Int32(y)))
            }
        }
        return tiles
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

    /// Calculates fluid flow within a network using advanced pressure simulation
    private func calculateNetworkFlow(_ network: inout FluidNetwork, deltaTime: Float, networkId: Int) {
        #if DEBUG
        let startTime = CACurrentMediaTime()
        #endif

        // Early exit optimization: skip calculation if network has no producers/consumers
        let hasActivity = !network.producers.isEmpty || !network.consumers.isEmpty
        if !hasActivity {
            // No production or consumption, just update basic capacity
            network.updateCapacity(world)
            return
        }

        // Step 1: Calculate consumption volumes first (needed for boiler tank filling)
        #if DEBUG
        let consumptionStart = CACurrentMediaTime()
        #endif
        let consumptionVolumes = calculateConsumptionVolumes(for: network, deltaTime: deltaTime)
        #if DEBUG
        let consumptionElapsed = CACurrentMediaTime() - consumptionStart
        #endif

        // Step 1.5: Handle fluid consumption from the network (fill consumer tanks like boilers)
        #if DEBUG
        let consumeStart = CACurrentMediaTime()
        #endif
        consumeFluidFromNetwork(consumptionVolumes: consumptionVolumes, network: network)
        #if DEBUG
        let consumeElapsed = CACurrentMediaTime() - consumeStart
        #endif

        // Step 2: Calculate production rates (now boilers have water in their tanks)
        #if DEBUG
        let productionStart = CACurrentMediaTime()
        #endif
        let productionRates = calculateProductionRates(for: network, deltaTime: deltaTime)
        #if DEBUG
        let productionElapsed = CACurrentMediaTime() - productionStart
        #endif

        let totalProduction = productionRates.values.reduce(0, +)
        let totalConsumption = consumptionVolumes.values.reduce(0, +)
        let netFlow = totalProduction - totalConsumption


        // Step 1.5: Inject produced fluid into the network
        #if DEBUG
        let injectStart = CACurrentMediaTime()
        #endif
        injectProducedFluid(productionRates: productionRates, network: network)
        #if DEBUG
        let injectElapsed = CACurrentMediaTime() - injectStart
        #endif

        // Early exit optimization: if net flow is negligible, skip detailed calculations
        if abs(netFlow) < 0.01 && network.pipes.count > 10 {
            // For large networks with minimal flow, just update capacity
            network.updateCapacity(world)
            return
        }

        // Step 2: Calculate pressure distribution across the network
        #if DEBUG
        let pressureStart = CACurrentMediaTime()
        #endif
        let pressureMap = calculatePressureDistribution(in: network, netFlow: netFlow)
        #if DEBUG
        let pressureElapsed = CACurrentMediaTime() - pressureStart
        #endif

        // Step 3: Calculate flow rates between connected components (skip for very small networks)
        let flowRates: [EntityPair: Float]
        #if DEBUG
        let flowStart = CACurrentMediaTime()
        #endif
        if network.pipes.count > 1 {
            flowRates = calculateFlowRates(in: network, pressureMap: pressureMap, deltaTime: deltaTime, networkId: networkId)
        } else {
            flowRates = [:]  // No flow calculations needed for single-pipe networks
        }
        #if DEBUG
        let flowElapsed = CACurrentMediaTime() - flowStart
        #endif

        // Step 4: Apply fluid transfers based on calculated flow rates
        #if DEBUG
        let transferStart = CACurrentMediaTime()
        #endif
        if !flowRates.isEmpty {
            applyFluidTransfers(in: network, flowRates: flowRates, deltaTime: deltaTime)
        } else {
        }
        #if DEBUG
        let transferElapsed = CACurrentMediaTime() - transferStart
        #endif

        // Step 5: Update network pressure and capacity
        #if DEBUG
        let finalizeStart = CACurrentMediaTime()
        #endif
        network.pressure = calculateNetworkPressure(network: network, pressureMap: pressureMap)
        network.updateCapacity(world)
        #if DEBUG
        let finalizeElapsed = CACurrentMediaTime() - finalizeStart

        let totalElapsed = CACurrentMediaTime() - startTime
        if totalElapsed >= 0.01 {
            let size = network.pipes.count + network.tanks.count + network.producers.count + network.consumers.count
            let timingSummary = [
                String(format: "consumption=%.2f", consumptionElapsed * 1000),
                String(format: "consume=%.2f", consumeElapsed * 1000),
                String(format: "production=%.2f", productionElapsed * 1000),
                String(format: "inject=%.2f", injectElapsed * 1000),
                String(format: "pressure=%.2f", pressureElapsed * 1000),
                String(format: "flow=%.2f", flowElapsed * 1000),
                String(format: "transfer=%.2f", transferElapsed * 1000),
                String(format: "finalize=%.2f", finalizeElapsed * 1000)
            ].joined(separator: ", ")
            print("FluidNetworkSystem: network \(networkId) size \(size) pipes \(network.pipes.count) total \(String(format: "%.2f", totalElapsed * 1000))ms | \(timingSummary)")
        }
        #endif
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
                    calculateNetworkFlow(&network, deltaTime: deltaTime, networkId: networkId)
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

                        let hasFuel = inventory.slots.contains { slot in
                            guard let itemStack = slot else { return false }
                            // Check if this item is fuel (coal, wood, solid-fuel)
                            return ["coal", "wood", "solid-fuel"].contains(itemStack.itemId)
                        } // Check if any fuel slot has actual fuel
                        let hasWater = tank.tanks.contains { $0.type == .water && $0.amount > 0.0 } // Need any water

                            if hasFuel && hasWater {
                                productionThisTick = producer.productionRate * deltaTime
                                producer.isActive = true
                            }

                            // Consume water at the same rate as steam production
                            let waterConsumed = productionThisTick
                            _ = removeFluidFromTank(producerEntity, amount: waterConsumed, fluidType: .water)

                            // Consume fuel based on energy content
                            // Boiler produces 1.8 steam/s, steam engine consumes 30 steam/s for 900 kW
                            // So boiler produces (1.8/30) * 900 kW = 54 kW of steam energy
                            let boilerPowerOutput: Float = 54.0  // kW (energy output rate)
                            let energyConsumptionRate = boilerPowerOutput  // kJ/s (since 1 kW = 1 kJ/s)

                            producer.fuelConsumptionAccumulator += energyConsumptionRate * deltaTime



                            // Network dirty state is now handled at the system level for boilers

                            // Find the fuel item and its energy value
                            var fuelEnergyValue: Float = 0
                            var fuelSlotIndex: Int? = nil

                            for i in 0..<inventory.slots.count {
                                if let itemStack = inventory.slots[i],
                                   ["coal", "wood", "solid-fuel"].contains(itemStack.itemId) {
                                    // Get fuel energy value (coal=4000, wood=2000, solid-fuel=25000)
                                    if let item = itemRegistry.get(itemStack.itemId),
                                       let fuelValue = item.fuelValue {
                                        fuelEnergyValue = Float(fuelValue)
                                        fuelSlotIndex = i
                                        break  // Use first available fuel
                                    }
                                }
                            }

                            if fuelEnergyValue > 0 && fuelSlotIndex != nil {
                                // Use floating point comparison with small epsilon to handle precision issues
                                let epsilon = 0.1  // Allow 0.1 kJ tolerance for floating point precision
                                if producer.fuelConsumptionAccumulator >= fuelEnergyValue - Float(epsilon) {
                                    // Consume one fuel item
                                    var itemStack = inventory.slots[fuelSlotIndex!]!
                                    itemStack.count -= 1

                                if itemStack.count <= 0 {
                                    inventory.slots[fuelSlotIndex!] = nil
                                } else {
                                    inventory.slots[fuelSlotIndex!] = itemStack
                                }

                                // Reset accumulator (subtract the energy we consumed)
                                producer.fuelConsumptionAccumulator -= fuelEnergyValue

                                // Save updated inventory
                                world.add(inventory, to: producerEntity)
                            }
                        } else {
                            // Not producing - reset fuel accumulator and mark inactive
                            producer.fuelConsumptionAccumulator = 0
                            producer.isActive = false
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
                    let actualRate = deltaTime > 0 ? (productionThisTick / deltaTime) : 0
                    updatedProducer.currentProduction = actualRate
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

    /// Calculate consumption volumes for all consumers in the network
    private func calculateConsumptionVolumes(for network: FluidNetwork, deltaTime: Float) -> [Entity: Float] {
        var consumptionVolumes: [Entity: Float] = [:]

        for consumerEntity in network.consumers {
            if let consumer = world.get(FluidConsumerComponent.self, for: consumerEntity) {

                // Get power satisfaction for non-boiler consumers
                let powerSatisfaction = world.get(PowerConsumerComponent.self, for: consumerEntity)?.satisfaction ?? 1.0

                // Calculate effective power multiplier (boilers are independent of electricity)
                let powerMultiplier: Float = consumer.buildingId == "boiler" ? 1.0 : max(0, min(powerSatisfaction, 1))

                // Must have some power to operate
                guard powerMultiplier > 0 else {
                    consumer.currentConsumption = 0
                    world.add(consumer, to: consumerEntity)
                    continue
                }

                // Check if consumer can request input
                let canRequestInput: Bool
                if consumer.buildingId == "boiler" {
                    // Boilers need fuel to request water
                    if let inventory = world.get(InventoryComponent.self, for: consumerEntity) {
                        canRequestInput = inventory.slots.contains { $0 != nil }
                    } else {
                        canRequestInput = false
                    }
                } else {
                    // Other consumers need input available
                    canRequestInput = hasInputAvailable(consumerEntity: consumerEntity, network: network)
                }

                guard canRequestInput else {
                    consumer.currentConsumption = 0
                    world.add(consumer, to: consumerEntity)
                    continue
                }

                // Calculate requested consumption volume (not rate)
                let requestedVolume = consumer.consumptionRate * deltaTime * powerMultiplier
                consumptionVolumes[consumerEntity] = requestedVolume

                // Store rate (L/s) for UI; requestedVolume is per tick
                consumer.currentConsumption = consumer.consumptionRate * powerMultiplier
            }
        }

        return consumptionVolumes
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
                    let minAmount: Float = (consumer.buildingId == "boiler") ? 0.001 : 0.01
                    if (pipe.fluidType == consumer.inputType || consumer.inputType == .steam) && pipe.fluidAmount > minAmount { // Minimum amount
                        return true
                    }
                } else if let tank = world.get(FluidTankComponent.self, for: connectedEntity) {
                    // Check if tank has the required fluid
                    for tankStack in tank.tanks {
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
        let useSimplified = networkSize > 50

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
            let iterations = networkSize > 25 ? 2 : 4  // Fewer iterations for medium networks
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
    private func calculateFlowRates(in network: FluidNetwork, pressureMap: [Entity: Float], deltaTime: Float, networkId: Int) -> [EntityPair: Float] {
        var flowRates: [EntityPair: Float] = [:]


        // Check all pipes and their connections
        let pipes = network.pipes
        let totalPipes = pipes.count
        if totalPipes == 0 {
            return flowRates
        }

        let pipesToProcess = totalPipes > maxPipesPerFlowUpdate ? maxPipesPerFlowUpdate : totalPipes
        let startIndex = flowUpdateCursorByNetwork[networkId] ?? 0

        for i in 0..<pipesToProcess {
            let index = (startIndex + i) % totalPipes
            let pipeEntity = pipes[index]
            guard let pipe = world.get(PipeComponent.self, for: pipeEntity),
                  let pipePressure = pressureMap[pipeEntity] else {
                continue
            }


            for connectedEntity in pipe.connections {
                // Skip connections to producers - they inject fluid separately
                if network.producers.contains(connectedEntity) {
                    continue
                }
                // Allow connections to consumers - flow can transfer fluid to them

                guard let connectedPressure = pressureMap[connectedEntity] else {
                    continue
                }

                // Calculate pressure gradient
                let pressureDiff = pipePressure - connectedPressure


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

        flowUpdateCursorByNetwork[networkId] = (startIndex + pipesToProcess) % totalPipes
        return flowRates
    }

    /// Apply calculated fluid transfers
    private func applyFluidTransfers(in network: FluidNetwork, flowRates: [EntityPair: Float], deltaTime: Float) {
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

        // Apply net flow rates to only the pipes that were updated this tick
        for (pipeEntity, netFlowRate) in netFlowRates {
            if let pipe = world.get(PipeComponent.self, for: pipeEntity) {
                let updatedPipe = pipe
                updatedPipe.flowRate = netFlowRate
                world.add(updatedPipe, to: pipeEntity)
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
        for (producerEntity, productionAmount) in productionRates {
            guard let producer = world.get(FluidProducerComponent.self, for: producerEntity) else { continue }


            // Determine the fluid type being produced
            let fluidType = producer.outputType

            // Try to add fluid to all pipes in the network, simulating fluid distribution
            var remainingAmount = productionAmount

            // First, try directly connected pipes
            for connectedEntity in producer.connections {
                if remainingAmount <= 0 { break }
                if world.has(PipeComponent.self, for: connectedEntity) {
                    let added = addFluidToEntity(connectedEntity, amount: remainingAmount, fluidType: fluidType)
                    remainingAmount -= added
                }
            }

            // Then distribute remaining fluid to all pipes in the network
            if remainingAmount > 0 {
                let pipesToFill = network.pipes.filter { pipeEntity in
                    if let pipe = world.get(PipeComponent.self, for: pipeEntity) {
                        return pipe.fluidType == nil || pipe.fluidType == fluidType
                    }
                    return false
                }

                if !pipesToFill.isEmpty {
                    let amountPerPipe = remainingAmount / Float(pipesToFill.count)
                    for pipeEntity in pipesToFill {
                        if remainingAmount <= 0 { break }
                        let added = addFluidToEntity(pipeEntity, amount: amountPerPipe, fluidType: fluidType)
                        remainingAmount -= added
                    }
                }
            }

            // Finally, try connected tanks
            for connectedEntity in producer.connections {
                if remainingAmount <= 0 { break }
                if world.has(FluidTankComponent.self, for: connectedEntity) {
                    let added = addFluidToEntity(connectedEntity, amount: remainingAmount, fluidType: fluidType)
                    remainingAmount -= added
                }
            }

            // If still fluid left and producer has a tank, add to own tank
            if remainingAmount > 0 {
                _ = addFluidToEntity(producerEntity, amount: remainingAmount, fluidType: fluidType)
            }
        }
    }

    /// Consume fluid volumes from the network for consumers
    private func consumeFluidFromNetwork(consumptionVolumes: [Entity: Float], network: FluidNetwork) {
        for (consumerEntity, consumptionVolume) in consumptionVolumes {
            guard let consumer = world.get(FluidConsumerComponent.self, for: consumerEntity) else { continue }

            // Determine the fluid type being consumed
            let fluidType = consumer.buildingId == "steam-engine" ? .steam : consumer.inputType

            // Try to consume fluid from connected pipes first, then tanks
            var remainingVolume = consumptionVolume

            // Special handling for boilers - water goes to tank instead of being consumed
            if consumer.buildingId == "boiler" && fluidType == .water {
                // For boilers, consume water into internal tank
                var addedToTank = 0.0

                // Try all pipes in the network, not just directly connected ones
                // This simulates fluid flow through the pipe network
                for pipeEntity in network.pipes {
                    if remainingVolume <= 0 { break }
                    if let pipe = world.get(PipeComponent.self, for: pipeEntity) {
                        if pipe.fluidType == fluidType && pipe.fluidAmount > 0 {
                            let removed = removeFluidFromEntity(pipeEntity, amount: remainingVolume, fluidType: fluidType!)
                            if removed > 0 {
                                // Add to boiler's tank instead of consuming
                                let added = addFluidToEntity(consumerEntity, amount: removed, fluidType: fluidType!)
                                addedToTank += Double(added)
                                remainingVolume -= removed
                            }
                        }
                    }
                }

                // Then try connected tanks
                for connectedEntity in consumer.connections {
                    if remainingVolume <= 0 { break }
                    if world.has(FluidTankComponent.self, for: connectedEntity) {
                        let removed = removeFluidFromEntity(connectedEntity, amount: remainingVolume, fluidType: fluidType!)
                        if removed > 0 {
                            // Add to boiler's tank
                            let added = addFluidToEntity(consumerEntity, amount: removed, fluidType: fluidType!)
                            addedToTank += Double(added)
                            remainingVolume -= removed
                        }
                    }
                }

            } else {
                // Normal consumption - remove from network
                if consumer.buildingId == "steam-engine" {
                    // Steam engines consume from any pipe in the network with steam
                    for pipeEntity in network.pipes {
                        if remainingVolume <= 0 { break }
                        if let pipe = world.get(PipeComponent.self, for: pipeEntity) {
                            if pipe.fluidType == fluidType && pipe.fluidAmount > 0 {
                                let removed = removeFluidFromEntity(pipeEntity, amount: remainingVolume, fluidType: fluidType!)
                                if removed > 0 {
                                    remainingVolume -= removed
                                }
                            }
                        }
                    }
                } else {
                    // Other consumers use connected pipes
                    for connectedEntity in consumer.connections {
                        if remainingVolume <= 0 { break }
                        if world.has(PipeComponent.self, for: connectedEntity) {
                            let removed = removeFluidFromEntity(connectedEntity, amount: remainingVolume, fluidType: fluidType!)
                            if removed > 0 {
                                remainingVolume -= removed
                            }
                        }
                    }
                }

                // Then try connected tanks
                for connectedEntity in consumer.connections {
                    if remainingVolume <= 0 { break }
                    if world.has(FluidTankComponent.self, for: connectedEntity) {
                        let removed = removeFluidFromEntity(connectedEntity, amount: remainingVolume, fluidType: fluidType!)
                        remainingVolume -= removed
                    }
                }

                // If still need fluid and consumer has a tank, consume from own tank
                if remainingVolume > 0 {
                    _ = removeFluidFromEntity(consumerEntity, amount: remainingVolume, fluidType: fluidType!)
                }
            }
        }
    }

    /// Handle direct transfers from producers to consumers (bypassing pipe network)
    private func handleDirectTransfers(in network: FluidNetwork, deltaTime: Float) {
        // For now, producers and consumers handle their own transfers through the existing logic
        // This could be enhanced to allow direct producer->consumer transfers when they're connected
    }

    /// Get networks that contain boilers (for continuous processing)
    private func getNetworksWithBoilers() -> Set<Int> {
        var boilerNetworks = Set<Int>()
        for (networkId, network) in networks {
            if network.producers.contains(where: { producerEntity in
                if let producer = world.get(FluidProducerComponent.self, for: producerEntity) {
                    return producer.buildingId == "boiler"
                }
                return false
            }) {
                boilerNetworks.insert(networkId)
            }
        }
        return boilerNetworks
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

    /// Gets the next available network ID and increments the counter
    func getNextNetworkId() -> Int {
        let id = nextNetworkId
        nextNetworkId += 1
        return id
    }

    /// Gets all existing network IDs
    func getAllNetworkIds() -> [Int] {
        return Array(networks.keys).sorted()
    }

    /// Merges the network of the specified entity with another network
    func mergeNetworksContainingEntities(_ entity1: Entity, _ entity2: Entity) {
        guard let networkId1 = getEntityNetworkId(entity1),
              let networkId2 = getEntityNetworkId(entity2),
              networkId1 != networkId2 else {
            return
        }

        // Determine which network to keep (use the smaller ID)
        let (primaryId, secondaryId) = networkId1 < networkId2 ? (networkId1, networkId2) : (networkId2, networkId1)

        guard var primaryNetwork = networks[primaryId],
              let secondaryNetwork = networks[secondaryId] else {
            return
        }

        // Merge the secondary network into the primary network
        primaryNetwork.merge(with: secondaryNetwork, world: world)

        // Remove the secondary network
        networks.removeValue(forKey: secondaryId)

        // Update all entities in the secondary network to use the primary network ID
        for entity in secondaryNetwork.pipes + secondaryNetwork.producers + secondaryNetwork.consumers + secondaryNetwork.tanks {
            setEntityNetworkId(entity, networkId: primaryId)
        }

        // Update the primary network
        networks[primaryId] = primaryNetwork

        // Mark the merged network as dirty
        markNetworkDirty(primaryId)
    }

    /// Converts an offset vector to a direction
    private func directionFromOffset(_ offset: IntVector2) -> Direction {
        if offset.x == 0 && offset.y == 1 { return .north }
        if offset.x == 1 && offset.y == 0 { return .east }
        if offset.x == 0 && offset.y == -1 { return .south }
        if offset.x == -1 && offset.y == 0 { return .west }
        // This shouldn't happen for adjacent positions, but return north as default
        return .north
    }

    private func hasFluidEntity(at tile: IntVector2) -> Bool {
        for entity in world.entities {
            if !isFluidEntity(entity) {
                continue
            }
            for occupied in getOccupiedTiles(for: entity) {
                if occupied == tile {
                    return true
                }
            }
        }
        return false
    }

    private func pipeShapeAndDirection(for directions: Set<Direction>, fallbackDirection: Direction) -> (shape: PipeShape, direction: Direction) {
        let count = directions.count
        if count == 0 {
            return (.straight, fallbackDirection)
        }
        if count == 1, let dir = directions.first {
            return (.end, dir)
        }
        if count == 2 {
            if directions.contains(.north) && directions.contains(.south) {
                return (.straight, .north)
            }
            if directions.contains(.east) && directions.contains(.west) {
                return (.straight, .east)
            }
            if directions.contains(.north) && directions.contains(.east) {
                return (.corner, .north)
            }
            if directions.contains(.east) && directions.contains(.south) {
                return (.corner, .east)
            }
            if directions.contains(.south) && directions.contains(.west) {
                return (.corner, .south)
            }
            if directions.contains(.west) && directions.contains(.north) {
                return (.corner, .west)
            }
            return (.corner, fallbackDirection)
        }
        if count == 3 {
            let missing = Direction.allCases.first { !directions.contains($0) } ?? fallbackDirection
            return (.tee, missing.clockwise)
        }
        return (.cross, fallbackDirection)
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

    /// Recompute pipe shapes/directions based on current adjacency (used after loading saves)
    func recomputePipeShapes() {
        for pipeEntity in world.query(PipeComponent.self) {
            guard let pipe = world.get(PipeComponent.self, for: pipeEntity),
                  let position = world.get(PositionComponent.self, for: pipeEntity)?.tilePosition else {
                continue
            }

            var neighborDirections: Set<Direction> = []
            for direction in Direction.allCases {
                let neighborPos = position + direction.intVector
                if hasFluidEntity(at: neighborPos) {
                    neighborDirections.insert(direction)
                }
            }

            let shapeInfo = pipeShapeAndDirection(for: neighborDirections, fallbackDirection: pipe.direction)
            pipe.direction = shapeInfo.direction
            pipe.shape = shapeInfo.shape
            pipe.allowedDirections = PipeComponent.allowedDirections(for: shapeInfo.shape, direction: shapeInfo.direction)
            world.add(pipe, to: pipeEntity)
            markEntityDirty(pipeEntity)
        }
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
