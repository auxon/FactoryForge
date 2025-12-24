import Foundation

/// Biome types for world generation
enum Biome: String, Codable, CaseIterable {
    case grassland
    case desert
    case forest
    case swamp
    case tundra
    case volcanic
    
    /// Primary tile type for this biome
    var primaryTile: TileType {
        switch self {
        case .grassland: return .grass
        case .desert: return .sand
        case .forest: return .grass
        case .swamp: return .dirt
        case .tundra: return .stone
        case .volcanic: return .stone
        }
    }
    
    /// Secondary tile type for variety
    var secondaryTile: TileType {
        switch self {
        case .grassland: return .dirt
        case .desert: return .stone
        case .forest: return .dirt
        case .swamp: return .water
        case .tundra: return .dirt
        case .volcanic: return .dirt
        }
    }
    
    /// Probability of trees in this biome
    var treeChance: Float {
        switch self {
        case .grassland: return 0.02
        case .desert: return 0.001
        case .forest: return 0.15
        case .swamp: return 0.05
        case .tundra: return 0.01
        case .volcanic: return 0
        }
    }
    
    /// Probability of water in this biome
    var waterChance: Float {
        switch self {
        case .grassland: return 0.05
        case .desert: return 0.01
        case .forest: return 0.03
        case .swamp: return 0.3
        case .tundra: return 0.02
        case .volcanic: return 0.02
        }
    }
    
    /// Resource frequency modifier
    var resourceModifier: Float {
        switch self {
        case .grassland: return 1.0
        case .desert: return 0.7
        case .forest: return 0.8
        case .swamp: return 0.6
        case .tundra: return 0.9
        case .volcanic: return 1.2
        }
    }
    
    /// Enemy nest frequency modifier
    var nestModifier: Float {
        switch self {
        case .grassland: return 1.0
        case .desert: return 1.5
        case .forest: return 0.7
        case .swamp: return 1.2
        case .tundra: return 0.8
        case .volcanic: return 2.0
        }
    }
    
    /// Pollution absorption rate per chunk
    var pollutionAbsorption: Float {
        switch self {
        case .grassland: return 1.0
        case .desert: return 0.3
        case .forest: return 3.0
        case .swamp: return 2.0
        case .tundra: return 0.5
        case .volcanic: return 0.1
        }
    }
}

/// Biome generator using noise
struct BiomeGenerator {
    private let temperatureNoise: PerlinNoise
    private let humidityNoise: PerlinNoise
    private let scale: Float = 0.005
    
    init(seed: UInt64) {
        temperatureNoise = PerlinNoise(seed: seed)
        humidityNoise = PerlinNoise(seed: seed ^ 0xDEADBEEF)
    }
    
    func getBiome(at position: Vector2) -> Biome {
        let temperature = temperatureNoise.octaveNoise(
            x: position.x * scale,
            y: position.y * scale,
            octaves: 3,
            persistence: 0.5
        )
        
        let humidity = humidityNoise.octaveNoise(
            x: position.x * scale,
            y: position.y * scale,
            octaves: 3,
            persistence: 0.5
        )
        
        // Map noise values to biomes
        if temperature > 0.3 {
            if humidity > 0.2 {
                return .forest
            } else if humidity < -0.2 {
                return .desert
            } else {
                return .grassland
            }
        } else if temperature < -0.3 {
            return .tundra
        } else {
            if humidity > 0.3 {
                return .swamp
            } else if humidity < -0.3 {
                return .volcanic
            } else {
                return .grassland
            }
        }
    }
    
    func getBiome(at chunkCoord: ChunkCoord) -> Biome {
        let worldPos = Vector2(
            Float(chunkCoord.x) * Chunk.sizeFloat + Chunk.sizeFloat / 2,
            Float(chunkCoord.y) * Chunk.sizeFloat + Chunk.sizeFloat / 2
        )
        return getBiome(at: worldPos)
    }
}

