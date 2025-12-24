import Foundation
import UIKit

/// Heads-up display showing vital game info
final class HUD {
    private var screenSize: Vector2
    private weak var gameLoop: GameLoop?
    
    // Scale factor for retina displays
    private let scale: Float = Float(UIScreen.main.scale)
    
    // Layout constants (in points, will be multiplied by scale)
    private var buttonSize: Float { 60 * scale }
    private var buttonSpacing: Float { 10 * scale }
    private var bottomMargin: Float { 30 * scale }
    private var slotSize: Float { 50 * scale }
    
    // Virtual joystick for movement
    let joystick: VirtualJoystick
    
    // Callbacks
    var onInventoryPressed: (() -> Void)?
    var onCraftingPressed: (() -> Void)?
    var onBuildPressed: (() -> Void)?
    var onResearchPressed: (() -> Void)?
    
    init(screenSize: Vector2, gameLoop: GameLoop?) {
        self.screenSize = screenSize
        self.gameLoop = gameLoop
        self.joystick = VirtualJoystick()
        
        joystick.updateScreenSize(screenSize)
        
        // Connect joystick to player movement
        joystick.onDirectionChanged = { [weak gameLoop] direction in
            if direction.lengthSquared > 0.001 {
                gameLoop?.player.setMoveDirection(direction)
            } else {
                gameLoop?.player.stopMoving()
            }
        }
    }
    
    func updateScreenSize(_ newSize: Vector2) {
        screenSize = newSize
        joystick.updateScreenSize(newSize)
    }
    
    func update(deltaTime: Float) {
        // HUD updates are minimal - most rendering is done dynamically
    }
    
    func render(renderer: MetalRenderer) {
        // Update screen size from renderer
        screenSize = renderer.screenSize
        
        // Calculate toolbar positions
        let toolbarY = screenSize.y - bottomMargin - buttonSize / 2
        var currentX = screenSize.x / 2 - (buttonSize * 2 + buttonSpacing * 1.5)
        
        // Render inventory button
        renderButton(renderer: renderer, position: Vector2(currentX, toolbarY), textureId: "chest", callback: onInventoryPressed)
        currentX += buttonSize + buttonSpacing
        
        // Render crafting button
        renderButton(renderer: renderer, position: Vector2(currentX, toolbarY), textureId: "gear", callback: onCraftingPressed)
        currentX += buttonSize + buttonSpacing
        
        // Render build button
        renderButton(renderer: renderer, position: Vector2(currentX, toolbarY), textureId: "assembler", callback: onBuildPressed)
        currentX += buttonSize + buttonSpacing
        
        // Render research button
        renderButton(renderer: renderer, position: Vector2(currentX, toolbarY), textureId: "lab", callback: onResearchPressed)
        
        // Render quick bar
        let quickBarY = screenSize.y - bottomMargin - buttonSize - buttonSpacing - slotSize / 2
        let quickBarStartX = screenSize.x / 2 - (slotSize * 5 + buttonSpacing * 4) / 2
        
        for i in 0..<10 {
            let slotX = quickBarStartX + Float(i) * (slotSize + buttonSpacing / 2)
            renderQuickBarSlot(renderer: renderer, index: i, position: Vector2(slotX, quickBarY))
        }
        
            // Render virtual joystick
            joystick.updateScreenSize(screenSize)
            joystick.render(renderer: renderer)
        
        // Debug: Render direction indicator in top-right
        renderDirectionDebug(renderer: renderer)
        
        // Render health bar
        renderHealthBar(renderer: renderer)
        
        // Render minimap
        renderMinimap(renderer: renderer)
        
        // Render resource counters
        renderResourceCounters(renderer: renderer)
    }
    
    private func renderButton(renderer: MetalRenderer, position: Vector2, textureId: String, callback: (() -> Void)?) {
        // Button background - use solid_white texture with tinted color
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: position,
            size: Vector2(buttonSize, buttonSize),
            textureRect: solidRect,
            color: Color(r: 0.2, g: 0.2, b: 0.25, a: 0.9),
            layer: .ui
        ))
        
        // Button icon
        let textureRect = renderer.textureAtlas.getTextureRect(for: textureId)
        renderer.queueSprite(SpriteInstance(
            position: position,
            size: Vector2(buttonSize - 10, buttonSize - 10),
            textureRect: textureRect,
            layer: .ui
        ))
    }
    
    private func renderQuickBarSlot(renderer: MetalRenderer, index: Int, position: Vector2) {
        // Slot background - use solid_white texture with tinted color
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: position,
            size: Vector2(slotSize, slotSize),
            textureRect: solidRect,
            color: Color(r: 0.15, g: 0.15, b: 0.2, a: 0.9),
            layer: .ui
        ))
        
        // Item if present
        if let player = gameLoop?.player, index < player.inventory.slots.count {
            if let item = player.inventory.slots[index] {
                let textureRect = renderer.textureAtlas.getTextureRect(for: item.itemId.replacingOccurrences(of: "-", with: "_"))
                renderer.queueSprite(SpriteInstance(
                    position: position,
                    size: Vector2(slotSize * 0.8, slotSize * 0.8),
                    textureRect: textureRect,
                    layer: .ui
                ))
            }
        }
    }
    
    private func renderHealthBar(renderer: MetalRenderer) {
        guard let player = gameLoop?.player else { return }
        
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        
        let barWidth: Float = 200 * scale
        let barHeight: Float = 20 * scale
        let margin: Float = 20 * scale
        let barX = margin + barWidth / 2
        let barY = margin + barHeight / 2
        
        // Background
        renderer.queueSprite(SpriteInstance(
            position: Vector2(barX, barY),
            size: Vector2(barWidth, barHeight),
            textureRect: solidRect,
            color: Color(r: 0.2, g: 0.2, b: 0.2, a: 0.8),
            layer: .ui
        ))
        
        // Health fill
        let healthPercent = player.health / player.maxHealth
        let fillWidth = barWidth * healthPercent
        renderer.queueSprite(SpriteInstance(
            position: Vector2(margin + fillWidth / 2, barY),
            size: Vector2(fillWidth, barHeight - 4 * scale),
            textureRect: solidRect,
            color: Color(r: 0.8, g: 0.2, b: 0.2, a: 1),
            layer: .ui
        ))
    }
    
    private func renderDirectionDebug(renderer: MetalRenderer) {
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        
        // Debug panel in top-right corner
        let panelSize: Float = 120 * scale
        let margin: Float = 20 * scale
        let panelCenter = Vector2(screenSize.x - margin - panelSize / 2, margin + panelSize / 2)
        
        // Background
        renderer.queueSprite(SpriteInstance(
            position: panelCenter,
            size: Vector2(panelSize, panelSize),
            textureRect: solidRect,
            color: Color(r: 0.1, g: 0.1, b: 0.15, a: 0.8),
            layer: .ui
        ))
        
        // Cross hairs
        let crossSize: Float = 2 * scale
        renderer.queueSprite(SpriteInstance(
            position: panelCenter,
            size: Vector2(panelSize - 20 * scale, crossSize),
            textureRect: solidRect,
            color: Color(r: 0.3, g: 0.3, b: 0.4, a: 0.5),
            layer: .ui
        ))
        renderer.queueSprite(SpriteInstance(
            position: panelCenter,
            size: Vector2(crossSize, panelSize - 20 * scale),
            textureRect: solidRect,
            color: Color(r: 0.3, g: 0.3, b: 0.4, a: 0.5),
            layer: .ui
        ))
        
        // Direction indicator dot
        let dir = joystick.direction
        let indicatorSize: Float = 16 * scale
        let indicatorPos = panelCenter + Vector2(
            dir.x * (panelSize / 2 - indicatorSize),
            -dir.y * (panelSize / 2 - indicatorSize)  // Invert Y for screen coords
        )
        
        // Color based on activity: bright when moving, dim when idle
        let isMoving = dir.lengthSquared > 0.01
        let color = isMoving ? Color(r: 0.2, g: 1.0, b: 0.4, a: 1) : Color(r: 0.5, g: 0.5, b: 0.6, a: 0.5)
        
        renderer.queueSprite(SpriteInstance(
            position: indicatorPos,
            size: Vector2(indicatorSize, indicatorSize),
            textureRect: solidRect,
            color: color,
            layer: .ui
        ))
    }
    
    private func renderMinimap(renderer: MetalRenderer) {
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        
        let minimapSize: Float = 150 * scale
        let margin: Float = 20 * scale
        let minimapCenter = Vector2(screenSize.x - margin - minimapSize / 2, margin + minimapSize / 2)
        
        // Background
        renderer.queueSprite(SpriteInstance(
            position: minimapCenter,
            size: Vector2(minimapSize, minimapSize),
            textureRect: solidRect,
            color: Color(r: 0.1, g: 0.15, b: 0.1, a: 0.8),
            layer: .ui
        ))
        
        // Player dot
        renderer.queueSprite(SpriteInstance(
            position: minimapCenter,
            size: Vector2(8 * scale, 8 * scale),
            textureRect: solidRect,
            color: Color(r: 1, g: 1, b: 1, a: 1),
            layer: .ui
        ))
    }
    
    private func renderResourceCounters(renderer: MetalRenderer) {
        // Resource counters in top left (below health bar)
        let resources = ["iron-plate", "copper-plate", "coal", "stone"]
        let counterY: Float = 60 * scale
        var currentX: Float = 20 * scale
        let iconSize: Float = 30 * scale
        
        guard let player = gameLoop?.player else { return }
        
        for resourceId in resources {
            let count = player.inventory.count(of: resourceId)
            
            // Icon
            let textureRect = renderer.textureAtlas.getTextureRect(for: resourceId.replacingOccurrences(of: "-", with: "_"))
            renderer.queueSprite(SpriteInstance(
                position: Vector2(currentX + iconSize / 2, counterY),
                size: Vector2(iconSize, iconSize),
                textureRect: textureRect,
                layer: .ui
            ))
            
            currentX += 80 * scale
        }
    }
    
    func handleTap(at position: Vector2, screenSize: Vector2) -> Bool {
        // Use provided screen size for consistent layout
        self.screenSize = screenSize
        
        // Calculate toolbar positions (same as render)
        let toolbarY = screenSize.y - bottomMargin - buttonSize / 2
        var currentX = screenSize.x / 2 - (buttonSize * 2 + buttonSpacing * 1.5)
        
        // Check inventory button
        if checkButtonTap(at: position, buttonPos: Vector2(currentX, toolbarY)) {
            onInventoryPressed?()
            return true
        }
        currentX += buttonSize + buttonSpacing
        
        // Check crafting button
        if checkButtonTap(at: position, buttonPos: Vector2(currentX, toolbarY)) {
            onCraftingPressed?()
            return true
        }
        currentX += buttonSize + buttonSpacing
        
        // Check build button
        if checkButtonTap(at: position, buttonPos: Vector2(currentX, toolbarY)) {
            onBuildPressed?()
            return true
        }
        currentX += buttonSize + buttonSpacing
        
        // Check research button
        if checkButtonTap(at: position, buttonPos: Vector2(currentX, toolbarY)) {
            onResearchPressed?()
            return true
        }
        
        // Check quick bar slots - for now, don't intercept world taps
        // The quick bar is for future use, so don't block world interaction

        return false
    }
    
    private func checkButtonTap(at position: Vector2, buttonPos: Vector2) -> Bool {
        let frame = Rect(center: buttonPos, size: Vector2(buttonSize, buttonSize))
        return frame.contains(position)
    }
}

