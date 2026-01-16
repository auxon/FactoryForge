import Foundation
import UIKit

/// Heads-up display showing vital game info
@available(iOS 17.0, *)
final class HUD {
    private var screenSize: Vector2
    private weak var gameLoop: GameLoop?
    private weak var inputManager: InputManager?
    
    // Scale factor for retina displays
    private let scale: Float = Float(UIScreen.main.scale)
    
    // Layout constants (in points, will be multiplied by scale)
    private var buttonSize: Float { 48 * scale }  // Reduced from 60 to fit 5 buttons on screen
    private var buttonSpacing: Float { 8 * scale }  // Reduced from 10 for better spacing
    private var bottomMargin: Float { 20 * scale }  // Reduced from 30 to position buttons closer to bottom
    
    // Virtual joystick for movement
    let joystick: VirtualJoystick
    
    // Callbacks
    var onInventoryPressed: (() -> Void)?
    var onCraftingPressed: (() -> Void)?
    var onBuildPressed: (() -> Void)?
    var onResearchPressed: (() -> Void)?
    var onBuyPressed: (() -> Void)? // Called when buy button is pressed
    var onMenuPressed: (() -> Void)? // Called when menu button is pressed
    var onMoveBuildingPressed: (() -> Void)? // Called when move button is pressed
    var onDeleteBuildingPressed: (() -> Void)? // Called when delete button is pressed
    var onRotateBuildingPressed: (() -> Void)? // Called when rotate button is pressed (for belts)
    var onOpenMachinePressed: (() -> Void)? // Called when open button is pressed
    var onConfigureInserterPressed: (() -> Void)? // Called when configure button is pressed (for inserters)
    var onExitBuildModePressed: (() -> Void)? // Called when exit build mode button is pressed
    var onFluidDebugPressed: (() -> Void)? // Called when fluid debug button is pressed
    
    // Selected building
    var selectedEntity: Entity? {
        didSet {
            // Validate that the selected entity is still alive
            validateSelectedEntity()
            // Notify about selection change
            onSelectedEntityChanged?(selectedEntity)
        }
    }

    // Callback when selected entity changes
    var onSelectedEntityChanged: ((Entity?) -> Void)?

    /// Validates that the currently selected entity is still alive
    private func validateSelectedEntity() {
        if let entity = selectedEntity, let gameLoop = gameLoop {
            let isAlive = gameLoop.world.isAlive(entity)
            if !isAlive {
                selectedEntity = nil
            }
        }
    }
    
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
        
        // Get inventory button position (screen coordinates) - same as toolbar calculation
        let toolbarY = screenSize.y - bottomMargin - buttonSize / 2
        let inventoryButtonX = screenSize.x / 2 - (buttonSize * 2.5 + buttonSpacing * 2)
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

        // Play appropriate sound based on item type
        if itemId == "wood" {
            AudioManager.shared.playChopSound()
        } else {
            AudioManager.shared.playMiningSound()
        }
    }
    
    func getButtonName(at position: Vector2, screenSize: Vector2) -> String? {
        self.screenSize = screenSize

        // Calculate toolbar positions
        let toolbarY = screenSize.y - bottomMargin - buttonSize / 2
        // Center 5 buttons: inventory, crafting, build, research, buy
        var currentX = screenSize.x / 2 - (buttonSize * 2.5 + buttonSpacing * 2)

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
        currentX += buttonSize + buttonSpacing

        if checkButtonTap(at: position, buttonPos: Vector2(currentX, toolbarY)) {
            return "Buy"
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
        // Center 5 buttons: inventory, crafting, build, research, buy
        var currentX = screenSize.x / 2 - (buttonSize * 2.5 + buttonSpacing * 2)

        // Render inventory button
        // print("Rendering inventory button at Metal position (\(currentX), \(toolbarY))")
        renderButton(renderer: renderer, position: Vector2(currentX, toolbarY), textureId: "inventory", callback: onInventoryPressed)
        currentX += buttonSize + buttonSpacing

        // Render crafting button
        renderButton(renderer: renderer, position: Vector2(currentX, toolbarY), textureId: "gear", callback: onCraftingPressed)
        currentX += buttonSize + buttonSpacing

        // Render build button
        renderButton(renderer: renderer, position: Vector2(currentX, toolbarY), textureId: "assembler", callback: onBuildPressed)
        currentX += buttonSize + buttonSpacing

        // Render research button
        renderButton(renderer: renderer, position: Vector2(currentX, toolbarY), textureId: "research", callback: onResearchPressed)
        currentX += buttonSize + buttonSpacing

        // Render buy button
        renderButton(renderer: renderer, position: Vector2(currentX, toolbarY), textureId: "buy", callback: onBuyPressed)

        // Render virtual joystick
            joystick.updateScreenSize(screenSize)
            joystick.render(renderer: renderer)
        
        // Render health bar
        renderHealthBar(renderer: renderer)
        
        // Render menu button (top-right corner)
        renderMenuButton(renderer: renderer)

        // Render fluid debug button (top-left corner, only in debug builds)
        renderFluidDebugButton(renderer: renderer)

        // Render build mode exit button (only when in build mode)
        renderBuildModeExitButton(renderer: renderer)

        // Render selected building indicator (only when in build mode)
        renderSelectedBuildingIndicator(renderer: renderer)

        // Render mining animations
        renderMiningAnimations(renderer: renderer)

        // Render build preview if in build mode
        renderBuildPreview(renderer: renderer)
        
        // Render selection rectangle if active
        renderSelectionRectangle(renderer: renderer)
        
        // Render move and delete buttons if a building is selected
        renderBuildingActionButtons(renderer: renderer)
    }
    
    private func renderMenuButton(renderer: MetalRenderer) {
        // Menu button in top-right corner
        let buttonX = screenSize.x - bottomMargin - buttonSize / 2
        let buttonY = bottomMargin + buttonSize / 2

        renderButton(renderer: renderer, position: Vector2(buttonX, buttonY), textureId: "menu", callback: onMenuPressed)
    }

    private func renderFluidDebugButton(renderer: MetalRenderer) {
        // Debug button in top-left corner (small, for development)
        let debugButtonSize: Float = 30 * scale
        let buttonX = debugButtonSize / 2 + 5 * scale
        let buttonY = debugButtonSize / 2 + 5 * scale

        // Render a small colored square as debug button
        let solidRect = renderer.textureAtlas.getTextureRect(for: "pipe")
        renderer.queueSprite(SpriteInstance(
            position: Vector2(buttonX, buttonY),
            size: Vector2(debugButtonSize, debugButtonSize),
            textureRect: solidRect,
            color: Color(r: 0.9, g: 0.9, b: 0.2, a: 0.8), // Yellow debug button
            layer: .ui
        ))
    }

    private func renderBuildModeExitButton(renderer: MetalRenderer) {
        // Only show when in build mode
        guard let inputManager = inputManager, inputManager.buildMode != .none else { return }

        // Position it next to the menu button, to the left
        let buttonX = screenSize.x - bottomMargin - buttonSize / 2 - buttonSize - buttonSpacing
        let buttonY = bottomMargin + buttonSize / 2

        renderButton(renderer: renderer, position: Vector2(buttonX, buttonY), textureId: "build", callback: onExitBuildModePressed)
    }

    private func renderSelectedBuildingIndicator(renderer: MetalRenderer) {
        // Only show when in build mode
        guard let inputManager = inputManager,
              inputManager.buildMode == .placing,
              let selectedBuildingId = inputManager.selectedBuildingId,
              let gameLoop = gameLoop,
              let buildingDef = gameLoop.buildingRegistry.get(selectedBuildingId) else { return }

        // Position it next to the build mode exit button, to the left
        let buttonX = screenSize.x - bottomMargin - buttonSize / 2 - buttonSize - buttonSpacing - buttonSize - buttonSpacing
        let buttonY = bottomMargin + buttonSize / 2

        // Render the selected building's texture
        renderButton(renderer: renderer, position: Vector2(buttonX, buttonY), textureId: buildingDef.textureId, callback: nil)
    }
    
    private func hasMachineUI(for entity: Entity) -> Bool {
        guard let world = gameLoop?.world else { return false }
        // Check if entity has components that indicate it should have a machine UI
        // Inserters also show an Open button (to open inserter type dialog)
        // Pipes now also show an Open button (to open pipe connection UI)
        return world.has(InventoryComponent.self, for: entity) ||
               world.has(FurnaceComponent.self, for: entity) ||
               world.has(AssemblerComponent.self, for: entity) ||
               world.has(MinerComponent.self, for: entity) ||
               world.has(GeneratorComponent.self, for: entity) ||
               world.has(InserterComponent.self, for: entity) ||
               world.has(FluidProducerComponent.self, for: entity) ||
               world.has(PipeComponent.self, for: entity)
    }
    
    private func renderBuildingActionButtons(renderer: MetalRenderer) {
        // Validate selection before rendering
        validateSelectedEntity()

        // Only render if a building is selected
        guard let selectedEntity = selectedEntity else {
            return
        }
        
        // Check if selected entity is a belt, pipe, or inserter
        let isBelt = gameLoop?.world.has(BeltComponent.self, for: selectedEntity) ?? false
        let isPipe = gameLoop?.world.has(PipeComponent.self, for: selectedEntity) ?? false
        let isInserter = gameLoop?.world.has(InserterComponent.self, for: selectedEntity) ?? false
        let hasMachine = hasMachineUI(for: selectedEntity)

        // Position buttons on the right side for thumb accessibility
        // Place them vertically stacked, starting from about 1/3 down the screen
        let rightMargin: Float = bottomMargin + buttonSize / 2
        let startY: Float = screenSize.y * 0.4 // Start lower on screen for better accessibility
        let spacing: Float = buttonSize + buttonSpacing * 0.5  // Tighter spacing

        // Move button (top)
        let moveButtonY = startY
        let moveButtonX = screenSize.x - rightMargin
        renderButton(renderer: renderer, position: Vector2(moveButtonX, moveButtonY), textureId: "move", callback: onMoveBuildingPressed)

        // Delete button (below move button)
        let deleteButtonY = startY + spacing
        let deleteButtonX = screenSize.x - rightMargin
        // Use a red tint for delete button
        renderDeleteButton(renderer: renderer, position: Vector2(deleteButtonX, deleteButtonY))

        // Calculate next button Y position (below delete, or below rotate if it exists)
        var nextButtonY = startY + spacing * 2

        // Rotate button (below delete button, only for belts and pipes)
        if isBelt || isPipe {
            let rotateButtonY = nextButtonY
            let rotateButtonX = screenSize.x - rightMargin
            renderButton(renderer: renderer, position: Vector2(rotateButtonX, rotateButtonY), textureId: "rotate", callback: onRotateBuildingPressed)
            nextButtonY += spacing
        }
        
        // Configure button (for inserters, below delete/rotate)
        if isInserter {
            let configureButtonY = nextButtonY
            let configureButtonX = screenSize.x - rightMargin
            // print("HUD: Rendering configure button at (\(configureButtonX), \(configureButtonY)), screenSize: \(screenSize), rightMargin: \(rightMargin), callback: \(onConfigureInserterPressed != nil ? "set" : "nil")")
            renderButton(renderer: renderer, position: Vector2(configureButtonX, configureButtonY), textureId: "gear", callback: onConfigureInserterPressed)
            nextButtonY += spacing
        } else {
            // print("HUD: Not rendering configure button - isInserter is false")
        }
        
        // Open button (below delete/rotate/configure, only for entities with machine UI that aren't inserters)
        if hasMachine && !isInserter {
            let openButtonY = nextButtonY
            let openButtonX = screenSize.x - rightMargin
            renderButton(renderer: renderer, position: Vector2(openButtonX, openButtonY), textureId: "gear", callback: onOpenMachinePressed)
        }
    }
    
    private func renderDeleteButton(renderer: MetalRenderer, position: Vector2) {
        // Button background - use solid_white texture with red tinted color
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: position,
            size: Vector2(buttonSize, buttonSize),
            textureRect: solidRect,
            color: Color(r: 0.6, g: 0.2, b: 0.2, a: 0.9), // Red tint
            layer: .ui
        ))

        // Button icon - try to use a recycle icon, fallback to "gear" if not available
        let textureId = "recycle" // Try recycle icon first
        let textureRect = renderer.textureAtlas.getTextureRect(for: textureId)
        
        renderer.queueSprite(SpriteInstance(
            position: position,
            size: Vector2(buttonSize - 10, buttonSize - 10),
            textureRect: textureRect,
            layer: .ui
        ))
    }
    

    private func renderBuildPreview(renderer: MetalRenderer) {
        guard let inputManager = inputManager,
              let gameLoop = gameLoop else {
            return
        }
        
        // Handle move mode preview
        if inputManager.buildMode == .moving,
           let entityToMove = inputManager.entityToMove,
           let sprite = gameLoop.world.get(SpriteComponent.self, for: entityToMove),
           let previewPos = inputManager.buildPreviewPosition {
            let worldPos = Vector2(Float(previewPos.x) + 0.5, Float(previewPos.y) + 0.5)
            let textureRect = renderer.textureAtlas.getTextureRect(for: sprite.textureId)
            
            // Check if move is valid (use private canPlaceBuilding with BuildingDefinition)
            // We'll check if the position is valid by trying to get entity at that position
            let existingEntity = gameLoop.world.getEntityAt(position: previewPos)
            let isValidMove = existingEntity == nil || existingEntity == entityToMove
            
            // Choose color based on validity
            let previewColor = isValidMove ?
                Color(r: 0.2, g: 0.8, b: 0.2, a: 0.6) :  // Green for valid
                Color(r: 0.8, g: 0.2, b: 0.2, a: 0.6)    // Red for invalid
            
            // Render ghost preview
            renderer.queueSprite(SpriteInstance(
                position: worldPos,
                size: sprite.size,
                textureRect: textureRect,
                color: previewColor,
                layer: .entity
            ))
            return
        }
        
        // Handle build mode preview
        guard inputManager.buildMode == .placing,
              let buildingId = inputManager.selectedBuildingId,
              let buildingDef = gameLoop.buildingRegistry.get(buildingId) else {
            return
        }

        // Get building texture
        let textureRect = renderer.textureAtlas.getTextureRect(for: buildingDef.textureId)

        // For pipes, render the path preview with direction overlay
        if buildingId.contains("pipe") && !inputManager.dragPathPreviewWorld.isEmpty {
            for (index, worldPos) in inputManager.dragPathPreviewWorld.enumerated() {
                let tilePos = IntVector2(from: worldPos)

                // Check if placement is valid
                let tileCenter = tilePos.toVector2 + Vector2(0.5, 0.5)
                let placementOffset = worldPos - tileCenter
                let direction = pipePreviewDirection(for: index, path: inputManager.dragPathPreviewWorld, fallback: inputManager.buildDirection)
                let isValidPlacement = gameLoop.canPlaceBuilding(buildingId, at: tilePos, direction: direction) &&
                    gameLoop.canPlacePipe(at: tilePos, direction: direction, offset: placementOffset)

                // Choose color based on validity
                let previewColor = isValidPlacement ?
                    Color(r: 0.2, g: 0.8, b: 0.2, a: 0.6) :  // Green for valid
                    Color(r: 0.8, g: 0.2, b: 0.2, a: 0.6)    // Red for invalid

                // Render ghost preview for this tile
                renderer.queueSprite(SpriteInstance(
                    position: worldPos,
                    size: Vector2(1.0, 0.66), // Thin pipe preview
                    rotation: pipeRotation(for: direction),
                    textureRect: textureRect,
                    color: previewColor,
                    layer: .entity // Render above ground but below UI
                ))

                renderPipeDirectionOverlay(renderer: renderer, worldPos: worldPos, direction: direction)
            }
        } else if buildingId.contains("pipe") && !inputManager.dragPathPreview.isEmpty {
            for (index, tilePos) in inputManager.dragPathPreview.enumerated() {
                let worldPos = Vector2(Float(tilePos.x) + 0.5, Float(tilePos.y) + 0.5)

                // Check if placement is valid
                let isValidPlacement = gameLoop.canPlaceBuilding(buildingId, at: tilePos, direction: inputManager.buildDirection)

                // Choose color based on validity
                let previewColor = isValidPlacement ?
                    Color(r: 0.2, g: 0.8, b: 0.2, a: 0.6) :  // Green for valid
                    Color(r: 0.8, g: 0.2, b: 0.2, a: 0.6)    // Red for invalid

                let direction = pipePreviewDirection(for: index, path: inputManager.dragPathPreview, fallback: inputManager.buildDirection)

                // Render ghost preview for this tile
                renderer.queueSprite(SpriteInstance(
                    position: worldPos,
                    size: Vector2(1.0, 0.66), // Thin pipe preview
                    rotation: pipeRotation(for: direction),
                    textureRect: textureRect,
                    color: previewColor,
                    layer: .entity // Render above ground but below UI
                ))

                renderPipeDirectionOverlay(renderer: renderer, worldPos: worldPos, direction: direction)
            }
        } else if (buildingId.contains("belt") || buildingId.contains("pole")) && !inputManager.dragPathPreview.isEmpty {
            for tilePos in inputManager.dragPathPreview {
                let worldPos = Vector2(Float(tilePos.x) + 0.5, Float(tilePos.y) + 0.5)
                
                // Check if placement is valid
                let isValidPlacement = gameLoop.canPlaceBuilding(buildingId, at: tilePos, direction: inputManager.buildDirection)
                
                // Choose color based on validity
                let previewColor = isValidPlacement ?
                    Color(r: 0.2, g: 0.8, b: 0.2, a: 0.6) :  // Green for valid
                    Color(r: 0.8, g: 0.2, b: 0.2, a: 0.6)    // Red for invalid
                
                // Render ghost preview for this tile
                renderer.queueSprite(SpriteInstance(
                    position: worldPos,
                    size: Vector2(1.0, 1.0), // Standard tile size
                    textureRect: textureRect,
                    color: previewColor,
                    layer: .entity // Render above ground but below UI
                ))
            }
        } else if let previewPos = inputManager.buildPreviewPosition {
            // For non-belt buildings, render single preview
            let worldPos = Vector2(Float(previewPos.x) + 0.5, Float(previewPos.y) + 0.5)

            // Check if placement is valid
            let isValidPlacement = gameLoop.canPlaceBuilding(buildingId, at: previewPos, direction: inputManager.buildDirection)

            // Choose color based on validity
            let previewColor = isValidPlacement ?
                Color(r: 0.2, g: 0.8, b: 0.2, a: 0.6) :  // Green for valid
                Color(r: 0.8, g: 0.2, b: 0.2, a: 0.6)    // Red for invalid

            // Render ghost preview
            let previewRotation = buildingId.contains("pipe") ? pipeRotation(for: inputManager.buildDirection) : 0
            renderer.queueSprite(SpriteInstance(
                position: worldPos,
                size: buildingId.contains("pipe") ? Vector2(1.0, 0.66) : Vector2(1.0, 1.0),
                rotation: previewRotation,
                textureRect: textureRect,
                color: previewColor,
                layer: .entity // Render above ground but below UI
            ))

            if buildingId.contains("pipe") {
                renderPipeDirectionOverlay(renderer: renderer, worldPos: worldPos, direction: inputManager.buildDirection)
            }
        }
    }

    private func renderPipeDirectionOverlay(renderer: MetalRenderer, worldPos: Vector2, direction: Direction) {
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        let overlaySize: Vector2
        if direction == .north || direction == .south {
            overlaySize = Vector2(0.12, 0.7)
        } else {
            overlaySize = Vector2(0.7, 0.12)
        }

        renderer.queueSprite(SpriteInstance(
            position: worldPos,
            size: overlaySize,
            textureRect: solidRect,
            color: Color(r: 0.9, g: 0.9, b: 0.9, a: 0.75),
            layer: .entity
        ))
    }

    private func pipePreviewDirection(for index: Int, path: [Vector2], fallback: Direction) -> Direction {
        guard !path.isEmpty else { return fallback }
        if index < path.count - 1 {
            let delta = path[index + 1] - path[index]
            return dominantDirection(from: delta, fallback: fallback)
        }
        if index > 0 {
            let delta = path[index] - path[index - 1]
            return dominantDirection(from: delta, fallback: fallback)
        }
        return fallback
    }

    private func dominantDirection(from delta: Vector2, fallback: Direction) -> Direction {
        if abs(delta.x) >= abs(delta.y) {
            return delta.x >= 0 ? .east : .west
        }
        if abs(delta.y) > 0 {
            return delta.y >= 0 ? .north : .south
        }
        return fallback
    }

    private func pipePreviewDirection(for index: Int, path: [IntVector2], fallback: Direction) -> Direction {
        if path.count <= 1 {
            return fallback
        }

        let current = path[index]
        let hasPrev = index > 0
        let hasNext = index + 1 < path.count
        let dirToPrev = hasPrev ? direction(from: current, to: path[index - 1]) : nil
        let dirToNext = hasNext ? direction(from: current, to: path[index + 1]) : nil

        if let dirToPrev = dirToPrev, let dirToNext = dirToNext {
            if dirToPrev == dirToNext.opposite {
                return dirToNext
            }
            if dirToNext == dirToPrev.clockwise {
                return dirToPrev
            }
            if dirToPrev == dirToNext.clockwise {
                return dirToNext
            }
            return dirToNext
        }

        return dirToNext ?? dirToPrev ?? fallback
    }

    private func direction(from start: IntVector2, to end: IntVector2) -> Direction {
        let offset = end - start
        if offset.x == 0 && offset.y == 1 { return .north }
        if offset.x == 1 && offset.y == 0 { return .east }
        if offset.x == 0 && offset.y == -1 { return .south }
        if offset.x == -1 && offset.y == 0 { return .west }
        return .north
    }

    private func pipeRotation(for direction: Direction) -> Float {
        return (.pi / 2) - direction.angle
    }
    
    private func renderSelectionRectangle(renderer: MetalRenderer) {
        guard let inputManager = inputManager,
              (inputManager.buildMode == .none || inputManager.buildMode == .connectingInserter),  // Render selection rectangle in normal and inserter connection modes
              let selectionRect = inputManager.selectionRect else {
            return
        }
        
        // Ensure rectangle has valid size
        guard selectionRect.width > 0 && selectionRect.height > 0 else {
            return
        }
        
        // Get texture rect for solid_white (returns a default rect if not found)
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        
        let borderColor = Color(r: 0.2, g: 0.6, b: 1.0, a: 0.8)  // Blue selection color
        let fillColor = Color(r: 0.2, g: 0.6, b: 1.0, a: 0.2)  // Semi-transparent fill
        let borderThickness: Float = 0.15  // Border thickness in world units (thicker for visibility)
        
        // Render semi-transparent fill (use .particle layer for world-space rendering on top of entities)
        renderer.queueSprite(SpriteInstance(
            position: selectionRect.center,
            size: selectionRect.size,
            textureRect: solidRect,
            color: fillColor,
            layer: .particle  // Use .particle layer (8) to render after entities but in world-space
        ))
        
        // Render border (four edges) - use .particle layer for world-space rendering on top
        // Top edge
        renderer.queueSprite(SpriteInstance(
            position: Vector2(selectionRect.center.x, selectionRect.maxY - borderThickness / 2),
            size: Vector2(selectionRect.width, borderThickness),
            textureRect: solidRect,
            color: borderColor,
            layer: .particle  // Use .particle layer (8) to render after entities but in world-space
        ))
        // Bottom edge
        renderer.queueSprite(SpriteInstance(
            position: Vector2(selectionRect.center.x, selectionRect.minY + borderThickness / 2),
            size: Vector2(selectionRect.width, borderThickness),
            textureRect: solidRect,
            color: borderColor,
            layer: .particle  // Use .particle layer (8) to render after entities but in world-space
        ))
        // Left edge
        renderer.queueSprite(SpriteInstance(
            position: Vector2(selectionRect.minX + borderThickness / 2, selectionRect.center.y),
            size: Vector2(borderThickness, selectionRect.height),
            textureRect: solidRect,
            color: borderColor,
            layer: .particle  // Use .particle layer (8) to render after entities but in world-space
        ))
        // Right edge
        renderer.queueSprite(SpriteInstance(
            position: Vector2(selectionRect.maxX - borderThickness / 2, selectionRect.center.y),
            size: Vector2(borderThickness, selectionRect.height),
            textureRect: solidRect,
            color: borderColor,
            layer: .particle  // Use .particle layer (8) to render after entities but in world-space
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
        // Center 5 buttons: inventory, crafting, build, research, buy
        var currentX = screenSize.x / 2 - (buttonSize * 2.5 + buttonSpacing * 2)

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
        currentX += buttonSize + buttonSpacing

        // Check buy button
        if checkButtonTap(at: position, buttonPos: Vector2(currentX, toolbarY)) {
            onBuyPressed?()
            return true
        }
        
        // Check menu button (top-right corner)
        let menuButtonX = screenSize.x - bottomMargin - buttonSize / 2
        let buttonY = bottomMargin + buttonSize / 2
        if checkButtonTap(at: position, buttonPos: Vector2(menuButtonX, buttonY)) {
            onMenuPressed?()
            return true
        }

        // Check fluid debug button (top-left corner)
        let debugButtonSize: Float = 30 * scale
        let debugButtonX = debugButtonSize / 2 + 5 * scale
        let debugButtonY = debugButtonSize / 2 + 5 * scale
        if checkButtonTap(at: position, buttonPos: Vector2(debugButtonX, debugButtonY)) {
            onFluidDebugPressed?()
            return true
        }

        // Check build mode exit button (only when in build mode)
        if let inputManager = inputManager, inputManager.buildMode != .none {
            let exitButtonX = screenSize.x - bottomMargin - buttonSize / 2 - buttonSize - buttonSpacing
            if checkButtonTap(at: position, buttonPos: Vector2(exitButtonX, buttonY)) {
                onExitBuildModePressed?()
                return true
            }
        }
        
        // Check move and delete buttons if a building is selected
        if selectedEntity != nil {
            let rightMargin: Float = bottomMargin + buttonSize / 2
            let startY: Float = screenSize.y * 0.4  // Match rendering position
            let spacing: Float = buttonSize + buttonSpacing * 0.5  // Match rendering spacing

            // Move button
            let moveButtonX = screenSize.x - rightMargin
            let moveButtonY = startY
            if checkButtonTap(at: position, buttonPos: Vector2(moveButtonX, moveButtonY)) {
                onMoveBuildingPressed?()
                return true
            }

            // Delete button
            let deleteButtonX = screenSize.x - rightMargin
            let deleteButtonY = startY + spacing
            if checkButtonTap(at: position, buttonPos: Vector2(deleteButtonX, deleteButtonY)) {
                onDeleteBuildingPressed?()
                return true
            }

            // Rotate button (only for belts and pipes)
            var nextButtonY = startY + spacing * 2
            if let selectedEntity = selectedEntity,
               (gameLoop?.world.has(BeltComponent.self, for: selectedEntity) ?? false) ||
               (gameLoop?.world.has(PipeComponent.self, for: selectedEntity) ?? false) {
                let rotateButtonX = screenSize.x - rightMargin
                let rotateButtonY = nextButtonY
                if checkButtonTap(at: position, buttonPos: Vector2(rotateButtonX, rotateButtonY)) {
                    onRotateBuildingPressed?()
                    return true
                }
                nextButtonY += spacing
            }

            // Configure button (only for inserters)
            if let selectedEntity = selectedEntity,
               gameLoop?.world.has(InserterComponent.self, for: selectedEntity) ?? false {
                let configureButtonX = screenSize.x - rightMargin
                let configureButtonY = nextButtonY
                if checkButtonTap(at: position, buttonPos: Vector2(configureButtonX, configureButtonY)) {
                    onConfigureInserterPressed?()
                    return true
                }
                nextButtonY += spacing
            }

            // Open button (only for entities with machine UI that aren't inserters)
            if let selectedEntity = selectedEntity,
               hasMachineUI(for: selectedEntity) && !(gameLoop?.world.has(InserterComponent.self, for: selectedEntity) ?? false) {
                let openButtonX = screenSize.x - rightMargin
                let openButtonY = nextButtonY
                if checkButtonTap(at: position, buttonPos: Vector2(openButtonX, openButtonY)) {
                    onOpenMachinePressed?()
                    return true
                }
            }
        }

        return false
    }


    private func checkButtonTap(at position: Vector2, buttonPos: Vector2) -> Bool {
        // Use a slightly larger tap target than the visual button for better usability
        let tapSize = buttonSize * 1.1  // 10% larger tap target (reduced from 20%)
        let frame = Rect(center: buttonPos, size: Vector2(tapSize, tapSize))
        let contains = frame.contains(position)
        return contains
    }
}
