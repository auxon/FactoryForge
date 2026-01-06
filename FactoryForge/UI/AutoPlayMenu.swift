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
        updateLabels()
    }

    private func updateLabels() {
        guard let parentView = parentView else { return }

        // Remove old labels
        for label in textLabels {
            label.removeFromSuperview()
        }
        textLabels.removeAll()

        let screenScale = CGFloat(UIScreen.main.scale)

        // Button texts
        let buttonTexts = [
            ("Select Scenario:", frame.minY + 60 * UIScale, 20),
            ("Basic Test - Speed changes", frame.minY + 100 * UIScale, 16),
            ("Speed Demo - Auto speed cycling", frame.minY + 140 * UIScale, 16),
            ("Select Speed:", frame.minY + 180 * UIScale, 20),
            ("0.5x Slow", frame.minY + 220 * UIScale, 16),
            ("1x Normal", frame.minY + 260 * UIScale, 16),
            ("2x Fast", frame.minY + 300 * UIScale, 16),
            ("4x Faster", frame.minY + 340 * UIScale, 16),
            ("8x Fastest", frame.minY + 380 * UIScale, 16),
            ("Start Auto-Play", frame.maxY - 100 * UIScale, 18),
            ("Stop Auto-Play", frame.maxY - 100 * UIScale, 18)
        ]

        for (text, yPos, fontSize) in buttonTexts {
            let label = UILabel()
            label.text = text
            label.font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: .medium)
            label.textColor = .white
            label.textAlignment = .center
            label.backgroundColor = .clear

            let labelWidth: CGFloat = 250
            let labelHeight: CGFloat = 30
            let labelX = (CGFloat(frame.center.x) - labelWidth/2) / screenScale
            let labelY = CGFloat(yPos) / screenScale - labelHeight/2

            label.frame = CGRect(x: labelX, y: labelY, width: labelWidth, height: labelHeight)

            // Special positioning for start/stop buttons
            if text == "Start Auto-Play" {
                label.frame.origin.x = (CGFloat(frame.center.x - 110 * UIScale) - labelWidth/2) / screenScale
            } else if text == "Stop Auto-Play" {
                label.frame.origin.x = (CGFloat(frame.center.x + 110 * UIScale) - labelWidth/2) / screenScale
            }

            parentView.addSubview(label)
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
            ("speed_demo", "Speed Demo - Auto speed cycling")
        ]

        for (scenarioId, scenarioName) in scenarios {
            let button = UIButton(
                frame: Rect(
                    center: Vector2(frame.center.x, currentY + buttonHeight / 2),
                    size: Vector2(buttonWidth, buttonHeight)
                ),
                textureId: "solid_white"  // Use solid color for text buttons
            )
            button.onTap = { [weak self] in
                AudioManager.shared.playClickSound()
                self?.selectedScenario = scenarioId
                self?.onScenarioSelected?(scenarioId)
                print("Selected scenario: \(scenarioId)")
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

        for (speedName, speedValue) in speeds {
            let button = UIButton(
                frame: Rect(
                    center: Vector2(frame.center.x, currentY + buttonHeight / 2),
                    size: Vector2(buttonWidth, buttonHeight)
                ),
                textureId: "solid_white"  // Use solid color for text buttons
            )
            button.onTap = { [weak self] in
                AudioManager.shared.playClickSound()
                self?.selectedSpeed = speedValue
                print("Selected speed: \(speedValue)x")
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
                print("No scenario selected!")
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
        // Show labels when menu opens
        for label in textLabels {
            label.isHidden = false
        }
    }

    override func close() {
        super.close()
        // Hide labels when menu closes
        for label in textLabels {
            label.isHidden = true
        }
    }

    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Render close button
        closeButton.render(renderer: renderer)

        // Render scenario buttons
        for button in scenarioButtons {
            button.render(renderer: renderer)
        }

        // Render speed buttons
        for button in speedButtons {
            button.render(renderer: renderer)
        }

        // Render control buttons
        startButton.render(renderer: renderer)
        stopButton.render(renderer: renderer)
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
