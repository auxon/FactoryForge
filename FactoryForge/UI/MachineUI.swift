import Foundation
import UIKit

/// UI for interacting with machines (assemblers, furnaces, etc.)
final class MachineUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var currentEntity: Entity?
    private var recipeButtons: [RecipeButton] = []
    private var inputSlots: [InventorySlot] = []
    private var outputSlots: [InventorySlot] = []

    // Count labels for input and output slots
    private var inputCountLabels: [UILabel] = []
    private var outputCountLabels: [UILabel] = []

    // Research progress labels for labs
    private var researchProgressLabels: [UILabel] = []

    // Rocket launch button for rocket silos
    private var launchButton: UIButton?

    // Callbacks for managing UIKit labels
    var onAddLabels: (([UILabel]) -> Void)?
    var onRemoveLabels: (([UILabel]) -> Void)?

    var onOpenInventoryForMachine: ((Entity, Int) -> Void)?
    var onOpenResearchMenu: (() -> Void)?
    var onLaunchRocket: ((Entity) -> Void)?
    var onClosePanel: (() -> Void)?

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
    }

    private func setupSlots() {
        let slotSize: Float = 40 * UIScale
        let slotSpacing: Float = 5 * UIScale

        // Input slots (left side)
        for i in 0..<4 {
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

        // Output slots (right side)
        for i in 0..<4 {
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
        setupSlotsForMachine(entity)
        refreshRecipeButtons()
    }

    override func open() {
        super.open()
        // Add appropriate labels to the view
        var allLabels = inputCountLabels + outputCountLabels
        if isLab {
            allLabels += researchProgressLabels
        }
        onAddLabels?(allLabels)

        // Add rocket launch button for rocket silos
        if isRocketSilo {
            setupRocketLaunchButton()
        }
    }

    override func close() {
        // Remove all count labels from the view
        let allLabels = inputCountLabels + outputCountLabels + researchProgressLabels
        onRemoveLabels?(allLabels)

        // Clear label text to ensure they're properly reset
        for label in allLabels {
            label.text = ""
            label.isHidden = true
        }

        // Remove rocket launch button
        launchButton = nil

        super.close()
    }

    private func refreshRecipeButtons() {
        recipeButtons.removeAll()

        guard let entity = currentEntity,
              let gameLoop = gameLoop else { return }

        // Get available recipes for this machine type
        var availableRecipes: [Recipe] = []

        if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            print("MachineUI: Machine is assembler with category: \(assembler.craftingCategory)")
            availableRecipes = gameLoop.recipeRegistry.recipes(in: CraftingCategory(rawValue: assembler.craftingCategory) ?? .crafting)
            print("MachineUI: Found \(availableRecipes.count) crafting recipes for assembler")
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

        let buttonSize: Float = 40 * UIScale
        let buttonSpacing: Float = 5 * UIScale
        let buttonsPerRow = 8  // Increased from 5 to fit more buttons with wider panel
        let startX = frame.center.x - (Float(buttonsPerRow - 1) * (buttonSize + buttonSpacing) + buttonSize) / 2
        // Position recipe buttons immediately below the progress bar (status bar area)
        // Progress bar is at frame.center.y - 30 * UIScale, height is 20 * UIScale
        // So progress bar bottom is at frame.center.y - 20 * UIScale
        // Start buttons with a small spacing below the progress bar
        let startY = frame.center.y - 10 * UIScale + buttonSize/2

        for (index, recipe) in availableRecipes.enumerated() {
            let row = index / buttonsPerRow
            let col = index % buttonsPerRow

            let x = startX + Float(col) * (buttonSize + buttonSpacing) + buttonSize 
            let y = startY + Float(row) * (buttonSize + buttonSpacing)

            let buttonFrame = Rect(center: Vector2(x, y), size: Vector2(buttonSize, buttonSize))
            let button = RecipeButton(frame: buttonFrame, recipe: recipe)
            recipeButtons.append(button)
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

        // Get machine inventory
        if let inventory = gameLoop.world.get(InventoryComponent.self, for: entity) {
            // Set up input slots
            for i in 0..<min(inputSlots.count, inventory.slots.count) {
                if let item = inventory.slots[i] {
                    inputSlots[i].item = item
                } else {
                    inputSlots[i].item = nil
                }
            }

            // Set up output slots (typically the last slots are outputs)
            let outputStartIndex = max(0, inventory.slots.count - outputSlots.count)
            for i in 0..<min(outputSlots.count, inventory.slots.count - outputStartIndex) {
                let inventoryIndex = outputStartIndex + i
                if let item = inventory.slots[inventoryIndex] {
                    outputSlots[i].item = item
                } else {
                    outputSlots[i].item = nil
                }
            }
        }

        // Update count labels
        updateCountLabels(entity)
    }

    private func updateCountLabels(_ entity: Entity) {
        guard let gameLoop = gameLoop,
              let inventory = gameLoop.world.get(InventoryComponent.self, for: entity) else { return }

        // Update input slot labels
        for i in 0..<min(inputSlots.count, inventory.slots.count) {
            if let item = inventory.slots[i] {
                inputCountLabels[i].text = "\(item.count)"
                inputCountLabels[i].isHidden = false
            } else {
                inputCountLabels[i].text = "0"
                inputCountLabels[i].isHidden = true
            }
        }

        // Update output slot labels
        let outputStartIndex = max(0, inventory.slots.count - outputSlots.count)
        for i in 0..<min(outputSlots.count, inventory.slots.count - outputStartIndex) {
            let inventoryIndex = outputStartIndex + i
            if let item = inventory.slots[inventoryIndex] {
                outputCountLabels[i].text = "\(item.count)"
                outputCountLabels[i].isHidden = false
            } else {
                outputCountLabels[i].text = "0"
                outputCountLabels[i].isHidden = true
            }
        }
    }

    func updateMachine(_ entity: Entity) {
        setupSlotsForMachine(entity)
        updateCountLabels(entity)
    }

    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Render input slots
        for slot in inputSlots {
            slot.render(renderer: renderer)
        }

        // Render output slots
        for slot in outputSlots {
            slot.render(renderer: renderer)
        }

        // Render recipe buttons
        for button in recipeButtons {
            button.render(renderer: renderer)
        }

        // Render rocket launch button
        if let button = launchButton {
            button.render(renderer: renderer)
        }
    }

    // MARK: - Rocket Launch UI

    private func setupRocketLaunchButton() {
        guard let gameLoop = gameLoop, let entity = currentEntity else { return }

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
           let inventory = gameLoop.world.get(InventoryComponent.self, for: entity) {

            let canLaunch = !silo.isLaunching && silo.rocketAssembled

            button.isEnabled = canLaunch
            button.label = canLaunch ? "🚀 LAUNCH ROCKET" : (silo.isLaunching ? "⏳ LAUNCHING..." : "⚠️ ASSEMBLE ROCKET")
        } else {
            button.isEnabled = false
            button.label = "❌ ERROR"
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

        // Check input slots
        for (index, slot) in inputSlots.enumerated() {
            if slot.handleTap(at: position) {
                // Handle inventory slot tap
                if let entity = currentEntity {
                    onOpenInventoryForMachine?(entity, index)
                }
                return true
            }
        }

        // Check output slots
        for (slotIndex, slot) in outputSlots.enumerated() {
            if slot.handleTap(at: position) {
                // Handle inventory slot tap
                if let entity = currentEntity {
                    let inventory = gameLoop?.world.get(InventoryComponent.self, for: entity)
                    let outputStartIndex = max(0, inventory?.slots.count ?? 0 - outputSlots.count)
                    let inventoryIndex = outputStartIndex + slotIndex
                    onOpenInventoryForMachine?(entity, inventoryIndex)
                }
                return true
            }
        }

        // If tap didn't hit any UI elements, close the panel
        onClosePanel?()
        return true // Consume the tap to prevent other interactions
    }
}