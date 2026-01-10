import Foundation
import UIKit

/// Research/Technology tree UI
final class ResearchUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var closeButton: CloseButton!
    private var selectedTech: Technology?

    // UIKit scrolling components (like HelpMenu)
    private var scrollView: UIKit.UIScrollView?
    private var techButtonViews: [UIKit.UIButton] = [] // UIKit buttons for scrolling
    private var researchButton: UIKit.UIButton? // Button to start research

    // Text labels
    private var researchInfoLabel: UIKit.UILabel?
    private var progressLabel: UIKit.UILabel?

    // Label management callbacks
    var onAddLabels: (([UIKit.UILabel]) -> Void)?
    var onRemoveLabels: (([UIKit.UILabel]) -> Void)?

    // View management callbacks for scroll view and research button
    var onAddViews: (([UIKit.UIView]) -> Void)?
    var onRemoveViews: (([UIKit.UIView]) -> Void)?

    // Tooltip callback
    var onShowTooltip: ((String) -> Void)?

    private weak var parentView: UIKit.UIView?
    
    init(screenSize: Vector2, gameLoop: GameLoop?) {
        // Use full screen size for background
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(screenSize.x, screenSize.y)
        )
        
        super.init(frame: panelFrame)
        self.gameLoop = gameLoop

        setupCloseButton()
    }

    private func setupScrollView(in parentView: UIKit.UIView) {
        // Remove existing scroll view if any
        scrollView?.removeFromSuperview()

        let screenScale = CGFloat(UIScreen.main.scale)

        // Scroll view covers most of the screen, leaving space for close button and margins
        let scrollViewFrame = CGRect(
            x: 20 / screenScale, // Small margin
            y: 60 / screenScale, // Leave space at top for close button
            width: (CGFloat(frame.width) - 40) / screenScale, // Leave margins
            height: (CGFloat(frame.height) - 120) / screenScale // Leave space at top and bottom
        )

        scrollView = UIKit.UIScrollView(frame: scrollViewFrame)
        scrollView?.backgroundColor = UIKit.UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.9)
        scrollView?.layer.borderColor = UIKit.UIColor.white.cgColor
        scrollView?.layer.borderWidth = 1.0
        scrollView?.layer.cornerRadius = 8.0
        scrollView?.showsVerticalScrollIndicator = true
        scrollView?.showsHorizontalScrollIndicator = false
        scrollView?.alwaysBounceVertical = true

        if let scrollView = scrollView {
            parentView.addSubview(scrollView)
            parentView.bringSubviewToFront(scrollView)
        }
    }

    /// Sets up UIScrollView with clickable UIButton overlays for tech selection
    /// Must be called from GameViewController after ResearchUI is created
    func setupLabels() {
        removeLabels()

        guard let registry = gameLoop?.technologyRegistry else {
            print("ResearchUI: No technology registry available")
            return
        }
        // Create scroll view for technologies (similar to HelpMenu)
        let screenBounds = UIScreen.main.bounds
        let scrollViewHeight: CGFloat = 200 // Smaller height to fit on screen
        let researchButtonHeight: CGFloat = 40
        let researchButtonSpacing: CGFloat = 10
        let startY: CGFloat = 80 // Fixed position below close button area
        let scrollViewFrame = CGRect(
            x: screenBounds.width * 0.1, // 10% margin on sides
            y: startY,
            width: screenBounds.width * 0.8, // 80% width
            height: scrollViewHeight
        )

        let scrollView = UIKit.UIScrollView(frame: scrollViewFrame)
        print("ResearchUI: Created scrollView with frame \(scrollViewFrame)")
        scrollView.backgroundColor = UIKit.UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.9)
        scrollView.layer.borderColor = UIKit.UIColor.white.cgColor
        scrollView.layer.borderWidth = 2.0
        scrollView.layer.cornerRadius = 8.0
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.isScrollEnabled = true
        scrollView.isUserInteractionEnabled = true

        self.scrollView = scrollView

        // Get all technologies sorted by tier and order
        let allTechs = registry.all

        // Calculate content size and create buttons
        let buttonHeight: CGFloat = 50
        let buttonSpacing: CGFloat = 8
        let contentHeight = CGFloat(allTechs.count) * (buttonHeight + buttonSpacing) - buttonSpacing

        scrollView.contentSize = CGSize(width: scrollViewFrame.width, height: max(contentHeight, scrollViewHeight))

        for (index, tech) in allTechs.enumerated() {
            let buttonY = CGFloat(index) * (buttonHeight + buttonSpacing)
            let buttonFrame = CGRect(x: 100, y: buttonY, width: scrollViewFrame.width - 200, height: buttonHeight)

            let button: UIKit.UIButton = UIKit.UIButton(type: UIKit.UIButton.ButtonType.custom)
            button.frame = buttonFrame

            // Set initial appearance
            updateTechButtonAppearance(button, for: tech)

            button.layer.borderWidth = 1
            button.layer.borderColor = UIKit.UIColor(white: 0.4, alpha: 1).cgColor
            button.layer.cornerRadius = 4
            button.titleLabel?.font = UIKit.UIFont.systemFont(ofSize: 14, weight: UIKit.UIFont.Weight.medium)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = UIKit.NSTextAlignment.center

            // Add tap gesture
            button.addTarget(self, action: #selector(techButtonTapped(_:)), for: UIKit.UIControl.Event.touchUpInside)

            // Store technology for identification
            button.accessibilityIdentifier = tech.id

            scrollView.addSubview(button)
            techButtonViews.append(button)
        }


        // Create research button below the scroll view
        let researchButtonFrame = CGRect(
            x: screenBounds.width * 0.1, // Same x as scroll view
            y: scrollViewFrame.maxY + researchButtonSpacing, // Below scroll view
            width: screenBounds.width * 0.8, // Same width as scroll view
            height: researchButtonHeight
        )

        let researchBtn: UIKit.UIButton = UIKit.UIButton(type: UIKit.UIButton.ButtonType.custom)
        researchBtn.frame = researchButtonFrame
        researchBtn.setTitle("Research", for: UIKit.UIControl.State.normal)
        researchBtn.setTitleColor(UIKit.UIColor.white, for: UIKit.UIControl.State.normal)
        researchBtn.backgroundColor = UIKit.UIColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 0.8) // Blue background
        researchBtn.layer.borderWidth = 2
        researchBtn.layer.borderColor = UIKit.UIColor.white.cgColor
        researchBtn.layer.cornerRadius = 8
        researchBtn.titleLabel?.font = UIKit.UIFont.systemFont(ofSize: 18, weight: UIKit.UIFont.Weight.bold)
        researchBtn.addTarget(self, action: #selector(researchButtonTapped), for: UIKit.UIControl.Event.touchUpInside)
        researchBtn.isEnabled = false // Initially disabled until tech is selected
        researchBtn.alpha = 0.5 // Visually indicate disabled state

        self.researchButton = researchBtn

        // Create research info label (positioned outside scroll view)
        if researchInfoLabel == nil {
            let label = UIKit.UILabel()
            label.font = UIKit.UIFont.systemFont(ofSize: 16, weight: UIKit.UIFont.Weight.semibold)
            label.textColor = UIKit.UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0)  // Light blue-white
            label.numberOfLines = 1
            label.backgroundColor = UIKit.UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.8)  // Dark panel background
            label.textAlignment = UIKit.NSTextAlignment.right  // Right-aligned since label is on right side
            label.layer.cornerRadius = 4
            label.layer.masksToBounds = true
            // Add subtle shadow
            label.layer.shadowColor = UIKit.UIColor.black.cgColor
            label.layer.shadowOffset = CGSize(width: 1, height: 1)
            label.layer.shadowRadius = 2
            label.layer.shadowOpacity = 0.6
            researchInfoLabel = label
        }

        // Create progress label (positioned outside scroll view)
        if progressLabel == nil {
            let label = UIKit.UILabel()
            label.font = UIKit.UIFont.systemFont(ofSize: 14, weight: UIKit.UIFont.Weight.medium)
            label.textColor = UIKit.UIColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 1.0)  // Gold/yellow for progress
            label.numberOfLines = 0  // Allow multiple lines
            label.backgroundColor = UIKit.UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.8)  // Dark panel background
            label.textAlignment = UIKit.NSTextAlignment.center
            label.layer.cornerRadius = 4
            label.layer.masksToBounds = true
            // Add subtle shadow
            label.layer.shadowColor = UIKit.UIColor.black.cgColor
            label.layer.shadowOffset = CGSize(width: 1, height: 1)
            label.layer.shadowRadius = 2
            label.layer.shadowOpacity = 0.6
            progressLabel = label
        }

        // Add labels to view using callback
        var allLabels: [UIKit.UILabel] = []
        if let infoLabel = researchInfoLabel {
            allLabels.append(infoLabel)
        }
        if let progLabel = progressLabel {
            allLabels.append(progLabel)
        }
        onAddLabels?(allLabels)

        // Add scroll view and research button through callback
        var allViews: [UIKit.UIView] = []
        if let scrollView = self.scrollView {
            allViews.append(scrollView)
        }
        if let researchButton = self.researchButton {
            allViews.append(researchButton)
        }
        onAddViews?(allViews)

        scrollView.isHidden = !isOpen
        updateLabels()
    }

    @objc private func techButtonTapped(_ button: UIKit.UIButton) {
        guard let techId = button.accessibilityIdentifier,
              let registry = gameLoop?.technologyRegistry,
              let tech = registry.get(techId) else { return }

        AudioManager.shared.playClickSound()
        selectTechnology(tech)
    }

    @objc private func researchButtonTapped() {
        guard let tech = selectedTech else { return }

        AudioManager.shared.playClickSound()
        startResearch(tech)
    }


    private func updateTechButtonAppearance(_ button: UIKit.UIButton, for tech: Technology) {
        guard let researchSystem = gameLoop?.researchSystem else { return }

        let isCompleted = researchSystem.completedTechnologies.contains(tech.id)
        let isResearching = researchSystem.currentResearch?.id == tech.id
        let isAvailable = researchSystem.canResearch(tech) && !isResearching
        let isSelected = selectedTech?.id == tech.id

        // Set background color based on state
        if isSelected {
            button.backgroundColor = UIKit.UIColor(red: 0.8, green: 0.6, blue: 0.1, alpha: 0.9) // Bright orange for selected
            button.layer.borderWidth = 3
            button.layer.borderColor = UIKit.UIColor.white.cgColor
        } else if isCompleted {
            button.backgroundColor = UIKit.UIColor(red: 0.2, green: 0.4, blue: 0.2, alpha: 0.8) // Green for completed
            button.layer.borderWidth = 1
            button.layer.borderColor = UIKit.UIColor(white: 0.4, alpha: 1).cgColor
        } else if isResearching {
            button.backgroundColor = UIKit.UIColor(red: 0.45, green: 0.45, blue: 0.15, alpha: 0.9) // Yellow/gold for researching
            button.layer.borderWidth = 1
            button.layer.borderColor = UIKit.UIColor(white: 0.4, alpha: 1).cgColor
        } else if isAvailable {
            button.backgroundColor = UIKit.UIColor(red: 0.25, green: 0.25, blue: 0.3, alpha: 0.7) // Light blue for available
            button.layer.borderWidth = 1
            button.layer.borderColor = UIKit.UIColor(white: 0.4, alpha: 1).cgColor
        } else {
            button.backgroundColor = UIKit.UIColor(red: 0.2, green: 0.15, blue: 0.15, alpha: 0.5) // Dark red for unavailable
            button.layer.borderWidth = 1
            button.layer.borderColor = UIKit.UIColor(white: 0.4, alpha: 1).cgColor
        }

        // Set text color
        if isCompleted {
            button.setTitleColor(UIKit.UIColor(red: 0.6, green: 0.9, blue: 0.6, alpha: 1.0), for: UIKit.UIControl.State.normal) // Green tint
        } else if isResearching {
            button.setTitleColor(UIKit.UIColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 1.0), for: UIKit.UIControl.State.normal) // Yellow/gold
        } else if isAvailable {
            button.setTitleColor(UIKit.UIColor(red: 0.7, green: 0.8, blue: 1.0, alpha: 1.0), for: UIKit.UIControl.State.normal) // Light blue
        } else {
            button.setTitleColor(UIKit.UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0), for: UIKit.UIControl.State.normal) // Gray
        }

        // Set button title with tech name
        button.setTitle(tech.name, for: UIKit.UIControl.State.normal)
    }

    private func removeLabels() {
        // Use callbacks to remove views from view
        var allViews: [UIKit.UIView] = []
        if let scrollView = self.scrollView {
            allViews.append(scrollView)
        }
        if let researchButton = self.researchButton {
            allViews.append(researchButton)
        }
        onRemoveViews?(allViews)

        // Clear references
        scrollView = nil
        techButtonViews.removeAll()
        researchButton = nil

        // Use callbacks to remove labels from view
        var allLabels: [UIKit.UILabel] = []
        if let infoLabel = researchInfoLabel {
            allLabels.append(infoLabel)
        }
        if let progLabel = progressLabel {
            allLabels.append(progLabel)
        }
        onRemoveLabels?(allLabels)

        researchInfoLabel = nil
        progressLabel = nil
    }

    private func updateLabels() {
        let screenScale = CGFloat(UIScreen.main.scale)

        // Update tech button appearances
        guard let registry = gameLoop?.technologyRegistry else { return }

        for button: UIKit.UIButton in techButtonViews {
            guard let techId = button.accessibilityIdentifier,
                  let tech = registry.get(techId) else { continue }

            updateTechButtonAppearance(button, for: tech)
        }

        // Update research info label
        if let researchSystem = gameLoop?.researchSystem,
           let currentResearch = researchSystem.currentResearch {
            researchInfoLabel?.text = "Researching: \(currentResearch.name)"
            researchInfoLabel?.isHidden = !isOpen

            if isOpen {
                // Position the info label on the right side with padding
                let infoBarY = frame.maxY - 85 * UIScale
                let labelHeight = researchInfoLabel?.font.lineHeight ?? 20
                let padding: CGFloat = 8
                let labelWidth: CGFloat = 300
                let rightMargin: CGFloat = 20
                let labelY = (CGFloat(infoBarY) / screenScale) - (labelHeight + padding) / 2
                let labelX = (CGFloat(frame.maxX) / screenScale) - labelWidth - rightMargin
                researchInfoLabel?.frame = CGRect(
                    x: labelX, // Right side
                    y: labelY,
                    width: labelWidth,
                    height: labelHeight + padding
                )
            }
        } else {
            researchInfoLabel?.text = "No active research"
            researchInfoLabel?.isHidden = !isOpen

            if isOpen {
                // Position the info label on the right side with padding
                let infoBarY = frame.maxY - 55 * UIScale
                let labelHeight = researchInfoLabel?.font.lineHeight ?? 20
                let padding: CGFloat = 8
                let labelWidth: CGFloat = 300
                let rightMargin: CGFloat = 20
                let labelY = (CGFloat(infoBarY) / screenScale) - (labelHeight + padding) / 2
                let labelX = (CGFloat(frame.maxX) / screenScale) - labelWidth - rightMargin
                researchInfoLabel?.frame = CGRect(
                    x: labelX, // Right side
                    y: labelY,
                    width: labelWidth,
                    height: labelHeight + padding
                )
            }
        }

        // Update progress label
        if let researchSystem = gameLoop?.researchSystem,
           let progressDetails = researchSystem.getResearchProgressDetails() {
            progressLabel?.isHidden = !isOpen

            if isOpen {
                // Create detailed progress text
                var progressText = "\(Int(progressDetails.overallProgress * 100))% complete\n"

                // Add science pack progress
                for (packId, packProgress) in progressDetails.packProgress {
                    let packName = packId.replacingOccurrences(of: "-", with: " ").capitalized
                    progressText += "\(packProgress.contributed)/\(packProgress.required) \(packName)\n"
                }

                // Add research speed bonus if any
                if progressDetails.researchSpeedBonus > 0 {
                    progressText += "Speed: +\(Int(progressDetails.researchSpeedBonus * 100))%"
                }

                progressLabel?.text = progressText.trimmingCharacters(in: .whitespacesAndNewlines)
                progressLabel?.numberOfLines = 0  // Allow multiple lines

                // Position the progress label with padding (wider and taller for detailed info)
                let progressY = frame.maxY - 50 * UIScale
                let lineCount = progressDetails.packProgress.count + 1 + (progressDetails.researchSpeedBonus > 0 ? 1 : 0)
                let labelHeight = (progressLabel?.font.lineHeight ?? 16) * CGFloat(lineCount)
                let padding: CGFloat = 8
                let labelY = (CGFloat(progressY) / screenScale) - (labelHeight + padding) / 2
                progressLabel?.frame = CGRect(
                    x: CGFloat(frame.center.x) - 200, // Center horizontally, wider
                    y: labelY,
                    width: 400, // Wider for detailed text
                    height: labelHeight + padding
                )
            }
        } else {
            progressLabel?.isHidden = true
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

    override func open() {
        super.open()

        // Create UIKit views if they don't exist yet and we have the necessary data
        if scrollView == nil && gameLoop?.technologyRegistry != nil {
            setupLabels()
        }

        // Show scroll view and research button when menu opens
        scrollView?.isHidden = false
        researchButton?.isHidden = false
        // Scroll to top when opening
        scrollView?.setContentOffset(.zero, animated: false)
        // Reset selection state
        selectedTech = nil
        researchButton?.isEnabled = false
        researchButton?.alpha = 0.5
        // Force update to set initial button states
        update(deltaTime: 0)
    }

    override func close() {
        super.close()
        // Hide scroll view and research button when menu closes
        scrollView?.isHidden = true
        researchButton?.isHidden = true
        // Hide labels when menu closes
        researchInfoLabel?.isHidden = true
        progressLabel?.isHidden = true
    }
    
    
    private func selectTechnology(_ tech: Technology) {
        // Just select the technology and show cost info - research button will start it
        selectedTech = tech
        showTechnologyCost(tech)

        // Show tooltip for the selected technology
        var tooltip = "\(tech.name)\n\(tech.description)\n\nCost:"
        for scienceCost in tech.cost {
            tooltip += " \(scienceCost.count) \(scienceCost.packId.replacingOccurrences(of: "-", with: " ").capitalized)"
        }

        if !tech.prerequisites.isEmpty {
            tooltip += "\n\nRequirements:"
            for prereq in tech.prerequisites {
                if let prereqTech = gameLoop?.technologyRegistry.get(prereq) {
                    let status = gameLoop?.researchSystem.completedTechnologies.contains(prereq) ?? false ? "✓" : "✗"
                    tooltip += "\n\(status) \(prereqTech.name)"
                }
            }
        }
        onShowTooltip?(tooltip)

        // Enable research button since we have a selected tech
        researchButton?.isEnabled = true
        researchButton?.alpha = 1.0
    }

    private func showTechnologyCost(_ tech: Technology) {
        var costText = "Cost: "
        for (index, scienceCost) in tech.cost.enumerated() {
            if index > 0 {
                costText += ", "
            }
            costText += "\(scienceCost.count) \(scienceCost.packId.replacingOccurrences(of: "-", with: " ").capitalized)"
        }
        costText += "\nTap Research button to start"

        // Update the research info label to show cost
        researchInfoLabel?.text = costText
        researchInfoLabel?.numberOfLines = 0  // Allow multiple lines
        researchInfoLabel?.isHidden = !isOpen

        if isOpen {
            // Position the info label on the right side with padding (wider for cost text)
            let screenScale = CGFloat(UIScreen.main.scale)
            let infoBarY = frame.maxY - 85 * UIScale
            let labelHeight = (researchInfoLabel?.font.lineHeight ?? 20) * 2  // Double height for 2 lines
            let padding: CGFloat = 8
            let labelWidth: CGFloat = 350  // Wider for cost text
            let rightMargin: CGFloat = 20
            let labelY = (CGFloat(infoBarY) / screenScale) - (labelHeight + padding) / 2
            let labelX = (CGFloat(frame.maxX) / screenScale) - labelWidth - rightMargin
            researchInfoLabel?.frame = CGRect(
                x: labelX,
                y: labelY,
                width: labelWidth,
                height: labelHeight + padding
            )
        }
    }

    private func startResearch(_ tech: Technology) {
        // Try to start research
        if let researchSystem = findResearchSystem() {
            print("ResearchUI: Checking if tech '\(tech.name)' can be researched...")
            let canResearch = researchSystem.canResearch(tech)
            print("ResearchUI: canResearch = \(canResearch)")

            if !canResearch {
                print("ResearchUI: Tech cannot be researched. Checking prerequisites...")
                for prereq in tech.prerequisites {
                    let completed = researchSystem.completedTechnologies.contains(prereq)
                    print("ResearchUI: Prerequisite '\(prereq)' completed: \(completed)")
                }
                let alreadyCompleted = researchSystem.completedTechnologies.contains(tech.id)
                print("ResearchUI: Tech already completed: \(alreadyCompleted)")
            }

            let success = researchSystem.selectResearch(tech.id)
            print("ResearchUI: Attempted to start research '\(tech.name)' (id: \(tech.id)), success: \(success)")

            if success {
                AudioManager.shared.playClickSound()
                selectedTech = nil  // Clear selection
                // Disable research button since no tech is selected
                researchButton?.isEnabled = false
                researchButton?.alpha = 0.5
                // Immediately update button states to reflect the change
                update(deltaTime: 0)
            } else {
                print("ResearchUI: Failed to start research - tech may not be available or already completed")
                // Show error message
                researchInfoLabel?.text = "Cannot start research - check prerequisites"
                researchInfoLabel?.isHidden = !isOpen
            }
        } else {
            print("ResearchUI: No research system available")
            researchInfoLabel?.text = "Research system unavailable"
            researchInfoLabel?.isHidden = !isOpen
        }
    }
    
    private func findResearchSystem() -> ResearchSystem? {
        return gameLoop?.researchSystem
    }
    
    override func update(deltaTime: Float) {
        guard isOpen else { return }

        // Update UIKit button appearances and labels
        updateLabels()
    }
    
    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Render close button
        closeButton.render(renderer: renderer)

        // Tech buttons are now UIKit buttons in the scroll view
        // Research info and progress are rendered as text labels
    }
    
    
    private func renderConnections(renderer: MetalRenderer) {
        // Would render lines between prerequisite techs
    }
    
    override func handleTap(at position: Vector2) -> Bool {
        guard isOpen else { return false }

        // Check close button first
        if closeButton.handleTap(at: position) {
            return true
        }

        // Tech button taps are handled by UIKit gesture recognizers
        // Consume tap within panel bounds to prevent it from going to game world
        return super.handleTap(at: position)
    }

    func getTooltip(at position: Vector2) -> String? {
        // For iOS touch interface, tooltips are shown on selection rather than tap
        // So we don't show tooltips on tap/hover
        return nil
    }
}

