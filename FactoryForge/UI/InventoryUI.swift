import Foundation

/// Player inventory panel
final class InventoryUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var slots: [InventorySlot] = []
    private var closeButton: CloseButton!
    private let slotsPerRow = 10

    // Machine input mode
    private var machineEntity: Entity?
    private var machineSlotIndex: Int?
    var onMachineInputCompleted: (() -> Void)?
    
    init(screenSize: Vector2, gameLoop: GameLoop?) {
        // Use full screen size for background
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(screenSize.x, screenSize.y)
        )
        
        super.init(frame: panelFrame)
        self.gameLoop = gameLoop

        setupCloseButton()
        setupSlots()
    }

    func enterMachineInputMode(entity: Entity, slotIndex: Int) {
        machineEntity = entity
        machineSlotIndex = slotIndex
    }

    func exitMachineInputMode() {
        machineEntity = nil
        machineSlotIndex = nil
    }

    private func setupSlots() {
        let slotSize: Float = 40 * UIScale
        let slotSpacing: Float = 5 * UIScale
        let totalWidth = Float(slotsPerRow) * slotSize + Float(slotsPerRow - 1) * slotSpacing
        let totalHeight = Float(4) * slotSize + Float(3) * slotSpacing
        let startX = frame.center.x - totalWidth / 2 + slotSize / 2
        let startY = frame.center.y - totalHeight / 2 + slotSize / 2
        
        for i in 0..<40 {
            let row = i / slotsPerRow
            let col = i % slotsPerRow
            
            let slotX = startX + Float(col) * (slotSize + slotSpacing) + slotSize / 2
            let slotY = startY + Float(row) * (slotSize + slotSpacing) + slotSize / 2
            
            slots.append(InventorySlot(
                frame: Rect(center: Vector2(slotX, slotY), size: Vector2(slotSize, slotSize)),
                index: i
            ))
        }
    }

    private func setupCloseButton() {
        let buttonSize: Float = 30 * UIScale
        let buttonX = frame.maxX - 25 * UIScale
        let buttonY = frame.minY + 25 * UIScale

        closeButton = CloseButton(frame: Rect(center: Vector2(buttonX, buttonY), size: Vector2(buttonSize, buttonSize)))
        closeButton.onTap = { [weak self] in
            self?.close()
        }
    }

    override func update(deltaTime: Float) {
        guard isOpen, let player = gameLoop?.player else { return }
        
        for (index, slot) in slots.enumerated() {
            if index < player.inventory.slots.count {
                slot.item = player.inventory.slots[index]
            }
        }
    }
    
    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Render close button
        closeButton.render(renderer: renderer)

        // Render slots
        for slot in slots {
            slot.render(renderer: renderer)
        }
    }
    
    override func handleTap(at position: Vector2) -> Bool {
        guard isOpen else { return false }

        // Check close button first
        if closeButton.handleTap(at: position) {
            return true
        }

        for slot in slots {
            if slot.handleTap(at: position) {
                if machineEntity != nil {
                    // Machine input mode - add item to machine
                    handleMachineInput(slot: slot)
                } else {
                    // Normal inventory mode - just select
                    // Handle slot selection
                }
                return true
            }
        }

        return super.handleTap(at: position)
    }

    override func close() {
        exitMachineInputMode()
        super.close()
    }

    private func handleMachineInput(slot: InventorySlot) {
        guard let gameLoop = gameLoop,
              let machineEntity = machineEntity,
              let itemStack = slot.item,
              itemStack.count > 0,
              var machineInventory = gameLoop.world.get(InventoryComponent.self, for: machineEntity) else {
            return
        }

        // Check if machine can accept this item
        if machineInventory.canAccept(itemId: itemStack.itemId) {
            // Remove one item from player inventory at this slot
            var playerInv = gameLoop.player.inventory
            if slot.index < playerInv.slots.count,
               var slotItem = playerInv.slots[slot.index],
               slotItem.count > 0 {

                // Take one item
                slotItem.count -= 1
                if slotItem.count == 0 {
                    playerInv.slots[slot.index] = nil
                } else {
                    playerInv.slots[slot.index] = slotItem
                }
                gameLoop.player.inventory = playerInv

                // Add to machine inventory
                let itemToAdd = ItemStack(itemId: slotItem.itemId, count: 1)
                let remaining = machineInventory.add(itemToAdd)
                gameLoop.world.add(machineInventory, to: machineEntity)

                // Return any items that couldn't be added back to player (shouldn't happen)
                if remaining > 0 {
                    gameLoop.player.inventory.add(itemId: slotItem.itemId, count: remaining)
                }

                // Signal completion and close inventory
                onMachineInputCompleted?()
                close()
            }
        }
    }

    func getTooltip(at position: Vector2) -> String? {
        guard isOpen else { return nil }

        for slot in slots {
            if slot.frame.contains(position), let item = slot.item, let itemRegistry = gameLoop?.itemRegistry {
                return itemRegistry.get(item.itemId)?.name ?? item.itemId
            }
        }

        return nil
    }
}

class InventorySlot: UIElement {
    var frame: Rect
    let index: Int
    var item: ItemStack?
    var isSelected: Bool = false
    
    init(frame: Rect, index: Int) {
        self.frame = frame
        self.index = index
    }
    
    func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }
        isSelected = true
        return true
    }
    
    func render(renderer: MetalRenderer) {
        // Slot background
        let bgColor = isSelected ?
            Color(r: 0.3, g: 0.3, b: 0.4, a: 1) :
            Color(r: 0.2, g: 0.2, b: 0.25, a: 1)
        
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: solidRect,
            color: bgColor,
            layer: .ui
        ))
        
        // Item
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

