import MetalKit
import simd

/// Core Metal renderer for the game
@available(iOS 17.0, *)
final class MetalRenderer: NSObject, MTKViewDelegate {
    // Metal objects
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // Pipeline states
    private var tilePipeline: MTLRenderPipelineState!
    private var spritePipeline: MTLRenderPipelineState!
    private var particlePipeline: MTLRenderPipelineState!
    private var uiPipeline: MTLRenderPipelineState!
    
    // Depth state
    private var depthState: MTLDepthStencilState!
    private var noDepthState: MTLDepthStencilState!
    
    // Texture atlas
    let textureAtlas: TextureAtlas
    
    // Sub-renderers
    let tileRenderer: TileMapRenderer
    let spriteRenderer: SpriteRenderer
    let particleRenderer: ParticleRenderer
    
    // Camera
    var camera: Camera2D
    
    // Screen size
    private(set) var screenSize: Vector2 = .zero

    // Drawable size for scissor calculations
    var drawableSize: CGSize = .zero

    // UI clip stack and batching for proper scissor support
    private var uiClipStack: [Rect] = []
    private var uiBatches: [(clip: Rect?, sprites: [SpriteInstance])] = []

    // Game loop reference
    weak var gameLoop: GameLoop?

    // UI system reference (needed for loading menu)
    weak var uiSystem: UISystem?

    // MTKView reference for coordinate system consistency
    private(set) weak var view: MTKView?

    // Selected entity for highlighting
    var selectedEntity: Entity?

    // Debug visualization modes
    var showFluidDebug: Bool = false

    /// Toggle fluid network debug visualization
    func toggleFluidDebug() {
        showFluidDebug.toggle()
        print("Fluid debug visualization: \(showFluidDebug ? "ON" : "OFF")")
    }

    /// Push a UI clip rect for sprite batching
    func pushClip(_ rect: Rect) {
        uiClipStack.append(rect)
    }

    /// Pop the current UI clip rect
    func popClip() {
        _ = uiClipStack.popLast()
    }

    private func currentClip() -> Rect? {
        return uiClipStack.last
    }

    #if DEBUG
    func debugCurrentClip() -> Rect? { currentClip() }
    #endif



    // Frame statistics
    private(set) var drawCallCount: Int = 0
    private(set) var triangleCount: Int = 0
    
    // UI vertex buffer (to avoid setVertexBytes 4KB limit)
    private var uiVertexBuffer: MTLBuffer?
    private let maxUIVertices = 4096  // 4096 vertices = ~682 sprites
    
    init(device: MTLDevice, view: MTKView) {
        self.device = device
        self.view = view
        
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Failed to create command queue")
        }
        self.commandQueue = commandQueue
        
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to create shader library")
        }
        self.library = library
        
        // Initialize texture atlas
        textureAtlas = TextureAtlas(device: device)
        
        // Initialize camera
        let screenScale = Float(UIScreen.main.scale)
        let screenWidth = Float(UIScreen.main.bounds.width) * screenScale
        let screenHeight = Float(UIScreen.main.bounds.height) * screenScale
        camera = Camera2D(screenWidth: screenWidth, screenHeight: screenHeight)
        camera.setZoom(5.0, animated: false) // Start fully zoomed in on player (25% more than before)
        screenSize = Vector2(screenWidth, screenHeight)
        
        // Initialize sub-renderers
        tileRenderer = TileMapRenderer(device: device, library: library, textureAtlas: textureAtlas)
        spriteRenderer = SpriteRenderer(device: device, library: library, textureAtlas: textureAtlas)
        particleRenderer = ParticleRenderer(device: device, library: library, textureAtlas: textureAtlas)
        
        super.init()
        
        setupPipelines(view: view)
        setupDepthState()
        setupUIBuffer()
    }
    
    private func setupUIBuffer() {
        let bufferSize = MemoryLayout<UIVertex>.stride * maxUIVertices
        uiVertexBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared)
        uiVertexBuffer?.label = "UI Vertex Buffer"
    }
    
    private func setupPipelines(view: MTKView) {
        // Tile pipeline
        tilePipeline = createPipeline(
            vertexFunction: "tileVertexShader",
            fragmentFunction: "tileFragmentShader",
            view: view,
            label: "Tile Pipeline"
        )
        
        // Sprite pipeline
        spritePipeline = createPipeline(
            vertexFunction: "spriteVertexShader",
            fragmentFunction: "spriteFragmentShader",
            view: view,
            label: "Sprite Pipeline"
        )
        
        // Particle pipeline
        particlePipeline = createPipeline(
            vertexFunction: "particleVertexShader",
            fragmentFunction: "particleFragmentShader",
            view: view,
            label: "Particle Pipeline",
            blendEnabled: true
        )
        
        // UI pipeline
        uiPipeline = createPipeline(
            vertexFunction: "uiVertexShader",
            fragmentFunction: "uiFragmentShader",
            view: view,
            label: "UI Pipeline",
            blendEnabled: true
        )
    }
    
    private func createPipeline(
        vertexFunction: String,
        fragmentFunction: String,
        view: MTKView,
        label: String,
        blendEnabled: Bool = false
    ) -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = label
        descriptor.vertexFunction = library.makeFunction(name: vertexFunction)
        descriptor.fragmentFunction = library.makeFunction(name: fragmentFunction)
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        
        if blendEnabled {
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }
        
        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }
    
    private func setupDepthState() {
        let descriptor = MTLDepthStencilDescriptor()
        // Use less comparison - sprites are at z=-10, tiles at z=0, so sprites pass
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: descriptor)
        
        // No-depth state for UI rendering
        let noDepthDescriptor = MTLDepthStencilDescriptor()
        noDepthDescriptor.depthCompareFunction = .always
        noDepthDescriptor.isDepthWriteEnabled = false
        noDepthState = device.makeDepthStencilState(descriptor: noDepthDescriptor)
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        screenSize = Vector2(Float(size.width), Float(size.height))
        print("Drawable size changed to: \(size.width) x \(size.height)")
        camera.updateScreenSize(width: Float(size.width), height: Float(size.height))
        gameLoop?.uiSystem?.updateScreenSize(screenSize) // Propagate screen size to UI
    }
    
    func draw(in view: MTKView) {
        // Safety reset - prevents stale clip state from poisoning frames
        uiClipStack.removeAll(keepingCapacity: true)
        uiBatches.removeAll(keepingCapacity: true)

        // Reset stats
        drawCallCount = 0
        triangleCount = 0

        // Update game logic
        gameLoop?.update()
        
        // Render UI first (in case loading menu is active)
        // UI system can exist without game loop (for loading menu)
        if let uiSystem = gameLoop?.uiSystem ?? self.uiSystem {
            uiSystem.render(renderer: self)
        }
        
        // Queue render data (tiles, sprites, etc.)
        if let gameLoop = gameLoop {
            gameLoop.render(renderer: self)
        }
        
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        // Begin render pass
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        // Set drawable size for scissor calculations
        drawableSize = view.drawableSize

        encoder.setDepthStencilState(depthState)
        
        // Calculate view-projection matrix
        let viewProjection = camera.viewProjectionMatrix
        
        // Render tiles
        encoder.setRenderPipelineState(tilePipeline)
        tileRenderer.render(encoder: encoder, viewProjection: viewProjection, camera: camera)
        
        // Render sprites (entities, items on belts, etc.) using UI pipeline
        encoder.setRenderPipelineState(uiPipeline)
        encoder.setDepthStencilState(noDepthState) // No depth for sprites
        if let gameLoop = gameLoop {
            spriteRenderer.render(
                encoder: encoder,
                viewProjection: viewProjection,
                world: gameLoop.world,
                chunkManager: gameLoop.chunkManager,
                camera: camera,
                selectedEntity: selectedEntity,
                deltaTime: Time.shared.deltaTime,
                showFluidDebug: showFluidDebug
            )
        }
        
        // Render particles
        encoder.setRenderPipelineState(particlePipeline)
        particleRenderer.render(encoder: encoder, viewProjection: viewProjection)
        
        // Render UI in screen space (disable depth testing)
        encoder.setDepthStencilState(noDepthState)
        encoder.setRenderPipelineState(uiPipeline)
 
        renderUISprites(encoder: encoder)
        
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    // MARK: - Rendering Helpers
    
    func queueSprite(_ sprite: SpriteInstance) {
        if sprite.layer == .ui {

            // Batch UI sprites by current clip rect
            let clip = currentClip()

            // Check if we can append to the last batch
            if let lastBatch = uiBatches.last {
                let sameClip =
                    (clip == nil && lastBatch.clip == nil) ||
                    (clip != nil && lastBatch.clip != nil &&
                     abs(clip!.minX - lastBatch.clip!.minX) < 0.1 &&
                     abs(clip!.minY - lastBatch.clip!.minY) < 0.1 &&
                     abs(clip!.size.x - lastBatch.clip!.size.x) < 0.1 &&
                     abs(clip!.size.y - lastBatch.clip!.size.y) < 0.1)

                if sameClip {
                    uiBatches[uiBatches.count - 1].sprites.append(sprite)
                } else {
                    uiBatches.append((clip: clip, sprites: [sprite]))
                }
            } else {
                // No existing batches, create the first one
                uiBatches.append((clip: clip, sprites: [sprite]))
            }
        } else {
            spriteRenderer.queue(sprite)
        }
    }
    
    
    func queueParticle(_ particle: ParticleInstance) {
        particleRenderer.queue(particle)
    }
    
    func queueTiles(_ tiles: [TileInstance]) {
        tileRenderer.queue(tiles)
    }
    
    func worldToScreen(_ worldPos: Vector2) -> Vector2 {
        return camera.worldToScreen(worldPos)
    }
    
    func screenToWorld(_ screenPos: Vector2) -> Vector2 {
        return camera.screenToWorld(screenPos)
    }
    
    // MARK: - UI Rendering
    
    private func renderUISprites(encoder: MTLRenderCommandEncoder) {
        guard !uiBatches.isEmpty else { return }
        guard let uiVertexBuffer = uiVertexBuffer else { return }

        var uniforms = UIUniforms(screenSize: screenSize)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<UIUniforms>.size, index: 0)
        encoder.setVertexBuffer(uiVertexBuffer, offset: 0, index: 1)
        encoder.setFragmentTexture(textureAtlas.atlasTexture, index: 0)
        encoder.setFragmentSamplerState(textureAtlas.sampler, index: 0)

        // Render each batch with its clip rect
        for batch in uiBatches {
            // Apply scissor for this batch
            if let clipRect = batch.clip {
                let scissor = clipRect.toScissorRect(drawableSize: drawableSize)
                encoder.setScissorRect(scissor)
            } else {
                // Reset to full framebuffer if no clip
                encoder.setScissorRect(MTLScissorRect(
                    x: 0, y: 0,
                    width: Int(drawableSize.width),
                    height: Int(drawableSize.height)
                ))
            }

            // Build vertices for this batch
            var vertices: [UIVertex] = []
            vertices.reserveCapacity(batch.sprites.count * 6)

            for sprite in batch.sprites {
                let halfSize = sprite.size * 0.5
                let center = sprite.position

                // Quad corners in screen space
                let topLeft = center + Vector2(-halfSize.x, -halfSize.y)
                let topRight = center + Vector2(halfSize.x, -halfSize.y)
                let bottomLeft = center + Vector2(-halfSize.x, halfSize.y)
                let bottomRight = center + Vector2(halfSize.x, halfSize.y)

                // TextureAtlas already returns normalized UV coordinates
                let uvOrigin = sprite.textureRect.origin
                let uvSize = sprite.textureRect.size

                let uvTopLeft = Vector2(uvOrigin.x, uvOrigin.y)
                let uvTopRight = Vector2(uvOrigin.x + uvSize.x, uvOrigin.y)
                let uvBottomLeft = Vector2(uvOrigin.x, uvOrigin.y + uvSize.y)
                let uvBottomRight = Vector2(uvOrigin.x + uvSize.x, uvOrigin.y + uvSize.y)

                let color = sprite.color.vector4

                // Two triangles
                vertices.append(UIVertex(position: topLeft, texCoord: uvTopLeft, color: color))
                vertices.append(UIVertex(position: topRight, texCoord: uvTopRight, color: color))
                vertices.append(UIVertex(position: bottomRight, texCoord: uvBottomRight, color: color))

                vertices.append(UIVertex(position: topLeft, texCoord: uvTopLeft, color: color))
                vertices.append(UIVertex(position: bottomRight, texCoord: uvBottomRight, color: color))
                vertices.append(UIVertex(position: bottomLeft, texCoord: uvBottomLeft, color: color))
            }

            guard !vertices.isEmpty else { continue }

            // Limit to max vertices
            let vertexCount = min(vertices.count, maxUIVertices)

            // Copy vertex data to buffer
            uiVertexBuffer.contents().copyMemory(
                from: vertices,
                byteCount: MemoryLayout<UIVertex>.stride * vertexCount
            )

            // Draw this batch
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        }

        uiBatches.removeAll(keepingCapacity: true)

        // Reset scissor to full screen after UI rendering
        encoder.setScissorRect(MTLScissorRect(
            x: 0, y: 0,
            width: Int(drawableSize.width),
            height: Int(drawableSize.height)
        ))

        // Debug: Assert clip stack is empty (catch unbalanced push/pop)
        #if DEBUG
        if !uiClipStack.isEmpty {
            print("ERROR: uiClipStack not empty at end of frame: \(uiClipStack.count)")
            uiClipStack.removeAll(keepingCapacity: true)
        }
        #endif
    }

    /// Clear any cached rendering data when starting a new game
    public func clearCachesForNewGame() {
        // Clear any renderer-specific cached data here
        // Currently no persistent caches, but this method ensures
        // future caches get cleared when starting new games
    }
}

// MARK: - UI Clipping Extensions

extension Rect {
    func toScissorRect(drawableSize: CGSize) -> MTLScissorRect {
        let x = Int(floor(minX))
        let y = Int(floor(minY))
        let w = Int(ceil(size.x))
        let h = Int(ceil(size.y))

        // Clamp to framebuffer bounds (Metal dislikes out-of-range scissors)
        let maxW = Int(drawableSize.width)
        let maxH = Int(drawableSize.height)

        let cx = max(0, min(x, maxW))
        let cy = max(0, min(y, maxH))
        let cw = max(0, min(w, maxW - cx))
        let ch = max(0, min(h, maxH - cy))

        return MTLScissorRect(x: cx, y: cy, width: cw, height: ch)
    }
}

// MARK: - UI Shader Types

struct UIVertex {
    var position: Vector2
    var texCoord: Vector2
    var color: Vector4
}

struct UIUniforms {
    var screenSize: Vector2
}

// MARK: - Camera

final class Camera2D {
    var position: Vector2 = .zero
    var target: Vector2 = .zero
    var zoom: Float = 1.0
    var targetZoom: Float = 1.0
    
    private var screenWidth: Float
    private var screenHeight: Float
    private var isFirstUpdate: Bool = true

    var screenSize: Vector2 {
        return Vector2(screenWidth, screenHeight)
    }
    
    let minZoom: Float = 0.20
    let maxZoom: Float = 10.0
    let followSpeed: Float = 8.0
    let zoomSpeed: Float = 5.0
    
    init(screenWidth: Float, screenHeight: Float) {
        // Ensure we use landscape dimensions (wider than tall)
        self.screenWidth = max(screenWidth, screenHeight)
        self.screenHeight = min(screenWidth, screenHeight)
    }
    
    func updateScreenSize(width: Float, height: Float) {
        screenWidth = width
        screenHeight = height
    }

    func setZoom(_ newZoom: Float, animated: Bool = true) {
        let clampedZoom = max(minZoom, min(maxZoom, newZoom))
        if animated {
            targetZoom = clampedZoom
        } else {
            zoom = clampedZoom
            targetZoom = clampedZoom
        }
    }

    /// Reset camera for new game - forces immediate snap to target position
    public func resetForNewGame() {
        isFirstUpdate = true
    }

    
    func update(deltaTime: Float) {
        // On first update, snap to target immediately
        if isFirstUpdate {
            position = target
            zoom = targetZoom
            isFirstUpdate = false
            return
        }
        
        // Smooth camera follow
        position = position.lerp(to: target, t: min(followSpeed * deltaTime, 1.0))

        // Smooth zoom
        zoom = zoom + (targetZoom - zoom) * min(zoomSpeed * deltaTime, 1.0)
    }
    
    var viewProjectionMatrix: Matrix4 {
        let halfWidth = (screenWidth / 2.0) / zoom / 32.0  // 32 pixels per tile
        let halfHeight = (screenHeight / 2.0) / zoom / 32.0
        
        let projection = Matrix4.orthographic(
            left: -halfWidth,
            right: halfWidth,
            bottom: -halfHeight,
            top: halfHeight,
            near: -100,
            far: 100
        )
        
        let view = Matrix4.translation(Vector2(-position.x, -position.y))
        
        return projection * view
    }
    
    var visibleRect: Rect {
        let halfWidth = (screenWidth / 2.0) / zoom / 32.0
        let halfHeight = (screenHeight / 2.0) / zoom / 32.0
        return Rect(
            center: position,
            size: Vector2(halfWidth * 2, halfHeight * 2)
        )
    }
    
    func worldToScreen(_ worldPos: Vector2) -> Vector2 {
        let relativePos = worldPos - position
        let screenPos = relativePos * zoom * 32.0
        return Vector2(
            screenWidth / 2.0 + screenPos.x,
            screenHeight / 2.0 - screenPos.y
        )
    }
    
    func screenToWorld(_ screenPos: Vector2) -> Vector2 {
        let centeredPos = Vector2(
            screenPos.x - screenWidth / 2.0,
            -(screenPos.y - screenHeight / 2.0)
        )
        let worldOffset = centeredPos / zoom / 32.0
        return position + worldOffset
    }
}

// MARK: - Render Instances

struct SpriteInstance {
    var position: Vector2
    var size: Vector2
    var rotation: Float
    var textureRect: Rect  // UV coordinates in atlas
    var color: Color
    var layer: RenderLayer
    var flipX: Bool
    var flipY: Bool
    var scissor: MTLScissorRect?
    
    init(position: Vector2, size: Vector2 = Vector2(1, 1), rotation: Float = 0,
         textureRect: Rect = Rect(x: 0, y: 0, width: 1, height: 1),
         color: Color = .white, layer: RenderLayer = .entity, flipX: Bool = false, flipY: Bool = false,
         scissor: MTLScissorRect? = nil) {
        self.position = position
        self.size = size
        self.rotation = rotation
        self.textureRect = textureRect
        self.color = color
        self.flipX = flipX
        self.flipY = flipY
        self.layer = layer
        self.scissor = scissor
    }
}

struct TileInstance {
    var position: IntVector2
    var textureIndex: UInt16
    var variation: UInt8
    var tint: Color
}

struct ParticleInstance {
    var position: Vector2
    var velocity: Vector2
    var size: Float
    var rotation: Float
    var color: Color
    var life: Float
    var maxLife: Float
}

enum RenderLayer: Int, Comparable, Codable {
    case ground = 0
    case groundDecoration = 1
    case shadow = 2
    case building = 3
  
    case entity = 4
    case item = 5
    case enemy = 6
    case projectile = 7
    case particle = 8
    case ui = 9
    
    static func < (lhs: RenderLayer, rhs: RenderLayer) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
