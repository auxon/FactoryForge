import Foundation

/// System that handles crafting in assemblers and furnaces
final class CraftingSystem: System {
    let priority = SystemPriority.production.rawValue
    
    private let world: World
    private let recipeRegistry: RecipeRegistry
    
    init(world: World, recipeRegistry: RecipeRegistry) {
        self.world = world
        self.recipeRegistry = recipeRegistry
    }
    
    func update(deltaTime: Float) {
        // Update assemblers
        updateAssemblers(deltaTime: deltaTime)
        
        // Update furnaces
        updateFurnaces(deltaTime: deltaTime)
    }
    
    private func updateAssemblers(deltaTime: Float) {
        world.forEach(AssemblerComponent.self) { [self] entity, assembler in
            guard let recipe = assembler.recipe else { return }
            guard var inventory = world.get(InventoryComponent.self, for: entity) else { return }
            
            // Check power
            var speedMultiplier: Float = 1.0
            if let power = world.get(PowerConsumerComponent.self, for: entity) {
                speedMultiplier = power.satisfaction
                if speedMultiplier <= 0 { return }
            }
            
            // Check if crafting in progress
            if assembler.craftingProgress > 0 {
                // Continue crafting
                let craftTime = recipe.craftTime / (assembler.craftingSpeed * speedMultiplier)
                assembler.craftingProgress += deltaTime / craftTime
                
                if assembler.craftingProgress >= 1.0 {
                    // Complete crafting
                    completeRecipe(recipe: recipe, inventory: &inventory, entity: entity)
                    assembler.craftingProgress = 0
                }
            } else {
                // Try to start crafting
                if canStartRecipe(recipe: recipe, inventory: inventory) {
                    // Consume inputs
                    for input in recipe.inputs {
                        inventory.remove(itemId: input.itemId, count: input.count)
                    }
                    assembler.craftingProgress = 0.001  // Started
                    world.add(inventory, to: entity)
                }
            }
        }
    }
    
    private func updateFurnaces(deltaTime: Float) {
        world.forEach(FurnaceComponent.self) { [self] entity, furnace in
            guard var inventory = world.get(InventoryComponent.self, for: entity) else { return }
            
            // Handle fuel consumption for non-electric furnaces
            if world.get(PowerConsumerComponent.self, for: entity) == nil {
                // Burner furnace - needs fuel
                if furnace.fuelRemaining <= 0 {
                    // Try to consume fuel
                    if !consumeFuel(inventory: &inventory, furnace: &furnace) {
                        return  // No fuel available
                    }
                }
                furnace.fuelRemaining -= deltaTime
            } else {
                // Electric furnace - check power
                if let power = world.get(PowerConsumerComponent.self, for: entity), power.satisfaction <= 0 {
                    return
                }
            }
            
            // Auto-select recipe based on input
            if furnace.recipe == nil {
                furnace.recipe = autoSelectSmeltingRecipe(inventory: inventory)
            }
            
            guard let recipe = furnace.recipe else { return }
            
            // Check if crafting in progress
            if furnace.smeltingProgress > 0 {
                let smeltTime = recipe.craftTime / furnace.smeltingSpeed
                furnace.smeltingProgress += deltaTime / smeltTime
                
                if furnace.smeltingProgress >= 1.0 {
                    completeRecipe(recipe: recipe, inventory: &inventory, entity: entity)
                    furnace.smeltingProgress = 0
                    furnace.recipe = nil  // Reset to auto-select next
                }
            } else {
                if canStartRecipe(recipe: recipe, inventory: inventory) {
                    for input in recipe.inputs {
                        inventory.remove(itemId: input.itemId, count: input.count)
                    }
                    furnace.smeltingProgress = 0.001
                    world.add(inventory, to: entity)
                }
            }
        }
    }
    
    private func canStartRecipe(recipe: Recipe, inventory: InventoryComponent) -> Bool {
        // Check if we have all inputs
        for input in recipe.inputs {
            if inventory.count(of: input.itemId) < input.count {
                return false
            }
        }
        
        // Check if we have space for outputs
        for output in recipe.outputs {
            if !inventory.canAccept(itemId: output.itemId) {
                return false
            }
        }
        
        return true
    }
    
    private func completeRecipe(recipe: Recipe, inventory: inout InventoryComponent, entity: Entity) {
        for output in recipe.outputs {
            inventory.add(output)
        }
        world.add(inventory, to: entity)
    }
    
    private func autoSelectSmeltingRecipe(inventory: InventoryComponent) -> Recipe? {
        // Check what's in the input slot
        let smeltableItems = ["iron-ore", "copper-ore", "stone", "iron-plate"]
        
        for itemId in smeltableItems {
            if inventory.has(itemId: itemId) {
                // Find the smelting recipe for this item
                return recipeRegistry.recipes(in: .smelting).first { recipe in
                    recipe.inputs.first?.itemId == itemId
                }
            }
        }
        
        return nil
    }
    
    private func consumeFuel(inventory: inout InventoryComponent, furnace: inout FurnaceComponent) -> Bool {
        let fuels: [(String, Float)] = [
            ("coal", 4.0),
            ("wood", 2.0),
            ("solid-fuel", 12.0)
        ]
        
        for (fuelId, fuelValue) in fuels {
            if inventory.has(itemId: fuelId) {
                inventory.remove(itemId: fuelId, count: 1)
                furnace.fuelRemaining = fuelValue
                return true
            }
        }
        
        return false
    }
}

