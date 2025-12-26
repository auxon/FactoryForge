import Foundation

/// UI for interacting with machines (assemblers, furnaces, etc.)
final class MachineUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var currentEntity: Entity?
    private var recipeButtons: [RecipeButton] = []
    private var inputSlots: [InventorySlot] = []
    private var outputSlots: [InventorySlot] = []
    
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
    
    func setEntity(_ entity: Entity) {
        currentEntity = entity
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
        
        return super.handleTap(at: position)
    }
    
    private func handleSlotTap(slot: InventorySlot, isInput: Bool) {
        guard let entity = currentEntity,
              let gameLoop = gameLoop,
              var machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity) else { return }
        
        if isInput {
            // Input slot - try to add item from player inventory
            let player = gameLoop.player
            
            // Get current recipe (if any)
            var currentRecipe: Recipe?
            if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
                currentRecipe = furnace.recipe
            } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
                currentRecipe = assembler.recipe
            }
            
            // For furnaces, try to add either recipe inputs OR fuel
            // Check what's needed/missing and add accordingly
            if gameLoop.world.has(FurnaceComponent.self, for: entity) {
                // First, check if we need recipe inputs (ore)
                var needsRecipeInput = false
                if let recipe = currentRecipe {
                    // Check if we're missing any recipe inputs
                    for input in recipe.inputs {
                        if machineInventory.count(of: input.itemId) < input.count {
                            needsRecipeInput = true
                            // Try to add this missing input
                            if player.inventory.has(itemId: input.itemId) && machineInventory.canAccept(itemId: input.itemId) {
                                var playerInv = player.inventory
                                playerInv.remove(itemId: input.itemId, count: 1)
                                gameLoop.player.inventory = playerInv
                                
                                let itemStack = ItemStack(itemId: input.itemId, count: 1)
                                let remaining = machineInventory.add(itemStack)
                                gameLoop.world.add(machineInventory, to: entity)
                                
                                if remaining > 0 {
                                    gameLoop.player.inventory.add(itemId: input.itemId, count: remaining)
                                }
                                return
                            }
                        }
                    }
                } else {
                    // No recipe set - try any smelting recipe inputs (ore) if we don't have any
                    let smeltingRecipes = gameLoop.recipeRegistry.recipes(in: .smelting)
                    var hasOre = false
                    for recipe in smeltingRecipes {
                        for input in recipe.inputs {
                            if machineInventory.has(itemId: input.itemId) {
                                hasOre = true
                                break
                            }
                        }
                        if hasOre { break }
                    }
                    
                    if !hasOre {
                        // We don't have ore yet, try to add it
                        for recipe in smeltingRecipes {
                            for input in recipe.inputs {
                                if player.inventory.has(itemId: input.itemId) && machineInventory.canAccept(itemId: input.itemId) {
                                    var playerInv = player.inventory
                                    playerInv.remove(itemId: input.itemId, count: 1)
                                    gameLoop.player.inventory = playerInv
                                    
                                    let itemStack = ItemStack(itemId: input.itemId, count: 1)
                                    let remaining = machineInventory.add(itemStack)
                                    gameLoop.world.add(machineInventory, to: entity)
                                    
                                    if remaining > 0 {
                                        gameLoop.player.inventory.add(itemId: input.itemId, count: remaining)
                                    }
                                    return
                                }
                            }
                        }
                    }
                }
                
                // If we don't need recipe inputs (or already have them), try to add fuel
                if !needsRecipeInput {
                    let fuelItems = ["coal", "wood", "solid-fuel"]
                    for fuelId in fuelItems {
                        if player.inventory.has(itemId: fuelId) && machineInventory.canAccept(itemId: fuelId) {
                            var playerInv = player.inventory
                            playerInv.remove(itemId: fuelId, count: 1)
                            gameLoop.player.inventory = playerInv
                            
                            let itemStack = ItemStack(itemId: fuelId, count: 1)
                            let remaining = machineInventory.add(itemStack)
                            gameLoop.world.add(machineInventory, to: entity)
                            
                            if remaining > 0 {
                                gameLoop.player.inventory.add(itemId: fuelId, count: remaining)
                            }
                            return
                        }
                    }
                }
            } else {
                // For assemblers (non-furnaces), just add recipe inputs
                if let recipe = currentRecipe {
                    for input in recipe.inputs {
                        if player.inventory.has(itemId: input.itemId) && machineInventory.canAccept(itemId: input.itemId) {
                            var playerInv = player.inventory
                            playerInv.remove(itemId: input.itemId, count: 1)
                            gameLoop.player.inventory = playerInv
                            
                            let itemStack = ItemStack(itemId: input.itemId, count: 1)
                            let remaining = machineInventory.add(itemStack)
                            gameLoop.world.add(machineInventory, to: entity)
                            
                            if remaining > 0 {
                                gameLoop.player.inventory.add(itemId: input.itemId, count: remaining)
                            }
                            return
                        }
                    }
                }
            }
            
            // If we get here, nothing was added
            if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
                currentRecipe = furnace.recipe
            } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
                currentRecipe = assembler.recipe
            }
            
            // If recipe is set, try to add recipe inputs; otherwise try any smelting input
            if let recipe = currentRecipe {
                // Try to add recipe inputs from player inventory
                for input in recipe.inputs {
                    if player.inventory.has(itemId: input.itemId) && machineInventory.canAccept(itemId: input.itemId) {
                        var playerInv = player.inventory
                        playerInv.remove(itemId: input.itemId, count: 1)
                        gameLoop.player.inventory = playerInv
                        
                        let itemStack = ItemStack(itemId: input.itemId, count: 1)
                        let remaining = machineInventory.add(itemStack)
                        gameLoop.world.add(machineInventory, to: entity)
                        
                        // Return any remaining items to player
                        if remaining > 0 {
                            gameLoop.player.inventory.add(itemId: input.itemId, count: remaining)
                        }
                        return
                    }
                }
            } else {
                // No recipe set - try any smelting recipe inputs (for furnaces)
                if gameLoop.world.has(FurnaceComponent.self, for: entity) {
                    let smeltingRecipes = gameLoop.recipeRegistry.recipes(in: .smelting)
                    for recipe in smeltingRecipes {
                        for input in recipe.inputs {
                            if player.inventory.has(itemId: input.itemId) && machineInventory.canAccept(itemId: input.itemId) {
                                var playerInv = player.inventory
                                playerInv.remove(itemId: input.itemId, count: 1)
                                gameLoop.player.inventory = playerInv
                                
                                let itemStack = ItemStack(itemId: input.itemId, count: 1)
                                let remaining = machineInventory.add(itemStack)
                                gameLoop.world.add(machineInventory, to: entity)
                                
                                if remaining > 0 {
                                    gameLoop.player.inventory.add(itemId: input.itemId, count: remaining)
                                }
                                return
                            }
                        }
                    }
                }
            }
        } else {
            // Output slot - try to take item to player inventory
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

