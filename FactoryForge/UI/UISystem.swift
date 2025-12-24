import UIKit
import Metal

/// Main UI system that manages all UI elements
final class UISystem {
    private weak var gameLoop: GameLoop?
    private weak var renderer: MetalRenderer?
    
    // UI Panels
    private var hud: HUD
    private var inventoryUI: InventoryUI
    private var craftingMenu: CraftingMenu
    private var buildMenu: BuildMenu
    private var researchUI: ResearchUI
    private var machineUI: MachineUI
    
    // Current state
    private(set) var activePanel: UIPanel?
    private(set) var isAnyPanelOpen: Bool = false
    
    // Touch handling
    private var touchedElement: UIElement?
    
    init(gameLoop: GameLoop, renderer: MetalRenderer?) {
        self.gameLoop = gameLoop
        self.renderer = renderer
        
        let screenSize = renderer?.screenSize ?? Vector2(800, 600)
        
        hud = HUD(screenSize: screenSize, gameLoop: gameLoop)
        inventoryUI = InventoryUI(screenSize: screenSize, gameLoop: gameLoop)
        craftingMenu = CraftingMenu(screenSize: screenSize, gameLoop: gameLoop)
        buildMenu = BuildMenu(screenSize: screenSize, gameLoop: gameLoop)
        researchUI = ResearchUI(screenSize: screenSize, gameLoop: gameLoop)
        machineUI = MachineUI(screenSize: screenSize, gameLoop: gameLoop)
        
        setupCallbacks()
    }
    
    private func setupCallbacks() {
        // HUD button callbacks
        hud.onInventoryPressed = { [weak self] in
            self?.togglePanel(.inventory)
        }
        
        hud.onCraftingPressed = { [weak self] in
            self?.togglePanel(.crafting)
        }
        
        hud.onBuildPressed = { [weak self] in
            self?.togglePanel(.build)
        }
        
        hud.onResearchPressed = { [weak self] in
            self?.togglePanel(.research)
        }
        
        // Build menu callbacks
        buildMenu.onBuildingSelected = { [weak self] buildingId in
            self?.gameLoop?.renderer?.gameLoop?.uiSystem?.closeAllPanels()
            // Enter build mode via input manager
        }
    }
    
    // MARK: - Update
    
    func update(deltaTime: Float) {
        hud.update(deltaTime: deltaTime)
        
        if let panel = activePanel {
            switch panel {
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
            }
        }
    }
    
    // MARK: - Rendering
    
    func render(renderer: MetalRenderer) {
        // Render HUD (always visible)
        hud.render(renderer: renderer)
        
        // Render active panel
        if let panel = activePanel {
            switch panel {
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
        }
    }
    
    func closeAllPanels() {
        if let panel = activePanel {
            switch panel {
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
            }
        }
        
        activePanel = nil
        isAnyPanelOpen = false
    }
    
    func openMachineUI(for entity: Entity) {
        machineUI.setEntity(entity)
        openPanel(.machine)
    }
    
    // MARK: - Touch Handling
    
    func handleTap(at screenPos: Vector2) -> Bool {
        // Get current screen size from renderer
        let currentScreenSize = renderer?.screenSize ?? Vector2(800, 600)
        
        // Check HUD first
        if hud.handleTap(at: screenPos, screenSize: currentScreenSize) {
            return true
        }
        
        // Check active panel
        if let panel = activePanel {
            switch panel {
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
            }
            
            // Tap outside panel closes it
            closeAllPanels()
            return true
        }
        
        return false
    }
    
    func handleDrag(from startPos: Vector2, to endPos: Vector2) -> Bool {
        if let panel = activePanel {
            switch panel {
            case .inventory:
                return inventoryUI.handleDrag(from: startPos, to: endPos)
            default:
                return false
            }
        }
        return false
    }
}

// MARK: - UI Types

enum UIPanel {
    case inventory
    case crafting
    case build
    case research
    case machine
}

protocol UIElement {
    var frame: Rect { get }
    func handleTap(at position: Vector2) -> Bool
    func render(renderer: MetalRenderer)
}

// MARK: - Base UI Components

class UIButton: UIElement {
    var frame: Rect
    var textureId: String
    var isEnabled: Bool = true
    var isPressed: Bool = false
    var onTap: (() -> Void)?
    
    init(frame: Rect, textureId: String) {
        self.frame = frame
        self.textureId = textureId
    }
    
    func handleTap(at position: Vector2) -> Bool {
        guard isEnabled && frame.contains(position) else { return false }
        onTap?()
        return true
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

