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

    // Callbacks for managing UIKit labels
    var onAddLabels: (([UILabel]) -> Void)?
    var onRemoveLabels: (([UILabel]) -> Void)?

    var onOpenInventoryForMachine: ((Entity, Int) -> Void)?
    var onOpenResearchMenu: (() -> Void)?

    // Helper to check if current machine is a lab
    private var isLab: Bool {
        guard let entity = currentEntity, let gameLoop = gameLoop else { return false }
        return gameLoop.world.has(LabComponent.self, for: entity)
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
            let slotX = frame.minX + 50 * UIScale
            let slotY = frame.minY + 80 * UIScale + Float(i) * (slotSize + slotSpacing)
            inputSlots.append(InventorySlot(
                frame: Rect(center: Vector2(slotX, slotY), size: Vector2(slotSize, slotSize)),
                index: i
            ))
        }

        // Output slots (right side)
        for i in 0..<4 {
            let slotX = frame.maxX - 50 * UIScale
            let slotY = frame.minY + 80 * UIScale + Float(i) * (slotSize + slotSpacing)
            outputSlots.append(InventorySlot(
                frame: Rect(center: Vector2(slotX, slotY), size: Vector2(slotSize, slotSize)),
                index: i
            ))
        }

        setupCountLabels()
    }

    private func setupCountLabels() {
        // Remove existing labels from view before clearing arrays
        let oldLabels = inputCountLabels + outputCountLabels + researchProgressLabels
        onRemoveLabels?(oldLabels)

        // Clear existing labels
        inputCountLabels.removeAll()
        outputCountLabels.removeAll()
        researchProgressLabels.removeAll()

        // Create labels for input slots
        for _ in inputSlots {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 8, weight: UIFont.Weight.bold)
            label.textColor = UIColor.white
            label.textAlignment = NSTextAlignment.right
            label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            label.layer.cornerRadius = 1
            label.layer.masksToBounds = true
            label.translatesAutoresizingMaskIntoConstraints = true
            label.text = ""
            label.isHidden = true
            inputCountLabels.append(label)
        }

        // Create labels for output slots
        for _ in outputSlots {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 8, weight: UIFont.Weight.bold)
            label.textColor = UIColor.white
            label.textAlignment = NSTextAlignment.right
            label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            label.layer.cornerRadius = 1
            label.layer.masksToBounds = true
            label.translatesAutoresizingMaskIntoConstraints = true
            label.text = ""
            label.isHidden = true
            outputCountLabels.append(label)
        }

        // Create research progress labels for labs
        for _ in 0..<4 { // Create 4 labels for research progress info
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            label.textColor = UIColor.white
            label.textAlignment = .left
            label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            label.layer.cornerRadius = 3
            label.layer.masksToBounds = true
            label.translatesAutoresizingMaskIntoConstraints = true
            label.text = ""
            label.isHidden = true
            label.numberOfLines = 0
            researchProgressLabels.append(label)
        }
    }

    private func setupSlotsForMachine(_ entity: Entity) {
        guard let gameLoop = gameLoop else { return }

        // Clear existing slots
        inputSlots.removeAll()
        outputSlots.removeAll()

        let slotSize: Float = 40 * UIScale

        // Setup slots based on machine type
        if gameLoop.world.has(LabComponent.self, for: entity) {
            // Labs: 6 input slots for science packs, no output slots
            for i in 0..<6 {
                let slotX = frame.minX + 50 * UIScale + Float(i % 3) * (slotSize + 5 * UIScale)
                let slotY = frame.minY + 80 * UIScale + Float(i / 3) * (slotSize + 5 * UIScale)
                inputSlots.append(InventorySlot(
                    frame: Rect(center: Vector2(slotX, slotY), size: Vector2(slotSize, slotSize)),
                    index: i
                ))
            }
            // Labs have no output slots
        } else if gameLoop.world.has(MinerComponent.self, for: entity) {
            // Mining drills: 1 centered output slot
            let slotX = frame.center.x
            let slotY = frame.minY + 80 * UIScale + slotSize / 2
            outputSlots.append(InventorySlot(
                frame: Rect(center: Vector2(slotX, slotY), size: Vector2(slotSize, slotSize)),
                index: 0
            ))
        } else if gameLoop.world.has(GeneratorComponent.self, for: entity) {
            // Generators (boilers): 1 centered fuel input slot
            let slotX = frame.center.x
            let slotY = frame.minY + 80 * UIScale + slotSize / 2
            inputSlots.append(InventorySlot(
                frame: Rect(center: Vector2(slotX, slotY), size: Vector2(slotSize, slotSize)),
                index: 0
            ))
        } else if gameLoop.world.has(FurnaceComponent.self, for: entity) {
            // Furnaces: 2 input slots (left) and 2 output slots (right)
            let slotSpacing: Float = 5 * UIScale

            // Input slots (left side) - slots 0 and 1
            for i in 0..<2 {
                let slotX = frame.minX + 50 * UIScale
                let slotY = frame.minY + 80 * UIScale + Float(i) * (slotSize + slotSpacing)
                inputSlots.append(InventorySlot(
                    frame: Rect(center: Vector2(slotX, slotY), size: Vector2(slotSize, slotSize)),
                    index: i
                ))
            }

            // Output slots (right side) - slots 2 and 3
            for i in 0..<2 {
                let slotX = frame.maxX - 50 * UIScale
                let slotY = frame.minY + 80 * UIScale + Float(i) * (slotSize + slotSpacing)
                outputSlots.append(InventorySlot(
                    frame: Rect(center: Vector2(slotX, slotY), size: Vector2(slotSize, slotSize)),
                    index: i + 2  // Output slots start at index 2
                ))
            }
        } else {
            // Default setup for other machines (assemblers)
            let slotSpacing: Float = 5 * UIScale

            // Input slots (left side)
            for i in 0..<4 {
                let slotX = frame.minX + 50 * UIScale
                let slotY = frame.minY + 80 * UIScale + Float(i) * (slotSize + slotSpacing)
                inputSlots.append(InventorySlot(
                    frame: Rect(center: Vector2(slotX, slotY), size: Vector2(slotSize, slotSize)),
                    index: i
                ))
            }

            // Output slots (right side) - slots 4, 5, 6, 7
            for i in 0..<4 {
                let slotX = frame.maxX - 50 * UIScale
                let slotY = frame.minY + 80 * UIScale + Float(i) * (slotSize + slotSpacing)
                outputSlots.append(InventorySlot(
                    frame: Rect(center: Vector2(slotX, slotY), size: Vector2(slotSize, slotSize)),
                    index: i + 4  // Output slots start at index 4
                ))
            }
        }

        // Setup count labels for the new slots
        setupCountLabels()
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
        } else {
            print("MachineUI: Machine type not recognized")
            availableRecipes = []
        }
        
        let buttonSize: Float = 40 * UIScale
        let buttonSpacing: Float = 5 * UIScale
        let buttonsPerRow = 8  // Increased from 5 to fit more buttons with wider panel
        let startX = frame.center.x - Float(buttonsPerRow) * (buttonSize + buttonSpacing) / 2
        // Position recipe buttons immediately below the progress bar (status bar area)
        // Progress bar is at frame.center.y - 30 * UIScale, height is 20 * UIScale
        // So progress bar bottom is at frame.center.y - 20 * UIScale
        // Start buttons with a small spacing below the progress bar
        let progressBarBottom = frame.center.y - 20 * UIScale
        let spacingBelowProgressBar: Float = 10 * UIScale
        let startY = progressBarBottom + spacingBelowProgressBar + buttonSize / 2
        
        print("MachineUI: Found \(availableRecipes.count) available recipes")
        for (index, recipe) in availableRecipes.enumerated() {
            let row = index / buttonsPerRow
            let col = index % buttonsPerRow

            let buttonX = startX + Float(col) * (buttonSize + buttonSpacing) + buttonSize / 2
            let buttonY = startY + Float(row) * (buttonSize + buttonSpacing)

            let button = RecipeButton(
                frame: Rect(center: Vector2(buttonX, buttonY), size: Vector2(buttonSize, buttonSize)),
                recipe: recipe
            )
            button.onTap = { [weak self] in
                print("MachineUI: Recipe button tapped for '\(recipe.name)'")
                self?.selectRecipe(recipe)
            }
            recipeButtons.append(button)
            print("MachineUI: Created recipe button \(index) for '\(recipe.name)' at (\(buttonX), \(buttonY))")
        }
    }
    
    private func selectRecipe(_ recipe: Recipe) {
        guard let entity = currentEntity else {
            print("MachineUI: No current entity for recipe selection")
            return
        }
        print("MachineUI: Setting recipe '\(recipe.name)' (id: \(recipe.id)) for entity")

        // Check what type of machine this is
        if let gameLoop = gameLoop {
            if gameLoop.world.has(AssemblerComponent.self, for: entity) {
                print("MachineUI: Entity has AssemblerComponent")
            } else if gameLoop.world.has(FurnaceComponent.self, for: entity) {
                print("MachineUI: Entity has FurnaceComponent")
            } else if gameLoop.world.has(MinerComponent.self, for: entity) {
                print("MachineUI: Entity has MinerComponent (miners don't use recipes)")
            } else {
                print("MachineUI: Entity has no recognized machine component")
            }
        }

        gameLoop?.setRecipe(for: entity, recipeId: recipe.id)
        AudioManager.shared.playClickSound()

        // Automatically try to fill machine with required items from player inventory
        autoFillMachineWithRecipe(recipe, for: entity)

        // Check if recipe was set
        if let gameLoop = gameLoop {
            if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
                print("MachineUI: After setting - assembler recipe: \(assembler.recipe?.name ?? "nil")")
            } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
                print("MachineUI: After setting - furnace recipe: \(furnace.recipe?.name ?? "nil")")
            }
        }
    }

    private func autoFillMachineWithRecipe(_ recipe: Recipe, for entity: Entity) {
        guard let gameLoop = gameLoop,
              var machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity) else {
            return
        }

        print("MachineUI: Auto-filling machine with recipe inputs: \(recipe.inputs.map { "\($0.itemId) x\($0.count)" }.joined(separator: ", "))")

        // Try to fill input slots with required items from player inventory
        var playerInventory = gameLoop.player.inventory
        var itemsFilled = 0

        for (index, inputItem) in recipe.inputs.enumerated() {
            if index >= machineInventory.slots.count / 2 { break } // Don't exceed input slots

            let machineSlotIndex = index
            if machineInventory.slots[machineSlotIndex] == nil {
                // Slot is empty, try to take the required item from player inventory
                if playerInventory.has(itemId: inputItem.itemId, count: inputItem.count) {
                    // Remove from player inventory
                    let _ = playerInventory.remove(itemId: inputItem.itemId, count: inputItem.count)
                    // Add to machine inventory
                    machineInventory.slots[machineSlotIndex] = ItemStack(itemId: inputItem.itemId, count: inputItem.count)
                    itemsFilled += 1
                    print("MachineUI: Filled slot \(machineSlotIndex) with \(inputItem.itemId) x\(inputItem.count)")
                } else {
                    print("MachineUI: Cannot fill slot \(machineSlotIndex) - player doesn't have \(inputItem.itemId) x\(inputItem.count)")
                }
            } else {
                print("MachineUI: Slot \(machineSlotIndex) already has an item")
            }
        }

        // Save the updated inventories
        gameLoop.player.inventory = playerInventory
        gameLoop.world.add(machineInventory, to: entity)

        if itemsFilled > 0 {
            print("MachineUI: Successfully auto-filled \(itemsFilled) input slots")
        } else {
            print("MachineUI: No items were auto-filled (either slots were occupied or player lacks required items)")
        }
    }
    
    override func update(deltaTime: Float) {
        guard isOpen, let entity = currentEntity, let world = gameLoop?.world else { return }

        // Handle labs differently - show research progress but also update input slots
        if world.has(LabComponent.self, for: entity) {
            updateLabProgress()
            // Continue to update input slots for labs (science packs)
        }

        // Update inventory slots from machine inventory
        if let inventory = world.get(InventoryComponent.self, for: entity) {
            if world.has(MinerComponent.self, for: entity) {
                // Mining drills: all slots are output slots
                for (index, slot) in outputSlots.enumerated() {
                    if index < inventory.slots.count {
                        slot.item = inventory.slots[index]
                        updateCountLabel(for: slot, label: outputCountLabels[index], item: slot.item)
                    }
                }
                // Clear input slots (mining drills don't have inputs)
                for slot in inputSlots {
                    slot.item = nil
                }
            } else if world.has(GeneratorComponent.self, for: entity) {
                // Generators (boilers): single fuel input slot
                for (index, slot) in inputSlots.enumerated() {
                    if index < inventory.slots.count {
                        slot.item = inventory.slots[index]
                        updateCountLabel(for: slot, label: inputCountLabels[index], item: slot.item)
                    }
                }
                // Clear output slots (generators don't have outputs)
                for slot in outputSlots {
                    slot.item = nil
                }
            } else {
                // Default behavior for assemblers/furnaces: split inventory in half
                var hasChanges = false
                var outputSummary = ""
                for (index, slot) in inputSlots.enumerated() {
                    let oldItem = slot.item
                    if slot.index < inventory.slots.count {
                        slot.item = inventory.slots[slot.index]
                    } else {
                        slot.item = nil  // Slot index out of bounds
                    }
                    if oldItem?.itemId != slot.item?.itemId || oldItem?.count != slot.item?.count {
                        hasChanges = true
                    }
                    updateCountLabel(for: slot, label: inputCountLabels[index], item: slot.item)
                }
                for (index, slot) in outputSlots.enumerated() {
                    let oldItem = slot.item
                    if slot.index < inventory.slots.count {
                        slot.item = inventory.slots[slot.index]
                    } else {
                        slot.item = nil  // Slot index out of bounds
                    }
                    if oldItem?.itemId != slot.item?.itemId || oldItem?.count != slot.item?.count {
                        hasChanges = true
                    }
                    if slot.item != nil {
                        outputSummary += "\(slot.item!.itemId) x\(slot.item!.count) "
                    }
                    updateCountLabel(for: slot, label: outputCountLabels[index], item: slot.item)
                }
                if hasChanges && !outputSummary.isEmpty {
                    print("MachineUI: 📦 Outputs: \(outputSummary.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
    }

    private func updateCountLabel(for slot: InventorySlot, label: UILabel, item: ItemStack?) {
        // Label position: bottom-right corner of slot
        let labelWidth: Float = 16
        let labelHeight: Float = 12
        let labelX = slot.frame.maxX - labelWidth
        let labelY = slot.frame.maxY - labelHeight

        // Convert to UIView coordinates
        let scale = UIScreen.main.scale
        let uiX = CGFloat(labelX) / scale
        let uiY = CGFloat(labelY) / scale

        label.frame = CGRect(x: uiX, y: uiY, width: CGFloat(labelWidth), height: CGFloat(labelHeight))

        // Show label only if item count > 1
        if let item = item, item.count > 1 {
            label.text = "\(item.count)"
            label.isHidden = false
        } else {
            label.text = ""
            label.isHidden = true
        }
    }
    
    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Check if this is a lab
        if let entity = currentEntity, let gameLoop = gameLoop, gameLoop.world.has(LabComponent.self, for: entity) {
            // Render lab research progress
            renderLabProgress(renderer: renderer)

            // Also render input slots for science packs
            for slot in inputSlots {
                slot.render(renderer: renderer)
            }
        } else {
            // Render normal machine UI
            // Render slots
            for slot in inputSlots {
                slot.render(renderer: renderer)
            }
            for slot in outputSlots {
                slot.render(renderer: renderer)
            }

            // Render progress bar
            renderProgressBar(renderer: renderer)

            // Render recipe buttons
            for button in recipeButtons {
                button.render(renderer: renderer)
            }
        }
    }
    
    private func renderLabProgress(renderer: MetalRenderer) {
        guard let gameLoop = gameLoop,
              let progressDetails = gameLoop.researchSystem.getResearchProgressDetails() else {
            // No active research
            renderLabStatus("No Active Research", renderer: renderer)
            return
        }

        let centerX = frame.center.x
        let startY = frame.center.y - 60 * UIScale
        let lineHeight: Float = 25 * UIScale

        // Title
        renderLabText("Research Progress", at: Vector2(centerX, startY), renderer: renderer)

        // Technology name
        renderLabText("Technology: \(progressDetails.technologyName)",
                     at: Vector2(centerX, startY + lineHeight), renderer: renderer)

        // Overall progress
        let percent = Int(progressDetails.overallProgress * 100)
        renderLabText("Progress: \(percent)%",
                     at: Vector2(centerX, startY + lineHeight * 2), renderer: renderer)

        // Science pack details
        var yOffset = lineHeight * 3
        for (packId, packProgress) in progressDetails.packProgress {
            let packName = packId.replacingOccurrences(of: "-", with: " ").capitalized
            renderLabText("\(packName): \(packProgress.contributed)/\(packProgress.required)",
                         at: Vector2(centerX, startY + yOffset), renderer: renderer)
            yOffset += lineHeight
        }

        // Research speed bonus
        if progressDetails.researchSpeedBonus > 0 {
            renderLabText("Speed Bonus: +\(Int(progressDetails.researchSpeedBonus * 100))%",
                         at: Vector2(centerX, startY + yOffset), renderer: renderer)
        }
    }

    private func renderLabText(_ text: String, at position: Vector2, renderer: MetalRenderer) {
        // This will be handled by the UIKit labels we set up earlier
        // The actual text rendering is done in update() method
    }

    private func renderLabStatus(_ status: String, renderer: MetalRenderer) {
        let centerX = frame.center.x
        let centerY = frame.center.y
        renderLabText(status, at: Vector2(centerX, centerY), renderer: renderer)
    }

    private func updateLabProgress() {
        guard let gameLoop = gameLoop else { return }

        if let progressDetails = gameLoop.researchSystem.getResearchProgressDetails() {
            // Update research progress labels
            if researchProgressLabels.count >= 4 {
                let percent = Int(progressDetails.overallProgress * 100)
                researchProgressLabels[0].text = "Researching: \(progressDetails.technologyName)"
                researchProgressLabels[1].text = "Progress: \(percent)%"
                researchProgressLabels[2].text = ""

                // Show science pack progress
                var packText = ""
                for (packId, packProgress) in progressDetails.packProgress {
                    let packName = packId.replacingOccurrences(of: "-", with: " ").capitalized
                    packText += "\(packName): \(packProgress.contributed)/\(packProgress.required)\n"
                }
                researchProgressLabels[2].text = packText.trimmingCharacters(in: .whitespacesAndNewlines)
                researchProgressLabels[2].numberOfLines = 0

                // Show research speed bonus
                if progressDetails.researchSpeedBonus > 0 {
                    researchProgressLabels[3].text = "Speed: +\(Int(progressDetails.researchSpeedBonus * 100))%"
                } else {
                    researchProgressLabels[3].text = ""
                }

                // Position and show labels
                updateLabProgressLabelPositions()
                for label in researchProgressLabels {
                    label.isHidden = false
                }
            }
        } else {
            // No active research - show clickable "Open Research Menu" label
            if researchProgressLabels.count >= 1 {
                researchProgressLabels[0].text = "Open Research Menu"
                researchProgressLabels[0].isHidden = false

                for i in 1..<researchProgressLabels.count {
                    researchProgressLabels[i].text = ""
                    researchProgressLabels[i].isHidden = true
                }

                updateLabProgressLabelPositions()
            }
        }
    }

    private func updateLabProgressLabelPositions() {
        let screenScale = CGFloat(UIScreen.main.scale)

        for (index, label) in researchProgressLabels.enumerated() {
            if !label.isHidden {
                // For the "Open Research Menu" text (index 0 when no research), center it in the panel
                if index == 0 && label.text == "Open Research Menu" {
                    // Center both horizontally and vertically in the entire panel
                    let uiX = CGFloat(frame.center.x) / screenScale - 150  // Center horizontally
                    let uiY = CGFloat(frame.center.y) / screenScale - 20  // Center vertically

                    label.frame = CGRect(
                        x: uiX,
                        y: uiY,
                        width: 300,
                        height: 40
                    )
                } else {
                    // Normal positioning for other labels (research progress, etc.)
                    let centerX = frame.center.x
                    let startY = frame.center.y - 60 * UIScale
                    let lineHeight: Float = 25 * UIScale
                    let y = startY + Float(index) * lineHeight
                    let uiX = CGFloat(centerX) / screenScale - 150 // Center horizontally
                    let uiY = CGFloat(y) / screenScale - 10 // Slight offset

                    label.frame = CGRect(
                        x: uiX,
                        y: uiY,
                        width: 300, // Fixed width
                        height: 40  // Allow for multiple lines
                    )
                }
            }
        }
    }

    private func renderProgressBar(renderer: MetalRenderer) {
        guard let entity = currentEntity, let world = gameLoop?.world else { return }
        
        let progressBarWidth: Float = 150 * UIScale
        let progressBarHeight: Float = 20 * UIScale
        let progressOffset: Float = 30 * UIScale
        let progressCenter = frame.center
        
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        
        // Background
        renderer.queueSprite(SpriteInstance(
            position: Vector2(progressCenter.x, progressCenter.y - progressOffset),
            size: Vector2(progressBarWidth, progressBarHeight),
            textureRect: solidRect,
            color: Color(r: 0.15, g: 0.15, b: 0.2, a: 1),
            layer: .ui
        ))
        
        // Get progress
        var progress: Float = 0
        
        if let assembler = world.get(AssemblerComponent.self, for: entity) {
            progress = assembler.craftingProgress
        } else if let furnace = world.get(FurnaceComponent.self, for: entity) {
            progress = furnace.smeltingProgress
        }
        
        // Fill
        if progress > 0 {
            let fillWidth = progressBarWidth * progress
            renderer.queueSprite(SpriteInstance(
                position: Vector2(progressCenter.x - progressBarWidth / 2 + fillWidth / 2, progressCenter.y - progressOffset),
                size: Vector2(fillWidth, progressBarHeight - 4 * UIScale),
                textureRect: solidRect,
                color: Color(r: 0.3, g: 0.6, b: 0.3, a: 1),
                layer: .ui
            ))
        }
    }
    
    override func handleTap(at position: Vector2) -> Bool {
        guard isOpen else { return false }

        // Check recipe buttons first
        for (index, button) in recipeButtons.enumerated() {
            if button.handleTap(at: position) {
                print("MachineUI: Recipe button \(index) tapped for recipe '\(button.recipe.name)'")
                return true
            }
        }

        // Check input slots - allow transferring items from player inventory
        for slot in inputSlots {
            if slot.handleTap(at: position) {
                handleSlotTap(slot: slot, isInput: true)
                return true
            }
        }

        // Check output slots - allow taking items
        for slot in outputSlots {
            if slot.handleTap(at: position) {
                handleSlotTap(slot: slot, isInput: false)
                return true
            }
        }

        // Check for research menu label tap (when no active research)
        if isLab && researchProgressLabels.count > 0 && !researchProgressLabels[0].isHidden &&
           researchProgressLabels[0].text == "Open Research Menu" {
            let screenScale = Float(UIScreen.main.scale)

            // Label is now centered in the entire panel
            let labelCenterX = frame.center.x
            let labelCenterY = frame.center.y

            // Label size in Metal coordinates
            let labelWidth: Float = 300 * screenScale  // Convert UIKit pixels to Metal units
            let labelHeight: Float = 40 * screenScale

            let labelRect = Rect(
                center: Vector2(labelCenterX, labelCenterY),
                size: Vector2(labelWidth, labelHeight)
            )

            if labelRect.contains(position) {
                print("MachineUI: Tapped on 'Open Research Menu' label, calling callback")
                onOpenResearchMenu?()
                return true
            }
        }

        // If tap is within panel bounds but not handled by interactive elements, still consume it
        return frame.contains(position)
    }

    override func handleDrag(from startPos: Vector2, to endPos: Vector2) -> Bool {
        guard isOpen, let entity = currentEntity, let gameLoop = gameLoop else { return false }

        // If drag starts anywhere within the panel, consume it to prevent game world interactions
        let dragStartedInPanel = frame.contains(startPos)
        
        // Check if drag started from an input slot
        for (index, slot) in inputSlots.enumerated() {
            if slot.frame.contains(startPos) {
                // Started dragging from input slot - clear it
                guard var machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity) else { 
                    // Still consume the drag even if inventory check fails
                    return dragStartedInPanel
                }

                let inputSlotIndex = index
                if inputSlotIndex < machineInventory.slots.count,
                   let item = machineInventory.slots[inputSlotIndex] {
                    // Return items to player inventory if possible
                    var playerInv = gameLoop.player.inventory
                    let remaining = playerInv.add(item)
                    gameLoop.player.inventory = playerInv

                    // Clear the machine slot
                    machineInventory.slots[inputSlotIndex] = nil
                    gameLoop.world.add(machineInventory, to: entity)

                    // If couldn't return all items to player, they stay in machine (shouldn't happen in practice)
                    if remaining > 0 {
                        print("Warning: Could not return \(remaining) items to player inventory")
                    }

                    return true
                }
            }
        }

        // Check if drag started from an output slot (though output slots are typically not draggable)
        for slot in outputSlots {
            if slot.frame.contains(startPos) {
                // For now, don't allow dragging from output slots
                // But still consume the drag to prevent game world interactions
                return true
            }
        }

        // If drag started in panel but not on a specific slot, still consume it
        return dragStartedInPanel
    }
    
    private func handleSlotTap(slot: InventorySlot, isInput: Bool) {
        guard let entity = currentEntity,
              let gameLoop = gameLoop else { return }

        if isInput {
            // Input slot - open inventory UI to let player choose what to add or replace
            // For generators, the slot index maps directly to inventory slot
            let inventorySlotIndex: Int
            if gameLoop.world.has(GeneratorComponent.self, for: entity) {
                inventorySlotIndex = slot.index  // Generators: direct mapping
            } else {
                inventorySlotIndex = slot.index  // Other machines: also direct for input slots
            }
            onOpenInventoryForMachine?(entity, inventorySlotIndex)
            return
        } else {
            // Output slot - try to take item to player inventory
            guard var machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity) else { return }

    // Get the actual item from the inventory slot (not from slot.item which might be stale)
    let outputSlotIndex = slot.index
            guard outputSlotIndex < machineInventory.slots.count,
                  let item = machineInventory.slots[outputSlotIndex] else { return }
            
            // Check if player can accept the item
            if gameLoop.player.inventory.canAccept(itemId: item.itemId) {
                var playerInv = gameLoop.player.inventory
                let remaining = playerInv.add(item)
                gameLoop.player.inventory = playerInv
                
                // Remove from machine inventory slot
                // remaining = number of items that couldn't be added to player
                // amountToRemove = number of items successfully added to player
                let amountToRemove = item.count - remaining
                if amountToRemove >= item.count {
                    // All items were added - remove entire stack
                    machineInventory.slots[outputSlotIndex] = nil
                } else if amountToRemove > 0 {
                    // Some items were added - reduce stack count
                    var updatedItem = item
                    updatedItem.count -= amountToRemove
                    machineInventory.slots[outputSlotIndex] = updatedItem
                }
                // If amountToRemove == 0, player inventory is full, don't remove anything
                
                gameLoop.world.add(machineInventory, to: entity)
            }
        }
    }
}

