import MetalKit
import Foundation

/// MTKViewDelegate bridge for driving the 3D renderer from the game loop.
@available(iOS 17.0, *)
final class Metal3DViewDelegate: NSObject, MTKViewDelegate {
    private let renderer3D: Metal3DRenderer
    private let camera: Camera3D
    private weak var renderer2D: MetalRenderer?
    private weak var gameLoop: GameLoop?
    private var modelRenderer: ModelRenderer3D?
    private var terrainRenderer: TerrainRenderer3D?
    var shouldUpdateGameLoop: Bool = true

    init(renderer3D: Metal3DRenderer, camera: Camera3D, renderer2D: MetalRenderer) {
        self.renderer3D = renderer3D
        self.camera = camera
        self.renderer2D = renderer2D
        super.init()
    }

    func setGameLoop(_ gameLoop: GameLoop?) {
        self.gameLoop = gameLoop
    }

    func setModelRenderer(_ modelRenderer: ModelRenderer3D?) {
        self.modelRenderer = modelRenderer
    }

    func setTerrainRenderer(_ terrainRenderer: TerrainRenderer3D?) {
        self.terrainRenderer = terrainRenderer
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let height = max(size.height, 1.0)
        let ratio = Float(size.width / height)
        camera.setAspectRatio(ratio)
    }

    func draw(in view: MTKView) {
        guard let gameLoop = gameLoop else { return }

        if shouldUpdateGameLoop {
            gameLoop.update()
        }

        syncCameraFrom2D()

        modelRenderer?.updateModels()
        if let terrainRenderer = terrainRenderer {
            terrainRenderer.updateTerrainChunks()
            renderer3D.queueTerrainChunks(terrainRenderer.getTerrainChunks())
        }

        guard let drawable = view.currentDrawable else { return }
        renderer3D.render(to: view, drawable: drawable)
    }

    private func syncCameraFrom2D() {
        guard let renderer2D = renderer2D else { return }

        let camera2D = renderer2D.camera
        camera.target = Vector3(camera2D.position.x, 0, camera2D.position.y)

        let zoom = max(camera2D.zoom, 0.1)
        let desiredDistance = max(camera.minDistance, min(camera.maxDistance, 100.0 / zoom))
        if abs(desiredDistance - camera.distance) > 0.01 {
            camera.setDistance(desiredDistance)
        }

        camera.update(deltaTime: Float(Time.shared.deltaTime))
    }
}
