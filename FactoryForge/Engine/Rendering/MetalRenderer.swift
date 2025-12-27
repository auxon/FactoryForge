import MetalKit
import simd

/// Core Metal renderer for the game
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
    
    // Game loop reference
    weak var gameLoop: GameLoop?
    
    // UI system reference (needed for loading menu)
    weak var uiSystem: UISystem?
    
    // Frame statistics
    private(set) var drawCallCount: Int = 0
    private(set) var triangleCount: Int = 0
    
    // UI vertex buffer (to avoid setVertexBytes 4KB limit)
    private var uiVertexBuffer: MTLBuffer?
    private let maxUIVertices = 4096  // 4096 vertices = ~682 sprites
    
    init(device: MTLDevice, view: MTKView) {
        self.device = device
        
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
        camera.setZoom(4.0, animated: false) // Start fully zoomed in on player
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
                camera: camera
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
            uiSprites.append(sprite)
        } else {
            spriteRenderer.queue(sprite)
        }
    }
    
    // UI sprites rendered in screen space
    private var uiSprites: [SpriteInstance] = []
    
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
        guard !uiSprites.isEmpty else {
            return
        }
        
        // Create UI vertex data directly
        var vertices: [UIVertex] = []
        vertices.reserveCapacity(uiSprites.count * 6)
        
        for sprite in uiSprites {
            // print("  UI sprite at (\(sprite.position.x), \(sprite.position.y)) size (\(sprite.size.x), \(sprite.size.y))")
            let halfSize = sprite.size * 0.5
            let center = sprite.position
            
            // Quad corners in screen space
            let topLeft = center + Vector2(-halfSize.x, -halfSize.y)
            let topRight = center + Vector2(halfSize.x, -halfSize.y)
            let bottomLeft = center + Vector2(-halfSize.x, halfSize.y)
            let bottomRight = center + Vector2(halfSize.x, halfSize.y)
            
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
        
        uiSprites.removeAll(keepingCapacity: true)
        
        guard !vertices.isEmpty else { return }
        guard let uiVertexBuffer = uiVertexBuffer else { return }
        
        // Limit to max vertices
        let vertexCount = min(vertices.count, maxUIVertices)
        
        // Copy vertex data to buffer
        uiVertexBuffer.contents().copyMemory(
            from: vertices,
            byteCount: MemoryLayout<UIVertex>.stride * vertexCount
        )
        
        // Set uniforms
        var uniforms = UIUniforms(screenSize: screenSize)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<UIUniforms>.size, index: 0)
        
        // Set vertex buffer
        encoder.setVertexBuffer(uiVertexBuffer, offset: 0, index: 1)
        
        // Set texture
        encoder.setFragmentTexture(textureAtlas.atlasTexture, index: 0)
        encoder.setFragmentSamplerState(textureAtlas.sampler, index: 0)
        
        // Draw
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
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
    
    init(position: Vector2, size: Vector2 = Vector2(1, 1), rotation: Float = 0,
         textureRect: Rect = Rect(x: 0, y: 0, width: 1, height: 1),
         color: Color = .white, layer: RenderLayer = .entity, flipX: Bool = false, flipY: Bool = false) {
        self.position = position
        self.size = size
        self.rotation = rotation
        self.textureRect = textureRect
        self.color = color
        self.flipX = flipX
        self.flipY = flipY
        self.layer = layer
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
    case item = 4
    case entity = 5
    case enemy = 6
    case projectile = 7
    case particle = 8
    case ui = 9
    
    static func < (lhs: RenderLayer, rhs: RenderLayer) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

