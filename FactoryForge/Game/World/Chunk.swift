import Foundation

/// Chunk coordinate (integer position in chunk space)
typealias ChunkCoord = IntVector2

/// A chunk of the game world (32x32 tiles)
final class Chunk {
    static let size: Int = 32
    static let sizeFloat: Float = Float(size)
    
    /// Chunk coordinate
    let coord: ChunkCoord
    
    /// Tiles in this chunk
    private var tiles: [[Tile]]
    
    /// Entities in this chunk
    private var entities: Set<Entity> = []

    /// Cached tile instances for rendering
    private var cachedTileInstances: [TileInstance] = []
    private var tilesDirty: Bool = true

    /// Pollution level (0-1+)
    var pollution: Float = 0
    
    /// Whether this chunk has been modified
    var isDirty: Bool = false
    
    /// Whether this chunk is currently loaded
    var isLoaded: Bool = true
    
    /// Biome of this chunk
    let biome: Biome
    
    /// Spawner positions in this chunk (world coordinates)
    var spawnerPositions: [IntVector2] = []
    
    init(coord: ChunkCoord, biome: Biome) {
        self.coord = coord
        self.biome = biome
        self.tiles = Array(repeating: Array(repeating: Tile(type: .grass), count: Chunk.size), count: Chunk.size)
    }
    
    // MARK: - Tile Access
    
    /// Gets a tile at local coordinates
    func getTile(localX: Int, localY: Int) -> Tile? {
        guard localX >= 0 && localX < Chunk.size && localY >= 0 && localY < Chunk.size else {
            return nil
        }
        return tiles[localY][localX]
    }
    
    /// Sets a tile at local coordinates
    func setTile(localX: Int, localY: Int, tile: Tile) {
        guard localX >= 0 && localX < Chunk.size && localY >= 0 && localY < Chunk.size else {
            return
        }
        tiles[localY][localX] = tile
        tilesDirty = true
        isDirty = true
    }
    
    /// Gets the resource deposit at local coordinates
    func getResource(localX: Int, localY: Int) -> ResourceDeposit? {
        return getTile(localX: localX, localY: localY)?.resource
    }
    
    /// Mines from a resource at local coordinates
    @discardableResult
    func mineResource(localX: Int, localY: Int, amount: Int = 1) -> Int {
        guard localX >= 0 && localX < Chunk.size && localY >= 0 && localY < Chunk.size else {
            return 0
        }
        guard var resource = tiles[localY][localX].resource else { return 0 }
        
        let mined = resource.mine(amount: amount)
        tiles[localY][localX].resource = resource.isEmpty ? nil : resource
        tilesDirty = true
        isDirty = true
        return mined
    }
    
    // MARK: - Entity Management
    
    func addEntity(_ entity: Entity, at position: IntVector2) {
        entities.insert(entity)
    }
    
    func removeEntity(_ entity: Entity) {
        entities.remove(entity)
    }
    
    func getEntities() -> Set<Entity> {
        return entities
    }
    
    // MARK: - World Coordinates
    
    /// Converts world tile position to chunk coordinate
    static func worldToChunk(_ worldPos: IntVector2) -> ChunkCoord {
        return ChunkCoord(
            x: worldPos.x >= 0 ? worldPos.x / Int32(size) : (worldPos.x + 1) / Int32(size) - 1,
            y: worldPos.y >= 0 ? worldPos.y / Int32(size) : (worldPos.y + 1) / Int32(size) - 1
        )
    }
    
    /// Converts world tile position to local chunk position
    static func worldToLocal(_ worldPos: IntVector2) -> (x: Int, y: Int) {
        var localX = Int(worldPos.x) % size
        var localY = Int(worldPos.y) % size
        if localX < 0 { localX += size }
        if localY < 0 { localY += size }
        return (localX, localY)
    }
    
    /// Gets the world position of the chunk's origin
    var worldOrigin: IntVector2 {
        return IntVector2(x: coord.x * Int32(Chunk.size), y: coord.y * Int32(Chunk.size))
    }
    
    /// Gets the world bounds of this chunk
    var worldBounds: Rect {
        let origin = worldOrigin.toVector2
        return Rect(origin: origin, size: Vector2(Chunk.sizeFloat, Chunk.sizeFloat))
    }
    
    // MARK: - Rendering
    
    /// Creates tile instances for rendering
    func getTileInstances() -> [TileInstance] {
        if !tilesDirty {
            return cachedTileInstances
        }

        var instances: [TileInstance] = []
        instances.reserveCapacity(Chunk.size * Chunk.size)
        
        let origin = worldOrigin
        
        for y in 0..<Chunk.size {
            for x in 0..<Chunk.size {
                let tile = tiles[y][x]
                let worldPos = IntVector2(x: origin.x + Int32(x), y: origin.y + Int32(y))
                instances.append(tile.toInstance(at: worldPos))
            }
        }

        cachedTileInstances = instances
        tilesDirty = false
        return instances
    }
    
    // MARK: - Pollution
    
    func addPollution(_ amount: Float) {
        pollution += amount
        isDirty = true
    }
    
    func absorbPollution(_ amount: Float) -> Float {
        let absorbed = min(amount, pollution)
        pollution -= absorbed
        if absorbed > 0 { isDirty = true }
        return absorbed
    }
}

// MARK: - Serialization

extension Chunk {
    func serialize() -> ChunkData {
        var tileData: [[TileData]] = []
        for row in tiles {
            tileData.append(row.map { TileData(type: $0.type.rawValue, variation: $0.variation, resource: $0.resource) })
        }
        return ChunkData(
            coordX: coord.x,
            coordY: coord.y,
            tiles: tileData,
            pollution: pollution,
            biome: biome.rawValue,
            spawnerPositions: spawnerPositions.map { [$0.x, $0.y] }
        )
    }
    
    static func deserialize(_ data: ChunkData) -> Chunk {
        let chunk = Chunk(
            coord: ChunkCoord(x: data.coordX, y: data.coordY),
            biome: Biome(rawValue: data.biome) ?? .grassland
        )
        
        for (y, row) in data.tiles.enumerated() {
            for (x, tileData) in row.enumerated() {
                let type = TileType(rawValue: tileData.type) ?? .grass
                chunk.tiles[y][x] = Tile(type: type, variation: tileData.variation, resource: tileData.resource)
            }
        }
        
        chunk.pollution = data.pollution
        chunk.spawnerPositions = (data.spawnerPositions ?? []).compactMap {
            guard $0.count == 2 else { return nil }
            return IntVector2(x: Int32($0[0]), y: Int32($0[1]))
        }
        return chunk
    }
}

struct ChunkData: Codable {
    let coordX: Int32
    let coordY: Int32
    let tiles: [[TileData]]
    let pollution: Float
    let biome: String
    let spawnerPositions: [[Int32]]?
}

struct TileData: Codable {
    let type: UInt16
    let variation: UInt8
    let resource: ResourceDeposit?
}
