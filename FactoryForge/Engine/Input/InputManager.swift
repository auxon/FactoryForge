import UIKit
import CoreMotion
import CoreHaptics

/// Manages all touch input for the game
@available(iOS 17.0, *)
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
    private var dragPlacementOffset: Vector2?  // Offset for drag placement (pipes)
    private var dragStartWorldPos: Vector2?  // World position where drag started (pipes)
    private var dragPlacedPositions: [Vector2] = []  // World positions placed for pipes
    private var dragPlacementNetworkId: Int?  // Network ID for pipe drag placement
    private var dragPlacedPipeEntities: Set<Entity> = []  // Pipes placed during drag
    var dragPathPreview: [IntVector2] = []  // Preview path for rendering
    var dragPathPreviewWorld: [Vector2] = []  // Preview path for pipes
    private var pendingPipeTankSelection: Entity?

    // MARK: - Flow State Mechanics (iPhone as Toy)

    // Core Motion for device tilt and shake
    private let motionManager = CMMotionManager()
    private var lastAcceleration: CMAcceleration?
    private var shakeThreshold: Double = 1.5
    private var lastShakeTime: TimeInterval = 0

    // Haptic feedback engine
    private var hapticEngine: CHHapticEngine?
    private var lastHapticTime: TimeInterval = 0
    private var hapticCooldown: TimeInterval = 0.1

    // Gesture combo timing
    private var lastGestureTime: TimeInterval = 0
    private var gestureComboThreshold: TimeInterval = 0.5

    // Haptic feedback patterns
    enum HapticPattern {
        case lightImpact
        case mediumImpact
        case heavyImpact
        case rigidImpact
        case notification(NotificationType)
        case continuous(TimeInterval)

        enum NotificationType {
            case success
            case warning
            case error
        }
    }

    // MARK: - Unit Commands

    private func issueUnitCommand(at worldPos: Vector2, tilePos: IntVector2, gameLoop: GameLoop) {
        // Check if there's an enemy at the target location
        let nearbyEnemies = gameLoop.world.getEntitiesNear(position: worldPos, radius: 2.0)
        var targetEnemy: Entity?

        for enemy in nearbyEnemies {
            if gameLoop.world.has(EnemyComponent.self, for: enemy) {
                targetEnemy = enemy
                break
            }
        }

        // Issue commands to all selected units
        for unitEntity in selectedUnits {
            if let unit = gameLoop.world.get(UnitComponent.self, for: unitEntity) {
                if let enemy = targetEnemy {
                    // Attack the enemy
                    unit.commandQueue.append(.attack(entity: enemy))
                    print("InputManager: Issued attack command to unit \(unitEntity) targeting enemy \(enemy)")
                } else {
                    // Move to position
                    unit.commandQueue.append(.move(to: tilePos))
                    print("InputManager: Issued move command to unit \(unitEntity) to position \(tilePos)")
                }
                // Clear current command to start the new one
                unit.currentCommand = nil
            }
        }
    }

    func selectUnit(_ entity: Entity, gameLoop: GameLoop) {
        if gameLoop.world.has(UnitComponent.self, for: entity) {
            // If shift is not held (or we don't have shift detection), clear previous selection
            // For now, we'll do single unit selection
            selectedUnits.removeAll()
            selectedUnits.insert(entity)

            selectedEntity = entity
            onEntitySelected?(entity)
            print("InputManager: Selected unit \(entity)")
        }
    }

    func clearUnitSelection() {
        selectedUnits.removeAll()
        selectedEntity = nil
        onEntitySelected?(nil)
        print("InputManager: Cleared unit selection")
    }
    
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

    // Unit selection and control
    var selectedUnits: Set<Entity> = []  // Multiple unit selection for RTS-style control
    var selectionBoxStart: Vector2?  // For drag selection
    var isDragSelecting: Bool = false

    /// Validates that the currently selected entity is still alive
    private func validateSelectedEntity() {
        if let entity = selectedEntity, let gameLoop = gameLoop {
            if !gameLoop.world.isAlive(entity) {
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
        setupMotionManager()
        setupHapticEngine()
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

        // Add new flow state gestures
        setupFlowStateGestures()
    }

    private func setupFlowStateGestures() {
        guard let view = view else { return }

        // Swipe gestures for quick actions
        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUp(_:)))
        swipeUp.direction = .up
        swipeUp.delegate = self
        view.addGestureRecognizer(swipeUp)

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown(_:)))
        swipeDown.direction = .down
        swipeDown.delegate = self
        view.addGestureRecognizer(swipeDown)

        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft(_:)))
        swipeLeft.direction = .left
        swipeLeft.delegate = self
        view.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight(_:)))
        swipeRight.direction = .right
        swipeRight.delegate = self
        view.addGestureRecognizer(swipeRight)

        // Multi-finger taps for special actions
        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
        twoFingerTap.numberOfTouchesRequired = 2
        twoFingerTap.delegate = self
        view.addGestureRecognizer(twoFingerTap)

        let threeFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleThreeFingerTap(_:)))
        threeFingerTap.numberOfTouchesRequired = 3
        threeFingerTap.delegate = self
        view.addGestureRecognizer(threeFingerTap)
    }

    private func setupMotionManager() {
        // Setup accelerometer for shake detection and tilt
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0 / 60.0 // 60Hz
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
                guard let self = self, let acceleration = data?.acceleration else { return }
                self.handleAccelerometer(data: acceleration)
            }
        }

        // Setup gyroscope for tilt detection
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 1.0 / 60.0
            motionManager.startGyroUpdates(to: .main) { [weak self] (data, error) in
                guard let self = self, let rotation = data?.rotationRate else { return }
                self.handleGyroscope(data: rotation)
            }
        }
    }

    private func setupHapticEngine() {
        // Create haptic engine for advanced feedback
        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.start(completionHandler: { [weak self] error in
                if let error = error {
                    print("InputManager: Failed to start haptic engine: \(error)")
                } else {
                    print("InputManager: Haptic engine started successfully")
                }
            })
        } catch {
            print("InputManager: Failed to create haptic engine: \(error)")
        }
    }

    // MARK: - Gesture Handlers
    
    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        let screenPos = screenPosition(from: recognizer)

        // If no game loop exists, we're done (loading menu should have handled it)
        guard let gameLoop = gameLoop else {
            // Still check UI system if game loop doesn't exist
            let uiSystem = renderer?.uiSystem
            if let uiSystem = uiSystem, uiSystem.handleTap(at: screenPos) {
                return
            }
            return
        }

        // Get world position for game world checks
        let worldPos = gameLoop.renderer?.screenToWorld(screenPos) ?? renderer?.screenToWorld(screenPos) ?? .zero
        let tilePos = IntVector2(from: worldPos)

        // If we're in placing mode, prioritize game world placement over UI interaction
        // This allows double-tap to place items/buildings even if the tap position overlaps with UI
        if buildMode == .placing {
            // Update build preview position for tap placement
            buildPreviewPosition = tilePos
            // Continue to placement logic below
        } else {
            // Not in placing mode - check UI first
            let uiSystem = gameLoop.uiSystem ?? renderer?.uiSystem
            if let uiSystem = uiSystem {
                if let tooltip = uiSystem.getTooltip(at: screenPos) {
                    // Show tooltip for UI element
                    onTooltip?(tooltip)
                }

                // Check if a UI panel is open that should consume the tap
                // If entitySelection dialog is open, let it handle double taps specially
                if uiSystem.isPanelOpen(.entitySelection) {
                    // Check if the dialog handles the double tap (e.g., on a button)
                    if uiSystem.handleDoubleTap(at: screenPos) {
                        return
                    }
                    // If tap wasn't on a button, don't process game world interaction
                    return
                }
                
                // For HUD buttons and other UI, double taps should work the same as single taps
                // Check if UI system handles the tap (e.g., HUD buttons)
                // Only check this if not in placing mode (we already handled placing mode above)
                if uiSystem.handleTap(at: screenPos) {
                    return
                }
            }
        }

        // Update build preview position for tap placement (if not already set above)
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
            if let player = gameLoop.player {
                let playerPos = player.position
                let distanceToTap = playerPos.distance(to: worldPos)
                print("InputManager: Double tap at \(worldPos), player at \(playerPos), distance: \(distanceToTap)")
            }
            
            let nearbyEnemies = gameLoop.world.getEntitiesNear(position: worldPos, radius: 5.0)
            print("InputManager: Double tap at \(worldPos), found \(nearbyEnemies.count) nearby entities via spatial query")
            
            // Also try direct enemy query as fallback (spatial index might miss moving enemies)
            var allEnemies: [Entity] = []
            gameLoop.world.forEach(EnemyComponent.self) { entity, _ in
                if let enemyPos = gameLoop.world.get(PositionComponent.self, for: entity) {
                    let distance = enemyPos.worldPosition.distance(to: worldPos)
                    if distance <= 5.0 {
                        allEnemies.append(entity)
                        print("InputManager: Found enemy \(entity.id) via direct query at distance \(distance), position: \(enemyPos.worldPosition)")
                    }
                }
            }
            
            // Combine results (use direct query if spatial query found nothing)
            let enemiesToCheck = nearbyEnemies.isEmpty ? allEnemies : nearbyEnemies
            print("InputManager: Checking \(enemiesToCheck.count) enemies (spatial: \(nearbyEnemies.count), direct: \(allEnemies.count))")
            var attacked = false

            for enemy in enemiesToCheck {
                if gameLoop.world.has(EnemyComponent.self, for: enemy) {
                    print("InputManager: Found enemy entity \(enemy.id) at tap location")
                    // Try to attack the enemy directly
                    if let player = gameLoop.player {
                        print("InputManager: Attempting to attack enemy \(enemy.id) with player")
                        if player.attackEnemy(enemy: enemy) {
                            print("InputManager: Attack successful!")
                            attacked = true
                            break
                        } else {
                            print("InputManager: Attack failed (check logs above for reason)")
                        }
                    } else {
                        print("InputManager: No player reference available")
                    }
                }
            }
            
            if !attacked && enemiesToCheck.count > 0 {
                print("InputManager: No valid enemy found to attack (checked \(enemiesToCheck.count) entities)")
            } else if !attacked {
                print("InputManager: No enemies found within 5.0 units of tap position")
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
                guard let player = gameLoop.player else { return }
                if !player.inventory.has(items: buildingDef.cost) {
                    // Show missing items
                    let missingItems = buildingDef.cost.filter { !player.inventory.has(items: [$0]) }
                    if let firstMissing = missingItems.first {
                        let itemName = gameLoop.itemRegistry.get(firstMissing.itemId)?.name ?? firstMissing.itemId
                        onTooltip?("Need \(firstMissing.count) \(itemName)")
                    } else {
                        onTooltip?("Missing required items")
                    }
                    return
                }
                
                // Calculate offset to place the building at the tap location
                // For centered sprites (belts, inserters), offset is relative to tile center
                // For non-centered sprites (buildings), account for half sprite size offset
                let spriteSize = Vector2(Float(buildingDef.width), Float(buildingDef.height))
                let tileCenter = tilePos.toVector2 + Vector2(0.5, 0.5)
                let isBelt = buildingDef.type == .belt
                let isInserter = buildingDef.type == .inserter
                let isPipe = buildingDef.type == .pipe
                let tapOffset = (isBelt || isInserter) ? (worldPos - tileCenter) : (worldPos - tileCenter - spriteSize / 2)

                // Check placement validity
                let canPlacePipe = !isPipe || gameLoop.canPlacePipe(at: tilePos, direction: buildDirection, offset: tapOffset)
                if !gameLoop.canPlaceBuilding(buildingId, at: tilePos, direction: buildDirection) || !canPlacePipe {
                    onTooltip?("Cannot place building here")
                    return
                }

                // Try to place with offset to center at tap location
                if gameLoop.placeBuilding(buildingId, at: tilePos, direction: buildDirection, offset: tapOffset) {
                    onBuildingPlaced?(buildingId, tilePos, buildDirection)
                    // Exit build mode after placing a building
                    exitBuildMode()
                    AudioManager.shared.playPlaceSound()

                    // Select the newly placed entity
                    if let placedEntity = gameLoop.world.getEntityAt(position: tilePos) {
                        selectedEntity = placedEntity
                        onEntitySelected?(placedEntity)
                        if isPipe {
                            promptPipeTankSelection(for: placedEntity, gameLoop: gameLoop)
                        }
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
        let screenPos = screenPosition(from: recognizer)

        // Check for UI tooltips first (before UI system consumes the tap)
        let uiSystem = gameLoop?.uiSystem ?? renderer?.uiSystem
        if let uiSystem = uiSystem {
            if let tooltip = uiSystem.getTooltip(at: screenPos) {
                // Show tooltip for UI element
                onTooltip?(tooltip)
            }

            // Then check UI system for actual functionality
            if uiSystem.handleTap(at: screenPos) {
                return
            }
            
            // Connection selection is now handled in buildMode == .connectingInserter
        }

        // If no game loop exists, we're done (loading menu should have handled it)
        guard let gameLoop = gameLoop else {
            return
        }

        // Validate current selection before processing
        validateSelectedEntity()

        // Check for entities/resources BEFORE UI system check, so tooltips always work
        let worldPos = gameLoop.renderer?.screenToWorld(screenPos) ?? renderer?.screenToWorld(screenPos) ?? .zero
        let tilePos = IntVector2(from: worldPos)
 
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
            if let player = gameLoop.player {
                let playerPos = player.position
                let distanceToTap = playerPos.distance(to: worldPos)
                print("InputManager: Single tap at \(worldPos), player at \(playerPos), distance: \(distanceToTap)")
            }
            
            let nearbyEnemies = gameLoop.world.getEntitiesNear(position: worldPos, radius: 5.0)
            print("InputManager: Single tap at \(worldPos), found \(nearbyEnemies.count) nearby entities via spatial query")
            
            // Also try direct enemy query as fallback (spatial index might miss moving enemies)
            var allEnemies: [Entity] = []
            gameLoop.world.forEach(EnemyComponent.self) { entity, _ in
                if let enemyPos = gameLoop.world.get(PositionComponent.self, for: entity) {
                    let distance = enemyPos.worldPosition.distance(to: worldPos)
                    if distance <= 5.0 {
                        allEnemies.append(entity)
                        print("InputManager: Found enemy \(entity.id) via direct query at distance \(distance), position: \(enemyPos.worldPosition)")
                    }
                }
            }
            
            // Combine results (use direct query if spatial query found nothing)
            let enemiesToCheck = nearbyEnemies.isEmpty ? allEnemies : nearbyEnemies
            print("InputManager: Checking \(enemiesToCheck.count) enemies (spatial: \(nearbyEnemies.count), direct: \(allEnemies.count))")
            var attacked = false

            for enemy in enemiesToCheck {
                if gameLoop.world.has(EnemyComponent.self, for: enemy) {
                    print("InputManager: Found enemy entity \(enemy.id) at tap location")
                    // Try to attack the enemy directly by its entity ID instead of position
                    // This avoids precision issues with position conversion
                    if let player = gameLoop.player {
                        print("InputManager: Attempting to attack enemy \(enemy.id) with player")
                        if player.attackEnemy(enemy: enemy) {
                            print("InputManager: Attack successful!")
                            attacked = true
                            break
                        } else {
                            print("InputManager: Attack failed (check logs above for reason)")
                        }
                    } else {
                        print("InputManager: No player reference available")
                    }
                }
            }
            
            if !attacked && enemiesToCheck.count > 0 {
                print("InputManager: No valid enemy found to attack (checked \(enemiesToCheck.count) entities)")
            } else if !attacked {
                print("InputManager: No enemies found within 5.0 units of tap position")
            }

            if !attacked {
                // Check if we have selected units - if so, issue commands
                if !selectedUnits.isEmpty {
                    issueUnitCommand(at: worldPos, tilePos: tilePos, gameLoop: gameLoop)
                } else {
                    // Try to select an entity at this position using the same logic as double tap
                    handleEntitySelection(at: screenPos, worldPos: worldPos, tilePos: tilePos, gameLoop: gameLoop)
                }
            }
            
        case .placing:
            let tilePos = IntVector2(from: worldPos)
            
            // Handle belt/pole/pipe placement (tap to set start tile, then drag)
            if let buildingId = selectedBuildingId,
               buildingId.contains("belt") || buildingId.contains("pole") || buildingId.contains("pipe") {
                // Just set the start tile, items will be placed during drag
                dragPlacementStartTile = tilePos
                dragPlacedTiles = []
                dragPathPreview = [tilePos]
                let tileCenter = tilePos.toVector2 + Vector2(0.5, 0.5)
                dragPlacementOffset = buildingId.contains("pipe") ? (worldPos - tileCenter) : .zero
                dragStartWorldPos = buildingId.contains("pipe") ? worldPos : nil
                dragPlacedPositions = []
                dragPathPreviewWorld = []
                if buildingId.contains("pipe") {
                    dragPlacementNetworkId = gameLoop.fluidNetworkSystem.getNextNetworkId()
                    dragPlacedPipeEntities.removeAll()
                    pendingPipeTankSelection = nil
                }
                return
            }
            
            // For non-belt buildings, check if we're tapping on an existing entity
            if let entity = gameLoop.world.getEntityAt(position: tilePos) {
                print("InputManager: Tapped on entity \(entity) at \(tilePos) - has assembler: \(gameLoop.world.has(AssemblerComponent.self, for: entity)), has furnace: \(gameLoop.world.has(FurnaceComponent.self, for: entity))")
                // Entity was tapped - select it and exit build mode
                selectedEntity = entity
                onEntitySelected?(entity)
                exitBuildMode()
                return
            } else {
                print("InputManager: No entity found at \(tilePos) for single tap")
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
                guard let player = gameLoop.player else { return }
                if !player.inventory.has(items: buildingDef.cost) {
                    // Show missing items
                    let missingItems = buildingDef.cost.filter { !player.inventory.has(items: [$0]) }
                    if let firstMissing = missingItems.first {
                        let itemName = gameLoop.itemRegistry.get(firstMissing.itemId)?.name ?? firstMissing.itemId
                        onTooltip?("Need \(firstMissing.count) \(itemName)")
                    } else {
                        onTooltip?("Missing required items")
                    }
                    return
                }
                
                // Calculate offset to place the building at the tap location
                // For centered sprites (belts, inserters), offset is relative to tile center
                // For non-centered sprites (buildings), account for half sprite size offset
                let spriteSize = Vector2(Float(buildingDef.width), Float(buildingDef.height))
                let tileCenter = tilePos.toVector2 + Vector2(0.5, 0.5)
                let isBelt = buildingDef.type == .belt
                let isInserter = buildingDef.type == .inserter
                let isPipe = buildingDef.type == .pipe
                let tapOffset = (isBelt || isInserter) ? (worldPos - tileCenter) : (worldPos - tileCenter - spriteSize / 2)

                // Check placement validity
                let canPlacePipe = !isPipe || gameLoop.canPlacePipe(at: tilePos, direction: buildDirection, offset: tapOffset)
                if !gameLoop.canPlaceBuilding(buildingId, at: tilePos, direction: buildDirection) || !canPlacePipe {
                    onTooltip?("Cannot place building here")
                    return
                }

                // Try to place with offset to center at tap location
                if gameLoop.placeBuilding(buildingId, at: tilePos, direction: buildDirection, offset: tapOffset) {
                    onBuildingPlaced?(buildingId, tilePos, buildDirection)
                    // Keep in build mode to allow placing more buildings
                    // Play placement sound/feedback
                    AudioManager.shared.playPlaceSound()

                    if buildingDef.type == .pipe {
                        updatePipeShapeForPlacement(at: tilePos, fallbackDirection: buildDirection, gameLoop: gameLoop)
                    }

                    // Select the newly placed entity
                    if let placedEntity = gameLoop.world.getEntityAt(position: tilePos) {
                        selectedEntity = placedEntity
                        onEntitySelected?(placedEntity)
                        if buildingDef.type == .pipe {
                            promptPipeTankSelection(for: placedEntity, gameLoop: gameLoop)
                        }
                    }
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
                   gameLoop.world.has(LabComponent.self, for: entityAtTile) ||
                   gameLoop.world.has(GeneratorComponent.self, for: entityAtTile) ||
                   gameLoop.world.has(PowerPoleComponent.self, for: entityAtTile) ||
                   gameLoop.world.has(BeltComponent.self, for: entityAtTile) ||
                   gameLoop.world.has(InserterComponent.self, for: entityAtTile) ||
                   gameLoop.world.has(FluidProducerComponent.self, for: entityAtTile) ||
                   gameLoop.world.has(FluidConsumerComponent.self, for: entityAtTile) ||
                   gameLoop.world.has(FluidTankComponent.self, for: entityAtTile) ||
                   gameLoop.world.has(AccumulatorComponent.self, for: entityAtTile) ||
                   gameLoop.world.has(SolarPanelComponent.self, for: entityAtTile) ||
                   gameLoop.world.has(TurretComponent.self, for: entityAtTile) ||
                   gameLoop.world.has(RocketSiloComponent.self, for: entityAtTile) ||
                   gameLoop.world.has(PipeComponent.self, for: entityAtTile) {
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
            // Reset joystick state at the start of each new touch
            isJoystickActive = false
            dragStartPosition = screenPos

            // Haptic feedback for starting a pan gesture
            playHaptic(.lightImpact)

            // Check if touch started in UI area FIRST (for drag gestures)
            // Store the start position for drag gestures
            isUIDragging = false

            // Check if touch started within an open UI panel FIRST
            if let uiSystem = gameLoop.uiSystem {
                // Check if any panel is open that should consume drags
                if uiSystem.isAnyPanelOpen {
                    // When panels are open, disable joystick and other game controls
                    // Check if the drag starts within a panel that handles drags
                    // Try to handle drag immediately if it starts in a UI element
                    // This prevents game world interactions when dragging within UI panels
                    if uiSystem.handleDrag(from: screenPos, to: screenPos) {
                        isUIDragging = true
                        // Don't return here - let the gesture continue so .changed and .ended events fire
                        // But isUIDragging flag will prevent game world interactions in .changed state
                    }
                    // Skip joystick activation when panels are open
                    return
                }
            }

            // Check if touch started in joystick area (only when no panels are open)
            if let joystick = joystick {
                // Ensure joystick is up to date with current screen size
                joystick.updateScreenSize(renderer.screenSize)
                // Try to activate joystick
                if joystick.handleTouchBegan(at: screenPos, touchId: 0) {
                    isJoystickActive = true
                    // Exit build mode and clear selection when joystick is engaged
                    exitBuildMode()
                    gameLoop.uiSystem?.hud.selectedEntity = nil
                    return  // Prevent camera pan, but gesture continues for .changed/.ended
                } else {
                    // Touch is not on joystick - ensure joystick state is reset
                    isJoystickActive = false
                }
            } else {
                // No joystick available - ensure joystick state is reset
                isJoystickActive = false
            }

            
            // Not a joystick touch, start selection rectangle (instead of camera pan)
            if buildMode == .none || buildMode == .connectingInserter {
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
                
                // For belt/pole/pipe placement, set start tile if not already set
                if buildMode == .placing, let buildingId = selectedBuildingId,
                   buildingId.contains("belt") || buildingId.contains("pole") || buildingId.contains("pipe") {
                    if dragPlacementStartTile == nil {
                        let startTile = IntVector2(from: worldPos)
                        dragPlacementStartTile = startTile
                        dragPlacedTiles = []
                        dragPathPreview = [dragPlacementStartTile!]
                        let tileCenter = startTile.toVector2 + Vector2(0.5, 0.5)
                        dragPlacementOffset = buildingId.contains("pipe") ? (worldPos - tileCenter) : .zero
                        dragStartWorldPos = buildingId.contains("pipe") ? worldPos : nil
                        dragPlacedPositions = []
                        dragPathPreviewWorld = []
                        if buildingId.contains("pipe") {
                            dragPlacementNetworkId = gameLoop.fluidNetworkSystem.getNextNetworkId()
                            dragPlacedPipeEntities.removeAll()
                        }
                    }
                }
            }
            
        case .changed:
            // Handle joystick movement early to avoid unnecessary UI/drag checks
            if isJoystickActive {
                joystick?.handleTouchMoved(at: screenPos, touchId: 0)
                if buildMode != .none {
                    exitBuildMode()
                }
                if isSelecting {
                    isSelecting = false
                    selectionStartScreenPos = nil
                    selectionRect = nil
                }
                return
            }

            // Prioritize belt/pole/pipe drag placement when in placing mode
            // This needs to run before UI drag checks to prevent interference
            if buildMode == .placing, let buildingId = selectedBuildingId,
               (buildingId.contains("belt") || buildingId.contains("pole") || buildingId.contains("pipe")) {
                // Handle belt/pole/pipe placement during drag
                buildPreviewPosition = IntVector2(from: worldPos)
                handleDragPlacement(at: worldPos, gameLoop: gameLoop, buildingId: buildingId)
                return  // Drag placement consumes the gesture
            }
            
            // Update build preview position for other build modes
            if buildMode == .placing || buildMode == .moving {
                buildPreviewPosition = IntVector2(from: worldPos)
            }
            
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

            // Update selection rectangle (instead of camera panning)
            // Don't update selection rectangle if a UI panel is open or joystick is active
            if (buildMode == .none || buildMode == .connectingInserter) && isSelecting && !isJoystickActive && !(gameLoop.uiSystem?.isAnyPanelOpen ?? false), let startPos = selectionStartScreenPos {
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
            } else if buildMode != .none && buildMode != .connectingInserter {
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

            // Exit build mode if we were doing drag placement
            if buildMode == .placing && dragPlacementStartTile != nil {
                if let buildingId = selectedBuildingId, buildingId.contains("pipe") {
                    finalizePipeDragNetworkAssignment(gameLoop: gameLoop)
                }
                exitBuildMode()
                if let pendingPipeTankSelection = pendingPipeTankSelection {
                    promptPipeTankSelection(for: pendingPipeTankSelection, gameLoop: gameLoop)
                    self.pendingPipeTankSelection = nil
                }
            }

            // Handle selection rectangle end (only when not in build mode and no UI panel is open)
            // Don't process selection rectangle end if a UI panel is already open
            if (buildMode == .none || buildMode == .connectingInserter) && isSelecting && !(gameLoop.uiSystem?.isAnyPanelOpen ?? false), let rect = selectionRect {
                print("InputManager: Processing selection rectangle: \(rect)")
                isSelecting = false
                selectionStartScreenPos = nil

                // Get all entities within the world rectangle
                let selectedEntities = gameLoop.world.getAllEntitiesInWorldRect(rect)
                print("InputManager: Found \(selectedEntities.count) entities in selection rectangle")
                
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
                    let hasFluidProducer = gameLoop.world.has(FluidProducerComponent.self, for: entity)
                    let hasAccumulator = gameLoop.world.has(AccumulatorComponent.self, for: entity)
                    let hasSolarPanel = gameLoop.world.has(SolarPanelComponent.self, for: entity)
                    let hasTurret = gameLoop.world.has(TurretComponent.self, for: entity)
                    let hasRocketSilo = gameLoop.world.has(RocketSiloComponent.self, for: entity)
                    let hasPipe = gameLoop.world.has(PipeComponent.self, for: entity)

                    let isInteractable = hasFurnace || hasAssembler || hasMiner || hasChest || hasLab || hasGenerator || hasPole || hasBelt || hasInserter || hasFluidProducer || hasAccumulator || hasSolarPanel || hasTurret || hasRocketSilo || hasPipe


                    return isInteractable
                }

                // Debug: Count interactable entities by type
                let assemblerCount = interactableEntities.filter { gameLoop.world.has(AssemblerComponent.self, for: $0) }.count
                let furnaceCount = interactableEntities.filter { gameLoop.world.has(FurnaceComponent.self, for: $0) }.count
                if assemblerCount > 0 || furnaceCount > 0 {
                    print("InputManager: Found \(assemblerCount) assemblers and \(furnaceCount) furnaces in \(interactableEntities.count) total interactable entities")
                }
                
                // Clear selection rectangle
                selectionRect = nil
                
                // Handle inserter connection mode
                if buildMode == .connectingInserter {
                    // Filter entities to only those adjacent to the inserter
                    guard let inserterEntity = inserterToConfigure,
                          let inserterPos = gameLoop.world.get(PositionComponent.self, for: inserterEntity) else {
                        return
                    }
                    
                    let adjacentEntities = interactableEntities.filter { entity in
                        if let entityPos = gameLoop.world.get(PositionComponent.self, for: entity) {
                            // For multi-tile buildings, check if any tile is adjacent
                            if let sprite = gameLoop.world.get(SpriteComponent.self, for: entity) {
                                let width = Int(ceil(sprite.size.x))
                                let height = Int(ceil(sprite.size.y))
                                for dy in 0..<height {
                                    for dx in 0..<width {
                                        let tileX = entityPos.tilePosition.x + Int32(dx)
                                        let tileY = entityPos.tilePosition.y + Int32(dy)
                                        let distance = abs(tileX - inserterPos.tilePosition.x) + abs(tileY - inserterPos.tilePosition.y)
                                        if distance <= 2 {
                                            return true
                                        }
                                    }
                                }
                                return false
                            } else {
                                let distance = abs(entityPos.tilePosition.x - inserterPos.tilePosition.x) + abs(entityPos.tilePosition.y - inserterPos.tilePosition.y)
                                return distance <= 2
                            }
                        }
                        return false
                    }
                    
                    // Also check for belts at positions within the rectangle
                    var beltPositions: [IntVector2] = []
                    let rectMinTileX = Int32(floor(rect.minX))
                    let rectMaxTileX = Int32(ceil(rect.maxX))
                    let rectMinTileY = Int32(floor(rect.minY))
                    let rectMaxTileY = Int32(ceil(rect.maxY))
                    for x in rectMinTileX...rectMaxTileX {
                        for y in rectMinTileY...rectMaxTileY {
                            let pos = IntVector2(x: x, y: y)
                            let distance = abs(pos.x - inserterPos.tilePosition.x) + abs(pos.y - inserterPos.tilePosition.y)
                            if distance <= 2 {
                                let entitiesAtPos = gameLoop.world.getAllEntitiesAt(position: pos)
                                if entitiesAtPos.contains(where: { gameLoop.world.has(BeltComponent.self, for: $0) }) {
                                    beltPositions.append(pos)
                                }
                            }
                        }
                    }
                    
                    // Show entity selection dialog if multiple entities or belt positions
                    if adjacentEntities.count + beltPositions.count > 1 {
                        // Create a combined list - we'll handle belt positions specially
                        gameLoop.uiSystem?.showEntitySelectionDialog(entities: adjacentEntities) { [weak self] selectedEntity in
                            self?.handleInserterConnectionEntitySelected(entity: selectedEntity, gameLoop: gameLoop)
                        }
                    } else if let entity = adjacentEntities.first {
                        handleInserterConnectionEntitySelected(entity: entity, gameLoop: gameLoop)
                    } else if let beltPos = beltPositions.first {
                        handleInserterConnectionPositionSelected(position: beltPos, gameLoop: gameLoop)
                    }
                } else {
                    // Normal entity selection
                    // Show entity selection dialog if multiple entities, otherwise select directly
                    if interactableEntities.count > 1 {
                        gameLoop.uiSystem?.showEntitySelectionDialog(entities: interactableEntities) { [weak self] selectedEntity in
                            self?.selectEntity(selectedEntity, gameLoop: gameLoop, isDoubleTap: false)
                        }
                    } else if let entity = interactableEntities.first {
                        selectEntity(entity, gameLoop: gameLoop, isDoubleTap: false)
                    }
                }
            } else {
                // Clear selection state if we were selecting but are now in build mode
                if isSelecting {
                    isSelecting = false
                    selectionStartScreenPos = nil
                    selectionRect = nil
                }
            }
            
            // Keep in build mode after placement (including belts/poles)
            // Users can exit via the build mode button or other means
            if buildMode == .placing {
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

            // Haptic feedback for starting pinch zoom
            playHaptic(.lightImpact)
            
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
        // Check if this is a unit - handle differently for RTS-style control
        if gameLoop.world.has(UnitComponent.self, for: entity) {
            selectUnit(entity, gameLoop: gameLoop)
            return
        }

        // Select the entity (normal building/machine behavior)
        // First set InputManager's selectedEntity, then notify via callback (which updates HUD)
        // This ensures both are in sync
        selectedEntity = entity

        // Show tooltip with entity icon
        if let tooltipText = getEntityTooltipText(entity: entity, gameLoop: gameLoop) {
            onTooltipWithEntity?(tooltipText, entity)
        }

        // Double-check that HUD got the same entity (safety check)
        if let hudEntity = gameLoop.uiSystem?.hud.selectedEntity {
            if hudEntity.id != entity.id || hudEntity.generation != entity.generation {
                // Force update HUD to match InputManager
                gameLoop.uiSystem?.hud.selectedEntity = entity
            }
        }

        // Notify listeners about entity selection
        onEntitySelected?(entity)
    }

    private func handleEntitySelection(at screenPos: Vector2, worldPos: Vector2, tilePos: IntVector2, gameLoop: GameLoop, isDoubleTap: Bool = false) {
        // Get all entities at this position
        let allEntities = gameLoop.world.getAllEntitiesAt(position: tilePos)
        
        // Filter to only interactable entities (buildings and units)
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
            let hasFluidProducer = gameLoop.world.has(FluidProducerComponent.self, for: entity)
            let hasFluidConsumer = gameLoop.world.has(FluidConsumerComponent.self, for: entity)
            let hasFluidTank = gameLoop.world.has(FluidTankComponent.self, for: entity)
            let hasAccumulator = gameLoop.world.has(AccumulatorComponent.self, for: entity)
            let hasSolarPanel = gameLoop.world.has(SolarPanelComponent.self, for: entity)
            let hasTurret = gameLoop.world.has(TurretComponent.self, for: entity)
            let hasRocketSilo = gameLoop.world.has(RocketSiloComponent.self, for: entity)
            let hasPipe = gameLoop.world.has(PipeComponent.self, for: entity)
            let hasUnit = gameLoop.world.has(UnitComponent.self, for: entity)

            let isInteractable = hasFurnace || hasAssembler || hasMiner || hasChest || hasLab || hasGenerator || hasPole || hasBelt || hasInserter || hasFluidProducer || hasFluidConsumer || hasFluidTank || hasAccumulator || hasSolarPanel || hasTurret || hasRocketSilo || hasPipe || hasUnit

            return isInteractable
        }

        // Debug: Log what we found
        if !interactableEntities.isEmpty {
            print("InputManager: Found \(interactableEntities.count) interactable entities at \(tilePos)")
        }
        
        // If multiple interactable entities, show selection dialog
        if interactableEntities.count > 1 {
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
            let hasFluidProducer = gameLoop.world.has(FluidProducerComponent.self, for: entityAtTile)
            let hasFluidConsumer = gameLoop.world.has(FluidConsumerComponent.self, for: entityAtTile)
            let hasFluidTank = gameLoop.world.has(FluidTankComponent.self, for: entityAtTile)
            let hasAccumulator = gameLoop.world.has(AccumulatorComponent.self, for: entityAtTile)
            let hasSolarPanel = gameLoop.world.has(SolarPanelComponent.self, for: entityAtTile)
            let hasTurret = gameLoop.world.has(TurretComponent.self, for: entityAtTile)
            let hasRocketSilo = gameLoop.world.has(RocketSiloComponent.self, for: entityAtTile)
            let hasPipe = gameLoop.world.has(PipeComponent.self, for: entityAtTile)
            let hasUnit = gameLoop.world.has(UnitComponent.self, for: entityAtTile)

            // Prioritize units for selection (for RTS-style control)
            if hasUnit {
                closestEntity = entityAtTile
            } else if hasInserter {
                closestEntity = entityAtTile
            } else if hasFurnace || hasAssembler || hasMiner || hasChest || hasLab || hasGenerator || hasPole || hasBelt || hasFluidProducer || hasFluidConsumer || hasFluidTank || hasAccumulator || hasSolarPanel || hasTurret || hasRocketSilo || hasPipe {
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
                let hasFluidProducer = gameLoop.world.has(FluidProducerComponent.self, for: entity)
                let hasAccumulator = gameLoop.world.has(AccumulatorComponent.self, for: entity)
                let hasSolarPanel = gameLoop.world.has(SolarPanelComponent.self, for: entity)
                let hasTurret = gameLoop.world.has(TurretComponent.self, for: entity)
                let hasRocketSilo = gameLoop.world.has(RocketSiloComponent.self, for: entity)
                let hasPipe = gameLoop.world.has(PipeComponent.self, for: entity)

                if hasFurnace || hasAssembler || hasMiner || hasChest || hasLab || hasGenerator || hasPole || hasBelt || hasInserter || hasFluidProducer || hasAccumulator || hasSolarPanel || hasTurret || hasRocketSilo || hasPipe {
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
                // Select the nearest entity
                selectedEntity = nearest
                onEntitySelected?(nearest)
                return
            }
            
            // No entity found at all, check for resource to mine manually
            if let resource = gameLoop.chunkManager.getResource(at: tilePos), !resource.isEmpty {
                // Check if player can accept the item
                guard let player = gameLoop.player else { return }
                if player.inventory.canAccept(itemId: resource.type.outputItem) {
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
                            if let gameLoop = gameLoop,
                               let player = gameLoop.player,
                               let itemDef = gameLoop.itemRegistry.get(itemId) {
                                player.inventory.add(itemId: itemId, count: mined, maxStack: itemDef.stackSize)
                            }
                        }
                    }
                } else {
                    onTooltip?("Inventory full, cannot mine")
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
            guard let player = gameLoop.player else { return }
            if !player.inventory.has(items: buildingDef.cost) {
                // Show missing items
                let missingItems = buildingDef.cost.filter { !player.inventory.has(items: [$0]) }
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
                // Exit build mode after placing a building
                exitBuildMode()
                // Play placement sound/feedback
                AudioManager.shared.playPlaceSound()

                // Select the newly placed entity
                if let placedEntity = gameLoop.world.getEntityAt(position: tilePos) {
                    selectedEntity = placedEntity
                    onEntitySelected?(placedEntity)
                }
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

                // Haptic feedback for rotation
                playHaptic(.lightImpact)
            }
            
        default:
            break
        }
    }

    // MARK: - Flow State Gesture Handlers

    @objc private func handleSwipeUp(_ recognizer: UISwipeGestureRecognizer) {
        guard let gameLoop = gameLoop else { return }
        playHaptic(.lightImpact)

        // Quick zoom in
        if let renderer = renderer {
            let currentZoom = renderer.camera.zoom
            let newZoom = min(currentZoom * 1.5, renderer.camera.maxZoom)
            renderer.camera.setZoom(newZoom, animated: true)
        }
    }

    @objc private func handleSwipeDown(_ recognizer: UISwipeGestureRecognizer) {
        guard let gameLoop = gameLoop else { return }
        playHaptic(.lightImpact)

        // Quick zoom out
        if let renderer = renderer {
            let currentZoom = renderer.camera.zoom
            let newZoom = max(currentZoom / 1.5, renderer.camera.minZoom)
            renderer.camera.setZoom(newZoom, animated: true)
        }
    }

    @objc private func handleSwipeLeft(_ recognizer: UISwipeGestureRecognizer) {
        guard let gameLoop = gameLoop else { return }
        playHaptic(.mediumImpact)

        // Cycle through selected units
        cycleSelectedUnits()
    }

    @objc private func handleSwipeRight(_ recognizer: UISwipeGestureRecognizer) {
        guard let gameLoop = gameLoop else { return }
        playHaptic(.mediumImpact)

        // Cycle through selected buildings
        cycleSelectedBuildings()
    }

    @objc private func handleTwoFingerTap(_ recognizer: UITapGestureRecognizer) {
        guard let gameLoop = gameLoop else { return }
        playHaptic(.heavyImpact)

        // Emergency stop all units
        for unitEntity in selectedUnits {
            if let unit = gameLoop.world.get(UnitComponent.self, for: unitEntity) {
                unit.commandQueue.removeAll()
                unit.currentCommand = nil
                print("InputManager: Emergency stop issued to unit \(unitEntity)")
            }
        }

        // Provide haptic feedback
        playHaptic(.heavyImpact)
    }

    @objc private func handleThreeFingerTap(_ recognizer: UITapGestureRecognizer) {
        guard gameLoop != nil else { return }
        playHaptic(.rigidImpact)

        // Pause/unpause game
        let wasPaused = Time.shared.isPaused
        if wasPaused {
            Time.shared.isPaused = false
            print("InputManager: Game resumed")
        } else {
            Time.shared.isPaused = true
            print("InputManager: Game paused")
        }
    }

    // MARK: - Motion Handlers

    private func handleAccelerometer(data: CMAcceleration) {
        let currentTime = Date().timeIntervalSince1970

        // Shake detection
        if let lastAccel = lastAcceleration {
            let deltaX = abs(data.x - lastAccel.x)
            let deltaY = abs(data.y - lastAccel.y)
            let deltaZ = abs(data.z - lastAccel.z)

            if (deltaX > shakeThreshold || deltaY > shakeThreshold || deltaZ > shakeThreshold) &&
               (currentTime - lastShakeTime > 0.5) {
                lastShakeTime = currentTime
                handleDeviceShake()
            }
        }
        lastAcceleration = data

        // Subtle camera tilt based on device orientation
        adjustCameraTilt(acceleration: data)
    }

    private func handleGyroscope(data: CMRotationRate) {
        // Could use gyroscope for more precise tilt control
        // For now, accelerometer is sufficient
    }

    private func handleDeviceShake() {
        guard let gameLoop = gameLoop else { return }
        playHaptic(.notification(.error))

        // Shake to deselect all
        selectedUnits.removeAll()
        selectedEntity = nil
        onEntitySelected?(nil)
        print("InputManager: All units deselected due to shake")
    }

    private func adjustCameraTilt(acceleration: CMAcceleration) {
        guard let renderer = renderer else { return }

        // Subtle camera movement based on device tilt
        let tiltSensitivity: Float = 0.01
        let tiltX = Float(acceleration.x) * tiltSensitivity
        let tiltY = Float(acceleration.y) * tiltSensitivity

        // Apply small camera offset based on tilt
        let currentPos = renderer.camera.position
        let newPos = currentPos + Vector2(x: tiltX, y: tiltY)
        renderer.camera.position = newPos
    }

    // MARK: - Haptic Feedback

    private func playHaptic(_ pattern: HapticPattern) {
        let currentTime = Date().timeIntervalSince1970
        guard currentTime - lastHapticTime > hapticCooldown else { return }
        lastHapticTime = currentTime

        guard let engine = hapticEngine else { return }

        do {
            var events: [CHHapticEvent] = []

            switch pattern {
            case .lightImpact:
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0))

            case .mediumImpact:
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0))

            case .heavyImpact:
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0))

            case .rigidImpact:
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0))

            case .notification(let type):
                switch type {
                case .success:
                    let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8)
                    let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0))
                case .warning:
                    let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)
                    let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0))
                case .error:
                    let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9)
                    let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                    events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0))
                    events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0.1))
                }

            case .continuous(let duration):
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: duration))
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)

        } catch {
            print("InputManager: Failed to play haptic pattern: \(error)")
        }
    }

    // MARK: - Helper Methods
    
    func getEntityTooltipText(entity: Entity, gameLoop: GameLoop?) -> String? {
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
            let maxOutputText = String(format: "%.0f", generator.powerOutput)
            let statusText = generator.currentOutput > 0 ? "Active" : "Inactive"
            tooltipLines.append("Power: \(outputText)/\(maxOutputText) kW")
            tooltipLines.append("Status: \(statusText)")
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

        // Add pipe/fluid information
        if let pipe = world.get(PipeComponent.self, for: entity) {
            if let fluidType = pipe.fluidType {
                let fluidAmountText = String(format: "%.1f", pipe.fluidAmount)
                let capacityText = String(format: "%.0f", pipe.maxCapacity)
                let fillPercent = Int((pipe.fluidAmount / pipe.maxCapacity) * 100)
                tooltipLines.append("Fluid: \(fluidType)")
                tooltipLines.append("Amount: \(fluidAmountText)/\(capacityText) L (\(fillPercent)%)")
            } else {
                tooltipLines.append("Empty")
            }

            let flowText = String(format: "%.2f", abs(pipe.flowRate))
            if abs(pipe.flowRate) > 0.01 {
                tooltipLines.append("Flow: \(flowText) L/s")
            } else {
                tooltipLines.append("No flow")
            }

            let connectionCount = pipe.connections.count
            tooltipLines.append("Connections: \(connectionCount)")

            if let networkId = pipe.networkId {
                tooltipLines.append("Network: \(networkId)")
            }
        }

        // Add fluid producer information
        if let producer = world.get(FluidProducerComponent.self, for: entity) {
            let productionText = String(format: "%.1f", producer.productionRate)
            let currentText = String(format: "%.2f", producer.currentProduction * 60.0)
            let stateText = producer.isActive ? "Active" : "Inactive"
            tooltipLines.append("Producing: \(producer.outputType)")
            tooltipLines.append("Rate: \(productionText) L/s")
            tooltipLines.append("Current: \(currentText) L/min")
            tooltipLines.append("Status: \(stateText)")

            let connectionCount = producer.connections.count
            tooltipLines.append("Connections: \(connectionCount)")
            let networkText = producer.networkId.map { String($0) } ?? "-"
            tooltipLines.append("Network: \(networkText)")
        }

        // Add fluid consumer information
        if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
            if let inputType = consumer.inputType {
                let consumptionText = String(format: "%.1f", consumer.consumptionRate)
                let currentText = String(format: "%.2f", consumer.currentConsumption * 60.0)
                tooltipLines.append("Consuming: \(inputType)")
                tooltipLines.append("Rate: \(consumptionText) L/s")
                tooltipLines.append("Current: \(currentText) L/min")
            }

            let connectionCount = consumer.connections.count
            tooltipLines.append("Connections: \(connectionCount)")
            let networkText = consumer.networkId.map { String($0) } ?? "-"
            tooltipLines.append("Network: \(networkText)")
        }

        // Add fluid tank information
        if let tank = world.get(FluidTankComponent.self, for: entity) {
            let totalCapacity = tank.maxCapacity
            var totalFluid: Float = 0
            var fluidTypes = Set<FluidType>()

            for stack in tank.tanks {
                totalFluid += stack.amount
                fluidTypes.insert(stack.type)
            }

            if !tank.tanks.isEmpty {
                let fillPercent = Int((totalFluid / totalCapacity) * 100)
                let fluidList = fluidTypes.map { "\($0)" }.joined(separator: ", ")
                tooltipLines.append("Fluids: \(fluidList)")
                tooltipLines.append("Capacity: \(totalCapacity) L (\(fillPercent)%)")
            } else {
                tooltipLines.append("Empty tank")
                tooltipLines.append("Capacity: \(totalCapacity) L")
            }

            let connectionCount = tank.connections.count
            tooltipLines.append("Connections: \(connectionCount)")
            let networkText = tank.networkId.map { String($0) } ?? "-"
            tooltipLines.append("Network: \(networkText)")
        }

        if let pump = world.get(FluidPumpComponent.self, for: entity) {
            let connectionCount = pump.connections.count
            tooltipLines.append("Connections: \(connectionCount)")
            let networkText = pump.networkId.map { String($0) } ?? "-"
            tooltipLines.append("Network: \(networkText)")
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
        let scale = Float(view.contentScaleFactor)
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
        dragPlacementOffset = nil
        dragStartWorldPos = nil
        dragPlacedPositions = []
        dragPathPreviewWorld = []
        dragPlacementNetworkId = nil
        dragPlacedPipeEntities.removeAll()
        // Clear selection rectangle state when entering build mode
        isSelecting = false
        selectionStartScreenPos = nil
        selectionRect = nil

        // Close all UI panels to reset state
        gameLoop?.uiSystem?.closeAllPanels()

        // Trigger layout update to ensure coordinate system is correct
        view?.setNeedsLayout()
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
        dragPlacementStartTile = nil
        dragPlacedTiles = []
        dragPathPreview = []
        dragPlacementOffset = nil
        dragStartWorldPos = nil
        dragPlacedPositions = []
        dragPathPreviewWorld = []
        dragPlacementNetworkId = nil
        dragPlacedPipeEntities.removeAll()
        entityToMove = nil
        // Clear inserter connection state
        inserterToConfigure = nil
        isConnectingInput = false
        // Clear selection rectangle state when exiting build mode
        isSelecting = false
        selectionStartScreenPos = nil
        selectionRect = nil
    }
    
    func enterInserterConnectionMode(inserter: Entity, isInput: Bool) {
        buildMode = .connectingInserter
        inserterToConfigure = inserter
        isConnectingInput = isInput
        onTooltip?(isInput ? "Tap or drag to select entity/belt for input connection" : "Tap or drag to select entity/belt for output connection")
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
        
        let inserterTile = inserterPos.tilePosition
        
        // Check all tiles within 1 tile (including diagonals) from inserter to find entities
        // This ensures we catch multi-tile entities even if the tapped tile isn't adjacent
        var allFoundEntities: Set<Entity> = []
        
        // Check all adjacent tiles (including diagonals)
        for dy in -1...1 {
            for dx in -1...1 {
                // Skip center tile (that's the inserter itself)
                if dx == 0 && dy == 0 { continue }
                
                let checkTile = IntVector2(x: inserterTile.x + Int32(dx), y: inserterTile.y + Int32(dy))
                let entitiesAtTile = gameLoop.world.getAllEntitiesAt(position: checkTile)
                for entity in entitiesAtTile {
                    allFoundEntities.insert(entity)
                }
            }
        }
        
        // Also check the tapped position (in case user taps on a tile 2+ away but still valid)
        // but only if it's within reasonable range
        let distance = abs(tilePos.x - inserterTile.x) + abs(tilePos.y - inserterTile.y)
        if distance <= 2 {
            let entitiesAtTappedPos = gameLoop.world.getAllEntitiesAt(position: tilePos)
            for entity in entitiesAtTappedPos {
                allFoundEntities.insert(entity)
            }
        } else {
            // Tapped tile is too far away
            onTooltip?("Target must be adjacent to inserter")
            return
        }
        
        // Filter to valid targets (belts, miners, machines, boilers, etc.)
        // For multi-tile entities, verify that at least one tile is within 1 tile of the inserter
        let validEntities: [Entity] = Array(allFoundEntities).filter { entity in
            let hasBelt = gameLoop.world.has(BeltComponent.self, for: entity)
            let hasMiner = gameLoop.world.has(MinerComponent.self, for: entity)
            let hasFurnace = gameLoop.world.has(FurnaceComponent.self, for: entity)
            let hasAssembler = gameLoop.world.has(AssemblerComponent.self, for: entity)
            let hasChest = gameLoop.world.has(ChestComponent.self, for: entity)
            let hasGenerator = gameLoop.world.has(GeneratorComponent.self, for: entity)
            let isValidType = hasBelt || hasMiner || hasFurnace || hasAssembler || hasChest || hasGenerator
            
            guard isValidType else { return false }
            
            // For all entities (single or multi-tile), verify at least one tile is within 1 tile of inserter
            guard let entityPos = gameLoop.world.get(PositionComponent.self, for: entity) else { return false }
            let entityOrigin = entityPos.tilePosition
            
            // Get entity size from sprite component
            let sprite = gameLoop.world.get(SpriteComponent.self, for: entity)
            let width = sprite != nil ? Int32(ceil(sprite!.size.x)) : 1
            let height = sprite != nil ? Int32(ceil(sprite!.size.y)) : 1
            
            // Check if any tile of this entity is within 1 tile of the inserter
            for y in entityOrigin.y..<(entityOrigin.y + height) {
                for x in entityOrigin.x..<(entityOrigin.x + width) {
                    let entityTile = IntVector2(x: x, y: y)
                    let tileDistance = abs(entityTile.x - inserterTile.x) + abs(entityTile.y - inserterTile.y)
                    if tileDistance <= 1 {
                        return true  // Found at least one tile within range
                    }
                }
            }
            
            return false  // No tiles within range
        }
        
        // If multiple entities, show selection dialog
        if validEntities.count > 1 {
            gameLoop.uiSystem?.showEntitySelectionDialog(entities: validEntities) { [weak self] selectedEntity in
                self?.handleInserterConnectionEntitySelected(entity: selectedEntity, gameLoop: gameLoop)
            }
        } else if let targetEntity = validEntities.first {
            // Single entity, connect directly
            handleInserterConnectionEntitySelected(entity: targetEntity, gameLoop: gameLoop)
        } else {
            // Check if there's a belt at the tapped position (might not be in validEntities if it's hidden under a building)
            let entitiesAtTappedPos = gameLoop.world.getAllEntitiesAt(position: tilePos)
            let hasBelt = entitiesAtTappedPos.contains { gameLoop.world.has(BeltComponent.self, for: $0) }
            
            if hasBelt {
                handleInserterConnectionPositionSelected(position: tilePos, gameLoop: gameLoop)
            } else {
                onTooltip?("No valid target at this position")
            }
        }
    }
    
    private func handleInserterConnectionEntitySelected(entity: Entity, gameLoop: GameLoop) {
        guard let inserterEntity = inserterToConfigure else {
            exitBuildMode()
            return
        }
        
        if isConnectingInput {
            if gameLoop.setInserterConnection(entity: inserterEntity, inputTarget: entity, inputPosition: nil) {
                onTooltip?("Input connection set")
                exitBuildMode()
            } else {
                onTooltip?("Failed to set input connection")
            }
        } else {
            if gameLoop.setInserterConnection(entity: inserterEntity, outputTarget: entity, outputPosition: nil) {
                onTooltip?("Output connection set")
                exitBuildMode()
            } else {
                onTooltip?("Failed to set output connection")
            }
        }
    }
    
    private func handleInserterConnectionPositionSelected(position: IntVector2, gameLoop: GameLoop) {
        guard let inserterEntity = inserterToConfigure else {
            exitBuildMode()
            return
        }
        
        if isConnectingInput {
            if gameLoop.setInserterConnection(entity: inserterEntity, inputTarget: nil, inputPosition: position) {
                onTooltip?("Input connection set")
                exitBuildMode()
            } else {
                onTooltip?("Failed to set input connection")
            }
        } else {
            if gameLoop.setInserterConnection(entity: inserterEntity, outputTarget: nil, outputPosition: position) {
                onTooltip?("Output connection set")
                exitBuildMode()
            } else {
                onTooltip?("Failed to set output connection")
            }
        }
    }
    
    func enterMoveMode(entity: Entity) {
        buildMode = .moving
        entityToMove = entity
        selectedBuildingId = nil
        buildPreviewPosition = nil
        dragPlacementStartTile = nil
        dragPlacedTiles = []
        dragPathPreview = []
        dragPlacementOffset = nil
        dragStartWorldPos = nil
        dragPlacedPositions = []
        dragPathPreviewWorld = []
        dragPlacementNetworkId = nil
        dragPlacedPipeEntities.removeAll()
        // Clear selection rectangle state when entering move mode
        isSelecting = false
        selectionStartScreenPos = nil
        selectionRect = nil
    }
    
    // MARK: - Belt/Pipe Placement
    
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
        
        let isBelt = buildingDef.type == .belt
        let isPipe = buildingDef.type == .pipe

        if isPipe {
            handlePipeDragPlacement(at: worldPos, gameLoop: gameLoop, buildingId: buildingId)
            return
        }

        let currentTile = IntVector2(from: worldPos)

        // Calculate path from start to current tile using Manhattan distance
        let path = calculateBeltPath(from: startTile, to: currentTile)

        // Update preview
        dragPathPreview = path
        
        // Place items along the path that haven't been placed yet
        for (index, pos) in path.enumerated() {
            // Skip if already placed
            if dragPlacedTiles.contains(pos) {
                continue
            }
            
            // Check if we can place here and have inventory
            guard gameLoop.canPlaceBuilding(buildingId, at: pos, direction: .north),
                  let player = gameLoop.player,
                  player.inventory.has(items: buildingDef.cost) else {
                continue
            }
            
            // Determine direction - belts and pipes use directional placement
            let direction: Direction
            var pipeShape: PipeShape? = nil
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
            } else if isPipe {
                let segmentInfo = pipeSegmentInfo(at: index, path: path, fallbackDirection: buildDirection)
                direction = segmentInfo.direction
                pipeShape = segmentInfo.shape
            } else {
                // Poles don't need direction
                direction = .north
            }
            
            // Place the building (placeBuilding already removes items from inventory)
            let placementOffset = isPipe ? (dragPlacementOffset ?? .zero) : .zero
            if isPipe && !gameLoop.canPlacePipe(at: pos, direction: direction, offset: placementOffset) {
                continue
            }
            if gameLoop.placeBuilding(buildingId, at: pos, direction: direction, offset: placementOffset) {
                dragPlacedTiles.insert(pos)

                if isPipe, let placedEntity = gameLoop.world.getEntityAt(position: pos),
                   let pipe = gameLoop.world.get(PipeComponent.self, for: placedEntity),
                   let pipeShape = pipeShape {
                    pipe.direction = direction
                    pipe.shape = pipeShape
                    pipe.allowedDirections = PipeComponent.allowedDirections(for: pipeShape, direction: direction)
                    gameLoop.world.add(pipe, to: placedEntity)
                    gameLoop.fluidNetworkSystem.markEntityDirty(placedEntity, connectionsDirty: true)
                }

                if isPipe {
                    updatePipeShapeForPlacement(at: pos, fallbackDirection: direction, gameLoop: gameLoop)
                }

                // Don't select entities during drag placement to avoid UI confusion
            }
        }
    }

    private func handlePipeDragPlacement(at worldPos: Vector2, gameLoop: GameLoop, buildingId: String) {
        guard let startWorldPos = dragStartWorldPos else { return }
        let delta = worldPos - startWorldPos
        let distance = (delta.x * delta.x + delta.y * delta.y).squareRoot()
        let spacing: Float = 0.33  // Allow ~3 pipes per tile
        let steps = max(1, Int(floor(distance / spacing)))
        let directionVector = distance > 0 ? delta / distance : Vector2(0, 0)

        dragPathPreviewWorld = []
        dragPathPreview = []

        for step in 0...steps {
            let stepDistance = Float(step) * spacing
            let pipeWorldPos = startWorldPos + directionVector * stepDistance
            dragPathPreviewWorld.append(pipeWorldPos)

            if dragPlacedPositions.contains(where: { $0.distance(to: pipeWorldPos) < spacing * 0.4 }) {
                continue
            }

            let tilePos = IntVector2(from: pipeWorldPos)
            let tileCenter = tilePos.toVector2 + Vector2(0.5, 0.5)
            let placementOffset = pipeWorldPos - tileCenter

            guard gameLoop.canPlaceBuilding(buildingId, at: tilePos, direction: .north) else {
                continue
            }
            guard let player = gameLoop.player,
                  player.inventory.has(items: gameLoop.buildingRegistry.get(buildingId)?.cost ?? []) else {
                continue
            }

            let direction = cardinalDirection(from: directionVector, fallback: buildDirection)
            if !gameLoop.canPlacePipe(at: tilePos, direction: direction, offset: placementOffset) {
                continue
            }
            if gameLoop.placeBuilding(buildingId, at: tilePos, direction: direction, offset: placementOffset) {
                dragPlacedPositions.append(pipeWorldPos)

                if let placedEntity = pipeEntity(at: tilePos, offset: placementOffset, gameLoop: gameLoop),
                   let pipe = gameLoop.world.get(PipeComponent.self, for: placedEntity) {
                    let pipeShape = PipeShape.straight
                    pipe.direction = direction
                    pipe.shape = pipeShape
                    pipe.allowedDirections = PipeComponent.allowedDirections(for: pipeShape, direction: direction)
                    gameLoop.world.add(pipe, to: placedEntity)
                    gameLoop.fluidNetworkSystem.markEntityDirty(placedEntity, connectionsDirty: true)
                    dragPlacedPipeEntities.insert(placedEntity)
                    if pipeNeedsTankSelection(placedEntity, gameLoop: gameLoop) {
                        pendingPipeTankSelection = placedEntity
                    }
                }

                updatePipeShapeForPlacement(at: tilePos, fallbackDirection: direction, gameLoop: gameLoop)
            }
        }
    }

    private func cardinalDirection(from vector: Vector2, fallback: Direction) -> Direction {
        if abs(vector.x) >= abs(vector.y) {
            return vector.x >= 0 ? .east : .west
        }
        if abs(vector.y) > 0 {
            return vector.y >= 0 ? .north : .south
        }
        return fallback
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

    private func pipeSegmentInfo(at index: Int, path: [IntVector2], fallbackDirection: Direction) -> (direction: Direction, shape: PipeShape) {
        if path.count <= 1 {
            return (fallbackDirection, .straight)
        }

        let current = path[index]
        let hasPrev = index > 0
        let hasNext = index + 1 < path.count
        let dirToPrev = hasPrev ? direction(from: current, to: path[index - 1]) : nil
        let dirToNext = hasNext ? direction(from: current, to: path[index + 1]) : nil

        if let dirToPrev = dirToPrev, let dirToNext = dirToNext {
            if dirToPrev == dirToNext.opposite {
                return (dirToNext, .straight)
            }
            if dirToNext == dirToPrev.clockwise {
                return (dirToPrev, .corner)
            }
            if dirToPrev == dirToNext.clockwise {
                return (dirToNext, .corner)
            }
            return (dirToNext, .corner)
        }

        if let dir = dirToNext ?? dirToPrev {
            return (dir, .straight)
        }

        return (fallbackDirection, .straight)
    }

    private func direction(from start: IntVector2, to end: IntVector2) -> Direction {
        let offset = end - start
        if offset.x == 0 && offset.y == 1 { return .north }
        if offset.x == 1 && offset.y == 0 { return .east }
        if offset.x == 0 && offset.y == -1 { return .south }
        if offset.x == -1 && offset.y == 0 { return .west }
        return .north
    }

    private func updatePipeShapeForPlacement(at position: IntVector2, fallbackDirection: Direction, gameLoop: GameLoop) {
        var queue: [IntVector2] = [position]
        var visited: Set<IntVector2> = []

        while let current = queue.first {
            queue.removeFirst()
            if visited.contains(current) {
                continue
            }
            visited.insert(current)

            let currentFallback = currentPipeDirection(at: current, fallback: fallbackDirection, gameLoop: gameLoop)
            updatePipeShape(at: current, fallbackDirection: currentFallback, gameLoop: gameLoop)

            for direction in Direction.allCases {
                let neighborPos = current + direction.intVector
                if let _ = pipeEntity(at: neighborPos, gameLoop: gameLoop), !visited.contains(neighborPos) {
                    queue.append(neighborPos)
                }
            }
        }
    }

    private func updatePipeShape(at position: IntVector2, fallbackDirection: Direction, gameLoop: GameLoop) {
        guard let entity = pipeEntity(at: position, gameLoop: gameLoop),
              let pipe = gameLoop.world.get(PipeComponent.self, for: entity) else {
            return
        }

        var neighborDirections: Set<Direction> = []
        for direction in Direction.allCases {
            let neighborPos = position + direction.intVector
            if isFluidEntityOccupying(tile: neighborPos, gameLoop: gameLoop) {
                neighborDirections.insert(direction)
            }
        }

        let shapeInfo = pipeShapeAndDirection(for: neighborDirections, fallbackDirection: fallbackDirection)
        pipe.direction = shapeInfo.direction
        pipe.shape = shapeInfo.shape
        pipe.allowedDirections = PipeComponent.allowedDirections(for: shapeInfo.shape, direction: shapeInfo.direction)
        gameLoop.world.add(pipe, to: entity)
        gameLoop.fluidNetworkSystem.markEntityDirty(entity, connectionsDirty: true)
    }

    private func pipeShapeAndDirection(for directions: Set<Direction>, fallbackDirection: Direction) -> (shape: PipeShape, direction: Direction) {
        let count = directions.count
        if count == 0 {
            return (.straight, fallbackDirection)
        }
        if count == 1, let dir = directions.first {
            return (.end, dir)
        }
        if count == 2 {
            let dirs = Array(directions)
            if dirs[0] == dirs[1].opposite {
                return (.straight, dirs[0])
            }
            if dirs[1] == dirs[0].clockwise {
                return (.corner, dirs[0])
            }
            if dirs[0] == dirs[1].clockwise {
                return (.corner, dirs[1])
            }
            return (.corner, fallbackDirection)
        }
        if count == 3 {
            let missing = Direction.allCases.first { !directions.contains($0) } ?? fallbackDirection
            return (.tee, missing.clockwise)
        }
        return (.cross, fallbackDirection)
    }

    private func isFluidEntity(_ entity: Entity, world: World) -> Bool {
        return world.has(PipeComponent.self, for: entity) ||
            world.has(FluidProducerComponent.self, for: entity) ||
            world.has(FluidConsumerComponent.self, for: entity) ||
            world.has(FluidTankComponent.self, for: entity) ||
            world.has(FluidPumpComponent.self, for: entity)
    }

    private func currentPipeDirection(at position: IntVector2, fallback: Direction, gameLoop: GameLoop) -> Direction {
        if let entity = pipeEntity(at: position, gameLoop: gameLoop),
           let pipe = gameLoop.world.get(PipeComponent.self, for: entity) {
            return pipe.direction
        }
        return fallback
    }

    private func pipeEntity(at position: IntVector2, gameLoop: GameLoop) -> Entity? {
        let entitiesAtPos = gameLoop.world.getAllEntitiesAt(position: position)
        if let entity = entitiesAtPos.first(where: { gameLoop.world.has(PipeComponent.self, for: $0) }) {
            return entity
        }

        // Fallback for any spatial index gaps
        for entity in gameLoop.world.entities {
            guard gameLoop.world.has(PipeComponent.self, for: entity),
                  let pos = gameLoop.world.get(PositionComponent.self, for: entity)?.tilePosition else {
                continue
            }
            if pos == position {
                return entity
            }
        }
        return nil
    }

    private func pipeEntity(at position: IntVector2, offset: Vector2, gameLoop: GameLoop) -> Entity? {
        let entitiesAtPos = gameLoop.world.getAllEntitiesAt(position: position)
        let tolerance: Float = 0.1
        var bestMatch: Entity?
        var bestDistance: Float = .greatestFiniteMagnitude

        for entity in entitiesAtPos {
            guard gameLoop.world.has(PipeComponent.self, for: entity),
                  let entityPos = gameLoop.world.get(PositionComponent.self, for: entity) else {
                continue
            }
            let distance = (entityPos.offset - offset).length
            if distance < bestDistance {
                bestDistance = distance
                bestMatch = entity
            }
        }

        if let match = bestMatch, bestDistance <= tolerance {
            return match
        }

        return bestMatch ?? pipeEntity(at: position, gameLoop: gameLoop)
    }

    private func finalizePipeDragNetworkAssignment(gameLoop: GameLoop) {
        guard let networkId = dragPlacementNetworkId,
              !dragPlacedPipeEntities.isEmpty else {
            return
        }
        let entities = Array(dragPlacedPipeEntities)
        gameLoop.fluidNetworkSystem.assignNetworkId(networkId, to: entities)
        for entity in entities {
            gameLoop.fluidNetworkSystem.markEntityDirty(entity, connectionsDirty: true)
        }
    }

    private func promptPipeTankSelection(for pipeEntity: Entity, gameLoop: GameLoop) {
        guard pipeNeedsTankSelection(pipeEntity, gameLoop: gameLoop) else { return }
        gameLoop.uiSystem?.openPipeTankSelection(for: pipeEntity)
    }

    private func pipeNeedsTankSelection(_ pipeEntity: Entity, gameLoop: GameLoop) -> Bool {
        guard let pipe = gameLoop.world.get(PipeComponent.self, for: pipeEntity) else { return false }
        let adjacent = adjacentTankBuildings(for: pipeEntity, gameLoop: gameLoop)
        guard !adjacent.isEmpty else { return false }
        return adjacent.contains { pipe.tankConnections[$0] == nil }
    }

    private func adjacentTankBuildings(for pipeEntity: Entity, gameLoop: GameLoop) -> [Entity] {
        guard let pipePos = gameLoop.world.get(PositionComponent.self, for: pipeEntity)?.worldPosition else {
            return []
        }

        let connectionRange: Float = 0.75
        var result: [Entity] = []

        for otherEntity in gameLoop.world.query(FluidTankComponent.self) {
            guard let tankComponent = gameLoop.world.get(FluidTankComponent.self, for: otherEntity),
                  let buildingDef = gameLoop.buildingRegistry.get(tankComponent.buildingId),
                  !buildingDef.fluidTanks.isEmpty else {
                continue
            }

            let bounds = tankBuildingBounds(for: otherEntity, gameLoop: gameLoop)
            let nearest = nearestPoint(on: bounds, to: pipePos)
            let delta = pipePos - nearest
            let distance = (delta.x * delta.x + delta.y * delta.y).squareRoot()
            if distance <= connectionRange {
                result.append(otherEntity)
            }
        }

        return result
    }

    private func tankBuildingBounds(for entity: Entity, gameLoop: GameLoop) -> Rect {
        guard let pos = gameLoop.world.get(PositionComponent.self, for: entity)?.tilePosition else {
            return Rect(x: 0, y: 0, width: 0, height: 0)
        }
        let size = fluidEntitySize(entity: entity, gameLoop: gameLoop)
        return Rect(origin: pos.toVector2, size: Vector2(Float(size.width), Float(size.height)))
    }

    private func nearestPoint(on bounds: Rect, to point: Vector2) -> Vector2 {
        let clampedX = min(max(point.x, bounds.minX), bounds.maxX)
        let clampedY = min(max(point.y, bounds.minY), bounds.maxY)
        return Vector2(clampedX, clampedY)
    }

    private func isFluidEntityOccupying(tile: IntVector2, gameLoop: GameLoop) -> Bool {
        for entity in gameLoop.world.entities {
            if !isFluidEntity(entity, world: gameLoop.world) {
                continue
            }
            guard let pos = gameLoop.world.get(PositionComponent.self, for: entity)?.tilePosition else {
                continue
            }
            let size = fluidEntitySize(entity: entity, gameLoop: gameLoop)
            let withinX = tile.x >= pos.x && tile.x < pos.x + Int32(size.width)
            let withinY = tile.y >= pos.y && tile.y < pos.y + Int32(size.height)
            if withinX && withinY {
                return true
            }
        }
        return false
    }

    private func fluidEntitySize(entity: Entity, gameLoop: GameLoop) -> (width: Int, height: Int) {
        var buildingId: String?

        if let pipe = gameLoop.world.get(PipeComponent.self, for: entity) {
            buildingId = pipe.buildingId
        } else if let producer = gameLoop.world.get(FluidProducerComponent.self, for: entity) {
            buildingId = producer.buildingId
        } else if let consumer = gameLoop.world.get(FluidConsumerComponent.self, for: entity) {
            buildingId = consumer.buildingId
        } else if let tank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
            buildingId = tank.buildingId
        } else if let pump = gameLoop.world.get(FluidPumpComponent.self, for: entity) {
            buildingId = pump.buildingId
        }

        if let buildingId = buildingId, let def = gameLoop.buildingRegistry.get(buildingId) {
            return (def.width, def.height)
        }

        return (1, 1)
    }

    // MARK: - Flow State Helper Methods

    private func cycleSelectedUnits() {
        guard let gameLoop = gameLoop, !selectedUnits.isEmpty else { return }

        // Get all units in the world
        var allUnits: [Entity] = []
        gameLoop.world.forEach(UnitComponent.self) { entity, _ in
            allUnits.append(entity)
        }

        guard !allUnits.isEmpty else { return }

        // Find current selection index
        let currentSelection = Array(selectedUnits).first
        var currentIndex = 0
        if let current = currentSelection {
            currentIndex = allUnits.firstIndex(of: current) ?? 0
        }

        // Move to next unit
        let nextIndex = (currentIndex + 1) % allUnits.count
        let nextUnit = allUnits[nextIndex]

        // Update selection
        selectedUnits.removeAll()
        selectedUnits.insert(nextUnit)
        selectedEntity = nextUnit
        onEntitySelected?(nextUnit)

        print("InputManager: Cycled to unit \(nextUnit)")
    }

    private func cycleSelectedBuildings() {
        guard let gameLoop = gameLoop else { return }

        // Get all buildings in the world
        var allBuildings: [Entity] = []
        gameLoop.world.forEach(BuildingComponent.self) { entity, _ in
            allBuildings.append(entity)
        }

        guard !allBuildings.isEmpty else { return }

        // Find current selection index (if any building is selected)
        var currentIndex = 0
        if let currentEntity = selectedEntity,
           gameLoop.world.has(BuildingComponent.self, for: currentEntity) {
            currentIndex = allBuildings.firstIndex(of: currentEntity) ?? 0
        }

        // Move to next building
        let nextIndex = (currentIndex + 1) % allBuildings.count
        let nextBuilding = allBuildings[nextIndex]

        // Update selection
        selectedEntity = nextBuilding
        onEntitySelected?(nextBuilding)

        print("InputManager: Cycled to building \(nextBuilding)")
    }

    deinit {
        // Clean up motion manager
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()

        // Clean up haptic engine
        hapticEngine?.stop(completionHandler: { error in
            if let error = error {
                print("InputManager: Error stopping haptic engine: \(error)")
            }
        })
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

@available(iOS 17.0, *)
extension InputManager: UIGestureRecognizerDelegate {
    // Don't prevent pan gesture - we'll handle joystick in the pan handler
    // This allows us to get .changed and .ended events

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow scroll views to handle their own pan gestures
        if gestureRecognizer is UIPanGestureRecognizer, let gameLoop = gameLoop {
            let touchLocation = gestureRecognizer.location(in: view)

            // Check if touch is within any UI scroll view
            if let uiSystem = gameLoop.uiSystem, uiSystem.isAnyPanelOpen {
                // Check inventory scroll view
                let inventoryUI = uiSystem.getInventoryUI()
                if let scrollView = inventoryUI.publicScrollView,
                   scrollView.frame.contains(touchLocation) {
                    return false
                }

                // Check machine UI scroll views
                let machineUI = uiSystem.getMachineUI()
                for scrollView in machineUI.getAllScrollViews() {
                    if scrollView.frame.contains(touchLocation) {
                        return false
                    }
                }
            }
        }

        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                          shouldReceive touch: UITouch) -> Bool {
        // Don't handle touches that start on UIKit controls
        if touch.view is UIControl { return false }

        // Don't handle touches on scroll views
        var superview = touch.view?.superview
        while superview != nil {
            if superview is UIScrollView { return false }
            superview = superview?.superview
        }

        // Check if touch is within any open UI panel
        if let gameLoop = gameLoop, let uiSystem = gameLoop.uiSystem, uiSystem.isAnyPanelOpen {
            let touchLocation = touch.location(in: view)

            // Check inventory scroll view
            let inventoryUI = uiSystem.getInventoryUI()
            if let scrollView = inventoryUI.publicScrollView,
               scrollView.frame.contains(touchLocation) {
                return false
            }

            // Check machine UI scroll views
            let machineUI = uiSystem.getMachineUI()
            for scrollView in machineUI.getAllScrollViews() {
                if scrollView.frame.contains(touchLocation) {
                    return false
                }
            }
            
        }

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

        // Allow simultaneous recognition with scroll view pan gestures
        if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer.view is UIScrollView {
            return true
        }
        if otherGestureRecognizer is UIPanGestureRecognizer && gestureRecognizer.view is UIScrollView {
            return true
        }

        // print("Not allowing simultaneous recognition")
        return false
    }
}
