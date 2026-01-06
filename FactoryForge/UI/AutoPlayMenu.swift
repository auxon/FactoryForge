import Foundation
import UIKit

/// Clickable label that can respond to tap events
class ClickableLabel: UILabel {
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTapGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTapGesture()
    }

    private func setupTapGesture() {
        isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap() {
        onTap?()
    }
}

/// Auto-play configuration menu for selecting scenarios and starting automated testing
final class AutoPlayMenu: UIPanel_Base {
    private var screenSize: Vector2
    private var closeButton: CloseButton!
    private var scenarioLabels: [ClickableLabel] = []
    private var startLabel: ClickableLabel!
    private var stopLabel: ClickableLabel!
    private var speedLabels: [ClickableLabel] = []
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

        var scenarioIndex = 0
        var speedIndex = 0

        for (text, yPos, fontSize) in buttonTexts {
            let label = ClickableLabel()
            label.text = text
            label.font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: .medium)
            label.textColor = .white
            label.textAlignment = .center
            label.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
            label.layer.borderColor = UIColor.white.cgColor
            label.layer.borderWidth = 1.0
            label.layer.cornerRadius = 5.0

            let labelWidth: CGFloat = 250
            let labelHeight: CGFloat = 30
            // Position relative to scroll view content
            let labelX = (scrollView.frame.width - labelWidth) / 2  // Center horizontally in scroll view
            let labelY = CGFloat(yPos) / screenScale - labelHeight/2

            label.frame = CGRect(x: labelX, y: labelY, width: labelWidth, height: labelHeight)

            // Set up tap callbacks based on label type
            if text == "Select Scenario:" || text == "Select Speed:" {
                // Header labels - no tap action
            } else if text == "Start Auto-Play" {
                let offsetX = CGFloat(110 * UIScale) / screenScale
                let centerX = scrollView.frame.width / 2 - offsetX
                label.frame.origin.x = centerX - labelWidth/2
                startLabel = label
                label.onTap = { [weak self] in
                    guard let self = self,
                          let scenario = self.selectedScenario else {
                        return
                    }
                    AudioManager.shared.playClickSound()
                    self.onStartAutoplay?(scenario, self.selectedSpeed)
                }
            } else if text == "Stop Auto-Play" {
                let offsetX = CGFloat(110 * UIScale) / screenScale
                let centerX = scrollView.frame.width / 2 + offsetX
                label.frame.origin.x = centerX - labelWidth/2
                stopLabel = label
                label.onTap = { [weak self] in
                    AudioManager.shared.playClickSound()
                    self?.onStopAutoplay?()
                }
            } else if scenarioIndex < 5 && ["Basic Test", "Speed Demo", "Basic Mining", "Smelting Setup", "Production Line"].contains(where: { text.contains($0) }) {
                // Scenario selection labels
                let scenarioId = ["basic_test", "speed_demo", "basic_mining", "smelting_setup", "production_line"][scenarioIndex]
                scenarioLabels.append(label)
                label.onTap = { [weak self] in
                    AudioManager.shared.playClickSound()
                    self?.selectedScenario = scenarioId
                    self?.onScenarioSelected?(scenarioId)
                    self?.updateLabelSelection()
                }
                scenarioIndex += 1
            } else if speedIndex < 5 {
                // Speed selection labels
                let speedValue = [0.5, 1.0, 2.0, 4.0, 8.0][speedIndex]
                speedLabels.append(label)
                label.onTap = { [weak self] in
                    AudioManager.shared.playClickSound()
                    self?.selectedSpeed = speedValue
                    self?.updateLabelSelection()
                }
                speedIndex += 1
            }

            scrollView.addSubview(label)
            textLabels.append(label)
        }
    }

    private func updateLabelSelection() {
        // Reset all labels to default appearance
        for label in scenarioLabels + speedLabels {
            label.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
        }

        // Debug: Check array sizes
        print("AutoPlayMenu: Updating selection - scenarios: \(scenarioLabels.count), speeds: \(speedLabels.count), selectedScenario: \(selectedScenario ?? "none"), selectedSpeed: \(selectedSpeed)")

        // Highlight selected scenario
        if let selectedScenario = selectedScenario,
           let index = ["basic_test", "speed_demo", "basic_mining", "smelting_setup", "production_line"].firstIndex(of: selectedScenario),
           index < scenarioLabels.count {
            scenarioLabels[index].backgroundColor = UIColor.blue.withAlphaComponent(0.5)
            print("AutoPlayMenu: Highlighted scenario at index \(index)")
        }

        // Highlight selected speed - map speed values to indices
        let speedToIndex: [Double: Int] = [0.5: 0, 1.0: 1, 2.0: 2, 4.0: 3, 8.0: 4]
        if let index = speedToIndex[selectedSpeed], index < speedLabels.count {
            speedLabels[index].backgroundColor = UIColor.green.withAlphaComponent(0.5)
            print("AutoPlayMenu: Highlighted speed at index \(index)")
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
        // Labels are created in updateLabels() and are already clickable
        // Just set up initial selection state
        updateLabelSelection()
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

        // Labels are rendered via UIKit, not Metal
    }

    override func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }

        // Check close button first
        if closeButton.handleTap(at: position) {
            return true
        }

        // Labels handle their own tap events via gesture recognizers
        // No need to check individual buttons since labels are clickable

        return true // Consume tap within panel bounds
    }
}
