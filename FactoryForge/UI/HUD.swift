import Foundation
import UIKit

/// Heads-up display showing vital game info
final class HUD {
    private var screenSize: Vector2
    private weak var gameLoop: GameLoop?
    private weak var inputManager: InputManager?
    
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
    var onMenuPressed: (() -> Void)? // Called when menu button is pressed
    var onQuickBarSlotSelected: ((Int) -> Void)? // Called when a quick bar slot is selected
    
    // Selected quick bar slot
    var selectedQuickBarSlot: Int? = nil
    
    // Mining animations
    private struct MiningAnimation {
        var itemId: String
        var startPosition: Vector2  // World position
        var targetPosition: Vector2  // Screen position (inventory button)
        var currentPosition: Vector2  // Current screen position
        var currentSize: Vector2
        var startSize: Vector2
        var targetSize: Vector2
        var progress: Float  // 0 to 1
        var duration: Float
        var elapsedTime: Float
    }
    
    private var miningAnimations: [MiningAnimation] = []

    
    init(screenSize: Vector2, gameLoop: GameLoop?, inputManager: InputManager?) {
        self.screenSize = screenSize
        self.gameLoop = gameLoop
        self.inputManager = inputManager
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

    func setInputManager(_ inputManager: InputManager?) {
        self.inputManager = inputManager
    }
    
    func update(deltaTime: Float) {
        // Update mining animations
        updateMiningAnimations(deltaTime: deltaTime)
    }
    
    private func updateMiningAnimations(deltaTime: Float) {
        for i in (0..<miningAnimations.count).reversed() {
            var animation = miningAnimations[i]
            animation.elapsedTime += deltaTime
            animation.progress = min(animation.elapsedTime / animation.duration, 1.0)
            
            // Update position (lerp from start to target)
            animation.currentPosition = animation.startPosition.lerp(to: animation.targetPosition, t: animation.progress)
            
            // Update size (lerp from start to target, with easing for scale up)
            let easeProgress = easeOutCubic(animation.progress) // Ease out for smooth scaling
            animation.currentSize = animation.startSize.lerp(to: animation.targetSize, t: easeProgress)
            
            if animation.progress >= 1.0 {
                // Animation complete - remove it
                miningAnimations.remove(at: i)
            } else {
                miningAnimations[i] = animation
            }
        }
    }
    
    private func easeOutCubic(_ t: Float) -> Float {
        let t1 = 1.0 - t
        return 1.0 - t1 * t1 * t1
    }
    
    /// Starts a mining animation from a world position to the inventory button
    func startMiningAnimation(itemId: String, fromWorldPosition worldPos: Vector2, renderer: MetalRenderer?) {
        guard let renderer = renderer else { return }
        
        // Get inventory button position (screen coordinates)
        let toolbarY = screenSize.y - bottomMargin - buttonSize / 2
        let inventoryButtonX = screenSize.x / 2 - (buttonSize * 2 + buttonSpacing * 1.5)
        let targetScreenPos = Vector2(inventoryButtonX, toolbarY)
        
        // Convert world position to screen position
        let startScreenPos = renderer.worldToScreen(worldPos)
        
        // Start size: small (about 20 points)
        let startSize = Vector2(20 * scale, 20 * scale)
        // Target size: same as inventory button
        let targetSize = Vector2(buttonSize, buttonSize)
        
        let animation = MiningAnimation(
            itemId: itemId,
            startPosition: startScreenPos,
            targetPosition: targetScreenPos,
            currentPosition: startScreenPos,
            currentSize: startSize,
            startSize: startSize,
            targetSize: targetSize,
            progress: 0,
            duration: 0.5, // 0.5 seconds
            elapsedTime: 0
        )
        
        miningAnimations.append(animation)
        
        // Play mining sound
        AudioManager.shared.playMiningSound()
    }
    
    func getButtonName(at position: Vector2, screenSize: Vector2) -> String? {
        self.screenSize = screenSize

        // Calculate toolbar positions
        let toolbarY = screenSize.y - bottomMargin - buttonSize / 2
        var currentX = screenSize.x / 2 - (buttonSize * 2 + buttonSpacing * 1.5)

        // Check inventory button
        if checkButtonTap(at: position, buttonPos: Vector2(currentX, toolbarY)) {
            return "Inventory"
        }
        currentX += buttonSize + buttonSpacing

        if checkButtonTap(at: position, buttonPos: Vector2(currentX, toolbarY)) {
            return "Crafting"
        }
        currentX += buttonSize + buttonSpacing

        if checkButtonTap(at: position, buttonPos: Vector2(currentX, toolbarY)) {
            return "Build"
        }
        currentX += buttonSize + buttonSpacing

        if checkButtonTap(at: position, buttonPos: Vector2(currentX, toolbarY)) {
            return "Research"
        }

        return nil
    }
    
    func render(renderer: MetalRenderer) {
        // Update screen size from renderer
        screenSize = renderer.screenSize

        // If player is dead, don't render HUD (UIKit handles game over screen)
        if let gameLoop = gameLoop, gameLoop.isPlayerDead {
            return
        }

        // Calculate toolbar positions
        let toolbarY = screenSize.y - bottomMargin - buttonSize / 2
        var currentX = screenSize.x / 2 - (buttonSize * 2 + buttonSpacing * 1.5)

        // Render inventory button
        // print("Rendering inventory button at Metal position (\(currentX), \(toolbarY))")
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

        // Render health bar
        renderHealthBar(renderer: renderer)

        // Render menu button (top-right corner)
        renderMenuButton(renderer: renderer)

        // Render mining animations
        renderMiningAnimations(renderer: renderer)

        // Render build preview if in build mode
        renderBuildPreview(renderer: renderer)
    }
    
    private func renderMenuButton(renderer: MetalRenderer) {
        // Menu button in top-right corner
        let buttonX = screenSize.x - bottomMargin - buttonSize / 2
        let buttonY = bottomMargin + buttonSize / 2
        
        renderButton(renderer: renderer, position: Vector2(buttonX, buttonY), textureId: "menu", callback: onMenuPressed)
    }
    

    private func renderBuildPreview(renderer: MetalRenderer) {
        guard let inputManager = inputManager,
              inputManager.buildMode == .placing,
              let buildingId = inputManager.selectedBuildingId,
              let previewPos = inputManager.buildPreviewPosition,
              let gameLoop = gameLoop,
              let buildingDef = gameLoop.buildingRegistry.get(buildingId) else {
            return
        }

        // Convert tile position to world position (center of tile)
        let worldPos = Vector2(Float(previewPos.x) + 0.5, Float(previewPos.y) + 0.5)

        // Check if placement is valid
        let isValidPlacement = gameLoop.canPlaceBuilding(buildingId, at: previewPos, direction: inputManager.buildDirection)

        // Choose color based on validity
        let previewColor = isValidPlacement ?
            Color(r: 0.2, g: 0.8, b: 0.2, a: 0.6) :  // Green for valid
            Color(r: 0.8, g: 0.2, b: 0.2, a: 0.6)    // Red for invalid

        // Get building texture
        let textureRect = renderer.textureAtlas.getTextureRect(for: buildingDef.textureId)

        // Render ghost preview
        renderer.queueSprite(SpriteInstance(
            position: worldPos,
            size: Vector2(1.0, 1.0), // Standard tile size
            textureRect: textureRect,
            color: previewColor,
            layer: .entity // Render above ground but below UI
        ))
    }

    private func renderMiningAnimations(renderer: MetalRenderer) {
        for animation in miningAnimations {
            // Get texture for the item
            let textureId = animation.itemId.replacingOccurrences(of: "-", with: "_")
            let textureRect = renderer.textureAtlas.getTextureRect(for: textureId)
            
            // Render the animated sprite
            renderer.queueSprite(SpriteInstance(
                position: animation.currentPosition,
                size: animation.currentSize,
                textureRect: textureRect,
                color: .white,
                layer: .ui
            ))
        }
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
        // Highlight if selected
        let isSelected = selectedQuickBarSlot == index
        let bgColor = isSelected ? 
            Color(r: 0.3, g: 0.3, b: 0.4, a: 0.9) : 
            Color(r: 0.15, g: 0.15, b: 0.2, a: 0.9)
        
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: position,
            size: Vector2(slotSize, slotSize),
            textureRect: solidRect,
            color: bgColor,
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
    
    func handleTap(at position: Vector2, screenSize: Vector2) -> Bool {
        // Use provided screen size for consistent layout
        self.screenSize = screenSize

        // Position is already in UIKit coordinates (top-left origin, Y increases downward)
        // Button positions are also in UIKit coordinates, so no conversion needed

        // When player is dead, don't handle any HUD taps (UIKit labels handle input)
        if let gameLoop = gameLoop, gameLoop.isPlayerDead {
            return false
        }

        // Calculate toolbar positions (same as render)
        let toolbarY = screenSize.y - bottomMargin - buttonSize / 2
        var currentX = screenSize.x / 2 - (buttonSize * 2 + buttonSpacing * 1.5)

        // Check inventory button
        if checkButtonTap(at: position, buttonPos: Vector2(currentX, toolbarY)) {
            print("HUD: Inventory button tapped, calling callback")
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

        // Check menu button (top-right corner)
        let buttonX = screenSize.x - bottomMargin - buttonSize / 2
        let buttonY = bottomMargin + buttonSize / 2
        if checkButtonTap(at: position, buttonPos: Vector2(buttonX, buttonY)) {
            onMenuPressed?()
            return true
        }

        // Check quick bar slots
        let quickBarY = screenSize.y - bottomMargin - buttonSize - buttonSpacing - slotSize / 2
        let quickBarStartX = screenSize.x / 2 - (slotSize * 5 + buttonSpacing * 4) / 2

        for i in 0..<10 {
            let slotX = quickBarStartX + Float(i) * (slotSize + buttonSpacing / 2)
            let slotPos = Vector2(slotX, quickBarY)
            let slotFrame = Rect(center: slotPos, size: Vector2(slotSize, slotSize))

            if slotFrame.contains(position) {
                // Quick bar slot tapped
                selectedQuickBarSlot = i
                onQuickBarSlotSelected?(i)
                print("HUD: Quick bar slot \(i) tapped")
                return true
            }
        }

        return false
    }
    
    private func checkButtonTap(at position: Vector2, buttonPos: Vector2) -> Bool {
        let frame = Rect(center: buttonPos, size: Vector2(buttonSize, buttonSize))
        let contains = frame.contains(position)
        return contains
    }
}

