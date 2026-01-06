import Foundation
import UIKit

/// Auto-play configuration menu for selecting scenarios and starting automated testing
final class AutoPlayMenu: UIPanel_Base {
    private var screenSize: Vector2
    private var closeButton: CloseButton!
    private var scenarioButtons: [UIButton] = []
    private var startButton: UIButton!
    private var stopButton: UIButton!
    private var speedButtons: [UIButton] = []
    private var textLabels: [UILabel] = []
    private var scrollView: UIScrollView?
    private var contentOffset: Float = 0
    private var maxContentOffset: Float = 0
    private var lastTouchY: Float = 0
    private var isDragging = false

    // Current selection
    private var selectedScenario: String?
    private var selectedSpeed: Double = 1.0

    var onScenarioSelected: ((String) -> Void)?
    var onStartAutoplay: ((String, Double) -> Void)?
    var onStopAutoplay: (() -> Void)?
    var onCloseTapped: (() -> Void)?

    init(screenSize: Vector2) {
        self.screenSize = screenSize

        // Use full screen size for background
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(screenSize.x, screenSize.y)
        )

        super.init(frame: panelFrame)

        setupCloseButton()
        setupButtons()
    }

    private weak var parentView: UIView?

    /// Sets up UILabel overlays for button text
    /// Must be called from GameViewController after AutoPlayMenu is created
    func setupLabels(in parentView: UIView) {
        self.parentView = parentView

        // Create scroll view
        setupScrollView(in: parentView)
        updateLabels()
    }

    private func setupScrollView(in parentView: UIView) {
        // Remove existing scroll view if any
        scrollView?.removeFromSuperview()

        let screenScale = CGFloat(UIScreen.main.scale)

        // Scroll view covers most of the screen, leaving space for close button
        let scrollViewFrame = CGRect(
            x: 0,
            y: 60 / screenScale, // Leave space at top for close button
            width: CGFloat(screenSize.x) / screenScale,
            height: (CGFloat(screenSize.y) - 120) / screenScale // Leave space at bottom
        )

        scrollView = UIScrollView(frame: scrollViewFrame)
        scrollView?.backgroundColor = .clear
        scrollView?.showsVerticalScrollIndicator = true
        scrollView?.showsHorizontalScrollIndicator = false
        scrollView?.alwaysBounceVertical = true

        if let scrollView = scrollView {
            parentView.addSubview(scrollView)
        }
    }

    private func updateLabels() {
        guard let scrollView = scrollView else { return }

        // Remove old labels
        for label in textLabels {
            label.removeFromSuperview()
        }
        textLabels.removeAll()

        let screenScale = CGFloat(UIScreen.main.scale)

        // Calculate content positions relative to scroll view
        let buttonHeight: Float = 40 * UIScale
        let buttonSpacing: Float = 15 * UIScale
        var contentY: Float = 20 * UIScale  // Start a bit down from top of scroll view

        // Title
        var buttonTexts: [(String, Float, Int)] = [
            ("Select Scenario:", contentY, 20)
        ]
        contentY += buttonHeight

        // Scenario buttons
        let scenarios = [
            "Basic Test - Speed changes",
            "Speed Demo - Auto speed cycling",
            "Basic Mining - Place electric miner",
            "Smelting Setup - Miner + Furnace",
            "Production Line - Complete chain"
        ]

        for scenarioName in scenarios {
            buttonTexts.append((scenarioName, contentY + buttonHeight / 2, 16))
            contentY += buttonHeight + buttonSpacing
        }

        // Speed section
        contentY += buttonSpacing * 2
        buttonTexts.append(("Select Speed:", contentY, 20))
        contentY += buttonHeight

        let speeds = [
            "0.5x Slow",
            "1x Normal",
            "2x Fast",
            "4x Faster",
            "8x Fastest"
        ]

        for speedName in speeds {
            buttonTexts.append((speedName, contentY + buttonHeight / 2, 16))
            contentY += buttonHeight + buttonSpacing
        }

        // Control buttons - positioned near bottom of scroll view
        contentY += buttonSpacing * 2
        buttonTexts.append(("Start Auto-Play", contentY, 18))
        buttonTexts.append(("Stop Auto-Play", contentY, 18))
        contentY += buttonHeight + 20 * UIScale  // Add some bottom padding

        // Set scroll view content size
        let contentWidth = scrollView.frame.width
        let contentHeight = CGFloat(contentY) / screenScale
        scrollView.contentSize = CGSize(width: contentWidth, height: contentHeight)

        for (text, yPos, fontSize) in buttonTexts {
            let label = UILabel()
            label.text = text
            label.font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: .medium)
            label.textColor = .white
            label.textAlignment = .center
            label.backgroundColor = .clear

            let labelWidth: CGFloat = 250
            let labelHeight: CGFloat = 30
            // Position relative to scroll view content
            let labelX = (scrollView.frame.width - labelWidth) / 2  // Center horizontally in scroll view
            let labelY = CGFloat(yPos) / screenScale - labelHeight/2

            label.frame = CGRect(x: labelX, y: labelY, width: labelWidth, height: labelHeight)

            // Special positioning for start/stop buttons
            if text == "Start Auto-Play" {
                let offsetX = CGFloat(110 * UIScale) / screenScale
                let centerX = scrollView.frame.width / 2 - offsetX
                label.frame.origin.x = centerX - labelWidth/2
            } else if text == "Stop Auto-Play" {
                let offsetX = CGFloat(110 * UIScale) / screenScale
                let centerX = scrollView.frame.width / 2 + offsetX
                label.frame.origin.x = centerX - labelWidth/2
            }

            scrollView.addSubview(label)
            textLabels.append(label)
        }
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
        let buttonWidth: Float = 200 * UIScale
        let buttonHeight: Float = 40 * UIScale
        let buttonSpacing: Float = 15 * UIScale

        var currentY = frame.minY + 80 * UIScale

        // Title area (just spacing for now)
        currentY += 20 * UIScale

        // Scenario selection
        addSectionTitle("Select Scenario:", at: currentY)
        currentY += buttonHeight

        let scenarios = [
            ("basic_test", "Basic Test - Speed changes"),
            ("speed_demo", "Speed Demo - Auto speed cycling"),
            ("basic_mining", "Basic Mining - Place electric miner"),
            ("smelting_setup", "Smelting Setup - Miner + Furnace"),
            ("production_line", "Production Line - Complete chain")
        ]

        for (scenarioId, _) in scenarios {
            let button = UIButton(
                frame: Rect(
                    center: Vector2(frame.center.x, currentY + buttonHeight / 2),
                    size: Vector2(buttonWidth, buttonHeight)
                ),
                textureId: "solid_white"  // Invisible button - text labels provide visual interface
            )
            button.onTap = { [weak self] in
                AudioManager.shared.playClickSound()
                self?.selectedScenario = scenarioId
                self?.onScenarioSelected?(scenarioId)
            }
            scenarioButtons.append(button)
            currentY += buttonHeight + buttonSpacing
        }

        currentY += buttonSpacing * 2

        // Speed selection
        addSectionTitle("Select Speed:", at: currentY)
        currentY += buttonHeight

        let speeds: [(String, Double)] = [
            ("0.5x Slow", 0.5),
            ("1x Normal", 1.0),
            ("2x Fast", 2.0),
            ("4x Faster", 4.0),
            ("8x Fastest", 8.0)
        ]

        for (_, speedValue) in speeds {
            let button = UIButton(
                frame: Rect(
                    center: Vector2(frame.center.x, currentY + buttonHeight / 2),
                    size: Vector2(buttonWidth, buttonHeight)
                ),
                textureId: "solid_white"  // Invisible button - text labels provide visual interface
            )
            button.onTap = { [weak self] in
                AudioManager.shared.playClickSound()
                self?.selectedSpeed = speedValue
            }
            speedButtons.append(button)
            currentY += buttonHeight + buttonSpacing
        }

        currentY += buttonSpacing * 2

        // Control buttons
        let controlButtonY = frame.maxY - 100 * UIScale
        let controlSpacing: Float = 20 * UIScale

        startButton = UIButton(
            frame: Rect(
                center: Vector2(frame.center.x - buttonWidth/2 - controlSpacing/2, controlButtonY),
                size: Vector2(buttonWidth, buttonHeight)
            ),
            textureId: "solid_white"  // Use solid color for text buttons
        )
        startButton.onTap = { [weak self] in
            guard let self = self,
                  let scenario = self.selectedScenario else {
                return
            }
            AudioManager.shared.playClickSound()
            self.onStartAutoplay?(scenario, self.selectedSpeed)
        }

        stopButton = UIButton(
            frame: Rect(
                center: Vector2(frame.center.x + buttonWidth/2 + controlSpacing/2, controlButtonY),
                size: Vector2(buttonWidth, buttonHeight)
            ),
            textureId: "solid_white"  // Use solid color for text buttons
        )
        stopButton.onTap = { [weak self] in
            AudioManager.shared.playClickSound()
            self?.onStopAutoplay?()
        }
    }

    private func addSectionTitle(_ title: String, at y: Float) {
        // For now, just log the title since we don't have text rendering in Metal
        // In a full implementation, this would render text
        print("AutoPlay Menu: \(title)")
    }

    override func open() {
        super.open()
        // Show scroll view and labels when menu opens
        scrollView?.isHidden = false
        for label in textLabels {
            label.isHidden = false
        }
    }

    override func close() {
        super.close()
        // Hide scroll view and labels when menu closes
        scrollView?.isHidden = true
        for label in textLabels {
            label.isHidden = true
        }
    }

    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Render close button
        closeButton.render(renderer: renderer)

        // Note: Buttons are not rendered - text labels provide the visual interface
        // Buttons exist only for touch handling
    }

    override func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }

        // Check close button first
        if closeButton.handleTap(at: position) {
            return true
        }

        // Check scenario buttons
        for button in scenarioButtons {
            if button.handleTap(at: position) == true {
                return true
            }
        }

        // Check speed buttons
        for button in speedButtons {
            if button.handleTap(at: position) == true {
                return true
            }
        }

        // Check control buttons
        if startButton?.handleTap(at: position) == true {
            return true
        }
        if stopButton?.handleTap(at: position) == true {
            return true
        }

        return true // Consume tap within panel bounds
    }
}
