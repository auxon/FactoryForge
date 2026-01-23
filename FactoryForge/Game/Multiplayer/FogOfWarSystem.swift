import Foundation

/// Server-authoritative visibility for fog of war.
/// Reveals areas from player/unit/building positions; clients hide enemy entities in unexplored areas.
///
/// Integration: Create with World + PlayerManager, call `update()` each tick (e.g. from GameLoop).
/// When rendering entities for a local player, skip or dim entities where
/// `shouldHide(entity:from: localPlayerId)` is true.
final class FogOfWarSystem {
    private let world: World
    private let playerManager: PlayerManager
    
    /// Chunks ever revealed to each player (explored).
    private var exploredChunks: [UInt32: Set<ChunkCoord>] = [:]
    /// Chunks currently in vision of each player (visible).
    private var visibleChunks: [UInt32: Set<ChunkCoord>] = [:]
    private let lock = NSLock()
    
    /// Vision radius in chunks: player entities.
    var playerVisionRadiusChunks: Int = 2
    /// Vision radius in chunks: owned units and buildings.
    var unitBuildingVisionRadiusChunks: Int = 1
    /// If true, FoW is disabled (all visible).
    var isEnabled: Bool = true

    init(world: World, playerManager: PlayerManager) {
        self.world = world
        self.playerManager = playerManager
    }

    /// Call each tick to recompute visibility from vision sources.
    func update() {
        guard isEnabled else { return }
        lock.lock()
        defer { lock.unlock() }
        
        var newVisible: [UInt32: Set<ChunkCoord>] = [:]
        var newExplored: [UInt32: Set<ChunkCoord>] = [:]
        
        for player in playerManager.getAllPlayers() {
            let pid = player.playerId
            var visible: Set<ChunkCoord> = []
            var explored: Set<ChunkCoord> = exploredChunks[pid] ?? []
            
            // Vision from player entity
            let playerChunk = Chunk.worldToChunk(IntVector2(from: player.position))
            addChunksInRadius(center: playerChunk, radius: playerVisionRadiusChunks, into: &visible)
            explored.formUnion(visible)
            
            // Vision from owned units and buildings (Position + Ownership)
            let owned = world.query(PositionComponent.self, OwnershipComponent.self)
            for entity in owned {
                guard let ownership = world.get(OwnershipComponent.self, for: entity),
                      ownership.ownerPlayerId == pid,
                      let pos = world.get(PositionComponent.self, for: entity) else { continue }
                let chunk = Chunk.worldToChunk(pos.tilePosition)
                let radius = world.has(PlayerComponent.self, for: entity)
                    ? playerVisionRadiusChunks
                    : unitBuildingVisionRadiusChunks
                addChunksInRadius(center: chunk, radius: radius, into: &visible)
            }
            explored.formUnion(visible)
            
            newVisible[pid] = visible
            newExplored[pid] = explored
        }
        
        visibleChunks = newVisible
        exploredChunks = newExplored
    }

    /// Chunks currently visible to `playerId`.
    func visibleChunks(for playerId: UInt32) -> Set<ChunkCoord> {
        lock.lock()
        defer { lock.unlock() }
        if !isEnabled { return [] }
        return visibleChunks[playerId] ?? []
    }

    /// Chunks ever explored by `playerId`.
    func exploredChunks(for playerId: UInt32) -> Set<ChunkCoord> {
        lock.lock()
        defer { lock.unlock() }
        if !isEnabled { return [] }
        return exploredChunks[playerId] ?? []
    }

    /// True if `chunk` is currently visible to `playerId`.
    func isVisible(to playerId: UInt32, chunk: ChunkCoord) -> Bool {
        guard isEnabled else { return true }
        lock.lock()
        defer { lock.unlock() }
        return visibleChunks[playerId]?.contains(chunk) ?? false
    }

    /// True if `chunk` was ever explored by `playerId`.
    func isExplored(to playerId: UInt32, chunk: ChunkCoord) -> Bool {
        guard isEnabled else { return true }
        lock.lock()
        defer { lock.unlock() }
        return exploredChunks[playerId]?.contains(chunk) ?? false
    }

    /// True if `entity`'s chunk is currently visible to `playerId`.
    func isVisible(to playerId: UInt32, entity: Entity) -> Bool {
        guard isEnabled else { return true }
        guard let pos = world.get(PositionComponent.self, for: entity) else { return false }
        return isVisible(to: playerId, chunk: Chunk.worldToChunk(pos.tilePosition))
    }

    /// True if `entity` should be hidden from `viewerPlayerId` (enemy in unexplored area).
    /// Use when rendering: hide enemies that are not visible.
    func shouldHide(entity: Entity, from viewerPlayerId: UInt32) -> Bool {
        guard isEnabled else { return false }
        if isVisible(to: viewerPlayerId, entity: entity) { return false }
        guard let ownership = world.get(OwnershipComponent.self, for: entity) else {
            return true
        }
        if ownership.ownerPlayerId == viewerPlayerId { return false }
        if let vTeam = team(of: viewerPlayerId),
           let eTeam = ownership.teamId,
           vTeam == eTeam {
            return false
        }
        return true
    }

    /// Resets explored/visible state (e.g. new match).
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        exploredChunks.removeAll()
        visibleChunks.removeAll()
    }

    // MARK: - Private

    private func addChunksInRadius(center: ChunkCoord, radius: Int, into set: inout Set<ChunkCoord>) {
        for dy in -radius...radius {
            for dx in -radius...radius {
                set.insert(ChunkCoord(x: center.x + Int32(dx), y: center.y + Int32(dy)))
            }
        }
    }

    private func team(of playerId: UInt32) -> UInt32? {
        guard let entity = playerManager.getPlayerEntity(playerId: playerId),
              let ownership = world.get(OwnershipComponent.self, for: entity) else {
            return nil
        }
        return ownership.teamId
    }
}
