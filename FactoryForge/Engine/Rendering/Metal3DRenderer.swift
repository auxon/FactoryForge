import Metal
import MetalKit
import Foundation
import CoreGraphics

/// 3D Metal renderer for FactoryForge - handles 3D models, lighting, and cameras
@available(iOS 17.0, *)
final class Metal3DRenderer {
    // MARK: - Metal Resources

    private let device: MTLDevice
    private let library: MTLLibrary
    private let commandQueue: MTLCommandQueue

    // Render pipeline states
    private var modelPipelineState: MTLRenderPipelineState!
    private var terrainPipelineState: MTLRenderPipelineState!
    private var skyboxPipelineState: MTLRenderPipelineState!

    // Depth stencil state
    private var depthStencilState: MTLDepthStencilState!

    // Vertex descriptor for 3D models
    private var vertexDescriptor: MTLVertexDescriptor!

    // MARK: - Rendering Resources

    // Buffers for dynamic data
    private var cameraUniformBuffer: MTLBuffer!
    private var lightUniformBuffer: MTLBuffer!
    private var modelUniformBuffer: MTLBuffer!

    // Texture resources
    private let textureAtlas: TextureAtlas

    // MARK: - Scene Management

    private var camera: Camera3D
    private var lights: [Light] = []
    private var modelsToRender: [RenderModel] = []
    private var terrainChunks: [TerrainChunk] = []

    // MARK: - Initialization

    init(device: MTLDevice, library: MTLLibrary, textureAtlas: TextureAtlas) throws {
        self.device = device
        self.library = library
        self.textureAtlas = textureAtlas
        self.camera = Camera3D()

        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            throw RendererError.failedToCreateCommandQueue
        }
        self.commandQueue = commandQueue

        setupVertexDescriptors()
        try setupRenderPipelineStates()
        setupDepthStencilState()
        createUniformBuffers()
        setupDefaultLighting()
    }

    // MARK: - Pipeline Setup

    private func setupRenderPipelineStates() throws {
        // Model rendering pipeline
        let modelPipelineDescriptor = MTLRenderPipelineDescriptor()
        modelPipelineDescriptor.label = "3D Model Pipeline"

        guard let vertexFunction = library.makeFunction(name: "vertex_3d_model"),
              let fragmentFunction = library.makeFunction(name: "fragment_3d_model") else {
            throw RendererError.failedToCreateShaders
        }

        modelPipelineDescriptor.vertexFunction = vertexFunction
        modelPipelineDescriptor.fragmentFunction = fragmentFunction
        modelPipelineDescriptor.vertexDescriptor = vertexDescriptor

        modelPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        modelPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        modelPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        modelPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        modelPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        modelPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        modelPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        modelPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        modelPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        modelPipelineState = try device.makeRenderPipelineState(descriptor: modelPipelineDescriptor)

        // Terrain rendering pipeline
        let terrainPipelineDescriptor = MTLRenderPipelineDescriptor()
        terrainPipelineDescriptor.label = "Terrain Pipeline"

        guard let terrainVertexFunction = library.makeFunction(name: "vertex_terrain"),
              let terrainFragmentFunction = library.makeFunction(name: "fragment_terrain") else {
            throw RendererError.failedToCreateShaders
        }

        terrainPipelineDescriptor.vertexFunction = terrainVertexFunction
        terrainPipelineDescriptor.fragmentFunction = terrainFragmentFunction
        terrainPipelineDescriptor.vertexDescriptor = createTerrainVertexDescriptor()

        terrainPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        terrainPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        terrainPipelineState = try device.makeRenderPipelineState(descriptor: terrainPipelineDescriptor)

        // Skybox pipeline (simplified for now)
        skyboxPipelineState = modelPipelineState // Reuse for now
    }

    private func setupDepthStencilState() {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true

        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
    }

    private func setupVertexDescriptors() {
        vertexDescriptor = MTLVertexDescriptor()

        // Position attribute
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        // Normal attribute
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
        vertexDescriptor.attributes[1].bufferIndex = 0

        // Texture coordinate attribute
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.stride * 6
        vertexDescriptor.attributes[2].bufferIndex = 0

        // Color attribute
        vertexDescriptor.attributes[3].format = .float4
        vertexDescriptor.attributes[3].offset = MemoryLayout<Float>.stride * 8
        vertexDescriptor.attributes[3].bufferIndex = 0

        // Layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 12
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
    }

    private func createTerrainVertexDescriptor() -> MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()

        // Position
        descriptor.attributes[0].format = .float3
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].bufferIndex = 0

        // Normal
        descriptor.attributes[1].format = .float3
        descriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
        descriptor.attributes[1].bufferIndex = 0

        // Texture coordinate
        descriptor.attributes[2].format = .float2
        descriptor.attributes[2].offset = MemoryLayout<Float>.stride * 6
        descriptor.attributes[2].bufferIndex = 0

        // Layout
        descriptor.layouts[0].stride = MemoryLayout<Float>.stride * 8
        descriptor.layouts[0].stepRate = 1
        descriptor.layouts[0].stepFunction = .perVertex

        return descriptor
    }

    private func createUniformBuffers() {
        // Camera uniforms
        cameraUniformBuffer = device.makeBuffer(length: MemoryLayout<CameraUniforms>.stride, options: .storageModeShared)

        // Light uniforms (support up to 4 lights for now)
        lightUniformBuffer = device.makeBuffer(length: MemoryLayout<LightUniforms>.stride, options: .storageModeShared)

        // Model uniforms
        modelUniformBuffer = device.makeBuffer(length: MemoryLayout<ModelUniforms>.stride, options: .storageModeShared)
    }

    private func setupDefaultLighting() {
        // Add a default directional light (sun)
        let sunLight = Light(
            type: .directional,
            position: Vector3(10, 10, 10),
            direction: Vector3(-1, -1, -1).normalized,
            color: Vector3(1, 1, 0.9),
            intensity: 1.0,
            range: 1000,
            spotAngle: 0
        )
        lights.append(sunLight)

        // Add ambient light
        let ambientLight = Light(
            type: .ambient,
            position: .zero,
            direction: .zero,
            color: Vector3(0.3, 0.3, 0.4),
            intensity: 0.3,
            range: 0,
            spotAngle: 0
        )
        lights.append(ambientLight)
    }

    // MARK: - Rendering

    func render(to view: MTKView, drawable: CAMetalDrawable) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }

        // Update camera uniforms
        updateCameraUniforms()

        // Update light uniforms
        updateLightUniforms()

        // Create render command encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setDepthStencilState(depthStencilState)

        // Render skybox first (background)
        renderSkybox(renderEncoder: renderEncoder)

        // Render terrain
        renderTerrain(renderEncoder: renderEncoder)

        // Render 3D models
        renderModels(renderEncoder: renderEncoder)

        renderEncoder.endEncoding()

        // Present drawable
        commandBuffer.present(drawable)
        commandBuffer.commit()

        // Clear render queue for next frame
        modelsToRender.removeAll()
        terrainChunks.removeAll()
    }

    private func updateCameraUniforms() {
        var cameraUniforms = CameraUniforms(
            viewMatrix: camera.viewMatrix,
            projectionMatrix: camera.projectionMatrix,
            viewProjectionMatrix: camera.viewProjectionMatrix,
            cameraPosition: camera.position
        )

        memcpy(cameraUniformBuffer.contents(), &cameraUniforms, MemoryLayout<CameraUniforms>.stride)
    }

    private func updateLightUniforms() {
        var lightUniforms = LightUniforms()
        lightUniforms.lightCount = UInt32(min(lights.count, 4))

        // Set up to 4 lights in the uniform buffer
        lightUniforms.lightCount = UInt32(min(lights.count, 4))
        if lights.count > 0 { lightUniforms.light0 = lights[0] }
        if lights.count > 1 { lightUniforms.light1 = lights[1] }
        if lights.count > 2 { lightUniforms.light2 = lights[2] }
        if lights.count > 3 { lightUniforms.light3 = lights[3] }

        memcpy(lightUniformBuffer.contents(), &lightUniforms, MemoryLayout<LightUniforms>.stride)
    }

    private func renderSkybox(renderEncoder: MTLRenderCommandEncoder) {
        // Simple skybox rendering - could be expanded later
        // For now, just clear to a sky color
    }

    private func renderTerrain(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.setRenderPipelineState(terrainPipelineState)
        renderEncoder.setVertexBuffer(cameraUniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(lightUniformBuffer, offset: 0, index: 3)

        for terrainChunk in terrainChunks {
            terrainChunk.render(renderEncoder: renderEncoder)
        }
    }

    private func renderModels(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.setRenderPipelineState(modelPipelineState)
        renderEncoder.setVertexBuffer(cameraUniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(lightUniformBuffer, offset: 0, index: 3)

        for model in modelsToRender {
            // Update model uniforms
            var modelUniforms = ModelUniforms(
                modelMatrix: model.transform.modelMatrix,
                normalMatrix: model.transform.normalMatrix
            )
            memcpy(modelUniformBuffer.contents(), &modelUniforms, MemoryLayout<ModelUniforms>.stride)

            renderEncoder.setVertexBuffer(modelUniformBuffer, offset: 0, index: 2)
            renderEncoder.setFragmentBuffer(modelUniformBuffer, offset: 0, index: 2)

            model.render(renderEncoder: renderEncoder, textureAtlas: textureAtlas)
        }
    }

    // MARK: - Public API

    func setCamera(_ camera: Camera3D) {
        self.camera = camera
    }

    func getCamera() -> Camera3D {
        return camera
    }

    func addLight(_ light: Light) {
        lights.append(light)
        // Limit to 4 lights for performance
        if lights.count > 4 {
            lights.removeFirst()
        }
    }

    func queueModel(_ model: RenderModel) {
        modelsToRender.append(model)
    }

    func addTerrainChunk(_ chunk: TerrainChunk) {
        terrainChunks.append(chunk)
    }

    func removeTerrainChunk(_ chunk: TerrainChunk) {
        terrainChunks.removeAll { $0 === chunk }
    }

    func queueTerrainChunks(_ chunks: [TerrainChunk]) {
        terrainChunks.append(contentsOf: chunks)
    }

    func clearTerrainChunks() {
        terrainChunks.removeAll()
    }

    // MARK: - Utility

    func screenToWorld(screenPoint: Vector2, screenSize: Vector2) -> Vector3? {
        return camera.screenToWorld(screenPoint: screenPoint, screenSize: screenSize)
    }

    func worldToScreen(worldPoint: Vector3, screenSize: Vector2) -> Vector2? {
        return camera.worldToScreen(worldPoint: worldPoint, screenSize: screenSize)
    }
}

// MARK: - Error Types

enum RendererError: Error {
    case failedToCreateCommandQueue
    case failedToCreateShaders
    case failedToCreatePipelineState
}

// MARK: - Data Structures

struct CameraUniforms {
    var viewMatrix: Matrix4
    var projectionMatrix: Matrix4
    var viewProjectionMatrix: Matrix4
    var cameraPosition: Vector3
}

struct LightUniforms {
    var lightCount: UInt32 = 0
    var light0: Light = .default
    var light1: Light = .default
    var light2: Light = .default
    var light3: Light = .default
}

struct ModelUniforms {
    var modelMatrix: Matrix4
    var normalMatrix: Matrix3
}

// MARK: - Supporting Types

struct Light {
    enum LightType: UInt32 {
        case directional = 0
        case point = 1
        case spot = 2
        case ambient = 3
    }

    var type: LightType
    var position: Vector3
    var direction: Vector3
    var color: Vector3
    var intensity: Float
    var range: Float
    var spotAngle: Float

    static var `default`: Light {
        return Light(
            type: .directional,
            position: .zero,
            direction: Vector3(0, -1, 0),
            color: Vector3(1, 1, 1),
            intensity: 1.0,
            range: 1000,
            spotAngle: 0
        )
    }
}

protocol RenderModel {
    var transform: Transform3D { get }
    func render(renderEncoder: MTLRenderCommandEncoder, textureAtlas: TextureAtlas)
}

protocol TerrainChunk: AnyObject {
    func render(renderEncoder: MTLRenderCommandEncoder)
}
