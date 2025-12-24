import Metal
import simd

/// Renders tile maps using instanced rendering for efficiency
final class TileMapRenderer {
    private let device: MTLDevice
    private let textureAtlas: TextureAtlas
    
    // Vertex buffer for a single quad
    private let quadVertexBuffer: MTLBuffer
    
    // Instance buffer for tile data
    private var instanceBuffer: MTLBuffer?
    private var instanceCount: Int = 0
    private let maxInstances = 10000
    
    // Queued tiles for current frame
    private var queuedTiles: [TileInstance] = []
    
    init(device: MTLDevice, library: MTLLibrary, textureAtlas: TextureAtlas) {
        self.device = device
        self.textureAtlas = textureAtlas
        
        // Create quad vertices
        let vertices: [TileVertex] = [
            TileVertex(position: Vector2(0, 0), texCoord: Vector2(0, 1)),
            TileVertex(position: Vector2(1, 0), texCoord: Vector2(1, 1)),
            TileVertex(position: Vector2(1, 1), texCoord: Vector2(1, 0)),
            TileVertex(position: Vector2(0, 0), texCoord: Vector2(0, 1)),
            TileVertex(position: Vector2(1, 1), texCoord: Vector2(1, 0)),
            TileVertex(position: Vector2(0, 1), texCoord: Vector2(0, 0))
        ]
        
        guard let buffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<TileVertex>.stride * vertices.count,
            options: .storageModeShared
        ) else {
            fatalError("Failed to create quad vertex buffer")
        }
        quadVertexBuffer = buffer
        
        // Create instance buffer
        instanceBuffer = device.makeBuffer(
            length: MemoryLayout<TileInstanceData>.stride * maxInstances,
            options: .storageModeShared
        )
    }
    
    func queue(_ tiles: [TileInstance]) {
        queuedTiles.append(contentsOf: tiles)
    }
    
    func render(encoder: MTLRenderCommandEncoder, viewProjection: Matrix4, camera: Camera2D) {
        guard !queuedTiles.isEmpty else { return }
        guard let instanceBuffer = instanceBuffer else { return }
        
        // Convert queued tiles to instance data
        var instances: [TileInstanceData] = []
        instances.reserveCapacity(min(queuedTiles.count, maxInstances))
        
        // Expand visible rect generously to ensure all visible tiles are included
        let visibleRect = camera.visibleRect.expanded(by: 5)
        
        // Frustum cull first, then limit to maxInstances
        for tile in queuedTiles {
            let worldPos = tile.position.toVector2
            
            // Frustum culling - skip tiles outside visible area
            guard visibleRect.contains(worldPos) else { continue }
            
            // Get texture UV from atlas based on tile type
            let textureRect = getTileTextureRect(for: tile)
            
            instances.append(TileInstanceData(
                position: worldPos,
                uvOrigin: Vector2(textureRect.origin.x, textureRect.origin.y),
                uvSize: Vector2(textureRect.size.x, textureRect.size.y),
                tint: tile.tint.vector4
            ))
            
            // Stop if we've hit the instance limit
            if instances.count >= maxInstances { break }
        }
        
        queuedTiles.removeAll(keepingCapacity: true)
        
        guard !instances.isEmpty else { return }
        
        // Update instance buffer
        instanceBuffer.contents().copyMemory(
            from: instances,
            byteCount: MemoryLayout<TileInstanceData>.stride * instances.count
        )
        instanceCount = instances.count
        
        // Set uniforms
        var uniforms = TileUniforms(viewProjection: viewProjection)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<TileUniforms>.size, index: 0)
        
        // Set buffers
        encoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 1)
        encoder.setVertexBuffer(instanceBuffer, offset: 0, index: 2)
        
        // Set texture
        encoder.setFragmentTexture(textureAtlas.atlasTexture, index: 0)
        encoder.setFragmentSamplerState(textureAtlas.sampler, index: 0)
        
        // Draw instanced
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: instanceCount)
    }
    
    private func getTileTextureRect(for tile: TileInstance) -> Rect {
        let textureName = TileType(rawValue: tile.textureIndex)?.textureName ?? "grass"
        return textureAtlas.getTextureRect(for: textureName)
    }
}

// MARK: - Tile Types

enum TileType: UInt16, Codable {
    case grass = 0
    case dirt = 1
    case stone = 2
    case water = 3
    case sand = 4
    case ironOre = 5
    case copperOre = 6
    case coal = 7
    case tree = 8
    
    var textureName: String {
        switch self {
        case .grass: return "grass"
        case .dirt: return "dirt"
        case .stone: return "stone"
        case .water: return "water"
        case .sand: return "sand"
        case .ironOre: return "iron_ore"
        case .copperOre: return "copper_ore"
        case .coal: return "coal"
        case .tree: return "tree"
        }
    }
    
    var isBuildable: Bool {
        switch self {
        case .water, .tree: return false
        default: return true
        }
    }
    
    var isWalkable: Bool {
        switch self {
        case .water: return false
        default: return true
        }
    }
}

// MARK: - Shader Data Structures

struct TileVertex {
    var position: Vector2
    var texCoord: Vector2
}

struct TileInstanceData {
    var position: Vector2
    var uvOrigin: Vector2
    var uvSize: Vector2
    var tint: Vector4
}

struct TileUniforms {
    var viewProjection: Matrix4
}

