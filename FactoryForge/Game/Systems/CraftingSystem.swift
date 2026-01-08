import Foundation
import QuartzCore

/// System that handles crafting in assemblers and furnaces
final class CraftingSystem: System {
    let priority = SystemPriority.production.rawValue

    private let world: World
    private let recipeRegistry: RecipeRegistry
    private let itemRegistry: ItemRegistry

    init(world: World, recipeRegistry: RecipeRegistry, itemRegistry: ItemRegistry) {
        self.world = world
        self.recipeRegistry = recipeRegistry
        self.itemRegistry = itemRegistry
    }
    
    func update(deltaTime: Float) {
        let startTime = CACurrentMediaTime()

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
                    world.add(inventory, to: entity)
                }
            } else {
                // Try to start crafting
                if canStartRecipe(recipe: recipe, inventory: inventory, entity: entity, world: world) {
                    // Consume inputs (from input slots only for machines)
                    consumeInputsFromInputSlots(recipe: recipe, inventory: &inventory, world: world, entity: entity)
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
                    world.add(inventory, to: entity)
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
                    // Consume inputs (from input slots only for machines)
                    consumeInputsFromInputSlots(recipe: recipe, inventory: &inventory, world: world, entity: entity)
                    furnace.smeltingProgress = 0.001
                    world.add(inventory, to: entity)
                }
            }
        }
    }
    
    private func canStartRecipe(recipe: Recipe, inventory: InventoryComponent, entity: Entity? = nil, world: World? = nil) -> Bool {
        // Check if we have all inputs (from input slots only for machines)
        if let entity = entity, let world = world, (world.has(FurnaceComponent.self, for: entity) || world.has(AssemblerComponent.self, for: entity)) {
            // For machines, only count inputs from input slots (first half)
            let inputSlotCount = inventory.slots.count / 2
            for input in recipe.inputs {
                var available = 0
                for i in 0..<inputSlotCount {
                    if let slot = inventory.slots[i], slot.itemId == input.itemId {
                        available += slot.count
                    }
                }
                if available < input.count {
                    return false
                }
            }
        } else {
            // For non-machines, check anywhere in inventory
            for input in recipe.inputs {
                if inventory.count(of: input.itemId) < input.count {
                    return false
                }
            }
        }

        // Check if we have space for outputs
        if let entity = entity, let world = world, let inventory = world.get(InventoryComponent.self, for: entity),
           (world.has(FurnaceComponent.self, for: entity) || world.has(AssemblerComponent.self, for: entity) || inventory.slots.count >= 8) {
            // For machines (furnaces and assemblers), check space only in output slots (second half)
            let outputStartIndex = inventory.slots.count / 2
            for output in recipe.outputs {
                var hasSpace = false
                let correctMaxStack = itemRegistry.get(output.itemId)?.stackSize ?? 200
                for i in outputStartIndex..<inventory.slots.count {
                    if let existing = inventory.slots[i], existing.itemId == output.itemId && existing.count < correctMaxStack {
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
            // For other entities, check space anywhere in inventory
            for output in recipe.outputs {
                if !inventory.canAccept(itemId: output.itemId) {
                    return false
                }
            }
        }

        return true
    }

    private func consumeInputsFromInputSlots(recipe: Recipe, inventory: inout InventoryComponent, world: World, entity: Entity) {
        let hasFurnace = world.has(FurnaceComponent.self, for: entity)
        let hasAssembler = world.has(AssemblerComponent.self, for: entity)
        let isMachine = hasFurnace || hasAssembler
        // Also check inventory size as fallback - machines have 8 slots, others have fewer
        let inventorySizeIndicatesMachine = inventory.slots.count >= 8
        let treatAsMachine = isMachine || inventorySizeIndicatesMachine

        if treatAsMachine {
            // For machines, only consume from input slots (first half)
            let inputSlotCount = inventory.slots.count / 2
            for input in recipe.inputs {
                var remaining = input.count
                for i in 0..<inputSlotCount {
                    if remaining <= 0 { break }
                    if var slot = inventory.slots[i], slot.itemId == input.itemId {
                        let toRemove = min(remaining, slot.count)
                        slot.count -= toRemove
                        remaining -= toRemove
                        inventory.slots[i] = slot.count > 0 ? slot : nil
                    }
                }
            }
        } else {
            // For non-machines, consume from anywhere
            for input in recipe.inputs {
                inventory.remove(itemId: input.itemId, count: input.count)
            }
        }
    }

    private func completeRecipe(recipe: Recipe, inventory: inout InventoryComponent, entity: Entity, world: World) {
        // For machines (furnaces and assemblers), put outputs in the second half of inventory slots
        let hasFurnace = world.has(FurnaceComponent.self, for: entity)
        let hasAssembler = world.has(AssemblerComponent.self, for: entity)
        let isMachine = hasFurnace || hasAssembler
        // Also check inventory size as fallback
        let inventorySizeIndicatesMachine = inventory.slots.count >= 8
        let treatAsMachine = isMachine || inventorySizeIndicatesMachine
        // Different machines have different output slot starts
        let outputStartIndex = treatAsMachine ? (hasFurnace ? 2 : inventory.slots.count / 2) : 0

        for var output in recipe.outputs {
            if treatAsMachine {
                // For machines (furnaces and assemblers), ONLY add to output slots (second half) - never to input slots
                var added = false
                for i in outputStartIndex..<inventory.slots.count {
                    if let existing = inventory.slots[i], existing.itemId == output.itemId {
                        // Check if maxStack needs updating
                        let item = itemRegistry.get(output.itemId)
                        let correctMaxStack = item?.stackSize ?? existing.maxStack
                        if existing.maxStack != correctMaxStack {
                            var updated = existing
                            updated.maxStack = correctMaxStack
                            inventory.slots[i] = updated
                        }

                        if existing.count < correctMaxStack {
                            // Add to existing stack (up to maxStack)
                            let spaceAvailable = correctMaxStack - existing.count
                            let amountToAdd = min(output.count, spaceAvailable)
                            inventory.slots[i]?.count += amountToAdd
                            output.count -= amountToAdd
                            if output.count == 0 {
                                added = true
                                break
                            }
                            // Continue to next slot if there's remaining output
                        }
                    } else if inventory.slots[i] == nil {
                        // Add to empty slot
                        let item = itemRegistry.get(output.itemId)
                        let correctMaxStack = item?.stackSize ?? output.maxStack
                        inventory.slots[i] = ItemStack(itemId: output.itemId, count: output.count, maxStack: correctMaxStack)
                        added = true
                        break
                    } else if let existing = inventory.slots[i], existing.itemId == output.itemId && existing.count >= existing.maxStack {
                        // Skip full stacks of the same item
                    } else if let existing = inventory.slots[i], existing.itemId != output.itemId {
                        // Skip slots with different items
                    }
                }
                // If output slots are full, allow completion but use fallback (any available slot)
                // This prevents machines from getting stuck with in-progress recipes
                if !added {
                    print("Warning: Machine output slots are full - using fallback placement for recipe \(recipe.id)")
                    // Use regular add as fallback (will place in any available slot, including input slots if needed)
                    let remaining = inventory.add(output)
                    if remaining > 0 {
                        print("Warning: Could not place machine output - no space anywhere in inventory")
                        // In a real game, this might destroy the item or something
                    }
                }
            } else {
                // For non-machines, use regular add
                inventory.add(output)
            }
        }

        // Inventory is saved by caller
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
                        return recipe
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

