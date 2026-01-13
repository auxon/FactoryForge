import Foundation
import UIKit

/// Player inventory panel
final class InventoryUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var slots: [InventorySlot] = []
    private var countLabels: [UILabel] = []
    private var closeButton: CloseButton!
    private var trashTarget: UIButton!
    private var scrollView: UIScrollView!

    // Public accessor for scroll view (needed for touch event handling)
    var publicScrollView: UIScrollView? {
        return scrollView
    }

    // Ensure scroll view exists (creates it if needed)
    private func ensureScrollView() {
        if scrollView == nil {
            setupSlots()
        }
    }
    private let slotsPerRow = 10
    private let maxSlots = 200  // Maximum slots for player inventory (supports expansion)
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

    // Current number of slots to display (will be set dynamically based on player inventory)
    private var totalSlots = 70

    // Callbacks for managing UIKit components
    var onAddLabels: (([UILabel]) -> Void)?
    var onRemoveLabels: (([UILabel]) -> Void)?
    var onAddScrollView: ((UIScrollView) -> Void)?
    var onRemoveScrollView: ((UIScrollView) -> Void)?
    
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
        // Don't create scrollview here - wait until panel is opened
        // setupSlots()
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
                let remaining: Int
                if let itemDef = gameLoop.itemRegistry.get(itemStack.itemId) {
                    remaining = chestInventory.add(itemId: itemStack.itemId, count: itemsToTransfer, maxStack: itemDef.stackSize)
                } else {
                    remaining = chestInventory.add(itemId: itemStack.itemId, count: itemsToTransfer, maxStack: 100) // fallback
                }
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
                let remaining: Int
                if let itemDef = gameLoop.itemRegistry.get(chestItemStack.itemId) {
                    remaining = playerInventory.add(itemId: chestItemStack.itemId, count: itemsToTransfer, maxStack: itemDef.stackSize)
                } else {
                    remaining = playerInventory.add(itemId: chestItemStack.itemId, count: itemsToTransfer, maxStack: 100) // fallback
                }
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
                let remaining: Int
                if let itemDef = gameLoop.itemRegistry.get(chestItemStack.itemId) {
                    remaining = playerInventory.add(itemId: chestItemStack.itemId, count: itemsToTransfer, maxStack: itemDef.stackSize)
                } else {
                    remaining = playerInventory.add(itemId: chestItemStack.itemId, count: itemsToTransfer, maxStack: 100) // fallback
                }
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
            let remaining: Int
            if let itemDef = gameLoop.itemRegistry.get(itemStack.itemId) {
                remaining = chestInventory.add(itemId: itemStack.itemId, count: itemsToTransfer, maxStack: itemDef.stackSize)
            } else {
                remaining = chestInventory.add(itemId: itemStack.itemId, count: itemsToTransfer, maxStack: 100) // fallback
            }
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

        // Create scrollview with reasonable dimensions
        let scale = UIScreen.main.scale
        let scrollViewHeight: CGFloat = CGFloat(220) * CGFloat(UIScale) // Show about 5 rows at a time
        let scrollViewWidth: CGFloat = CGFloat(screenSize.x) / scale * 0.9 // 90% of screen width

        // Position scroll view centered horizontally, with some top margin for close button
        let topMargin: CGFloat = CGFloat(60) * CGFloat(UIScale) // Space for close button
        let scrollViewY = topMargin + scrollViewHeight / 2
        let scrollViewX = CGFloat(screenSize.x) / scale / 2  // Center horizontally


        scrollView = UIScrollView(frame: CGRect(
            x: scrollViewX - scrollViewWidth / 2,
            y: scrollViewY - scrollViewHeight / 2,
            width: scrollViewWidth,
            height: scrollViewHeight
        ))

        // Content size in points (UIKit coordinates)
        let contentWidthPoints = max(CGFloat(totalWidth) / scale, scrollViewWidth)
        let contentHeightPoints = CGFloat(totalHeight) / scale
        scrollView.contentSize = CGSize(width: contentWidthPoints, height: contentHeightPoints)

        // Center the content initially if it's wider than the scrollview
        if contentWidthPoints > scrollViewWidth {
            let centerOffset = (contentWidthPoints - scrollViewWidth) / 2
            scrollView.contentOffset = CGPoint(x: centerOffset, y: 0)
        } else {
            scrollView.contentOffset = .zero
        }
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isScrollEnabled = true
        scrollView.alwaysBounceVertical = true
        scrollView.delaysContentTouches = false

        // Position slots within the scrollview - initial setup, positioning handled in update()

        for i in 0..<maxSlots {
            // Initial positioning at origin - will be updated in update() method
            slots.append(InventorySlot(
                frame: Rect(center: Vector2(0, 0), size: Vector2(slotSize, slotSize)),
                index: i
            ))
        }

        // Add scrollview to UI
        onAddScrollView?(scrollView)
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

        // Position trash in bottom right corner of the panel
        let margin: Float = 25 * UIScale
        let trashX = frame.maxX - margin - trashSize / 2
        let trashY = frame.maxY - margin - trashSize / 2

        trashTarget = UIButton(
            frame: Rect(center: Vector2(trashX, trashY), size: Vector2(trashSize, trashSize)),
            textureId: "trash"
        )

        trashTarget.onTap = {
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
            // Also notify UISystem to update panel state
            self?.gameLoop?.uiSystem?.closeAllPanels()
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
        let playerInventorySize = playerSlots.count
        self.totalSlots = playerInventorySize
        if chestEntity != nil {
            // Chest mode - show both player and chest
            self.totalSlots += chestSlots.count
        } else if chestOnlyEntity != nil {
            // Chest-only mode - show only chest slots
            self.totalSlots = chestSlots.count
        } else if pendingChestEntity != nil {
            // Pending chest mode - show player slots for item selection
            self.totalSlots = playerInventorySize
        }

        // Update scrollview content size based on actual slots needed
        let rows = (totalSlots + slotsPerRow - 1) / slotsPerRow
        let slotSize: Float = 40 * UIScale
        let slotSpacing: Float = 5 * UIScale
        let totalWidth = Float(slotsPerRow) * slotSize + Float(slotsPerRow - 1) * slotSpacing
        let totalHeight = Float(rows) * slotSize + Float(rows - 1) * slotSpacing

        // Content size in points (UIKit coordinates)
        let scale = UIScreen.main.scale
        let contentWidthPoints = max(CGFloat(totalWidth) / scale, scrollView?.frame.width ?? 0)
        let contentHeightPoints = CGFloat(totalHeight) / scale
        scrollView?.contentSize = CGSize(width: contentWidthPoints, height: contentHeightPoints)

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

                    // Position label relative to slot within scrollview
                    let slotSize: Float = 40 * UIScale
                    let slotSpacing: Float = 5 * UIScale

                    // Calculate slot position in scrollview content (same as setupSlots)
                    let row = index / self.slotsPerRow
                    let col = index % self.slotsPerRow

                    // Center slots within the scroll view's visible width
                    let scale = UIScreen.main.scale
                    let scrollViewWidthPixels = Float(scrollView?.frame.width ?? 0) * Float(scale)  // Convert points to pixels
                    let totalWidth = Float(self.slotsPerRow) * slotSize + Float(self.slotsPerRow - 1) * slotSpacing

                    // If slots are narrower than scroll view, center them. Otherwise, start from left edge.
                    let gridStartX: Float
                    if totalWidth < scrollViewWidthPixels {
                        // Center within scroll view
                        gridStartX = (scrollViewWidthPixels - totalWidth) / 2 + slotSize / 2
                    } else {
                        // Start from left edge
                        gridStartX = slotSize / 2
                    }


                    let slotX = gridStartX + Float(col) * (slotSize + slotSpacing)
                    let slotY = slotSize / 2 + Float(row) * (slotSize + slotSpacing)

                    // Position slots in scrollview content space (UIKit manages scrolling)
                    let contentX = slotX
                    let contentY = slotY

                    // Update slot frame (in content space)
                    slot.frame = Rect(center: Vector2(contentX, contentY), size: Vector2(slotSize, slotSize))

                    // Label position: bottom-right corner of slot (use same scrolled coordinates as rendered slot)
                    if let scrollView = scrollView {
                        // Calculate scroll offset for positioning
                        let scrollOffsetX = Float(scrollView.contentOffset.x) * Float(scale)
                        let scrollOffsetY = Float(scrollView.contentOffset.y) * Float(scale)
                        let scrollOffset = Vector2(scrollOffsetX, scrollOffsetY)

                        let labelWidth: Float = 24
                        let labelHeight: Float = 16
                        let scrolledFrame = Rect(
                            center: slot.frame.center - scrollOffset,
                            size: slot.frame.size
                        )
                        let labelX = scrolledFrame.center.x + scrolledFrame.size.x/2 - labelWidth - 5
                        let labelY = scrolledFrame.center.y + scrolledFrame.size.y/2 - labelHeight - 5

                        // Convert to UIView coordinates (pixels to points) relative to panel
                        let uiX = CGFloat(labelX) / scale
                        let uiY = CGFloat(labelY) / scale

                        // Set the frame relative to panel
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

        // Render slots (only up to totalSlots and within visible scrollview content area)
        if let scrollView = scrollView {
            // Calculate visible content area accounting for scroll offset
            let visibleRect = Rect(
                center: Vector2(
                    Float(scrollView.contentOffset.x + scrollView.bounds.midX) * Float(UIScreen.main.scale),
                    Float(scrollView.contentOffset.y + scrollView.bounds.midY) * Float(UIScreen.main.scale)
                ),
                size: Vector2(
                    Float(scrollView.bounds.width) * Float(UIScreen.main.scale),
                    Float(scrollView.bounds.height) * Float(UIScreen.main.scale)
                )
            )

            // Calculate scroll offset for Metal rendering
            let scrollOffset = Vector2(
                Float(scrollView.contentOffset.x) * Float(UIScreen.main.scale),
                Float(scrollView.contentOffset.y) * Float(UIScreen.main.scale)
            )

            for (index, slot) in slots.enumerated() {
                if index < totalSlots && visibleRect.intersects(slot.frame) {
                    // Render slot with scroll offset applied to align with UIKit scrolling
                    let scrolledFrame = Rect(
                        center: slot.frame.center - scrollOffset,
                        size: slot.frame.size
                    )
                    slot.render(renderer: renderer, frameOverride: scrolledFrame)
                }
            }
        }

        // Render trash target
        trashTarget.render(renderer: renderer)
    }
    
    override func handleTap(at position: Vector2) -> Bool {
        guard isOpen, let scrollView = scrollView else { return false }

        // Check close button first (stays in panel space)
        if closeButton.handleTap(at: position) {
            return true
        }

        let scale = Float(UIScreen.main.scale)

        // Convert screen → scroll content coordinates
        let contentPos = Vector2(
            position.x - Float(scrollView.frame.origin.x) * scale + Float(scrollView.contentOffset.x) * scale,
            position.y - Float(scrollView.frame.origin.y) * scale + Float(scrollView.contentOffset.y) * scale
        )

        for (index, slot) in slots.enumerated() {
            if index < totalSlots && slot.handleTap(at: contentPos) {
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
                    // Normal inventory mode - building placement is handled via Build Menu only
                    // Placeable items in inventory are just managed as regular items
                }
                return true
            }
        }

        return super.handleTap(at: position)
    }

    override func open() {
        super.open()
        // Create scrollview now that callbacks are set up
        if scrollView == nil {
            setupSlots()
        }
        // Add labels to the UIKit view hierarchy via callback
        onAddLabels?(countLabels)
    }

    override func close() {
        // Remove labels from UIKit view hierarchy via callback
        onRemoveLabels?(countLabels)
        if scrollView != nil {
            onRemoveScrollView?(scrollView)
            scrollView = nil
        }
        exitMachineInputMode()
        exitChestMode()
        exitChestOnlyMode()
        exitPendingChestMode()
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
                        if let itemDef = gameLoop.itemRegistry.get(slotItem.itemId) {
                            gameLoop.player.inventory.add(itemId: slotItem.itemId, count: remaining, maxStack: itemDef.stackSize)
                        } else {
                            gameLoop.player.inventory.add(itemId: slotItem.itemId, count: remaining, maxStack: 100) // fallback
                        }
                    }

                    // Signal completion but DON'T close inventory - let player add more items
                    onMachineInputCompleted?()
                    // close() - Removed so inventory stays open for multiple transfers
                }
            }
        }
    }

    override func handleDrag(from startPos: Vector2, to endPos: Vector2) -> Bool {
        // Drag and drop disabled for now while fixing scrollView issues
        return false
    }

    private func handleInventoryDrop(fromSlotIndex: Int, toSlotIndex: Int) {
        guard let gameLoop = gameLoop else { return }

        // Determine which inventories are involved
        let playerSlotsCount = gameLoop.player.inventory.slots.count

        // Check if we're in chest mode
        let isChestMode = chestEntity != nil || chestOnlyEntity != nil || pendingChestEntity != nil

        if isChestMode {
            // Handle chest inventory drag and drop
            handleChestInventoryDrop(fromSlotIndex: fromSlotIndex, toSlotIndex: toSlotIndex, playerSlotsCount: playerSlotsCount)
        } else {
            // Handle player-only inventory drag and drop
            handlePlayerInventoryDrop(fromSlotIndex: fromSlotIndex, toSlotIndex: toSlotIndex)
        }
    }

    private func handlePlayerInventoryDrop(fromSlotIndex: Int, toSlotIndex: Int) {
        guard let gameLoop = gameLoop else { return }
        guard fromSlotIndex < gameLoop.player.inventory.slots.count,
              toSlotIndex < gameLoop.player.inventory.slots.count else { return }

        var playerInventory = gameLoop.player.inventory

        let sourceStack = playerInventory.slots[fromSlotIndex]
        let destStack = playerInventory.slots[toSlotIndex]


        if sourceStack == nil {
            // Nothing to move
            return
        }

        if destStack == nil {
            // Move to empty slot
            playerInventory.slots[toSlotIndex] = sourceStack
            playerInventory.slots[fromSlotIndex] = nil
        } else if destStack!.itemId == sourceStack!.itemId {
            // Combine stacks of same item - use correct maxStack from ItemRegistry
            let maxStack = gameLoop.itemRegistry.get(sourceStack!.itemId)?.stackSize ?? sourceStack!.maxStack
            let totalItems = destStack!.count + sourceStack!.count
            let itemsInDest = min(totalItems, maxStack)
            let remainingItems = totalItems - itemsInDest

            if itemsInDest > 0 {
                playerInventory.slots[toSlotIndex] = ItemStack(itemId: destStack!.itemId, count: itemsInDest, maxStack: maxStack)
            }

            if remainingItems > 0 {
                playerInventory.slots[fromSlotIndex] = ItemStack(itemId: sourceStack!.itemId, count: remainingItems, maxStack: maxStack)
            } else {
                playerInventory.slots[fromSlotIndex] = nil
            }
        } else {
            // Swap different items
            playerInventory.slots[toSlotIndex] = sourceStack
            playerInventory.slots[fromSlotIndex] = destStack
        }

        gameLoop.player.inventory = playerInventory
        AudioManager.shared.playClickSound()
    }

    private func handleChestInventoryDrop(fromSlotIndex: Int, toSlotIndex: Int, playerSlotsCount: Int) {
        guard let gameLoop = gameLoop else { return }

        var playerInventory = gameLoop.player.inventory
        var chestInventory: InventoryComponent?

        // Get the appropriate chest inventory
        if let chestEntity = chestEntity {
            chestInventory = gameLoop.world.get(InventoryComponent.self, for: chestEntity)
        } else if let chestOnlyEntity = chestOnlyEntity {
            chestInventory = gameLoop.world.get(InventoryComponent.self, for: chestOnlyEntity)
        } else if let pendingChestEntity = pendingChestEntity {
            chestInventory = gameLoop.world.get(InventoryComponent.self, for: pendingChestEntity)
        }

        guard var chestInventory = chestInventory else { return }

        // Determine source and destination
        let isSourcePlayerSlot = fromSlotIndex < playerSlotsCount
        let isDestPlayerSlot = toSlotIndex < playerSlotsCount

        let sourceStack: ItemStack?
        let destStack: ItemStack?

        if isSourcePlayerSlot {
            sourceStack = fromSlotIndex < playerInventory.slots.count ? playerInventory.slots[fromSlotIndex] : nil
        } else {
            let chestIndex = fromSlotIndex - playerSlotsCount
            sourceStack = chestIndex < chestInventory.slots.count ? chestInventory.slots[chestIndex] : nil
        }

        if isDestPlayerSlot {
            destStack = toSlotIndex < playerInventory.slots.count ? playerInventory.slots[toSlotIndex] : nil
        } else {
            let chestIndex = toSlotIndex - playerSlotsCount
            destStack = chestIndex < chestInventory.slots.count ? chestInventory.slots[chestIndex] : nil
        }

        if sourceStack == nil {
            // Nothing to move
            return
        }

        // Perform the move/combine/swap operation
        if destStack == nil {
            // Move to empty slot
            if isDestPlayerSlot {
                playerInventory.slots[toSlotIndex] = sourceStack
            } else {
                let chestIndex = toSlotIndex - playerSlotsCount
                chestInventory.slots[chestIndex] = sourceStack
            }

            // Clear source
            if isSourcePlayerSlot {
                playerInventory.slots[fromSlotIndex] = nil
            } else {
                let chestIndex = fromSlotIndex - playerSlotsCount
                chestInventory.slots[chestIndex] = nil
            }
        } else if destStack!.itemId == sourceStack!.itemId {
            // Combine stacks of same item - use correct maxStack from ItemRegistry
            let maxStack = gameLoop.itemRegistry.get(sourceStack!.itemId)?.stackSize ?? sourceStack!.maxStack
            let totalItems = destStack!.count + sourceStack!.count
            let itemsInDest = min(totalItems, maxStack)
            let remainingItems = totalItems - itemsInDest

            let combinedStack = ItemStack(itemId: destStack!.itemId, count: itemsInDest, maxStack: maxStack)

            if isDestPlayerSlot {
                playerInventory.slots[toSlotIndex] = combinedStack
            } else {
                let chestIndex = toSlotIndex - playerSlotsCount
                chestInventory.slots[chestIndex] = combinedStack
            }

            if remainingItems > 0 {
                let remainingStack = ItemStack(itemId: sourceStack!.itemId, count: remainingItems, maxStack: maxStack)
                if isSourcePlayerSlot {
                    playerInventory.slots[fromSlotIndex] = remainingStack
                } else {
                    let chestIndex = fromSlotIndex - playerSlotsCount
                    chestInventory.slots[chestIndex] = remainingStack
                }
            } else {
                // Clear source
                if isSourcePlayerSlot {
                    playerInventory.slots[fromSlotIndex] = nil
                } else {
                    let chestIndex = fromSlotIndex - playerSlotsCount
                    chestInventory.slots[chestIndex] = nil
                }
            }
        } else {
            // Swap different items
            if isDestPlayerSlot {
                playerInventory.slots[toSlotIndex] = sourceStack
            } else {
                let chestIndex = toSlotIndex - playerSlotsCount
                chestInventory.slots[chestIndex] = sourceStack
            }

            if isSourcePlayerSlot {
                playerInventory.slots[fromSlotIndex] = destStack
            } else {
                let chestIndex = fromSlotIndex - playerSlotsCount
                chestInventory.slots[chestIndex] = destStack
            }
        }

        // Save changes
        gameLoop.player.inventory = playerInventory

        // Save chest changes if applicable
        if let chestEntity = chestEntity {
            gameLoop.world.add(chestInventory, to: chestEntity)
        } else if let chestOnlyEntity = chestOnlyEntity {
            gameLoop.world.add(chestInventory, to: chestOnlyEntity)
        } else if let pendingChestEntity = pendingChestEntity {
            gameLoop.world.add(chestInventory, to: pendingChestEntity)
        }

        AudioManager.shared.playClickSound()
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


    func getTooltip(at screenPos: Vector2) -> String? {
        guard isOpen, let scrollView = scrollView else { return nil }

        // Convert screen position to scrollview content coordinates
        let scale = Float(UIScreen.main.scale)
        let contentPos = Vector2(
            screenPos.x - Float(scrollView.frame.origin.x) * scale + Float(scrollView.contentOffset.x) * scale,
            screenPos.y - Float(scrollView.frame.origin.y) * scale + Float(scrollView.contentOffset.y) * scale
        )

        for slot in slots {
            if slot.frame.contains(contentPos), let item = slot.item, let itemRegistry = gameLoop?.itemRegistry {
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
    var backgroundColor: Color?
    var isRequired: Bool = false // True if this slot shows a required item for current recipe

    init(frame: Rect, index: Int, backgroundColor: Color? = nil) {
        self.frame = frame
        self.index = index
        self.backgroundColor = backgroundColor
    }
    
    func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }
        isSelected = true
        return true
    }
    
    func render(renderer: MetalRenderer, frameOverride: Rect? = nil) {
        let frameToUse = frameOverride ?? frame

        // Slot background - use custom color if provided, otherwise default
        let bgColor: Color
        if let customColor = backgroundColor {
            bgColor = customColor
        } else {
            bgColor = isSelected ?
                Color(r: 0.3, g: 0.3, b: 0.4, a: 1) :
                Color(r: 0.2, g: 0.2, b: 0.25, a: 1)
        }

        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: frameToUse.center,
            size: frameToUse.size,
            textureRect: solidRect,
            color: bgColor,
            layer: .ui
        ))

        // Item
        if let item = item {
            let textureRect = renderer.textureAtlas.getTextureRect(for: item.itemId.replacingOccurrences(of: "-", with: "_"))
            renderer.queueSprite(SpriteInstance(
                position: frameToUse.center,
                size: frameToUse.size * 0.8,
                textureRect: textureRect,
                layer: .ui
            ))

            // Add a border for required items
            if isRequired {
                let borderRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
                renderer.queueSprite(SpriteInstance(
                    position: frameToUse.center,
                    size: frameToUse.size * 0.9,
                    textureRect: borderRect,
                    color: Color(r: 1.0, g: 0.8, b: 0.2, a: 0.3), // Orange border for required items
                    layer: .ui
                ))
            }
        }
    }
}

