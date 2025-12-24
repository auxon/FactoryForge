import Foundation

/// Heads-up display showing vital game info
final class HUD {
    private let screenSize: Vector2
    private weak var gameLoop: GameLoop?
    
    // Buttons
    private var inventoryButton: UIButton
    private var craftingButton: UIButton
    private var buildButton: UIButton
    private var researchButton: UIButton
    
    // Quick bar slots
    private var quickBarSlots: [QuickBarSlot] = []
    
    // Callbacks
    var onInventoryPressed: (() -> Void)?
    var onCraftingPressed: (() -> Void)?
    var onBuildPressed: (() -> Void)?
    var onResearchPressed: (() -> Void)?
    
    init(screenSize: Vector2, gameLoop: GameLoop?) {
        self.screenSize = screenSize
        self.gameLoop = gameLoop
        
        let buttonSize: Float = 60
        let buttonSpacing: Float = 10
        let bottomMargin: Float = 20
        
        // Create bottom toolbar buttons
        let toolbarY = screenSize.y - bottomMargin - buttonSize / 2
        var currentX = screenSize.x / 2 - (buttonSize * 2 + buttonSpacing * 1.5)
        
        inventoryButton = UIButton(
            frame: Rect(center: Vector2(currentX, toolbarY), size: Vector2(buttonSize, buttonSize)),
            textureId: "chest"
        )
        currentX += buttonSize + buttonSpacing
        
        craftingButton = UIButton(
            frame: Rect(center: Vector2(currentX, toolbarY), size: Vector2(buttonSize, buttonSize)),
            textureId: "gear"
        )
        currentX += buttonSize + buttonSpacing
        
        buildButton = UIButton(
            frame: Rect(center: Vector2(currentX, toolbarY), size: Vector2(buttonSize, buttonSize)),
            textureId: "assembler"
        )
        currentX += buttonSize + buttonSpacing
        
        researchButton = UIButton(
            frame: Rect(center: Vector2(currentX, toolbarY), size: Vector2(buttonSize, buttonSize)),
            textureId: "lab"
        )
        
        // Setup button callbacks
        inventoryButton.onTap = { [weak self] in self?.onInventoryPressed?() }
        craftingButton.onTap = { [weak self] in self?.onCraftingPressed?() }
        buildButton.onTap = { [weak self] in self?.onBuildPressed?() }
        researchButton.onTap = { [weak self] in self?.onResearchPressed?() }
        
        // Create quick bar slots
        let slotSize: Float = 50
        let quickBarY = screenSize.y - bottomMargin - buttonSize - buttonSpacing - slotSize / 2
        let quickBarStartX = screenSize.x / 2 - (slotSize * 5 + buttonSpacing * 4) / 2
        
        for i in 0..<10 {
            let slotX = quickBarStartX + Float(i) * (slotSize + buttonSpacing / 2)
            quickBarSlots.append(QuickBarSlot(
                frame: Rect(center: Vector2(slotX, quickBarY), size: Vector2(slotSize, slotSize)),
                index: i
            ))
        }
    }
    
    func update(deltaTime: Float) {
        // Update quick bar from player inventory
        if let player = gameLoop?.player {
            for (index, slot) in quickBarSlots.enumerated() {
                if index < player.inventory.slots.count {
                    slot.item = player.inventory.slots[index]
                }
            }
        }
    }
    
    func render(renderer: MetalRenderer) {
        // Render buttons
        inventoryButton.render(renderer: renderer)
        craftingButton.render(renderer: renderer)
        buildButton.render(renderer: renderer)
        researchButton.render(renderer: renderer)
        
        // Render quick bar
        for slot in quickBarSlots {
            slot.render(renderer: renderer)
        }
        
        // Render health bar
        renderHealthBar(renderer: renderer)
        
        // Render minimap
        renderMinimap(renderer: renderer)
        
        // Render resource counters
        renderResourceCounters(renderer: renderer)
    }
    
    private func renderHealthBar(renderer: MetalRenderer) {
        guard let player = gameLoop?.player else { return }
        
        let barWidth: Float = 200
        let barHeight: Float = 20
        let margin: Float = 20
        let barX = margin + barWidth / 2
        let barY = margin + barHeight / 2
        
        // Background
        renderer.queueSprite(SpriteInstance(
            position: Vector2(barX, barY),
            size: Vector2(barWidth, barHeight),
            color: Color(r: 0.2, g: 0.2, b: 0.2, a: 0.8),
            layer: .ui
        ))
        
        // Health fill
        let healthPercent = player.health / player.maxHealth
        let fillWidth = barWidth * healthPercent
        renderer.queueSprite(SpriteInstance(
            position: Vector2(margin + fillWidth / 2, barY),
            size: Vector2(fillWidth, barHeight - 4),
            color: Color(r: 0.8, g: 0.2, b: 0.2, a: 1),
            layer: .ui
        ))
    }
    
    private func renderMinimap(renderer: MetalRenderer) {
        let minimapSize: Float = 150
        let margin: Float = 20
        let minimapCenter = Vector2(screenSize.x - margin - minimapSize / 2, margin + minimapSize / 2)
        
        // Background
        renderer.queueSprite(SpriteInstance(
            position: minimapCenter,
            size: Vector2(minimapSize, minimapSize),
            color: Color(r: 0.1, g: 0.15, b: 0.1, a: 0.8),
            layer: .ui
        ))
        
        // Player dot
        renderer.queueSprite(SpriteInstance(
            position: minimapCenter,
            size: Vector2(6, 6),
            color: Color(r: 1, g: 1, b: 1, a: 1),
            layer: .ui
        ))
    }
    
    private func renderResourceCounters(renderer: MetalRenderer) {
        // Resource counters in top left
        let resources = ["iron-plate", "copper-plate", "coal", "stone"]
        let counterY: Float = 60
        var currentX: Float = 20
        
        guard let player = gameLoop?.player else { return }
        
        for resourceId in resources {
            let count = player.inventory.count(of: resourceId)
            
            // Icon
            let textureRect = renderer.textureAtlas.getTextureRect(for: resourceId.replacingOccurrences(of: "-", with: "_"))
            renderer.queueSprite(SpriteInstance(
                position: Vector2(currentX + 15, counterY),
                size: Vector2(30, 30),
                textureRect: textureRect,
                layer: .ui
            ))
            
            currentX += 80
        }
    }
    
    func handleTap(at position: Vector2) -> Bool {
        if inventoryButton.handleTap(at: position) { return true }
        if craftingButton.handleTap(at: position) { return true }
        if buildButton.handleTap(at: position) { return true }
        if researchButton.handleTap(at: position) { return true }
        
        for slot in quickBarSlots {
            if slot.handleTap(at: position) { return true }
        }
        
        return false
    }
}

// MARK: - Quick Bar Slot

class QuickBarSlot: UIElement {
    var frame: Rect
    let index: Int
    var item: ItemStack?
    
    init(frame: Rect, index: Int) {
        self.frame = frame
        self.index = index
    }
    
    func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }
        // Select this slot's item
        return true
    }
    
    func render(renderer: MetalRenderer) {
        // Slot background
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            color: Color(r: 0.15, g: 0.15, b: 0.2, a: 0.9),
            layer: .ui
        ))
        
        // Item if present
        if let item = item {
            let textureRect = renderer.textureAtlas.getTextureRect(for: item.itemId.replacingOccurrences(of: "-", with: "_"))
            renderer.queueSprite(SpriteInstance(
                position: frame.center,
                size: frame.size * 0.8,
                textureRect: textureRect,
                layer: .ui
            ))
        }
    }
}

