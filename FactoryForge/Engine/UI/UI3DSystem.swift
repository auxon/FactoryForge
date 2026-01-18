import Metal
import MetalKit
import UIKit
import Foundation

/// 3D UI System that integrates 2D UI overlays with 3D world positioning
@available(iOS 17.0, *)
final class UI3DSystem {
    private let device: MTLDevice
    private weak var camera: Camera3D?
    private weak var metalRenderer: Metal3DRenderer?

    // UI Elements
    private var worldSpaceUIElements: [WorldSpaceUIElement] = []
    private var screenSpaceUIElements: [ScreenSpaceUIElement] = []

    // Selection indicator
    private var selectionIndicator: SelectionIndicator3D?

    // Health bars and other overlays
    private var entityHealthBars: [Entity: HealthBar3D] = [:]

    init(device: MTLDevice, camera: Camera3D, metalRenderer: Metal3DRenderer) {
        self.device = device
        self.camera = camera
        self.metalRenderer = metalRenderer
    }

    // MARK: - World Space UI

    func addWorldSpaceUIElement(_ element: WorldSpaceUIElement) {
        worldSpaceUIElements.append(element)
    }

    func removeWorldSpaceUIElement(_ element: WorldSpaceUIElement) {
        worldSpaceUIElements.removeAll { $0 === element }
    }

    func addScreenSpaceUIElement(_ element: ScreenSpaceUIElement) {
        screenSpaceUIElements.append(element)
    }

    func removeScreenSpaceUIElement(_ element: ScreenSpaceUIElement) {
        // Cast to AnyObject to use reference equality
        let elementObj = element as any AnyObject
        screenSpaceUIElements.removeAll { ($0 as any AnyObject) === elementObj }
    }

    // MARK: - Selection

    func setSelectedEntity(_ entity: Entity?, position: Vector3?) {
        if let _ = entity, let position = position {
            // Create or update selection indicator
            if selectionIndicator == nil {
                selectionIndicator = SelectionIndicator3D(device: device)
            }
            selectionIndicator?.updatePosition(position)
            selectionIndicator?.setVisible(true)
        } else {
            // Hide selection indicator
            selectionIndicator?.setVisible(false)
        }
    }

    // MARK: - Health Bars

    func updateEntityHealthBar(entity: Entity, currentHealth: Float, maxHealth: Float, position: Vector3) {
        if entityHealthBars[entity] == nil {
            entityHealthBars[entity] = HealthBar3D(device: device)
        }

        let healthBar = entityHealthBars[entity]!
        healthBar.updateHealth(currentHealth: currentHealth, maxHealth: maxHealth)
        healthBar.updatePosition(position + Vector3(0, 2, 0)) // Above entity
        healthBar.setVisible(currentHealth < maxHealth) // Only show when damaged
    }

    func removeEntityHealthBar(entity: Entity) {
        entityHealthBars.removeValue(forKey: entity)
    }

    // MARK: - Rendering

    func render(to view: MTKView, commandBuffer: MTLCommandBuffer) {
        // Render world space UI elements
        renderWorldSpaceUI(commandBuffer: commandBuffer)

        // Render screen space UI elements
        renderScreenSpaceUI(to: view, commandBuffer: commandBuffer)
    }

    private func renderWorldSpaceUI(commandBuffer: MTLCommandBuffer) {
        // World space UI is rendered as part of the 3D scene
        // The Metal3DRenderer will handle these through the queued models
        for element in worldSpaceUIElements {
            if let model = element.getModel() {
                metalRenderer?.queueModel(model)
            }
        }

        // Render selection indicator
        if let indicator = selectionIndicator, indicator.isVisible {
            metalRenderer?.queueModel(indicator)
        }

        // Render health bars
        for healthBar in entityHealthBars.values where healthBar.isVisible {
            metalRenderer?.queueModel(healthBar)
        }
    }

    private func renderScreenSpaceUI(to view: MTKView, commandBuffer: MTLCommandBuffer) {
        // Screen space UI elements are rendered as 2D overlays
        // This would typically be handled by a separate 2D rendering pass
        // For now, we'll use UIKit overlays for screen space elements

        for element in screenSpaceUIElements {
            element.renderToScreen()
        }
    }

    // MARK: - Utility

    func worldToScreen(worldPoint: Vector3, screenSize: Vector2) -> Vector2? {
        return camera?.worldToScreen(worldPoint: worldPoint, screenSize: screenSize)
    }

    func screenToWorld(screenPoint: Vector2, screenSize: Vector2) -> Vector3? {
        return camera?.screenToWorld(screenPoint: screenPoint, screenSize: screenSize)
    }

    func createFloatingText(at worldPosition: Vector3, text: String, color: UIColor = .white, duration: Float = 2.0) {
        let floatingText = FloatingText3D(
            text: text,
            position: worldPosition,
            color: color,
            duration: duration,
            device: device
        )
        addWorldSpaceUIElement(floatingText)

        // Auto-remove after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(duration)) {
            self.removeWorldSpaceUIElement(floatingText)
        }
    }

    func createDamageNumber(at worldPosition: Vector3, damage: Float, isCritical: Bool = false) {
        let text = String(format: "%.0f", damage)
        let color: UIColor = isCritical ? .red : .orange
        createFloatingText(at: worldPosition + Vector3(0, 1, 0), text: text, color: color, duration: 1.5)
    }
}

// MARK: - UI Element Protocols

protocol WorldSpaceUIElement: AnyObject {
    func getModel() -> RenderModel?
    func update(deltaTime: Float)
}

protocol ScreenSpaceUIElement {
    func renderToScreen()
    func update(deltaTime: Float)
}

// MARK: - Concrete UI Elements

@available(iOS 17.0, *)
final class SelectionIndicator3D: RenderModel, WorldSpaceUIElement {
    private let model: Model3D
    var transform = Transform3D()
    var isVisible = false

    init(device: MTLDevice) {
        let modelGenerator = Model3DGenerator(device: device)
        self.model = modelGenerator.createCubeModel(Color(r: 0.2, g: 0.8, b: 0.2, a: 0.5))
        // Make it a ring/cylinder around the selected unit
        transform.scale = Vector3(1.2, 0.1, 1.2)
    }

    func updatePosition(_ position: Vector3) {
        transform.position = position + Vector3(0, 0.1, 0) // Slightly above ground
    }

    func setVisible(_ visible: Bool) {
        isVisible = visible
    }

    func getModel() -> RenderModel? {
        return isVisible ? self : nil
    }

    func update(deltaTime: Float) {
        // Pulsing animation
        let pulse = sin(Float(Date().timeIntervalSince1970) * 4) * 0.1 + 0.9
        transform.scale = Vector3(1.2 * pulse, 0.1, 1.2 * pulse)
    }

    func render(renderEncoder: MTLRenderCommandEncoder, textureAtlas: TextureAtlas) {
        model.transform = transform
        model.render(renderEncoder: renderEncoder, textureAtlas: textureAtlas)
    }
}

@available(iOS 17.0, *)
final class HealthBar3D: RenderModel, WorldSpaceUIElement {
    private let backgroundModel: Model3D
    private let foregroundModel: Model3D
    var transform = Transform3D()
    private var healthRatio: Float = 1.0
    var isVisible = true

    init(device: MTLDevice) {
        // Background (gray)
        backgroundModel = Model3DGenerator(device: device).createCubeModel(Color(r: 0.3, g: 0.3, b: 0.3, a: 0.8))

        // Foreground (green to red based on health)
        foregroundModel = Model3DGenerator(device: device).createCubeModel(Color(r: 0.2, g: 0.8, b: 0.2, a: 0.9))

        transform.scale = Vector3(1, 0.1, 0.1) // Thin horizontal bar
    }

    func updateHealth(currentHealth: Float, maxHealth: Float) {
        healthRatio = max(0, min(1, currentHealth / maxHealth))
    }

    func updatePosition(_ position: Vector3) {
        transform.position = position
    }

    func setVisible(_ visible: Bool) {
        isVisible = visible
    }

    func getModel() -> RenderModel? {
        return isVisible ? self : nil
    }

    func update(deltaTime: Float) {
        // Update color based on health
        _ = healthRatio > 0.6 ? Color(r: 0.2, g: 0.8, b: 0.2, a: 0.9) :  // Green
                   healthRatio > 0.3 ? Color(r: 0.8, g: 0.8, b: 0.2, a: 0.9) :   // Yellow
                   Color(r: 0.8, g: 0.2, b: 0.2, a: 0.9)                          // Red

        // Update foreground model color (this is a simplified approach)
        // In a real implementation, you'd update the model's mesh colors
    }

    func render(renderEncoder: MTLRenderCommandEncoder, textureAtlas: TextureAtlas) {
        // Render background
        let bgTransform = transform
        backgroundModel.transform = bgTransform
        backgroundModel.render(renderEncoder: renderEncoder, textureAtlas: textureAtlas)

        // Render foreground (scaled based on health)
        var fgTransform = transform
        fgTransform.scale.x *= healthRatio
        fgTransform.position.x -= (transform.scale.x - fgTransform.scale.x) * 0.5 // Center it

        foregroundModel.transform = fgTransform
        foregroundModel.render(renderEncoder: renderEncoder, textureAtlas: textureAtlas)
    }
}

@available(iOS 17.0, *)
final class FloatingText3D: WorldSpaceUIElement {
    private let text: String
    private var position: Vector3
    private let color: UIColor
    private let duration: Float
    private var elapsed: Float = 0
    private var model: TextModel3D?

    init(text: String, position: Vector3, color: UIColor, duration: Float, device: MTLDevice) {
        self.text = text
        self.position = position
        self.color = color
        self.duration = duration
        self.model = TextModel3D(text: text, color: color, device: device)
    }

    func getModel() -> RenderModel? {
        return model
    }

    func update(deltaTime: Float) {
        elapsed += deltaTime

        // Float upward over time
        position.y += deltaTime * 2.0

        // Fade out near end
        let fadeStart = duration * 0.7
        if elapsed > fadeStart {
            let fadeProgress = (elapsed - fadeStart) / (duration - fadeStart)
            model?.setAlpha(1.0 - fadeProgress)
        }

        // Update model position
        model?.updatePosition(position)
    }

    var isExpired: Bool {
        return elapsed >= duration
    }
}

/// Simplified 3D text model (would need proper text rendering implementation)
@available(iOS 17.0, *)
final class TextModel3D: RenderModel {
    private let text: String
    private let color: UIColor
    private var position: Vector3 = .zero
    private var alpha: Float = 1.0

    var transform: Transform3D {
        var t = Transform3D()
        t.position = position
        return t
    }

    init(text: String, color: UIColor, device: MTLDevice) {
        self.text = text
        self.color = color
        // In a real implementation, this would create actual 3D text geometry
    }

    func updatePosition(_ position: Vector3) {
        self.position = position
    }

    func setAlpha(_ alpha: Float) {
        self.alpha = alpha
    }

    func render(renderEncoder: MTLRenderCommandEncoder, textureAtlas: TextureAtlas) {
        // Placeholder - real implementation would render 3D text
        // This would use a texture atlas with pre-rendered text or
        // generate geometry for each character
    }
}