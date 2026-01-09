import Foundation
import UIKit

/// Research/Technology tree UI
final class ResearchUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var techButtons: [TechButton] = []
    private var closeButton: CloseButton!
    private var selectedTech: Technology?

    // Text labels
    private var techLabels: [UILabel] = []
    private var researchInfoLabel: UILabel?
    private var progressLabel: UILabel?

    // Label management callbacks
    var onAddLabels: (([UILabel]) -> Void)?
    var onRemoveLabels: (([UILabel]) -> Void)?
    
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

    /// Sets up UILabel overlays for research UI text
    /// Must be called from GameViewController after ResearchUI is created
    func setupLabels() {
        // Remove existing labels
        removeLabels()

            // Create labels for each tech button
        for (index, button) in techButtons.enumerated() {
            if index >= techLabels.count {
                let label = UILabel()
                label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
                label.textColor = .white  // White text for dark theme
                label.numberOfLines = 1
                // Dark background matching panel aesthetic (dark blue-gray)
                label.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 0.85)
                label.textAlignment = .center
                label.lineBreakMode = .byTruncatingMiddle
                // Add subtle shadow for better readability
                label.layer.shadowColor = UIColor.black.cgColor
                label.layer.shadowOffset = CGSize(width: 1, height: 1)
                label.layer.shadowRadius = 2
                label.layer.shadowOpacity = 0.8
                techLabels.append(label)
            }

            let label = techLabels[index]
            // Set text
            label.text = button.technology.name
            // Position will be set in updateLabels
        }

        // Remove excess labels
        while techLabels.count > techButtons.count {
            techLabels.removeLast()
        }

        // Create research info label
        if researchInfoLabel == nil {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            label.textColor = UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0)  // Light blue-white
            label.numberOfLines = 1
            label.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.8)  // Dark panel background
            label.textAlignment = .right  // Right-aligned since label is on right side
            label.layer.cornerRadius = 4
            label.layer.masksToBounds = true
            // Add subtle shadow
            label.layer.shadowColor = UIColor.black.cgColor
            label.layer.shadowOffset = CGSize(width: 1, height: 1)
            label.layer.shadowRadius = 2
            label.layer.shadowOpacity = 0.6
            researchInfoLabel = label
        }

        // Create progress label
        if progressLabel == nil {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            label.textColor = UIColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 1.0)  // Gold/yellow for progress
            label.numberOfLines = 1
            label.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.8)  // Dark panel background
            label.textAlignment = .center
            label.layer.cornerRadius = 4
            label.layer.masksToBounds = true
            // Add subtle shadow
            label.layer.shadowColor = UIColor.black.cgColor
            label.layer.shadowOffset = CGSize(width: 1, height: 1)
            label.layer.shadowRadius = 2
            label.layer.shadowOpacity = 0.6
            progressLabel = label
        }

        // Add labels to view using callback
        var allLabels = techLabels
        if let infoLabel = researchInfoLabel {
            allLabels.append(infoLabel)
        }
        if let progLabel = progressLabel {
            allLabels.append(progLabel)
        }
        onAddLabels?(allLabels)

        updateLabels()
    }

    private func removeLabels() {
        // Use callbacks to remove labels from view
        var allLabels = techLabels
        if let infoLabel = researchInfoLabel {
            allLabels.append(infoLabel)
        }
        if let progLabel = progressLabel {
            allLabels.append(progLabel)
        }
        onRemoveLabels?(allLabels)

        techLabels.removeAll()
        researchInfoLabel = nil
        progressLabel = nil
    }

    private func updateLabels() {
        let screenScale = CGFloat(UIScreen.main.scale)

        // Update tech button labels
        for (index, label) in techLabels.enumerated() {
            guard index < techButtons.count else { break }

            let button = techButtons[index]

            // Set text
            label.text = button.technology.name
            
            // Set text color based on button state to match game aesthetic
            if button.isCompleted {
                // Green tint for completed technologies
                label.textColor = UIColor(red: 0.6, green: 0.9, blue: 0.6, alpha: 1.0)
            } else if button.isResearching {
                // Yellow/gold for currently researching
                label.textColor = UIColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 1.0)
            } else if button.isAvailable {
                // Light blue for available technologies
                label.textColor = UIColor(red: 0.7, green: 0.8, blue: 1.0, alpha: 1.0)
            } else {
                // Gray for unavailable/locked technologies
                label.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
            }

            // Convert button frame from Metal coordinates to UIKit coordinates
            let buttonMinXPixels = CGFloat(button.frame.minX)
            let buttonCenterYPixels = CGFloat(button.frame.center.y)

            // Add padding for better visual appearance
            let padding: CGFloat = 4
            let labelXPoints = buttonMinXPixels / screenScale
            let labelYPoints = (buttonCenterYPixels / screenScale) - (label.font.lineHeight / 2) - padding / 2

            label.frame = CGRect(
                x: labelXPoints,
                y: labelYPoints,
                width: CGFloat(button.frame.width) / screenScale,
                height: label.font.lineHeight + padding
            )
            
            // Add corner radius for rounded background
            label.layer.cornerRadius = 4
            label.layer.masksToBounds = true

            label.isHidden = !isOpen
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
        refreshTechTree()
        setupLabels() // Set up labels when opening
        // Force update to set initial button states
        update(deltaTime: 0)
    }

    override func close() {
        super.close()
        // Hide all labels when menu closes
        for label in techLabels {
            label.isHidden = true
        }
        researchInfoLabel?.isHidden = true
        progressLabel?.isHidden = true
    }
    
    private func refreshTechTree() {
        techButtons.removeAll()
        
        guard let registry = gameLoop?.technologyRegistry else {
            print("ResearchUI: No technology registry available")
            return
        }
        
        let buttonWidth: Float = 120 * UIScale
        let buttonHeight: Float = 40 * UIScale
        let tierSpacing: Float = 150 * UIScale
        let buttonSpacing: Float = 50 * UIScale

        // Calculate total width of all tiers and center them
        let totalTiersWidth = 3 * buttonWidth + 2 * tierSpacing
        let startTierX = frame.center.x - totalTiersWidth / 2 + buttonWidth / 2

        var totalTechs = 0

        // Group by tier
        for tier in 1...3 {
            let techs = registry.technologies(tier: tier)
            totalTechs += techs.count

            if techs.isEmpty {
                continue
            }

            let tierX = startTierX + Float(tier - 1) * (buttonWidth + tierSpacing)
            var currentY = frame.center.y - 150 * UIScale
            
            for tech in techs {
                let button = TechButton(
                    frame: Rect(center: Vector2(tierX, currentY), size: Vector2(buttonWidth, buttonHeight)),
                    technology: tech
                )
                button.onTap = { [weak self] in
                    self?.selectTechnology(tech)
                }
                techButtons.append(button)
                currentY += buttonHeight + buttonSpacing / 2
            }
        }
        
        print("ResearchUI: Loaded \(totalTechs) technologies, created \(techButtons.count) buttons")
    }
    
    private func selectTechnology(_ tech: Technology) {
        // If this technology is already selected, start research
        if selectedTech?.id == tech.id {
            startResearch(tech)
        } else {
            // Show cost information for the selected technology
            selectedTech = tech
            showTechnologyCost(tech)
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
        costText += "\nTap again to start research"

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
        guard isOpen, let researchSystem = gameLoop?.researchSystem else { return }

        // Update button states based on research system
        for button in techButtons {
            let tech = button.technology

            // Check if completed
            _ = button.isCompleted
            button.isCompleted = researchSystem.completedTechnologies.contains(tech.id)

            // Check if currently researching (this takes priority)
            let wasResearching = button.isResearching
            button.isResearching = researchSystem.currentResearch?.id == tech.id

            // Check if available for research (prerequisites met, not completed, not already researching)
            button.isAvailable = researchSystem.canResearch(tech) && !button.isResearching

            // Debug: log state changes
            if wasResearching != button.isResearching {
                print("ResearchUI: Tech '\(tech.name)' researching state changed: \(wasResearching) -> \(button.isResearching)")
            }
        }

        // Update text labels
        updateLabels()
    }
    
    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Render close button
        closeButton.render(renderer: renderer)

        // Render tech buttons
        for button in techButtons {
            button.render(renderer: renderer)
        }
        
        // Research info and progress are now rendered as text labels
        
        // Render connections between techs
        renderConnections(renderer: renderer)
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

        for button in techButtons {
            if button.handleTap(at: position) {
                return true
            }
        }

        return super.handleTap(at: position)
    }

    func getTooltip(at position: Vector2) -> String? {
        guard isOpen else { return nil }

        for button in techButtons {
            if button.frame.contains(position) {
                let tech = button.technology
                var tooltip = "\(tech.name)\n\(tech.description)\n\nCost:"

                for scienceCost in tech.cost {
                    tooltip += " \(scienceCost.count) \(scienceCost.packId.replacingOccurrences(of: "-", with: " ").capitalized)"
                }

                if !tech.prerequisites.isEmpty {
                    tooltip += "\n\nRequires:"
                    for prereq in tech.prerequisites {
                        if let prereqTech = gameLoop?.technologyRegistry.get(prereq) {
                            tooltip += " \(prereqTech.name)"
                        }
                    }
                }

                return tooltip
            }
        }

        return nil
    }
}

class TechButton: UIElement {
    var frame: Rect
    let technology: Technology
    var isCompleted: Bool = false
    var isAvailable: Bool = false
    var isResearching: Bool = false
    var onTap: (() -> Void)?
    
    init(frame: Rect, technology: Technology) {
        self.frame = frame
        self.technology = technology
    }
    
    func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) && isAvailable else { return false }
        onTap?()
        return true
    }
    
    func render(renderer: MetalRenderer) {
        var bgColor: Color
        // Priority: completed > researching > available > unavailable
        // Use very subtle backgrounds so text labels are clearly visible
        if isCompleted {
            bgColor = Color(r: 0.2, g: 0.4, b: 0.2, a: 0.3) // Green, very transparent
        } else if isResearching {
            bgColor = Color(r: 0.45, g: 0.45, b: 0.15, a: 0.4) // Bright yellow/gold, slightly more visible
        } else if isAvailable {
            bgColor = Color(r: 0.25, g: 0.25, b: 0.3, a: 0.2) // Light blue, very transparent
        } else {
            // Unavailable - barely visible to indicate locked state
            bgColor = Color(r: 0.2, g: 0.15, b: 0.15, a: 0.1) // Dark red, almost invisible
        }

        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: solidRect,
            color: bgColor,
            layer: .ui
        ))
    }
}
