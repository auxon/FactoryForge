import Metal
import simd

/// Renders sprites with sorting by layer
final class SpriteRenderer {
    private let device: MTLDevice
    private let textureAtlas: TextureAtlas
    
    // Vertex buffer for a single quad
    private let quadVertexBuffer: MTLBuffer
    
    // Instance buffer for sprite data
    private var instanceBuffer: MTLBuffer?
    private var instanceCount: Int = 0
    private let maxInstances = 5000
    
    // Queued sprites for current frame
    private var queuedSprites: [SpriteInstance] = []
    
    init(device: MTLDevice, library: MTLLibrary, textureAtlas: TextureAtlas) {
        self.device = device
        self.textureAtlas = textureAtlas
        
        // Create quad vertices (centered on origin)
        let vertices: [SpriteVertex] = [
            SpriteVertex(position: Vector2(-0.5, -0.5), texCoord: Vector2(0, 1)),
            SpriteVertex(position: Vector2(0.5, -0.5), texCoord: Vector2(1, 1)),
            SpriteVertex(position: Vector2(0.5, 0.5), texCoord: Vector2(1, 0)),
            SpriteVertex(position: Vector2(-0.5, -0.5), texCoord: Vector2(0, 1)),
            SpriteVertex(position: Vector2(0.5, 0.5), texCoord: Vector2(1, 0)),
            SpriteVertex(position: Vector2(-0.5, 0.5), texCoord: Vector2(0, 0))
        ]
        
        guard let buffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<SpriteVertex>.stride * vertices.count,
            options: .storageModeShared
        ) else {
            fatalError("Failed to create sprite vertex buffer")
        }
        quadVertexBuffer = buffer
        
        // Create instance buffer
        instanceBuffer = device.makeBuffer(
            length: MemoryLayout<SpriteInstanceData>.stride * maxInstances,
            options: .storageModeShared
        )
    }
    
    func queue(_ sprite: SpriteInstance) {
        queuedSprites.append(sprite)
    }
    
    func render(encoder: MTLRenderCommandEncoder, viewProjection: Matrix4, world: World, camera: Camera2D) {
        // Collect sprites from world entities
        let visibleRect = camera.visibleRect.expanded(by: 5)
        
        // Query all entities with position and sprite components
        for entity in world.query(PositionComponent.self, SpriteComponent.self) {
            guard let position = world.get(PositionComponent.self, for: entity),
                  let sprite = world.get(SpriteComponent.self, for: entity) else { continue }
            
            let worldPos = position.worldPosition
            guard visibleRect.contains(worldPos) else { continue }
            
            let textureRect = textureAtlas.getTextureRect(for: sprite.textureId)
            
            // For centered sprites (like player), use position directly
            // For non-centered sprites (buildings), offset by half size to align with tile origin
            let renderPos = sprite.centered ? worldPos : worldPos + Vector2(sprite.size.x / 2, sprite.size.y / 2)
            
            queuedSprites.append(SpriteInstance(
                position: renderPos,
                size: sprite.size,
                rotation: position.direction.angle,
                textureRect: textureRect,
                color: sprite.tint,
                layer: sprite.layer
            ))
        }
        
        // Add items on belts
        renderBeltItems(world: world, visibleRect: visibleRect)
        
        guard !queuedSprites.isEmpty else { return }
        guard let instanceBuffer = instanceBuffer else { return }
        
        // Sort by layer
        queuedSprites.sort { $0.layer < $1.layer }
        
        // Convert to instance data
        var instances: [SpriteInstanceData] = []
        instances.reserveCapacity(min(queuedSprites.count, maxInstances))
        
        for sprite in queuedSprites.prefix(maxInstances) {
            let transform = createTransform(
                position: sprite.position,
                size: sprite.size,
                rotation: sprite.rotation
            )
            
            instances.append(SpriteInstanceData(
                transform: transform,
                uvOrigin: Vector2(sprite.textureRect.origin.x, sprite.textureRect.origin.y),
                uvSize: Vector2(sprite.textureRect.size.x, sprite.textureRect.size.y),
                tint: sprite.color.vector4
            ))
        }
        
        queuedSprites.removeAll(keepingCapacity: true)
        
        guard !instances.isEmpty else { return }
        
        // Update instance buffer
        instanceBuffer.contents().copyMemory(
            from: instances,
            byteCount: MemoryLayout<SpriteInstanceData>.stride * instances.count
        )
        instanceCount = instances.count
        
        // Set uniforms
        var uniforms = SpriteUniforms(viewProjection: viewProjection)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<SpriteUniforms>.size, index: 0)
        
        // Set buffers
        encoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 1)
        encoder.setVertexBuffer(instanceBuffer, offset: 0, index: 2)
        
        // Set texture
        encoder.setFragmentTexture(textureAtlas.atlasTexture, index: 0)
        encoder.setFragmentSamplerState(textureAtlas.sampler, index: 0)
        
        // Draw instanced
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: instanceCount)
    }
    
    private func renderBeltItems(world: World, visibleRect: Rect) {
        for entity in world.query(BeltComponent.self) {
            guard let position = world.get(PositionComponent.self, for: entity),
                  let belt = world.get(BeltComponent.self, for: entity) else { continue }
            
            let basePos = position.worldPosition
            guard visibleRect.contains(basePos) else { continue }
            
            // Render items on left lane
            for item in belt.leftLane {
                let itemPos = basePos + Vector2(-0.25, item.progress - 0.5).rotated(by: belt.direction.angle)
                let textureRect = textureAtlas.getTextureRect(for: item.itemId)
                
                queuedSprites.append(SpriteInstance(
                    position: itemPos,
                    size: Vector2(0.4, 0.4),
                    rotation: 0,
                    textureRect: textureRect,
                    color: .white,
                    layer: .item
                ))
            }
            
            // Render items on right lane
            for item in belt.rightLane {
                let itemPos = basePos + Vector2(0.25, item.progress - 0.5).rotated(by: belt.direction.angle)
                let textureRect = textureAtlas.getTextureRect(for: item.itemId)
                
                queuedSprites.append(SpriteInstance(
                    position: itemPos,
                    size: Vector2(0.4, 0.4),
                    rotation: 0,
                    textureRect: textureRect,
                    color: .white,
                    layer: .item
                ))
            }
        }
    }
    
    private func createTransform(position: Vector2, size: Vector2, rotation: Float) -> Matrix4 {
        let translation = Matrix4.translation(position)
        let rotationMat = Matrix4.rotationZ(rotation)
        let scale = Matrix4.scale(size)
        return translation * rotationMat * scale
    }
}

// MARK: - Shader Data Structures

struct SpriteVertex {
    var position: Vector2
    var texCoord: Vector2
}

struct SpriteInstanceData {
    var transform: Matrix4
    var uvOrigin: Vector2
    var uvSize: Vector2
    var tint: Vector4
}

struct SpriteUniforms {
    var viewProjection: Matrix4
}

