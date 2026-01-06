import Foundation

/// Manages chunk loading, unloading, and generation
final class ChunkManager {
    /// Loaded chunks
    private var chunks: [ChunkCoord: Chunk] = [:]
    
    /// World generation seed
    private(set) var seed: UInt64
    
    /// World generator
    private var worldGenerator: WorldGenerator
    
    /// Biome generator
    private var biomeGenerator: BiomeGenerator
    
    /// Load radius in chunks (reduced for performance)
    let loadRadius: Int = 1
    
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
    
    /// Updates the seed and recreates generators (used when loading a save with a different seed)
    func updateSeed(_ newSeed: UInt64) {
        guard newSeed != seed else { return }
        self.seed = newSeed
        print("ChunkManager: Updated seed to: \(newSeed)")
        self.worldGenerator = WorldGenerator(seed: newSeed)
        self.biomeGenerator = BiomeGenerator(seed: newSeed)
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
            // Generate new chunk (chunk file doesn't exist or failed to load)
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
    
    /// Clears all loaded chunks
    /// - Parameter saveDirty: If true, saves dirty chunks before clearing. If false, discards them (use when loading a game to avoid overwriting saved chunks)
    /// Note: This should be called AFTER setSaveSlot() when loading, so chunks load from the correct directory
    func clearLoadedChunks(saveDirty: Bool = true) {
        if saveDirty {
            // Only save dirty chunks if we have a valid save slot set
            // This prevents saving chunks from one slot to another when switching saves
            if let slotName = currentSaveSlot {
                var savedCount = 0
                for (_, chunk) in chunks {
                    if chunk.isDirty {
                        saveChunkToDisk(chunk)
                        savedCount += 1
                    }
                }
                if savedCount > 0 {
                    print("ChunkManager: Saved \(savedCount) dirty chunks before clearing (slot: \(slotName))")
                }
            } else {
                print("ChunkManager: WARNING - clearLoadedChunks called without save slot set, not saving dirty chunks")
            }
        } else {
            print("ChunkManager: Clearing chunks without saving (loading game - discarding incorrectly generated chunks)")
        }
        chunks.removeAll()
        loadedChunks.removeAll()
        print("ChunkManager: Cleared all loaded chunks (save slot: \(currentSaveSlot ?? "nil"))")
    }
    
    /// Force loads chunks around a specific position (used when loading a save)
    /// This ensures chunks are loaded from disk before they can be regenerated
    func forceLoadChunksAround(position: Vector2) {
        let playerChunk = Chunk.worldToChunk(IntVector2(from: position))
        
        // Load chunks in a larger radius to ensure all nearby chunks are loaded
        let loadRadius = self.loadRadius + 2  // Load extra chunks to be safe
        
        for dy in -loadRadius...loadRadius {
            for dx in -loadRadius...loadRadius {
                let coord = ChunkCoord(x: playerChunk.x + Int32(dx), y: playerChunk.y + Int32(dy))
                
                // Only load if not already loaded
                if !loadedChunks.contains(coord) {
                    loadChunk(at: coord)
                }
            }
        }
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
    
    /// Current save slot name (used to organize chunks per save slot)
    private var currentSaveSlot: String? = nil
    
    /// Sets the current save slot for chunk persistence
    func setSaveSlot(_ slotName: String?) {
        currentSaveSlot = slotName
        print("ChunkManager: Set save slot to: \(slotName ?? "nil")")
    }
    
    /// Saves all currently loaded chunks to disk (used before saving the game)
    func saveAllChunks() {
        guard currentSaveSlot != nil else {
            print("ChunkManager: Warning - saving chunks without a save slot set")
            return
        }
        
        for (_, chunk) in chunks {
            saveChunkToDisk(chunk)
            // Mark as not dirty since we just saved it
            chunk.isDirty = false
        }
        print("ChunkManager: Saved \(chunks.count) chunks to disk for slot: \(currentSaveSlot ?? "unknown")")
    }
    
    private func saveChunkToDisk(_ chunk: Chunk) {
        guard let slotName = currentSaveSlot else {
            print("ChunkManager: ERROR - Cannot save chunk at (\(chunk.coord.x), \(chunk.coord.y)) - no save slot set")
            return
        }
        
        let data = chunk.serialize()
        let filename = "chunk_\(chunk.coord.x)_\(chunk.coord.y).json"
        
        guard let saveDir = getSaveDirectory(for: slotName) else {
            print("ChunkManager: ERROR - Cannot get save directory for slot: \(slotName)")
            return
        }
        
        let url = saveDir.appendingPathComponent(filename)
        do {
            let jsonData = try JSONEncoder().encode(data)
            try jsonData.write(to: url)
            print("ChunkManager: Saved chunk at (\(chunk.coord.x), \(chunk.coord.y)) to slot: \(slotName) at \(url.path)")
        } catch {
            print("ChunkManager: ERROR - Failed to save chunk at (\(chunk.coord.x), \(chunk.coord.y)): \(error)")
        }
    }
    
    private func loadChunkFromDisk(_ coord: ChunkCoord) -> Chunk? {
        guard let slotName = currentSaveSlot else {
            print("ChunkManager: WARNING - Cannot load chunk at (\(coord.x), \(coord.y)) - no save slot set")
            return nil
        }
        
        let filename = "chunk_\(coord.x)_\(coord.y).json"
        
        guard let saveDir = getSaveDirectory(for: slotName) else {
            print("ChunkManager: ERROR - Cannot get save directory for slot: \(slotName)")
            return nil
        }
        
        let url = saveDir.appendingPathComponent(filename)
        
        // Check if file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            print("ChunkManager: Chunk file does not exist at \(url.path)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let chunkData = try JSONDecoder().decode(ChunkData.self, from: data)
            let chunk = Chunk.deserialize(chunkData)
            return chunk
        } catch {
            print("ChunkManager: ERROR - Failed to load chunk at (\(coord.x), \(coord.y)) from slot: \(slotName), path: \(url.path), error: \(error)")
            return nil
        }
    }
    
    private func getSaveDirectory(for slotName: String) -> URL? {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsDir = paths.first else { return nil }
        
        // Organize chunks per save slot
        let saveDir = documentsDir.appendingPathComponent("saves/chunks/\(slotName)")
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

