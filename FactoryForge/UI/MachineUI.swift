import Foundation

// Import ECS components
import struct FactoryForge.MinerComponent

/// UI for interacting with machines (assemblers, furnaces, etc.)
final class MachineUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var currentEntity: Entity?
    private var recipeButtons: [RecipeButton] = []
    private var inputSlots: [InventorySlot] = []
    private var outputSlots: [InventorySlot] = []

    var onOpenInventoryForMachine: ((Entity, Int) -> Void)?
    
    init(screenSize: Vector2, gameLoop: GameLoop?) {
        let panelWidth: Float = 400 * UIScale
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
    }

    private func setupSlotsForMachine(_ entity: Entity) {
        guard let gameLoop = gameLoop else { return }

        // Clear existing slots
        inputSlots.removeAll()
        outputSlots.removeAll()

        let slotSize: Float = 40 * UIScale

        // Setup slots based on machine type
        if gameLoop.world.has(MinerComponent.self, for: entity) {
            // Mining drills: 1 centered output slot
            let slotX = frame.center.x
            let slotY = frame.minY + 80 * UIScale + slotSize / 2
            outputSlots.append(InventorySlot(
                frame: Rect(center: Vector2(slotX, slotY), size: Vector2(slotSize, slotSize)),
                index: 0
            ))
        } else {
            // Default setup for other machines (assemblers, furnaces)
            setupSlots()
        }
    }
    
    func setEntity(_ entity: Entity) {
        currentEntity = entity
        setupSlotsForMachine(entity)
        refreshRecipeButtons()
    }
    
    private func refreshRecipeButtons() {
        recipeButtons.removeAll()
        
        guard let entity = currentEntity,
              let gameLoop = gameLoop else { return }
        
        // Get available recipes for this machine type
        var availableRecipes: [Recipe] = []
        
        if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            availableRecipes = gameLoop.recipeRegistry.recipes(in: CraftingCategory(rawValue: assembler.craftingCategory) ?? .crafting)
        } else if gameLoop.world.has(FurnaceComponent.self, for: entity) {
            availableRecipes = gameLoop.recipeRegistry.recipes(in: .smelting)
        }
        
        let buttonSize: Float = 40 * UIScale
        let buttonSpacing: Float = 5 * UIScale
        let buttonsPerRow = 5
        let startX = frame.center.x - Float(buttonsPerRow) * (buttonSize + buttonSpacing) / 2
        let startY = frame.minY + 250 * UIScale
        
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
                self?.selectRecipe(recipe)
            }
            recipeButtons.append(button)
        }
    }
    
    private func selectRecipe(_ recipe: Recipe) {
        guard let entity = currentEntity else { return }
        gameLoop?.setRecipe(for: entity, recipeId: recipe.id)
        AudioManager.shared.playClickSound()
    }
    
    override func update(deltaTime: Float) {
        guard isOpen, let entity = currentEntity, let world = gameLoop?.world else { return }

        // Update inventory slots from machine inventory
        if let inventory = world.get(InventoryComponent.self, for: entity) {
            if world.has(MinerComponent.self, for: entity) {
                // Mining drills: all slots are output slots
                for (index, slot) in outputSlots.enumerated() {
                    if index < inventory.slots.count {
                        slot.item = inventory.slots[index]
                    }
                }
                // Clear input slots (mining drills don't have inputs)
                for slot in inputSlots {
                    slot.item = nil
                }
            } else {
                // Default behavior for assemblers/furnaces: split inventory in half
                for (index, slot) in inputSlots.enumerated() {
                    if index < inventory.slots.count / 2 {
                        slot.item = inventory.slots[index]
                    }
                }
                for (index, slot) in outputSlots.enumerated() {
                    let inventoryIndex = inventory.slots.count / 2 + index
                    if inventoryIndex < inventory.slots.count {
                        slot.item = inventory.slots[inventoryIndex]
                    }
                }
            }
        }
    }
    
    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }
        
        super.render(renderer: renderer)
        
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
        for button in recipeButtons {
            if button.handleTap(at: position) {
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

        // If tap is within panel bounds but not handled by interactive elements, still consume it
        return frame.contains(position)
    }

    override func handleDrag(from startPos: Vector2, to endPos: Vector2) -> Bool {
        guard isOpen, let entity = currentEntity, let gameLoop = gameLoop else { return false }

        // Check if drag started from an input slot
        for (index, slot) in inputSlots.enumerated() {
            if slot.frame.contains(startPos) {
                // Started dragging from input slot - clear it
                guard var machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity) else { return false }

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
                return false
            }
        }

        return false
    }
    
    private func handleSlotTap(slot: InventorySlot, isInput: Bool) {
        guard let entity = currentEntity,
              let gameLoop = gameLoop else { return }

        if isInput {
            // Input slot - open inventory UI to let player choose what to add or replace
            onOpenInventoryForMachine?(entity, slot.index)
            return
        } else {
            // Output slot - try to take item to player inventory
            guard var machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity) else { return }

            // Get the actual item from the inventory slot (not from slot.item which might be stale)
            let outputSlotIndex = machineInventory.slots.count / 2 + slot.index
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

