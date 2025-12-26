import Foundation

/// Research/Technology tree UI
final class ResearchUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var techButtons: [TechButton] = []
    private var closeButton: CloseButton!
    private var selectedTech: Technology?
    
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

    private func setupCloseButton() {
        let buttonSize: Float = 30 * UIScale
        let buttonX = frame.maxX - 25 * UIScale
        let buttonY = frame.minY + 25 * UIScale

        closeButton = CloseButton(frame: Rect(center: Vector2(buttonX, buttonY), size: Vector2(buttonSize, buttonSize)))
        closeButton.onTap = { [weak self] in
            self?.close()
        }
    }

    override func open() {
        super.open()
        refreshTechTree()
        // Force update to set initial button states
        update(deltaTime: 0)
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
        selectedTech = tech
        
        // Try to start research
        if let researchSystem = findResearchSystem() {
            let success = researchSystem.selectResearch(tech.id)
            print("ResearchUI: Attempted to start research '\(tech.name)' (id: \(tech.id)), success: \(success)")
            
            if success {
                AudioManager.shared.playClickSound()
                // Immediately update button states to reflect the change
                update(deltaTime: 0)
            } else {
                print("ResearchUI: Failed to start research - tech may not be available or already completed")
            }
        } else {
            print("ResearchUI: No research system available")
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
        
        // Render current research info and progress
        renderResearchInfo(renderer: renderer)
        renderResearchProgress(renderer: renderer)
        
        // Render connections between techs
        renderConnections(renderer: renderer)
    }
    
    private func renderResearchInfo(renderer: MetalRenderer) {
        guard let researchSystem = gameLoop?.researchSystem,
              researchSystem.currentResearch != nil else {
            return // No active research
        }
        
        // Render technology name area (we can't render text yet, so use a colored bar)
        // Yellow/orange tint to indicate active research
        let infoBarWidth: Float = frame.width - 40 * UIScale
        let infoBarHeight: Float = 30 * UIScale
        let infoBarY = frame.maxY - 85 * UIScale
        
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: Vector2(frame.center.x, infoBarY),
            size: Vector2(infoBarWidth, infoBarHeight),
            textureRect: solidRect,
            color: Color(r: 0.4, g: 0.35, b: 0.2, a: 0.9), // Yellowish tint to match researching button
            layer: .ui
        ))
    }
    
    private func renderResearchProgress(renderer: MetalRenderer) {
        guard let researchSystem = gameLoop?.researchSystem,
              researchSystem.currentResearch != nil else {
            return // No active research
        }
        
        let progressBarWidth: Float = frame.width - 40 * UIScale
        let progressBarHeight: Float = 20 * UIScale
        let progressY = frame.maxY - 50 * UIScale
        
        // Background
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: Vector2(frame.center.x, progressY),
            size: Vector2(progressBarWidth, progressBarHeight),
            textureRect: solidRect,
            color: Color(r: 0.15, g: 0.15, b: 0.2, a: 1),
            layer: .ui
        ))
        
        // Progress fill
        let progress = researchSystem.getResearchProgress()
        if progress > 0 {
            let fillWidth = progressBarWidth * progress
            renderer.queueSprite(SpriteInstance(
                position: Vector2(frame.center.x - progressBarWidth / 2 + fillWidth / 2, progressY),
                size: Vector2(fillWidth, progressBarHeight),
                textureRect: solidRect,
                color: Color(r: 0.2, g: 0.6, b: 0.2, a: 1),
                layer: .ui
            ))
        }
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
                return button.technology.name
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
        if isCompleted {
            bgColor = Color(r: 0.2, g: 0.4, b: 0.2, a: 1) // Green
        } else if isResearching {
            bgColor = Color(r: 0.45, g: 0.45, b: 0.15, a: 1) // Bright yellow/gold
        } else if isAvailable {
            bgColor = Color(r: 0.25, g: 0.25, b: 0.3, a: 1) // Light blue
        } else {
            // Unavailable - still visible but darker/reddish to indicate locked
            bgColor = Color(r: 0.2, g: 0.15, b: 0.15, a: 0.7) // Dark red
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
