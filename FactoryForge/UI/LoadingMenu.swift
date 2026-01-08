import Foundation
import UIKit

/// Loading menu for starting new game or loading saved games
final class LoadingMenu: UIPanel_Base {
    private var saveSystem: SaveSystem
    private var screenSize: Vector2 // Store screen size for coordinate conversion
    private var newGameButton: UIButton!
    private var saveGameButton: UIButton!
    private var autoplayButton: UIButton!
    private var helpButton: UIButton!
    private var audioToggleButton: UIButton!
    private var saveSlotButtons: [SaveSlotButton] = []
    private var slotLabels: [UILabel] = [] // Labels for save slot information
    private var helpButtonLabel: UILabel? // Label for help button question mark
    private var closeButton: CloseButton!

    // Scrolling functionality
    private var scrollOffset: Float = 0 // Current scroll position (0 = top)
    private var maxScrollOffset: Float = 0 // Maximum scroll position
    private var scrollButtonHeight: Float = 40 * UIScale // Height of scroll buttons
    private var visibleSlotCount: Int = 0 // Number of slots that can fit on screen
    private var scrollUpButton: UIButton!
    private var scrollDownButton: UIButton!
    private var isDragging: Bool = false
    private var dragStartPosition: Vector2 = .zero
    private var dragStartScrollOffset: Float = 0
    
    var onNewGameSelected: (() -> Void)?
    var onSaveSlotSelected: ((String) -> Void)? // Called when a save slot is selected to load
    var onSaveSlotDelete: ((String) -> Void)? // Called when delete button is pressed for a save slot
    var onSaveGameRequested: (() -> Void)? // Called when save button is pressed
    var onAutoplayTapped: (() -> Void)? // Called when autoplay button is tapped
    var onHelpTapped: (() -> Void)? // Called when help button is tapped
    var onCloseTapped: (() -> Void)? // Called when close button (X) is tapped
    
    init(screenSize: Vector2) {
        self.saveSystem = SaveSystem()
        self.screenSize = screenSize
        
        // Use full screen size for background
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(screenSize.x, screenSize.y)
        )
        
        super.init(frame: panelFrame)
        
        setupCloseButton()
        setupButtons()
        refreshSaveSlots()
    }

    private func setupCloseButton() {
        let buttonSize: Float = 30 * UIScale
        let buttonX = frame.maxX - 25 * UIScale
        let buttonY = frame.minY + 25 * UIScale

        closeButton = CloseButton(frame: Rect(center: Vector2(buttonX, buttonY), size: Vector2(buttonSize, buttonSize)))
        closeButton.onTap = { [weak self] in
            AudioManager.shared.playClickSound()
            self?.onCloseTapped?()
        }
    }
    
    private func setupButtons() {
        // Button images are 805x279px (aspect ratio ~2.89:1), calculate size to preserve aspect ratio
        let imageAspectRatio: Float = 805.0 / 279.0  // ~2.89
        let buttonHeight: Float = 60 * UIScale  // Reduced from 90 to make buttons smaller
        let buttonWidth: Float = buttonHeight * imageAspectRatio  // Maintain aspect ratio
        let buttonSpacing: Float = 10 * UIScale  // Reduced spacing
        let buttonY = frame.center.y - 150 * UIScale  // Moved up from -200 to leave more space
        
        // New Game button at the top
        newGameButton = UIButton(
            frame: Rect(
                center: Vector2(frame.center.x, buttonY + buttonHeight / 2),
                size: Vector2(buttonWidth, buttonHeight)
            ),
            textureId: "new_game"
        )
        newGameButton.onTap = { [weak self] in
            AudioManager.shared.playClickSound()
            self?.onNewGameSelected?()
        }
        
        // Save Game button below New Game (only show if game is running)
        let saveButtonY = buttonY + buttonHeight + buttonSpacing
        saveGameButton = UIButton(
            frame: Rect(
                center: Vector2(frame.center.x, saveButtonY + buttonHeight / 2),
                size: Vector2(buttonWidth, buttonHeight)
            ),
            textureId: "save_game"
        )
        saveGameButton.onTap = { [weak self] in
            AudioManager.shared.playClickSound()
            self?.onSaveGameRequested?()
        }

        // Help button (left of autoplay button)
        let helpButtonSize: Float = 50 * UIScale
        let helpButtonX = frame.maxX - 180 * UIScale
        let helpButtonY = frame.maxY - 60 * UIScale
        helpButton = UIButton(
            frame: Rect(
                center: Vector2(helpButtonX, helpButtonY),
                size: Vector2(helpButtonSize, helpButtonSize)
            ),
            textureId: "help"  // Will render question mark emoji as overlay
        )
        helpButton.onTap = { [weak self] in
            AudioManager.shared.playClickSound()
            self?.onHelpTapped?()
        }

        // Autoplay button (left of audio toggle)
        let autoplayButtonSize: Float = 50 * UIScale
        let autoplayButtonX = frame.maxX - 120 * UIScale
        let autoplayButtonY = frame.maxY - 60 * UIScale
        autoplayButton = UIButton(
            frame: Rect(
                center: Vector2(autoplayButtonX, autoplayButtonY),
                size: Vector2(autoplayButtonSize, autoplayButtonSize)
            ),
            textureId: "menu"  // Use menu texture for now, could be replaced with autoplay icon
        )
        autoplayButton.onTap = { [weak self] in
            AudioManager.shared.playClickSound()
            self?.onAutoplayTapped?()
        }

        // Audio Toggle button (bottom right)
        let audioButtonSize: Float = 50 * UIScale
        let audioButtonX = frame.maxX - 60 * UIScale
        let audioButtonY = frame.maxY - 60 * UIScale
        audioToggleButton = UIButton(
            frame: Rect(
                center: Vector2(audioButtonX, audioButtonY),
                size: Vector2(audioButtonSize, audioButtonSize)
            ),
            textureId: "disable_audio"  // Use menu texture for now, could be replaced with audio icon
        )
        audioToggleButton.onTap = {
            AudioManager.shared.playClickSound()
            AudioManager.shared.toggleMute()
            print("Audio toggled: \(AudioManager.shared.isMuted ? "MUTED" : "UNMUTED")")
        }

        // Scroll buttons (positioned on the left side of save slots area)
        let scrollButtonWidth: Float = 50 * UIScale
        let scrollButtonX = frame.center.x - 220 * UIScale  // Position left of save slots
        let slotsAreaTop = frame.center.y - 20 * UIScale

        // Scroll up button
        scrollUpButton = UIButton(
            frame: Rect(
                center: Vector2(scrollButtonX, slotsAreaTop - scrollButtonHeight / 2),
                size: Vector2(scrollButtonWidth, scrollButtonHeight)
            ),
            textureId: "solid_white"
        )
        scrollUpButton.onTap = { [weak self] in
            self?.scrollUp()
        }

        // Scroll down button
        scrollDownButton = UIButton(
            frame: Rect(
                center: Vector2(scrollButtonX, slotsAreaTop + scrollButtonHeight / 2 + 10 * UIScale),
                size: Vector2(scrollButtonWidth, scrollButtonHeight)
            ),
            textureId: "solid_white"
        )
        scrollDownButton.onTap = { [weak self] in
            self?.scrollDown()
        }
    }
    
    func setShowSaveButton(_ show: Bool) {
        // Save button visibility will be controlled by whether onSaveGameRequested is set
    }

    // MARK: - Scrolling Methods

    private func scrollUp() {
        AudioManager.shared.playClickSound()
        scrollOffset = max(0, scrollOffset - 1)
        refreshSaveSlots()
    }

    private func scrollDown() {
        AudioManager.shared.playClickSound()
        let maxOffset = max(0, Float(saveSystem.getSaveSlots().count) - Float(visibleSlotCount))
        scrollOffset = min(maxOffset, scrollOffset + 1)
        refreshSaveSlots()
    }

    private func calculateVisibleSlots() -> Int {
        // Calculate how many slots can fit in the available space
        let availableHeight = frame.height - 200 * UIScale  // Leave space for buttons above/below
        let buttonHeight: Float = 60 * UIScale
        let buttonSpacing: Float = 10 * UIScale
        let totalButtonHeight = buttonHeight + buttonSpacing
        return max(1, Int(availableHeight / totalButtonHeight))
    }

    private func startDrag(at position: Vector2) {
        // Check if drag started in the save slots area
        let slotsAreaLeft = frame.center.x - 250 * UIScale
        let slotsAreaRight = frame.center.x + 250 * UIScale
        let slotsAreaTop = frame.center.y - 20 * UIScale - scrollButtonHeight
        let slotsAreaBottom = frame.center.y + 100 * UIScale  // Approximate bottom of slots area

        if position.x >= slotsAreaLeft && position.x <= slotsAreaRight &&
           position.y >= slotsAreaTop && position.y <= slotsAreaBottom {
            isDragging = true
            dragStartPosition = position
            dragStartScrollOffset = scrollOffset
        }
    }

    private func updateDrag(at position: Vector2) {
        guard isDragging else { return }

        // Calculate scroll change based on drag distance
        let dragDistance = position.y - dragStartPosition.y
        let scrollSensitivity: Float = 0.5  // Adjust sensitivity as needed

        let newScrollOffset = dragStartScrollOffset - dragDistance * scrollSensitivity / (60 * UIScale + 10 * UIScale)  // Per slot height
        scrollOffset = max(0, min(maxScrollOffset, newScrollOffset))

        refreshSaveSlots()
    }

    private func endDrag() {
        isDragging = false
    }

    private func showRenameDialog(for slot: SaveSlotInfo) {
        guard let parentView = parentView else { return }

        let alertController = UIAlertController(title: "Rename Save Slot", message: "Enter a new name for this save slot", preferredStyle: .alert)

        alertController.addTextField { textField in
            textField.text = slot.effectiveDisplayName
            textField.placeholder = "Save name"
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let textField = alertController.textFields?.first,
                  let newName = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !newName.isEmpty else {
                return
            }

            self?.saveSystem.setDisplayName(newName, for: slot.name)
            self?.refreshSaveSlots()
        }

        alertController.addAction(cancelAction)
        alertController.addAction(saveAction)

        // Find the view controller to present the alert
        var responder: UIResponder? = parentView
        while responder != nil {
            if let viewController = responder as? UIViewController {
                viewController.present(alertController, animated: true, completion: nil)
                break
            }
            responder = responder?.next
        }
    }
    
    func refreshSaveSlots() {
        // Remove old labels
        removeSlotLabels()

        saveSlotButtons.removeAll()

        let slots = saveSystem.getSaveSlots()

        // Calculate visible slots and scrolling
        visibleSlotCount = calculateVisibleSlots()
        let totalSlots = slots.count
        maxScrollOffset = max(0, Float(totalSlots) - Float(visibleSlotCount))

        // Ensure scroll offset is valid
        scrollOffset = min(scrollOffset, maxScrollOffset)
        scrollOffset = max(0, scrollOffset)

        // Save slot area width (leave space for load/delete buttons on the right)
        let slotAreaWidth: Float = 460 * UIScale
        let buttonHeight: Float = 60 * UIScale
        let buttonSpacing: Float = 10 * UIScale
        let startY = frame.center.y - 20 * UIScale // Moved up from -50 to have better spacing from buttons

        // Load/Delete button size (using same aspect ratio as other buttons)
        let imageAspectRatio: Float = 805.0 / 279.0
        let loadDeleteButtonHeight: Float = 60 * UIScale  // Match the button height used in save slots
        let loadDeleteButtonWidth: Float = loadDeleteButtonHeight * imageAspectRatio

        // Create visible slots based on scroll offset
        let startIndex = Int(scrollOffset)
        let endIndex = min(startIndex + visibleSlotCount, totalSlots)

        for (visibleIndex, slotIndex) in (startIndex..<endIndex).enumerated() {
            let slot = slots[slotIndex]
            let buttonY = startY + Float(visibleIndex) * (buttonHeight + buttonSpacing)

            // Save slot button (left side - takes up most of the width)
            let slotButton = SaveSlotButton(
                frame: Rect(
                    center: Vector2(frame.center.x - (loadDeleteButtonWidth + buttonSpacing) / 2, buttonY + buttonHeight / 2),
                    size: Vector2(slotAreaWidth, buttonHeight)
                ),
                slotInfo: slot
            )
            slotButton.onTap = { [weak self] in
                self?.onSaveSlotSelected?(slot.name)
            }
            slotButton.onLoadTap = { [weak self] in
                AudioManager.shared.playClickSound()
                self?.onSaveSlotSelected?(slot.name)
            }
            slotButton.onDeleteTap = { [weak self] in
                AudioManager.shared.playClickSound()
                self?.onSaveSlotDelete?(slot.name)
            }
            slotButton.onRenameTap = { [weak self] in
                AudioManager.shared.playClickSound()
                self?.showRenameDialog(for: slot)
            }
            saveSlotButtons.append(slotButton)
        }

        // Update labels (will be created in setupLabels if parent view is set)
        updateSlotLabels()
        setupHelpButtonLabel()
    }
    
    private weak var parentView: UIView?
    
    /// Sets up UILabel overlays for save slot information
    /// Must be called from GameViewController after LoadingMenu is created
    func setupLabels(in parentView: UIView) {
        self.parentView = parentView
        removeSlotLabels()
        updateSlotLabels()
    }
    
    private func updateSlotLabels() {
        // Only create labels if parent view is available
        guard let parentView = parentView else { return }
        
        // Convert Metal coordinates to UIKit coordinates
        // Metal uses pixels (screenSize * scale) with bottom-left origin
        // UIKit uses points with top-left origin
        let screenScale = CGFloat(UIScreen.main.scale)
        // let screenHeightPoints = CGFloat(parentView.bounds.height)  // Unused for now
        
        // Calculate Load/Delete button dimensions for accurate label width calculation
        let imageAspectRatio: Float = 805.0 / 279.0
        let loadDeleteButtonHeight: Float = 60 * UIScale  // Match the button height used in save slots
        let loadDeleteButtonWidth: Float = loadDeleteButtonHeight * imageAspectRatio
        let buttonSpacing: Float = 5 * UIScale
        let buttonsAreaWidth = loadDeleteButtonWidth * 2 + buttonSpacing * 3 // Total width of Load/Delete buttons + spacing
        
        for (index, slotButton) in saveSlotButtons.enumerated() {
            let slotInfo = slotButton.slotInfo
            
            // Create label if it doesn't exist
            if index >= slotLabels.count {
                let label = UILabel()
                label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
                label.textColor = .white
                label.numberOfLines = 1 // Single line
                label.backgroundColor = .clear
                label.lineBreakMode = .byCharWrapping
                parentView.addSubview(label)
                slotLabels.append(label)
            }
            
            let label = slotLabels[index]
            
            // Just show the save file display name
            label.text = slotInfo.effectiveDisplayName
            
            let labelPadding: Float = 10 * UIScale
            
            // Calculate available width for text (leave room for Load/Delete buttons on the right)
            let availableWidth = slotButton.frame.width - buttonsAreaWidth - labelPadding * 2
            
            // Ensure label doesn't exceed button bounds
            let clampedWidth = max(availableWidth, 100 * UIScale) // Minimum 100 pixels
            
            // Convert button frame from Metal coordinates (pixels, bottom-left origin) to UIKit (points, top-left origin)
            // Metal: X is in pixels, Y increases upward from bottom (0 at bottom, screenHeight at top)
            // UIKit: X and Y are in points, Y increases downward from top (0 at top, screenHeight at bottom)
            
            // X coordinate: Convert from Metal pixels (top-left origin) to UIKit points (top-left origin)
            let buttonMinXPixels = CGFloat(slotButton.frame.minX)
            let labelXPoints = buttonMinXPixels / screenScale + CGFloat(labelPadding)
            
            // Y coordinate: Convert from Metal (top-left origin, pixels) to UIKit (top-left origin, points)
            // Metal UI: Y=0 at top, Y increases downward. Button center Y is in pixels from top.
            // UIKit: Y=0 at top, Y increases downward.
            // Conversion: UIKit Y = Metal Y / screenScale
            // We want to center the label vertically in the button
            let buttonCenterYPixels = CGFloat(slotButton.frame.center.y)
            
            // Convert from Metal pixels (top-left origin) to UIKit points (top-left origin)
            let buttonCenterYPoints = buttonCenterYPixels / screenScale
            
            // Position label centered vertically in button
            // Use proper font metrics for label height
            let font = UIFont.systemFont(ofSize: 16, weight: .medium)
            let estimatedLabelHeight: CGFloat = font.lineHeight
            let labelYPoints = buttonCenterYPoints - estimatedLabelHeight / 2
            
            // Width: Convert from pixels to points, leave room for buttons on right
            let labelWidthPoints = CGFloat(clampedWidth) / screenScale
            
            label.frame = CGRect(
                x: labelXPoints,
                y: labelYPoints,
                width: max(labelWidthPoints, 50),
                height: estimatedLabelHeight
            )
            label.isHidden = !isOpen
        }
        
        // Remove excess labels
        while slotLabels.count > saveSlotButtons.count {
            slotLabels.last?.removeFromSuperview()
            slotLabels.removeLast()
        }
    }

    private func setupHelpButtonLabel() {
        guard let parentView = parentView else { return }

        // Remove existing label if any
        helpButtonLabel?.removeFromSuperview()

        // Create new label
        let label = UILabel()
        label.text = "?"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = .clear
        parentView.addSubview(label)
        helpButtonLabel = label

        // Position the label to center it on the help button
        updateHelpButtonLabelPosition()
    }

    private func updateHelpButtonLabelPosition() {
        guard let label = helpButtonLabel, let button = helpButton else { return }

        let screenScale = CGFloat(UIScreen.main.scale)

        // Convert button center from Metal coordinates to UIKit points
        let buttonCenterXPixels = CGFloat(button.frame.center.x)
        let buttonCenterYPixels = CGFloat(button.frame.center.y)

        let buttonCenterXPoints = buttonCenterXPixels / screenScale
        let buttonCenterYPoints = buttonCenterYPixels / screenScale

        // Size the label to fit the button
        let buttonSizePoints = CGFloat(button.frame.size.x) / screenScale
        label.frame = CGRect(
            x: buttonCenterXPoints - buttonSizePoints / 2,
            y: buttonCenterYPoints - buttonSizePoints / 2,
            width: buttonSizePoints,
            height: buttonSizePoints
        )

        label.isHidden = !isOpen
    }
    
    private func removeSlotLabels() {
        for label in slotLabels {
            label.removeFromSuperview()
        }
        slotLabels.removeAll()
    }
    
    override func open() {
        super.open()
        refreshSaveSlots()
        // Show labels when menu opens
        for label in slotLabels {
            label.isHidden = false
        }
        helpButtonLabel?.isHidden = false
    }
    
    override func close() {
        super.close()
        // Hide labels when menu closes
        for label in slotLabels {
            label.isHidden = true
        }
        helpButtonLabel?.isHidden = true
    }
    
    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Render close button
        closeButton.render(renderer: renderer)

        // Render scroll buttons
        renderScrollButtons(renderer: renderer)

        // Render title
        renderTitle(renderer: renderer)

        // Render New Game button
        renderNewGameButton(renderer: renderer)
        
        // Render Save Game button (if callback is set, meaning game is running)
        if onSaveGameRequested != nil {
            renderSaveGameButton(renderer: renderer)
        }

        // Render Help button
        renderHelpButton(renderer: renderer)

        // Render Autoplay button
        renderAutoplayButton(renderer: renderer)

        // Render Audio Toggle button
        renderAudioToggleButton(renderer: renderer)

        // Render save slot buttons
        for button in saveSlotButtons {
            button.render(renderer: renderer)
        }
        
        // Render empty state if no saves
        if saveSlotButtons.isEmpty {
            renderEmptyState(renderer: renderer)
        }
    }
    
    private func renderTitle(renderer: MetalRenderer) {
        // Title rendered as text (using sprites for now, could use UILabel overlay)
        // For now, just leave space for title
    }
    
    private func renderNewGameButton(renderer: MetalRenderer) {
        guard let button = newGameButton else { return }
        // Use the button's built-in render method - button size now matches image aspect ratio
        button.render(renderer: renderer)
    }
    
    private func renderSaveGameButton(renderer: MetalRenderer) {
        guard let button = saveGameButton else { return }
        // Use the button's built-in render method - button size now matches image aspect ratio
        button.render(renderer: renderer)
    }

    private func renderAutoplayButton(renderer: MetalRenderer) {
        guard let button = autoplayButton else { return }
        // Use the button's built-in render method
        button.render(renderer: renderer)
    }

    private func renderHelpButton(renderer: MetalRenderer) {
        guard let button = helpButton else { return }
        // Use the button's built-in render method
        button.render(renderer: renderer)
    }

    private func renderAudioToggleButton(renderer: MetalRenderer) {
        guard let button = audioToggleButton else { return }
        // Use the button's built-in render method
        button.render(renderer: renderer)
    }

    private func renderScrollButtons(renderer: MetalRenderer) {
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")

        // Only render scroll buttons if there are more slots than can fit on screen
        let totalSlots = Float(saveSystem.getSaveSlots().count)
        if totalSlots <= Float(visibleSlotCount) {
            return
        }

        // Render scroll up button background
        if let button = scrollUpButton {
            // Render button background with bright color for visibility
            let bgColor = scrollOffset > 0 ? Color(r: 0.8, g: 0.8, b: 0.9, a: 1) : Color(r: 0.4, g: 0.4, b: 0.5, a: 1)
            renderer.queueSprite(SpriteInstance(
                position: button.frame.center,
                size: button.frame.size,
                textureRect: solidRect,
                color: bgColor,
                layer: .ui
            ))

            // Simple up arrow
            let arrowColor = Color.white
            let arrowWidth: Float = 20 * UIScale
            let arrowHeight: Float = 15 * UIScale

            // Arrow shaft
            renderer.queueSprite(SpriteInstance(
                position: Vector2(button.frame.center.x, button.frame.center.y + arrowHeight * 0.2),
                size: Vector2(3 * UIScale, arrowHeight * 0.6),
                textureRect: solidRect,
                color: arrowColor,
                layer: .ui
            ))

            // Arrow head
            renderer.queueSprite(SpriteInstance(
                position: Vector2(button.frame.center.x, button.frame.center.y - arrowHeight * 0.3),
                size: Vector2(arrowWidth * 0.5, arrowHeight * 0.4),
                textureRect: solidRect,
                color: arrowColor,
                layer: .ui
            ))
            renderer.queueSprite(SpriteInstance(
                position: Vector2(button.frame.center.x - arrowWidth * 0.15, button.frame.center.y - arrowHeight * 0.2),
                size: Vector2(arrowWidth * 0.2, arrowHeight * 0.2),
                textureRect: solidRect,
                color: arrowColor,
                layer: .ui
            ))
            renderer.queueSprite(SpriteInstance(
                position: Vector2(button.frame.center.x + arrowWidth * 0.15, button.frame.center.y - arrowHeight * 0.2),
                size: Vector2(arrowWidth * 0.2, arrowHeight * 0.2),
                textureRect: solidRect,
                color: arrowColor,
                layer: .ui
            ))
        }

        // Render scroll down button background
        if let button = scrollDownButton {
            // Render button background with bright color for visibility
            let bgColor = Color(r: 0.2, g: 0.8, b: 0.2, a: 1)  // Bright green for visibility
            renderer.queueSprite(SpriteInstance(
                position: button.frame.center,
                size: button.frame.size,
                textureRect: solidRect,
                color: bgColor,
                layer: .ui
            ))

            // Simple down arrow
            let arrowColor = Color.white
            let arrowWidth: Float = 20 * UIScale
            let arrowHeight: Float = 15 * UIScale

            // Arrow shaft
            renderer.queueSprite(SpriteInstance(
                position: Vector2(button.frame.center.x, button.frame.center.y - arrowHeight * 0.2),
                size: Vector2(3 * UIScale, arrowHeight * 0.6),
                textureRect: solidRect,
                color: arrowColor,
                layer: .ui
            ))

            // Arrow head
            renderer.queueSprite(SpriteInstance(
                position: Vector2(button.frame.center.x, button.frame.center.y + arrowHeight * 0.3),
                size: Vector2(arrowWidth * 0.5, arrowHeight * 0.4),
                textureRect: solidRect,
                color: arrowColor,
                layer: .ui
            ))
            renderer.queueSprite(SpriteInstance(
                position: Vector2(button.frame.center.x - arrowWidth * 0.15, button.frame.center.y + arrowHeight * 0.2),
                size: Vector2(arrowWidth * 0.2, arrowHeight * 0.2),
                textureRect: solidRect,
                color: arrowColor,
                layer: .ui
            ))
            renderer.queueSprite(SpriteInstance(
                position: Vector2(button.frame.center.x + arrowWidth * 0.15, button.frame.center.y + arrowHeight * 0.2),
                size: Vector2(arrowWidth * 0.2, arrowHeight * 0.2),
                textureRect: solidRect,
                color: arrowColor,
                layer: .ui
            ))
        }
    }
    
    private func renderEmptyState(renderer: MetalRenderer) {
        // Could render "No saved games" text here
        // For now, just leave empty
    }
    
    override func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }

        // Check close button first
        if closeButton.handleTap(at: position) {
            return true
        }

        // Check scroll buttons
        if scrollUpButton?.handleTap(at: position) == true {
            return true
        }
        if scrollDownButton?.handleTap(at: position) == true {
            return true
        }

        // Check New Game button
        if newGameButton?.handleTap(at: position) == true {
            return true
        }

        // Check Save Game button (if visible)
        if onSaveGameRequested != nil, saveGameButton?.handleTap(at: position) == true {
            return true
        }

        // Check Help button
        if helpButton?.handleTap(at: position) == true {
            return true
        }

        // Check Autoplay button
        if autoplayButton?.handleTap(at: position) == true {
            return true
        }

        // Check Audio Toggle button
        if audioToggleButton?.handleTap(at: position) == true {
            return true
        }

        // Check save slot buttons
        for button in saveSlotButtons {
            if button.handleTap(at: position) {
                return true
            }
        }

        return true // Consume tap within panel bounds
    }
}

// MARK: - Save Slot Button

class SaveSlotButton: UIElement {
    var frame: Rect
    var slotInfo: SaveSlotInfo // Made public so LoadingMenu can access it
    var onTap: (() -> Void)?
    var onLoadTap: (() -> Void)? // Called when load button is tapped
    var onDeleteTap: (() -> Void)? // Called when delete button is tapped
    var onRenameTap: (() -> Void)? // Called when rename button is tapped
    
    // Load, delete, and rename button frames (positioned on the right side of the slot)
    private var loadButtonFrame: Rect {
        let buttonHeight: Float = 60 * UIScale  // Match the button height used in save slots
        let imageAspectRatio: Float = 805.0 / 279.0
        let buttonWidth: Float = buttonHeight * imageAspectRatio
        let spacing: Float = 5 * UIScale
        return Rect(
            center: Vector2(frame.maxX - buttonWidth / 2 - spacing, frame.center.y),
            size: Vector2(buttonWidth, buttonHeight)
        )
    }

    private var deleteButtonFrame: Rect {
        let buttonHeight: Float = 60 * UIScale  // Match the button height used in save slots
        let imageAspectRatio: Float = 805.0 / 279.0
        let buttonWidth: Float = buttonHeight * imageAspectRatio
        let spacing: Float = 5 * UIScale
        let loadButtonWidth = buttonWidth
        return Rect(
            center: Vector2(frame.maxX - loadButtonWidth - buttonWidth / 2 - spacing * 2, frame.center.y),
            size: Vector2(buttonWidth, buttonHeight)
        )
    }

    private var renameButtonFrame: Rect {
        let buttonHeight: Float = 40 * UIScale  // Smaller button for rename
        let buttonWidth: Float = buttonHeight  // Square button
        let spacing: Float = 5 * UIScale
        let imageAspectRatio: Float = 805.0 / 279.0
        let loadButtonWidth: Float = 60 * UIScale * imageAspectRatio
        let deleteButtonWidth: Float = loadButtonWidth
        return Rect(
            center: Vector2(frame.maxX - loadButtonWidth - deleteButtonWidth - buttonWidth / 2 - spacing * 3, frame.center.y),
            size: Vector2(buttonWidth, buttonHeight)
        )
    }
    
    init(frame: Rect, slotInfo: SaveSlotInfo) {
        self.frame = frame
        self.slotInfo = slotInfo
    }
    
    func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }

        // Check if load button was tapped
        if loadButtonFrame.contains(position) {
            onLoadTap?()
            return true
        }

        // Check if delete button was tapped
        if deleteButtonFrame.contains(position) {
            onDeleteTap?()
            return true
        }

        // Check if rename button was tapped (only for non-autosave slots)
        if renameButtonFrame.contains(position) && !slotInfo.name.hasPrefix("autosave_") {
            onRenameTap?()
            return true
        }

        // Otherwise, treat as slot tap
        onTap?()
        return true
    }
    
    func render(renderer: MetalRenderer) {
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        
        // Button background - different color for autosave slots
        let isAutosave = slotInfo.name.hasPrefix("autosave_")
        let bgColor = isAutosave ? Color(r: 0.12, g: 0.18, b: 0.15, a: 1) : Color(r: 0.15, g: 0.15, b: 0.2, a: 1)
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: solidRect,
            color: bgColor,
            layer: .ui
        ))
        
        // Button border
        let borderColor = Color(r: 0.25, g: 0.25, b: 0.3, a: 1)
        let borderThickness: Float = 2 * UIScale
        renderer.queueSprite(SpriteInstance(
            position: Vector2(frame.minX + borderThickness / 2, frame.center.y),
            size: Vector2(borderThickness, frame.height),
            textureRect: solidRect,
            color: borderColor,
            layer: .ui
        ))
        renderer.queueSprite(SpriteInstance(
            position: Vector2(frame.maxX - borderThickness / 2, frame.center.y),
            size: Vector2(borderThickness, frame.height),
            textureRect: solidRect,
            color: borderColor,
            layer: .ui
        ))
        renderer.queueSprite(SpriteInstance(
            position: Vector2(frame.center.x, frame.minY + borderThickness / 2),
            size: Vector2(frame.width, borderThickness),
            textureRect: solidRect,
            color: borderColor,
            layer: .ui
        ))
        renderer.queueSprite(SpriteInstance(
            position: Vector2(frame.center.x, frame.maxY - borderThickness / 2),
            size: Vector2(frame.width, borderThickness),
            textureRect: solidRect,
            color: borderColor,
            layer: .ui
        ))
        
        // Render load button (right side)
        let loadRect = renderer.textureAtlas.getTextureRect(for: "load_game")
        renderer.queueSprite(SpriteInstance(
            position: loadButtonFrame.center,
            size: loadButtonFrame.size,
            textureRect: loadRect,
            color: .white,
            layer: .ui
        ))
        
        // Render delete button (to the left of load button)
        let deleteRect = renderer.textureAtlas.getTextureRect(for: "delete_game")
        renderer.queueSprite(SpriteInstance(
            position: deleteButtonFrame.center,
            size: deleteButtonFrame.size,
            textureRect: deleteRect,
            color: .white,
            layer: .ui
        ))

        // Render rename button only for non-autosave slots
        if !isAutosave {
            let renameButtonColor = Color(r: 0.3, g: 0.6, b: 0.8, a: 1)
            renderer.queueSprite(SpriteInstance(
                position: renameButtonFrame.center,
                size: renameButtonFrame.size,
                textureRect: solidRect,
                color: renameButtonColor,
                layer: .ui
            ))

            // Render rename icon (simple "R" text approximation)
            let iconSize: Float = 12 * UIScale
            renderer.queueSprite(SpriteInstance(
                position: renameButtonFrame.center + Vector2(-2 * UIScale, 0),
                size: Vector2(iconSize * 0.8, iconSize),
                textureRect: solidRect,
                color: .white,
                layer: .ui
            ))
            renderer.queueSprite(SpriteInstance(
                position: renameButtonFrame.center + Vector2(2 * UIScale, -3 * UIScale),
                size: Vector2(iconSize * 0.6, iconSize * 0.3),
                textureRect: solidRect,
                color: .white,
                layer: .ui
            ))
        } else {
            // Render autosave indicator instead of rename button
            let autosaveColor = Color(r: 0.4, g: 0.7, b: 0.5, a: 1)
            renderer.queueSprite(SpriteInstance(
                position: renameButtonFrame.center,
                size: renameButtonFrame.size,
                textureRect: solidRect,
                color: autosaveColor,
                layer: .ui
            ))

            // Render "A" for autosave
            let iconSize: Float = 12 * UIScale
            renderer.queueSprite(SpriteInstance(
                position: renameButtonFrame.center + Vector2(-3 * UIScale, 0),
                size: Vector2(iconSize * 0.6, iconSize),
                textureRect: solidRect,
                color: .white,
                layer: .ui
            ))
            renderer.queueSprite(SpriteInstance(
                position: renameButtonFrame.center + Vector2(3 * UIScale, -3 * UIScale),
                size: Vector2(iconSize * 0.6, iconSize * 0.3),
                textureRect: solidRect,
                color: .white,
                layer: .ui
            ))
        }

        // Text is rendered using UILabel overlays (see setupLabels and updateSlotLabels)
    }

    func getTooltip(at position: Vector2) -> String? {
        // Loading menu doesn't need detailed tooltips for individual elements
        return nil
    }
}
