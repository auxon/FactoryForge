import UIKit
import Metal

/// Global UI scale factor for retina displays
let UIScale: Float = Float(UIScreen.main.scale)

/// Main UI system that manages all UI elements
final class UISystem {
    private weak var gameLoop: GameLoop?
    private weak var renderer: MetalRenderer?
    private weak var inputManager: InputManager?
    
    // UI Panels
    private(set) var hud: HUD
    private var inventoryUI: InventoryUI
    private var craftingMenu: CraftingMenu
    private var buildMenu: BuildMenu
    private var researchUI: ResearchUI
    private var machineUI: MachineUI
    private var loadingMenu: LoadingMenu
    private var inserterTypeDialog: InserterTypeDialog?
    
    // Current state
    private(set) var activePanel: UIPanel?
    private(set) var isAnyPanelOpen: Bool = false
    
    // Touch handling
    private var touchedElement: UIElement?
    
    init(gameLoop: GameLoop?, renderer: MetalRenderer?) {
        self.gameLoop = gameLoop
        self.renderer = renderer
        
        let screenSize = renderer?.screenSize ?? Vector2(800, 600)
        
        loadingMenu = LoadingMenu(screenSize: screenSize)
        hud = HUD(screenSize: screenSize, gameLoop: gameLoop, inputManager: nil)
        inventoryUI = InventoryUI(screenSize: screenSize, gameLoop: gameLoop)
        craftingMenu = CraftingMenu(screenSize: screenSize, gameLoop: gameLoop)
        buildMenu = BuildMenu(screenSize: screenSize, gameLoop: gameLoop)
        researchUI = ResearchUI(screenSize: screenSize, gameLoop: gameLoop)
        machineUI = MachineUI(screenSize: screenSize, gameLoop: gameLoop)
        // Get texture dimensions for button sizing (preserve aspect ratios like LoadingMenu)
        // Use actual known texture sizes as fallback if lookup fails
        let inputSize = renderer?.textureAtlas.getTextureSize(for: "inserter_input_button") ?? (width: 787, height: 332)
        let outputSize = renderer?.textureAtlas.getTextureSize(for: "inserter_output_button") ?? (width: 885, height: 416)
        let cancelSize = renderer?.textureAtlas.getTextureSize(for: "inserter_cancel_button") ?? (width: 810, height: 345)

        // Calculate aspect ratios for each button
        let inputAspectRatio = Float(inputSize.width) / Float(inputSize.height)
        let outputAspectRatio = Float(outputSize.width) / Float(outputSize.height)
        let cancelAspectRatio = Float(cancelSize.width) / Float(cancelSize.height)

        // Set target height for all buttons (like LoadingMenu does - use UIScale for proper sizing)
        // Use larger height for better visibility
        let targetButtonHeight: Float = 100 * UIScale  // Scaled height for UI buttons

        // Calculate widths based on aspect ratios (preserve texture proportions)
        let inputWidth = targetButtonHeight * inputAspectRatio
        let outputWidth = targetButtonHeight * outputAspectRatio
        let cancelWidth = targetButtonHeight * cancelAspectRatio

        inserterTypeDialog = InserterTypeDialog(screenSize: screenSize, inputWidth: inputWidth, outputWidth: outputWidth, cancelWidth: cancelWidth, buttonHeight: targetButtonHeight)

        setupCallbacks()
    }
    
    func setGameLoop(_ gameLoop: GameLoop) {
        self.gameLoop = gameLoop
        let screenSize = renderer?.screenSize ?? Vector2(800, 600)

        // Update all UI components that need gameLoop
        hud = HUD(screenSize: screenSize, gameLoop: gameLoop, inputManager: inputManager)
        inventoryUI = InventoryUI(screenSize: screenSize, gameLoop: gameLoop)
        craftingMenu = CraftingMenu(screenSize: screenSize, gameLoop: gameLoop)
        buildMenu = BuildMenu(screenSize: screenSize, gameLoop: gameLoop)
        researchUI = ResearchUI(screenSize: screenSize, gameLoop: gameLoop)
        machineUI = MachineUI(screenSize: screenSize, gameLoop: gameLoop)
        setupCallbacks()
    }

    func setInputManager(_ inputManager: InputManager) {
        self.inputManager = inputManager
        // Update HUD with inputManager reference
        hud.setInputManager(inputManager)
    }
    
    func getLoadingMenu() -> LoadingMenu {
        return loadingMenu
    }

    func getInventoryUI() -> InventoryUI {
        return inventoryUI
    }

    func getMachineUI() -> MachineUI {
        return machineUI
    }

    func getResearchUI() -> ResearchUI {
        return researchUI
    }

    func getCraftingMenu() -> CraftingMenu {
        return craftingMenu
    }

    func getInserterTypeDialog() -> InserterTypeDialog? {
        return inserterTypeDialog
    }
    
    private func setupCallbacks() {
        // Input manager callbacks
        inputManager?.onInserterTypeSelection = { [weak self] buildingId, position, direction, offset in
            self?.showInserterTypeDialog(buildingId: buildingId, position: position, direction: direction, offset: offset)
        }

        // Inserter type dialog callbacks
        inserterTypeDialog?.onInputSelected = { [weak self] buildingId, position, direction, offset in
            // Place inserter first, then close dialog to ensure placement completes
            self?.inputManager?.placeInserter(buildingId, at: position, direction: direction, offset: offset, type: .input)
            self?.closeInserterTypeDialog()
        }

        inserterTypeDialog?.onOutputSelected = { [weak self] buildingId, position, direction, offset in
            // Place inserter first, then close dialog to ensure placement completes
            self?.inputManager?.placeInserter(buildingId, at: position, direction: direction, offset: offset, type: .output)
            self?.closeInserterTypeDialog()
        }

        inserterTypeDialog?.onCancel = { [weak self] in
            self?.closeInserterTypeDialog()
            self?.inputManager?.exitBuildMode() // Exit build mode when canceling
        }


        // HUD button callbacks
        hud.onInventoryPressed = { [weak self] in
            // Close machine UI if open when clicking any HUD button
            if self?.activePanel == .machine {
                self?.closeAllPanels()
            }
            self?.togglePanel(.inventory)
        }
        
        hud.onCraftingPressed = { [weak self] in
            // Close machine UI if open when clicking any HUD button
            if self?.activePanel == .machine {
                self?.closeAllPanels()
            }
            self?.togglePanel(.crafting)
        }
        
        hud.onBuildPressed = { [weak self] in
            // Close machine UI if open when clicking any HUD button
            if self?.activePanel == .machine {
                self?.closeAllPanels()
            }
            self?.togglePanel(.build)
        }
        
        hud.onResearchPressed = { [weak self] in
            // Close machine UI if open when clicking any HUD button
            if self?.activePanel == .machine {
                self?.closeAllPanels()
            }
            self?.togglePanel(.research)
        }
        
        hud.onMenuPressed = { [weak self] in
            // Close machine UI if open when clicking any HUD button
            if self?.activePanel == .machine {
                self?.closeAllPanels()
            }
            self?.openPanel(.loadingMenu)
        }
        
        // Build menu callbacks
        buildMenu.onBuildingSelected = { [weak self] buildingId in
            self?.closeAllPanels()
            // Enter build mode via input manager
            self?.gameLoop?.inputManager?.enterBuildMode(buildingId: buildingId)
        }
        
        // Machine UI callback for opening inventory
        machineUI.onOpenInventoryForMachine = { [weak self] entity, slotIndex in
            // Open inventory UI in machine input mode
            self?.inventoryUI.enterMachineInputMode(entity: entity, slotIndex: slotIndex)
            self?.inventoryUI.onMachineInputCompleted = { [weak self] in
                // Reopen machine UI after inventory input is completed
                self?.openPanel(.machine)
            }
            self?.openPanel(.inventory)
        }

        // Quick bar slot callback
    }
    
    // MARK: - Update
    
    func update(deltaTime: Float) {
        if let panel = activePanel, panel == .loadingMenu {
            loadingMenu.update(deltaTime: deltaTime)
            return // Don't update game UI if loading menu is open
        }
        
        hud.update(deltaTime: deltaTime)
        
        if let panel = activePanel {
            switch panel {
            case .loadingMenu:
                loadingMenu.update(deltaTime: deltaTime)
            case .inventory:
                inventoryUI.update(deltaTime: deltaTime)
            case .crafting:
                craftingMenu.update(deltaTime: deltaTime)
            case .build:
                buildMenu.update(deltaTime: deltaTime)
            case .research:
                researchUI.update(deltaTime: deltaTime)
            case .machine:
                machineUI.update(deltaTime: deltaTime)
            case .inserterType:
                inserterTypeDialog?.update(deltaTime: deltaTime)
            }
        }
    }

    private func showInserterTypeDialog(buildingId: String, position: IntVector2, direction: Direction, offset: Vector2) {
        guard let dialog = inserterTypeDialog else { return }
        dialog.setBuildingInfo(buildingId: buildingId, position: position, direction: direction, offset: offset)

        // Set up callbacks for new inserter placement
        dialog.onInputSelected = { [weak self] buildingId, position, direction, offset in
            print("InserterTypeDialog: Input selected - buildingId: \(buildingId), position: \(position), direction: \(direction)")
            // Place inserter first, then close dialog to ensure placement completes
            self?.inputManager?.placeInserter(buildingId, at: position, direction: direction, offset: offset, type: .input)
            self?.closeInserterTypeDialog()
        }
        dialog.onOutputSelected = { [weak self] buildingId, position, direction, offset in
            print("InserterTypeDialog: Output selected - buildingId: \(buildingId), position: \(position), direction: \(direction)")
            // Place inserter first, then close dialog to ensure placement completes
            self?.inputManager?.placeInserter(buildingId, at: position, direction: direction, offset: offset, type: .output)
            self?.closeInserterTypeDialog()
        }
        dialog.onInserterTypeChanged = nil // Clear existing callback
        dialog.onCancel = { [weak self] in
            self?.closeInserterTypeDialog()
            self?.inputManager?.exitBuildMode() // Exit build mode when canceling
        }

        // Show the dialog
        dialog.open()
        activePanel = .inserterType
        isAnyPanelOpen = true
    }

    func showInserterTypeDialogForExisting(entity: Entity, currentType: InserterType, position: IntVector2, direction: Direction, offset: Vector2) {
        guard let dialog = inserterTypeDialog else { return }
        dialog.setExistingInserterInfo(entity: entity, currentType: currentType, position: position, direction: direction, offset: offset)

        // Set up callbacks for existing inserter modification
        dialog.onInserterTypeChanged = { [weak self] entity, newType in
            self?.gameLoop?.changeInserterType(entity: entity, newType: newType)
            self?.closeInserterTypeDialog()
        }
        dialog.onInputSelected = nil // Clear new placement callbacks
        dialog.onOutputSelected = nil
        dialog.onCancel = { [weak self] in
            self?.closeInserterTypeDialog()
        }

        // Show the dialog
        dialog.open()
        activePanel = .inserterType
        isAnyPanelOpen = true
    }

    private func closeInserterTypeDialog() {
        inserterTypeDialog?.close()
        activePanel = nil
        isAnyPanelOpen = false
    }

    // MARK: - Rendering
    
    func render(renderer: MetalRenderer) {
        if let panel = activePanel, panel == .loadingMenu {
            // Only render loading menu if it's active (replaces entire view)
            loadingMenu.render(renderer: renderer)
            return
        }
        
        // Render HUD (always visible)
        hud.render(renderer: renderer)
        
        // Render active panel
        if let panel = activePanel {
            switch panel {
            case .loadingMenu:
                loadingMenu.render(renderer: renderer)
            case .inventory:
                inventoryUI.render(renderer: renderer)
            case .crafting:
                craftingMenu.render(renderer: renderer)
            case .build:
                buildMenu.render(renderer: renderer)
            case .research:
                researchUI.render(renderer: renderer)
            case .machine:
                machineUI.render(renderer: renderer)
            case .inserterType:
                inserterTypeDialog?.render(renderer: renderer)
            }
        }
    }
    
    func renderMetal(encoder: MTLRenderCommandEncoder, screenSize: Vector2) {
        // Metal-based UI rendering would go here
        // For now, UI is rendered through the sprite system
    }
    
    // MARK: - Panel Management
    
    func togglePanel(_ panel: UIPanel) {
        if activePanel == panel {
            closeAllPanels()
        } else {
            openPanel(panel)
        }
    }
    
    func openPanel(_ panel: UIPanel) {
        closeAllPanels()
        activePanel = panel
        isAnyPanelOpen = true
        
        switch panel {
        case .loadingMenu:
            loadingMenu.open()
        case .inventory:
            inventoryUI.open()
        case .crafting:
            craftingMenu.open()
        case .build:
            buildMenu.open()
        case .research:
            researchUI.open()
        case .machine:
            machineUI.open()
        case .inserterType:
            inserterTypeDialog?.open()
        }
    }
    
    func closeAllPanels() {
        if let panel = activePanel {
            switch panel {
            case .loadingMenu:
                loadingMenu.close()
            case .inventory:
                inventoryUI.close()
            case .crafting:
                craftingMenu.close()
            case .build:
                buildMenu.close()
            case .research:
                researchUI.close()
            case .machine:
                machineUI.close()
            case .inserterType:
                inserterTypeDialog?.close()
            }
        }

        activePanel = nil
        isAnyPanelOpen = false
    }
    
    func openMachineUI(for entity: Entity) {
        machineUI.setEntity(entity)
        openPanel(.machine)
    }

    func openChestInventory(for entity: Entity) {
        inventoryUI.enterChestMode(entity: entity)
        openPanel(.inventory)
    }
    
    func updateScreenSize(_ newSize: Vector2) {
        hud.updateScreenSize(newSize)
        // TODO: Update other UI panels if they need screen size updates
    }
    
    // MARK: - Touch Handling
    
    func handleTap(at screenPos: Vector2) -> Bool {
        // If loading menu is active, handle taps only for it
        if let panel = activePanel, panel == .loadingMenu {
            return loadingMenu.handleTap(at: screenPos)
        }
        
        // Get current screen size from renderer
        let currentScreenSize = renderer?.screenSize ?? Vector2(800, 600)
        
        // Check HUD first
        if hud.handleTap(at: screenPos, screenSize: currentScreenSize) {
            return true
        }
        
        // Check active panel
        if let panel = activePanel {
            switch panel {
            case .loadingMenu:
                return loadingMenu.handleTap(at: screenPos)
            case .inventory:
                if inventoryUI.handleTap(at: screenPos) { return true }
            case .crafting:
                if craftingMenu.handleTap(at: screenPos) { return true }
            case .build:
                if buildMenu.handleTap(at: screenPos) { return true }
            case .research:
                if researchUI.handleTap(at: screenPos) { return true }
            case .machine:
                if machineUI.handleTap(at: screenPos) { return true }
            case .inserterType:
                if inserterTypeDialog?.handleTap(at: screenPos) ?? false { return true }
            }

            // If we reach here, the panel's handleTap returned false,
            // meaning the tap was not handled by the panel.
            // Close the panel regardless of tap location.
            closeAllPanels()
            return true
        }
        
        return false
    }

    func getTooltip(at screenPos: Vector2) -> String? {
        // If loading menu is active, check tooltips only for it
        if let panel = activePanel, panel == .loadingMenu {
            return nil // Loading menu doesn't need tooltips
        }

        // Get current screen size from renderer
        let currentScreenSize = renderer?.screenSize ?? Vector2(800, 600)

        // Check HUD first
        if let tooltip = hud.getButtonName(at: screenPos, screenSize: currentScreenSize) {
            return tooltip
        }

        // Check active panel
        if let panel = activePanel {
            switch panel {
            case .loadingMenu:
                return nil
            case .inventory:
                return inventoryUI.getTooltip(at: screenPos)
            case .crafting:
                return craftingMenu.getTooltip(at: screenPos)
            case .build:
                return buildMenu.getTooltip(at: screenPos)
            case .research:
                return researchUI.getTooltip(at: screenPos)
            case .machine:
                return nil // MachineUI doesn't need tooltips yet
            case .inserterType:
                return nil // InserterTypeDialog doesn't need tooltips
            }
        }

        return nil
    }

    func handleDrag(from startPos: Vector2, to endPos: Vector2) -> Bool {
        // Check active panels
        if let panel = activePanel {
            switch panel {
            case .inventory:
                return inventoryUI.handleDrag(from: startPos, to: endPos)
            case .machine:
                return machineUI.handleDrag(from: startPos, to: endPos)
            default:
                return false
            }
        }
        return false
    }
}

// MARK: - UI Types

enum UIPanel {
    case loadingMenu
    case inventory
    case crafting
    case build
    case research
    case machine
    case inserterType
}

/// Dialog for selecting inserter type (Input or Output)
final class InserterTypeDialog {
    // Unique identifier for debugging
    private let id = Int.random(in: 0...9999)
    var debugId: Int { id }

    // Callbacks
    var onInputSelected: ((String, IntVector2, Direction, Vector2) -> Void)?
    var onOutputSelected: ((String, IntVector2, Direction, Vector2) -> Void)?
    var onInserterTypeChanged: ((Entity, InserterType) -> Void)?
    var onCancel: (() -> Void)?


    // Building info
    private var buildingId: String = ""
    private var position: IntVector2 = .zero
    private var direction: Direction = .north
    private var offset: Vector2 = .zero

    // For modifying existing inserters
    private var existingEntity: Entity?
    private var currentType: InserterType = .input

    // UI Elements
    private var inputButton: UIButton
    private var outputButton: UIButton
    private var cancelButton: UIButton

    init(screenSize: Vector2, inputWidth: Float = 200, outputWidth: Float = 200, cancelWidth: Float = 200, buttonHeight: Float = 50) {
        let spacing: Float = 20 * UIScale  // Scaled spacing like LoadingMenu

        // Center the buttons vertically and horizontally
        // Use the maximum width for centering calculations
        let maxWidth = max(inputWidth, outputWidth, cancelWidth)
        let totalHeight = buttonHeight * 3 + spacing * 2
        let startY = (screenSize.y - totalHeight) / 2
        let buttonX = (screenSize.x - maxWidth) / 2

        // Input button (top) - center each button in the available width
        let inputX = buttonX + maxWidth/2
        inputButton = UIButton(frame: Rect(
            center: Vector2(inputX, startY + buttonHeight/2),
            size: Vector2(inputWidth, buttonHeight)
        ), textureId: "inserter_input_button")

        // Output button (middle)
        let outputX = buttonX + maxWidth/2
        outputButton = UIButton(frame: Rect(
            center: Vector2(outputX, startY + buttonHeight/2 + buttonHeight + spacing),
            size: Vector2(outputWidth, buttonHeight)
        ), textureId: "inserter_output_button")

        // Cancel button (bottom)
        let cancelX = buttonX + maxWidth/2
        cancelButton = UIButton(frame: Rect(
            center: Vector2(cancelX, startY + buttonHeight/2 + (buttonHeight + spacing) * 2),
            size: Vector2(cancelWidth, buttonHeight)
        ), textureId: "inserter_cancel_button")

        // Buttons now use textures with built-in text - no additional setup needed

        // Set up callbacks after all properties are initialized
        inputButton.onTap = { [weak self] in
            guard let self = self else { return }
            print("InserterTypeDialog: Input button tapped - existingEntity: \(self.existingEntity != nil ? "exists" : "nil"), buildingId: \(self.buildingId), position: \(self.position)")
            if let existingEntity = self.existingEntity {
                // Modifying existing inserter
                print("InserterTypeDialog: Calling onInserterTypeChanged for existing entity")
                self.onInserterTypeChanged?(existingEntity, .input)
            } else {
                // Placing new inserter
                print("InserterTypeDialog: Calling onInputSelected for new inserter")
                self.onInputSelected?(self.buildingId, self.position, self.direction, self.offset)
            }
        }

        outputButton.onTap = { [weak self] in
            guard let self = self else { return }
            print("InserterTypeDialog: Output button tapped - existingEntity: \(self.existingEntity != nil ? "exists" : "nil"), buildingId: \(self.buildingId), position: \(self.position)")
            if let existingEntity = self.existingEntity {
                // Modifying existing inserter
                print("InserterTypeDialog: Calling onInserterTypeChanged for existing entity")
                self.onInserterTypeChanged?(existingEntity, .output)
            } else {
                // Placing new inserter
                print("InserterTypeDialog: Calling onOutputSelected for new inserter")
                self.onOutputSelected?(self.buildingId, self.position, self.direction, self.offset)
            }
        }

        cancelButton.onTap = { [weak self] in
            self?.onCancel?()
        }
    }

    func setBuildingInfo(buildingId: String, position: IntVector2, direction: Direction, offset: Vector2) {
        self.buildingId = buildingId
        self.position = position
        self.direction = direction
        self.offset = offset
        self.existingEntity = nil  // Clear any existing entity reference
    }

    func setExistingInserterInfo(entity: Entity, currentType: InserterType, position: IntVector2, direction: Direction, offset: Vector2) {
        self.existingEntity = entity
        self.currentType = currentType
        self.buildingId = "inserter"
        self.position = position
        self.direction = direction
        self.offset = offset
    }

    func handleTap(at position: Vector2) -> Bool {
        return inputButton.handleTap(at: position) ||
               outputButton.handleTap(at: position) ||
               cancelButton.handleTap(at: position)
    }

    func update(deltaTime: Float) {
        inputButton.update(deltaTime: deltaTime)
        outputButton.update(deltaTime: deltaTime)
        cancelButton.update(deltaTime: deltaTime)
    }



    func open() {
        // Buttons now use textures with built-in text
    }

    func close() {
        // Text labels will stop being rendered when dialog is not active
    }

    func render(renderer: MetalRenderer) {
        // Render background - size it to fit all buttons with proper aspect ratios
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")

        // Calculate background size based on button dimensions
        let maxButtonWidth = max(inputButton.frame.width, outputButton.frame.width, cancelButton.frame.width)
        let spacing: Float = 20 * UIScale
        let totalButtonHeight = inputButton.frame.height * 3 + spacing * 2  // 3 buttons + 2 spacings
        let padding: Float = 100 * UIScale  // Very generous padding to prevent clipping
        let bgWidth = maxButtonWidth + padding * 2  // Add padding on both sides
        let bgHeight = totalButtonHeight + padding * 2  // Add padding on top and bottom

        let bgRect = Rect(
            center: Vector2(renderer.screenSize.x / 2, renderer.screenSize.y / 2),
            size: Vector2(bgWidth, bgHeight)
        )
        renderer.queueSprite(SpriteInstance(
            position: bgRect.center,
            size: bgRect.size,
            textureRect: solidRect,
            color: Color(r: 0.1, g: 0.1, b: 0.15, a: 0.9),
            layer: .ui
        ))

        // Render title
        // Note: Text rendering would need to be implemented separately

        // Render buttons (now with built-in text textures)
        inputButton.render(renderer: renderer)
        outputButton.render(renderer: renderer)
        cancelButton.render(renderer: renderer)
    }
}

protocol UIElement {
    var frame: Rect { get }
    func handleTap(at position: Vector2) -> Bool
}

// MARK: - Base UI Components

class UIButton: UIElement {
    var frame: Rect
    var textureId: String
    var label: String = ""
    var isEnabled: Bool = true
    var isPressed: Bool = false
    var onTap: (() -> Void)?

    init(frame: Rect, textureId: String = "solid_white") {
        self.frame = frame
        self.textureId = textureId
    }
    
    func handleTap(at position: Vector2) -> Bool {
        guard isEnabled && frame.contains(position) else { return false }
        onTap?()
        return true
    }

    func update(deltaTime: Float) {
        // Handle button animations or state changes if needed
    }
    
    func render(renderer: MetalRenderer) {
        let color = isEnabled ? (isPressed ? Color(r: 0.8, g: 0.8, b: 0.8, a: 1) : .white) : Color(r: 0.5, g: 0.5, b: 0.5, a: 1)

        let textureRect = renderer.textureAtlas.getTextureRect(for: textureId)

        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: textureRect,
            color: color,
            layer: .ui
        ))
    }
}

class UIPanel_Base {
    var frame: Rect
    var isOpen: Bool = false
    var backgroundColor: Color = Color(r: 0.1, g: 0.1, b: 0.15, a: 0.95)
    
    init(frame: Rect) {
        self.frame = frame
    }
    
    func open() {
        isOpen = true
    }
    
    func close() {
        isOpen = false
    }
    
    func update(deltaTime: Float) {}
    
    func render(renderer: MetalRenderer) {
        guard isOpen else { return }
        
        // Render background
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: solidRect,
            color: backgroundColor,
            layer: .ui
        ))
    }
    
    func handleTap(at position: Vector2) -> Bool {
        return frame.contains(position)
    }
    
    func handleDrag(from startPos: Vector2, to endPos: Vector2) -> Bool {
        return false
    }
}

class CloseButton: UIElement {
    var frame: Rect
    var onTap: (() -> Void)?

    init(frame: Rect) {
        self.frame = frame
    }

    func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }
        onTap?()
        return true
    }

    func render(renderer: MetalRenderer) {
        // Render background circle
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: solidRect,
            color: Color(r: 0.3, g: 0.3, b: 0.3, a: 1),
            layer: .ui
        ))

        // Render X symbol using diagonal lines made of small squares
        let squareSize: Float = 3 * UIScale
        let spacing = squareSize * 1.2
        let numSquares = 5

        // First diagonal (top-left to bottom-right)
        for i in 0..<numSquares {
            let t = Float(i) / Float(numSquares - 1) - 0.5
            let pos = frame.center + Vector2(t * spacing * 2, t * spacing * 2)
            renderer.queueSprite(SpriteInstance(
                position: pos,
                size: Vector2(squareSize, squareSize),
                textureRect: solidRect,
                color: .white,
                layer: .ui
            ))
        }

        // Second diagonal (top-right to bottom-left)
        for i in 0..<numSquares {
            let t = Float(i) / Float(numSquares - 1) - 0.5
            let pos = frame.center + Vector2(-t * spacing * 2, t * spacing * 2)
            renderer.queueSprite(SpriteInstance(
                position: pos,
                size: Vector2(squareSize, squareSize),
                textureRect: solidRect,
                color: .white,
                layer: .ui
            ))
        }
    }
}


