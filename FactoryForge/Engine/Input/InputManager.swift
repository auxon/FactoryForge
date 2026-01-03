import UIKit

/// Manages all touch input for the game
final class InputManager: NSObject {
    private weak var view: UIView?
    private weak var gameLoop: GameLoop?
    private weak var renderer: MetalRenderer?
    
    // Gesture recognizers
    private var tapRecognizer: UITapGestureRecognizer!
    private var panRecognizer: UIPanGestureRecognizer!
    private var pinchRecognizer: UIPinchGestureRecognizer!
    private var longPressRecognizer: UILongPressGestureRecognizer!
    private var rotationRecognizer: UIRotationGestureRecognizer!
    
    // Input state
    private(set) var currentTouchPosition: Vector2 = .zero
    private(set) var isDragging = false
    private(set) var isPinching = false
    private var isUIDragging = false
    private var dragStartPosition: Vector2 = .zero
    
    // Joystick touch tracking
    private var joystickTouchId: Int? = nil
    private var isJoystickActive: Bool = false
    
    // Camera control
    private var panStartPosition: Vector2 = .zero
    private var cameraStartPosition: Vector2 = .zero
    private var startZoom: Float = 1.0
    
    // Building placement
    var buildMode: BuildMode = .none
    var selectedBuildingId: String?
    var buildDirection: Direction = .north
    var buildPreviewPosition: IntVector2?
    
    // Building movement
    var entityToMove: Entity?  // Entity being moved (accessible for preview rendering)
    
    // Inserter connection mode
    var inserterToConfigure: Entity?  // Inserter being configured
    var isConnectingInput: Bool = false  // True if setting input, false if setting output
    
    // Belt and pole placement (drag-based)
    private var dragPlacementStartTile: IntVector2?  // Starting tile for drag placement
    private var dragPlacedTiles: Set<IntVector2> = []  // Tiles where items have been placed in current drag
    var dragPathPreview: [IntVector2] = []  // Preview path for rendering
    
    // Selection rectangle
    var selectionRect: Rect?  // Selection rectangle in world coordinates (for rendering)
    private var selectionStartScreenPos: Vector2?  // Start position of selection rectangle in screen coordinates
    private var isSelecting = false  // Whether we're currently selecting with rectangle
    
    // Selection
    var selectedEntity: Entity? {
        didSet {
            // Validate that the selected entity is still alive
            validateSelectedEntity()
        }
    }

    /// Validates that the currently selected entity is still alive
    private func validateSelectedEntity() {
        if let entity = selectedEntity, let gameLoop = gameLoop {
            if !gameLoop.world.isAlive(entity) {
                print("InputManager: Selected entity \(entity) is no longer alive, clearing selection")
                selectedEntity = nil
            }
        }
    }
    
    // Callbacks
    var onTap: ((Vector2) -> Void)?
    var onLongPress: ((Vector2) -> Void)?
    var onBuildingPlaced: ((String, IntVector2, Direction) -> Void)?
    var onEntitySelected: ((Entity?) -> Void)?
    var onTooltip: ((String) -> Void)? // Called when something is tapped to show tooltip
    var onTooltipWithEntity: ((String, Entity?) -> Void)? // Called when something is tapped to show tooltip with entity icon
    init(view: UIView, gameLoop: GameLoop?, renderer: MetalRenderer? = nil) {
        self.view = view
        self.gameLoop = gameLoop
        self.renderer = renderer
        
        super.init()
        
        setupGestureRecognizers()
    }
    
    func setGameLoop(_ gameLoop: GameLoop?) {
        self.gameLoop = gameLoop
    }
    
    private func setupGestureRecognizers() {
        guard let view = view else { return }

        // Ensure view can receive touches
        view.isUserInteractionEnabled = true
        view.isMultipleTouchEnabled = true
        
        // Double tap recognizer (must be added first)
        let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.delegate = self
        view.addGestureRecognizer(doubleTapRecognizer)

        // Single tap recognizer (requires double tap to fail)
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapRecognizer.numberOfTapsRequired = 1
        tapRecognizer.require(toFail: doubleTapRecognizer)  // Wait for double tap to fail
        tapRecognizer.delegate = self
        view.addGestureRecognizer(tapRecognizer)

        // Prevent single tap from firing when double tap is detected
        tapRecognizer.require(toFail: doubleTapRecognizer)
        
        // Pan recognizer for camera movement
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panRecognizer.minimumNumberOfTouches = 1
        panRecognizer.maximumNumberOfTouches = 1
        panRecognizer.delegate = self
        panRecognizer.delaysTouchesBegan = false
        panRecognizer.delaysTouchesEnded = false
        view.addGestureRecognizer(panRecognizer)
        
        // Pinch recognizer for zoom
        pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchRecognizer.delegate = self
        view.addGestureRecognizer(pinchRecognizer)
        
        // Long press recognizer removed - using tap for tooltips
        
        // Rotation recognizer for building rotation
        rotationRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        rotationRecognizer.delegate = self
        view.addGestureRecognizer(rotationRecognizer)
        
        // Allow tap to work immediately without waiting for long press to fail
        // (Long press will cancel if finger moves or lifts before the duration)
    }
    
    // MARK: - Gesture Handlers
    
    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }

        print("InputManager: DOUBLE TAP GESTURE DETECTED")
        let screenPos = screenPosition(from: recognizer)
        print("InputManager: Double tap screen position: \(screenPos)")

        // Check for UI tooltips first (before UI system consumes the tap)
        let uiSystem = gameLoop?.uiSystem ?? renderer?.uiSystem
        if let uiSystem = uiSystem {
            if let tooltip = uiSystem.getTooltip(at: screenPos) {
                // Show tooltip for UI element
                onTooltip?(tooltip)
            }

            // Check if a UI panel is open that should consume the tap
            // If entitySelection dialog is open, let it handle double taps specially
            if uiSystem.isPanelOpen(.entitySelection) {
                print("InputManager: Double tap - entitySelection dialog is open, checking if dialog handles it")
                // Check if the dialog handles the double tap (e.g., on a button)
                if uiSystem.handleDoubleTap(at: screenPos) {
                    print("InputManager: Double tap handled by entitySelection dialog")
                    return
                }
                // If tap wasn't on a button, don't process game world interaction
                print("InputManager: Double tap not on dialog button, skipping game world interaction")
                return
            }
            
            // For HUD buttons and other UI, double taps should work the same as single taps
            // Check if UI system handles the tap (e.g., HUD buttons)
            if uiSystem.handleTap(at: screenPos) {
                print("InputManager: Double tap handled by UI system (HUD or panel)")
                return
            }
        }

        // If no game loop exists, we're done (loading menu should have handled it)
        guard let gameLoop = gameLoop else {
            print("InputManager: Double tap - no game loop available")
            return
        }

        // Check for entities/resources BEFORE UI system check, so tooltips always work
        let worldPos = gameLoop.renderer?.screenToWorld(screenPos) ?? renderer?.screenToWorld(screenPos) ?? .zero
        let tilePos = IntVector2(from: worldPos)
        print("InputManager: Double tap - world position: \(worldPos), tile position: (\(tilePos.x), \(tilePos.y))")

        // Update build preview position for tap placement
        if buildMode == .placing {
            buildPreviewPosition = tilePos
        }

        // Show tooltips for entities only when not in build mode (to allow building placement)
        // Note: For double taps, we show tooltips but don't return early - we still want combat to work
        if buildMode == .none {
            let nearbyEntities = gameLoop.world.getEntitiesNear(position: worldPos, radius: 1.5)
            var closestEntity: Entity?
            var closestDistance = Float.greatestFiniteMagnitude

            for entity in nearbyEntities {
                if let pos = gameLoop.world.get(PositionComponent.self, for: entity) {
                    let distance = pos.worldPosition.distance(to: worldPos)
                    if distance < closestDistance {
                        closestDistance = distance
                        closestEntity = entity
                    }
                }
            }

            if let entity = closestEntity {
                // Show tooltip for the closest entity, but continue to combat code below
                if let tooltipText = getEntityTooltipText(entity: entity, gameLoop: gameLoop) {
                    onTooltip?(tooltipText)
                    // Don't return - continue to process combat even if we show a tooltip
                }
            }
        }

        // Check for resource at the exact tile (only when not in build mode)
        if buildMode == .none {
            if let resource = gameLoop.chunkManager.getResource(at: tilePos), !resource.isEmpty {
                // Show tooltip for resource
                onTooltip?(resource.type.displayName)
            }
        }

        // UI didn't handle it, process game tap
        currentTouchPosition = worldPos

        switch buildMode {
        case .none:
            // Check if player is attacking an enemy (prioritize combat)
            // Use a larger radius for double taps to make it easier to hit enemies
            let nearbyEnemies = gameLoop.world.getEntitiesNear(position: worldPos, radius: 5.0)
            print("InputManager: Double tap - found \(nearbyEnemies.count) entities near position \(worldPos)")
            var attacked = false

            for enemy in nearbyEnemies {
                if gameLoop.world.has(EnemyComponent.self, for: enemy) {
                    print("InputManager: Double tapping on enemy \(enemy)")
                    // Try to attack the enemy directly
                    if gameLoop.player.attackEnemy(enemy: enemy) {
                        attacked = true
                        print("InputManager: Player double attack initiated successfully")
                        break
                    } else {
                        print("InputManager: Player double attack failed")
                    }
                } else {
                    print("InputManager: Entity \(enemy) is not an enemy")
                }
            }

            if !attacked {
                print("InputManager: Double tap - no enemy attacked, found \(nearbyEnemies.count) nearby entities")
            }

            if attacked {
                // Attack was successful, don't process further
                return
            } else {
                // No enemy attacked, handle building/machine interaction
                handleNonCombatDoubleTap(at: screenPos, worldPos: worldPos, tilePos: tilePos, gameLoop: gameLoop)
            }

        case .placing:
            // Place the building (use same logic as single-tap for consistency)
            if let buildingId = selectedBuildingId {
                guard let buildingDef = gameLoop.buildingRegistry.get(buildingId) else {
                    onTooltip?("Unknown building type")
                    return
                }

                // Check inventory first
                if !gameLoop.player.inventory.has(items: buildingDef.cost) {
                    // Show missing items
                    let missingItems = buildingDef.cost.filter { !gameLoop.player.inventory.has(items: [$0]) }
                    if let firstMissing = missingItems.first {
                        let itemName = gameLoop.itemRegistry.get(firstMissing.itemId)?.name ?? firstMissing.itemId
                        onTooltip?("Need \(firstMissing.count) \(itemName)")
                    } else {
                        onTooltip?("Missing required items")
                    }
                    return
                }
                
                // Calculate offset to center the building at the tap location
                let spriteSize = Vector2(Float(buildingDef.width), Float(buildingDef.height))
                let tileCenter = tilePos.toVector2 + Vector2(0.5, 0.5)
                let tapOffset = worldPos - tileCenter - spriteSize / 2

                // Check placement validity
                if !gameLoop.canPlaceBuilding(buildingId, at: tilePos, direction: buildDirection) {
                    onTooltip?("Cannot place building here")
                    return
                }

                // Try to place with offset to center at tap location
                if gameLoop.placeBuilding(buildingId, at: tilePos, direction: buildDirection, offset: tapOffset) {
                    onBuildingPlaced?(buildingId, tilePos, buildDirection)
                    // Exit build mode after placing (except for belts which allow drag placement)
                    if !buildingId.contains("belt") {
                        exitBuildMode()
                    }
                } else {
                    onTooltip?("Failed to place building")
                }
            }

        case .selecting:
            // Select entity at position (not implemented yet)
            onEntitySelected?(nil)

        case .removing:
            // Remove building at position (not implemented yet)
            break
            
        case .moving:
            // Move building to new position (same logic as single tap)
            let tilePos = IntVector2(from: worldPos)
            if let entity = entityToMove {
                if gameLoop.moveBuilding(entity: entity, to: tilePos) {
                    onTooltip?("Building moved")
                    exitBuildMode()
                    // Clear selection
                    selectedEntity = nil
                    onEntitySelected?(nil)
                } else {
                    onTooltip?("Cannot move building here")
                }
            }
            
        case .connectingInserter:
            // Handle inserter connection selection
            let tilePos = IntVector2(from: worldPos)
            handleInserterConnectionSelection(at: tilePos, gameLoop: gameLoop)
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }

        print("InputManager: TAP GESTURE DETECTED")
        let screenPos = screenPosition(from: recognizer)
        print("InputManager: Screen position: \(screenPos)")

        // Check for UI tooltips first (before UI system consumes the tap)
        let uiSystem = gameLoop?.uiSystem ?? renderer?.uiSystem
        print("InputManager: UI system available: \(uiSystem != nil)")
        if let uiSystem = uiSystem {
            if let tooltip = uiSystem.getTooltip(at: screenPos) {
                // Show tooltip for UI element
                print("InputManager: Showing tooltip: \(tooltip)")
                onTooltip?(tooltip)
            }

            // Then check UI system for actual functionality
            let uiHandled = uiSystem.handleTap(at: screenPos)
            print("InputManager: UI system handled tap: \(uiHandled)")
            if uiHandled == true {
                print("InputManager: Tap consumed by UI system")
                return
            }
            
            // Connection selection is now handled in buildMode == .connectingInserter
        }

        // If no game loop exists, we're done (loading menu should have handled it)
        guard let gameLoop = gameLoop else {
            print("InputManager: No game loop available")
            return
        }

        // Validate current selection before processing
        validateSelectedEntity()

        // Check for entities/resources BEFORE UI system check, so tooltips always work
        let worldPos = gameLoop.renderer?.screenToWorld(screenPos) ?? renderer?.screenToWorld(screenPos) ?? .zero
        let tilePos = IntVector2(from: worldPos)
        print("InputManager: World position: \(worldPos), tile position: (\(tilePos.x), \(tilePos.y))")

        // Update build preview position for tap placement
        if buildMode == .placing {
            buildPreviewPosition = tilePos
        }

        // Show tooltips for entities only when not in build mode (to allow building placement)
        if buildMode == .none {
            let nearbyEntities = gameLoop.world.getEntitiesNear(position: worldPos, radius: 1.5)
            var closestEntity: Entity?
            var closestDistance = Float.greatestFiniteMagnitude

            for entity in nearbyEntities {
                if let pos = gameLoop.world.get(PositionComponent.self, for: entity) {
                    let distance = pos.worldPosition.distance(to: worldPos)
                    if distance < closestDistance {
                        closestDistance = distance
                        closestEntity = entity
                    }
                }
            }

            if let entity = closestEntity {
                // Show tooltip for the closest entity
                if let tooltipText = getEntityTooltipText(entity: entity, gameLoop: gameLoop) {
                    onTooltipWithEntity?(tooltipText, entity)
                    // Continue to entity selection - don't return early
                }
            }
        }

        // Check for resource at the exact tile (only when not in build mode)
        if buildMode == .none {
            if let resource = gameLoop.chunkManager.getResource(at: tilePos), !resource.isEmpty {
                // Show tooltip for resource
                onTooltip?(resource.type.displayName)
            }
        }

        // UI didn't handle it, process game tap
        currentTouchPosition = worldPos
        
        switch buildMode {
        case .none:
            // Check if player is attacking an enemy (prioritize combat)
            let nearbyEnemies = gameLoop.world.getEntitiesNear(position: worldPos, radius: 5.0)
            print("InputManager: Found \(nearbyEnemies.count) entities near tap position")
            var attacked = false

            for enemy in nearbyEnemies {
                if gameLoop.world.has(EnemyComponent.self, for: enemy) {
                    print("InputManager: Tapping on enemy \(enemy)")
                    // Try to attack the enemy directly by its entity ID instead of position
                    // This avoids precision issues with position conversion
                    if gameLoop.player.attackEnemy(enemy: enemy) {
                        attacked = true
                        print("InputManager: Player attack on enemy \(enemy) initiated successfully")
                        break
                    } else {
                        print("InputManager: Player attack on enemy \(enemy) failed")
                    }
                } else {
                    print("InputManager: Entity \(enemy) is not an enemy")
                }
            }

            if !attacked {
                print("InputManager: No enemy attacked, processing other tap logic")
            }
            
            if !attacked {
                // Try to select an entity at this position using the same logic as double tap
                handleEntitySelection(at: screenPos, worldPos: worldPos, tilePos: tilePos, gameLoop: gameLoop)
            }
            
        case .placing:
            let tilePos = IntVector2(from: worldPos)
            
            // Handle belt/pole placement (tap to set start tile, then drag)
            if let buildingId = selectedBuildingId, buildingId.contains("belt") || buildingId.contains("pole") {
                // Just set the start tile, items will be placed during drag
                dragPlacementStartTile = tilePos
                dragPlacedTiles = []
                dragPathPreview = [tilePos]
                return
            }
            
            // For non-belt buildings, check if we're tapping on an existing entity
            if let entity = gameLoop.world.getEntityAt(position: tilePos) {
                // Entity was tapped - select it and exit build mode
                selectedEntity = entity
                onEntitySelected?(entity)
                exitBuildMode()
                return
            }
            
            // Place building (non-belt)
            if let buildingId = selectedBuildingId {
                // Check if we can place the building and why it might fail
                guard let buildingDef = gameLoop.buildingRegistry.get(buildingId) else {
                    // Invalid building - this shouldn't happen in normal gameplay
                    onTooltip?("Unknown building type")
                    return
                }

                // Check inventory first
                if !gameLoop.player.inventory.has(items: buildingDef.cost) {
                    // Show missing items
                    let missingItems = buildingDef.cost.filter { !gameLoop.player.inventory.has(items: [$0]) }
                    if let firstMissing = missingItems.first {
                        let itemName = gameLoop.itemRegistry.get(firstMissing.itemId)?.name ?? firstMissing.itemId
                        onTooltip?("Need \(firstMissing.count) \(itemName)")
                    } else {
                        onTooltip?("Missing required items")
                    }
                    return
                }
                
                // Calculate offset to center the building at the tap location
                // Account for sprite rendering offset: buildings are offset by half their size
                let spriteSize = Vector2(Float(buildingDef.width), Float(buildingDef.height))
                let tileCenter = tilePos.toVector2 + Vector2(0.5, 0.5)
                let tapOffset = worldPos - tileCenter - spriteSize / 2

                // Check placement validity
                if !gameLoop.canPlaceBuilding(buildingId, at: tilePos, direction: buildDirection) {
                    onTooltip?("Cannot place building here")
                    return
                }

                // Try to place with offset to center at tap location
                if gameLoop.placeBuilding(buildingId, at: tilePos, direction: buildDirection, offset: tapOffset) {
                    onBuildingPlaced?(buildingId, tilePos, buildDirection)
                    // Exit build mode after placing (except for belts which allow drag placement)
                    if !buildingId.contains("belt") {
                        exitBuildMode()
                    }
                    // Play placement sound/feedback
                } else {
                    onTooltip?("Failed to place building")
                }
            }
            
        case .removing:
            // Remove building
            let tilePos = IntVector2(from: worldPos)
            _ = gameLoop.removeBuilding(at: tilePos)
            // Stay in remove mode for continuous removal

        case .selecting:
            // Select entity at exact tile position only
            let tilePos = IntVector2(from: worldPos)
            var selected: Entity?
            
            if let entityAtTile = gameLoop.world.getEntityAt(position: tilePos) {
                // Check if this entity is interactable
                if gameLoop.world.has(FurnaceComponent.self, for: entityAtTile) ||
                   gameLoop.world.has(AssemblerComponent.self, for: entityAtTile) ||
                   gameLoop.world.has(MinerComponent.self, for: entityAtTile) ||
                   gameLoop.world.has(ChestComponent.self, for: entityAtTile) ||
                   gameLoop.world.has(LabComponent.self, for: entityAtTile) {
                    selected = entityAtTile
                }
            }

            onEntitySelected?(selected)
            
        case .moving:
            // Move building to new position
            let tilePos = IntVector2(from: worldPos)
            if let entity = entityToMove {
                if gameLoop.moveBuilding(entity: entity, to: tilePos) {
                    onTooltip?("Building moved")
                    exitBuildMode()
                    // Clear selection
                    selectedEntity = nil
                    onEntitySelected?(nil)
                } else {
                    onTooltip?("Cannot move building here")
                }
            }
            
        case .connectingInserter:
            // Handle inserter connection selection
            let tilePos = IntVector2(from: worldPos)
            handleInserterConnectionSelection(at: tilePos, gameLoop: gameLoop)
        }
        
        onTap?(worldPos)
    }
    
    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let gameLoop = gameLoop, let renderer = gameLoop.renderer ?? self.renderer else { return }
        
        let screenPos = screenPosition(from: recognizer)
        let worldPos = renderer.screenToWorld(screenPos)
        currentTouchPosition = worldPos

        // Get joystick from HUD
        let joystick = gameLoop.uiSystem?.hud.joystick

        switch recognizer.state {
        case .began:
            dragStartPosition = screenPos

            // Check if touch started in UI area FIRST (for drag gestures)
            // Store the start position for drag gestures
            isUIDragging = false

            // Check if touch started within an open UI panel FIRST
            if let uiSystem = gameLoop.uiSystem {
                // Check if any panel is open that should consume drags
                if uiSystem.isAnyPanelOpen {
                    // Check if the drag starts within a panel that handles drags
                    // Try to handle drag immediately if it starts in a UI element
                    // This prevents game world interactions when dragging within UI panels
                    if uiSystem.handleDrag(from: screenPos, to: screenPos) {
                        isUIDragging = true
                        // Don't return here - let the gesture continue so .changed and .ended events fire
                        // But isUIDragging flag will prevent game world interactions in .changed state
                    }
                }
            }

            // Check if touch started in joystick area FIRST
            if let joystick = joystick {
                let activationRadius = joystick.baseRadius * 1.5
                let distance = (screenPos - joystick.baseCenter).length

                if distance <= activationRadius {
                    // This is a joystick touch - handle it and prevent camera pan
                    if joystick.handleTouchBegan(at: screenPos, touchId: 0) {
                        isJoystickActive = true
                        return  // Prevent camera pan, but gesture continues for .changed/.ended
                    }
                }
            }

            
            // Not a joystick touch, start selection rectangle (instead of camera pan)
            if buildMode == .none {
                isSelecting = true
                selectionStartScreenPos = screenPos
                selectionRect = nil
            } else {
            isDragging = true
            panStartPosition = screenPos
            cameraStartPosition = renderer.camera.position
            }
            
            if buildMode == .placing || buildMode == .moving {
                // Update build preview position
                buildPreviewPosition = IntVector2(from: worldPos)
                
                // For belt/pole placement, set start tile if not already set
                if buildMode == .placing, let buildingId = selectedBuildingId, buildingId.contains("belt") || buildingId.contains("pole") {
                    if dragPlacementStartTile == nil {
                        dragPlacementStartTile = IntVector2(from: worldPos)
                        dragPlacedTiles = []
                        dragPathPreview = [dragPlacementStartTile!]
                    }
                }
            }
            
        case .changed:
            // Check if a UI panel is open - if so, don't process game world interactions
            if let uiSystem = gameLoop.uiSystem, uiSystem.isAnyPanelOpen {
                // Check for UI drag gesture
                if !isUIDragging && !isJoystickActive {
                    let dragDistance = (screenPos - dragStartPosition).length
                    if dragDistance > 10 { // Minimum drag distance to start UI drag
                        // Try to start UI drag
                        isUIDragging = uiSystem.handleDrag(from: dragStartPosition, to: screenPos)
                    } else {
                        // Even if drag distance is small, check if we're within a UI panel
                        // This prevents game world interactions when a panel is open
                        if uiSystem.handleDrag(from: dragStartPosition, to: screenPos) {
                            isUIDragging = true
                        }
                    }
                }

                // If UI drag is active or panel is open, consume the gesture
                if isUIDragging {
                    if let uiSystem = gameLoop.uiSystem {
                        _ = uiSystem.handleDrag(from: dragStartPosition, to: screenPos)
                    }
                    return
                }
                // Even if not dragging, if a panel is open, don't process game world pan interactions
                return
            }

            // Check for UI drag gesture (only if no panel is open)
            if !isUIDragging && !isJoystickActive {
                let dragDistance = (screenPos - dragStartPosition).length
                if dragDistance > 10 { // Minimum drag distance to start UI drag
                    // Try to start UI drag
                    if let uiSystem = gameLoop.uiSystem {
                        isUIDragging = uiSystem.handleDrag(from: dragStartPosition, to: screenPos)
                    }
                }
            }

            // If UI drag is active, continue it
            if isUIDragging {
                if let uiSystem = gameLoop.uiSystem {
                    _ = uiSystem.handleDrag(from: dragStartPosition, to: screenPos)
                }
                return
            }

            // Update build preview position for any build mode
            if buildMode == .placing || buildMode == .moving {
                buildPreviewPosition = IntVector2(from: worldPos)
                
                // Handle belt/pole placement during drag
                if buildMode == .placing, let buildingId = selectedBuildingId, buildingId.contains("belt") || buildingId.contains("pole") {
                    handleDragPlacement(at: worldPos, gameLoop: gameLoop, buildingId: buildingId)
                }
            }

            // Handle joystick movement
            if isJoystickActive {
                joystick?.handleTouchMoved(at: screenPos, touchId: 0)
                // Exit build mode when player starts moving
                if buildMode != .none {
                    exitBuildMode()
                }
                // Prevent selection when joystick is active
                return
            }

            // Update selection rectangle (instead of camera panning)
            // Don't update selection rectangle if a UI panel is open
            if buildMode == .none && isSelecting && !(gameLoop.uiSystem?.isAnyPanelOpen ?? false), let startPos = selectionStartScreenPos {
                let startWorldPos = renderer.screenToWorld(startPos)
                let endWorldPos = renderer.screenToWorld(screenPos)
                
                // Create rectangle from start to current position
                let minX = min(startWorldPos.x, endWorldPos.x)
                let maxX = max(startWorldPos.x, endWorldPos.x)
                let minY = min(startWorldPos.y, endWorldPos.y)
                let maxY = max(startWorldPos.y, endWorldPos.y)
                
                selectionRect = Rect(
                    origin: Vector2(minX, minY),
                    size: Vector2(maxX - minX, maxY - minY)
                )
            } else if buildMode != .none {
                // Don't pan camera in build mode - building placement handles its own preview
                // (Camera panning disabled to allow belt/pole drag placement)
            }
            // Belt placement is now handled by tap-to-start, tap-to-end, not drag
            
        case .ended, .cancelled:
            // Reset UI drag state
            isUIDragging = false

            if isJoystickActive {
                joystick?.handleTouchEnded(touchId: 0)
                isJoystickActive = false
                // Reset state
                return
            }

            isDragging = false
            
            // Handle selection rectangle end (only when not in build mode and no UI panel is open)
            // Don't process selection rectangle end if a UI panel is already open
            if buildMode == .none && isSelecting && !(gameLoop.uiSystem?.isAnyPanelOpen ?? false), let rect = selectionRect {
                isSelecting = false
                selectionStartScreenPos = nil
                
                // Convert world rect to tile bounds
                let minTileX = Int32(floor(rect.minX))
                let maxTileX = Int32(ceil(rect.maxX))
                let minTileY = Int32(floor(rect.minY))
                let maxTileY = Int32(ceil(rect.maxY))
                
                // Get all entities within the rectangle
                let selectedEntities = gameLoop.world.getAllEntitiesInRect(
                    minX: minTileX, maxX: maxTileX,
                    minY: minTileY, maxY: maxTileY
                )
                
                // Filter to only interactable entities
                let interactableEntities = selectedEntities.filter { entity in
                    let hasFurnace = gameLoop.world.has(FurnaceComponent.self, for: entity)
                    let hasAssembler = gameLoop.world.has(AssemblerComponent.self, for: entity)
                    let hasMiner = gameLoop.world.has(MinerComponent.self, for: entity)
                    let hasChest = gameLoop.world.has(ChestComponent.self, for: entity)
                    let hasLab = gameLoop.world.has(LabComponent.self, for: entity)
                    let hasGenerator = gameLoop.world.has(GeneratorComponent.self, for: entity)
                    let hasPole = gameLoop.world.has(PowerPoleComponent.self, for: entity)
                    let hasBelt = gameLoop.world.has(BeltComponent.self, for: entity)
                    let hasInserter = gameLoop.world.has(InserterComponent.self, for: entity)
                    
                    return hasFurnace || hasAssembler || hasMiner || hasChest || hasLab || hasGenerator || hasPole || hasBelt || hasInserter
                }
                
                // Clear selection rectangle
                selectionRect = nil
                
                // Show entity selection dialog if multiple entities, otherwise select directly
                if interactableEntities.count > 1 {
                    gameLoop.uiSystem?.showEntitySelectionDialog(entities: interactableEntities) { [weak self] selectedEntity in
                        self?.selectEntity(selectedEntity, gameLoop: gameLoop, isDoubleTap: false)
                    }
                } else if let entity = interactableEntities.first {
                    selectEntity(entity, gameLoop: gameLoop, isDoubleTap: false)
                }
            } else {
                // Clear selection state if we were selecting but are now in build mode
                if isSelecting {
                    isSelecting = false
                    selectionStartScreenPos = nil
                    selectionRect = nil
                }
            }
            
            // Exit build mode after belt/pole placement drag ends
            if buildMode == .placing, let buildingId = selectedBuildingId, buildingId.contains("belt") || buildingId.contains("pole") {
                exitBuildMode()
            } else {
                // Clear drag placement state on drag end (for other modes)
                dragPlacedTiles = []
            }
            // Don't clear buildPreviewPosition - keep preview visible until build mode exits
            
        default:
            break
        }
    }
    
    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let camera = gameLoop?.renderer?.camera else { return }
        
        switch recognizer.state {
        case .began:
            isPinching = true
            startZoom = camera.zoom
            
        case .changed:
            let newZoom = startZoom * Float(recognizer.scale)
            camera.setZoom(newZoom, animated: false)
            
        case .ended, .cancelled:
            isPinching = false
            
        default:
            break
        }
    }


    private func selectEntity(_ entity: Entity, gameLoop: GameLoop, isDoubleTap: Bool) {
        // Debug: log what entity was selected
        let hasInserter = gameLoop.world.has(InserterComponent.self, for: entity)
        let hasBelt = gameLoop.world.has(BeltComponent.self, for: entity)
        print("InputManager: Selected entity \(entity) - Inserter: \(hasInserter), Belt: \(hasBelt)")

        // Select the entity (normal behavior)
        // First set InputManager's selectedEntity, then notify via callback (which updates HUD)
        // This ensures both are in sync
        selectedEntity = entity
        print("InputManager: Setting selectedEntity to \(entity) and calling onEntitySelected callback")
        onEntitySelected?(entity)
        
        // Show tooltip with entity icon
        if let tooltipText = getEntityTooltipText(entity: entity, gameLoop: gameLoop) {
            onTooltipWithEntity?(tooltipText, entity)
        }
        
        // Double-check that HUD got the same entity (safety check)
        if let hudEntity = gameLoop.uiSystem?.hud.selectedEntity {
            if hudEntity.id != entity.id || hudEntity.generation != entity.generation {
                print("InputManager: WARNING - HUD selectedEntity doesn't match InputManager after callback!")
                print("InputManager: Expected \(entity), but HUD has \(hudEntity)")
                // Force update HUD to match InputManager
                gameLoop.uiSystem?.hud.selectedEntity = entity
            }
        }
    }

    private func handleEntitySelection(at screenPos: Vector2, worldPos: Vector2, tilePos: IntVector2, gameLoop: GameLoop, isDoubleTap: Bool = false) {
        // Get all entities at this position
        let allEntities = gameLoop.world.getAllEntitiesAt(position: tilePos)
        
        print("InputManager: getAllEntitiesAt returned \(allEntities.count) entities at \(tilePos)")
        for entity in allEntities {
            let hasInserter = gameLoop.world.has(InserterComponent.self, for: entity)
            let hasBelt = gameLoop.world.has(BeltComponent.self, for: entity)
            let hasFurnace = gameLoop.world.has(FurnaceComponent.self, for: entity)
            print("InputManager: Entity \(entity) - Inserter: \(hasInserter), Belt: \(hasBelt), Furnace: \(hasFurnace)")
        }
        
        // Filter to only interactable entities
        let interactableEntities = allEntities.filter { entity in
            let hasFurnace = gameLoop.world.has(FurnaceComponent.self, for: entity)
            let hasAssembler = gameLoop.world.has(AssemblerComponent.self, for: entity)
            let hasMiner = gameLoop.world.has(MinerComponent.self, for: entity)
            let hasChest = gameLoop.world.has(ChestComponent.self, for: entity)
            let hasLab = gameLoop.world.has(LabComponent.self, for: entity)
            let hasGenerator = gameLoop.world.has(GeneratorComponent.self, for: entity)
            let hasPole = gameLoop.world.has(PowerPoleComponent.self, for: entity)
            let hasBelt = gameLoop.world.has(BeltComponent.self, for: entity)
            let hasInserter = gameLoop.world.has(InserterComponent.self, for: entity)
            
            let isInteractable = hasFurnace || hasAssembler || hasMiner || hasChest || hasLab || hasGenerator || hasPole || hasBelt || hasInserter
            if isInteractable {
                print("InputManager: Entity \(entity) is interactable - Inserter: \(hasInserter), Belt: \(hasBelt), Building: \(hasFurnace || hasAssembler || hasMiner || hasChest || hasLab || hasGenerator)")
            }
            return isInteractable
        }
        
        print("InputManager: Filtered to \(interactableEntities.count) interactable entities")
        
        // If multiple interactable entities, show selection dialog
        if interactableEntities.count > 1 {
            print("InputManager: Showing entity selection dialog with \(interactableEntities.count) entities")
            gameLoop.uiSystem?.showEntitySelectionDialog(entities: interactableEntities) { [weak self] selectedEntity in
                self?.selectEntity(selectedEntity, gameLoop: gameLoop, isDoubleTap: isDoubleTap)
            }
            return
        }
        
        // Single entity (or none) - use existing logic
        var closestEntity: Entity?
        if let entityAtTile = gameLoop.world.getEntityAt(position: tilePos) {
            // Check if this entity is interactable
            let hasFurnace = gameLoop.world.has(FurnaceComponent.self, for: entityAtTile)
            let hasAssembler = gameLoop.world.has(AssemblerComponent.self, for: entityAtTile)
            let hasMiner = gameLoop.world.has(MinerComponent.self, for: entityAtTile)
            let hasChest = gameLoop.world.has(ChestComponent.self, for: entityAtTile)
            let hasLab = gameLoop.world.has(LabComponent.self, for: entityAtTile)
            let hasGenerator = gameLoop.world.has(GeneratorComponent.self, for: entityAtTile)
            let hasPole = gameLoop.world.has(PowerPoleComponent.self, for: entityAtTile)
            let hasBelt = gameLoop.world.has(BeltComponent.self, for: entityAtTile)
            let hasInserter = gameLoop.world.has(InserterComponent.self, for: entityAtTile)
            
            // Prioritize inserters explicitly (getEntityAt should already do this, but be explicit)
            if hasInserter {
                closestEntity = entityAtTile
            } else if hasFurnace || hasAssembler || hasMiner || hasChest || hasLab || hasGenerator || hasPole || hasBelt {
                closestEntity = entityAtTile
            }
        }
        
        if let entity = closestEntity {
            selectEntity(entity, gameLoop: gameLoop, isDoubleTap: isDoubleTap)
        } else {
            // No entity found via getEntityAt, but check explicitly for inserters at this position
            // (inserters might be on top of ore/resources, and we want to prioritize inserter selection over mining)
            let allEntitiesAtPosition = gameLoop.world.query(PositionComponent.self).filter { entity in
                guard let pos = gameLoop.world.get(PositionComponent.self, for: entity) else { return false }
                return pos.tilePosition.x == tilePos.x && pos.tilePosition.y == tilePos.y
            }
            
            // Check if any of these entities are inserters
            for entity in allEntitiesAtPosition {
                if gameLoop.world.has(InserterComponent.self, for: entity) {
                    print("InputManager: Found inserter at \(tilePos) that wasn't returned by getEntityAt, prioritizing inserter over mining")
                    
                    // Select the inserter (normal behavior)
                    selectedEntity = entity
                    onEntitySelected?(entity)
                    return
                }
            }
            
            // No entity found at exact position, check if tap is within any entity's sprite bounds
            let allEntities = gameLoop.world.query(PositionComponent.self, SpriteComponent.self)
            var entitiesInBounds: [(Entity, Float)] = [] // (entity, sprite area - smaller is more specific)
            
            for entity in allEntities {
                // Check if this entity is interactable
                let hasFurnace = gameLoop.world.has(FurnaceComponent.self, for: entity)
                let hasAssembler = gameLoop.world.has(AssemblerComponent.self, for: entity)
                let hasMiner = gameLoop.world.has(MinerComponent.self, for: entity)
                let hasChest = gameLoop.world.has(ChestComponent.self, for: entity)
                let hasLab = gameLoop.world.has(LabComponent.self, for: entity)
                let hasGenerator = gameLoop.world.has(GeneratorComponent.self, for: entity)
                let hasPole = gameLoop.world.has(PowerPoleComponent.self, for: entity)
                let hasBelt = gameLoop.world.has(BeltComponent.self, for: entity)
                let hasInserter = gameLoop.world.has(InserterComponent.self, for: entity)
                
                if hasFurnace || hasAssembler || hasMiner || hasChest || hasLab || hasGenerator || hasPole || hasBelt || hasInserter {
                    guard let entityPos = gameLoop.world.get(PositionComponent.self, for: entity),
                          let sprite = gameLoop.world.get(SpriteComponent.self, for: entity) else { continue }
                    
                    // Calculate sprite bounds
                    // Sprite position is tilePosition + offset (in world coordinates)
                    let spriteOrigin = entityPos.tilePosition.toVector2 + entityPos.offset
                    let spriteSize = sprite.size
                    let spriteBounds = (min: spriteOrigin, max: spriteOrigin + spriteSize)
                    
                    // Check if tap position is within sprite bounds
                    if worldPos.x >= spriteBounds.min.x && worldPos.x < spriteBounds.max.x &&
                       worldPos.y >= spriteBounds.min.y && worldPos.y < spriteBounds.max.y {
                        // Entity's sprite contains the tap position
                        let spriteArea = spriteSize.x * spriteSize.y
                        entitiesInBounds.append((entity, spriteArea))
                    }
                }
            }
            
            // If multiple entities contain the tap, prefer the smallest sprite (most specific)
            if let nearest = entitiesInBounds.min(by: { $0.1 < $1.1 })?.0 {
                print("InputManager: No entity at exact position, selected entity \(nearest) whose sprite bounds contain tap position")
                
                // Select the nearest entity
                selectedEntity = nearest
                onEntitySelected?(nearest)
                return
            }
            
            // No entity found at all, check for resource to mine manually
            if let resource = gameLoop.chunkManager.getResource(at: tilePos), !resource.isEmpty {
                // Check if player can accept the item
                if gameLoop.player.inventory.canAccept(itemId: resource.type.outputItem) {
                    print("Mining resource at (\(tilePos.x), \(tilePos.y)): \(resource.type) with \(resource.amount) remaining")
                    // Manual mining - mine 1 unit
                    let mined = gameLoop.chunkManager.mineResource(at: tilePos, amount: 1)
                    if mined > 0 {
                        // Start mining animation
                        let itemId = resource.type.outputItem
                        gameLoop.uiSystem?.hud.startMiningAnimation(
                            itemId: itemId,
                            fromWorldPosition: worldPos,
                            renderer: gameLoop.renderer
                        )
                        
                        // Add to player inventory (after a delay to match animation)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak gameLoop] in
                            gameLoop?.player.inventory.add(itemId: itemId, count: mined)
                        }
                        
                        print("Manually mined \(mined) \(itemId), \(resource.amount - mined) remaining")

                        // Check if resource is now depleted
                        if let updatedResource = gameLoop.chunkManager.getResource(at: tilePos) {
                            print("Resource now has \(updatedResource.amount) remaining")
                        } else {
                            print("Resource depleted, tile should now be normal")
                        }
                    }
                } else {
                    print("Inventory full, cannot mine")
                }
            } else {
                selectedEntity = nil
                onEntitySelected?(nil)
            }
        }
    }
    
    private func handleNonCombatDoubleTap(at screenPos: Vector2, worldPos: Vector2, tilePos: IntVector2, gameLoop: GameLoop) {
        // If we're in build mode, place the building instead of normal double-tap behavior
        if buildMode == .placing, let buildingId = selectedBuildingId {
            // Calculate offset to center the building at the tap location
            // Account for sprite rendering offset: buildings are offset by half their size
            guard let buildingDef = gameLoop.buildingRegistry.get(buildingId) else { return }

            // Check inventory first
            if !gameLoop.player.inventory.has(items: buildingDef.cost) {
                // Show missing items
                let missingItems = buildingDef.cost.filter { !gameLoop.player.inventory.has(items: [$0]) }
                if let firstMissing = missingItems.first {
                    let itemName = gameLoop.itemRegistry.get(firstMissing.itemId)?.name ?? firstMissing.itemId
                    onTooltip?("Need \(firstMissing.count) \(itemName)")
                } else {
                    onTooltip?("Missing required items")
                }
                return
            }

            let spriteSize = Vector2(Float(buildingDef.width), Float(buildingDef.height))
            let tileCenter = tilePos.toVector2 + Vector2(0.5, 0.5)
            let tapOffset = worldPos - tileCenter - spriteSize / 2

            // Check placement validity
            if !gameLoop.canPlaceBuilding(buildingId, at: tilePos, direction: buildDirection) {
                onTooltip?("Cannot place building here")
                return
            }

            // Try to place with offset to center at tap location
            if gameLoop.placeBuilding(buildingId, at: tilePos, direction: buildDirection, offset: tapOffset) {
                onBuildingPlaced?(buildingId, tilePos, buildDirection)
                // Exit build mode after placing (except for belts which allow drag placement)
                if !buildingId.contains("belt") {
                    exitBuildMode()
                }
                // Play placement sound/feedback
            } else {
                onTooltip?("Failed to place building")
            }
            return
        }

        // Validate current selection before processing
        validateSelectedEntity()

        // Use shared entity selection logic
        handleEntitySelection(at: screenPos, worldPos: worldPos, tilePos: tilePos, gameLoop: gameLoop, isDoubleTap: true)
    }

    @objc private func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
        switch recognizer.state {
        case .changed:
            // Rotate building direction
            let rotation = Float(recognizer.rotation)
            if abs(rotation) > .pi / 4 {
                if rotation > 0 {
                    buildDirection = buildDirection.clockwise
                } else {
                    buildDirection = buildDirection.counterClockwise
                }
                recognizer.rotation = 0
            }
            
        default:
            break
        }
    }
    
    // MARK: - Helper Methods
    
    private func getEntityTooltipText(entity: Entity, gameLoop: GameLoop?) -> String? {
        guard let world = gameLoop?.world else { return nil }

        var tooltipLines: [String] = []

        // Get entity name first
        let entityName = getEntityName(entity: entity, gameLoop: gameLoop)
        tooltipLines.append(entityName)

        // Add health information
        if let health = world.get(HealthComponent.self, for: entity) {
            let healthPercent = Int(health.percentage * 100)
            let healthText = health.isDead ? "DESTROYED" : "Health: \(healthPercent)%"
            tooltipLines.append(healthText)
        }

        // Add production information for buildings
        if let miner = world.get(MinerComponent.self, for: entity) {
            if miner.isActive {
                if let resource = miner.resourceOutput {
                    let speedText = String(format: "%.1f", miner.miningSpeed)
                    tooltipLines.append("Mining: \(resource)")
                    tooltipLines.append("Speed: \(speedText)/s")
                } else {
                    tooltipLines.append("No resource")
                }
            } else {
                tooltipLines.append("Inactive")
            }
        }

        if let furnace = world.get(FurnaceComponent.self, for: entity) {
            if let recipe = furnace.recipe {
                let progressPercent = Int(furnace.smeltingProgress * 100)
                tooltipLines.append("Smelting: \(recipe.name)")
                tooltipLines.append("Progress: \(progressPercent)%")
                if furnace.fuelRemaining > 0 {
                    let fuelText = String(format: "%.1f", furnace.fuelRemaining)
                    tooltipLines.append("Fuel: \(fuelText)")
                }
            } else {
                tooltipLines.append("No recipe")
            }
        }

        if let assembler = world.get(AssemblerComponent.self, for: entity) {
            if let recipe = assembler.recipe {
                let progressPercent = Int(assembler.craftingProgress * 100)
                tooltipLines.append("Crafting: \(recipe.name)")
                tooltipLines.append("Progress: \(progressPercent)%")
            } else {
                tooltipLines.append("No recipe")
            }
        }

        if let belt = world.get(BeltComponent.self, for: entity) {
            let totalItems = belt.leftLane.count + belt.rightLane.count
            let speedText = String(format: "%.1f", belt.speed)
            tooltipLines.append("Items: \(totalItems)")
            tooltipLines.append("Speed: \(speedText) tiles/s")
        }

        if let inserter = world.get(InserterComponent.self, for: entity) {
            let stateText = inserter.state != .idle ? "Working" : "Idle"
            tooltipLines.append("State: \(stateText)")
        }

        // Add enemy information
        if let enemy = world.get(EnemyComponent.self, for: entity) {
            let speedText = String(format: "%.1f", enemy.speed)
            let damageText = String(format: "%.0f", enemy.damage)
            tooltipLines.append("Speed: \(speedText) tiles/s")
            tooltipLines.append("Damage: \(damageText)")

            let stateText = switch enemy.state {
            case .idle: "Idle"
            case .wandering: "Wandering"
            case .attacking: "Attacking"
            case .returning: "Returning to nest"
            case .fleeing: "Fleeing"
            }
            tooltipLines.append("State: \(stateText)")
        }

        // Add turret information
        if let turret = world.get(TurretComponent.self, for: entity) {
            let damageText = String(format: "%.0f", turret.damage)
            let rangeText = String(format: "%.0f", turret.range)
            let fireRateText = String(format: "%.1f", turret.fireRate)
            tooltipLines.append("Damage: \(damageText)")
            tooltipLines.append("Range: \(rangeText) tiles")
            tooltipLines.append("Fire Rate: \(fireRateText)/s")

            if turret.targetEntity != nil {
                tooltipLines.append("Target acquired")
            } else {
                tooltipLines.append("No target")
            }
        }

        // Add spawner information
        if let spawner = world.get(SpawnerComponent.self, for: entity) {
            let spawnedText = "\(spawner.spawnedCount)/\(spawner.maxEnemies)"
            let cooldownText = String(format: "%.1f", spawner.spawnCooldown)
            tooltipLines.append("Enemies: \(spawnedText)")
            tooltipLines.append("Cooldown: \(cooldownText)s")
        }

        // Add power information
        if let generator = world.get(GeneratorComponent.self, for: entity) {
            let outputText = String(format: "%.0f", generator.currentOutput)
            tooltipLines.append("Power: \(outputText) kW")
            if let fuel = generator.currentFuel {
                let fuelText = String(format: "%.1f", generator.fuelRemaining)
                tooltipLines.append("Fuel: \(fuel) (\(fuelText))")
            }
        }

        if let solar = world.get(SolarPanelComponent.self, for: entity) {
            let outputText = String(format: "%.0f", solar.currentOutput)
            tooltipLines.append("Power: \(outputText) kW")
        }

        if let accumulator = world.get(AccumulatorComponent.self, for: entity) {
            let chargePercent = Int(accumulator.chargePercentage * 100)
            let modeText = switch accumulator.mode {
            case .charging: "Charging"
            case .discharging: "Discharging"
            case .idle: "Idle"
            }
            tooltipLines.append("Charge: \(chargePercent)%")
            tooltipLines.append("Mode: \(modeText)")
        }

        // Add power consumer information
        if let consumer = world.get(PowerConsumerComponent.self, for: entity) {
            let consumptionText = String(format: "%.1f", consumer.consumption)
            let satisfactionPercent = Int(consumer.satisfaction * 100)
            tooltipLines.append("Power Use: \(consumptionText) kW")
            tooltipLines.append("Satisfaction: \(satisfactionPercent)%")
        }

        // Add inventory information for containers
        if let inventory = world.get(InventoryComponent.self, for: entity) {
            if !inventory.isEmpty {
                let totalItems = inventory.getAll().reduce(0) { $0 + $1.count }
                let slotInfo = "\(inventory.slots.filter { $0 != nil }.count)/\(inventory.slotCount)"
                tooltipLines.append("Items: \(totalItems)")
                tooltipLines.append("Slots: \(slotInfo)")

                // Show first few items
                let items = inventory.getAll().prefix(3)
                for item in items {
                    let itemName = gameLoop?.itemRegistry.get(item.itemId)?.name ?? item.itemId
                    tooltipLines.append("- \(itemName): \(item.count)")
                }
                if inventory.getAll().count > 3 {
                    tooltipLines.append("... and more")
                }
            } else {
                tooltipLines.append("Empty")
            }
        }

        // Add lab/research information
        if let lab = world.get(LabComponent.self, for: entity) {
            if lab.isResearching {
                tooltipLines.append("Researching...")
            } else {
                tooltipLines.append("Research complete")
            }
        }

        // Add projectile information
        if let projectile = world.get(ProjectileComponent.self, for: entity) {
            let damageText = String(format: "%.0f", projectile.damage)
            tooltipLines.append("Projectile")
            tooltipLines.append("Damage: \(damageText)")

            let targetText = projectile.target != nil ? "Target acquired" : "No target"
            tooltipLines.append(targetText)
        }

        // Join all lines with newlines
        return tooltipLines.joined(separator: "\n")
    }

    private func getEntityName(entity: Entity, gameLoop: GameLoop?) -> String {
        guard let world = gameLoop?.world else { return "Entity" }

        // Try to get name from sprite texture
        if let sprite = world.get(SpriteComponent.self, for: entity) {
            // Check for player
            if sprite.textureId == "player" {
                return "Player"
            }
            // Try to find building by texture
            if let building = gameLoop?.buildingRegistry.getByTexture(sprite.textureId) {
                return building.name
            }
            // Try to find item by texture
            let itemId = sprite.textureId.replacingOccurrences(of: "_", with: "-")
            if let item = gameLoop?.itemRegistry.get(itemId) {
                return item.name
            }
            // Fallback to texture ID
            return sprite.textureId.replacingOccurrences(of: "_", with: " ").capitalized
        }

        return "Entity"
    }
    
    private func screenPosition(from recognizer: UIGestureRecognizer) -> Vector2 {
        guard let view = view else { return .zero }
        let point = recognizer.location(in: view)
        let scale = Float(UIScreen.main.scale)
        // UI uses top-left origin (Y increases downward), same as UIKit
        return Vector2(Float(point.x) * scale, Float(point.y) * scale)
    }
    
    private func selectEntityAt(_ worldPos: Vector2) {
        guard let world = gameLoop?.world else { return }
        
        let tilePos = IntVector2(from: worldPos)
        
        if let entity = world.getEntityAt(position: tilePos) {
            selectedEntity = entity
            onEntitySelected?(entity)
        } else {
            selectedEntity = nil
            onEntitySelected?(nil)
        }
    }
    
    // MARK: - Build Mode
    
    func enterBuildMode(buildingId: String) {
        buildMode = .placing
        selectedBuildingId = buildingId
        selectedEntity = nil
        // Clear selection rectangle state when entering build mode
        isSelecting = false
        selectionStartScreenPos = nil
        selectionRect = nil
    }
    
    func enterRemoveMode() {
        buildMode = .removing
        selectedBuildingId = nil
        selectedEntity = nil
    }
    
    func exitBuildMode() {
        print("InputManager: exitBuildMode called - clearing build mode state")
        buildMode = .none
        selectedBuildingId = nil
        buildPreviewPosition = nil
        dragPlacementStartTile = nil
        dragPlacedTiles = []
        dragPathPreview = []
        entityToMove = nil
        // Clear inserter connection state
        inserterToConfigure = nil
        isConnectingInput = false
        // Clear selection rectangle state when exiting build mode
        isSelecting = false
        selectionStartScreenPos = nil
        selectionRect = nil
        print("InputManager: exitBuildMode completed - buildMode: \(buildMode), selectedBuildingId: \(selectedBuildingId ?? "nil")")
    }
    
    func enterInserterConnectionMode(inserter: Entity, isInput: Bool) {
        buildMode = .connectingInserter
        inserterToConfigure = inserter
        isConnectingInput = isInput
        onTooltip?(isInput ? "Tap an entity or belt to set input connection" : "Tap an entity or belt to set output connection")
    }
    
    private func handleInserterConnectionSelection(at tilePos: IntVector2, gameLoop: GameLoop) {
        guard let inserterEntity = inserterToConfigure else {
            exitBuildMode()
            return
        }
        
        guard let inserterPos = gameLoop.world.get(PositionComponent.self, for: inserterEntity) else {
            exitBuildMode()
            return
        }
        
        // Check if selection is within 1 tile (including diagonals)
        let distance = abs(tilePos.x - inserterPos.tilePosition.x) + abs(tilePos.y - inserterPos.tilePosition.y)
        guard distance <= 1 else {
            onTooltip?("Target must be adjacent to inserter")
            return
        }
        
        // Try to find entity at position
        if let targetEntity = gameLoop.world.getEntityAt(position: tilePos) {
            // Check if it's a valid target (belt, miner, machine, etc.)
            let hasBelt = gameLoop.world.has(BeltComponent.self, for: targetEntity)
            let hasMiner = gameLoop.world.has(MinerComponent.self, for: targetEntity)
            let hasFurnace = gameLoop.world.has(FurnaceComponent.self, for: targetEntity)
            let hasAssembler = gameLoop.world.has(AssemblerComponent.self, for: targetEntity)
            let hasChest = gameLoop.world.has(ChestComponent.self, for: targetEntity)
            
            if hasBelt || hasMiner || hasFurnace || hasAssembler || hasChest {
                if isConnectingInput {
                    if gameLoop.setInserterConnection(entity: inserterEntity, inputTarget: targetEntity, inputPosition: nil) {
                        onTooltip?("Input connection set")
                        exitBuildMode()
                    } else {
                        onTooltip?("Failed to set input connection")
                    }
                } else {
                    if gameLoop.setInserterConnection(entity: inserterEntity, outputTarget: targetEntity, outputPosition: nil) {
                        onTooltip?("Output connection set")
                        exitBuildMode()
                    } else {
                        onTooltip?("Failed to set output connection")
                    }
                }
                return
            }
        }
        
        // No entity, check if there's a belt at this position
        let entitiesAtPos = gameLoop.world.getAllEntitiesAt(position: tilePos)
        let hasBelt = entitiesAtPos.contains { gameLoop.world.has(BeltComponent.self, for: $0) }
        
        if hasBelt {
            if isConnectingInput {
                if gameLoop.setInserterConnection(entity: inserterEntity, inputTarget: nil, inputPosition: tilePos) {
                    onTooltip?("Input connection set")
                    exitBuildMode()
                } else {
                    onTooltip?("Failed to set input connection")
                }
            } else {
                if gameLoop.setInserterConnection(entity: inserterEntity, outputTarget: nil, outputPosition: tilePos) {
                    onTooltip?("Output connection set")
                    exitBuildMode()
                } else {
                    onTooltip?("Failed to set output connection")
                }
            }
            return
        }
        
        onTooltip?("No valid target at this position")
    }
    
    func enterMoveMode(entity: Entity) {
        buildMode = .moving
        entityToMove = entity
        selectedBuildingId = nil
        buildPreviewPosition = nil
        dragPlacementStartTile = nil
        dragPlacedTiles = []
        dragPathPreview = []
        // Clear selection rectangle state when entering move mode
        isSelecting = false
        selectionStartScreenPos = nil
        selectionRect = nil
    }
    
    // MARK: - Belt Placement
    
    /// Checks if an entity can be a belt source (has inventory/output)
    private func canBeBeltSource(entity: Entity, world: World) -> Bool {
        // Check for any component that indicates output capability
        return world.has(InventoryComponent.self, for: entity) ||
               world.has(FurnaceComponent.self, for: entity) ||
               world.has(AssemblerComponent.self, for: entity) ||
               world.has(MinerComponent.self, for: entity) ||
               world.has(ChestComponent.self, for: entity) ||
               world.has(BeltComponent.self, for: entity)  // Belts can connect to other belts
    }
    
    /// Checks if an entity can be a belt destination (has inventory/input)
    private func canBeBeltDestination(entity: Entity, world: World) -> Bool {
        // Same check - most entities with inventory can both input and output
        return canBeBeltSource(entity: entity, world: world)
    }
    
    /// Handles belt/pole placement during drag
    private func handleDragPlacement(at worldPos: Vector2, gameLoop: GameLoop, buildingId: String) {
        guard let buildingDef = gameLoop.buildingRegistry.get(buildingId) else { return }
        
        // Ensure we have a start tile
        guard let startTile = dragPlacementStartTile else { return }
        
        let currentTile = IntVector2(from: worldPos)
        
        // Calculate path from start to current tile using Manhattan distance
        let path = calculateBeltPath(from: startTile, to: currentTile)
        
        // Update preview
        dragPathPreview = path
        
        let isBelt = buildingId.contains("belt")
        
        // Place items along the path that haven't been placed yet
        for (index, pos) in path.enumerated() {
            // Skip if already placed
            if dragPlacedTiles.contains(pos) {
                continue
            }
            
            // Check if we can place here and have inventory
            guard gameLoop.canPlaceBuilding(buildingId, at: pos, direction: .north) else {
                continue
            }
            
            guard gameLoop.player.inventory.has(items: buildingDef.cost) else {
                continue
            }
            
            // Determine direction - only needed for belts, poles use .north
            let direction: Direction
            if isBelt {
                if index == 0 && path.count > 1 {
                    // For the start tile, use direction to the next tile
                    let nextPos = path[index + 1]
                    let dx = nextPos.x - pos.x
                    let dy = nextPos.y - pos.y
                    
                    if dx > 0 {
                        direction = .east
                    } else if dx < 0 {
                        direction = .west
                    } else if dy > 0 {
                        direction = .north
                    } else if dy < 0 {
                        direction = .south
                    } else {
                        direction = .north  // Default
                    }
                } else if index > 0 {
                    // For subsequent tiles, use direction from previous tile
                    let prevPos = path[index - 1]
                    let dx = pos.x - prevPos.x
                    let dy = pos.y - prevPos.y
                    
                    if dx > 0 {
                        direction = .east
                    } else if dx < 0 {
                        direction = .west
                    } else if dy > 0 {
                        direction = .north
                    } else if dy < 0 {
                        direction = .south
                    } else {
                        direction = .north  // Default
                    }
                } else {
                    direction = .north  // Default for single tile path
                }
            } else {
                // Poles don't need direction
                direction = .north
            }
            
            // Place the building (placeBuilding already removes items from inventory)
            if gameLoop.placeBuilding(buildingId, at: pos, direction: direction, offset: .zero) {
                dragPlacedTiles.insert(pos)
            }
        }
    }
    
    /// Calculates a path of tiles between two points (Manhattan path)
    private func calculateBeltPath(from start: IntVector2, to end: IntVector2) -> [IntVector2] {
        var path: [IntVector2] = []
        let dx = end.x - start.x
        let dy = end.y - start.y
        
        // Simple Manhattan path: move horizontally first, then vertically
        let stepX = dx > 0 ? 1 : (dx < 0 ? -1 : 0)
        let stepY = dy > 0 ? 1 : (dy < 0 ? -1 : 0)
        
        var current = start
        path.append(current)
        
        // Move horizontally
        while current.x != end.x {
            current = IntVector2(x: current.x + Int32(stepX), y: current.y)
            path.append(current)
        }
        
        // Move vertically
        while current.y != end.y {
            current = IntVector2(x: current.x, y: current.y + Int32(stepY))
            path.append(current)
        }
        
        return path
    }
    
    
    func rotateBuildDirection() {
        buildDirection = buildDirection.clockwise
    }
}

// MARK: - Build Mode

enum BuildMode {
    case none
    case placing
    case removing
    case selecting
    case moving
    case connectingInserter  // Special mode for setting inserter connections
}

// MARK: - UIGestureRecognizerDelegate

extension InputManager: UIGestureRecognizerDelegate {
    // Don't prevent pan gesture - we'll handle joystick in the pan handler
    // This allows us to get .changed and .ended events

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                          shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {

        // Allow pinch and rotation together
        if gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIRotationGestureRecognizer {
            return true
        }
        if gestureRecognizer is UIRotationGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer {
            return true
        }
        // Allow pinch and pan together (for simultaneous zoom and pan)
        if gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer {
            return true
        }
        // Allow tap and pan together
        if gestureRecognizer is UITapGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UITapGestureRecognizer {
            return true
        }
        // Allow single tap and double tap together (they're configured with requireToFail)
        if gestureRecognizer is UITapGestureRecognizer && otherGestureRecognizer is UITapGestureRecognizer {
            return true
        }
        // print("Not allowing simultaneous recognition")
        return false
    }
}

