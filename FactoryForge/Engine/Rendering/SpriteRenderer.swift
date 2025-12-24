import Metal
import simd

/// Renders sprites with sorting by layer
final class SpriteRenderer {
    private let device: MTLDevice
    private let textureAtlas: TextureAtlas

    // Quad vertices
    private var quadVertices: [Vector2] = []
    private var quadTexCoords: [Vector2] = []

    // Vertex buffer for expanded vertices
    private var spriteVertexBuffer: MTLBuffer?
    private var spriteVertices: [UIVertex] = []
    private let maxVertices = 1024

    // Queued sprites for current frame
    private var queuedSprites: [SpriteInstance] = []
    
    init(device: MTLDevice, library: MTLLibrary, textureAtlas: TextureAtlas) {
        self.device = device
        self.textureAtlas = textureAtlas

        // Create quad vertices (centered on origin, counterclockwise winding)
        quadVertices = [
            Vector2(-0.5, -0.5), // bottom-left
            Vector2(-0.5, 0.5),  // top-left
            Vector2(0.5, 0.5),   // top-right
            Vector2(-0.5, -0.5), // bottom-left
            Vector2(0.5, 0.5),   // top-right
            Vector2(0.5, -0.5)   // bottom-right
        ]

        quadTexCoords = [
            Vector2(0, 1), // bottom-left
            Vector2(0, 0), // top-left
            Vector2(1, 0), // top-right
            Vector2(0, 1), // bottom-left
            Vector2(1, 0), // top-right
            Vector2(1, 1)  // bottom-right
        ]

        // Create vertex buffer for expanded vertices
        spriteVertexBuffer = device.makeBuffer(
            length: MemoryLayout<UIVertex>.stride * maxVertices,
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

        // Sort by layer
        queuedSprites.sort { $0.layer < $1.layer }

        // Generate vertices for all sprites
        spriteVertices.removeAll(keepingCapacity: true)

        for sprite in queuedSprites.prefix(maxVertices / 6) {
            let uvOrigin = Vector2(sprite.textureRect.origin.x, sprite.textureRect.origin.y)
            let uvSize = Vector2(sprite.textureRect.size.x, sprite.textureRect.size.y)
            let color = sprite.color.vector4

            let transform = createTransform(
                position: sprite.position,
                size: sprite.size,
                rotation: sprite.rotation
            )

            for i in 0..<6 {
                let localPos = quadVertices[i]
                let worldPos4 = transform * SIMD4(localPos.x, localPos.y, 0, 1)
                let worldPos = Vector2(worldPos4.x, worldPos4.y)
                let screenPos = camera.worldToScreen(worldPos)
                let texCoord = uvOrigin + quadTexCoords[i] * uvSize

                spriteVertices.append(UIVertex(position: screenPos, texCoord: texCoord, color: color))
            }
        }

        queuedSprites.removeAll(keepingCapacity: true)

        guard !spriteVertices.isEmpty else { return }
        guard let spriteVertexBuffer = spriteVertexBuffer else { return }

        // Update vertex buffer
        let vertexCount = spriteVertices.count
        spriteVertexBuffer.contents().copyMemory(
            from: spriteVertices,
            byteCount: MemoryLayout<UIVertex>.stride * vertexCount
        )

        // Use UI pipeline for rendering
        var uniforms = UIUniforms(screenSize: camera.screenSize)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<UIUniforms>.size, index: 0)
        encoder.setVertexBuffer(spriteVertexBuffer, offset: 0, index: 1)
        encoder.setFragmentTexture(textureAtlas.atlasTexture, index: 0)
        encoder.setFragmentSamplerState(textureAtlas.sampler, index: 0)

        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
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

