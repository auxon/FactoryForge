import Foundation
import UIKit

/// Building selection menu
final class BuildMenu: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var categoryButtons: [BuildCategoryButton] = []
    private var buildingButtons: [BuildingButton] = []
    private var closeButton: CloseButton!
    private var selectedCategory: BuildingType?

    // Building selection mode
    private var selectedBuilding: BuildingDefinition?
    private var lastRenderedBuilding: BuildingDefinition?
    private var buildingLabels: [UILabel] = [] // Track labels for building details
    private var buildButton: UIKit.UIButton? // Track the build button

    // Callbacks for managing UIKit labels and buttons
    var onAddLabels: (([UILabel]) -> Void)?
    var onRemoveLabels: (([UILabel]) -> Void)?
    var onAddBuildButton: ((UIView) -> Void)?
    var onRemoveBuildButton: ((UIView) -> Void)?
    
    
    init(screenSize: Vector2, gameLoop: GameLoop?) {
        // Use full screen size for background
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(screenSize.x, screenSize.y)
        )
        
        super.init(frame: panelFrame)
        self.gameLoop = gameLoop

        setupCloseButton()
        setupCategories()
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

    private func setupCategories() {
        let categories: [(BuildingType, String)] = [
            (.miner, "miner"),
            (.furnace, "furnace"),
            (.assembler, "assembler"),
            (.belt, "belt"),
            (.inserter, "inserter"),
            (.pumpjack, "oil_well"),
            (.waterPump, "water_pump"),
            (.oilRefinery, "oil_refinery"),
            (.chemicalPlant, "chemical_plant"),
            (.powerPole, "power_pole"),
            (.generator, "steam_engine"),
            (.lab, "lab"),
            (.turret, "turret"),
            (.chest, "chest")
        ]

        let buttonSize: Float = 40 * UIScale
        let buttonSpacing: Float = 5 * UIScale
        let totalWidth = Float(categories.count) * buttonSize + Float(categories.count - 1) * buttonSpacing
        var currentX = frame.center.x - totalWidth / 2 + buttonSize / 2
        let categoryY = frame.center.y - 150 * UIScale
        
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

        let buttonSize: Float = 60 * UIScale
        let buttonSpacing: Float = 10 * UIScale
        let buttonsPerRow = 4
        let totalWidth = Float(buttonsPerRow) * buttonSize + Float(buttonsPerRow - 1) * buttonSpacing
        let startX = frame.center.x - totalWidth / 2 + buttonSize / 2
        let startY = frame.center.y - 50 * UIScale
        
        for (index, building) in buildings.enumerated() {
            let row = index / buttonsPerRow
            let col = index % buttonsPerRow
            
            let buttonX = startX + Float(col) * (buttonSize + buttonSpacing) + buttonSize / 2
            let buttonY = startY + Float(row) * (buttonSize + buttonSpacing) + buttonSize / 2
            
            // Check if player can afford this building
            let canAfford = gameLoop?.player.inventory.has(items: building.cost) ?? false

            let button = BuildingButton(
                frame: Rect(center: Vector2(buttonX, buttonY), size: Vector2(buttonSize, buttonSize)),
                building: building
            )
            button.canBuild = canAfford

            button.onTap = { [weak self] in
                self?.selectBuildingForDisplay(building)
            }
            buildingButtons.append(button)
        }
    }
    
    private func selectBuildingForDisplay(_ building: BuildingDefinition) {
        // Remove old build button if it exists
        if let oldButton = buildButton {
            onRemoveBuildButton?(oldButton)
            buildButton = nil
        }

        // Update selected building for display purposes
        selectedBuilding = building

        // Create and show new build button
        setupBuildButton()
    }

    private func buildSelectedBuilding() {
        guard let building = selectedBuilding else { return }

        // Close the menu
        close()

        // Enter build mode with a delay to prevent tap passthrough
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            self.gameLoop?.inputManager?.enterBuildMode(buildingId: building.id)
        }
    }

    private func setupBuildButton() {
        // Position build button at bottom center of screen
        let screenBounds = UIScreen.main.bounds
        let buttonWidth: CGFloat = 180  // Smaller width
        let buttonHeight: CGFloat = 60  // Smaller height
        let buttonX = (screenBounds.width - buttonWidth) / 2  // Center horizontally
        let buttonY = screenBounds.height - buttonHeight - 80  // Bottom with margin

        let button = UIKit.UIButton(frame: CGRect(x: buttonX, y: buttonY, width: buttonWidth, height: buttonHeight))
        button.setTitle("Build", for: UIControl.State.normal)
        button.setTitleColor(UIColor.white, for: UIControl.State.normal)
        button.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false

        button.addTarget(self, action: #selector(buildButtonTapped), for: UIControl.Event.touchUpInside)

        // Use frame-based positioning instead of Auto Layout
        button.translatesAutoresizingMaskIntoConstraints = true

        // Set properties
        button.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)

        // Store and add to view
        buildButton = button
        onAddBuildButton?(button)

        // Set frame after adding to view (important for proper positioning)
        button.frame = CGRect(x: buttonX, y: buttonY, width: buttonWidth, height: buttonHeight)
        button.isHidden = false
    }

    @objc private func buildButtonTapped() {
        buildSelectedBuilding()
    }
    
    override func update(deltaTime: Float) {
        guard isOpen, let player = gameLoop?.player else { return }

        // Update button states based on availability
        for button in buildingButtons {
            button.canBuild = player.inventory.has(items: button.building.cost)
        }
    }

    override func open() {
        super.open()
        onAddLabels?(buildingLabels)
    }

    override func close() {
        onRemoveLabels?(buildingLabels)
        buildingLabels.removeAll()
        selectedBuilding = nil
        lastRenderedBuilding = nil
        // Remove build button if it exists
        if let button = buildButton {
            onRemoveBuildButton?(button)
            buildButton = nil
        }
        super.close()
    }
    
    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Render close button
        closeButton.render(renderer: renderer)

        // Render category buttons
        for button in categoryButtons {
            button.render(renderer: renderer)
        }

        // Render building buttons
        for button in buildingButtons {
            button.render(renderer: renderer)
        }

        // Render selected building details
        if let building = selectedBuilding {
            // Always render the building info (every frame)
            renderBuildingInfo(building: building, renderer: renderer)

            // Only recreate labels if building changed
            if building.id != lastRenderedBuilding?.id {
                // Clear previous labels
                if !buildingLabels.isEmpty {
                    onRemoveLabels?(buildingLabels)
                    buildingLabels.removeAll()
                }
                // Create new labels for this building
                createBuildingLabels(building: building, renderer: renderer)
                lastRenderedBuilding = building
            }
            // If building hasn't changed, labels already exist and persist
        } else if lastRenderedBuilding != nil {
            // Building was deselected, clear the details
            if !buildingLabels.isEmpty {
                onRemoveLabels?(buildingLabels)
                buildingLabels.removeAll()
            }
            lastRenderedBuilding = nil
        }
    }
    
    override func handleTap(at position: Vector2) -> Bool {
        guard isOpen else { return false }

        // Check close button first
        if closeButton.handleTap(at: position) {
            return true
        }

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

    func getTooltip(at position: Vector2) -> String? {
        guard isOpen else { return nil }

        for button in categoryButtons {
            if button.frame.contains(position) {
                return button.category.displayName
            }
        }

        for button in buildingButtons {
            if button.frame.contains(position) {
                return button.building.name
            }
        }

        return nil
    }

    private func renderBuildingInfo(building: BuildingDefinition, renderer: MetalRenderer) {
        let iconSize: Float = 30 * UIScale
        let iconSpacing: Float = 40 * UIScale
        let detailsY = frame.maxY - 120 * UIScale

        // Building inputs (costs)
        var inputX = frame.minX + 50 * UIScale
        for itemStack in building.cost {
            let textureRect = renderer.textureAtlas.getTextureRect(for: itemStack.itemId.replacingOccurrences(of: "-", with: "_"))
            renderer.queueSprite(SpriteInstance(
                position: Vector2(inputX, detailsY),
                size: Vector2(iconSize, iconSize),
                textureRect: textureRect,
                layer: .ui
            ))

            inputX += iconSpacing
        }

        // Arrow
        let arrowRect = renderer.textureAtlas.getTextureRect(for: "right_arrow")
        renderer.queueSprite(SpriteInstance(
            position: Vector2(inputX + 20 * UIScale, detailsY),
            size: Vector2(iconSize, iconSize),
            textureRect: arrowRect,
            layer: .ui
        ))

        // Building output (the building itself)
        let outputX = inputX + 60 * UIScale
        let textureRect = renderer.textureAtlas.getTextureRect(for: building.textureId)
        renderer.queueSprite(SpriteInstance(
            position: Vector2(outputX, detailsY),
            size: Vector2(iconSize, iconSize),
            textureRect: textureRect,
            layer: .ui
        ))
    }

    private func createBuildingLabels(building: BuildingDefinition, renderer: MetalRenderer) {
        // Create a label for the building name
        let nameLabel = createBuildingNameLabel(text: building.name, centerX: frame.minX + 100 * UIScale, centerY: frame.maxY - 120 * UIScale)
        buildingLabels.append(nameLabel)

        // Create labels for building requirements
        var yOffset: Float = 100 * UIScale
        for itemStack in building.cost {
            if let itemDef = gameLoop?.itemRegistry.get(itemStack.itemId) {
                let costLabel = createBuildingCostLabel(
                    itemName: itemDef.name,
                    count: itemStack.count,
                    centerX: frame.minX + 100 * UIScale,
                    centerY: frame.maxY - yOffset
                )
                buildingLabels.append(costLabel)
                yOffset += 25 * UIScale
            }
        }
    }

    private func createBuildingNameLabel(text: String, centerX: Float, centerY: Float) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = UIColor.white
        label.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.8)
        label.textAlignment = NSTextAlignment.center
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = true

        label.sizeToFit()

        let padding: CGFloat = 8
        let labelWidth = label.frame.width + padding * 2
        let labelHeight = label.frame.height + padding

        // Convert to UIView coordinates
        let scale = Float(UIScreen.main.scale)
        let halfWidth = Float(labelWidth) / 2
        let halfHeight = Float(labelHeight) / 2
        let uiX = CGFloat(centerX - halfWidth / scale)
        let uiY = CGFloat(centerY - halfHeight / scale)

        label.frame = CGRect(x: uiX, y: uiY, width: labelWidth, height: labelHeight)

        return label
    }

    private func createBuildingCostLabel(itemName: String, count: Int, centerX: Float, centerY: Float) -> UILabel {
        let text = "\(count) × \(itemName)"
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 12, weight: UIFont.Weight.regular)
        label.textColor = UIColor.white
        label.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 0.8)
        label.textAlignment = NSTextAlignment.left
        label.layer.cornerRadius = 3
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = true

        label.sizeToFit()

        let padding: CGFloat = 6
        let labelWidth = label.frame.width + padding * 2
        let labelHeight = label.frame.height + padding

        // Convert to UIView coordinates
        let scale = Float(UIScreen.main.scale)
        let halfWidth = Float(labelWidth) / 2
        let halfHeight = Float(labelHeight) / 2
        let uiX = CGFloat(centerX - halfWidth / scale)
        let uiY = CGFloat(centerY - halfHeight / scale)

        label.frame = CGRect(x: uiX, y: uiY, width: labelWidth, height: labelHeight)

        return label
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

