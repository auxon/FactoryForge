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
                    // Try to consume fuel (modify in place, don't call world.add here)
                    if !consumeFuel(inventory: &inventory, furnace: &furnace) {
                        return  // No fuel available
                    }
                    // Save inventory after fuel consumption (outside consumeFuel to avoid exclusivity violation)
                    world.add(inventory, to: entity)
                }
                furnace.fuelRemaining -= deltaTime
                // furnace component is saved automatically by forEach
            } else {
                // Electric furnace - check power
                if let power = world.get(PowerConsumerComponent.self, for: entity), power.satisfaction <= 0 {
                    return
                }
            }
            
            // Auto-select recipe based on input (only look for actual smeltable ores, not fuel)
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
                // Only start recipe if we have ALL required inputs (not just fuel)
                if canStartRecipe(recipe: recipe, inventory: inventory) {
                    let oreCountBefore = inventory.count(of: recipe.inputs.first?.itemId ?? "")
                    print("CraftingSystem: Furnace at entity \(entity) can start recipe \(recipe.id), has \(oreCountBefore) \(recipe.inputs.first?.itemId ?? "unknown")")
                    for input in recipe.inputs {
                        let countBefore = inventory.count(of: input.itemId)
                        inventory.remove(itemId: input.itemId, count: input.count)
                        let countAfter = inventory.count(of: input.itemId)
                        print("CraftingSystem: Furnace consumed \(input.count) \(input.itemId), count before=\(countBefore), after=\(countAfter)")
                    }
                    let oreCountAfter = inventory.count(of: recipe.inputs.first?.itemId ?? "")
                    print("CraftingSystem: Furnace at entity \(entity) started smelting \(recipe.inputs.first?.itemId ?? "unknown"), ore count before=\(oreCountBefore), after=\(oreCountAfter)")
                    furnace.smeltingProgress = 0.001
                    world.add(inventory, to: entity)
                } else {
                    // Log why we can't start
                    let missingInputs = recipe.inputs.filter { inventory.count(of: $0.itemId) < $0.count }
                    if !missingInputs.isEmpty {
                        print("CraftingSystem: Furnace at entity \(entity) cannot start recipe \(recipe.id), missing: \(missingInputs.map { "\($0.count) \($0.itemId)" }.joined(separator: ", "))")
                    }
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
        // For furnaces, put outputs in the second half of inventory slots
        let isFurnace = world.has(FurnaceComponent.self, for: entity)
        let outputStartIndex = isFurnace ? inventory.slots.count / 2 : 0
        
        for output in recipe.outputs {
            if isFurnace {
                // Try to add to output slots first (second half)
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
                // If output slots are full, fall back to regular add (will use first available slot)
                if !added {
                    let remaining = inventory.add(output)
                    if remaining > 0 {
                        // Couldn't add all items - this shouldn't happen if canStartRecipe checked properly
                        print("Warning: Could not add all output items to furnace inventory")
                    }
                }
            } else {
                // For assemblers, use regular add
                inventory.add(output)
            }
        }
        world.add(inventory, to: entity)
    }
    
    private func autoSelectSmeltingRecipe(inventory: InventoryComponent) -> Recipe? {
        // Check what's in the input slot (only look for actual smeltable ores, not fuel)
        let smeltableItems = ["iron-ore", "copper-ore", "stone", "iron-plate"]
        
        for itemId in smeltableItems {
            if inventory.has(itemId: itemId) {
                // Find the smelting recipe for this item
                if let recipe = recipeRegistry.recipes(in: .smelting).first(where: { recipe in
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

