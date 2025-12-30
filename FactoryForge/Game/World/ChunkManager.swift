import Foundation

/// Manages chunk loading, unloading, and generation
final class ChunkManager {
    /// Loaded chunks
    private var chunks: [ChunkCoord: Chunk] = [:]
    
    /// World generation seed
    let seed: UInt64
    
    /// World generator
    private let worldGenerator: WorldGenerator
    
    /// Biome generator
    private let biomeGenerator: BiomeGenerator
    
    /// Load radius in chunks
    let loadRadius: Int = 3
    
    /// Currently loaded chunk coordinates
    private var loadedChunks: Set<ChunkCoord> = []
    
    /// Chunks queued for saving
    private var dirtyChunks: Set<ChunkCoord> = []
    
    init(seed: UInt64) {
        self.seed = seed
        print("ChunkManager: Initialized with seed: \(seed)")
        self.worldGenerator = WorldGenerator(seed: seed)
        self.biomeGenerator = BiomeGenerator(seed: seed)
    }
    
    // MARK: - Chunk Loading
    
    /// Updates loaded chunks based on player position
    func update(playerPosition: Vector2) {
        let playerChunk = Chunk.worldToChunk(IntVector2(from: playerPosition))
        
        var chunksToLoad: Set<ChunkCoord> = []
        var chunksToUnload: Set<ChunkCoord> = []
        
        // Determine which chunks should be loaded
        for dy in -loadRadius...loadRadius {
            for dx in -loadRadius...loadRadius {
                let coord = ChunkCoord(x: playerChunk.x + Int32(dx), y: playerChunk.y + Int32(dy))
                chunksToLoad.insert(coord)
            }
        }
        
        // Find chunks to unload
        for coord in loadedChunks {
            if !chunksToLoad.contains(coord) {
                chunksToUnload.insert(coord)
            }
        }
        
        // Unload chunks
        for coord in chunksToUnload {
            unloadChunk(at: coord)
        }
        
        // Load new chunks
        for coord in chunksToLoad {
            if !loadedChunks.contains(coord) {
                loadChunk(at: coord)
            }
        }
    }
    
    private func loadChunk(at coord: ChunkCoord) {
        // Try to load from disk first
        if let savedChunk = loadChunkFromDisk(coord) {
            chunks[coord] = savedChunk
        } else {
            // Generate new chunk
            let biome = biomeGenerator.getBiome(at: coord)
            let chunk = worldGenerator.generateChunk(at: coord, biome: biome)
            chunks[coord] = chunk
        }

        loadedChunks.insert(coord)
    }
    
    private func unloadChunk(at coord: ChunkCoord) {
        if let chunk = chunks[coord], chunk.isDirty {
            saveChunkToDisk(chunk)
        }
        chunks.removeValue(forKey: coord)
        loadedChunks.remove(coord)
    }
    
    // MARK: - Tile Access
    
    func getTile(at worldPos: IntVector2) -> Tile? {
        let chunkCoord = Chunk.worldToChunk(worldPos)
        let (localX, localY) = Chunk.worldToLocal(worldPos)
        return chunks[chunkCoord]?.getTile(localX: localX, localY: localY)
    }
    
    func setTile(at worldPos: IntVector2, tile: Tile) {
        let chunkCoord = Chunk.worldToChunk(worldPos)
        let (localX, localY) = Chunk.worldToLocal(worldPos)
        chunks[chunkCoord]?.setTile(localX: localX, localY: localY, tile: tile)
    }
    
    func getResource(at worldPos: IntVector2) -> ResourceDeposit? {
        return getTile(at: worldPos)?.resource
    }
    
    func mineResource(at worldPos: IntVector2, amount: Int = 1) -> Int {
        let chunkCoord = Chunk.worldToChunk(worldPos)
        let (localX, localY) = Chunk.worldToLocal(worldPos)
        return chunks[chunkCoord]?.mineResource(localX: localX, localY: localY, amount: amount) ?? 0
    }
    
    // MARK: - Chunk Access
    
    func getChunk(at worldPos: IntVector2) -> Chunk? {
        let chunkCoord = Chunk.worldToChunk(worldPos)
        return chunks[chunkCoord]
    }
    
    func getChunkByCoord(_ coord: ChunkCoord) -> Chunk? {
        return chunks[coord]
    }
    
    var allLoadedChunks: [Chunk] {
        return Array(chunks.values)
    }
    
    /// Clears all loaded chunks (used when loading a save to force reload from disk)
    func clearLoadedChunks() {
        // Save any dirty chunks before clearing
        for (_, chunk) in chunks {
            if chunk.isDirty {
                saveChunkToDisk(chunk)
            }
        }
        chunks.removeAll()
        loadedChunks.removeAll()
        print("ChunkManager: Cleared all loaded chunks")
    }
    
    // MARK: - Rendering
    
    func render(renderer: MetalRenderer, camera: Camera2D) {
        // Expand visible rect significantly to ensure all visible chunks are included
        let visibleRect = camera.visibleRect.expanded(by: Chunk.sizeFloat * 2)

        for chunk in chunks.values {
            if chunk.worldBounds.intersects(visibleRect) {
                renderer.queueTiles(chunk.getTileInstances())
            }
        }
    }
    
    // MARK: - Persistence
    
    /// Saves all currently loaded chunks to disk (used before saving the game)
    func saveAllChunks() {
        for (_, chunk) in chunks {
            saveChunkToDisk(chunk)
            // Mark as not dirty since we just saved it
            chunk.isDirty = false
        }
        print("ChunkManager: Saved \(chunks.count) chunks to disk")
    }
    
    private func saveChunkToDisk(_ chunk: Chunk) {
        // TODO: Implement chunk saving
        let data = chunk.serialize()
        let filename = "chunk_\(chunk.coord.x)_\(chunk.coord.y).json"
        
        if let saveDir = getSaveDirectory() {
            let url = saveDir.appendingPathComponent(filename)
            if let jsonData = try? JSONEncoder().encode(data) {
                try? jsonData.write(to: url)
            }
        }
    }
    
    private func loadChunkFromDisk(_ coord: ChunkCoord) -> Chunk? {
        let filename = "chunk_\(coord.x)_\(coord.y).json"
        
        guard let saveDir = getSaveDirectory() else { return nil }
        let url = saveDir.appendingPathComponent(filename)
        
        guard let data = try? Data(contentsOf: url),
              let chunkData = try? JSONDecoder().decode(ChunkData.self, from: data) else {
            return nil
        }
        
        return Chunk.deserialize(chunkData)
    }
    
    private func getSaveDirectory() -> URL? {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsDir = paths.first else { return nil }
        
        let saveDir = documentsDir.appendingPathComponent("saves/chunks")
        try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
        return saveDir
    }
    
    // MARK: - Pollution
    
    func addPollution(at worldPos: IntVector2, amount: Float) {
        let chunkCoord = Chunk.worldToChunk(worldPos)
        chunks[chunkCoord]?.addPollution(amount)
    }
    
    func getPollution(at worldPos: IntVector2) -> Float {
        let chunkCoord = Chunk.worldToChunk(worldPos)
        return chunks[chunkCoord]?.pollution ?? 0
    }
    
    /// Spreads pollution between chunks
    func spreadPollution(deltaTime: Float) {
        let spreadRate: Float = 0.1 * deltaTime
        
        var pollutionChanges: [ChunkCoord: Float] = [:]
        
        for (coord, chunk) in chunks {
            guard chunk.pollution > 0 else { continue }
            
            let biome = chunk.biome
            let absorption = biome.pollutionAbsorption * deltaTime * 0.01
            let absorbed = min(absorption, chunk.pollution)
            pollutionChanges[coord, default: 0] -= absorbed
            
            // Spread to neighbors
            let spreadAmount = chunk.pollution * spreadRate
            let neighborOffsets: [IntVector2] = [
                IntVector2(1, 0), IntVector2(-1, 0),
                IntVector2(0, 1), IntVector2(0, -1)
            ]
            
            for offset in neighborOffsets {
                let neighborCoord = coord + offset
                if chunks[neighborCoord] != nil {
                    pollutionChanges[neighborCoord, default: 0] += spreadAmount / 4
                    pollutionChanges[coord, default: 0] -= spreadAmount / 4
                }
            }
        }
        
        // Apply changes
        for (coord, change) in pollutionChanges {
            chunks[coord]?.pollution = max(0, (chunks[coord]?.pollution ?? 0) + change)
        }
    }
}

