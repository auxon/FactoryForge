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
    
    // Belt placement (entity-to-entity connection)
    private var beltSourceEntity: Entity?  // First entity selected (source)
    var beltPathPreview: [IntVector2] = []  // Preview path for rendering
    
    // Selection
    var selectedEntity: Entity?
    
    // Callbacks
    var onTap: ((Vector2) -> Void)?
    var onLongPress: ((Vector2) -> Void)?
    var onBuildingPlaced: ((String, IntVector2, Direction) -> Void)?
    var onEntitySelected: ((Entity?) -> Void)?
    var onTooltip: ((String) -> Void)? // Called when something is tapped to show tooltip
    
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

            // Don't call handleTap for double taps - double taps are for game actions, not UI
            // The UI system should only handle single taps
            print("InputManager: Double tap detected, skipping UI tap handler")
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
        }

        // If no game loop exists, we're done (loading menu should have handled it)
        guard let gameLoop = gameLoop else {
            print("InputManager: No game loop available")
            return
        }

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
                    onTooltip?(tooltipText)
                    return // Don't check resources if we found an entity
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
                // Try to select an entity at this position
                let tilePos = IntVector2(from: worldPos)
                if let entity = gameLoop.world.getEntityAt(position: tilePos) {
                    selectedEntity = entity
                    onEntitySelected?(entity)
                } else {
                    // No entity, check for resource to mine manually
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
            
        case .placing:
            let tilePos = IntVector2(from: worldPos)
            
            // Handle belt placement (entity-to-entity connection)
            if let buildingId = selectedBuildingId, buildingId.contains("belt") {
                handleBeltPlacementTap(at: tilePos, gameLoop: gameLoop, buildingId: buildingId)
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
            // Select entity at position
            let nearbyEntities = gameLoop.world.getEntitiesNear(position: worldPos, radius: 1.5)
            var selected: Entity?

            for entity in nearbyEntities {
                if gameLoop.world.has(FurnaceComponent.self, for: entity) ||
                   gameLoop.world.has(AssemblerComponent.self, for: entity) ||
                   gameLoop.world.has(MinerComponent.self, for: entity) ||
                   gameLoop.world.has(ChestComponent.self, for: entity) ||
                   gameLoop.world.has(LabComponent.self, for: entity) {
                    selected = entity
                    break
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

            
            // Not a joystick touch, proceed with camera pan
            isDragging = true
            panStartPosition = screenPos
            cameraStartPosition = renderer.camera.position
            
            if buildMode == .placing || buildMode == .moving {
                // Update build preview position
                buildPreviewPosition = IntVector2(from: worldPos)
                
                // Update belt path preview if we're placing belts and have a source entity
                if buildMode == .placing, let buildingId = selectedBuildingId, buildingId.contains("belt"), beltSourceEntity != nil {
                    updateBeltPathPreview(at: worldPos, gameLoop: gameLoop)
                }
            }
            
        case .changed:
            // Check for UI drag gesture
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
                
                // Update belt path preview if we're placing belts and have a source entity
                if buildMode == .placing, let buildingId = selectedBuildingId, buildingId.contains("belt"), beltSourceEntity != nil {
                    updateBeltPathPreview(at: worldPos, gameLoop: gameLoop)
                }
            }

            // Handle joystick movement
            if isJoystickActive {
                joystick?.handleTouchMoved(at: screenPos, touchId: 0)
                // Exit build mode when player starts moving
                if buildMode != .none {
                    exitBuildMode()
                }
                // Prevent camera pan when joystick is active
                return
            }

            // Always allow camera panning (even in build mode)
            if buildMode == .none {
                // Pan camera
                let delta = screenPos - panStartPosition
                let worldDelta = delta / renderer.camera.zoom / 32.0
                renderer.camera.target = cameraStartPosition - Vector2(worldDelta.x, -worldDelta.y)
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

        // Find the closest interactable entity near the tap position (use world position for better accuracy)
        print("InputManager: Double-tap at tile (\(tilePos.x), \(tilePos.y)), worldPos: (\(worldPos.x), \(worldPos.y))")
        
        // First, try to get the entity at the exact tile position (prioritizes buildings)
        var closestEntity: Entity?
        if let entityAtTile = gameLoop.world.getEntityAt(position: tilePos) {
            print("InputManager: getEntityAt returned entity \(entityAtTile) at tile \(tilePos)")
            // Check if this entity is interactable
            let hasFurnace = gameLoop.world.has(FurnaceComponent.self, for: entityAtTile)
            let hasAssembler = gameLoop.world.has(AssemblerComponent.self, for: entityAtTile)
            let hasMiner = gameLoop.world.has(MinerComponent.self, for: entityAtTile)
            let hasChest = gameLoop.world.has(ChestComponent.self, for: entityAtTile)
            let hasLab = gameLoop.world.has(LabComponent.self, for: entityAtTile)
            let hasGenerator = gameLoop.world.has(GeneratorComponent.self, for: entityAtTile)
            let hasBelt = gameLoop.world.has(BeltComponent.self, for: entityAtTile)
            let hasInserter = gameLoop.world.has(InserterComponent.self, for: entityAtTile)
            let hasPole = gameLoop.world.has(PowerPoleComponent.self, for: entityAtTile)
            
            print("InputManager: Entity \(entityAtTile) components - Furnace: \(hasFurnace), Assembler: \(hasAssembler), Miner: \(hasMiner), Chest: \(hasChest), Lab: \(hasLab), Generator: \(hasGenerator), Belt: \(hasBelt), Inserter: \(hasInserter), Pole: \(hasPole)")
            
            if hasFurnace || hasAssembler || hasMiner || hasChest || hasLab || hasGenerator || hasPole {
                closestEntity = entityAtTile
                print("InputManager: Found interactable entity at exact tile position: \(entityAtTile)")
            } else {
                print("InputManager: Entity at tile is not interactable")
            }
        } else {
            print("InputManager: getEntityAt returned nil for tile \(tilePos)")
        }
        
        // If no entity found at exact position, search for interactable entities
        if closestEntity == nil {
            // First, try to find entities where the tap is within their bounds (for multi-tile buildings)
            // Query all entities with interactable components and check bounds
            var candidates: [(Entity, Float)] = []  // (entity, priority distance)
            
            // Check all generators, furnaces, assemblers, etc. to see if tap is within bounds
            // Query each type separately (can't use protocol types in query)
            let generatorEntities = gameLoop.world.query(GeneratorComponent.self)
            print("InputManager: Found \(generatorEntities.count) entities with Generator component")
            for entity in generatorEntities {
                guard let pos = gameLoop.world.get(PositionComponent.self, for: entity),
                      let sprite = gameLoop.world.get(SpriteComponent.self, for: entity) else { 
                    print("InputManager: Generator entity \(entity) missing PositionComponent or SpriteComponent")
                    continue 
                }
                
                let origin = pos.tilePosition
                let width = Int32(sprite.size.x)
                let height = Int32(sprite.size.y)
                
                print("InputManager: Checking Generator entity \(entity) at origin \(origin), size \(width)x\(height), tap at \(tilePos)")
                
                let isWithinBounds = tilePos.x >= origin.x && tilePos.x < origin.x + width &&
                                    tilePos.y >= origin.y && tilePos.y < origin.y + height
                
                print("InputManager: Generator entity \(entity) - isWithinBounds: \(isWithinBounds)")
                
                if isWithinBounds {
                    let distance = pos.worldPosition.distance(to: worldPos)
                    candidates.append((entity, distance))
                    print("InputManager: Found Generator entity \(entity) with tap within bounds, distance: \(distance), origin: \(origin), size: \(width)x\(height)")
                } else {
                    print("InputManager: Generator entity \(entity) tap NOT within bounds - tap: \(tilePos), origin: \(origin), size: \(width)x\(height)")
                }
            }
            
            let furnaceEntities = gameLoop.world.query(FurnaceComponent.self)
            print("InputManager: Found \(furnaceEntities.count) entities with Furnace component")
            for entity in furnaceEntities {
                guard let pos = gameLoop.world.get(PositionComponent.self, for: entity),
                      let sprite = gameLoop.world.get(SpriteComponent.self, for: entity) else { continue }
                
                let origin = pos.tilePosition
                let width = Int32(sprite.size.x)
                let height = Int32(sprite.size.y)
                
                let isWithinBounds = tilePos.x >= origin.x && tilePos.x < origin.x + width &&
                                    tilePos.y >= origin.y && tilePos.y < origin.y + height
                
                if isWithinBounds {
                    let distance = pos.worldPosition.distance(to: worldPos)
                    candidates.append((entity, distance))
                    print("InputManager: Found Furnace entity \(entity) with tap within bounds, distance: \(distance)")
                }
            }
            
            let assemblerEntities = gameLoop.world.query(AssemblerComponent.self)
            print("InputManager: Found \(assemblerEntities.count) entities with Assembler component")
            for entity in assemblerEntities {
                guard let pos = gameLoop.world.get(PositionComponent.self, for: entity),
                      let sprite = gameLoop.world.get(SpriteComponent.self, for: entity) else { continue }
                
                let origin = pos.tilePosition
                let width = Int32(sprite.size.x)
                let height = Int32(sprite.size.y)
                
                let isWithinBounds = tilePos.x >= origin.x && tilePos.x < origin.x + width &&
                                    tilePos.y >= origin.y && tilePos.y < origin.y + height
                
                if isWithinBounds {
                    let distance = pos.worldPosition.distance(to: worldPos)
                    candidates.append((entity, distance))
                    print("InputManager: Found Assembler entity \(entity) with tap within bounds, distance: \(distance)")
                }
            }
            
            let minerEntities = gameLoop.world.query(MinerComponent.self)
            print("InputManager: Found \(minerEntities.count) entities with Miner component")
            for entity in minerEntities {
                guard let pos = gameLoop.world.get(PositionComponent.self, for: entity),
                      let sprite = gameLoop.world.get(SpriteComponent.self, for: entity) else { continue }
                
                let origin = pos.tilePosition
                let width = Int32(sprite.size.x)
                let height = Int32(sprite.size.y)
                
                let isWithinBounds = tilePos.x >= origin.x && tilePos.x < origin.x + width &&
                                    tilePos.y >= origin.y && tilePos.y < origin.y + height
                
                if isWithinBounds {
                    let distance = pos.worldPosition.distance(to: worldPos)
                    candidates.append((entity, distance))
                    print("InputManager: Found Miner entity \(entity) with tap within bounds, distance: \(distance)")
                }
            }
            
            let chestEntities = gameLoop.world.query(ChestComponent.self)
            print("InputManager: Found \(chestEntities.count) entities with Chest component")
            for entity in chestEntities {
                guard let pos = gameLoop.world.get(PositionComponent.self, for: entity),
                      let sprite = gameLoop.world.get(SpriteComponent.self, for: entity) else { continue }
                
                let origin = pos.tilePosition
                let width = Int32(sprite.size.x)
                let height = Int32(sprite.size.y)
                
                let isWithinBounds = tilePos.x >= origin.x && tilePos.x < origin.x + width &&
                                    tilePos.y >= origin.y && tilePos.y < origin.y + height
                
                if isWithinBounds {
                    let distance = pos.worldPosition.distance(to: worldPos)
                    candidates.append((entity, distance))
                    print("InputManager: Found Chest entity \(entity) with tap within bounds, distance: \(distance)")
                }
            }
            
            let labEntities = gameLoop.world.query(LabComponent.self)
            print("InputManager: Found \(labEntities.count) entities with Lab component")
            for entity in labEntities {
                guard let pos = gameLoop.world.get(PositionComponent.self, for: entity),
                      let sprite = gameLoop.world.get(SpriteComponent.self, for: entity) else { continue }
                
                let origin = pos.tilePosition
                let width = Int32(sprite.size.x)
                let height = Int32(sprite.size.y)
                
                let isWithinBounds = tilePos.x >= origin.x && tilePos.x < origin.x + width &&
                                    tilePos.y >= origin.y && tilePos.y < origin.y + height
                
                if isWithinBounds {
                    let distance = pos.worldPosition.distance(to: worldPos)
                    candidates.append((entity, distance))
                    print("InputManager: Found Lab entity \(entity) with tap within bounds, distance: \(distance)")
                }
            }
            
            // Check power poles
            let poleEntities = gameLoop.world.query(PowerPoleComponent.self)
            print("InputManager: Found \(poleEntities.count) entities with PowerPole component")
            for entity in poleEntities {
                guard let pos = gameLoop.world.get(PositionComponent.self, for: entity),
                      let sprite = gameLoop.world.get(SpriteComponent.self, for: entity) else { continue }
                
                let origin = pos.tilePosition
                let width = Int32(sprite.size.x)
                let height = Int32(sprite.size.y)
                
                let isWithinBounds = tilePos.x >= origin.x && tilePos.x < origin.x + width &&
                                    tilePos.y >= origin.y && tilePos.y < origin.y + height
                
                if isWithinBounds {
                    let distance = pos.worldPosition.distance(to: worldPos)
                    candidates.append((entity, distance))
                    print("InputManager: Found PowerPole entity \(entity) with tap within bounds, distance: \(distance)")
                }
            }
            
            // If we found candidates within bounds, use the closest one
            if !candidates.isEmpty {
                candidates.sort { $0.1 < $1.1 }  // Sort by distance
                closestEntity = candidates[0].0
                print("InputManager: Selected entity \(closestEntity!) from bounds check, distance: \(candidates[0].1)")
            } else {
                // Fallback: search nearby entities by distance, and also check by sprite texture/size for boilers
                // This handles cases where boilers might not have GeneratorComponent (old saves)
                let nearbyEntities = gameLoop.world.getEntitiesNear(position: worldPos, radius: 3.0)
                print("InputManager: No entities within bounds, checking \(nearbyEntities.count) nearby entities")
                var closestDistance = Float.greatestFiniteMagnitude
                
            for entity in nearbyEntities {
                let hasFurnace = gameLoop.world.has(FurnaceComponent.self, for: entity)
                let hasAssembler = gameLoop.world.has(AssemblerComponent.self, for: entity)
                let hasMiner = gameLoop.world.has(MinerComponent.self, for: entity)
                let hasChest = gameLoop.world.has(ChestComponent.self, for: entity)
                let hasLab = gameLoop.world.has(LabComponent.self, for: entity)
                let hasGenerator = gameLoop.world.has(GeneratorComponent.self, for: entity)
                let hasPowerPole = gameLoop.world.has(PowerPoleComponent.self, for: entity)
                
                // Also check if it's a boiler by sprite texture/size (2x3 = boiler)
                var isBoiler = false
                if let sprite = gameLoop.world.get(SpriteComponent.self, for: entity),
                   let pos = gameLoop.world.get(PositionComponent.self, for: entity) {
                    // Boiler is 2x3 tiles
                    if sprite.size.x == 2.0 && sprite.size.y == 3.0 {
                        // Check if tap is within bounds
                        let origin = pos.tilePosition
                        if tilePos.x >= origin.x && tilePos.x < origin.x + 2 &&
                           tilePos.y >= origin.y && tilePos.y < origin.y + 3 {
                            isBoiler = true
                            print("InputManager: Found potential boiler entity \(entity) by size/texture check")
                        }
                    }
                }
                
                guard hasFurnace || hasAssembler || hasMiner || hasChest || hasLab || hasGenerator || hasPowerPole || isBoiler else { continue }
                    
                    if let pos = gameLoop.world.get(PositionComponent.self, for: entity) {
                        let distance = pos.worldPosition.distance(to: worldPos)
                        // Prioritize boilers found by size check
                        let adjustedDistance = isBoiler ? distance * 0.1 : distance
                        if adjustedDistance < closestDistance {
                            closestDistance = adjustedDistance
                            closestEntity = entity
                            print("InputManager: Selected entity \(entity) (isBoiler: \(isBoiler)) with distance \(distance)")
                        }
                    }
                }
            }
        }
        
        if let entity = closestEntity {
            print("InputManager: Found closest interactable entity \(entity)")
            // Check what type it is for logging
            let hasFurnace = gameLoop.world.has(FurnaceComponent.self, for: entity)
            let hasAssembler = gameLoop.world.has(AssemblerComponent.self, for: entity)
            let hasMiner = gameLoop.world.has(MinerComponent.self, for: entity)
            let hasChest = gameLoop.world.has(ChestComponent.self, for: entity)
            let hasLab = gameLoop.world.has(LabComponent.self, for: entity)
            let hasGenerator = gameLoop.world.has(GeneratorComponent.self, for: entity)
            let hasPowerPole = gameLoop.world.has(PowerPoleComponent.self, for: entity)
            print("InputManager: Entity components - Furnace: \(hasFurnace), Assembler: \(hasAssembler), Miner: \(hasMiner), Chest: \(hasChest), Lab: \(hasLab), Generator: \(hasGenerator), PowerPole: \(hasPowerPole)")

            print("InputManager: Opening UI for entity")

            // Exit build mode if we're in it
            if buildMode != .none {
                exitBuildMode()
            }

            // Select the entity and open appropriate UI
            selectedEntity = entity
            onEntitySelected?(entity)
        } else {
            print("InputManager: No interactable entity found near position")
            // No entity, check for resource to mine
            if let resource = gameLoop.chunkManager.getResource(at: tilePos), !resource.isEmpty {
                // Check if player can accept the item
                if gameLoop.player.inventory.canAccept(itemId: resource.type.outputItem) {
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

                        print("Manually mined \(mined) \(itemId)")
                    }
                } else {
                    print("Inventory full, cannot mine")
                    onTooltip?("Inventory Full")
                }
            }
        }
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
    }
    
    func enterRemoveMode() {
        buildMode = .removing
        selectedBuildingId = nil
        selectedEntity = nil
    }
    
    func exitBuildMode() {
        buildMode = .none
        selectedBuildingId = nil
        buildPreviewPosition = nil
        beltSourceEntity = nil
        beltPathPreview = []
        entityToMove = nil
    }
    
    func enterMoveMode(entity: Entity) {
        buildMode = .moving
        entityToMove = entity
        selectedBuildingId = nil
        buildPreviewPosition = nil
        beltSourceEntity = nil
        beltPathPreview = []
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
    
    private func handleBeltPlacementTap(at tilePos: IntVector2, gameLoop: GameLoop, buildingId: String) {
        guard let buildingDef = gameLoop.buildingRegistry.get(buildingId) else { return }
        
        // Find entity at this position
        guard let targetEntity = gameLoop.world.getEntityAt(position: tilePos) else {
            onTooltip?("Select a building or item to connect")
            return
        }
        
        if let sourceEntity = beltSourceEntity {
            // Second tap - check if this is a valid destination
            guard sourceEntity != targetEntity else {
                onTooltip?("Cannot connect entity to itself")
                return
            }
            
            guard canBeBeltDestination(entity: targetEntity, world: gameLoop.world) else {
                onTooltip?("Selected entity cannot receive items")
                return
            }
            
            // Check inventory for belt items
            if !gameLoop.player.inventory.has(items: buildingDef.cost) {
                let missingItems = buildingDef.cost.filter { !gameLoop.player.inventory.has(items: [$0]) }
                if let firstMissing = missingItems.first {
                    let itemName = gameLoop.itemRegistry.get(firstMissing.itemId)?.name ?? firstMissing.itemId
                    onTooltip?("Need \(firstMissing.count) \(itemName)")
                } else {
                    onTooltip?("Missing required items")
                }
                return
            }
            
            // Get positions of source and destination entities
            guard let sourcePos = gameLoop.world.get(PositionComponent.self, for: sourceEntity),
                  let destPos = gameLoop.world.get(PositionComponent.self, for: targetEntity) else {
                onTooltip?("Invalid entity positions")
                return
            }
            
            // Calculate path and place belts
            let path = calculateBeltPath(from: sourcePos.tilePosition, to: destPos.tilePosition)
            var placedCount = 0
            
            for pos in path {
                // Check if we can place here
                if gameLoop.canPlaceBuilding(buildingId, at: pos, direction: buildDirection) {
                    // Check if we still have items
                    if gameLoop.player.inventory.has(items: buildingDef.cost) {
                        if gameLoop.placeBuilding(buildingId, at: pos, direction: buildDirection, offset: .zero) {
                            gameLoop.player.inventory.remove(items: buildingDef.cost)
                            placedCount += 1
                        }
                    } else {
                        // Out of items, stop placing
                        break
                    }
                }
            }
            
            if placedCount > 0 {
                onBuildingPlaced?(buildingId, destPos.tilePosition, buildDirection)
                onTooltip?("Placed \(placedCount) belt\(placedCount == 1 ? "" : "s")")
            } else {
                onTooltip?("Cannot place belts along path")
            }
            
            // Reset for next placement
            beltSourceEntity = nil
            beltPathPreview = []
        } else {
            // First tap - select source entity
            guard canBeBeltSource(entity: targetEntity, world: gameLoop.world) else {
                onTooltip?("Selected entity cannot output items")
                return
            }
            
            beltSourceEntity = targetEntity
            if let sourcePos = gameLoop.world.get(PositionComponent.self, for: targetEntity) {
                beltPathPreview = [sourcePos.tilePosition]  // Start with source position
            }
            onTooltip?("Select destination building or item")
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
    
    /// Updates the belt path preview when hovering (called from pan handler)
    func updateBeltPathPreview(at worldPos: Vector2, gameLoop: GameLoop) {
        guard let sourceEntity = beltSourceEntity,
              let sourcePos = gameLoop.world.get(PositionComponent.self, for: sourceEntity) else {
            beltPathPreview = []
            return
        }
        
        let tilePos = IntVector2(from: worldPos)
        
        // Check if there's a valid destination entity at this position
        if let destEntity = gameLoop.world.getEntityAt(position: tilePos),
           destEntity != sourceEntity,
           canBeBeltDestination(entity: destEntity, world: gameLoop.world),
           let destPos = gameLoop.world.get(PositionComponent.self, for: destEntity) {
            // Show preview path to valid destination
            beltPathPreview = calculateBeltPath(from: sourcePos.tilePosition, to: destPos.tilePosition)
        } else {
            // No valid destination - clear preview
            beltPathPreview = []
        }
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

