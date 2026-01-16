import Foundation
import UIKit

/// Research/Technology tree UI
final class ResearchUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var closeButtonView: UIKit.UIButton?
    private var selectedTech: Technology?

    // UIKit scrolling components (like HelpMenu)
    private var scrollView: UIKit.UIScrollView?
    private var techPanelBackground: UIView?
    private var techHeaderLabel: UILabel?
    private var selectedPanelBackground: UIView?
    private var techButtonViews: [UIKit.UIButton] = [] // UIKit buttons for scrolling
    private var researchButton: UIKit.UIButton? // Button to start research

    // Text labels
    private var selectedTitleLabel: UIKit.UILabel?
    private var selectedDescLabel: UIKit.UILabel?
    private var selectedCostLabel: UIKit.UILabel?
    private var progressLabel: UIKit.UILabel?
    private var labStatusLabel: UIKit.UILabel?
    private var nextStepLabel: UIKit.UILabel?
    private var progressBarBackground: UIView?
    private var progressBarFill: UIView?

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
        let iconSpacing: CGFloat = 8
        let countLabelHeight: CGFloat = 14
        let totalIconHeight = iconSize + countLabelHeight + 2 // icon + label + spacing

        var currentX = button.bounds.width - 12 // Start from right edge with margin

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
            countLabel.sizeToFit()

            let iconY = (button.bounds.height - totalIconHeight) / 2

            // Position count label below icon
            let labelWidth = max(iconSize, countLabel.bounds.width + 6)
            let labelY = iconY + iconSize + 2
            countLabel.frame = CGRect(x: currentX - labelWidth, y: labelY, width: labelWidth, height: countLabelHeight)
            button.addSubview(countLabel)

            // Position icon centered above label
            iconView.frame = CGRect(
                x: currentX - labelWidth + (labelWidth - iconSize) * 0.5,
                y: iconY,
                width: iconSize,
                height: iconSize
            )
            button.addSubview(iconView)

            currentX -= (labelWidth + iconSpacing)
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

    private func setupPanelViewsIfNeeded() {
        guard let rootView = rootView else { return }

        if selectedPanelBackground == nil {
            let background = UIView()
            background.backgroundColor = UIColor(white: 0.12, alpha: 0.6)
            background.layer.cornerRadius = 10
            rootView.addSubview(background)
            selectedPanelBackground = background
        }

        if techPanelBackground == nil {
            let background = UIView()
            background.backgroundColor = UIColor(white: 0.12, alpha: 0.6)
            background.layer.cornerRadius = 10
            rootView.addSubview(background)
            techPanelBackground = background
        }

        if techHeaderLabel == nil {
            let label = UILabel()
            label.text = "Technologies"
            label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            label.textColor = UIColor(white: 0.85, alpha: 1.0)
            label.textAlignment = .center
            rootView.addSubview(label)
            techHeaderLabel = label
        }

        if selectedTitleLabel == nil {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            label.textColor = UIColor.white
            label.textAlignment = .center
            rootView.addSubview(label)
            selectedTitleLabel = label
        }

        if selectedDescLabel == nil {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
            label.textColor = UIColor(white: 0.85, alpha: 1.0)
            label.numberOfLines = 2
            label.textAlignment = .center
            rootView.addSubview(label)
            selectedDescLabel = label
        }

        if selectedCostLabel == nil {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            label.textColor = UIColor(white: 0.9, alpha: 1.0)
            label.textAlignment = .center
            label.numberOfLines = 2
            label.lineBreakMode = .byWordWrapping
            rootView.addSubview(label)
            selectedCostLabel = label
        }

        if progressLabel == nil {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            label.textColor = UIColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 1.0)
            label.numberOfLines = 2
            label.textAlignment = .center
            label.lineBreakMode = .byWordWrapping
            rootView.addSubview(label)
            progressLabel = label
        }

        if labStatusLabel == nil {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
            label.textColor = UIColor(white: 0.9, alpha: 1.0)
            label.textAlignment = .center
            label.numberOfLines = 2
            label.backgroundColor = UIColor(white: 0.12, alpha: 0.6)
            label.layer.cornerRadius = 6
            label.layer.masksToBounds = true
            rootView.addSubview(label)
            labStatusLabel = label
        }

        if nextStepLabel == nil {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 11, weight: .medium)
            label.textColor = UIColor(white: 0.9, alpha: 1.0)
            label.textAlignment = .center
            rootView.addSubview(label)
            nextStepLabel = label
        }

        if progressBarBackground == nil {
            let background = UIView()
            background.backgroundColor = UIColor.gray
            background.layer.cornerRadius = 4
            rootView.addSubview(background)
            progressBarBackground = background
        }

        if progressBarFill == nil {
            let fill = UIView()
            fill.backgroundColor = UIColor.blue
            fill.layer.cornerRadius = 4
            rootView.addSubview(fill)
            progressBarFill = fill
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

    private func layoutUI() {
        guard let rootView = rootView else { return }

        let bounds = rootView.bounds
        let padding: CGFloat = 12
        let columnGap: CGFloat = 12
        let minRightWidth: CGFloat = 220
        var leftWidth = min(bounds.width * 0.62, bounds.width - padding * 2 - columnGap - minRightWidth)
        leftWidth = max(240, leftWidth)
        let rightWidth = bounds.width - padding * 2 - columnGap - leftWidth
        let leftX = padding
        let rightX = leftX + leftWidth + columnGap
        let leftY = padding
        let leftHeight = bounds.height - padding * 2

        let selectedPanelHeight: CGFloat = 112
        let selectedPanelY = leftY
        selectedPanelBackground?.frame = CGRect(x: rightX - 6, y: selectedPanelY - 6, width: rightWidth + 12, height: selectedPanelHeight + 12)
        selectedTitleLabel?.frame = CGRect(x: rightX, y: selectedPanelY, width: rightWidth, height: 24)
        selectedDescLabel?.frame = CGRect(x: rightX, y: selectedPanelY + 22, width: rightWidth, height: 36)
        selectedCostLabel?.frame = CGRect(x: rightX, y: selectedPanelY + 60, width: rightWidth, height: 44)

        let statusY = selectedPanelY + selectedPanelHeight + 10
        let barWidth = rightWidth
        let barHeight: CGFloat = 16
        let barX = rightX
        let barY = statusY
        progressBarBackground?.frame = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)
        progressBarFill?.frame = CGRect(x: barX, y: barY, width: progressBarFill?.frame.width ?? 0, height: barHeight)
        progressLabel?.frame = CGRect(x: barX, y: barY + barHeight + 4, width: barWidth, height: 48)
        labStatusLabel?.frame = CGRect(x: barX, y: barY + barHeight + 56, width: barWidth, height: 28)
        nextStepLabel?.frame = CGRect(x: barX, y: barY + barHeight + 88, width: barWidth, height: 16)

        let headerHeight: CGFloat = 18
        techHeaderLabel?.frame = CGRect(x: leftX, y: leftY, width: leftWidth, height: headerHeight)

        let scrollY = leftY + headerHeight + 6
        let scrollHeight = leftHeight - headerHeight - 6
        techPanelBackground?.frame = CGRect(x: leftX - 6, y: scrollY - 6, width: leftWidth + 12, height: scrollHeight + 12)
        scrollView?.frame = CGRect(x: leftX, y: scrollY, width: leftWidth, height: scrollHeight)

        let researchButtonHeight: CGFloat = 40
        let researchButtonY = leftY + leftHeight - researchButtonHeight
        researchButton?.frame = CGRect(
            x: rightX,
            y: researchButtonY,
            width: rightWidth,
            height: researchButtonHeight
        )

        let closeSize: CGFloat = 36
        let closeMargin: CGFloat = 10
        closeButtonView?.frame = CGRect(
            x: bounds.width - closeMargin - closeSize,
            y: closeMargin,
            width: closeSize,
            height: closeSize
        )

        rootView.bringSubviewToFront(selectedPanelBackground ?? UIView())
        rootView.bringSubviewToFront(selectedTitleLabel ?? UIView())
        rootView.bringSubviewToFront(selectedDescLabel ?? UIView())
        rootView.bringSubviewToFront(selectedCostLabel ?? UIView())
        rootView.bringSubviewToFront(progressBarBackground ?? UIView())
        rootView.bringSubviewToFront(progressBarFill ?? UIView())
        rootView.bringSubviewToFront(progressLabel ?? UIView())
        rootView.bringSubviewToFront(labStatusLabel ?? UIView())
        rootView.bringSubviewToFront(nextStepLabel ?? UIView())
        rootView.bringSubviewToFront(closeButtonView ?? UIView())
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
        let padding: CGFloat = 12
        let columnGap: CGFloat = 12
        let minRightWidth: CGFloat = 220
        var leftWidth = min(bounds.width * 0.62, bounds.width - padding * 2 - columnGap - minRightWidth)
        leftWidth = max(240, leftWidth)
        let leftX = padding
        let leftY = padding
        let leftHeight = bounds.height - padding * 2
        let headerHeight: CGFloat = 20
        let scrollViewHeight = leftHeight - headerHeight - 6
        let scrollViewFrame = CGRect(
            x: leftX,
            y: leftY + headerHeight + 6,
            width: leftWidth,
            height: scrollViewHeight
        )

        let scrollView = UIKit.UIScrollView(frame: scrollViewFrame)
        print("ResearchUI: Created scrollView with frame \(scrollViewFrame)")
        scrollView.backgroundColor = UIKit.UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 0.6)
        scrollView.layer.borderColor = UIKit.UIColor.gray.cgColor
        scrollView.layer.borderWidth = 1.0
        scrollView.layer.cornerRadius = 8.0
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.isScrollEnabled = true
        scrollView.isUserInteractionEnabled = true

        self.scrollView = scrollView

        // Get all technologies sorted by tier and order
        let allTechs = registry.all.sorted { lhs, rhs in
            if lhs.tier != rhs.tier {
                return lhs.tier < rhs.tier
            }
            if lhs.order != rhs.order {
                return lhs.order < rhs.order
            }
            return lhs.name < rhs.name
        }

        // Calculate content size and create buttons
        let buttonHeight: CGFloat = 48
        let buttonSpacing: CGFloat = 8
        let contentWidth = scrollViewFrame.width

        var contentY: CGFloat = 0
        var currentTier: Int?

        for tech in allTechs {
            if currentTier != tech.tier {
                currentTier = tech.tier
                let headerLabel = UILabel()
                headerLabel.text = "Tier \(tech.tier)"
                headerLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
                headerLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
                headerLabel.textAlignment = .left
                headerLabel.frame = CGRect(x: 12, y: contentY, width: contentWidth - 24, height: headerHeight)
                scrollView.addSubview(headerLabel)
                contentY += headerHeight + 6
            }

            // Leave space on the right for science pack icons (up to 3 icons * ~24px each)
            let iconSpace: CGFloat = 120
            let buttonWidth = contentWidth - 24
            let buttonFrame = CGRect(x: 12, y: contentY, width: buttonWidth, height: buttonHeight)

            let button: UIKit.UIButton = UIKit.UIButton(type: UIKit.UIButton.ButtonType.custom)
            button.frame = buttonFrame
            var config = UIKit.UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: iconSpace)
            config.titleAlignment = .leading
            config.titleLineBreakMode = .byWordWrapping
            button.configuration = config

            // Set initial appearance
            updateTechButtonAppearance(button, for: tech)

            button.layer.borderWidth = 1
            button.layer.borderColor = UIKit.UIColor(white: 0.4, alpha: 1).cgColor
            button.layer.cornerRadius = 4
            button.titleLabel?.font = UIKit.UIFont.systemFont(ofSize: 14, weight: UIKit.UIFont.Weight.medium)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = UIKit.NSTextAlignment.left

            // Add science pack icons
            addSciencePackIcons(to: button, for: tech)

            // Add tap gesture
            button.addTarget(self, action: #selector(techButtonTapped(_:)), for: UIKit.UIControl.Event.touchUpInside)

            // Store technology for identification
            button.accessibilityIdentifier = tech.id

            scrollView.addSubview(button)
            techButtonViews.append(button)
            contentY += buttonHeight + buttonSpacing
        }
        let contentHeight = max(contentY - buttonSpacing, scrollViewHeight)
        scrollView.contentSize = CGSize(width: scrollViewFrame.width, height: contentHeight)
        rootView.addSubview(scrollView)


        // Create research button; layoutUI will finalize its position
        let researchButtonFrame = CGRect(x: 0, y: 0, width: 200, height: 40)

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
            var config = button.configuration ?? UIKit.UIButton.Configuration.plain()
            config.title = tech.name
            config.baseForegroundColor = UIKit.UIColor.white
            button.configuration = config
            return
        }

        let isCompleted = researchSystem.completedTechnologies.contains(tech.id)
        let isResearching = researchSystem.currentResearch?.id == tech.id
        let isAvailable = researchSystem.canResearch(tech) && !isResearching
        let isSelected = selectedTech?.id == tech.id

        var config = button.configuration ?? UIKit.UIButton.Configuration.plain()

        // Set background color based on state
        if isSelected {
            config.background.backgroundColor = UIKit.UIColor(red: 0.8, green: 0.6, blue: 0.1, alpha: 0.9) // Bright orange for selected
            config.background.strokeWidth = 3
            config.background.strokeColor = UIKit.UIColor.white
        } else if isCompleted {
            config.background.backgroundColor = UIKit.UIColor(red: 0.2, green: 0.4, blue: 0.2, alpha: 0.8) // Green for completed
            config.background.strokeWidth = 1
            config.background.strokeColor = UIKit.UIColor(white: 0.4, alpha: 1)
        } else if isResearching {
            config.background.backgroundColor = UIKit.UIColor(red: 0.45, green: 0.45, blue: 0.15, alpha: 0.9) // Yellow/gold for researching
            config.background.strokeWidth = 1
            config.background.strokeColor = UIKit.UIColor(white: 0.4, alpha: 1)
        } else if isAvailable {
            config.background.backgroundColor = UIKit.UIColor(red: 0.25, green: 0.25, blue: 0.3, alpha: 0.7) // Light blue for available
            config.background.strokeWidth = 1
            config.background.strokeColor = UIKit.UIColor(white: 0.4, alpha: 1)
        } else {
            config.background.backgroundColor = UIKit.UIColor(red: 0.2, green: 0.15, blue: 0.15, alpha: 0.5) // Dark red for unavailable
            config.background.strokeWidth = 1
            config.background.strokeColor = UIKit.UIColor(white: 0.4, alpha: 1)
        }

        // Set text color
        if isCompleted {
            config.baseForegroundColor = UIKit.UIColor(red: 0.6, green: 0.9, blue: 0.6, alpha: 1.0)
        } else if isResearching {
            config.baseForegroundColor = UIKit.UIColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 1.0)
        } else if isAvailable {
            config.baseForegroundColor = UIKit.UIColor(red: 0.7, green: 0.8, blue: 1.0, alpha: 1.0)
        } else {
            config.baseForegroundColor = UIKit.UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        }

        // Set button title with tech name
        config.title = tech.name
        config.background.cornerRadius = 4.0
        button.configuration = config

        // Update science pack icons
        addSciencePackIcons(to: button, for: tech)
    }

    private func removeLabels() {
        scrollView?.removeFromSuperview()
        scrollView = nil
        techButtonViews.removeAll()
        researchButton?.removeFromSuperview()
        researchButton = nil

        // Panel views are cleared on close to avoid rebuilding them every list refresh.
    }

    private func updateLabels() {
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
            updateSelectedTechPanel(selectedTech)
            researchButton?.setTitle("Research", for: .normal)
        } else {
            updateSelectedTechPanelForEmpty()
            researchButton?.isEnabled = false
            researchButton?.alpha = 0.5
            researchButton?.setTitle("Select a technology", for: .normal)
        }

        updateProgressUI()
    }

    override func open() {
        super.open()

        if rootView == nil {
            rootView = UIView(frame: panelFrameInPoints())
            rootView?.backgroundColor = .clear
            rootView?.isUserInteractionEnabled = true
        }

        setupPanelViewsIfNeeded()
        setupCloseButtonViewIfNeeded()
        layoutUI()

        // Create UIKit views if they don't exist yet and we have the necessary data
        if (scrollView == nil || techButtonViews.isEmpty) && gameLoop?.technologyRegistry != nil {
            setupLabels()
            layoutUI()
        }

        // Show scroll view and research button when menu opens
        scrollView?.isHidden = false
        researchButton?.isHidden = false
        selectedTitleLabel?.isHidden = false
        selectedDescLabel?.isHidden = false
        selectedCostLabel?.isHidden = false
        progressLabel?.isHidden = false
        labStatusLabel?.isHidden = false
        nextStepLabel?.isHidden = false
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
            layoutUI()
        }
    }

    override func close() {
        super.close()
        // Hide scroll view and research button when menu closes
        scrollView?.isHidden = true
        researchButton?.isHidden = true
        selectedTitleLabel?.isHidden = true
        selectedDescLabel?.isHidden = true
        selectedCostLabel?.isHidden = true
        progressLabel?.isHidden = true
        labStatusLabel?.isHidden = true

        closeButtonView?.removeFromSuperview()
        closeButtonView = nil

        removeLabels()

        progressLabel?.removeFromSuperview()
        progressLabel = nil
        labStatusLabel?.removeFromSuperview()
        labStatusLabel = nil
        nextStepLabel?.removeFromSuperview()
        nextStepLabel = nil

        selectedTitleLabel?.removeFromSuperview()
        selectedTitleLabel = nil
        selectedDescLabel?.removeFromSuperview()
        selectedDescLabel = nil
        selectedCostLabel?.removeFromSuperview()
        selectedCostLabel = nil

        techPanelBackground?.removeFromSuperview()
        techPanelBackground = nil
        techHeaderLabel?.removeFromSuperview()
        techHeaderLabel = nil
        selectedPanelBackground?.removeFromSuperview()
        selectedPanelBackground = nil

        progressBarFill?.removeFromSuperview()
        progressBarFill = nil
        progressBarBackground?.removeFromSuperview()
        progressBarBackground = nil

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
        updateSelectedTechPanel(tech)

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
        updateSelectedTechPanel(tech)
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
                selectedCostLabel?.text = "Cannot start research — check prerequisites"
            }
        } else {
            print("ResearchUI: No research system available")
            selectedCostLabel?.text = "Research system unavailable"
        }
    }
    
    private func findResearchSystem() -> ResearchSystem? {
        return gameLoop?.researchSystem
    }

    private func updateSelectedTechPanel(_ tech: Technology) {
        selectedTitleLabel?.text = tech.name
        selectedDescLabel?.text = tech.description.isEmpty ? "Select a technology to see details." : tech.description

        var costText = "Cost: "
        for (index, scienceCost) in tech.cost.enumerated() {
            if index > 0 {
                costText += ", "
            }
            costText += "\(scienceCost.count) \(scienceCost.packId.replacingOccurrences(of: "-", with: " ").capitalized)"
        }

        let canResearch = gameLoop?.researchSystem.canResearch(tech) ?? false
        if !canResearch {
            if !tech.prerequisites.isEmpty {
                let prereqNames = tech.prerequisites.compactMap { id in
                    gameLoop?.technologyRegistry.get(id)?.name ?? id
                }
                costText += "\nRequires: " + prereqNames.joined(separator: ", ")
            } else {
                costText += "\nRequirements not met"
            }
        }
        selectedCostLabel?.text = costText
    }

    private func updateSelectedTechPanelForEmpty() {
        selectedTitleLabel?.text = "Select a technology"
        selectedDescLabel?.text = "Choose a tech to view details. Labs consume science packs (player inventory does not)."
        selectedCostLabel?.text = ""
    }

    private func updateLabStatusLabel() {
        guard let world = gameLoop?.world else {
            labStatusLabel?.text = "Labs: unavailable"
            labStatusLabel?.isHidden = false
            nextStepLabel?.text = "Next: Select a technology"
            return
        }

        var totalLabs = 0
        var activeLabs = 0
        var poweredLabs = 0

        world.forEach(LabComponent.self) { entity, lab in
            totalLabs += 1
            if lab.isResearching { activeLabs += 1 }
            if let power = world.get(PowerConsumerComponent.self, for: entity), power.satisfaction > 0 {
                poweredLabs += 1
            }
        }

        if totalLabs == 0 {
            labStatusLabel?.text = "Labs: 0 built — science packs must be in labs"
            labStatusLabel?.isHidden = false
            updateNextStepHint(activeLabs: 0, poweredLabs: 0, totalLabs: 0)
            return
        }

        if let current = gameLoop?.researchSystem.currentResearch {
            if activeLabs == 0 {
                if poweredLabs == 0 {
                    labStatusLabel?.text = "Labs: 0 active — no powered labs for \(current.name)"
                } else {
                    labStatusLabel?.text = "Labs: 0 active — add science packs to labs"
                }
                labStatusLabel?.isHidden = false
                updateNextStepHint(activeLabs: activeLabs, poweredLabs: poweredLabs, totalLabs: totalLabs)
                return
            }
        }

        labStatusLabel?.text = "Labs: \(activeLabs) active / \(poweredLabs) powered / \(totalLabs) total"
        labStatusLabel?.isHidden = false
        updateNextStepHint(activeLabs: activeLabs, poweredLabs: poweredLabs, totalLabs: totalLabs)
    }

    private func updateNextStepHint(activeLabs: Int, poweredLabs: Int, totalLabs: Int) {
        guard let researchSystem = gameLoop?.researchSystem else {
            nextStepLabel?.text = "Next: Start a game to research"
            return
        }

        if totalLabs == 0 {
            nextStepLabel?.text = "Next: Build a lab (Automation)"
            return
        }

        if let current = researchSystem.currentResearch {
            if poweredLabs == 0 {
                nextStepLabel?.text = "Next: Power a lab for \(current.name)"
                return
            }
            if activeLabs == 0 {
                nextStepLabel?.text = "Next: Add science packs to labs"
                return
            }
            nextStepLabel?.text = "Next: Wait or add more labs"
            return
        }

        if let selectedTech = selectedTech {
            let canResearch = researchSystem.canResearch(selectedTech)
            if canResearch {
                nextStepLabel?.text = "Next: Tap Research to start"
            } else if let prereq = selectedTech.prerequisites.first,
                      let prereqTech = gameLoop?.technologyRegistry.get(prereq) {
                nextStepLabel?.text = "Next: Research \(prereqTech.name)"
            } else {
                nextStepLabel?.text = "Next: Complete prerequisites"
            }
            return
        }

        nextStepLabel?.text = "Next: Select a technology"
    }

    private func updateProgressUI() {
        guard let researchSystem = gameLoop?.researchSystem else {
            progressLabel?.text = "No research system"
            progressBarFill?.frame.size.width = 0
            return
        }

        if let progressDetails = researchSystem.getResearchProgressDetails() {
            let percent = Int(progressDetails.overallProgress * 100)
            var progressText = "Researching: \(progressDetails.technologyName) • \(percent)%"
            if progressDetails.researchSpeedBonus > 0 {
                progressText += " • Speed +\(Int(progressDetails.researchSpeedBonus * 100))%"
            }
            var packLines: [String] = []
            for (packId, packProgress) in progressDetails.packProgress {
                let packName = packId.replacingOccurrences(of: "-", with: " ").capitalized
                packLines.append("\(packProgress.contributed)/\(packProgress.required) \(packName)")
            }
            if !packLines.isEmpty {
                progressText += "\n" + packLines.joined(separator: " • ")
            }
            progressLabel?.text = progressText

            if let background = progressBarBackground {
                let width = max(0, min(1, progressDetails.overallProgress)) * Float(background.frame.width)
                progressBarFill?.frame.size.width = CGFloat(width)
            }
        } else {
            if let selectedTech = selectedTech {
                let canResearch = researchSystem.canResearch(selectedTech)
                if canResearch {
                    progressLabel?.text = "No active research — tap Research to start"
                } else {
                    progressLabel?.text = "Locked — complete prerequisites first"
                }
            } else {
                progressLabel?.text = "Select a technology to see progress"
            }
            progressBarFill?.frame.size.width = 0
        }

        updateLabStatusLabel()
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
