import Foundation
import UIKit

/// Loading menu for starting new game or loading saved games
final class LoadingMenu: UIPanel_Base {
    private var saveSystem: SaveSystem
    private var newGameButton: UIButton!
    private var saveGameButton: UIButton!
    private var saveSlotButtons: [SaveSlotButton] = []
    private var slotLabels: [UILabel] = [] // Labels for save slot information
    
    var onNewGameSelected: (() -> Void)?
    var onSaveSlotSelected: ((String) -> Void)? // Called when a save slot is selected to load
    var onSaveSlotDelete: ((String) -> Void)? // Called when delete button is pressed for a save slot
    var onSaveGameRequested: (() -> Void)? // Called when save button is pressed
    
    init(screenSize: Vector2) {
        self.saveSystem = SaveSystem()
        
        let panelWidth: Float = 500 * UIScale
        let panelHeight: Float = 600 * UIScale
        // Move menu down - center it lower on the screen
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2 + 50 * UIScale),
            size: Vector2(panelWidth, panelHeight)
        )
        
        super.init(frame: panelFrame)
        
        setupButtons()
        refreshSaveSlots()
    }
    
    private func setupButtons() {
        // Button images are 805x279px (aspect ratio ~2.89:1), calculate size to preserve aspect ratio
        let imageAspectRatio: Float = 805.0 / 279.0  // ~2.89
        let buttonHeight: Float = 90 * UIScale  // Base height
        let buttonWidth: Float = buttonHeight * imageAspectRatio  // Maintain aspect ratio
        let buttonSpacing: Float = 15 * UIScale
        let buttonY = frame.minY + 40 * UIScale
        
        // New Game button at the top
        newGameButton = UIButton(
            frame: Rect(
                center: Vector2(frame.center.x, buttonY + buttonHeight / 2),
                size: Vector2(buttonWidth, buttonHeight)
            ),
            textureId: "new_game"
        )
        newGameButton.onTap = { [weak self] in
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
            self?.onSaveGameRequested?()
        }
    }
    
    func setShowSaveButton(_ show: Bool) {
        // Save button visibility will be controlled by whether onSaveGameRequested is set
    }
    
    func refreshSaveSlots() {
        // Remove old labels
        removeSlotLabels()
        
        saveSlotButtons.removeAll()
        
        let slots = saveSystem.getSaveSlots()
        
        // Save slot area width (leave space for load/delete buttons on the right)
        let slotAreaWidth: Float = 460 * UIScale
        let buttonHeight: Float = 60 * UIScale
        let buttonSpacing: Float = 10 * UIScale
        let startY = frame.minY + 240 * UIScale // Move down to accommodate save button (which is taller now)
        let maxButtons = 7 // Maximum number of save slots to display
        
        // Load/Delete button size (using same aspect ratio as other buttons)
        let imageAspectRatio: Float = 805.0 / 279.0
        let loadDeleteButtonHeight: Float = 50 * UIScale
        let loadDeleteButtonWidth: Float = loadDeleteButtonHeight * imageAspectRatio
        
        for (index, slot) in slots.prefix(maxButtons).enumerated() {
            let buttonY = startY + Float(index) * (buttonHeight + buttonSpacing)
            
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
                self?.onSaveSlotSelected?(slot.name)
            }
            slotButton.onDeleteTap = { [weak self] in
                self?.onSaveSlotDelete?(slot.name)
            }
            saveSlotButtons.append(slotButton)
        }
        
        // Update labels (will be created in setupLabels if parent view is set)
        updateSlotLabels()
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
        
        let screenScale = CGFloat(UIScreen.main.scale)
        
        for (index, slotButton) in saveSlotButtons.enumerated() {
            let slotInfo = slotButton.slotInfo
            
            // Create label if it doesn't exist
            if index >= slotLabels.count {
                let label = UILabel()
                label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
                label.textColor = .white
                label.numberOfLines = 3
                label.backgroundColor = .clear
                parentView.addSubview(label)
                slotLabels.append(label)
            }
            
            let label = slotLabels[index]
            
            // Format the date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            let formattedDate = dateFormatter.string(from: slotInfo.modificationDate)
            
            // Create text with name, play time, and date
            let text = "\(slotInfo.name)\n\(slotInfo.formattedPlayTime)\n\(formattedDate)"
            label.text = text
            
            // Position label based on slot button frame (convert Metal coordinates to UIKit)
            // Metal uses bottom-left origin, UIKit uses top-left origin
            // Metal coordinates are already in pixels (accounting for screen scale), so we divide by screenScale to get points
            let screenHeight = CGFloat(parentView.bounds.height)
            let labelX = CGFloat(slotButton.frame.minX + 10 * UIScale) / screenScale
            let labelY = screenHeight - (CGFloat(slotButton.frame.maxY) / screenScale) + 5
            let labelWidth = CGFloat(slotButton.frame.width - 200 * UIScale) / screenScale // Leave room for buttons
            let labelHeight = CGFloat(slotButton.frame.height - 10 * UIScale) / screenScale
            
            label.frame = CGRect(x: labelX, y: labelY, width: labelWidth, height: labelHeight)
            label.isHidden = !isOpen
        }
        
        // Remove excess labels
        while slotLabels.count > saveSlotButtons.count {
            slotLabels.last?.removeFromSuperview()
            slotLabels.removeLast()
        }
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
    }
    
    override func close() {
        super.close()
        // Hide labels when menu closes
        for label in slotLabels {
            label.isHidden = true
        }
    }
    
    override func render(renderer: MetalRenderer) {
        super.render(renderer: renderer)
        
        // Render title
        renderTitle(renderer: renderer)
        
        // Render New Game button
        renderNewGameButton(renderer: renderer)
        
        // Render Save Game button (if callback is set, meaning game is running)
        if onSaveGameRequested != nil {
            renderSaveGameButton(renderer: renderer)
        }
        
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
    
    private func renderEmptyState(renderer: MetalRenderer) {
        // Could render "No saved games" text here
        // For now, just leave empty
    }
    
    override func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }
        
        // Check New Game button
        if newGameButton?.handleTap(at: position) == true {
            return true
        }
        
        // Check Save Game button (if visible)
        if onSaveGameRequested != nil, saveGameButton?.handleTap(at: position) == true {
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
    
    // Load and delete button frames (positioned on the right side of the slot)
    private var loadButtonFrame: Rect {
        let buttonHeight: Float = 50 * UIScale
        let imageAspectRatio: Float = 805.0 / 279.0
        let buttonWidth: Float = buttonHeight * imageAspectRatio
        let spacing: Float = 5 * UIScale
        return Rect(
            center: Vector2(frame.maxX - buttonWidth / 2 - spacing, frame.center.y),
            size: Vector2(buttonWidth, buttonHeight)
        )
    }
    
    private var deleteButtonFrame: Rect {
        let buttonHeight: Float = 50 * UIScale
        let imageAspectRatio: Float = 805.0 / 279.0
        let buttonWidth: Float = buttonHeight * imageAspectRatio
        let spacing: Float = 5 * UIScale
        let loadButtonWidth = buttonWidth
        return Rect(
            center: Vector2(frame.maxX - loadButtonWidth - buttonWidth / 2 - spacing * 2, frame.center.y),
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
        
        // Otherwise, treat as slot tap
        onTap?()
        return true
    }
    
    func render(renderer: MetalRenderer) {
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        
        // Button background
        let bgColor = Color(r: 0.15, g: 0.15, b: 0.2, a: 1)
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
        
        // Text is rendered using UILabel overlays (see setupLabels and updateSlotLabels)
    }
}

