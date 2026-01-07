import Foundation
import UIKit

/// Help menu that displays a list of documentation files
final class HelpMenu: UIPanel_Base {
    private var screenSize: Vector2 // Store screen size for coordinate conversion

    // Document list
    private let documents = [
        "INSTRUCTIONS.md",
        "Belt Mechanics.md",
        "Research.md",
        "How to Use a Furnace.md",
        "autoplay_plan.md"
    ]

    private var documentButtons: [UIButton] = []
    private var documentLabels: [UILabel] = []
    private var closeButton: CloseButton!

    var onDocumentSelected: ((String) -> Void)? // Called when a document is selected
    var onCloseTapped: (() -> Void)? // Called when close button is tapped

    init(screenSize: Vector2) {
        self.screenSize = screenSize

        // Use full screen size for background
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(screenSize.x, screenSize.y)
        )

        super.init(frame: panelFrame)

        setupCloseButton()
        setupDocumentButtons()
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

    private func setupDocumentButtons() {
        let buttonHeight: Float = 60 * UIScale
        let buttonWidth: Float = frame.width * 0.8 // 80% of panel width
        let buttonSpacing: Float = 10 * UIScale
        let startY = frame.center.y - 150 * UIScale // Start above center

        for (index, documentName) in documents.enumerated() {
            let buttonY = startY + Float(index) * (buttonHeight + buttonSpacing)

            let button = UIButton(
                frame: Rect(
                    center: Vector2(frame.center.x, buttonY + buttonHeight / 2),
                    size: Vector2(buttonWidth, buttonHeight)
                ),
                textureId: "solid_white"
            )

            button.onTap = { [weak self] in
                AudioManager.shared.playClickSound()
                self?.onDocumentSelected?(documentName)
            }

            documentButtons.append(button)
        }
    }

    private weak var parentView: UIView?

    /// Sets up UILabel overlays for document names
    func setupLabels(in parentView: UIView) {
        self.parentView = parentView
        removeDocumentLabels()
        updateDocumentLabels()
    }

    private func updateDocumentLabels() {
        guard let parentView = parentView else { return }

        let screenScale = CGFloat(UIScreen.main.scale)

        for (index, button) in documentButtons.enumerated() {
            let documentName = documents[index]

            // Create label if it doesn't exist
            if index >= documentLabels.count {
                let label = UILabel()
                label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
                label.textColor = .white
                label.textAlignment = .center
                label.backgroundColor = .clear
                label.numberOfLines = 0
                parentView.addSubview(label)
                documentLabels.append(label)
            }

            let label = documentLabels[index]
            label.text = documentName.replacingOccurrences(of: ".md", with: "").replacingOccurrences(of: "_", with: " ")

            // Position label centered on button
            let buttonCenterXPixels = CGFloat(button.frame.center.x)
            let buttonCenterYPixels = CGFloat(button.frame.center.y)

            let buttonCenterXPoints = buttonCenterXPixels / screenScale
            let buttonCenterYPoints = buttonCenterYPixels / screenScale

            let buttonWidthPoints = CGFloat(button.frame.size.x) / screenScale
            let buttonHeightPoints = CGFloat(button.frame.size.y) / screenScale

            label.frame = CGRect(
                x: buttonCenterXPoints - buttonWidthPoints / 2,
                y: buttonCenterYPoints - buttonHeightPoints / 2,
                width: buttonWidthPoints,
                height: buttonHeightPoints
            )

            label.isHidden = !isOpen
        }

        // Remove excess labels
        while documentLabels.count > documentButtons.count {
            documentLabels.last?.removeFromSuperview()
            documentLabels.removeLast()
        }
    }

    private func removeDocumentLabels() {
        for label in documentLabels {
            label.removeFromSuperview()
        }
        documentLabels.removeAll()
    }

    override func open() {
        super.open()
        // Show labels when menu opens
        for label in documentLabels {
            label.isHidden = false
        }
    }

    override func close() {
        super.close()
        // Hide labels when menu closes
        for label in documentLabels {
            label.isHidden = true
        }
    }

    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Render close button
        closeButton.render(renderer: renderer)

        // Render title
        renderTitle(renderer: renderer)

        // Render document buttons
        for button in documentButtons {
            renderDocumentButton(button, renderer: renderer)
        }
    }

    private func renderTitle(renderer: MetalRenderer) {
        // Title rendered as text (could use UILabel overlay if needed)
        // For now, just leave space for title
    }

    private func renderDocumentButton(_ button: UIButton, renderer: MetalRenderer) {
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")

        // Button background
        let bgColor = Color(r: 0.15, g: 0.15, b: 0.2, a: 1)
        renderer.queueSprite(SpriteInstance(
            position: button.frame.center,
            size: button.frame.size,
            textureRect: solidRect,
            color: bgColor,
            layer: .ui
        ))

        // Button border
        let borderColor = Color(r: 0.25, g: 0.25, b: 0.3, a: 1)
        let borderThickness: Float = 2 * UIScale

        // Top border
        renderer.queueSprite(SpriteInstance(
            position: Vector2(button.frame.center.x, button.frame.minY + borderThickness / 2),
            size: Vector2(button.frame.width, borderThickness),
            textureRect: solidRect,
            color: borderColor,
            layer: .ui
        ))

        // Bottom border
        renderer.queueSprite(SpriteInstance(
            position: Vector2(button.frame.center.x, button.frame.maxY - borderThickness / 2),
            size: Vector2(button.frame.width, borderThickness),
            textureRect: solidRect,
            color: borderColor,
            layer: .ui
        ))

        // Left border
        renderer.queueSprite(SpriteInstance(
            position: Vector2(button.frame.minX + borderThickness / 2, button.frame.center.y),
            size: Vector2(borderThickness, button.frame.height),
            textureRect: solidRect,
            color: borderColor,
            layer: .ui
        ))

        // Right border
        renderer.queueSprite(SpriteInstance(
            position: Vector2(button.frame.maxX - borderThickness / 2, button.frame.center.y),
            size: Vector2(borderThickness, button.frame.height),
            textureRect: solidRect,
            color: borderColor,
            layer: .ui
        ))
    }

    override func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }

        // Check close button first
        if closeButton.handleTap(at: position) {
            return true
        }

        // Check document buttons
        for button in documentButtons {
            if button.handleTap(at: position) {
                return true
            }
        }

        return true // Consume tap within panel bounds
    }
}
