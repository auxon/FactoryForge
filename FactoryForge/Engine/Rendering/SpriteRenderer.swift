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

    // Frame counter for debug throttling
    private var frameCount: UInt64 = 0
    
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
    
    func render(encoder: MTLRenderCommandEncoder, viewProjection: Matrix4, world: World, camera: Camera2D, selectedEntity: Entity?, deltaTime: Float, showFluidDebug: Bool = false) {
        frameCount += 1

        // Collect sprites from world entities
        let visibleRect = camera.visibleRect.expanded(by: 3)  // Reduced from 5 for performance
        let cameraCenter = camera.position
        let maxRenderDistance = 100.0 / camera.zoom  // Increased render distance when zoomed out

        var spritesCollected = 0
        var spritesCulledDistance = 0
        var spritesCulledSize = 0
        var animationUpdates: [(Entity, SpriteComponent)] = []

        // Query all entities with position and sprite components
        for entity in world.query(PositionComponent.self, SpriteComponent.self) {
            guard let position = world.get(PositionComponent.self, for: entity),
                  let sprite = world.get(SpriteComponent.self, for: entity) else { continue }

            // Check if this is a belt entity for rotation
            let belt = world.get(BeltComponent.self, for: entity)

            let worldPos = position.worldPosition
            guard visibleRect.contains(worldPos) else { continue }
            spritesCollected += 1

            // Distance-based culling: skip sprites too far from camera center
            let distanceFromCamera = (worldPos - cameraCenter).length
            guard distanceFromCamera <= maxRenderDistance else {
                spritesCulledDistance += 1
                continue
            }

            // Animated belts are rendered as sprites, non-animated belts are rendered as shapes
            let beltTypes = ["transport_belt", "fast_transport_belt", "express_transport_belt"]
            if beltTypes.contains(sprite.textureId) && sprite.animation == nil {
                continue  // Skip non-animated belt sprites - they'll be drawn as shapes in renderBelts
            }

            // Update animation if present (use a mutable copy for rendering)
            var renderSprite = sprite
            
            let textureRect = textureAtlas.getTextureRect(for: renderSprite.textureId)

            // Use sprite size as defined in the building/component
            let effectiveSize = renderSprite.size

            // Skip very small sprites when zoomed out (performance optimization)
            // Convert world size to screen size: worldSize * zoom * 32.0 (pixels per world unit)
            let screenSize = effectiveSize * camera.zoom * Float(32.0)
            let minScreenSize = camera.zoom > 2.0 ? Float(4.0) : Float(2.0)  // Minimum screen pixels for sprite to be worth rendering
            guard screenSize.x >= minScreenSize || screenSize.y >= minScreenSize else {
                spritesCulledSize += 1
                continue
            }

            if var animation = renderSprite.animation {
                if let newTextureId = animation.update(deltaTime: deltaTime) {  // Use actual delta time
                    renderSprite.textureId = newTextureId
                }
                renderSprite.animation = animation

                // Collect animation updates to apply after the query
                var updatedSprite = sprite
                updatedSprite.animation = animation
                updatedSprite.textureId = renderSprite.textureId
                animationUpdates.append((entity, updatedSprite))
            }

            // Center sprites that aren't already centered
            let renderPos: Vector2
            if renderSprite.centered {
                // Sprite position is already centered, use as-is
                renderPos = worldPos
            } else {
                // Add centering offset for sprites with bottom-left origin
                renderPos = worldPos + Vector2(renderSprite.size.x / 2, renderSprite.size.y / 2)
            }

            // Apply rotation based on entity type
            var rotation: Float = 0
            if let belt = belt {
                // Belts use their transport direction
                // Negate angle for clockwise rotation to match texture orientation
                rotation = -belt.direction.angle
            }
            // Other sprites (buildings) don't rotate

            // Check if this entity is selected for highlighting
            let isSelected = selectedEntity != nil && entity.id == selectedEntity!.id && entity.generation == selectedEntity!.generation
            let tintColor = isSelected ?
                Color(r: renderSprite.tint.r * 1.5, g: renderSprite.tint.g * 1.5, b: renderSprite.tint.b * 1.0, a: renderSprite.tint.a) :
                renderSprite.tint  // Brighten selected entities

            queuedSprites.append(SpriteInstance(
                position: renderPos,
                size: effectiveSize,
                rotation: rotation,
                textureRect: textureRect,
                color: tintColor,
                layer: renderSprite.layer
            ))

            // Add highlight outline for selected entities
            if isSelected {
                // Render a slightly larger, semi-transparent version behind the original sprite
                let highlightSize = sprite.size * 1.1  // 10% larger
                let highlightColor = Color(r: 1.0, g: 1.0, b: 0.0, a: 0.3)  // Yellow semi-transparent highlight

                queuedSprites.append(SpriteInstance(
                    position: renderPos,
                    size: highlightSize,
                    rotation: rotation,
                    textureRect: textureRect,
                    color: highlightColor,
                    layer: sprite.layer  // Same layer, but will be rendered first due to queue order
                ))
            }
        }

        // Apply collected animation updates
        for (entity, updatedSprite) in animationUpdates {
            world.add(updatedSprite, to: entity)
        }

        // Render belts as simple shapes (before items so items appear on top)
        renderBelts(world: world, visibleRect: visibleRect, camera: camera)
        
        // Add items on belts
        renderBeltItems(world: world, visibleRect: visibleRect, camera: camera)

        // Add progress bars for mining drills
        renderMiningProgressBars(world: world, visibleRect: visibleRect, camera: camera)

        // Add progress bars for crafting machines (furnaces and assemblers)
        renderCraftingProgressBars(world: world, visibleRect: visibleRect, camera: camera)

        // Add fluid visualizations for pipes
        renderFluidVisualizations(world: world, visibleRect: visibleRect, camera: camera)

        // Add fluid network debug visualizations
        if showFluidDebug {
            renderFluidNetworkDebug(world: world, visibleRect: visibleRect, camera: camera)
        }

        guard !queuedSprites.isEmpty else { return }

        // Sort by layer for correct z-ordering (texture batching is less critical than correct layering)
        queuedSprites.sort { (a, b) -> Bool in
            return a.layer.rawValue < b.layer.rawValue
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
    }
    
    private func renderBelts(world: World, visibleRect: Rect, camera: Camera2D) {
        // All belt types now have textures - they are rendered as sprites instead of shapes
        // This function is kept for future use if needed
    }

    
    private func renderBeltItems(world: World, visibleRect: Rect, camera: Camera2D) {
        let cameraCenter = camera.position
        let maxRenderDistance = 60.0 / camera.zoom

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
                let itemPos = calculateBeltItemPosition(basePos: basePos, beltDirection: belt.direction, laneOffset: 0.2, progress: item.progress)
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
                let itemPos = calculateBeltItemPosition(basePos: basePos, beltDirection: belt.direction, laneOffset: -0.2, progress: item.progress)
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

    private func calculateBeltItemPosition(basePos: Vector2, beltDirection: Direction, laneOffset: Float, progress: Float) -> Vector2 {
        // Calculate position along the belt based on direction
        // Progress goes from 0 (start) to 1 (end)
        // Belt textures are 32x32 pixels with 4-pixel edges, so visual surface is full width
        // Items move across the full 1.0 unit width of the belt

        let beltLength = Float(1.0)  // Full width of belt texture (32 pixels = 1.0 world units)
        let itemOffset = (progress - 0.5) * beltLength

        switch beltDirection {
        case .north: // Moving up (positive Y) - lanes are horizontal (X offset)
            return basePos + Vector2(laneOffset, itemOffset)
        case .south: // Moving down (negative Y) - lanes are horizontal (X offset)
            return basePos + Vector2(laneOffset, -itemOffset) // Flip for downward movement
        case .east: // Moving right (positive X) - lanes are vertical (Y offset)
            return basePos + Vector2(itemOffset, laneOffset)
        case .west: // Moving left (negative X) - lanes are vertical (Y offset)
            return basePos + Vector2(-itemOffset, laneOffset) // Flip for leftward movement
        }
    }

    private func renderMiningProgressBars(world: World, visibleRect: Rect, camera: Camera2D) {
        let cameraCenter = camera.position
        let maxRenderDistance = 60.0 / camera.zoom

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

    private func renderFluidVisualizations(world: World, visibleRect: Rect, camera: Camera2D) {
        let cameraCenter = camera.position
        let maxRenderDistance = 60.0 / camera.zoom

        // Query entities with PipeComponent and SpriteComponent
        for entity in world.query(PipeComponent.self, SpriteComponent.self) {
            guard let position = world.get(PositionComponent.self, for: entity),
                  let pipe = world.get(PipeComponent.self, for: entity),
                  let sprite = world.get(SpriteComponent.self, for: entity) else { continue }

            let worldPos = position.worldPosition
            guard visibleRect.contains(worldPos) else { continue }

            // Distance-based culling for fluid visualizations
            let distanceFromCamera = (worldPos - cameraCenter).length
            guard distanceFromCamera <= maxRenderDistance else { continue }

            // Render fluid level indicator
            renderFluidLevel(pipe: pipe, position: worldPos, sprite: sprite)

            // Render connection indicators (only when zoomed in enough)
            if camera.zoom > 0.8 {
                renderPipeConnections(pipe: pipe, tilePosition: position.tilePosition, sprite: sprite, world: world)
            }

            // Render flow direction indicator if there's significant flow
            if abs(pipe.flowRate) > 0.1 {
                renderFlowDirection(pipe: pipe, position: worldPos, sprite: sprite)
            }
        }
    }

    private func renderFluidLevel(pipe: PipeComponent, position: Vector2, sprite: SpriteComponent) {
        guard pipe.fluidType != nil && pipe.maxCapacity > 0 else { return }

        let fillLevel = pipe.fluidAmount / pipe.maxCapacity
        guard fillLevel > 0.01 else { return } // Don't render very low levels

        // Position fluid level slightly above the pipe sprite
        let fluidPos = position + Vector2(0, sprite.size.y * 0.4)

        // Fluid bar dimensions
        let barWidth: Float = sprite.size.x * 0.7  // 70% of pipe width
        let barHeight: Float = sprite.size.y * 0.15 // Thin bar
        let filledWidth = barWidth * fillLevel

        // Get fluid color based on type
        let fluidColor = getFluidColor(pipe.fluidType!)

        // Background bar (dark version of fluid color)
        let backgroundBar = SpriteInstance(
            position: fluidPos,
            size: Vector2(barWidth, barHeight),
            rotation: 0,
            textureRect: Rect(x: 0, y: 0, width: 0, height: 0), // Solid color
            color: fluidColor.withAlpha(0.3), // Semi-transparent background
            layer: .ui
        )

        // Fluid level bar
        let fluidBar = SpriteInstance(
            position: fluidPos + Vector2(-barWidth/2 + filledWidth/2, 0), // Left-aligned fill
            size: Vector2(filledWidth, barHeight),
            rotation: 0,
            textureRect: Rect(x: 0, y: 0, width: 0, height: 0), // Solid color
            color: fluidColor.withAlpha(0.8), // Semi-transparent fluid
            layer: .ui
        )

        queuedSprites.append(backgroundBar)
        queuedSprites.append(fluidBar)
    }

    private func renderPipeConnections(pipe: PipeComponent, tilePosition: IntVector2, sprite: SpriteComponent, world: World) {
        // Render small dots at connection points
        let connectionRadius: Float = sprite.size.x * 0.1
        let connectionOffset: Float = sprite.size.x * 0.35

        // Check each direction for connections
        let directions = [
            (Vector2(0, connectionOffset), Direction.north),   // North
            (Vector2(connectionOffset, 0), Direction.east),   // East
            (Vector2(0, -connectionOffset), Direction.south),  // South
            (Vector2(-connectionOffset, 0), Direction.west)   // West
        ]

        for (offset, direction) in directions {
            let hasConnection = pipe.connections.contains { connectedEntity in
                if let connectedPos = world.get(PositionComponent.self, for: connectedEntity)?.tilePosition {
                    // Check if the connected entity is in the expected direction
                    let delta = connectedPos - tilePosition
                    switch direction {
                    case .north: return delta.y > 0 && delta.x == 0
                    case .east: return delta.x > 0 && delta.y == 0
                    case .south: return delta.y < 0 && delta.x == 0
                    case .west: return delta.x < 0 && delta.y == 0
                    }
                }
                return false
            }

            if hasConnection {
                let worldPosition = tilePosition.toVector2 + Vector2(0.5, 0.5) // Convert tile position to world position
                let connectionPos = worldPosition + offset
                let connectionDot = SpriteInstance(
                    position: connectionPos,
                    size: Vector2(connectionRadius * 2, connectionRadius * 2),
                    rotation: 0,
                    textureRect: Rect(x: 0, y: 0, width: 0, height: 0), // Solid color
                    color: Color(r: 0.8, g: 0.8, b: 0.2, a: 0.9), // Yellow connection indicator
                    layer: .ui
                )
                queuedSprites.append(connectionDot)
            }
        }
    }

    private func renderFlowDirection(pipe: PipeComponent, position: Vector2, sprite: SpriteComponent) {
        // Render a small arrow indicating flow direction
        let arrowSize: Float = sprite.size.x * 0.2
        let arrowOffset: Float = sprite.size.x * 0.3

        // Determine flow direction based on connections and pressure gradients
        // For now, use pipe direction as flow direction
        let flowDirection = pipe.direction
        let arrowOffsetVector = flowDirection.vector * arrowOffset
        let arrowPos = position + arrowOffsetVector

        // Rotate arrow based on flow direction
        let rotation: Float
        switch flowDirection {
        case .north: rotation = 0
        case .east: rotation = .pi / 2
        case .south: rotation = .pi
        case .west: rotation = 3 * .pi / 2
        }

        // Create arrow using a triangle shape (simplified as a small rotated rectangle)
        let arrow = SpriteInstance(
            position: arrowPos,
            size: Vector2(arrowSize, arrowSize * 0.5),
            rotation: rotation,
            textureRect: Rect(x: 0, y: 0, width: 0, height: 0), // Solid color
            color: Color(r: 0.9, g: 0.9, b: 0.9, a: 0.8), // Light gray arrow
            layer: .ui
        )

        queuedSprites.append(arrow)
    }

    private func renderFluidNetworkDebug(world: World, visibleRect: Rect, camera: Camera2D) {
        // This method will be implemented to show network debugging information
        // For now, we'll show network boundaries and basic info

        // Get fluid network system (assuming it's available through the world or passed as parameter)
        // For now, we'll create a simple visualization of pipe networks
        renderNetworkBoundaries(world: world, visibleRect: visibleRect, camera: camera)
        renderPressureVisualization(world: world, visibleRect: visibleRect, camera: camera)
    }

    private func renderNetworkBoundaries(world: World, visibleRect: Rect, camera: Camera2D) {
        let cameraCenter = camera.position
        let maxRenderDistance = 80.0 / camera.zoom

        // Group pipes by network (simplified - in real implementation we'd use FluidNetworkSystem)
        var networkGroups: [Int: [Entity]] = [:]

        for entity in world.query(PipeComponent.self) {
            guard let position = world.get(PositionComponent.self, for: entity),
                  let pipe = world.get(PipeComponent.self, for: entity) else { continue }

            let worldPos = position.worldPosition
            guard visibleRect.contains(worldPos) else { continue }

            let distanceFromCamera = (worldPos - cameraCenter).length
            guard distanceFromCamera <= maxRenderDistance else { continue }

            let networkId = pipe.networkId ?? 0
            if networkGroups[networkId] == nil {
                networkGroups[networkId] = []
            }
            networkGroups[networkId]?.append(entity)
        }

        // Render network boundary overlays
        let solidRect = textureAtlas.getTextureRect(for: "solid_white")
        for (networkId, pipes) in networkGroups {
            if pipes.isEmpty { continue }

            // Create a color based on network ID for visual distinction
            let networkColors: [Color] = [
                Color(r: 1.0, g: 0.2, b: 0.2, a: 0.2), // Red
                Color(r: 0.2, g: 1.0, b: 0.2, a: 0.2), // Green
                Color(r: 0.2, g: 0.2, b: 1.0, a: 0.2), // Blue
                Color(r: 1.0, g: 1.0, b: 0.2, a: 0.2), // Yellow
                Color(r: 1.0, g: 0.2, b: 1.0, a: 0.2), // Magenta
                Color(r: 0.2, g: 1.0, b: 1.0, a: 0.2), // Cyan
                Color(r: 1.0, g: 0.5, b: 0.2, a: 0.2), // Orange
                Color(r: 0.5, g: 0.2, b: 1.0, a: 0.2), // Purple
                Color(r: 0.2, g: 0.5, b: 0.2, a: 0.2), // Dark Green
                Color(r: 0.5, g: 0.5, b: 0.5, a: 0.2)  // Gray
            ]
            let networkColor = networkColors[networkId % networkColors.count]

            // Render a subtle overlay for each pipe in the network
            for pipeEntity in pipes {
                guard let position = world.get(PositionComponent.self, for: pipeEntity) else { continue }
                let worldPos = position.worldPosition

                // Render network boundary indicator
                let boundarySize: Float = 1.5 // Slightly larger than pipe
                let boundary = SpriteInstance(
                    position: worldPos,
                    size: Vector2(boundarySize, boundarySize),
                    textureRect: solidRect,
                    color: networkColor,
                    layer: .groundDecoration  // Behind buildings but above ground
                )
                queuedSprites.append(boundary)
            }
        }
    }

    private func renderPressureVisualization(world: World, visibleRect: Rect, camera: Camera2D) {
        let cameraCenter = camera.position
        let maxRenderDistance = 60.0 / camera.zoom

        // Render pressure indicators for pipes
        for entity in world.query(PipeComponent.self) {
            guard let position = world.get(PositionComponent.self, for: entity),
                  let pipe = world.get(PipeComponent.self, for: entity) else { continue }

            let worldPos = position.worldPosition
            guard visibleRect.contains(worldPos) else { continue }

            let distanceFromCamera = (worldPos - cameraCenter).length
            guard distanceFromCamera <= maxRenderDistance else { continue }

            // Calculate pressure visualization (simplified)
            let fillRatio = pipe.maxCapacity > 0 ? pipe.fluidAmount / pipe.maxCapacity : 0
            let pressure = fillRatio * 100.0 // Simplified pressure calculation

            // Pressure color coding: low = blue, medium = yellow, high = red
            let pressureColor: Color
            if pressure < 30 {
                pressureColor = Color(r: 0.2, g: 0.4, b: 0.9, a: 0.6) // Blue for low pressure
            } else if pressure < 70 {
                pressureColor = Color(r: 0.9, g: 0.9, b: 0.2, a: 0.6) // Yellow for medium pressure
            } else {
                pressureColor = Color(r: 0.9, g: 0.2, b: 0.2, a: 0.6) // Red for high pressure
            }

            let solidRect = textureAtlas.getTextureRect(for: "solid_white")

            // Render pressure overlay
            let pressureSize: Float = 0.8
            let pressureIndicator = SpriteInstance(
                position: worldPos + Vector2(0, 0.6), // Above the pipe
                size: Vector2(pressureSize, pressureSize * 0.3),
                textureRect: solidRect,
                color: pressureColor,
                layer: .ui
            )
            queuedSprites.append(pressureIndicator)

            // Render flow direction indicator if there's significant flow
            if abs(pipe.flowRate) > 1.0 {
                renderFlowDebugIndicator(pipe: pipe, position: worldPos + Vector2(0.6, 0), solidRect: solidRect)
            }
        }
    }

    private func renderFlowDebugIndicator(pipe: PipeComponent, position: Vector2, solidRect: Rect) {
        // Render flow rate as a bar indicator
        let flowRatio = min(abs(pipe.flowRate) / 50.0, 1.0) // Normalize to 0-1
        let flowColor = pipe.flowRate > 0 ?
            Color(r: 0.2, g: 0.9, b: 0.2, a: 0.8) : // Green for positive flow
            Color(r: 0.9, g: 0.2, b: 0.2, a: 0.8)   // Red for negative flow

        let barWidth: Float = 0.3
        let barHeight: Float = flowRatio * 0.8
        let flowBar = SpriteInstance(
            position: position + Vector2(0, barHeight/2),
            size: Vector2(barWidth, barHeight),
            textureRect: solidRect,
            color: flowColor,
            layer: .ui
        )
        queuedSprites.append(flowBar)
    }

    private func getFluidColor(_ fluidType: FluidType) -> Color {
        switch fluidType {
        case .water:
            return Color(r: 0.2, g: 0.4, b: 0.9, a: 1.0)  // Blue
        case .steam:
            return Color(r: 0.8, g: 0.8, b: 0.9, a: 0.7)  // Light blue-gray
        case .crudeOil:
            return Color(r: 0.3, g: 0.2, b: 0.1, a: 1.0)  // Dark brown
        case .heavyOil:
            return Color(r: 0.4, g: 0.3, b: 0.2, a: 1.0)  // Brown
        case .lightOil:
            return Color(r: 0.5, g: 0.4, b: 0.2, a: 1.0)  // Light brown
        case .petroleumGas:
            return Color(r: 0.9, g: 0.8, b: 0.2, a: 0.6)  // Yellow gas
        case .sulfuricAcid:
            return Color(r: 0.9, g: 0.9, b: 0.1, a: 1.0)  // Yellow
        case .lubricant:
            return Color(r: 0.6, g: 0.5, b: 0.3, a: 1.0)  // Tan
        }
    }

    private func renderCraftingProgressBars(world: World, visibleRect: Rect, camera: Camera2D) {
        let cameraCenter = camera.position
        let maxRenderDistance = 60.0 / camera.zoom

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

