import Foundation
import UIKit

/// Player inventory panel
final class InventoryUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var slots: [InventorySlot] = []
    private var countLabels: [UILabel] = []
    private var closeButton: CloseButton!
    private let slotsPerRow = 10
    private let screenSize: Vector2

    // Machine input mode
    private var machineEntity: Entity?
    private var machineSlotIndex: Int?
    var onMachineInputCompleted: (() -> Void)?

    // Chest inventory mode
    private var chestEntity: Entity?

    // Callbacks for managing UIKit labels
    var onAddLabels: (([UILabel]) -> Void)?
    var onRemoveLabels: (([UILabel]) -> Void)?
    
    init(screenSize: Vector2, gameLoop: GameLoop?) {
        self.screenSize = screenSize

        // Use full screen size for background
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(screenSize.x, screenSize.y)
        )

        super.init(frame: panelFrame)
        self.gameLoop = gameLoop

        setupCloseButton()
        setupSlots()
        setupCountLabels()
    }

    func enterMachineInputMode(entity: Entity, slotIndex: Int) {
        machineEntity = entity
        machineSlotIndex = slotIndex
    }

    func exitMachineInputMode() {
        machineEntity = nil
        machineSlotIndex = nil
    }

    func enterChestMode(entity: Entity) {
        chestEntity = entity
    }

    func exitChestMode() {
        chestEntity = nil
    }

    private func handleChestTransfer(slot: InventorySlot) {
        guard let chestEntity = chestEntity,
              let gameLoop = gameLoop,
              let itemStack = slot.item else { return }

        // Get player and chest inventories
        var playerInventory = gameLoop.player.inventory
        guard var chestInventory = gameLoop.world.get(InventoryComponent.self, for: chestEntity) else { return }

        // Determine which inventory this slot belongs to
        var isPlayerSlot = false
        if slot.index < playerInventory.slots.count {
            isPlayerSlot = true
        }

        if isPlayerSlot {
            // Transfer from player to chest
            // Calculate available space in chest for this item
            var availableSpace = 0
            if chestInventory.canAccept(itemId: itemStack.itemId) {
                // Check existing stacks of same item
                for slot in chestInventory.slots {
                    if let stack = slot, stack.itemId == itemStack.itemId {
                        availableSpace += stack.maxStack - stack.count
                    }
                }
                // Check empty slots
                let emptySlots = chestInventory.slots.filter { $0 == nil }.count
                availableSpace += emptySlots * itemStack.maxStack
            }

            let itemsToTransfer = min(itemStack.count, availableSpace)

            if itemsToTransfer > 0 {
                // Remove from player
                playerInventory.remove(itemId: itemStack.itemId, count: itemsToTransfer)
                gameLoop.player.inventory = playerInventory

                // Add to chest
                let remaining = chestInventory.add(itemId: itemStack.itemId, count: itemsToTransfer)
                if remaining == 0 {  // All items were added
                    gameLoop.world.add(chestInventory, to: chestEntity)
                    AudioManager.shared.playClickSound()
                }
            }
        } else {
            // Transfer from chest to player (adjust slot index for chest inventory)
            let chestSlotIndex = slot.index - playerInventory.slots.count
            guard chestSlotIndex >= 0, chestSlotIndex < chestInventory.slots.count,
                  let chestItemStack = chestInventory.slots[chestSlotIndex] else { return }

            // Calculate available space in player inventory for this item
            var availableSpace = 0
            if playerInventory.canAccept(itemId: chestItemStack.itemId) {
                // Check existing stacks of same item
                for slot in playerInventory.slots {
                    if let stack = slot, stack.itemId == chestItemStack.itemId {
                        availableSpace += stack.maxStack - stack.count
                    }
                }
                // Check empty slots
                let emptySlots = playerInventory.slots.filter { $0 == nil }.count
                availableSpace += emptySlots * chestItemStack.maxStack
            }

            let itemsToTransfer = min(chestItemStack.count, availableSpace)

            if itemsToTransfer > 0 {
                // Remove from chest
                chestInventory.slots[chestSlotIndex]?.count -= itemsToTransfer
                if chestInventory.slots[chestSlotIndex]?.count == 0 {
                    chestInventory.slots[chestSlotIndex] = nil
                }
                gameLoop.world.add(chestInventory, to: chestEntity)

                // Add to player
                let remaining = playerInventory.add(itemId: chestItemStack.itemId, count: itemsToTransfer)
                if remaining == 0 {  // All items were added
                    gameLoop.player.inventory = playerInventory
                    AudioManager.shared.playClickSound()
                }
            }
        }
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

    private func setupCountLabels() {
        for _ in 0..<40 {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 10, weight: UIFont.Weight.bold)
            label.textColor = UIColor.white
            label.textAlignment = NSTextAlignment.right
            label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            label.layer.cornerRadius = 2
            label.layer.masksToBounds = true
            label.translatesAutoresizingMaskIntoConstraints = true
            label.text = ""
            label.isHidden = true
            countLabels.append(label)
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
        guard isOpen, let gameLoop = gameLoop else { return }

        // Determine which inventories to show
        var playerSlots: [ItemStack?] = []
        var chestSlots: [ItemStack?] = []

        playerSlots = gameLoop.player.inventory.slots

        if let chestEntity = chestEntity, let chestInventory = gameLoop.world.get(InventoryComponent.self, for: chestEntity) {
            chestSlots = chestInventory.slots
        }

        // Show both player and chest inventories
        let totalSlots = playerSlots.count + chestSlots.count

        for (index, slot) in slots.enumerated() {
            if index < totalSlots {
                if index < playerSlots.count {
                    // Player inventory slot
                    slot.item = playerSlots[index]
                } else {
                    // Chest inventory slot
                    let chestIndex = index - playerSlots.count
                    slot.item = chestIndex < chestSlots.count ? chestSlots[chestIndex] : nil
                }

                // Update count label
                if index < countLabels.count {
                    let label = countLabels[index]

                    // Position label in bottom-right corner of slot
                    // Calculate position based on slot index in the grid (10 columns x 4 rows)
                    let slotsPerRow = 10
                    let slotSize: Float = 40 * UIScale
                    let slotSpacing: Float = 5 * UIScale

                    // Calculate slot position in grid
                    let row = index / slotsPerRow
                    let col = index % slotsPerRow

                    // Calculate total grid size
                    let totalWidth = Float(slotsPerRow) * slotSize + Float(slotsPerRow - 1) * slotSpacing
                    let totalHeight = 4 * slotSize + 3 * slotSpacing

                    // Calculate grid top-left position (centered on screen)
                    let gridStartX = (screenSize.x - totalWidth) / 2
                    let gridStartY = (screenSize.y - totalHeight) / 2

                    // Calculate this slot's top-left position
                    let slotX = gridStartX + Float(col) * (slotSize + slotSpacing)
                    let slotY = gridStartY + Float(row) * (slotSize + slotSpacing)

                    // Label position: bottom-right corner of slot
                    let labelWidth: Float = 24
                    let labelHeight: Float = 16
                    let labelX = slotX + slotSize - labelWidth
                    let labelY = slotY + slotSize - labelHeight

                    // Convert to UIView coordinates (pixels to points)
                    let scale = UIScreen.main.scale
                    let uiX = CGFloat(labelX) / scale
                    let uiY = CGFloat(labelY) / scale

                    // Set the frame
                    label.frame = CGRect(x: uiX, y: uiY, width: CGFloat(labelWidth), height: CGFloat(labelHeight))

                    // Show label only if item count > 1
                    if let item = slot.item, item.count > 1 {
                        label.text = "\(item.count)"
                        label.isHidden = false
                    } else {
                        label.text = ""
                        label.isHidden = true
                    }
                }
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
                } else if chestEntity != nil {
                    // Chest inventory mode - transfer items between player and chest
                    handleChestTransfer(slot: slot)
                } else {
                    // Normal inventory mode - check if item is a building
                    if let itemStack = slot.item,
                       let gameLoop = gameLoop,
                       gameLoop.buildingRegistry.get(itemStack.itemId) != nil {
                        // It's a building - enter build mode
                        gameLoop.inputManager?.enterBuildMode(buildingId: itemStack.itemId)
                        close() // Close inventory when entering build mode
                    } else {
                        // Not a building - just select the slot
                        // Handle slot selection (could add visual feedback here)
                    }
                }
                return true
            }
        }

        return super.handleTap(at: position)
    }

    override func open() {
        super.open()
        onAddLabels?(countLabels)
    }

    override func close() {
        onRemoveLabels?(countLabels)
        exitMachineInputMode()
        exitChestMode()
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

                // Transfer as many items as possible (up to the entire stack)
                // Calculate available space in machine inventory
                var availableSpace = 0
                for slot in machineInventory.slots {
                    if slot == nil {
                        // Empty slot can hold max stack
                        availableSpace += slotItem.maxStack
                    } else if slot!.itemId == slotItem.itemId {
                        // Existing stack can hold remaining space
                        availableSpace += slot!.maxStack - slot!.count
                    }
                }
                let itemsToTransfer = min(slotItem.count, availableSpace)

                if itemsToTransfer > 0 {
                    // Remove items from player inventory
                    slotItem.count -= itemsToTransfer
                    if slotItem.count == 0 {
                        playerInv.slots[slot.index] = nil
                    } else {
                        playerInv.slots[slot.index] = slotItem
                    }
                    gameLoop.player.inventory = playerInv

                    // Check if machine can accept this item
                    if !machineInventory.canAccept(itemId: slotItem.itemId) {
                        // Machine cannot accept this item - don't transfer
                        return
                    }

                    // Add to machine inventory
                    let itemToAdd = ItemStack(itemId: slotItem.itemId, count: itemsToTransfer)
                    let remaining = machineInventory.add(itemToAdd)
                    gameLoop.world.add(machineInventory, to: machineEntity)

                    // Return any items that couldn't be added back to player (shouldn't happen)
                    if remaining > 0 {
                        gameLoop.player.inventory.add(itemId: slotItem.itemId, count: remaining)
                    }

                    // Signal completion but DON'T close inventory - let player add more items
                    onMachineInputCompleted?()
                    // close() - Removed so inventory stays open for multiple transfers
                }
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

