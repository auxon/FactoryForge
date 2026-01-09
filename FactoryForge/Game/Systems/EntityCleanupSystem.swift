import Foundation

/// System that handles cleanup of entities marked for removal (depleted trees, destroyed buildings, etc.)
final class EntityCleanupSystem: System {
    let priority = SystemPriority.cleanup.rawValue

    private let world: World
    private let chunkManager: ChunkManager

    // Cleanup timing
    private let cleanupInterval: TimeInterval = 1.0  // Check for cleanup every 1 second
    private var lastCleanupTime: TimeInterval = 0

    init(world: World, chunkManager: ChunkManager) {
        self.world = world
        self.chunkManager = chunkManager
    }

    func update(deltaTime: Float) {
        let currentTime = Time.shared.totalTime

        // Only run cleanup periodically to avoid performance issues
        if Double(currentTime) - lastCleanupTime < cleanupInterval {
            return
        }
        lastCleanupTime = Double(currentTime)

        performCleanup()
    }

    /// Immediately clean up all entities marked for removal
    /// Used during game loading to clean up stale entities
    func performImmediateCleanup() {
        performCleanup()
    }

    private func performCleanup() {
        // Collect entities to remove (avoid modifying world while iterating)
        var entitiesToRemove: [Entity] = []

        // Find trees marked for removal
        world.forEach(TreeComponent.self) { entity, tree in
            if tree.markedForRemoval {
                entitiesToRemove.append(entity)
            }
        }

        // Find buildings marked for removal (if any other systems use this)
        // This could be extended for other entity types that need cleanup

        // Remove all marked entities
        for entity in entitiesToRemove {
            removeEntity(entity)
        }
    }

    private func removeEntity(_ entity: Entity) {
        // Get position before removing (needed for chunk cleanup)
        guard let position = world.get(PositionComponent.self, for: entity) else {
            // Entity has no position, just despawn it
            world.despawn(entity)
            return
        }

        let tilePosition = position.tilePosition

        // Remove from chunk
        if let chunk = chunkManager.getChunk(at: tilePosition) {
            chunk.removeEntity(entity)
        }

        // Log cleanup for debugging
        if let _ = world.get(TreeComponent.self, for: entity) {
            print("EntityCleanupSystem: Removing depleted tree at \(tilePosition)")
        }

        // Despawn the entity
        world.despawn(entity)
    }
}
