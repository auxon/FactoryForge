import Foundation

/// Chunk-based interest management: which entities/chunks to sync to which clients.
/// Leverages ChunkManager; only entities in loaded chunks near player positions are sent.
final class InterestManager {
    private let chunkManager: ChunkManager
    private let loadRadius: Int

    init(chunkManager: ChunkManager, loadRadius: Int = 3) {
        self.chunkManager = chunkManager
        self.loadRadius = loadRadius
    }

    /// Chunk coordinates considered "visible" for a player at the given tile position.
    func visibleChunkCoords(aroundPlayerTilePosition playerTile: IntVector2) -> Set<ChunkCoord> {
        let playerChunk = Chunk.worldToChunk(playerTile)
        var coords: Set<ChunkCoord> = []
        for dy in -loadRadius ... loadRadius {
            for dx in -loadRadius ... loadRadius {
                coords.insert(ChunkCoord(x: playerChunk.x + Int32(dx), y: playerChunk.y + Int32(dy)))
            }
        }
        return coords
    }

    /// Union of visible chunk coords for all given player positions.
    func visibleChunkCoords(aroundPlayerPositions positions: [Vector2]) -> Set<ChunkCoord> {
        var all = Set<ChunkCoord>()
        for p in positions {
            let tile = IntVector2(from: p)
            all.formUnion(visibleChunkCoords(aroundPlayerTilePosition: tile))
        }
        return all
    }

    /// Returns loaded chunks that are in the visible set for the given player positions.
    /// Use ChunkManager.allLoadedChunks and filter by visible coords.
    func relevantChunkCoords(aroundPlayerPositions positions: [Vector2]) -> Set<ChunkCoord> {
        let visible = visibleChunkCoords(aroundPlayerPositions: positions)
        let loaded = Set(chunkManager.allLoadedChunks.map { $0.coord })
        return visible.intersection(loaded)
    }
}
