import Foundation
import UIKit

/// Custom scroll view that forcibly removes any internal background/backdrop views
/// that UIKit might insert during scrolling, ensuring Metal content shows through cleanly
final class ClearScrollView: UIScrollView {
    override func layoutSubviews() {
        super.layoutSubviews()

        // Ensure the scroll view itself is transparent
        backgroundColor = .clear
        isOpaque = false
        layer.backgroundColor = UIColor.clear.cgColor

        // iOS sometimes inserts private backdrop/background views inside UIScrollView
        // (especially visible during scrolling/dragging).
        var hiddenViews: [String] = []
        for v in subviews {
            let name = NSStringFromClass(type(of: v))

            // Common private/internal culprits across iOS versions
            if name.contains("Backdrop") ||
               name.contains("Background") ||
               name.contains("Shadow") ||
               name.contains("ScrollBarBackground") ||
               name.contains("_UI") && name.contains("Background") {

                hiddenViews.append(name)
                v.isHidden = true
                v.backgroundColor = .clear
                v.isOpaque = false
                v.layer.backgroundColor = UIColor.clear.cgColor
            }
        }

        if !hiddenViews.isEmpty {
            print("ClearScrollView: Hidden internal background views: \(hiddenViews)")
        }
    }
}

/// Player inventory panel
final class InventoryUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var slots: [InventorySlot] = []
    private var countLabels: [UILabel] = []
    private var closeButton: CloseButton!
    private var trashTarget: UIButton!
    private var scrollView: ClearScrollView!
    private var placeBuildingButton: UIKit.UIButton!

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
    var onAddScrollView: ((ClearScrollView) -> Void)?
    var onRemoveScrollView: ((ClearScrollView) -> Void)?
    var onAddPlaceBuildingButton: ((UIView) -> Void)?
    var onRemovePlaceBuildingButton: ((UIView) -> Void)?
    var onShowTooltip: ((String) -> Void)?
    
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
        setupPlaceBuildingButton()
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
        guard let player = gameLoop.player else { return }
        var playerInventory = player.inventory
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
                player.inventory = playerInventory

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
                    player.inventory = playerInventory
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
            guard let player = gameLoop.player else { return }
            var playerInventory = player.inventory

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
                    player.inventory = playerInventory
                    AudioManager.shared.playClickSound()
                }
            }
        } else {
            // Empty chest slot - open player inventory for item selection
            enterPendingChestMode(entity: chestOnlyEntity)
            exitChestOnlyMode()
        }
    }

    private func handlePendingChestTransfer(slot: InventorySlot) {
        guard let pendingChestEntity = pendingChestEntity,
              let gameLoop = gameLoop,
              let itemStack = slot.item else { return }

        // Get player and chest inventories
        guard let player = gameLoop.player else { return }
        var playerInventory = player.inventory
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
                player.inventory = playerInventory

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


        scrollView = ClearScrollView(frame: CGRect(
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
        scrollView.translatesAutoresizingMaskIntoConstraints = true  // Use frame-based layout
        scrollView.isScrollEnabled = true
        scrollView.alwaysBounceVertical = true
        scrollView.delaysContentTouches = false

        // Make scrollView transparent so Metal slots show through
        scrollView.backgroundColor = .clear
        scrollView.isOpaque = false
        scrollView.layer.backgroundColor = UIColor.clear.cgColor
        scrollView.clipsToBounds = true
        scrollView.layer.compositingFilter = nil
        scrollView.layer.opacity = 1.0

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
            label.backgroundColor = .clear
            label.layer.cornerRadius = 2
            label.layer.masksToBounds = true
            label.translatesAutoresizingMaskIntoConstraints = true
            label.text = ""
            label.isHidden = true

            // ✅ critical: don't let labels steal touches
            label.isUserInteractionEnabled = false

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

    private func setupPlaceBuildingButton() {
        // Create button with temporary frame - positioning will be handled by the callback
        let buttonWidth: CGFloat = 120
        let buttonHeight: CGFloat = 40
        placeBuildingButton = UIKit.UIButton(frame: CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight))

        placeBuildingButton.setTitle("Place Building", for: UIControl.State.normal)
        placeBuildingButton.setTitleColor(UIColor.white, for: UIControl.State.normal)
        placeBuildingButton.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)
        placeBuildingButton.layer.cornerRadius = 8
        placeBuildingButton.layer.masksToBounds = true
        placeBuildingButton.translatesAutoresizingMaskIntoConstraints = true

        placeBuildingButton.addTarget(self, action: #selector(placeBuildingButtonTapped), for: UIControl.Event.touchUpInside)

        // Initially hidden
        placeBuildingButton.isHidden = true
        placeBuildingButton.alpha = 0.0
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

        guard let player = gameLoop.player else { return }
        playerSlots = player.inventory.slots

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

        // --- constants (compute once per update) ---
        guard let sv = scrollView else { return }
        let scale = gameLoop.renderer?.view?.contentScaleFactor ?? UIScreen.main.scale

        // Define slot geometry in *points* (UIKit space)
        let slotSizePt    = CGFloat(40 * UIScale) / scale
        let slotSpacingPt = CGFloat(5  * UIScale) / scale

        let rows = (totalSlots + slotsPerRow - 1) / slotsPerRow
        let totalWidthPt  = CGFloat(slotsPerRow) * slotSizePt + CGFloat(slotsPerRow - 1) * slotSpacingPt
        let totalHeightPt = CGFloat(rows)       * slotSizePt + CGFloat(rows - 1)       * slotSpacingPt

        // Update scroll content size in *points*
        let contentWidthPt  = max(totalWidthPt, sv.bounds.width)
        let contentHeightPt = totalHeightPt
        sv.contentSize = CGSize(width: contentWidthPt, height: contentHeightPt)

        // Center grid in the visible width (points)
        let gridOriginXPt: CGFloat = (totalWidthPt < sv.bounds.width) ? (sv.bounds.width - totalWidthPt) * 0.5 : 0.0
        let gridOriginYPt: CGFloat = 0.0

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

            guard index < totalSlots else { continue }

            let row = index / slotsPerRow
            let col = index % slotsPerRow

            // Slot center in *points* (scrollView content coordinates)
            let slotCenterXPt = gridOriginXPt + slotSizePt * 0.5 + CGFloat(col) * (slotSizePt + slotSpacingPt)
            let slotCenterYPt = gridOriginYPt + slotSizePt * 0.5 + CGFloat(row) * (slotSizePt + slotSpacingPt)

            // Update slot frame in *pixels* for Metal (engine space)
            let slotCenterXPx = Float(slotCenterXPt * scale)
            let slotCenterYPx = Float(slotCenterYPt * scale)
            let slotSizePx    = Float(slotSizePt * scale)

            slot.frame = Rect(
                center: Vector2(slotCenterXPx, slotCenterYPx),
                size: Vector2(slotSizePx, slotSizePx)
            )

            // ---- label ----
            let label = countLabels[index]

            // Label size/inset in *points* (proportional to slot size)
            let labelWPt: CGFloat = slotSizePt * 0.65  // proportional to slot
            let labelHPt: CGFloat = slotSizePt * 0.40  // proportional to slot
            let insetPt:  CGFloat = slotSizePt * 0.10  // proportional inset

            // Bottom-right inside the slot, in *points*
            let labelXPt = (slotCenterXPt + slotSizePt * 0.5) - labelWPt - insetPt
            let labelYPt = (slotCenterYPt + slotSizePt * 0.5) - labelHPt - insetPt

            label.frame = CGRect(x: labelXPt, y: labelYPt, width: labelWPt, height: labelHPt)

            // Check if label is visible within scroll view bounds
            let labelRect = label.frame
            let viewportRect = sv.bounds  // in scrollView's content coordinate system (points)
            let isVisible = viewportRect.intersects(labelRect)

            if let item = slot.item, item.count > 1, isVisible {
                label.text = "\(item.count)"
                label.isHidden = false
            } else {
                label.text = ""
                label.isHidden = true
            }
            }
    }

    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Render close button
        closeButton.render(renderer: renderer)

        guard let scrollView = scrollView else { return }

        // Use Metal view's content scale factor for consistency
        let scale = Float(renderer.view?.contentScaleFactor ?? UIScreen.main.scale)

        // ScrollView origin in *pixels* (screen space)
        let svOriginPx = Vector2(
            Float(scrollView.frame.origin.x) * scale,
            Float(scrollView.frame.origin.y) * scale
        )

        // Scroll offset in *pixels* (content space)
        let scrollOffsetPx = Vector2(
            Float(scrollView.contentOffset.x) * scale,
            Float(scrollView.contentOffset.y) * scale
        )

        // ScrollView rect in *screen pixels*
        let svScreenRectPx = Rect(
            center: Vector2(
                Float(scrollView.frame.midX) * scale,
                Float(scrollView.frame.midY) * scale
            ),
            size: Vector2(
                Float(scrollView.bounds.width) * scale,
                Float(scrollView.bounds.height) * scale
            )
        )

        for (index, slot) in slots.enumerated() {
            guard index < totalSlots else { continue }

            // contentPx -> screenPx:
            let screenCenter = svOriginPx + (slot.frame.center - scrollOffsetPx)
            let scrolledFrame = Rect(center: screenCenter, size: slot.frame.size)

            // Cull in SCREEN space, not content space
            guard svScreenRectPx.intersects(scrolledFrame) else { continue }

            slot.render(renderer: renderer, frameOverride: scrolledFrame)
        }

        // Render trash target
        trashTarget.render(renderer: renderer)
    }
    
    override func handleTap(at position: Vector2) -> Bool {
        guard isOpen, let scrollView = scrollView else { return false }

        // Close button stays in panel/screen space
        if closeButton.handleTap(at: position) {
            return true
        }

        // Use Metal view's content scale factor for consistency with rendering
        let scale = Float(gameLoop?.renderer?.view?.contentScaleFactor ?? UIScreen.main.scale)

        // Screen → scroll content space
        let contentPos = Vector2(
            position.x
                - Float(scrollView.frame.origin.x) * scale
                + Float(scrollView.contentOffset.x) * scale,

            position.y
                - Float(scrollView.frame.origin.y) * scale
                + Float(scrollView.contentOffset.y) * scale
        )

        for (index, slot) in slots.enumerated() {
            guard index < totalSlots else { continue }

            if slot.frame.contains(contentPos) {
                // Set selection highlight
                for j in 0..<totalSlots { slots[j].isSelected = false } // clear previous
                slot.isSelected = true

                // Update place building button visibility
                updatePlaceBuildingButtonVisibility()

                // Show tooltip for tapped item
                if let item = slot.item, let itemRegistry = gameLoop?.itemRegistry {
                    let tooltip = itemRegistry.get(item.itemId)?.name ?? item.itemId
                    onShowTooltip?(tooltip)
                }

                if machineEntity != nil {
                    handleMachineInput(slot: slot)
                } else if chestEntity != nil {
                    handleChestTransfer(slot: slot)
                } else if chestOnlyEntity != nil {
                    handleChestOnlyInteraction(slot: slot)
                } else if pendingChestEntity != nil {
                    handlePendingChestTransfer(slot: slot)
                }

                return true
            }
        }

        return false
    }

    override func open() {
        super.open()
        // Create scrollview now that callbacks are set up
        if scrollView == nil {
            setupSlots()
        }

        guard let sv = scrollView else { return }

        // Reposition scrollview using actual screen bounds in points
        let screenBounds = UIScreen.main.bounds
        let screenScale = UIScreen.main.scale
        let scrollViewWidth = screenBounds.width * 0.9

        // Convert from pixel space to points - show ~8 rows total
        let scrollViewHeightPt: CGFloat = (360 * CGFloat(UIScale)) / screenScale
        let topSafe = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0
        let topMarginPt: CGFloat = topSafe + (12 * CGFloat(UIScale)) / screenScale

        sv.frame = CGRect(
            x: (screenBounds.width - scrollViewWidth) * 0.5,
            y: topMarginPt,
            width: scrollViewWidth,
            height: scrollViewHeightPt
        )

        // If any labels were previously added somewhere else, yank them back.
        for label in countLabels {
            if label.superview !== sv {
                label.removeFromSuperview()
                sv.addSubview(label)
            }
        }
    }

    override func close() {
        // Remove labels from scrollView
        for label in countLabels {
            label.removeFromSuperview()
        }
        if scrollView != nil {
            onRemoveScrollView?(scrollView)
            scrollView = nil
        }

        // Hide and remove place building button
        if !placeBuildingButton.isHidden {
            onRemovePlaceBuildingButton?(placeBuildingButton)
        }
        placeBuildingButton.isHidden = true
        placeBuildingButton.alpha = 0.0

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
        guard let player = gameLoop.player else { return }
        if machineInventory.canAccept(itemId: itemStack.itemId) {
            // Remove one item from player inventory at this slot
            var playerInv = player.inventory
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
                    player.inventory = playerInv

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
                            player.inventory.add(itemId: slotItem.itemId, count: remaining, maxStack: itemDef.stackSize)
                        } else {
                            player.inventory.add(itemId: slotItem.itemId, count: remaining, maxStack: 100) // fallback
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
        guard let gameLoop = gameLoop,
              let player = gameLoop.player else { return }

        // Determine which inventories are involved
        let playerSlotsCount = player.inventory.slots.count

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
        guard let gameLoop = gameLoop,
              let player = gameLoop.player else { return }
        guard fromSlotIndex < player.inventory.slots.count,
              toSlotIndex < player.inventory.slots.count else { return }
        var playerInventory = player.inventory

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

        player.inventory = playerInventory
        AudioManager.shared.playClickSound()
    }

    private func handleChestInventoryDrop(fromSlotIndex: Int, toSlotIndex: Int, playerSlotsCount: Int) {
        guard let gameLoop = gameLoop,
              let player = gameLoop.player else { return }
        var playerInventory = player.inventory
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
        player.inventory = playerInventory

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

    private func isBuildingItem(itemId: String) -> Bool {
        guard let gameLoop = gameLoop else { return false }
        return gameLoop.buildingRegistry.get(itemId) != nil
    }

    private func placeSelectedBuilding() {
        // Find the currently selected slot
        guard let selectedSlot = slots.first(where: { $0.isSelected }),
              let itemStack = selectedSlot.item,
              isBuildingItem(itemId: itemStack.itemId) else { return }

        // Enter build mode with the selected building
        gameLoop?.inputManager?.enterBuildMode(buildingId: itemStack.itemId)
    }

    @objc private func placeBuildingButtonTapped() {
        placeSelectedBuilding()
    }

    private func updatePlaceBuildingButtonVisibility() {
        // Check if any slot has a selected building item
        let hasSelectedBuilding = slots.contains { slot in
            slot.isSelected && slot.item != nil && isBuildingItem(itemId: slot.item!.itemId)
        }

        if hasSelectedBuilding && placeBuildingButton.isHidden {
            // Show button
            placeBuildingButton.isHidden = false
            placeBuildingButton.alpha = 1.0
            onAddPlaceBuildingButton?(placeBuildingButton)
        } else if !hasSelectedBuilding && !placeBuildingButton.isHidden {
            // Hide button
            placeBuildingButton.isHidden = true
            placeBuildingButton.alpha = 0.0
            onRemovePlaceBuildingButton?(placeBuildingButton)
        }
    }

    private func handleTrashDrop(slotIndex: Int) {
        guard let gameLoop = gameLoop,
              let player = gameLoop.player,
              slotIndex < player.inventory.slots.count else { return }
        var playerInventory = player.inventory

        // Remove the item stack from the slot
        if let itemStack = playerInventory.slots[slotIndex] {
            playerInventory.slots[slotIndex] = nil
            player.inventory = playerInventory

            // Play sound effect
            AudioManager.shared.playClickSound()

            print("Trashed \(itemStack.count) \(itemStack.itemId)")
        }
    }


    func getTooltip(at screenPos: Vector2) -> String? {
        guard isOpen, let sv = scrollView else { return nil }
        guard let itemRegistry = gameLoop?.itemRegistry else { return nil }

        // Use the same scale and mapping as handleTap()
        let scale = Float(gameLoop?.renderer?.view?.contentScaleFactor ?? UIScreen.main.scale)

        // If the pointer is outside the scroll view, there is no tooltip from inventory.
        let svRectPx = Rect(
            center: Vector2(Float(sv.frame.midX) * scale, Float(sv.frame.midY) * scale),
            size:   Vector2(Float(sv.bounds.width) * scale, Float(sv.bounds.height) * scale)
        )
        guard svRectPx.contains(screenPos) else { return nil }

        // Screen(px) -> content(px)
        let contentPos = Vector2(
            screenPos.x - Float(sv.frame.origin.x) * scale + Float(sv.contentOffset.x) * scale,
            screenPos.y - Float(sv.frame.origin.y) * scale + Float(sv.contentOffset.y) * scale
        )

        // Only check slots that are actually active
        for i in 0..<totalSlots {
            let slot = slots[i]
            if slot.frame.contains(contentPos), let item = slot.item {
                return itemRegistry.get(item.itemId)?.name ?? item.itemId
            }
        }
        return nil
    }

}

class InventorySlot: UIElement {
    func handleTap(at position: Vector2) -> Bool {
        print("InventorySlot:  handleTap invoked.")
        return true
    }
    
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

