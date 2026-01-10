import Foundation
import UIKit

/// UI for interacting with machines (assemblers, furnaces, etc.)
final class MachineUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var currentEntity: Entity?
    private var recipeButtons: [RecipeButton] = []
    private var inputSlots: [InventorySlot] = []
    private var outputSlots: [InventorySlot] = []
    private var fuelSlots: [InventorySlot] = []

    // Count labels for input, output and fuel slots
    private var inputCountLabels: [UILabel] = []
    private var outputCountLabels: [UILabel] = []
    private var fuelCountLabels: [UILabel] = []

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
        // Clear existing slots and labels
        inputSlots.removeAll()
        outputSlots.removeAll()
        fuelSlots.removeAll()
        inputCountLabels.removeAll()
        outputCountLabels.removeAll()
        fuelCountLabels.removeAll()

        // Get machine inventory and building definition
        guard let entity = currentEntity,
              let gameLoop = gameLoop,
              let _ = gameLoop.world.get(InventoryComponent.self, for: entity),
              let buildingEntity = gameLoop.world.get(BuildingComponent.self, for: entity),
              let buildingDef = gameLoop.buildingRegistry.get(buildingEntity.buildingId) else {
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
            let slot = InventorySlot(frame: slotFrame, index: i)
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
    }

    override func open() {
        super.open()
        // Add appropriate labels to the view
        var allLabels = inputCountLabels + outputCountLabels + fuelCountLabels
        if isLab {
            allLabels += researchProgressLabels
        }
        onAddLabels?(allLabels)

        // Position the count labels
        positionCountLabels()

        // Add rocket launch button for rocket silos
        if isRocketSilo {
            setupRocketLaunchButton()
        }
    }

    override func close() {
        // Remove all count labels from the view
        let allLabels = inputCountLabels + outputCountLabels + fuelCountLabels + researchProgressLabels
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
        for slot in fuelSlots {
            slot.item = nil
        }

        // Get machine inventory and building definition
        if let inventory = gameLoop.world.get(InventoryComponent.self, for: entity),
           let buildingEntity = gameLoop.world.get(BuildingComponent.self, for: entity),
           let buildingDef = gameLoop.buildingRegistry.get(buildingEntity.buildingId) {

            let totalSlots = inventory.slots.count
            var inventoryIndex = 0

            // Map fuel slots (first in inventory)
            for i in 0..<fuelSlots.count {
                if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                    fuelSlots[i].item = item
                } else {
                    fuelSlots[i].item = nil
                }
                inventoryIndex += 1
            }

            // Map input slots (next in inventory)
            for i in 0..<inputSlots.count {
                if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                    inputSlots[i].item = item
                } else {
                    inputSlots[i].item = nil
                }
                inventoryIndex += 1
            }

            // Map output slots (remaining slots)
            for i in 0..<outputSlots.count {
                if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                    outputSlots[i].item = item
                } else {
                    outputSlots[i].item = nil
                }
                inventoryIndex += 1
            }
        }

        // Update count labels
        updateCountLabels(entity)
    }

    private func updateCountLabels(_ entity: Entity) {
        guard let gameLoop = gameLoop,
              let inventory = gameLoop.world.get(InventoryComponent.self, for: entity),
              let buildingEntity = gameLoop.world.get(BuildingComponent.self, for: entity),
              let buildingDef = gameLoop.buildingRegistry.get(buildingEntity.buildingId) else { return }

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

    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

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

        // Check fuel slots
        for (index, slot) in fuelSlots.enumerated() {
            if slot.handleTap(at: position) {
                if let entity = currentEntity, let gameLoop = gameLoop,
                   let inventory = gameLoop.world.get(InventoryComponent.self, for: entity),
                   let buildingEntity = gameLoop.world.get(BuildingComponent.self, for: entity),
                   let buildingDef = gameLoop.buildingRegistry.get(buildingEntity.buildingId) {
                    let inventoryIndex = index  // Fuel slots are first in inventory
                    if inventoryIndex < inventory.slots.count,
                       inventory.slots[inventoryIndex] != nil {
                        // Slot has an item - remove it to player inventory
                        handleSlotTap(entity: entity, slotIndex: inventoryIndex, gameLoop: gameLoop)
                    } else {
                        // Slot is empty - open inventory for fuel
                        handleEmptySlotTap(entity: entity, slotIndex: inventoryIndex)
                    }
                }
                return true
            }
        }

        // Check input slots
        for (index, slot) in inputSlots.enumerated() {
            if slot.handleTap(at: position) {
                if let entity = currentEntity, let gameLoop = gameLoop,
                   let inventory = gameLoop.world.get(InventoryComponent.self, for: entity),
                   let buildingEntity = gameLoop.world.get(BuildingComponent.self, for: entity),
                   let buildingDef = gameLoop.buildingRegistry.get(buildingEntity.buildingId) {
                    let inventoryIndex = buildingDef.fuelSlots + index  // Input slots come after fuel slots
                    if inventoryIndex < inventory.slots.count,
                       inventory.slots[inventoryIndex] != nil {
                        // Slot has an item - remove it to player inventory
                        handleSlotTap(entity: entity, slotIndex: inventoryIndex, gameLoop: gameLoop)
                    } else {
                        // Slot is empty - open inventory for input
                        handleEmptySlotTap(entity: entity, slotIndex: inventoryIndex)
                    }
                }
                return true
            }
        }

        // Check output slots
        for (slotIndex, slot) in outputSlots.enumerated() {
            if slot.handleTap(at: position) {
                if let entity = currentEntity, let gameLoop = gameLoop,
                   let inventory = gameLoop.world.get(InventoryComponent.self, for: entity),
                   let buildingEntity = gameLoop.world.get(BuildingComponent.self, for: entity),
                   let buildingDef = gameLoop.buildingRegistry.get(buildingEntity.buildingId) {
                    let inventoryIndex = buildingDef.fuelSlots + buildingDef.inputSlots + slotIndex  // Output slots come after fuel and input slots
                    if inventoryIndex < inventory.slots.count,
                       inventory.slots[inventoryIndex] != nil {
                        // Slot has an item - remove it to player inventory
                        handleSlotTap(entity: entity, slotIndex: inventoryIndex, gameLoop: gameLoop)
                    } else {
                        // Slot is empty - could potentially open inventory for output, but for now just ignore
                        // Output slots are typically filled by machine production, not manual input
                    }
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
        guard let gameLoop = gameLoop, let entity = currentEntity else { return false }

        // Check fuel slots
        for (index, slot) in fuelSlots.enumerated() {
            if slot.frame.contains(endPos) && slot.item == nil {
                // Dropped on empty fuel slot - this would require drag state from inventory
                // For now, just return true to indicate drag was handled
                return true
            }
        }

        // Check input slots
        for (index, slot) in inputSlots.enumerated() {
            if slot.frame.contains(endPos) && slot.item == nil {
                // Dropped on empty input slot - this would require drag state from inventory
                // For now, just return true to indicate drag was handled
                return true
            }
        }

        // Check output slots
        for (slotIndex, slot) in outputSlots.enumerated() {
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

        if let miner = gameLoop.world.get(MinerComponent.self, for: entity) {
            progress = miner.progress
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            progress = furnace.smeltingProgress
        } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            progress = assembler.craftingProgress
        } else if let pumpjack = gameLoop.world.get(PumpjackComponent.self, for: entity) {
            progress = pumpjack.progress
        } else {
            // No progress to show
            return
        }

        // Only show progress bar if there's actual progress
        guard progress > 0 else { return }

        // Position the progress bar above the slots
        let barWidth: Float = 300 * UIScale
        let barHeight: Float = 20 * UIScale
        let barX = frame.center.x - barWidth/2
        let barY = frame.center.y - 30 * UIScale

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

        // Progress fill (green)
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
