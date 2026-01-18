import Metal
import Foundation

/// 3D Terrain renderer that creates and manages terrain chunks
@available(iOS 17.0, *)
final class TerrainRenderer3D {
    private let device: MTLDevice
    private let modelGenerator: Model3DGenerator
    private var terrainChunks: [ChunkCoord: TerrainChunk3D] = [:]
    private var chunkManager: ChunkManager

    init(device: MTLDevice, chunkManager: ChunkManager) {
        self.device = device
        self.chunkManager = chunkManager
        self.modelGenerator = Model3DGenerator(device: device)
    }

    /// Updates terrain chunks based on loaded chunks
    func updateTerrainChunks() {
        let loadedChunks = chunkManager.allLoadedChunks

        // Remove chunks that are no longer loaded
        let loadedCoords = Set(loadedChunks.map { $0.coord })
        terrainChunks = terrainChunks.filter { loadedCoords.contains($0.key) }

        // Add new chunks
        for chunk in loadedChunks {
            if terrainChunks[chunk.coord] == nil {
                createTerrainChunk(for: chunk)
            }
        }
    }

    private func createTerrainChunk(for chunk: Chunk) {
        // Extract height map and tile types from chunk
        var heightMap = Array(repeating: Array(repeating: Float(0), count: Chunk.size), count: Chunk.size)
        var tileTypes = Array(repeating: Array(repeating: TileType.grass, count: Chunk.size), count: Chunk.size)

        for y in 0..<Chunk.size {
            for x in 0..<Chunk.size {
                heightMap[y][x] = chunk.getHeight(localX: x, localY: y)
                if let tile = chunk.getTile(localX: x, localY: y) {
                    tileTypes[y][x] = tile.type
                }
            }
        }

        let terrainChunk = modelGenerator.createTerrainChunk(
            width: Chunk.size,
            height: Chunk.size,
            heightMap: heightMap,
            tileTypes: tileTypes
        )

        terrainChunks[chunk.coord] = terrainChunk
    }

    /// Gets all terrain chunks for rendering
    func getTerrainChunks() -> [TerrainChunk3D] {
        return Array(terrainChunks.values)
    }

    /// Updates a specific chunk when terrain changes
    func updateChunk(at coord: ChunkCoord) {
        guard let chunk = chunkManager.getChunkByCoord(coord) else { return }
        createTerrainChunk(for: chunk)
    }

    /// Modifies terrain height at a specific position
    func modifyTerrain(at worldPos: IntVector2, heightDelta: Float, radius: Int = 1) {
        let chunkCoord = Chunk.worldToChunk(worldPos)
        guard let chunk = chunkManager.getChunk(at: worldPos) else { return }

        let localX = Int(worldPos.x - chunkCoord.x * Int32(Chunk.size))
        let localY = Int(worldPos.y - chunkCoord.y * Int32(Chunk.size))

        // Apply height modification in a radius
        for dy in -radius...radius {
            for dx in -radius...radius {
                let x = localX + dx
                let y = localY + dy

                if x >= 0 && x < Chunk.size && y >= 0 && y < Chunk.size {
                    let distance = sqrt(Float(dx*dx + dy*dy))
                    if distance <= Float(radius) {
                        let falloff = 1.0 - (distance / Float(radius))
                        let currentHeight = chunk.getHeight(localX: x, localY: y)
                        chunk.setHeight(localX: x, localY: y, height: currentHeight + heightDelta * falloff)
                    }
                }
            }
        }

        // Update the terrain chunk
        updateChunk(at: chunkCoord)
    }
}