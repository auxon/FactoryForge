import Foundation
import UIKit

/// Research/Technology tree UI
final class ResearchUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var closeButtonView: UIKit.UIButton?
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

    private var rootView: UIView?

    // Root view callbacks
    var onAddRootView: ((UIView) -> Void)?
    var onRemoveRootView: ((UIView) -> Void)?
    
    init(screenSize: Vector2, gameLoop: GameLoop?) {
        // Use full screen size for background
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(screenSize.x, screenSize.y)
        )
        
        super.init(frame: panelFrame)
        self.gameLoop = gameLoop
    }

    /// Convert Metal frame to UIKit points for panel container
    private func panelFrameInPoints() -> CGRect {
        let screenScale = UIScreen.main.scale
        return CGRect(
            x: CGFloat(frame.minX) / screenScale,
            y: CGFloat(frame.minY) / screenScale,
            width: CGFloat(frame.size.x) / screenScale,
            height: CGFloat(frame.size.y) / screenScale
        )
    }

    private func addSciencePackIcons(to button: UIKit.UIButton, for tech: Technology) {
        // Clear any existing icons
        for subview in button.subviews where subview.tag == 999 {
            subview.removeFromSuperview()
        }

        let iconSize: CGFloat = 20
        let iconSpacing: CGFloat = 4
        let countLabelHeight: CGFloat = 12
        let totalIconHeight = iconSize + countLabelHeight + 2 // icon + label + spacing

        var currentX = button.bounds.width - 10 // Start from right edge with margin

        for scienceCost in tech.cost.reversed() { // Reverse to show from right to left
            // Create icon image view
            let iconView = UIKit.UIImageView()
            iconView.tag = 999 // Tag for easy removal
            iconView.contentMode = .scaleAspectFit

            // Map pack ID to image name
            let imageName = scienceCost.packId.replacingOccurrences(of: "-science-pack", with: "_science_pack")
            if let image = UIKit.UIImage(named: imageName) {
                iconView.image = image
            }

            // Position icon
            let iconY = (button.bounds.height - totalIconHeight) / 2
            iconView.frame = CGRect(x: currentX - iconSize, y: iconY, width: iconSize, height: iconSize)
            button.addSubview(iconView)

            // Create count label
            let countLabel = UIKit.UILabel()
            countLabel.tag = 999
            countLabel.text = "\(scienceCost.count)"
            countLabel.font = UIKit.UIFont.systemFont(ofSize: 10, weight: .bold)
            countLabel.textColor = UIKit.UIColor.white
            countLabel.textAlignment = .center
            countLabel.backgroundColor = UIKit.UIColor.black.withAlphaComponent(0.7)
            countLabel.layer.cornerRadius = 3
            countLabel.layer.masksToBounds = true

            // Position count label below icon
            let labelY = iconY + iconSize + 2
            countLabel.frame = CGRect(x: currentX - iconSize, y: labelY, width: iconSize, height: countLabelHeight)
            button.addSubview(countLabel)

            currentX -= (iconSize + iconSpacing)
        }
    }

    private func setupScrollView(in parentView: UIKit.UIView) {
        // Remove existing scroll view if any
        scrollView?.removeFromSuperview()

        let screenScale = CGFloat(UIScreen.main.scale)

        // Scroll view covers most of the screen, leaving space for close button and margins
        let scrollViewFrame = CGRect(
            x: 20 / screenScale, // Small margin
            y: 4 / screenScale, // Leave space at top for close button
            width: (CGFloat(frame.width) - 40) / screenScale, // Leave margins
            height: (CGFloat(frame.height) + 38) / screenScale // Leave space at top and bottom, plus one button height
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

    private func setupCloseButtonViewIfNeeded() {
        guard let rootView = rootView else { return }
        if closeButtonView != nil { return }

        let button = UIKit.UIButton(type: .system)
        button.setTitle("X", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        button.layer.cornerRadius = 4
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        rootView.addSubview(button)
        closeButtonView = button
    }

    @objc private func closeButtonTapped() {
        close()
        gameLoop?.uiSystem?.closeAllPanels()
    }

    private func layoutCloseButton() {
        guard let rootView = rootView else { return }
        let bounds = rootView.bounds
        let closeSize: CGFloat = 36
        let closeMargin: CGFloat = 10
        closeButtonView?.frame = CGRect(
            x: bounds.width - closeMargin - closeSize,
            y: closeMargin,
            width: closeSize,
            height: closeSize
        )
        if let closeButtonView = closeButtonView {
            rootView.bringSubviewToFront(closeButtonView)
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
        guard let rootView = rootView else { return }
        // Create scroll view for technologies (similar to HelpMenu)
        let bounds = rootView.bounds
        let scrollViewHeight: CGFloat = 200 // Smaller height to fit on screen
        let researchButtonHeight: CGFloat = 40
        let researchButtonSpacing: CGFloat = 10
        let startY: CGFloat = 60 // Fixed position below close button area
        let scrollViewFrame = CGRect(
            x: bounds.width * 0.1, // 10% margin on sides
            y: startY,
            width: bounds.width * 0.8, // 80% width
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
            // Leave space on the right for science pack icons (up to 3 icons * ~24px each)
            let iconSpace: CGFloat = 80
            let buttonFrame = CGRect(x: 100, y: buttonY, width: scrollViewFrame.width - 200 - iconSpace, height: buttonHeight)

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

            // Add science pack icons
            addSciencePackIcons(to: button, for: tech)

            // Add tap gesture
            button.addTarget(self, action: #selector(techButtonTapped(_:)), for: UIKit.UIControl.Event.touchUpInside)

            // Store technology for identification
            button.accessibilityIdentifier = tech.id

            scrollView.addSubview(button)
            techButtonViews.append(button)
        }
        rootView.addSubview(scrollView)


        // Create research button below the scroll view (normal sized, centered)
        let researchButtonWidth: CGFloat = 200
        let researchButtonFrame = CGRect(
            x: (bounds.width - researchButtonWidth) / 2, // Center horizontally
            y: scrollViewFrame.maxY + researchButtonSpacing, // Below scroll view
            width: researchButtonWidth,
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
        rootView.addSubview(researchBtn)

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
        if let infoLabel = researchInfoLabel {
            rootView.addSubview(infoLabel)
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
        if let progLabel = progressLabel {
            rootView.addSubview(progLabel)
        }

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
        guard let researchSystem = gameLoop?.researchSystem else {
            button.setTitle(tech.name, for: UIKit.UIControl.State.normal)
            button.setTitleColor(UIKit.UIColor.white, for: UIKit.UIControl.State.normal)
            return
        }

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

        // Update science pack icons
        addSciencePackIcons(to: button, for: tech)
    }

    private func removeLabels() {
        scrollView?.removeFromSuperview()
        scrollView = nil
        techButtonViews.removeAll()
        researchButton?.removeFromSuperview()
        researchButton = nil

        researchInfoLabel?.removeFromSuperview()
        researchInfoLabel = nil
        progressLabel?.removeFromSuperview()
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

        // Update research button state based on selected technology
        if let selectedTech = selectedTech {
            let canResearch = gameLoop?.researchSystem.canResearch(selectedTech) ?? false
            researchButton?.isEnabled = canResearch
            researchButton?.alpha = canResearch ? 1.0 : 0.3
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

                // Position the progress label on the left side, above the bottom
                let progressY = frame.maxY - 100 * UIScale  // Higher up to avoid research button
                let lineCount = progressDetails.packProgress.count + 1 + (progressDetails.researchSpeedBonus > 0 ? 1 : 0)
                let labelHeight = (progressLabel?.font.lineHeight ?? 16) * CGFloat(lineCount)
                let padding: CGFloat = 8
                let labelWidth: CGFloat = 300
                let leftMargin: CGFloat = 20
                let labelY = (CGFloat(progressY) / screenScale) - (labelHeight + padding) / 2
                let labelX = leftMargin  // Left side of screen
                progressLabel?.frame = CGRect(
                    x: labelX,
                    y: labelY,
                    width: labelWidth,
                    height: labelHeight + padding
                )
            }
        } else {
            progressLabel?.isHidden = true
        }
    }

    override func open() {
        super.open()

        if rootView == nil {
            rootView = UIView(frame: panelFrameInPoints())
            rootView?.backgroundColor = .clear
            rootView?.isUserInteractionEnabled = true
        }

        setupCloseButtonViewIfNeeded()

        // Create UIKit views if they don't exist yet and we have the necessary data
        if (scrollView == nil || techButtonViews.isEmpty) && gameLoop?.technologyRegistry != nil {
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

        if let rootView = rootView {
            onAddRootView?(rootView)
            layoutCloseButton()
        }
    }

    override func close() {
        super.close()
        // Hide scroll view and research button when menu closes
        scrollView?.isHidden = true
        researchButton?.isHidden = true
        // Hide labels when menu closes
        researchInfoLabel?.isHidden = true
        progressLabel?.isHidden = true

        closeButtonView?.removeFromSuperview()
        closeButtonView = nil

        removeLabels()

        if let rv = rootView {
            rv.isUserInteractionEnabled = false
            rv.removeFromSuperview()
            onRemoveRootView?(rv)
        }
        rootView = nil
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

        // Check if the technology can actually be researched (has all requirements)
        let canResearch = gameLoop?.researchSystem.canResearch(tech) ?? false

        if canResearch {
            // Enable research button since we have a selected tech that can be researched
            researchButton?.isEnabled = true
            researchButton?.alpha = 1.0
        } else {
            // Disable research button since requirements are not met
            researchButton?.isEnabled = false
            researchButton?.alpha = 0.3 // More disabled-looking than 0.5
        }
    }

    private func showTechnologyCost(_ tech: Technology) {
        var costText = "Cost: "
        for (index, scienceCost) in tech.cost.enumerated() {
            if index > 0 {
                costText += ", "
            }
            costText += "\(scienceCost.count) \(scienceCost.packId.replacingOccurrences(of: "-", with: " ").capitalized)"
        }

        // Check if technology can be researched
        let canResearch = gameLoop?.researchSystem.canResearch(tech) ?? false

        if canResearch {
            costText += "\nTap Research button to start"
        } else {
            costText += "\nRequirements not met"
        }

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
    }
    
    
    private func renderConnections(renderer: MetalRenderer) {
        // Would render lines between prerequisite techs
    }
    
    override func handleTap(at position: Vector2) -> Bool {
        guard isOpen else { return false }

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
