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
                    completeRecipe(recipe: recipe, inventory: &inventory, entity: entity, world: world)
                    assembler.craftingProgress = 0
                }
            } else {
                // Try to start crafting
                if canStartRecipe(recipe: recipe, inventory: inventory, entity: entity, world: world) {
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
            let isBurnerFurnace = world.get(PowerConsumerComponent.self, for: entity) == nil
            var hasFuel = true

            if isBurnerFurnace {
                // Burner furnace - check current fuel status
                hasFuel = furnace.fuelRemaining > 0

                // If we have an active recipe but no fuel, try to consume fuel
                if furnace.smeltingProgress > 0 && !hasFuel {
                    if consumeFuel(inventory: &inventory, furnace: &furnace) {
                        hasFuel = true
                        // Save inventory after fuel consumption
                        world.add(inventory, to: entity)
                    }
                }

                // Decrement fuel only when actively processing
                if hasFuel && furnace.smeltingProgress > 0 {
                    furnace.fuelRemaining -= deltaTime
                }
                // furnace component is saved automatically by forEach
            } else {
                // Electric furnace - check power
                if let power = world.get(PowerConsumerComponent.self, for: entity), power.satisfaction <= 0 {
                    hasFuel = false
                }
            }
            
            // Auto-select recipe based on input (only look for actual smeltable ores, not fuel)
            if furnace.recipe == nil {
                furnace.recipe = autoSelectSmeltingRecipe(inventory: inventory, recipeRegistry: recipeRegistry)
            }
            
            guard let recipe = furnace.recipe else { return }

            // Check if crafting in progress
            if furnace.smeltingProgress > 0 {
                // Continue in-progress recipes regardless of current fuel status
                let smeltTime = recipe.craftTime / furnace.smeltingSpeed
                furnace.smeltingProgress += deltaTime / smeltTime

                if furnace.smeltingProgress >= 1.0 {
                    // Complete recipe
                    completeRecipe(recipe: recipe, inventory: &inventory, entity: entity, world: world)
                    furnace.smeltingProgress = 0
                    furnace.recipe = nil  // Reset to auto-select next
                }
            } else {
                // Try to start a new recipe
                // For burner furnaces, try to consume fuel if we don't have any
                if isBurnerFurnace && !hasFuel {
                    if consumeFuel(inventory: &inventory, furnace: &furnace) {
                        hasFuel = true
                        // Save inventory after fuel consumption
                        world.add(inventory, to: entity)
                    }
                }

                // Only start new recipes if we have fuel/power
                if hasFuel && canStartRecipe(recipe: recipe, inventory: inventory, entity: entity, world: world) {
                    // Consume inputs
                    for input in recipe.inputs {
                        inventory.remove(itemId: input.itemId, count: input.count)
                    }
                    furnace.smeltingProgress = 0.001
                    world.add(inventory, to: entity)
                }
            }
        }
    }
    
    private func canStartRecipe(recipe: Recipe, inventory: InventoryComponent, entity: Entity? = nil, world: World? = nil) -> Bool {
        // Check if we have all inputs
        for input in recipe.inputs {
            if inventory.count(of: input.itemId) < input.count {
                return false
            }
        }

        // Check if we have space for outputs
        if let entity = entity, let world = world, world.has(FurnaceComponent.self, for: entity) {
            // For furnaces, check space only in output slots (second half)
            let outputStartIndex = inventory.slots.count / 2
            for output in recipe.outputs {
                var hasSpace = false
                for i in outputStartIndex..<inventory.slots.count {
                    if let existing = inventory.slots[i], existing.itemId == output.itemId && existing.count < existing.maxStack {
                        hasSpace = true
                        break
                    } else if inventory.slots[i] == nil {
                        hasSpace = true
                        break
                    }
                }
                if !hasSpace {
                    return false
                }
            }
        } else {
            // For assemblers and other machines, check space anywhere in inventory
            for output in recipe.outputs {
                if !inventory.canAccept(itemId: output.itemId) {
                    return false
                }
            }
        }

        return true
    }
    
    private func completeRecipe(recipe: Recipe, inventory: inout InventoryComponent, entity: Entity, world: World) {
        // For furnaces, put outputs in the second half of inventory slots
        let isFurnace = world.has(FurnaceComponent.self, for: entity)
        let outputStartIndex = isFurnace ? inventory.slots.count / 2 : 0

        for output in recipe.outputs {
            if isFurnace {
                // For furnaces, ONLY add to output slots (second half) - never to input slots
                var added = false
                for i in outputStartIndex..<inventory.slots.count {
                    if let existing = inventory.slots[i], existing.itemId == output.itemId && existing.count < existing.maxStack {
                        // Add to existing stack
                        inventory.slots[i]?.count += output.count
                        added = true
                        break
                    } else if inventory.slots[i] == nil {
                        // Add to empty slot
                        inventory.slots[i] = output
                        added = true
                        break
                    }
                }
                // If output slots are full, allow completion but use fallback (any available slot)
                // This prevents furnaces from getting stuck with in-progress recipes
                if !added {
                    print("Warning: Furnace output slots are full - using fallback placement for recipe \(recipe.id)")
                    // Use regular add as fallback (will place in any available slot, including input slots if needed)
                    let remaining = inventory.add(output)
                    if remaining > 0 {
                        print("Warning: Could not place furnace output - no space anywhere in inventory")
                        // In a real game, this might destroy the item or something
                    }
                }
            } else {
                // For assemblers, use regular add
                inventory.add(output)
            }
        }
        world.add(inventory, to: entity)
    }
    
    private func autoSelectSmeltingRecipe(inventory: InventoryComponent, recipeRegistry: RecipeRegistry) -> Recipe? {
        // Check what's in the input slot (only look for actual smeltable ores, not fuel)
        let smeltableItems = ["iron-ore", "copper-ore", "stone", "iron-plate"]

        for itemId in smeltableItems {
            if inventory.has(itemId: itemId) {
                // Find the smelting recipe for this item
                if let recipe = recipeRegistry.recipes(in: CraftingCategory.smelting).first(where: { recipe in
                    recipe.inputs.first?.itemId == itemId
                }) {
                    // Verify we have ALL required inputs for this recipe (not just one)
                    let hasAllInputs = recipe.inputs.allSatisfy { input in
                        inventory.count(of: input.itemId) >= input.count
                    }
                    if hasAllInputs {
                        print("CraftingSystem: autoSelectSmeltingRecipe selected recipe \(recipe.id) for item \(itemId), has all inputs")
                        return recipe
                    } else {
                        let missing = recipe.inputs.filter { inventory.count(of: $0.itemId) < $0.count }
                        print("CraftingSystem: autoSelectSmeltingRecipe found recipe \(recipe.id) for item \(itemId), but missing inputs: \(missing.map { "\($0.count) \($0.itemId)" }.joined(separator: ", "))")
                    }
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
                // Don't call world.add here - caller will handle saving to avoid exclusivity violations
                return true
            }
        }
        
        return false
    }
}

