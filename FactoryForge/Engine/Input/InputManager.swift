import UIKit

/// Manages all touch input for the game
final class InputManager: NSObject {
    private weak var view: UIView?
    private weak var gameLoop: GameLoop?
    
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
    private var buildPreviewPosition: IntVector2?
    
    // Selection
    var selectedEntity: Entity?
    
    // Callbacks
    var onTap: ((Vector2) -> Void)?
    var onLongPress: ((Vector2) -> Void)?
    var onBuildingPlaced: ((String, IntVector2, Direction) -> Void)?
    var onEntitySelected: ((Entity?) -> Void)?
    var onTooltip: ((String) -> Void)? // Called when something is tapped to show tooltip
    
    init(view: UIView, gameLoop: GameLoop) {
        self.view = view
        self.gameLoop = gameLoop
        
        super.init()
        
        setupGestureRecognizers()
    }
    
    private func setupGestureRecognizers() {
        guard let view = view else { return }
        
        // Ensure view can receive touches
        view.isUserInteractionEnabled = true
        view.isMultipleTouchEnabled = true
        
        // Tap recognizer
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapRecognizer.delegate = self
        view.addGestureRecognizer(tapRecognizer)
        
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
    
    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }

        let screenPos = screenPosition(from: recognizer)

        // Check for HUD button taps FIRST and show tooltip
        let screenSize = gameLoop?.renderer?.screenSize ?? Vector2(800, 600)
        if let buttonName = gameLoop?.uiSystem?.hud.getButtonName(at: screenPos, screenSize: screenSize) {
            // Show tooltip for button
            onTooltip?(buttonName)
        }

        // Check for entities/resources BEFORE UI system check, so tooltips always work
        let worldPos = gameLoop?.renderer?.screenToWorld(screenPos) ?? .zero
        
        if buildMode == .none {
            let tilePos = IntVector2(from: worldPos)
            
            // Check for entity
            if let entity = gameLoop?.world.getEntityAt(position: tilePos) {
                // Show tooltip for entity
                if let tooltipText = getEntityTooltipText(entity: entity, gameLoop: gameLoop) {
                    onTooltip?(tooltipText)
                }
            } else {
                // Check for resource
                if let resource = gameLoop?.chunkManager.getResource(at: tilePos), !resource.isEmpty {
                    // Show tooltip for resource
                    onTooltip?(resource.type.displayName)
                }
            }
        }

        // Check UI system for button actions (may consume the tap)
        if gameLoop?.uiSystem?.handleTap(at: screenPos) == true {
            return
        }

        // UI didn't handle it, process game tap
        currentTouchPosition = worldPos
        
        switch buildMode {
        case .none:
            // Try to select an entity at this position
            let tilePos = IntVector2(from: worldPos)
            if let entity = gameLoop?.world.getEntityAt(position: tilePos) {
                selectedEntity = entity
                onEntitySelected?(entity)
            } else {
                // No entity, check for resource to mine manually
                if let resource = gameLoop?.chunkManager.getResource(at: tilePos), !resource.isEmpty {
                    // Check if player can accept the item
                    if gameLoop?.player.inventory.canAccept(itemId: resource.type.outputItem) == true {
                        print("Mining resource at (\(tilePos.x), \(tilePos.y)): \(resource.type) with \(resource.amount) remaining")
                        // Manual mining - mine 1 unit
                        let mined = gameLoop?.chunkManager.mineResource(at: tilePos, amount: 1) ?? 0
                        if mined > 0 {
                            // Add to player inventory
                            gameLoop?.player.inventory.add(itemId: resource.type.outputItem, count: mined)
                            print("Manually mined \(mined) \(resource.type.outputItem), \(resource.amount - mined) remaining")

                            // Check if resource is now depleted
                            if let updatedResource = gameLoop?.chunkManager.getResource(at: tilePos) {
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
            
        case .placing:
            // Place building
            if let buildingId = selectedBuildingId {
                let tilePos = IntVector2(from: worldPos)
                if gameLoop?.placeBuilding(buildingId, at: tilePos, direction: buildDirection) == true {
                    onBuildingPlaced?(buildingId, tilePos, buildDirection)
                    // Play placement sound/feedback
                }
            }
            
        case .removing:
            // Remove building
            let tilePos = IntVector2(from: worldPos)
            _ = gameLoop?.removeBuilding(at: tilePos)
        }
        
        onTap?(worldPos)
    }
    
    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let renderer = gameLoop?.renderer else { return }
        
        let screenPos = screenPosition(from: recognizer)
        let worldPos = renderer.screenToWorld(screenPos)
        currentTouchPosition = worldPos
        
        // Get joystick from HUD
        let joystick = gameLoop?.uiSystem?.hud.joystick
        
        switch recognizer.state {
        case .began:
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
            
            if buildMode == .placing, let buildingId = selectedBuildingId {
                // Start belt drag placement
                buildPreviewPosition = IntVector2(from: worldPos)
            }
            
        case .changed:
            // Handle joystick movement
            if isJoystickActive {
                joystick?.handleTouchMoved(at: screenPos, touchId: 0)
                // Prevent camera pan when joystick is active
                return
            }
            
            if buildMode == .none {
                // Pan camera
                let delta = screenPos - panStartPosition
                let worldDelta = delta / renderer.camera.zoom / 32.0
                renderer.camera.target = cameraStartPosition - Vector2(worldDelta.x, -worldDelta.y)
            } else if buildMode == .placing {
                // Update build preview
                buildPreviewPosition = IntVector2(from: worldPos)
                
                // For belts, continuously place as we drag
                if let buildingId = selectedBuildingId,
                   buildingId.contains("belt"),
                   let pos = buildPreviewPosition {
                    _ = gameLoop?.placeBuilding(buildingId, at: pos, direction: buildDirection)
                }
            }
            
        case .ended, .cancelled:
            if isJoystickActive {
                joystick?.handleTouchEnded(touchId: 0)
                isJoystickActive = false
                // Reset state
                return
            }

            isDragging = false
            buildPreviewPosition = nil
            
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
        
        // Check for building components to identify building type
        if world.has(MinerComponent.self, for: entity) {
            if let sprite = world.get(SpriteComponent.self, for: entity),
               let building = gameLoop?.buildingRegistry.getByTexture(sprite.textureId) {
                return building.name
            }
            return "Mining Drill"
        }
        if world.has(FurnaceComponent.self, for: entity) {
            if let sprite = world.get(SpriteComponent.self, for: entity),
               let building = gameLoop?.buildingRegistry.getByTexture(sprite.textureId) {
                return building.name
            }
            return "Furnace"
        }
        if world.has(AssemblerComponent.self, for: entity) {
            if let sprite = world.get(SpriteComponent.self, for: entity),
               let building = gameLoop?.buildingRegistry.getByTexture(sprite.textureId) {
                return building.name
            }
            return "Assembling Machine"
        }
        if world.has(BeltComponent.self, for: entity) {
            return "Conveyor Belt"
        }
        if world.has(InserterComponent.self, for: entity) {
            return "Inserter"
        }
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
}

// MARK: - UIGestureRecognizerDelegate

extension InputManager: UIGestureRecognizerDelegate {
    // Don't prevent pan gesture - we'll handle joystick in the pan handler
    // This allows us to get .changed and .ended events

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        print("gestureRecognizerShouldBegin called for \(type(of: gestureRecognizer))")
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                          shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        let gesture1Type = type(of: gestureRecognizer)
        let gesture2Type = type(of: otherGestureRecognizer)
        print("Checking simultaneous recognition: \(gesture1Type) vs \(gesture2Type)")

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
        print("Not allowing simultaneous recognition")
        return false
    }
}

