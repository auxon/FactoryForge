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
    
    func registerBelt(entity: Entity, at position: IntVector2, direction: Direction) {
        let node = BeltNode(entity: entity, position: position, direction: direction)
        beltGraph[position] = node
        updateConnections(for: position)
        
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
            print("BeltSystem: updateConnections - No belt node at \(position)")
            return 
        }
        
        print("BeltSystem: updateConnections for belt at \(position) (dir: \(node.direction))")
        
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
                print("BeltSystem: Belt at \(position) (dir: \(node.direction)) connected output to belt at \(outputPos) (dir: \(outputNode.direction))")
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
                    print("BeltSystem: Belt at \(outputPos) (dir: \(outputNode.direction)) now has input from belt at \(position) (dir: \(node.direction))")
                }
            }
        } else {
            node.outputEntity = nil
            if var belt = world.get(BeltComponent.self, for: node.entity) {
                belt.outputConnection = nil
                world.add(belt, to: node.entity)
                print("BeltSystem: Belt at \(position) (dir: \(node.direction)) has no output connection")
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
                    print("BeltSystem: Belt at \(position) (dir: \(node.direction)) connected input from belt at \(inputPos) (dir: \(inputNode.direction))")
                }
            }
        }
        
        // Update input connection on belt component
        if var belt = world.get(BeltComponent.self, for: node.entity) {
            belt.inputConnection = node.inputEntities.first
            world.add(belt, to: node.entity)
        }
        
        beltGraph[position] = node
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
            
            // Move items on left lane
            moveItemsOnLane(lane: &belt.leftLane, speed: speed, outputBelt: getOutputBelt(for: entity), outputLane: .left)
            
            // Move items on right lane
            moveItemsOnLane(lane: &belt.rightLane, speed: speed, outputBelt: getOutputBelt(for: entity), outputLane: .right)
            
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
                // Can't transfer, stop at end
                newProgress = 0.99
            }
            
            item.progress = max(item.progress, newProgress)  // Don't go backwards
            lane[i] = item
        }
    }
    
    private func getOutputBelt(for entity: Entity) -> Entity? {
        guard let belt = world.get(BeltComponent.self, for: entity) else { return nil }
        return belt.outputConnection
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
    let direction: Direction
    var inputEntities: [Entity] = []
    var outputEntity: Entity?
}

