import Foundation

/// Building selection menu
final class BuildMenu: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var categoryButtons: [BuildCategoryButton] = []
    private var buildingButtons: [BuildingButton] = []
    private var selectedCategory: BuildingType?
    
    var onBuildingSelected: ((String) -> Void)?
    
    init(screenSize: Vector2, gameLoop: GameLoop?) {
        let panelWidth: Float = 350
        let panelHeight: Float = 450
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(panelWidth, panelHeight)
        )
        
        super.init(frame: panelFrame)
        self.gameLoop = gameLoop
        
        setupCategories()
    }
    
    private func setupCategories() {
        let categories: [(BuildingType, String)] = [
            (.miner, "miner"),
            (.furnace, "furnace"),
            (.assembler, "assembler"),
            (.belt, "belt"),
            (.inserter, "inserter"),
            (.powerPole, "power_pole"),
            (.generator, "steam_engine"),
            (.turret, "turret"),
            (.chest, "chest")
        ]
        
        let buttonSize: Float = 40
        let buttonSpacing: Float = 5
        var currentX = frame.minX + 20 + buttonSize / 2
        let categoryY = frame.minY + 30
        
        for (type, textureId) in categories {
            let button = BuildCategoryButton(
                frame: Rect(center: Vector2(currentX, categoryY), size: Vector2(buttonSize, buttonSize)),
                category: type,
                textureId: textureId
            )
            button.onTap = { [weak self] in
                self?.selectCategory(type)
            }
            categoryButtons.append(button)
            currentX += buttonSize + buttonSpacing
        }
        
        // Select first category
        selectCategory(.miner)
    }
    
    private func selectCategory(_ category: BuildingType) {
        selectedCategory = category
        
        for button in categoryButtons {
            button.isSelected = button.category == category
        }
        
        refreshBuildingButtons()
    }
    
    private func refreshBuildingButtons() {
        buildingButtons.removeAll()
        
        guard let category = selectedCategory,
              let registry = gameLoop?.buildingRegistry else { return }
        
        let buildings = registry.buildings(ofType: category)
        
        let buttonSize: Float = 60
        let buttonSpacing: Float = 10
        let buttonsPerRow = 4
        let startX = frame.minX + 30
        let startY = frame.minY + 80
        
        for (index, building) in buildings.enumerated() {
            let row = index / buttonsPerRow
            let col = index % buttonsPerRow
            
            let buttonX = startX + Float(col) * (buttonSize + buttonSpacing) + buttonSize / 2
            let buttonY = startY + Float(row) * (buttonSize + buttonSpacing) + buttonSize / 2
            
            let button = BuildingButton(
                frame: Rect(center: Vector2(buttonX, buttonY), size: Vector2(buttonSize, buttonSize)),
                building: building
            )
            button.onTap = { [weak self] in
                self?.selectBuilding(building.id)
            }
            buildingButtons.append(button)
        }
    }
    
    private func selectBuilding(_ buildingId: String) {
        onBuildingSelected?(buildingId)
        close()
    }
    
    override func update(deltaTime: Float) {
        guard isOpen, let player = gameLoop?.player else { return }
        
        // Update button states based on availability
        for button in buildingButtons {
            button.canBuild = player.inventory.has(items: button.building.cost)
        }
    }
    
    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }
        
        super.render(renderer: renderer)
        
        // Render category buttons
        for button in categoryButtons {
            button.render(renderer: renderer)
        }
        
        // Render building buttons
        for button in buildingButtons {
            button.render(renderer: renderer)
        }
    }
    
    override func handleTap(at position: Vector2) -> Bool {
        guard isOpen else { return false }
        
        for button in categoryButtons {
            if button.handleTap(at: position) {
                return true
            }
        }
        
        for button in buildingButtons {
            if button.handleTap(at: position) {
                return true
            }
        }
        
        return super.handleTap(at: position)
    }
}

class BuildCategoryButton: UIElement {
    var frame: Rect
    let category: BuildingType
    let textureId: String
    var isSelected: Bool = false
    var onTap: (() -> Void)?
    
    init(frame: Rect, category: BuildingType, textureId: String) {
        self.frame = frame
        self.category = category
        self.textureId = textureId
    }
    
    func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }
        onTap?()
        return true
    }
    
    func render(renderer: MetalRenderer) {
        let bgColor = isSelected ?
            Color(r: 0.3, g: 0.4, b: 0.5, a: 1) :
            Color(r: 0.2, g: 0.2, b: 0.25, a: 1)
        
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: solidRect,
            color: bgColor,
            layer: .ui
        ))
        
        let textureRect = renderer.textureAtlas.getTextureRect(for: textureId)
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size * 0.7,
            textureRect: textureRect,
            layer: .ui
        ))
    }
}

class BuildingButton: UIElement {
    var frame: Rect
    let building: BuildingDefinition
    var canBuild: Bool = false
    var onTap: (() -> Void)?
    
    init(frame: Rect, building: BuildingDefinition) {
        self.frame = frame
        self.building = building
    }
    
    func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) && canBuild else { return false }
        onTap?()
        return true
    }
    
    func render(renderer: MetalRenderer) {
        let bgColor = canBuild ?
            Color(r: 0.2, g: 0.25, b: 0.2, a: 1) :
            Color(r: 0.25, g: 0.2, b: 0.2, a: 1)
        
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: solidRect,
            color: bgColor,
            layer: .ui
        ))
        
        let textureRect = renderer.textureAtlas.getTextureRect(for: building.textureId)
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size * 0.8,
            textureRect: textureRect,
            color: canBuild ? .white : Color(r: 0.5, g: 0.5, b: 0.5, a: 1),
            layer: .ui
        ))
    }
}

