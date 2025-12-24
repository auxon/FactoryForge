import Foundation

/// Research/Technology tree UI
final class ResearchUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var techButtons: [TechButton] = []
    private var selectedTech: Technology?
    
    init(screenSize: Vector2, gameLoop: GameLoop?) {
        let panelWidth: Float = 600
        let panelHeight: Float = 500
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(panelWidth, panelHeight)
        )
        
        super.init(frame: panelFrame)
        self.gameLoop = gameLoop
    }
    
    override func open() {
        super.open()
        refreshTechTree()
    }
    
    private func refreshTechTree() {
        techButtons.removeAll()
        
        guard let registry = gameLoop?.technologyRegistry else { return }
        
        let buttonWidth: Float = 120
        let buttonHeight: Float = 40
        let tierSpacing: Float = 150
        let buttonSpacing: Float = 50
        
        // Group by tier
        for tier in 1...3 {
            let techs = registry.technologies(tier: tier)
            let tierX = frame.minX + 80 + Float(tier - 1) * tierSpacing
            var currentY = frame.minY + 60
            
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
    }
    
    private func selectTechnology(_ tech: Technology) {
        selectedTech = tech
        
        // Try to start research
        if let researchSystem = findResearchSystem() {
            if researchSystem.selectResearch(tech.id) {
                AudioManager.shared.playClickSound()
            }
        }
    }
    
    private func findResearchSystem() -> ResearchSystem? {
        // Would need proper access to research system
        return nil
    }
    
    override func update(deltaTime: Float) {
        guard isOpen else { return }
        
        // Update button states
        // Would need access to research system
    }
    
    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }
        
        super.render(renderer: renderer)
        
        // Render tech buttons
        for button in techButtons {
            button.render(renderer: renderer)
        }
        
        // Render current research progress
        renderResearchProgress(renderer: renderer)
        
        // Render connections between techs
        renderConnections(renderer: renderer)
    }
    
    private func renderResearchProgress(renderer: MetalRenderer) {
        let progressBarWidth: Float = frame.width - 40
        let progressBarHeight: Float = 20
        let progressY = frame.maxY - 50
        
        // Background
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: Vector2(frame.center.x, progressY),
            size: Vector2(progressBarWidth, progressBarHeight),
            textureRect: solidRect,
            color: Color(r: 0.15, g: 0.15, b: 0.2, a: 1),
            layer: .ui
        ))
        
        // Would render actual progress here
    }
    
    private func renderConnections(renderer: MetalRenderer) {
        // Would render lines between prerequisite techs
    }
    
    override func handleTap(at position: Vector2) -> Bool {
        guard isOpen else { return false }
        
        for button in techButtons {
            if button.handleTap(at: position) {
                return true
            }
        }
        
        return super.handleTap(at: position)
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
        if isCompleted {
            bgColor = Color(r: 0.2, g: 0.4, b: 0.2, a: 1)
        } else if isResearching {
            bgColor = Color(r: 0.4, g: 0.4, b: 0.2, a: 1)
        } else if isAvailable {
            bgColor = Color(r: 0.25, g: 0.25, b: 0.3, a: 1)
        } else {
            bgColor = Color(r: 0.15, g: 0.15, b: 0.15, a: 1)
        }
        
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: solidRect,
            color: bgColor,
            layer: .ui
        ))
        
        // Tech icon would go here
    }
}

