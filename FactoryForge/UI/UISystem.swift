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
    private var entitySelectionDialog: EntitySelectionDialog?
    
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
        // Initialize entity selection dialog
        entitySelectionDialog = EntitySelectionDialog(screenSize: screenSize, gameLoop: gameLoop, renderer: renderer)

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
        
        // Reinitialize entity selection dialog with gameLoop
        entitySelectionDialog = EntitySelectionDialog(screenSize: screenSize, gameLoop: gameLoop, renderer: renderer)
        
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

    private func setupCallbacks() {
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
            case .entitySelection:
                entitySelectionDialog?.update(deltaTime: deltaTime)
            }
        }
    }

    func showEntitySelectionDialog(entities: [Entity], onSelected: @escaping (Entity) -> Void) {
        guard let dialog = entitySelectionDialog else { return }
        dialog.setEntities(entities)
        
        dialog.onEntitySelected = { [weak self] entity in
            onSelected(entity)
            self?.closeEntitySelectionDialog()
        }
        
        dialog.onCancel = { [weak self] in
            self?.closeEntitySelectionDialog()
        }
        
        dialog.open()
        activePanel = .entitySelection
        isAnyPanelOpen = true
    }
    
    private func closeEntitySelectionDialog() {
        entitySelectionDialog?.close()
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
            case .entitySelection:
                entitySelectionDialog?.render(renderer: renderer)
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
            case .entitySelection:
                entitySelectionDialog?.open()
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
            case .entitySelection:
                entitySelectionDialog?.close()
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
            case .entitySelection:
                if entitySelectionDialog?.handleTap(at: screenPos) ?? false { return true }
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
            case .entitySelection:
                return nil // EntitySelectionDialog doesn't need tooltips
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
    case entitySelection
}

// MARK: - Entity Selection Dialog

class EntitySelectionDialog {
    private weak var gameLoop: GameLoop?
    private weak var renderer: MetalRenderer?
    private var screenSize: Vector2
    
    private var entities: [Entity] = []
    private var entityButtons: [UIButton] = []
    private var cancelButton: UIButton
    
    var onEntitySelected: ((Entity) -> Void)?
    var onCancel: (() -> Void)?
    
    var isOpen: Bool = false
    
    init(screenSize: Vector2, gameLoop: GameLoop?, renderer: MetalRenderer?) {
        self.screenSize = screenSize
        self.gameLoop = gameLoop
        self.renderer = renderer
        
        // Create cancel button with proper texture and aspect ratio (same as InserterTypeDialog)
        let cancelSize = renderer?.textureAtlas.getTextureSize(for: "cancel_button") ?? (width: 810, height: 345)
        let cancelAspectRatio = Float(cancelSize.width) / Float(cancelSize.height)
        let targetButtonHeight: Float = 50 * UIScale
        let cancelWidth = targetButtonHeight * cancelAspectRatio
        
        let cancelX = screenSize.x / 2
        let cancelY = screenSize.y - 100 * UIScale
        
        cancelButton = UIButton(
            frame: Rect(
                center: Vector2(cancelX, cancelY),
                size: Vector2(cancelWidth, targetButtonHeight)
            ),
            textureId: "inserter_cancel_button"
        )
        
        cancelButton.onTap = { [weak self] in
            self?.onCancel?()
        }
    }
    
    func setEntities(_ entities: [Entity]) {
        self.entities = entities
        entityButtons.removeAll()
        
        guard let gameLoop = gameLoop else { return }
        
        print("EntitySelectionDialog: setEntities called with \(entities.count) entities")
        for entity in entities {
            let hasInserter = gameLoop.world.has(InserterComponent.self, for: entity)
            let hasBelt = gameLoop.world.has(BeltComponent.self, for: entity)
            let hasFurnace = gameLoop.world.has(FurnaceComponent.self, for: entity)
            print("EntitySelectionDialog: Entity \(entity) - Inserter: \(hasInserter), Belt: \(hasBelt), Furnace: \(hasFurnace)")
        }
        
        let iconSize: Float = 80 * UIScale
        let spacing: Float = 20 * UIScale
        let padding: Float = 40 * UIScale
        
        // Calculate grid layout
        let cols = min(3, entities.count)  // Max 3 columns
        let rows = (entities.count + cols - 1) / cols  // Ceiling division
        
        let totalWidth = Float(cols) * iconSize + Float(cols - 1) * spacing + padding * 2
        let totalHeight = Float(rows) * iconSize + Float(rows - 1) * spacing + padding * 2 + 100  // Extra space for cancel button
        
        let startX = (screenSize.x - totalWidth) / 2 + padding
        let startY = (screenSize.y - totalHeight) / 2 + padding
        
        // Create buttons for each entity
        for (index, entity) in entities.enumerated() {
            let row = index / cols
            let col = index % cols
            
            let x = startX + Float(col) * (iconSize + spacing) + iconSize / 2
            let y = startY + Float(row) * (iconSize + spacing) + iconSize / 2
            
            let button = UIButton(
                frame: Rect(
                    center: Vector2(x, y),
                    size: Vector2(iconSize, iconSize)
                ),
                textureId: getEntityTextureId(entity: entity, gameLoop: gameLoop)
            )
            
            // Capture the entity ID and generation to ensure we use the correct entity
            let capturedEntity = entity
            let entityId = entity.id
            let entityGeneration = entity.generation
            button.onTap = { [weak self] in
                guard let self = self else { return }
                // Verify the captured entity is still the same (in case it changed)
                // Use the captured entity directly since it's a struct value type
                print("EntitySelectionDialog: Entity button tapped for entity \(capturedEntity) (id: \(entityId), generation: \(entityGeneration))")
                self.onEntitySelected?(capturedEntity)
            }
            
            entityButtons.append(button)
        }
    }
    
    private func getEntityTextureId(entity: Entity, gameLoop: GameLoop) -> String {
        // Get sprite texture ID, but handle directional textures (like belts)
        if let sprite = gameLoop.world.get(SpriteComponent.self, for: entity) {
            var textureId = sprite.textureId
            
            // Handle belt directional textures (e.g., "transport_belt_north_001" -> "transport_belt")
            if textureId.contains("_belt_") {
                let parts = textureId.split(separator: "_")
                if let beltIndex = parts.firstIndex(where: { $0 == "belt" }) {
                    textureId = parts[0...beltIndex].joined(separator: "_")
                }
            }
            
            return textureId
        }
        
        return "solid_white"
    }
    
    private func getEntityName(entity: Entity, gameLoop: GameLoop) -> String {
        // Try to get name from sprite texture
        if let sprite = gameLoop.world.get(SpriteComponent.self, for: entity) {
            // Check for player
            if sprite.textureId == "player" {
                return "Player"
            }
            
            // Handle belt directional textures
            var textureId = sprite.textureId
            if textureId.contains("_belt_") {
                let parts = textureId.split(separator: "_")
                if let beltIndex = parts.firstIndex(where: { $0 == "belt" }) {
                    textureId = parts[0...beltIndex].joined(separator: "_")
                }
            }
            
            // Try to find building by texture
            if let building = gameLoop.buildingRegistry.getByTexture(textureId) {
                return building.name
            }
            
            // Fallback to texture ID
            return textureId.replacingOccurrences(of: "_", with: " ").capitalized
        }
        
        return "Entity"
    }
    
    func open() {
        isOpen = true
    }
    
    func close() {
        isOpen = false
    }
    
    func handleTap(at position: Vector2) -> Bool {
        guard isOpen else { return false }
        
        // Check entity buttons
        for button in entityButtons {
            if button.handleTap(at: position) {
                return true
            }
        }
        
        // Check cancel button
        if cancelButton.handleTap(at: position) {
            return true
        }
        
        // Tap outside dialog - close it
        return true
    }
    
    func update(deltaTime: Float) {
        for button in entityButtons {
            button.update(deltaTime: deltaTime)
        }
        cancelButton.update(deltaTime: deltaTime)
    }
    
    func render(renderer: MetalRenderer) {
        guard isOpen else { return }
        
        // Render background
        let iconSize: Float = 80 * UIScale
        let spacing: Float = 20 * UIScale
        let padding: Float = 40 * UIScale
        
        let cols = min(3, entities.count)
        let rows = (entities.count + cols - 1) / cols
        
        let totalWidth = Float(cols) * iconSize + Float(cols - 1) * spacing + padding * 2
        let totalHeight = Float(rows) * iconSize + Float(rows - 1) * spacing + padding * 2 + 100
        
        let bgRect = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(totalWidth, totalHeight)
        )
        
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: bgRect.center,
            size: bgRect.size,
            textureRect: solidRect,
            color: Color(r: 0.1, g: 0.1, b: 0.15, a: 0.95),
            layer: .ui
        ))
        
        // Render entity buttons
        for button in entityButtons {
            button.render(renderer: renderer)
        }
        
        // Render cancel button
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


