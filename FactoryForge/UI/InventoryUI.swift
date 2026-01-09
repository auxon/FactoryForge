import Foundation
import UIKit

/// Player inventory panel
final class InventoryUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var slots: [InventorySlot] = []
    private var countLabels: [UILabel] = []
    private var closeButton: CloseButton!
    private var trashTarget: UIButton!
    private let slotsPerRow = 8
    private let maxSlots = 64  // Maximum slots for player inventory (supports expansion)
    private let screenSize: Vector2

    // Machine input mode
    private var machineEntity: Entity?
    private var machineSlotIndex: Int?
    var onMachineInputCompleted: (() -> Void)?

    // Chest inventory mode
    private var chestEntity: Entity?

    // Chest-only mode - when showing only chest inventory
    private var chestOnlyEntity: Entity?

    // Pending chest transfer mode - when selecting items to transfer to a chest
    private var pendingChestEntity: Entity?

    // Current number of slots to display
    private var totalSlots = 48

    // Drag and drop state
    private var draggedItemStack: ItemStack?
    private var draggedSlotIndex: Int?
    private var isDragging = false
    private var dragPreviewPosition: Vector2 = .zero

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
        setupTrashTarget()
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

    func enterChestOnlyMode(entity: Entity) {
        chestOnlyEntity = entity
    }

    func exitChestOnlyMode() {
        chestOnlyEntity = nil
    }

    func enterPendingChestMode(entity: Entity) {
        pendingChestEntity = entity
    }

    func exitPendingChestMode() {
        pendingChestEntity = nil
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

    private func handleChestOnlyInteraction(slot: InventorySlot) {
        guard let chestOnlyEntity = chestOnlyEntity,
              let gameLoop = gameLoop else { return }

        let chestInventory = gameLoop.world.get(InventoryComponent.self, for: chestOnlyEntity)
        guard var chestInventory = chestInventory else { return }

        let slotIndex = slot.index

        // Bounds check - make sure slotIndex is valid for this chest
        guard slotIndex < chestInventory.slots.count else { return }

        if let chestItemStack = chestInventory.slots[slotIndex] {
            // Filled chest slot - transfer to player
            var playerInventory = gameLoop.player.inventory

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
                chestInventory.slots[slotIndex]?.count -= itemsToTransfer
                if chestInventory.slots[slotIndex]?.count == 0 {
                    chestInventory.slots[slotIndex] = nil
                }
                gameLoop.world.add(chestInventory, to: chestOnlyEntity)

                // Add to player
                let remaining = playerInventory.add(itemId: chestItemStack.itemId, count: itemsToTransfer)
                if remaining == 0 {  // All items were added
                    gameLoop.player.inventory = playerInventory
                    AudioManager.shared.playClickSound()
                }
            }
        } else {
            // Empty chest slot - open player inventory for item selection
            print("InventoryUI: Empty chest slot clicked, opening player inventory for selection")
            enterPendingChestMode(entity: chestOnlyEntity)
            exitChestOnlyMode()
        }
    }

    private func handlePendingChestTransfer(slot: InventorySlot) {
        guard let pendingChestEntity = pendingChestEntity,
              let gameLoop = gameLoop,
              let itemStack = slot.item else { return }

        // Get player and chest inventories
        var playerInventory = gameLoop.player.inventory
        guard var chestInventory = gameLoop.world.get(InventoryComponent.self, for: pendingChestEntity) else { return }

        // Determine if this is a player slot (should be, since we're in pending chest mode)
        let isPlayerSlot = slot.index < playerInventory.slots.count
        guard isPlayerSlot else { return }

        // Transfer from player to chest
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
                gameLoop.world.add(chestInventory, to: pendingChestEntity)
                AudioManager.shared.playClickSound()
            }
        }
    }

    private func setupSlots() {
        let slotSize: Float = 40 * UIScale
        let slotSpacing: Float = 5 * UIScale
        let rows = (maxSlots + slotsPerRow - 1) / slotsPerRow  // Calculate rows needed
        let totalWidth = Float(slotsPerRow) * slotSize + Float(slotsPerRow - 1) * slotSpacing
        let totalHeight = Float(rows) * slotSize + Float(rows - 1) * slotSpacing
        let startX = frame.center.x - totalWidth / 2 + slotSize / 2
        let startY = frame.center.y - totalHeight / 2 + slotSize / 2

        for i in 0..<maxSlots {
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
        for _ in 0..<maxSlots {
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

    private func setupTrashTarget() {
        let trashSize: Float = 60 * UIScale
        let slotSize: Float = 40 * UIScale
        let slotSpacing: Float = 5 * UIScale
        let rows = (maxSlots + slotsPerRow - 1) / slotsPerRow
        let totalWidth = Float(slotsPerRow) * slotSize + Float(slotsPerRow - 1) * slotSpacing
        let gridStartX = (screenSize.x - totalWidth) / 2

        // Position trash to the right of the inventory grid
        let trashX = gridStartX + totalWidth + 30 * UIScale + trashSize / 2
        let trashY = (screenSize.y - Float(rows) * (slotSize + slotSpacing) + slotSpacing) / 2 + trashSize / 2

        trashTarget = UIButton(
            frame: Rect(center: Vector2(trashX, trashY), size: Vector2(trashSize, trashSize)),
            textureId: "trash"
        )

        trashTarget.onTap = { [weak self] in
            // Trash can be tapped but no action needed - drag and drop only
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

        if let chestOnlyEntity = chestOnlyEntity, let chestInventory = gameLoop.world.get(InventoryComponent.self, for: chestOnlyEntity) {
            chestSlots = chestInventory.slots
        }

        // Determine total slots to show
        self.totalSlots = playerSlots.count
        if chestEntity != nil {
            // Chest mode - show both player and chest
            self.totalSlots += chestSlots.count
        } else if chestOnlyEntity != nil {
            // Chest-only mode - show only chest slots
            self.totalSlots = chestSlots.count
        } else if pendingChestEntity != nil {
            // Pending chest mode - show player slots for item selection
            self.totalSlots = playerSlots.count
        }

        for (index, slot) in slots.enumerated() {
            if index < totalSlots {
                if chestEntity != nil && index >= playerSlots.count {
                    // Chest inventory slot (only in chest mode, not pending chest mode)
                    let chestIndex = index - playerSlots.count
                    slot.item = chestIndex < chestSlots.count ? chestSlots[chestIndex] : nil
                } else if chestOnlyEntity != nil {
                    // Chest-only mode - all slots show chest inventory
                    slot.item = index < chestSlots.count ? chestSlots[index] : nil
                } else {
                    // Player inventory slot (normal mode or pending chest mode)
                    slot.item = index < playerSlots.count ? playerSlots[index] : nil
                }
            } else {
                // Clear slots beyond totalSlots
                slot.item = nil
            }

                // Update count label
                if index < countLabels.count && index < totalSlots {
                    let label = countLabels[index]

                    // Position label in bottom-right corner of slot
                    let slotSize: Float = 40 * UIScale
                    let slotSpacing: Float = 5 * UIScale
                    let rows = (maxSlots + self.slotsPerRow - 1) / self.slotsPerRow

                    // Calculate slot position in grid
                    let row = index / self.slotsPerRow
                    let col = index % self.slotsPerRow

                    // Calculate total grid size
                    let totalWidth = Float(self.slotsPerRow) * slotSize + Float(self.slotsPerRow - 1) * slotSpacing
                    let totalHeight = Float(rows) * slotSize + Float(rows - 1) * slotSpacing

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

    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Render close button
        closeButton.render(renderer: renderer)

        // Render slots (only up to totalSlots)
        for (index, slot) in slots.enumerated() {
            if index < totalSlots {
                slot.render(renderer: renderer)
            }
        }

        // Render trash target
        trashTarget.render(renderer: renderer)

        // Render drag preview
        if isDragging, let draggedItem = draggedItemStack {
            let textureRect = renderer.textureAtlas.getTextureRect(for: draggedItem.itemId.replacingOccurrences(of: "-", with: "_"))
            let previewSize = Vector2(50, 50) // Slightly larger than slot size for visibility
            renderer.queueSprite(SpriteInstance(
                position: dragPreviewPosition,
                size: previewSize,
                textureRect: textureRect,
                color: Color(r: 1, g: 1, b: 1, a: 0.8), // Semi-transparent
                layer: .ui
            ))
        }
    }
    
    override func handleTap(at position: Vector2) -> Bool {
        guard isOpen else { return false }

        // Check close button first
        if closeButton.handleTap(at: position) {
            return true
        }

        for (index, slot) in slots.enumerated() {
            if index < totalSlots && slot.handleTap(at: position) {
                if machineEntity != nil {
                    // Machine input mode - add item to machine
                    handleMachineInput(slot: slot)
                } else if chestEntity != nil {
                    // Chest inventory mode - transfer items between player and chest
                    handleChestTransfer(slot: slot)
                } else if chestOnlyEntity != nil {
                    // Chest-only mode - handle chest slot interactions
                    handleChestOnlyInteraction(slot: slot)
                } else if pendingChestEntity != nil {
                    // Pending chest transfer mode - transfer items from player to chest
                    handlePendingChestTransfer(slot: slot)
                } else {
                    // Normal inventory mode - check if item can be placed as a building
                    if let itemStack = slot.item,
                       let gameLoop = gameLoop,
                       let itemDef = gameLoop.itemRegistry.get(itemStack.itemId),
                       let buildingId = itemDef.placedAs,
                       gameLoop.buildingRegistry.get(buildingId) != nil {
                        // It's a placeable building - enter build mode
                        gameLoop.inputManager?.enterBuildMode(buildingId: buildingId)
                        close() // Close inventory when entering build mode
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
        exitChestOnlyMode()
        exitPendingChestMode()
        endDrag() // Reset drag state
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
                    let itemToAdd = ItemStack(itemId: slotItem.itemId, count: itemsToTransfer, maxStack: slotItem.maxStack)
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

    override func handleDrag(from startPos: Vector2, to endPos: Vector2) -> Bool {
        dragPreviewPosition = endPos

        // Check if drag started from an inventory slot
        if !isDragging {
            // Find which slot the drag started from
            for (index, slot) in slots.enumerated() {
                if index < totalSlots && slot.frame.contains(startPos), let itemStack = slot.item {
                    isDragging = true
                    draggedSlotIndex = index
                    draggedItemStack = itemStack
                    return true
                }
            }
        } else {
            // Handle ongoing drag
            // Check if drag ended on trash
            if trashTarget.frame.contains(endPos), let draggedIndex = draggedSlotIndex {
                // Drop on trash - remove the item
                handleTrashDrop(slotIndex: draggedIndex)
                endDrag()
                return true
            }
        }

        return false
    }

    private func handleTrashDrop(slotIndex: Int) {
        guard let gameLoop = gameLoop else { return }

        // Only allow trashing from player inventory slots (not chest inventory)
        guard slotIndex < gameLoop.player.inventory.slots.count else { return }

        var playerInventory = gameLoop.player.inventory

        // Remove the item stack from the slot
        if let itemStack = playerInventory.slots[slotIndex] {
            playerInventory.slots[slotIndex] = nil
            gameLoop.player.inventory = playerInventory

            // Play sound effect
            AudioManager.shared.playClickSound()

            print("Trashed \(itemStack.count) \(itemStack.itemId)")
        }
    }

    private func endDrag() {
        isDragging = false
        draggedSlotIndex = nil
        draggedItemStack = nil
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

