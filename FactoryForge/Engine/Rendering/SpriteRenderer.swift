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
    private let maxVertices = 8192  // Increased from 1024 to handle more sprites (1024 vertices = 170 sprites, 8192 = 1365 sprites)

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
        let cameraCenter = camera.position
        let maxRenderDistance = camera.zoom * 15.0  // Adjust based on zoom level

        var spritesCollected = 0
        var spritesCulledDistance = 0
        var spritesCulledSize = 0

        // Query all entities with position and sprite components
        for entity in world.query(PositionComponent.self, SpriteComponent.self) {
            guard let position = world.get(PositionComponent.self, for: entity),
                  let sprite = world.get(SpriteComponent.self, for: entity) else { continue }

            let worldPos = position.worldPosition
            guard visibleRect.contains(worldPos) else { continue }
            spritesCollected += 1

            // Distance-based culling: skip sprites too far from camera center
            let distanceFromCamera = (worldPos - cameraCenter).length
            guard distanceFromCamera <= maxRenderDistance else {
                spritesCulledDistance += 1
                continue
            }

            // Skip very small sprites when zoomed out (performance optimization)
            // Convert world size to screen size: worldSize * zoom * 32.0 (pixels per world unit)
            let screenSize = sprite.size * camera.zoom * Float(32.0)
            let minScreenSize = camera.zoom > 2.0 ? Float(4.0) : Float(2.0)  // Minimum screen pixels for sprite to be worth rendering
            guard screenSize.x >= minScreenSize || screenSize.y >= minScreenSize else {
                spritesCulledSize += 1
                continue
            }

            // Skip belt rendering here - belts are drawn as simple shapes instead of sprites
            let beltTypes = ["transport_belt", "fast_transport_belt", "express_transport_belt"]
            if beltTypes.contains(sprite.textureId) {
                continue  // Skip belt sprites - they'll be drawn as shapes
            }

            let textureRect = textureAtlas.getTextureRect(for: sprite.textureId)

            // For centered sprites (like player), use position directly
            // For non-centered sprites (buildings), offset by half size to align with tile origin
            let renderPos = sprite.centered ? worldPos : worldPos + Vector2(sprite.size.x / 2, sprite.size.y / 2)

            // Only apply rotation to centered sprites (like player), not buildings
            // Buildings use directional sprites or don't need rotation
            let rotation = sprite.centered ? position.direction.angle : 0

            queuedSprites.append(SpriteInstance(
                position: renderPos,
                size: sprite.size,
                rotation: rotation,
                textureRect: textureRect,
                color: sprite.tint,
                layer: sprite.layer
            ))
        }

        // Render belts as simple shapes (before items so items appear on top)
        renderBelts(world: world, visibleRect: visibleRect, camera: camera)
        
        // Add items on belts
        renderBeltItems(world: world, visibleRect: visibleRect, camera: camera)

        // Add progress bars for mining drills
        renderMiningProgressBars(world: world, visibleRect: visibleRect, camera: camera)

        // Add progress bars for crafting machines (furnaces and assemblers)
        renderCraftingProgressBars(world: world, visibleRect: visibleRect, camera: camera)

        guard !queuedSprites.isEmpty else { return }

        // Sort by texture first (for better batching), then by layer
        queuedSprites.sort { (a, b) -> Bool in
            if a.textureRect.origin != b.textureRect.origin {
                return a.textureRect.origin.x < b.textureRect.origin.x ||
                       (a.textureRect.origin.x == b.textureRect.origin.x && a.textureRect.origin.y < b.textureRect.origin.y)
            }
            return a.layer < b.layer
        }

        // Generate vertices for all sprites
        spriteVertices.removeAll(keepingCapacity: true)

        let spritesToRender = min(queuedSprites.count, maxVertices / 6)
        for sprite in queuedSprites.prefix(spritesToRender) {
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

        // Debug performance info (only in debug builds)
        #if DEBUG
        let totalSprites = spritesCollected + spritesCulledDistance + spritesCulledSize
        if totalSprites > 50 {  // Only log when there are many sprites
            print("SpriteRenderer: Rendered \(spritesToRender) sprites (\(spritesCollected) collected, \(spritesCulledDistance) culled by distance, \(spritesCulledSize) culled by size)")
        }
        #endif
    }
    
    private func renderBelts(world: World, visibleRect: Rect, camera: Camera2D) {
        // Use solid white texture and tint it with belt color
        let solidRect = textureAtlas.getTextureRect(for: "solid_white")
        let cameraCenter = camera.position
        let maxRenderDistance = camera.zoom * 15.0

        // Belt colors for different types
        let beltColors: [String: Color] = [
            "transport_belt": Color(r: 0.5, g: 0.5, b: 0.5, a: 1.0),      // Grey
            "fast_transport_belt": Color(r: 0.2, g: 0.5, b: 0.9, a: 1.0),  // Blue
            "express_transport_belt": Color(r: 0.8, g: 0.2, b: 0.8, a: 1.0) // Purple
        ]
        
        for entity in world.query(BeltComponent.self, SpriteComponent.self) {
            guard let position = world.get(PositionComponent.self, for: entity),
                  let belt = world.get(BeltComponent.self, for: entity),
                  let sprite = world.get(SpriteComponent.self, for: entity) else { continue }

            let worldPos = position.worldPosition
            guard visibleRect.contains(worldPos) else { continue }

            // Distance-based culling for belts
            let distanceFromCamera = (worldPos - cameraCenter).length
            guard distanceFromCamera <= maxRenderDistance else { continue }
            
            // Get belt color based on texture ID
            let beltColor = beltColors[sprite.textureId] ?? Color(r: 0.5, g: 0.5, b: 0.5, a: 1.0)
            
            // Draw belt as a simple rectangle
            // The belt should be oriented along its direction
            let beltWidth: Float = 0.7  // Width of the belt (70% of tile)
            let beltLength: Float = 1.0  // Full tile length
            
            // Create a rectangle oriented along the belt direction
            let angle = belt.direction.angle
            let beltSize = Vector2(beltWidth, beltLength)
            
            queuedSprites.append(SpriteInstance(
                position: worldPos,
                size: beltSize,
                rotation: angle,
                textureRect: solidRect,
                color: beltColor,
                layer: sprite.layer
            ))
        }
    }
    
    private func renderBeltItems(world: World, visibleRect: Rect, camera: Camera2D) {
        let cameraCenter = camera.position
        let maxRenderDistance = camera.zoom * 15.0

        for entity in world.query(BeltComponent.self) {
            guard let position = world.get(PositionComponent.self, for: entity),
                  let belt = world.get(BeltComponent.self, for: entity) else { continue }

            let basePos = position.worldPosition
            guard visibleRect.contains(basePos) else { continue }

            // Distance-based culling for belt items
            let distanceFromCamera = (basePos - cameraCenter).length
            guard distanceFromCamera <= maxRenderDistance else { continue }

            // Render items on left lane
            for item in belt.leftLane {
                let itemPos = basePos + Vector2(-0.25, item.progress - 0.5).rotated(by: belt.direction.angle)
                let textureRect = textureAtlas.getTextureRect(for: item.itemId.replacingOccurrences(of: "-", with: "_"))

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
                let textureRect = textureAtlas.getTextureRect(for: item.itemId.replacingOccurrences(of: "-", with: "_"))

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

    private func renderMiningProgressBars(world: World, visibleRect: Rect, camera: Camera2D) {
        let cameraCenter = camera.position
        let maxRenderDistance = camera.zoom * 15.0

        // Query entities with MinerComponent and SpriteComponent
        for entity in world.query(MinerComponent.self, SpriteComponent.self) {
            guard let position = world.get(PositionComponent.self, for: entity),
                  let miner = world.get(MinerComponent.self, for: entity),
                  let sprite = world.get(SpriteComponent.self, for: entity) else { continue }

            // Only show progress bar if miner is active
            guard miner.isActive else { continue }

            let worldPos = position.worldPosition
            guard visibleRect.contains(worldPos) else { continue }

            // Distance-based culling for progress bars
            let distanceFromCamera = (worldPos - cameraCenter).length
            guard distanceFromCamera <= maxRenderDistance else { continue }

            // Position progress bar below the drill sprite
            let progressBarPos = worldPos + Vector2(0, sprite.size.y / 2 + 0.3) // 0.3 units below sprite

            // Progress bar dimensions
            let barWidth: Float = sprite.size.x * 0.8  // 80% of sprite width
            let barHeight: Float = 0.15  // Thin bar
            let progressWidth = barWidth * miner.progress

            // Background bar (gray)
            let backgroundBar = SpriteInstance(
                position: progressBarPos,
                size: Vector2(barWidth, barHeight),
                rotation: 0,
                textureRect: Rect(x: 0, y: 0, width: 0, height: 0), // Solid color
                color: Color(r: 0.3, g: 0.3, b: 0.3, a: 0.8), // Dark gray background
                layer: .ui
            )

            // Progress bar (green)
            let progressBar = SpriteInstance(
                position: progressBarPos + Vector2(-barWidth/2 + progressWidth/2, 0), // Left-aligned progress
                size: Vector2(progressWidth, barHeight),
                rotation: 0,
                textureRect: Rect(x: 0, y: 0, width: 0, height: 0), // Solid color
                color: Color(r: 0.2, g: 0.8, b: 0.2, a: 0.9), // Bright green progress
                layer: .ui
            )

            queuedSprites.append(backgroundBar)
            if miner.progress > 0 {
                queuedSprites.append(progressBar)
            }
        }
    }

    private func renderCraftingProgressBars(world: World, visibleRect: Rect, camera: Camera2D) {
        let cameraCenter = camera.position
        let maxRenderDistance = camera.zoom * 15.0

        // Query entities with crafting components and sprite components

        // Render furnace progress bars
        for entity in world.query(FurnaceComponent.self, SpriteComponent.self) {
            guard let position = world.get(PositionComponent.self, for: entity),
                  let furnace = world.get(FurnaceComponent.self, for: entity),
                  let sprite = world.get(SpriteComponent.self, for: entity) else { continue }

            // Only show progress bar if furnace has a recipe and is actively crafting
            guard furnace.recipe != nil && furnace.fuelRemaining > 0 else { continue }

            let worldPos = position.worldPosition
            guard visibleRect.contains(worldPos) else { continue }

            // Distance-based culling for progress bars
            let distanceFromCamera = (worldPos - cameraCenter).length
            guard distanceFromCamera <= maxRenderDistance else { continue }

            // Position progress bar below the furnace sprite
            let progressBarPos = worldPos + Vector2(0, sprite.size.y / 2 + 0.3) // 0.3 units below sprite

            // Progress bar dimensions
            let barWidth: Float = sprite.size.x * 0.8  // 80% of sprite width
            let barHeight: Float = 0.15  // Thin bar
            let progressWidth = barWidth * furnace.smeltingProgress

            // Background bar (gray)
            let backgroundBar = SpriteInstance(
                position: progressBarPos,
                size: Vector2(barWidth, barHeight),
                rotation: 0,
                textureRect: Rect(x: 0, y: 0, width: 0, height: 0), // Solid color
                color: Color(r: 0.3, g: 0.3, b: 0.3, a: 0.8), // Dark gray background
                layer: .ui
            )

            // Progress bar (orange for furnaces)
            let progressBar = SpriteInstance(
                position: progressBarPos + Vector2(-barWidth/2 + progressWidth/2, 0), // Left-aligned progress
                size: Vector2(progressWidth, barHeight),
                rotation: 0,
                textureRect: Rect(x: 0, y: 0, width: 0, height: 0), // Solid color
                color: Color(r: 0.9, g: 0.6, b: 0.2, a: 0.9), // Orange progress for furnaces
                layer: .ui
            )

            queuedSprites.append(backgroundBar)
            if furnace.smeltingProgress > 0 {
                queuedSprites.append(progressBar)
            }
        }

        // Render assembler progress bars
        for entity in world.query(AssemblerComponent.self, SpriteComponent.self) {
            guard let position = world.get(PositionComponent.self, for: entity),
                  let assembler = world.get(AssemblerComponent.self, for: entity),
                  let sprite = world.get(SpriteComponent.self, for: entity) else { continue }

            // Only show progress bar if assembler has a recipe and is actively crafting
            guard assembler.recipe != nil else { continue }

            let worldPos = position.worldPosition
            guard visibleRect.contains(worldPos) else { continue }

            // Distance-based culling for progress bars
            let distanceFromCamera = (worldPos - cameraCenter).length
            guard distanceFromCamera <= maxRenderDistance else { continue }

            // Position progress bar below the assembler sprite
            let progressBarPos = worldPos + Vector2(0, sprite.size.y / 2 + 0.3) // 0.3 units below sprite

            // Progress bar dimensions
            let barWidth: Float = sprite.size.x * 0.8  // 80% of sprite width
            let barHeight: Float = 0.15  // Thin bar
            let progressWidth = barWidth * assembler.craftingProgress

            // Background bar (gray)
            let backgroundBar = SpriteInstance(
                position: progressBarPos,
                size: Vector2(barWidth, barHeight),
                rotation: 0,
                textureRect: Rect(x: 0, y: 0, width: 0, height: 0), // Solid color
                color: Color(r: 0.3, g: 0.3, b: 0.3, a: 0.8), // Dark gray background
                layer: .ui
            )

            // Progress bar (blue for assemblers)
            let progressBar = SpriteInstance(
                position: progressBarPos + Vector2(-barWidth/2 + progressWidth/2, 0), // Left-aligned progress
                size: Vector2(progressWidth, barHeight),
                rotation: 0,
                textureRect: Rect(x: 0, y: 0, width: 0, height: 0), // Solid color
                color: Color(r: 0.2, g: 0.6, b: 0.9, a: 0.9), // Blue progress for assemblers
                layer: .ui
            )

            queuedSprites.append(backgroundBar)
            if assembler.craftingProgress > 0 {
                queuedSprites.append(progressBar)
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

