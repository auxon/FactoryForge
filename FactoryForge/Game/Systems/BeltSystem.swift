import Foundation

/// System that handles transport belt item movement
final class BeltSystem: System {
    let priority = SystemPriority.logistics.rawValue
    
    private let world: World
    
    /// Belt connections graph
    private var beltGraph: [IntVector2: BeltNode] = [:]
    
    /// Topologically sorted belts for processing
    private var sortedBelts: [Entity] = []
    private var needsResort = true
    
    init(world: World) {
        self.world = world
    }
    
    // MARK: - Belt Registration
    
    func registerBelt(entity: Entity, at position: IntVector2, direction: Direction, type: BeltType = .normal) {
        let node = BeltNode(entity: entity, position: position, direction: direction, type: type)
        beltGraph[position] = node
        updateConnections(for: position)

        // For underground belts, also register the output position if specified
        if type == .underground {
            if let beltComp = world.get(BeltComponent.self, for: entity),
               let outputPos = beltComp.undergroundOutputPosition {
                let outputNode = BeltNode(entity: entity, position: outputPos, direction: direction, type: type)
                beltGraph[outputPos] = outputNode
            }
        }

        // Update connections for neighbors that might now connect to this belt
        // Check the belt behind us (opposite of our direction)
        let behindPos = position - direction.intVector
        updateConnections(for: behindPos)

        // Check the belt in front of us (in our direction)
        let frontPos = position + direction.intVector
        updateConnections(for: frontPos)

        // Also check adjacent positions in case belts are pointing at us
        for offset in [IntVector2(1, 0), IntVector2(-1, 0), IntVector2(0, 1), IntVector2(0, -1)] {
            let neighborPos = position + offset
            if neighborPos != behindPos && neighborPos != frontPos {
                updateConnections(for: neighborPos)
            }
        }

        needsResort = true
    }
    
    func updateBeltDirection(entity: Entity, newDirection: Direction) {
        guard let position = world.get(PositionComponent.self, for: entity)?.tilePosition,
              var node = beltGraph[position] else {
            return
        }

        // Update the direction in the graph
        node.direction = newDirection
        beltGraph[position] = node

        // Update connections for this belt and all potentially affected neighbors
        updateConnections(for: position)

        // Update connections for positions that might be affected by the direction change
        let oldFrontPos = position + node.direction.opposite.intVector  // Where it used to point
        let newFrontPos = position + newDirection.intVector  // Where it now points

        // Update connections for the old and new output positions
        updateConnections(for: oldFrontPos)
        updateConnections(for: newFrontPos)

        // Update connections for all adjacent positions (belts that might point to us)
        for offset in [IntVector2(1, 0), IntVector2(-1, 0), IntVector2(0, 1), IntVector2(0, -1)] {
            let neighborPos = position + offset
            updateConnections(for: neighborPos)
        }

        // Also update connections for positions that might be pointing at our new/old positions
        for offset in [IntVector2(1, 0), IntVector2(-1, 0), IntVector2(0, 1), IntVector2(0, -1)] {
            let extendedPos = position + offset * 2
            updateConnections(for: extendedPos)
        }

        needsResort = true
    }

    func unregisterBelt(at position: IntVector2) {
        beltGraph.removeValue(forKey: position)

        // Update neighbors' connections
        for offset in [IntVector2(1, 0), IntVector2(-1, 0), IntVector2(0, 1), IntVector2(0, -1)] {
            let neighborPos = position + offset
            updateConnections(for: neighborPos)
        }

        needsResort = true
    }
    
    private func updateConnections(for position: IntVector2) {
        guard var node = beltGraph[position] else {
            return
        }

        switch node.type {
        case .normal, .bridge:
            updateNormalBeltConnections(for: position, node: &node)
        case .underground:
            updateUndergroundBeltConnections(for: position, node: &node)
        case .splitter:
            updateSplitterConnections(for: position, node: &node)
        case .merger:
            updateMergerConnections(for: position, node: &node)
        }

        beltGraph[position] = node
    }

    private func updateNormalBeltConnections(for position: IntVector2, node: inout BeltNode) {
        // Find output connection (belt in front in the direction we're facing)
        // This connects even if the output belt is going at a 90-degree angle
        let outputPos = position + node.direction.intVector
        if let outputNode = beltGraph[outputPos] {
            // Connect to belt at the position we're pointing to, regardless of its direction
            // This allows 90-degree turns
            node.outputEntity = outputNode.entity

            // Update belt component
            if var belt = world.get(BeltComponent.self, for: node.entity) {
                belt.outputConnection = outputNode.entity
                world.add(belt, to: node.entity)
            }

            // IMPORTANT: Also ensure the output belt has this belt as an input
            // This ensures bidirectional connection for 90-degree turns
            if var outputBelt = world.get(BeltComponent.self, for: outputNode.entity) {
                // Check if we're not already in the output belt's input connections
                var outputNodeCopy = outputNode
                if !outputNodeCopy.inputEntities.contains(node.entity) {
                    outputNodeCopy.inputEntities.append(node.entity)
                    outputBelt.inputConnection = outputNodeCopy.inputEntities.first
                    world.add(outputBelt, to: outputNode.entity)
                    beltGraph[outputPos] = outputNodeCopy
                }
            }
        } else {
            node.outputEntity = nil
            if var belt = world.get(BeltComponent.self, for: node.entity) {
                belt.outputConnection = nil
                world.add(belt, to: node.entity)
            }
        }

        // Find input connections (belts pointing to us from any adjacent position)
        // This includes belts directly behind us, and belts at 90-degree angles
        node.inputEntities = []
        for offset in [IntVector2(1, 0), IntVector2(-1, 0), IntVector2(0, 1), IntVector2(0, -1)] {
            let inputPos = position + offset
            if let inputNode = beltGraph[inputPos] {
                // Check if this belt is pointing at our position
                let inputOutputPos = inputPos + inputNode.direction.intVector
                if inputOutputPos == position {
                    // This belt is pointing directly at us, so it can feed into us
                    node.inputEntities.append(inputNode.entity)
                }
            }
        }

        // Update input connection on belt component
        if var belt = world.get(BeltComponent.self, for: node.entity) {
            belt.inputConnection = node.inputEntities.first
            world.add(belt, to: node.entity)
        }
    }

    private func updateUndergroundBeltConnections(for position: IntVector2, node: inout BeltNode) {
        // Underground belts connect input and output positions
        // For now, treat them similar to normal belts but with special handling
        updateNormalBeltConnections(for: position, node: &node)
    }

    private func updateSplitterConnections(for position: IntVector2, node: inout BeltNode) {
        // Splitters take one input and distribute to multiple outputs
        node.inputEntities = []
        node.outputEntity = nil

        // Find input (belt pointing to us)
        for offset in [IntVector2(1, 0), IntVector2(-1, 0), IntVector2(0, 1), IntVector2(0, -1)] {
            let inputPos = position + offset
            if let inputNode = beltGraph[inputPos] {
                let inputOutputPos = inputPos + inputNode.direction.intVector
                if inputOutputPos == position {
                    node.inputEntities.append(inputNode.entity)
                }
            }
        }

        // Find outputs (belts in front of us and to the sides)
        var outputEntities: [Entity] = []
        for offset in [IntVector2(1, 0), IntVector2(-1, 0), IntVector2(0, 1), IntVector2(0, -1)] {
            let outputPos = position + offset
            if let outputNode = beltGraph[outputPos] {
                // Connect to any adjacent belt (splitters output in all directions)
                outputEntities.append(outputNode.entity)
            }
        }

        // Update belt component with multiple connections
        if var belt = world.get(BeltComponent.self, for: node.entity) {
            belt.inputConnection = node.inputEntities.first
            belt.outputConnections = outputEntities
            world.add(belt, to: node.entity)
        }
    }

    private func updateMergerConnections(for position: IntVector2, node: inout BeltNode) {
        // Mergers take multiple inputs and combine into one output
        node.inputEntities = []
        node.outputEntity = nil

        // Find inputs (any adjacent belts)
        var inputEntities: [Entity] = []
        for offset in [IntVector2(1, 0), IntVector2(-1, 0), IntVector2(0, 1), IntVector2(0, -1)] {
            let inputPos = position + offset
            if let inputNode = beltGraph[inputPos] {
                inputEntities.append(inputNode.entity)
            }
        }

        // Find output (belt in front of us)
        let outputPos = position + node.direction.intVector
        if let outputNode = beltGraph[outputPos] {
            node.outputEntity = outputNode.entity
        }

        // Update belt component with multiple inputs
        if var belt = world.get(BeltComponent.self, for: node.entity) {
            belt.inputConnections = inputEntities
            belt.outputConnection = node.outputEntity
            world.add(belt, to: node.entity)
        }
    }
    
    private func topologicalSort() {
        // Sort belts so we process from end to beginning
        // This ensures items flow correctly without gaps
        
        var inDegree: [Entity: Int] = [:]
        var adjacency: [Entity: [Entity]] = [:]
        
        for node in beltGraph.values {
            inDegree[node.entity] = node.inputEntities.count
            if let output = node.outputEntity {
                adjacency[node.entity, default: []].append(output)
            }
        }
        
        var queue: [Entity] = []
        for (entity, degree) in inDegree {
            if degree == 0 {
                queue.append(entity)
            }
        }
        
        sortedBelts = []
        while !queue.isEmpty {
            let entity = queue.removeFirst()
            sortedBelts.append(entity)
            
            for neighbor in adjacency[entity] ?? [] {
                inDegree[neighbor, default: 0] -= 1
                if inDegree[neighbor] == 0 {
                    queue.append(neighbor)
                }
            }
        }
        
        // Process from end to beginning
        sortedBelts.reverse()
        needsResort = false
    }
    
    // MARK: - Update
    
    func update(deltaTime: Float) {
        if needsResort {
            topologicalSort()
        }
        
        // Process belts in topological order
        for entity in sortedBelts {
            guard var belt = world.get(BeltComponent.self, for: entity) else { continue }

            let speed = belt.speed * deltaTime

            // Handle different belt types
            switch belt.type {
            case .normal, .bridge:
                // Standard belt behavior
                moveItemsOnLane(lane: &belt.leftLane, speed: speed, outputBelt: getOutputBelt(for: entity), outputLane: .left)
                moveItemsOnLane(lane: &belt.rightLane, speed: speed, outputBelt: getOutputBelt(for: entity), outputLane: .right)

            case .underground:
                // Underground belts move items instantly between input and output
                moveUndergroundBeltItems(belt: &belt, entity: entity)

            case .splitter:
                // Splitters distribute items from input to multiple outputs
                moveSplitterItems(belt: &belt, speed: speed, entity: entity)

            case .merger:
                // Mergers combine items from multiple inputs
                moveMergerItems(belt: &belt, speed: speed, entity: entity)
            }

            world.add(belt, to: entity)
        }
    }
    
    private func moveItemsOnLane(lane: inout [BeltItem], speed: Float, outputBelt: Entity?, outputLane: BeltLane) {
        guard !lane.isEmpty else { return }
        
        // Process items from end to beginning
        for i in stride(from: lane.count - 1, through: 0, by: -1) {
            var item = lane[i]
            var newProgress = item.progress + speed
            
            // Check for collision with item in front
            if i < lane.count - 1 {
                let itemInFront = lane[i + 1]
                let minGap: Float = 0.25
                newProgress = min(newProgress, itemInFront.progress - minGap)
            }
            
            // Check if item should transfer to next belt
            if newProgress >= 1.0 {
                if let nextBelt = outputBelt {
                    if var nextBeltComp = world.get(BeltComponent.self, for: nextBelt) {
                        // Try to add to next belt
                        if nextBeltComp.addItem(item.itemId, lane: outputLane, position: 0) {
                            world.add(nextBeltComp, to: nextBelt)
                            lane.remove(at: i)
                            continue
                        }
                    }
                }
                // Can't transfer, stay at end to block items behind
                newProgress = 1.0
            }
            
            item.progress = max(item.progress, newProgress)  // Don't go backwards
            lane[i] = item
        }
    }
    
    private func getOutputBelt(for entity: Entity) -> Entity? {
        guard let belt = world.get(BeltComponent.self, for: entity) else { return nil }
        return belt.outputConnection
    }

    private func moveUndergroundBeltItems(belt: inout BeltComponent, entity: Entity) {
        // Underground belts instantly transfer items from input position to output position
        // For now, we'll simulate this by moving items very quickly
        // In a more advanced implementation, we'd track underground routing

        let speed = belt.speed * 10.0 // Much faster underground movement

        moveItemsOnLane(lane: &belt.leftLane, speed: speed, outputBelt: getOutputBelt(for: entity), outputLane: .left)
        moveItemsOnLane(lane: &belt.rightLane, speed: speed, outputBelt: getOutputBelt(for: entity), outputLane: .right)
    }

    private func moveSplitterItems(belt: inout BeltComponent, speed: Float, entity: Entity) {
        // Splitters take items from input and distribute to multiple outputs

        // First, try to get items from input connections
        if let inputEntity = belt.inputConnection {
            if var inputBelt = world.get(BeltComponent.self, for: inputEntity) {
                // Try to take items from input belt
                if let item = inputBelt.takeItemFromMerger() { // Reusing merger method for taking from input
                    // Add to splitter's distribution logic
                    _ = belt.addItemToSplitter(item.itemId)
                    // Update the input belt
                    world.add(inputBelt, to: inputEntity)
                }
            }
        }

        // Move items along splitter and distribute to outputs
        moveItemsOnLane(lane: &belt.leftLane, speed: speed, outputBelt: belt.outputConnections.first, outputLane: .left)
        moveItemsOnLane(lane: &belt.rightLane, speed: speed, outputBelt: belt.outputConnections.last, outputLane: .right)
    }

    private func moveMergerItems(belt: inout BeltComponent, speed: Float, entity: Entity) {
        // Mergers combine items from multiple inputs into one output

        // Try to get items from all input connections
        for inputEntity in belt.inputConnections {
            if var inputBelt = world.get(BeltComponent.self, for: inputEntity) {
                if let item = inputBelt.takeItemFromMerger() {
                    // Add to merger's combined output
                    _ = belt.addItemToSplitter(item.itemId) // Reusing splitter method for distribution
                    // Update the input belt
                    world.add(inputBelt, to: inputEntity)
                }
            }
        }

        // Move combined items to output
        moveItemsOnLane(lane: &belt.leftLane, speed: speed, outputBelt: getOutputBelt(for: entity), outputLane: .left)
        moveItemsOnLane(lane: &belt.rightLane, speed: speed, outputBelt: getOutputBelt(for: entity), outputLane: .right)
    }
    
    // MARK: - Public Interface
    
    /// Adds an item to a belt at a position
    func addItem(_ itemId: String, at position: IntVector2, lane: BeltLane, progress: Float = 0) -> Bool {
        guard let node = beltGraph[position],
              var belt = world.get(BeltComponent.self, for: node.entity) else {
            return false
        }
        
        let success = belt.addItem(itemId, lane: lane, position: progress)
        if success {
            world.add(belt, to: node.entity)
        }
        return success
    }
    
    /// Takes an item from a belt at a position
    func takeItem(at position: IntVector2, lane: BeltLane) -> BeltItem? {
        guard let node = beltGraph[position],
              var belt = world.get(BeltComponent.self, for: node.entity) else {
            return nil
        }
        
        let item = belt.takeItem(from: lane)
        if item != nil {
            world.add(belt, to: node.entity)
        }
        return item
    }
    
    /// Gets the belt entity at a position
    func getBeltAt(position: IntVector2) -> Entity? {
        return beltGraph[position]?.entity
    }
    
    /// Checks if there's space on a belt for an item
    func hasSpace(at position: IntVector2, lane: BeltLane) -> Bool {
        guard let node = beltGraph[position],
              let belt = world.get(BeltComponent.self, for: node.entity) else {
            return false
        }
        
        let items = lane == .left ? belt.leftLane : belt.rightLane
        if items.isEmpty { return true }
        
        // Check if there's space at the beginning
        return items.first!.progress > 0.25
    }
}

// MARK: - Belt Node

private struct BeltNode {
    let entity: Entity
    let position: IntVector2
    var direction: Direction
    var type: BeltType = .normal
    var inputEntities: [Entity] = []
    var outputEntity: Entity?
}

