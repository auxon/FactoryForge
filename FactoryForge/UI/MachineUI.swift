import Foundation
import UIKit

// Use UIKit's UIButton explicitly to avoid conflict with custom UIButton
typealias UIKitButton = UIKit.UIButton

/// UI for interacting with machines (assemblers, furnaces, etc.)
final class MachineUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var currentEntity: Entity?
    private var recipeButtons: [RecipeButton] = []
    private var inputSlots: [InventorySlot] = []
    private var outputSlots: [InventorySlot] = []
    private var fuelSlots: [InventorySlot] = []

    // Scrollable recipe area using UIKit
    private var recipeScrollView: UIScrollView?
    private var recipeUIButtons: [UIKitButton] = [] // UIKit buttons for recipes

    // Count labels for input, output and fuel slots
    private var inputCountLabels: [UILabel] = []
    private var outputCountLabels: [UILabel] = []
    private var fuelCountLabels: [UILabel] = []

    // Research progress labels for labs
    private var researchProgressLabels: [UILabel] = []

    // Power label for generators
    private var powerLabel: UILabel?

    // Rocket launch button for rocket silos
    private var launchButton: UIButton?

    // Callbacks for managing UIKit labels
    var onAddLabels: (([UILabel]) -> Void)?
    var onRemoveLabels: (([UILabel]) -> Void)?

    var onOpenInventoryForMachine: ((Entity, Int) -> Void)?
    var onOpenResearchMenu: (() -> Void)?
    var onLaunchRocket: ((Entity) -> Void)?
    var onSelectRecipeForMachine: ((Entity, Recipe) -> Void)?
    var onClosePanel: (() -> Void)?

    // Callbacks for managing UIKit scroll view
    var onAddScrollView: ((UIScrollView) -> Void)?
    var onRemoveScrollView: ((UIScrollView) -> Void)?

    // Helper to check if current machine is a lab
    private var isLab: Bool {
        guard let entity = currentEntity, let gameLoop = gameLoop else { return false }
        return gameLoop.world.has(LabComponent.self, for: entity)
    }

    // Helper to check if current machine is a rocket silo
    private var isRocketSilo: Bool {
        guard let entity = currentEntity, let gameLoop = gameLoop else { return false }
        return gameLoop.world.has(RocketSiloComponent.self, for: entity)
    }

    // Helper to check if current machine is a generator
    private var isGenerator: Bool {
        guard let entity = currentEntity, let gameLoop = gameLoop else { return false }
        return gameLoop.world.has(GeneratorComponent.self, for: entity)
    }

    init(screenSize: Vector2, gameLoop: GameLoop?) {
        let panelWidth: Float = 600 * UIScale
        let panelHeight: Float = 350 * UIScale
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(panelWidth, panelHeight)
        )

        super.init(frame: panelFrame)
        self.gameLoop = gameLoop

        setupSlots()
        setupRecipeScrollView()
    }

    private func setupSlots() {
        // Clear existing slots and labels
        inputSlots.removeAll()
        outputSlots.removeAll()
        fuelSlots.removeAll()
        inputCountLabels.removeAll()
        outputCountLabels.removeAll()
        fuelCountLabels.removeAll()

        // Get machine building definition
        guard let entity = currentEntity,
              let gameLoop = gameLoop else {
            print("MachineUI: Missing entity or gameLoop")
            return
        }

        // Try to get building component (check specific types since inheritance might not work in ECS)
        let buildingEntity: BuildingComponent?
        if let miner = gameLoop.world.get(MinerComponent.self, for: entity) {
            buildingEntity = miner
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            buildingEntity = furnace
        } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            buildingEntity = assembler
        } else if let generator = gameLoop.world.get(GeneratorComponent.self, for: entity) {
            buildingEntity = generator
        } else if let lab = gameLoop.world.get(LabComponent.self, for: entity) {
            buildingEntity = lab
        } else if let rocketSilo = gameLoop.world.get(RocketSiloComponent.self, for: entity) {
            buildingEntity = rocketSilo
        } else {
            print("MachineUI: No building component found for entity")
            return
        }

        guard let buildingDef = gameLoop.buildingRegistry.get(buildingEntity!.buildingId) else {
            print("MachineUI: Failed to get building definition for entity \(entity.id) buildingId: '\(buildingEntity!.buildingId)'")
            return
        }

        let slotSize: Float = 40 * UIScale
        let slotSpacing: Float = 5 * UIScale

        let inputCount = buildingDef.inputSlots
        let outputCount = buildingDef.outputSlots
        let fuelCount = buildingDef.fuelSlots

        // Create fuel slots (left side, top)
        for i in 0..<fuelCount {
            let x = frame.center.x - 200 * UIScale - slotSize/2
            let y = frame.center.y - 120 * UIScale + Float(i) * (slotSize + slotSpacing)

            let slotFrame = Rect(center: Vector2(x, y), size: Vector2(slotSize, slotSize))
            // Use lighter gray for fuel slots
            let fuelSlotColor = Color(r: 0.35, g: 0.35, b: 0.35, a: 1)
            let slot = InventorySlot(frame: slotFrame, index: i, backgroundColor: fuelSlotColor)
            fuelSlots.append(slot)

            // Count label
            let label = UILabel()
            label.text = "0"
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = .white
            label.textAlignment = .center
            label.frame = CGRect(x: CGFloat(x - slotSize/2 - 25), y: CGFloat(y + slotSize/2 + 2), width: 20, height: 12)
            fuelCountLabels.append(label)
        }

        // Create input slots (left side, below fuel)
        for i in 0..<inputCount {
            let x = frame.center.x - 200 * UIScale - slotSize/2
            let y = frame.center.y - 80 * UIScale + Float(i) * (slotSize + slotSpacing)

            let slotFrame = Rect(center: Vector2(x, y), size: Vector2(slotSize, slotSize))
            let slot = InventorySlot(frame: slotFrame, index: i)
            inputSlots.append(slot)

            // Count label
            let label = UILabel()
            label.text = "0"
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = .white
            label.textAlignment = .center
            label.frame = CGRect(x: CGFloat(x - slotSize/2 - 25), y: CGFloat(y + slotSize/2 + 2), width: 20, height: 12)
            inputCountLabels.append(label)
        }

        // Create output slots (right side)
        for i in 0..<outputCount {
            let x = frame.center.x + 200 * UIScale + slotSize/2
            let y = frame.center.y - 80 * UIScale + Float(i) * (slotSize + slotSpacing)

            let slotFrame = Rect(center: Vector2(x, y), size: Vector2(slotSize, slotSize))
            let slot = InventorySlot(frame: slotFrame, index: i)
            outputSlots.append(slot)

            // Count label
            let label = UILabel()
            label.text = "0"
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = .white
            label.textAlignment = .center
            label.frame = CGRect(x: CGFloat(x - slotSize/2 - 25), y: CGFloat(y + slotSize/2 + 2), width: 20, height: 12)
            outputCountLabels.append(label)
        }
    }

    func setEntity(_ entity: Entity) {
        currentEntity = entity
        setupSlots() // Re-setup slots based on machine inventory size
        setupSlotsForMachine(entity)
        refreshRecipeButtons()

        // Setup power label for generators
        setupPowerLabel(for: entity)
    }

    private func setupPowerLabel(for entity: Entity) {
        // Remove existing power label if any
        powerLabel = nil

        // Create power label if this is a generator
        if isGenerator {
            let label = UILabel()
            label.text = "Power"
            label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            label.textColor = .white
            label.textAlignment = .center
            powerLabel = label
        }
    }

    override func open() {
        super.open()
        // Add appropriate labels to the view
        var allLabels = inputCountLabels + outputCountLabels + fuelCountLabels
        if isLab {
            allLabels += researchProgressLabels
        }
        if isGenerator, let powerLabel = powerLabel {
            allLabels.append(powerLabel)
        }
        onAddLabels?(allLabels)

        // Position the count labels
        positionCountLabels()

        // Add rocket launch button for rocket silos
        if isRocketSilo {
            setupRocketLaunchButton()
        }

        // Refresh recipe buttons for current machine
        refreshRecipeButtons()

        // Add scroll view for recipes
        if let scrollView = recipeScrollView {
            onAddScrollView?(scrollView)
            scrollView.isHidden = false // Ensure it's visible when panel opens
        }
    }

    override func close() {
        // Remove all count labels from the view
        var allLabels = inputCountLabels + outputCountLabels + fuelCountLabels + researchProgressLabels
        if let powerLabel = powerLabel {
            allLabels.append(powerLabel)
        }
        onRemoveLabels?(allLabels)

        // Clear label text to ensure they're properly reset
        for label in allLabels {
            label.text = ""
            label.isHidden = true
        }

        // Remove rocket launch button
        launchButton = nil

        // Remove scroll view
        if let scrollView = recipeScrollView {
            onRemoveScrollView?(scrollView)
        }

        super.close()
    }

    private func createBuildingRecipes(for gameLoop: GameLoop) -> [Recipe] {
        var buildingRecipes: [Recipe] = []

        // Advanced buildings that should be crafted in assemblers (not basic infrastructure)
        // These are complex buildings that require assembly rather than simple hand crafting
        let advancedBuildingIds = [
            "assembling-machine-1", "assembling-machine-2", "assembling-machine-3",
            "electric-furnace",
            "lab",
            "oil-refinery", "chemical-plant",
            "centrifuge",
            "solar-panel", "accumulator",
            "rocket-silo"
        ]

        for buildingId in advancedBuildingIds {
            // Only include buildings that are unlocked (have their prerequisites met)
            if gameLoop.isRecipeUnlocked(buildingId),
               let building = gameLoop.buildingRegistry.get(buildingId) {
                // Create a recipe from the building definition
                let recipe = Recipe(
                    id: building.id,
                    name: building.name,
                    inputs: building.cost, // Use building cost as recipe inputs
                    outputs: [ItemStack(itemId: building.id, count: 1)], // Output 1 building
                    craftTime: 0.5, // Standard crafting time for buildings
                    category: .crafting, // Buildings are crafted in assemblers
                    enabled: true,
                    order: "z" // Put buildings at the end of the recipe list
                )
                buildingRecipes.append(recipe)
            }
        }

        return buildingRecipes.sorted { $0.order < $1.order }
    }

    private func setupRecipeScrollView() {
        // Remove existing scroll view and buttons
        recipeScrollView?.removeFromSuperview()
        recipeScrollView = nil
        recipeUIButtons.removeAll()

        // Position scrollview right under the progress bar
        // Panel is centered on screen, progress bar is positioned relative to panel center
        let screenBounds = UIScreen.main.bounds
        let panelWidth: CGFloat = 600 * CGFloat(UIScale)
        let panelHeight: CGFloat = 350 * CGFloat(UIScale)
        let panelX = (screenBounds.width - panelWidth) / 2
        let panelY = (screenBounds.height - panelHeight) / 2

        // Progress bar is at panel center Y - 30 * UIScale, height 20 * UIScale
        // So progress bar bottom is at panel center Y - 20 * UIScale
        let progressBarBottomY = panelY + panelHeight/2 - 20 * CGFloat(UIScale)
        let scrollViewTopMargin: CGFloat = 10 * CGFloat(UIScale) // Small gap below progress bar

        // Position scrollview under progress bar, centered horizontally
        let scrollViewWidth: CGFloat = 300 // Fixed width that fits within typical panel
        let scrollViewHeight: CGFloat = 140 // Fixed height to fit nicely
        let scrollViewX = panelX + (panelWidth - scrollViewWidth) / 2 // Center horizontally in panel
        let scrollViewY = progressBarBottomY + scrollViewTopMargin

        let scrollViewFrame = CGRect(x: scrollViewX, y: scrollViewY, width: scrollViewWidth, height: scrollViewHeight)

        let scrollView = UIScrollView(frame: scrollViewFrame)
        scrollView.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.9)
        scrollView.layer.borderColor = UIColor.white.cgColor
        scrollView.layer.borderWidth = 2
        scrollView.layer.cornerRadius = 8
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false

        // Store reference
        recipeScrollView = scrollView
    }

    private func refreshRecipeButtons() {
        recipeButtons.removeAll()
        recipeUIButtons.forEach { $0.removeFromSuperview() }
        recipeUIButtons.removeAll()

        guard let entity = currentEntity,
              let gameLoop = gameLoop,
              let scrollView = recipeScrollView else { return }

        // Get available recipes for this machine type
        var availableRecipes: [Recipe] = []

        if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            print("MachineUI: Machine is assembler with category: \(assembler.craftingCategory)")
            availableRecipes = gameLoop.recipeRegistry.recipes(in: CraftingCategory(rawValue: assembler.craftingCategory) ?? .crafting)
            print("MachineUI: Found \(availableRecipes.count) crafting recipes for assembler")

            // Add advanced building recipes for assemblers - complex machinery
            let buildingRecipes = createBuildingRecipes(for: gameLoop)
            availableRecipes += buildingRecipes
            print("MachineUI: Added \(buildingRecipes.count) building recipes for assembler (total: \(availableRecipes.count))")
        } else if gameLoop.world.has(FurnaceComponent.self, for: entity) {
            print("MachineUI: Machine is furnace")
            availableRecipes = gameLoop.recipeRegistry.recipes(in: .smelting)
            print("MachineUI: Found \(availableRecipes.count) smelting recipes for furnace")
        } else if gameLoop.world.has(MinerComponent.self, for: entity) {
            print("MachineUI: Machine is mining drill (no recipes needed)")
            availableRecipes = []
        } else if gameLoop.world.has(GeneratorComponent.self, for: entity) {
            print("MachineUI: Machine is generator/boiler (no recipes needed)")
            availableRecipes = []
        } else if gameLoop.world.has(LabComponent.self, for: entity) {
            print("MachineUI: Machine is lab (no recipes needed)")
            availableRecipes = []
        } else if gameLoop.world.has(RocketSiloComponent.self, for: entity) {
            print("MachineUI: Machine is rocket silo")
            // Rocket silos don't have recipes, but show launch controls
            availableRecipes = []
        } else {
            print("MachineUI: Machine type not recognized")
            availableRecipes = []
        }

        // Create UIKit buttons inside scroll view
        let buttonSize: CGFloat = 32 // Fixed 32x32 pixels for icons
        let buttonSpacing: CGFloat = 4
        let buttonsPerRow = 6  // Fewer per row to ensure they fit

        var totalHeight: CGFloat = 0

        for (index, recipe) in availableRecipes.enumerated() {
            let row = index / buttonsPerRow
            let col = index % buttonsPerRow

            let x = CGFloat(col) * (buttonSize + buttonSpacing) + buttonSize/2
            let y = CGFloat(row) * (buttonSize + buttonSpacing) + buttonSize/2

            let buttonFrame = CGRect(x: x, y: y, width: buttonSize, height: buttonSize)

            let button = UIKitButton(frame: buttonFrame)
            button.layer.borderColor = UIColor.white.cgColor
            button.layer.borderWidth = 1
            button.layer.cornerRadius = 4

            // Set background color based on item type
            if let output = recipe.outputs.first {
                button.backgroundColor = getColorForItem(itemId: output.itemId)
            } else {
                button.backgroundColor = UIColor.gray
            }

            // Add item icon image
            if let output = recipe.outputs.first {
                let imageName = output.itemId.replacingOccurrences(of: "-", with: "_")
                if let iconImage = UIImage(named: imageName) {
                    // Scale image to fit button
                    let scaledImage = UIGraphicsImageRenderer(size: CGSize(width: buttonSize - 4, height: buttonSize - 4)).image { _ in
                        iconImage.draw(in: CGRect(origin: .zero, size: CGSize(width: buttonSize - 4, height: buttonSize - 4)))
                    }
                    button.setImage(scaledImage, for: .normal)
                    button.imageView?.contentMode = .scaleAspectFit
                }
            }

            // Store recipe ID in button tag for lookup
            button.tag = recipe.id.hashValue

            // Add tap handler
            button.addTarget(self, action: #selector(recipeButtonTapped(_:)), for: UIKit.UIControl.Event.touchUpInside)

            scrollView.addSubview(button)
            recipeUIButtons.append(button)

            // Update total height
            totalHeight = max(totalHeight, y + buttonSize)
        }

        // Set scroll view content size
        scrollView.contentSize = CGSize(width: scrollView.frame.width, height: totalHeight + buttonSpacing)
    }


    private func getColorForItem(itemId: String) -> UIColor {
        if itemId.contains("transport-belt") || itemId.contains("fast-transport-belt") {
            return UIColor.yellow
        } else if itemId.contains("express-transport-belt") {
            return UIColor.purple
        } else if itemId.contains("inserter") {
            return UIColor.orange
        } else if itemId.contains("chest") {
            return UIColor.brown
        } else if itemId.contains("furnace") || itemId.contains("assembler") {
            return UIColor.gray
        } else if itemId.contains("pole") {
            return UIColor.lightGray
        } else if itemId.contains("solar-panel") || itemId.contains("accumulator") {
            return UIColor.blue
        } else {
            return UIColor.green // Default for other items
        }
    }

    @objc func recipeButtonTapped(_ sender: AnyObject) {
        guard let button = sender as? UIKitButton,
              let entity = currentEntity,
              let gameLoop = gameLoop else { return }

        // Find recipe by ID stored in button tag
        let recipeIdHash = button.tag
        let allRecipes = gameLoop.recipeRegistry.all + (createBuildingRecipes(for: gameLoop))

        if let recipe = allRecipes.first(where: { $0.id.hashValue == recipeIdHash }) {
            onSelectRecipeForMachine?(entity, recipe)
        }
    }

    private func setupSlotsForMachine(_ entity: Entity) {
        guard let gameLoop = gameLoop else { return }

        // Clear all slots
        for slot in inputSlots {
            slot.item = nil
        }
        for slot in outputSlots {
            slot.item = nil
        }
        for slot in fuelSlots {
            slot.item = nil
        }

        // Get machine inventory and building definition
        guard let inventory = gameLoop.world.get(InventoryComponent.self, for: entity) else { return }

        // Try to get building component by checking specific types
        let buildingEntity: BuildingComponent?
        if let miner = gameLoop.world.get(MinerComponent.self, for: entity) {
            buildingEntity = miner
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            buildingEntity = furnace
        } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            buildingEntity = assembler
        } else if let generator = gameLoop.world.get(GeneratorComponent.self, for: entity) {
            buildingEntity = generator
        } else if let lab = gameLoop.world.get(LabComponent.self, for: entity) {
            buildingEntity = lab
        } else if let rocketSilo = gameLoop.world.get(RocketSiloComponent.self, for: entity) {
            buildingEntity = rocketSilo
        } else {
            return
        }

        guard gameLoop.buildingRegistry.get(buildingEntity!.buildingId) != nil else { return }

        let totalSlots = inventory.slots.count
        var inventoryIndex = 0

        // Map fuel slots (first in inventory)
        for i in 0..<fuelSlots.count {
            if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                fuelSlots[i].item = item
                fuelSlots[i].isRequired = false
            } else {
                fuelSlots[i].item = nil
                fuelSlots[i].isRequired = false
            }
            inventoryIndex += 1
        }

        // Check if this is an assembler with a recipe set
        var currentRecipe: Recipe? = nil
        if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            currentRecipe = assembler.recipe
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            currentRecipe = furnace.recipe
        }

        // Map input slots - show required ingredients for current recipe
        if let recipe = currentRecipe {
            for i in 0..<min(inputSlots.count, recipe.inputs.count) {
                let requiredItem = recipe.inputs[i]
                // Check if we have this item in inventory at the expected position
                if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex], item.itemId == requiredItem.itemId {
                    inputSlots[i].item = item
                    inputSlots[i].isRequired = false
                } else {
                    // Show required item even if not in inventory
                    inputSlots[i].item = ItemStack(itemId: requiredItem.itemId, count: 0)
                    inputSlots[i].isRequired = true
                }
                inventoryIndex += 1
            }
            // Clear remaining input slots
            for i in recipe.inputs.count..<inputSlots.count {
                inputSlots[i].item = nil
                inputSlots[i].isRequired = false
            }
        } else {
            // No recipe set - show actual inventory items
            for i in 0..<inputSlots.count {
                if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                    inputSlots[i].item = item
                    inputSlots[i].isRequired = false
                } else {
                    inputSlots[i].item = nil
                    inputSlots[i].isRequired = false
                }
                inventoryIndex += 1
            }
        }

        // Map output slots - show recipe outputs or actual inventory
        if let recipe = currentRecipe {
            for i in 0..<min(outputSlots.count, recipe.outputs.count) {
                let outputItem = recipe.outputs[i]
                // Check if we have this output in inventory
                if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex], item.itemId == outputItem.itemId {
                    outputSlots[i].item = item
                    outputSlots[i].isRequired = false
                } else {
                    // Show expected output
                    outputSlots[i].item = ItemStack(itemId: outputItem.itemId, count: 0)
                    outputSlots[i].isRequired = true // Expected output
                }
                inventoryIndex += 1
            }
            // Clear remaining output slots
            for i in recipe.outputs.count..<outputSlots.count {
                outputSlots[i].item = nil
                outputSlots[i].isRequired = false
            }
        } else {
            // No recipe set - show actual inventory items
            for i in 0..<outputSlots.count {
                if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                    outputSlots[i].item = item
                    outputSlots[i].isRequired = false
                } else {
                    outputSlots[i].item = nil
                    outputSlots[i].isRequired = false
                }
                inventoryIndex += 1
            }
        }
        // Update count labels
        updateCountLabels(entity)
    }

    private func updateCountLabels(_ entity: Entity) {
        guard let gameLoop = gameLoop,
              let inventory = gameLoop.world.get(InventoryComponent.self, for: entity) else { return }

        // Try to get building component by checking specific types
        let buildingEntity: BuildingComponent?
        if let miner = gameLoop.world.get(MinerComponent.self, for: entity) {
            buildingEntity = miner
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            buildingEntity = furnace
        } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            buildingEntity = assembler
        } else if let generator = gameLoop.world.get(GeneratorComponent.self, for: entity) {
            buildingEntity = generator
        } else if let lab = gameLoop.world.get(LabComponent.self, for: entity) {
            buildingEntity = lab
        } else if let rocketSilo = gameLoop.world.get(RocketSiloComponent.self, for: entity) {
            buildingEntity = rocketSilo
        } else {
            return
        }

        guard gameLoop.buildingRegistry.get(buildingEntity!.buildingId) != nil else { return }

        let totalSlots = inventory.slots.count
        var inventoryIndex = 0

        // Update fuel slot labels
        for i in 0..<fuelCountLabels.count {
            if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                fuelCountLabels[i].text = "\(item.count)"
                fuelCountLabels[i].isHidden = false
            } else {
                fuelCountLabels[i].text = "0"
                fuelCountLabels[i].isHidden = true
            }
            inventoryIndex += 1
        }

        // Update input slot labels
        for i in 0..<inputCountLabels.count {
            if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                inputCountLabels[i].text = "\(item.count)"
                inputCountLabels[i].isHidden = false
            } else {
                inputCountLabels[i].text = "0"
                inputCountLabels[i].isHidden = true
            }
            inventoryIndex += 1
        }

        // Update output slot labels
        for i in 0..<outputCountLabels.count {
            if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                outputCountLabels[i].text = "\(item.count)"
                outputCountLabels[i].isHidden = false
            } else {
                outputCountLabels[i].text = "0"
                outputCountLabels[i].isHidden = true
            }
            inventoryIndex += 1
        }
    }

    func updateMachine(_ entity: Entity) {
        setupSlotsForMachine(entity)
        updateCountLabels(entity)
        positionCountLabels()
    }

    override func update(deltaTime: Float) {
        guard isOpen else { return }

        // Update button states based on craftability and crafting status
        guard let player = gameLoop?.player,
              let gameLoop = gameLoop else { return }

        for uiButton in recipeUIButtons {
            let recipeIdHash = uiButton.tag
            let allRecipes = gameLoop.recipeRegistry.all + (createBuildingRecipes(for: gameLoop))

            if let recipe = allRecipes.first(where: { $0.id.hashValue == recipeIdHash }) {
                let canCraft = recipe.canCraft(with: player.inventory)
                let isCrafting = player.isCrafting(recipe: recipe)

                if isCrafting {
                    uiButton.backgroundColor = UIKit.UIColor(red: 0.3, green: 0.4, blue: 0.6, alpha: 1.0) // Blue for crafting
                } else if canCraft {
                    uiButton.backgroundColor = UIKit.UIColor(red: 0.4, green: 0.7, blue: 0.4, alpha: 1.0) // Green for can craft
                } else {
                    uiButton.backgroundColor = UIKit.UIColor(red: 0.25, green: 0.2, blue: 0.2, alpha: 1.0) // Red for cannot craft
                }
            }
        }
    }

    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Debug: Render slot backgrounds to show positions
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        for slot in fuelSlots + inputSlots + outputSlots {
            renderer.queueSprite(SpriteInstance(
                position: slot.frame.center,
                size: slot.frame.size,
                textureRect: solidRect,
                color: Color(r: 0.5, g: 0.5, b: 0.5, a: 0.3), // Semi-transparent gray
                layer: .ui
            ))
        }

        // Render fuel slots
        for i in 0..<fuelSlots.count {
            fuelSlots[i].render(renderer: renderer)
        }

        // Render input slots
        for i in 0..<inputSlots.count {
            inputSlots[i].render(renderer: renderer)
        }

        // Render output slots
        for i in 0..<outputSlots.count {
            outputSlots[i].render(renderer: renderer)
        }

        // update count labels
        if let entity = currentEntity {
            updateMachine(entity)
        }
        
        // Render recipe buttons
        for button in recipeButtons {
            button.render(renderer: renderer)
        }

        // Render progress bar
        renderProgressBar(renderer: renderer)

        // Render rocket launch button
        if let button = launchButton {
            button.render(renderer: renderer)
        }
    }

    // MARK: - Rocket Launch UI

    private func setupRocketLaunchButton() {
        guard let _ = gameLoop, let entity = currentEntity else { return }

        // Remove existing button if any
        launchButton = nil

        // Create launch button
        let buttonWidth: Float = 200
        let buttonHeight: Float = 50
        let buttonX = frame.center.x - buttonWidth/2
        let buttonY = frame.center.y + frame.size.y/2 - buttonHeight - 20

        let buttonFrame = Rect(center: Vector2(buttonX, buttonY), size: Vector2(buttonWidth, buttonHeight))
        let button = UIButton(frame: buttonFrame, textureId: "solid_white")
        button.label = "🚀 LAUNCH ROCKET"
        button.onTap = { [weak self] in
            self?.launchRocketPressed()
        }

        // Check if rocket can be launched
        updateLaunchButtonState(button, for: entity)

        launchButton = button
    }

    private func launchRocketPressed() {
        guard let entity = currentEntity else { return }
        onLaunchRocket?(entity)
        // Update button state after launch attempt
        if let button = launchButton {
            updateLaunchButtonState(button, for: entity)
        }
    }

    private func updateLaunchButtonState(_ button: UIButton, for entity: Entity) {
        guard let gameLoop = gameLoop else { return }

        // Check if rocket silo has components for launch
        if let silo = gameLoop.world.get(RocketSiloComponent.self, for: entity),
           let _ = gameLoop.world.get(InventoryComponent.self, for: entity) {

            let canLaunch = !silo.isLaunching && silo.rocketAssembled

            button.isEnabled = canLaunch
            button.label = canLaunch ? "🚀 LAUNCH ROCKET" : (silo.isLaunching ? "⏳ LAUNCHING..." : "⚠️ ASSEMBLE ROCKET")
        } else {
            button.isEnabled = false
            button.label = "❌ ERROR"
        }
    }

    private func handleSlotTap(entity: Entity, slotIndex: Int, gameLoop: GameLoop) {
        let world = gameLoop.world

        // Get machine inventory
        guard var machineInventory = world.get(InventoryComponent.self, for: entity),
              slotIndex < machineInventory.slots.count,
              let itemStack = machineInventory.slots[slotIndex] else {
            return
        }

        // Try to add the item to player inventory
        let remainingCount = gameLoop.player.inventory.add(itemStack)

        if remainingCount == 0 {
            // All items were successfully moved to player inventory
            machineInventory.slots[slotIndex] = nil
            world.add(machineInventory, to: entity)

            // Update the UI
            updateMachine(entity)

            print("MachineUI: Returned \(itemStack.count) \(itemStack.itemId) to player inventory")
        } else {
            // Some items couldn't be moved - update the machine slot with remaining items
            let remainingStack = ItemStack(itemId: itemStack.itemId, count: remainingCount, maxStack: itemStack.maxStack)
            machineInventory.slots[slotIndex] = remainingStack
            world.add(machineInventory, to: entity)

            // Update the UI
            updateMachine(entity)

            // Show feedback that only partial items were moved
            showInventoryFullTooltip()
            print("MachineUI: Returned \(itemStack.count - remainingCount) \(itemStack.itemId) to player inventory, \(remainingCount) remaining in machine")
        }
    }

    private func showInventoryFullTooltip() {
        // Show tooltip using the existing tooltip system
        gameLoop?.inputManager?.onTooltip?("Inventory is full!")
    }

    private func handleEmptySlotTap(entity: Entity, slotIndex: Int) {
        // Open inventory UI in machine input mode for this slot
        onOpenInventoryForMachine?(entity, slotIndex)
    }


    private func positionCountLabels() {
        let slotSize: Float = 40 * UIScale

        // Position fuel slot labels
        for i in 0..<fuelSlots.count {
            let slot = fuelSlots[i]
            let label = fuelCountLabels[i]

            // Label position: bottom-right corner of slot
            let labelWidth: Float = 24
            let labelHeight: Float = 12
            let labelX = slot.frame.center.x - slotSize/2 + slotSize - labelWidth
            let labelY = slot.frame.center.y - slotSize/2 + slotSize - labelHeight

            // Convert to UIView coordinates
            let scale = UIScreen.main.scale
            let uiX = CGFloat(labelX) / scale
            let uiY = CGFloat(labelY) / scale

            label.frame = CGRect(x: uiX, y: uiY, width: CGFloat(labelWidth), height: CGFloat(labelHeight))
        }

        // Position input slot labels
        for i in 0..<inputSlots.count {
            let slot = inputSlots[i]
            let label = inputCountLabels[i]

            // Label position: bottom-right corner of slot
            let labelWidth: Float = 24
            let labelHeight: Float = 12
            let labelX = slot.frame.center.x - slotSize/2 + slotSize - labelWidth
            let labelY = slot.frame.center.y - slotSize/2 + slotSize - labelHeight

            // Convert to UIView coordinates
            let scale = UIScreen.main.scale
            let uiX = CGFloat(labelX) / scale
            let uiY = CGFloat(labelY) / scale

            label.frame = CGRect(x: uiX, y: uiY, width: CGFloat(labelWidth), height: CGFloat(labelHeight))
        }

        // Position output slot labels
        for i in 0..<outputSlots.count {
            let slot = outputSlots[i]
            let label = outputCountLabels[i]

            // Label position: bottom-right corner of slot
            let labelWidth: Float = 20
            let labelHeight: Float = 12
            let labelX = slot.frame.center.x - slotSize/2 + slotSize - labelWidth
            let labelY = slot.frame.center.y - slotSize/2 + slotSize - labelHeight

            // Convert to UIView coordinates
            let scale = UIScreen.main.scale
            let uiX = CGFloat(labelX) / scale
            let uiY = CGFloat(labelY) / scale

            label.frame = CGRect(x: uiX, y: uiY, width: CGFloat(labelWidth), height: CGFloat(labelHeight))
        }

        // Position power label above the power bar
        if let powerLabel = powerLabel {
            let labelWidth: Float = 100
            let labelHeight: Float = 16
            let labelX = frame.center.x - labelWidth/2  // Center the label
            let labelY = frame.center.y - 85 * UIScale  // Position above the power bar

            // Convert to UIView coordinates
            let scale = UIScreen.main.scale
            let uiX = CGFloat(labelX) / scale
            let uiY = CGFloat(labelY) / scale

            powerLabel.frame = CGRect(x: uiX, y: uiY, width: CGFloat(labelWidth), height: CGFloat(labelHeight))
        }
    }

    override func handleTap(at position: Vector2) -> Bool {
        guard isOpen else { return false }

        // Check rocket launch button first
        if let button = launchButton, button.handleTap(at: position) {
            return true
        }

        // Check recipe buttons
        for button in recipeButtons {
            if button.handleTap(at: position) {
                return true
            }
        }

        // Get building component for inventory index calculations
        guard let entity = currentEntity, let gameLoop = gameLoop else { return false }

        // Try to get building component by checking specific types
        let buildingEntity: BuildingComponent?
        if let miner = gameLoop.world.get(MinerComponent.self, for: entity) {
            buildingEntity = miner
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            buildingEntity = furnace
        } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            buildingEntity = assembler
        } else if let generator = gameLoop.world.get(GeneratorComponent.self, for: entity) {
            buildingEntity = generator
        } else if let lab = gameLoop.world.get(LabComponent.self, for: entity) {
            buildingEntity = lab
        } else if let rocketSilo = gameLoop.world.get(RocketSiloComponent.self, for: entity) {
            buildingEntity = rocketSilo
        } else {
            return false
        }

        guard let inventory = gameLoop.world.get(InventoryComponent.self, for: entity),
              let buildingDef = gameLoop.buildingRegistry.get(buildingEntity!.buildingId) else {
            return false
        }

        // Check fuel slots
        for (index, slot) in fuelSlots.enumerated() {
            if slot.handleTap(at: position) {
                let inventoryIndex = index  // Fuel slots are first in inventory
                if inventoryIndex < inventory.slots.count,
                   inventory.slots[inventoryIndex] != nil {
                    // Slot has an item - remove it to player inventory
                    handleSlotTap(entity: entity, slotIndex: inventoryIndex, gameLoop: gameLoop)
                } else {
                    // Slot is empty - open inventory for fuel
                    handleEmptySlotTap(entity: entity, slotIndex: inventoryIndex)
                }
                return true
            }
        }

        // Check input slots
        for (index, slot) in inputSlots.enumerated() {
            if slot.handleTap(at: position) {
                let inventoryIndex = buildingDef.fuelSlots + index  // Input slots come after fuel slots
                if inventoryIndex < inventory.slots.count,
                   inventory.slots[inventoryIndex] != nil {
                    // Slot has an item - remove it to player inventory
                    handleSlotTap(entity: entity, slotIndex: inventoryIndex, gameLoop: gameLoop)
                } else {
                    // Slot is empty - open inventory for input
                    handleEmptySlotTap(entity: entity, slotIndex: inventoryIndex)
                }
                return true
            }
        }

        // Check output slots
        for (slotIndex, slot) in outputSlots.enumerated() {
            if slot.handleTap(at: position) {
                let inventoryIndex = buildingDef.fuelSlots + buildingDef.inputSlots + slotIndex  // Output slots come after fuel and input slots
                if inventoryIndex < inventory.slots.count,
                   inventory.slots[inventoryIndex] != nil {
                    // Slot has an item - remove it to player inventory
                    handleSlotTap(entity: entity, slotIndex: inventoryIndex, gameLoop: gameLoop)
                } else {
                    // Slot is empty - could potentially open inventory for output, but for now just ignore
                    // Output slots are typically filled by machine production, not manual input
                }
                return true
            }
        }

        // If tap didn't hit any UI elements, close the panel
        onClosePanel?()
        return true // Consume the tap to prevent other interactions
    }

    override func handleDrag(from startPos: Vector2, to endPos: Vector2) -> Bool {
        // Check if dragging to an empty input or output slot
        guard let _ = gameLoop, let _ = currentEntity else { return false }

        // Check fuel slots
        for (_, slot) in fuelSlots.enumerated() {
            if slot.frame.contains(endPos) && slot.item == nil {
                // Dropped on empty fuel slot - this would require drag state from inventory
                // For now, just return true to indicate drag was handled
                return true
            }
        }

        // Check input slots
        for (_, slot) in inputSlots.enumerated() {
            if slot.frame.contains(endPos) && slot.item == nil {
                // Dropped on empty input slot - this would require drag state from inventory
                // For now, just return true to indicate drag was handled
                return true
            }
        }

        // Check output slots
        for (_, slot) in outputSlots.enumerated() {
            if slot.frame.contains(endPos) && slot.item == nil {
                // Dropped on empty output slot - this would require drag state from inventory
                return true
            }
        }

        return false
    }

    private func renderProgressBar(renderer: MetalRenderer) {
        guard let entity = currentEntity, let gameLoop = gameLoop else { return }

        // Get progress from the appropriate component
        var progress: Float = 0
        var isGenerator = false
        var powerAvailability: Float = 1.0

        if let miner = gameLoop.world.get(MinerComponent.self, for: entity) {
            progress = miner.progress
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            progress = furnace.smeltingProgress
        } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            progress = assembler.craftingProgress
        } else if let pumpjack = gameLoop.world.get(PumpjackComponent.self, for: entity) {
            progress = pumpjack.progress
        } else if gameLoop.world.has(GeneratorComponent.self, for: entity) {
            // For generators, show power availability bar instead of progress
            isGenerator = true
            if let networkInfo = gameLoop.powerSystem.getNetworkInfo(for: entity) {
                powerAvailability = networkInfo.powerAvailability
            }
        } else {
            // No progress or power info to show
            return
        }

        // Position the progress/power bar above the slots
        let barWidth: Float = 300 * UIScale
        let barHeight: Float = 20 * UIScale
        let barX = frame.center.x - barWidth/2
        let barY = frame.center.y - 60 * UIScale

        let barRect = Rect(center: Vector2(frame.center.x, barY), size: Vector2(barWidth, barHeight))

        // Background (gray)
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: barRect.center,
            size: barRect.size,
            textureRect: solidRect,
            color: Color(r: 0.3, g: 0.3, b: 0.3, a: 1.0),
            layer: .ui
        ))

        // Progress/Power fill
        if isGenerator {
            // Power availability bar (blue with white border)
            let powerWidth = barWidth * powerAvailability

            // White border showing full capacity (always full width)
            let borderThickness: Float = 1.5 * UIScale
            let borderRect = Rect(
                center: barRect.center,
                size: Vector2(barWidth + borderThickness, barHeight + borderThickness)
            )
            renderer.queueSprite(SpriteInstance(
                position: borderRect.center,
                size: borderRect.size,
                textureRect: solidRect,
                color: Color(r: 1.0, g: 1.0, b: 1.0, a: 1.0), // White border
                layer: .ui
            ))

            // Blue fill showing available power
            if powerWidth > 0 {
                let powerRect = Rect(
                    center: Vector2(barX + powerWidth/2, barY),
                    size: Vector2(powerWidth, barHeight)
                )
                renderer.queueSprite(SpriteInstance(
                    position: powerRect.center,
                    size: powerRect.size,
                    textureRect: solidRect,
                    color: Color(r: 0.2, g: 0.4, b: 0.9, a: 1.0), // Blue for power availability
                    layer: .ui
                ))
            }
        } else {
            // Progress fill (green) for other machines
            if progress > 0 {
                let progressWidth = barWidth * progress
                let progressRect = Rect(
                    center: Vector2(barX + progressWidth/2, barY),
                    size: Vector2(progressWidth, barHeight)
                )
                renderer.queueSprite(SpriteInstance(
                    position: progressRect.center,
                    size: progressRect.size,
                    textureRect: solidRect,
                    color: Color(r: 0.2, g: 0.8, b: 0.2, a: 1.0),
                    layer: .ui
                ))
            }
        }
    }
}
