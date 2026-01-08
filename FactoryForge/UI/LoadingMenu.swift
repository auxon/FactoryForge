import Foundation
import UIKit

/// Loading menu for starting new game or loading saved games
final class LoadingMenu: UIPanel_Base {
    private var saveSystem: SaveSystem
    private var screenSize: Vector2 // Store screen size for coordinate conversion
    private var autoplayButton: UIButton!
    private var helpButton: UIButton!
    private var audioToggleButton: UIButton!
    private var helpButtonLabel: UILabel? // Label for help button question mark
    private var closeButton: CloseButton!

    // Save slot scrolling with UIKit
    private var scrollView: UIScrollView?
    private var saveSlotLabels: [UILabel] = [] // Clickable labels for save slots
    
    var onNewGameSelected: (() -> Void)?
    var onSaveSlotSelected: ((String) -> Void)? // Called when a save slot label is tapped to load
    var onSaveSlotDelete: ((String) -> Void)? // Called when delete button is pressed for a save slot
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
    }
    

    
    func refreshSaveSlots() {
        // This method is now handled by setupLabels which creates the UIKit scroll view
        // Just ensure labels are updated if we have a parent view
        if parentView != nil {
            setupLabels(in: parentView!)
        }
    }
    
    private weak var parentView: UIView?
    
    /// Sets up UIScrollView with clickable UILabels for save slots
    /// Must be called from GameViewController after LoadingMenu is created
    func setupLabels(in parentView: UIView) {
        self.parentView = parentView
        removeSaveSlotLabels()

        let slots = saveSystem.getSaveSlots()
        if slots.isEmpty {
            return
        }

        // Create scroll view for save slots
        let scrollViewHeight: CGFloat = 300 // Fixed height for scrollable area
        let scrollViewY = (parentView.bounds.height - scrollViewHeight) / 2 - 50 // Position above center
        let scrollViewFrame = CGRect(
            x: parentView.bounds.width * 0.1, // 10% margin on sides
            y: scrollViewY,
            width: parentView.bounds.width * 0.8, // 80% width
            height: scrollViewHeight
        )

        let scrollView = UIScrollView(frame: scrollViewFrame)
        scrollView.backgroundColor = UIColor(white: 0.1, alpha: 0.8)
        scrollView.layer.borderColor = UIColor(white: 0.3, alpha: 1).cgColor
        scrollView.layer.borderWidth = 2
        scrollView.layer.cornerRadius = 8
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false

        parentView.addSubview(scrollView)
        self.scrollView = scrollView

        // Calculate content size and create labels
        let labelHeight: CGFloat = 50
        let labelSpacing: CGFloat = 8
        let totalHeight = CGFloat(slots.count) * (labelHeight + labelSpacing) - labelSpacing

        scrollView.contentSize = CGSize(width: scrollViewFrame.width, height: max(totalHeight, scrollViewHeight))

        for (index, slot) in slots.enumerated() {
            let labelY = CGFloat(index) * (labelHeight + labelSpacing)
            let labelFrame = CGRect(x: 8, y: labelY, width: scrollViewFrame.width - 16, height: labelHeight)

            let label = UILabel(frame: labelFrame)
            label.text = slot.effectiveDisplayName
            label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            label.textColor = .white
            label.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
            label.textAlignment = .center
            label.layer.borderColor = UIColor(white: 0.4, alpha: 1).cgColor
            label.layer.borderWidth = 1
            label.layer.cornerRadius = 4
            label.isUserInteractionEnabled = true

            // Add tap gesture recognizer
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(saveSlotLabelTapped(_:)))
            label.addGestureRecognizer(tapGesture)

            // Store slot name in label for identification
            label.accessibilityIdentifier = slot.name

            scrollView.addSubview(label)
            saveSlotLabels.append(label)
        }

        scrollView.isHidden = !isOpen

        // Setup help button label
        setupHelpButtonLabel()
    }
    
    @objc private func saveSlotLabelTapped(_ gesture: UITapGestureRecognizer) {
        guard let label = gesture.view as? UILabel,
              let slotName = label.accessibilityIdentifier else { return }

        AudioManager.shared.playClickSound()
        onSaveSlotSelected?(slotName)
    }

    private func removeSaveSlotLabels() {
        // Remove scroll view and all its subviews
        scrollView?.removeFromSuperview()
        scrollView = nil
        saveSlotLabels.removeAll()

        // Also remove help button label
        helpButtonLabel?.removeFromSuperview()
        helpButtonLabel = nil
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
    
    
    override func open() {
        super.open()
        refreshSaveSlots()
        // Show scroll view and help button label when menu opens
        scrollView?.isHidden = false
        helpButtonLabel?.isHidden = false
    }

    override func close() {
        super.close()
        // Hide scroll view and help button label when menu closes
        scrollView?.isHidden = true
        helpButtonLabel?.isHidden = true
    }
    
    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Render close button
        closeButton.render(renderer: renderer)

        // Render title
        renderTitle(renderer: renderer)

        // Render Help button
        renderHelpButton(renderer: renderer)

        // Render Autoplay button
        renderAutoplayButton(renderer: renderer)

        // Render Audio Toggle button
        renderAudioToggleButton(renderer: renderer)
    }
    
    private func renderTitle(renderer: MetalRenderer) {
        // Title rendered as text (using sprites for now, could use UILabel overlay)
        // For now, just leave space for title
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

        return true // Consume tap within panel bounds
    }
}

