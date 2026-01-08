import Foundation
import QuartzCore

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
        // Remove any existing entries for this entity to prevent duplicates
        for (pos, node) in beltGraph {
            if node.entity == entity {
                beltGraph.removeValue(forKey: pos)
            }
        }

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
        case .normal, .bridge, .fast, .express:
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

        // Find adjacent belts in cardinal directions (north, south, east, west)
        // Splitters connect to belts adjacent in the 4 cardinal directions, like normal belts
        var adjacentBelts: [Entity] = []

        // Check cardinal directions in priority order: north, east, south, west
        for offset in [IntVector2(0, 1), IntVector2(1, 0), IntVector2(0, -1), IntVector2(-1, 0)] {
            let adjacentPos = position + offset
            if let outputNode = beltGraph[adjacentPos] {
                adjacentBelts.append(outputNode.entity)
            }
        }

        // Update belt component with all adjacent belt connections
        if var belt = world.get(BeltComponent.self, for: node.entity) {
            belt.inputConnection = node.inputEntities.first
            belt.outputConnections = adjacentBelts
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
        let startTime = CACurrentMediaTime()

        if needsResort {
            topologicalSort()
        }

        // Process belts in topological order
        for entity in sortedBelts {
            guard var belt = world.get(BeltComponent.self, for: entity) else { continue }

            // Update belt animation speed based on actual belt speed and power
            updateBeltAnimation(entity: entity, belt: belt)

            let speed = belt.speed * deltaTime

            // Handle different belt types
            switch belt.type {
            case .normal, .bridge, .fast, .express:
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

    private func updateBeltAnimation(entity: Entity, belt: BeltComponent) {
        // Update belt animation playback speed based on belt speed and power
        guard var sprite = world.get(SpriteComponent.self, for: entity),
              var animation = sprite.animation else { return }

        // Check power status
        var speedMultiplier: Float = 1.0
        if let power = world.get(PowerConsumerComponent.self, for: entity) {
            speedMultiplier = power.satisfaction
        }

        // Adjust animation speed based on belt speed and power
        // Base animation is 1.6 seconds for 16 frames (0.1s per frame)
        // Speed up/slow down based on belt speed and power
        let baseFrameTime: Float = 0.1
        let beltSpeedFactor = belt.speed / Float(1.875)  // Normalize to transport belt speed
        let adjustedFrameTime = baseFrameTime / (beltSpeedFactor * speedMultiplier)

        animation.frameTime = adjustedFrameTime
        sprite.animation = animation
        world.add(sprite, to: entity)
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
        // Factorio-style splitter: collect items and distribute evenly to all adjacent belts
        guard let position = world.get(PositionComponent.self, for: entity)?.tilePosition else { return }

        // Get all items currently on splitter
        var splitterItems: [BeltItem] = []
        splitterItems.append(contentsOf: belt.leftLane)
        splitterItems.append(contentsOf: belt.rightLane)

        // Clear splitter immediately (like Factorio)
        belt.leftLane.removeAll()
        belt.rightLane.removeAll()

        if splitterItems.isEmpty { return }

        // Find output belts (exclude the input direction)
        var outputBelts: [Entity] = []
        var foundEntities = Set<Entity>() // Prevent duplicates from beltGraph bugs

        // Splitter outputs to all directions except the input direction (opposite of facing direction)
        let inputDirection = belt.direction.opposite // Items come from the opposite direction
        let inputOffset = inputDirection.intVector
        let inputPos = position + inputOffset

        // print("BeltSystem: Splitter at \(position), direction: \(belt.direction), inputDirection: \(inputDirection), inputPos: \(inputPos)")

        let directions = [
            IntVector2(0, 1),  // North
            IntVector2(1, 0),  // East
            IntVector2(0, -1), // South
            IntVector2(-1, 0)  // West
        ]

        for offset in directions {
            let checkPos = position + offset
            // Skip the input position - splitter doesn't output to its input direction
            if checkPos == inputPos {
                // print("BeltSystem: Skipping input position: \(checkPos)")
                continue
            }

            print("BeltSystem: Checking output position: \(checkPos)")
            // Check beltGraph for belts at exact adjacent positions
            if let beltNode = beltGraph[checkPos],
               beltNode.type == .normal || beltNode.type == .fast || beltNode.type == .express,
               !foundEntities.contains(beltNode.entity) {
                outputBelts.append(beltNode.entity)
                foundEntities.insert(beltNode.entity)
                // print("BeltSystem: Found output belt \(beltNode.entity) at \(checkPos)")
            }
        }

        if outputBelts.isEmpty { return }

        // Distribute items randomly across output belts (1/3 chance each)
        for item in splitterItems {
            var itemPlaced = false

            // Randomly select one output belt for this item
            if !outputBelts.isEmpty {
                let randomIndex = Int.random(in: 0..<outputBelts.count)
                let targetBeltEntity = outputBelts[randomIndex]

                if var targetBelt = world.get(BeltComponent.self, for: targetBeltEntity) {
                    // Try left lane first, then right lane
                    if targetBelt.addItem(item.itemId, lane: .left, position: 0) ||
                       targetBelt.addItem(item.itemId, lane: .right, position: 0) {
                        world.add(targetBelt, to: targetBeltEntity)
                        itemPlaced = true
                        // print("BeltSystem: Added item to belt \(targetBeltEntity) (random)")
                    } else {
                        // print("BeltSystem: Selected belt \(targetBeltEntity) full, item lost")
                    }
                }
            }

            // If no belt can accept the item, it's lost (Factorio behavior)
            if !itemPlaced {
                print("BeltSystem: Item lost - no valid output belts")
            }
        }
    }

    private func moveMergerItems(belt: inout BeltComponent, speed: Float, entity: Entity) {
        // Mergers collect items from multiple inputs and combine them into a single output stream

        // Collect items from all input connections that have items ready
        var collectedItems: [BeltItem] = []
        for inputEntity in belt.inputConnections {
            if var inputBelt = world.get(BeltComponent.self, for: inputEntity) {
                // Take any items ready from input belt
                while let item = inputBelt.takeItem(from: .left) ?? inputBelt.takeItem(from: .right) {
                    collectedItems.append(item)
                }
                if !collectedItems.isEmpty {
                    world.add(inputBelt, to: inputEntity)
                }
            }
        }

        // Add collected items to merger lanes for output
        for item in collectedItems {
            _ = belt.addItemToSplitter(item.itemId)
        }

        // Send combined items to the single output
        let outputBelt = getOutputBelt(for: entity)
        moveItemsOnLane(lane: &belt.leftLane, speed: speed, outputBelt: outputBelt, outputLane: .left)
        moveItemsOnLane(lane: &belt.rightLane, speed: speed, outputBelt: outputBelt, outputLane: .right)
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

