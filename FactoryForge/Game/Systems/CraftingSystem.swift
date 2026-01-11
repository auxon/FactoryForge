import Foundation
import QuartzCore

/// System that handles crafting in assemblers and furnaces
final class CraftingSystem: System {
    let priority = SystemPriority.production.rawValue

    private let world: World
    private let recipeRegistry: RecipeRegistry
    private let itemRegistry: ItemRegistry
    private let buildingRegistry: BuildingRegistry

    init(world: World, recipeRegistry: RecipeRegistry, itemRegistry: ItemRegistry, buildingRegistry: BuildingRegistry) {
        self.world = world
        self.recipeRegistry = recipeRegistry
        self.itemRegistry = itemRegistry
        self.buildingRegistry = buildingRegistry
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
                    completeRecipe(recipe: recipe, inventory: &inventory, buildingComponent: assembler, entity: entity, world: world)
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
                    completeRecipe(recipe: recipe, inventory: &inventory, buildingComponent: furnace, entity: entity, world: world)
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
        // Check if we have all item inputs (now check anywhere in inventory for all cases)
        for input in recipe.inputs {
            if inventory.count(of: input.itemId) < input.count {
                return false
            }
        }

        // Check if we have space for item outputs (now check anywhere in inventory for all cases)
        for output in recipe.outputs {
            if !inventory.canAccept(itemId: output.itemId) {
                return false
            }
        }

        // Check fluid inputs if we have entity and world context
        if let entity = entity, let world = world {
            // Get fluid tanks from the building
            var availableFluids: [FluidStack] = []
            if let tankComponent = world.get(FluidTankComponent.self, for: entity) {
                availableFluids = tankComponent.tanks
            }

            // Check fluid inputs
            for fluidInput in recipe.fluidInputs {
                var foundFluid = false
                for tank in availableFluids {
                    if tank.type == fluidInput.type && tank.amount >= fluidInput.amount {
                        foundFluid = true
                        break
                    }
                }
                if !foundFluid {
                    return false
                }
            }
        }

        return true
    }

    private func consumeInputsFromInputSlots(recipe: Recipe, inventory: inout InventoryComponent, world: World, entity: Entity) {
        // Consume item inputs from anywhere in inventory for all cases
        for input in recipe.inputs {
            inventory.remove(itemId: input.itemId, count: input.count)
        }

        // Consume fluid inputs from fluid tanks
        if var tankComponent = world.get(FluidTankComponent.self, for: entity) {
            for fluidInput in recipe.fluidInputs {
                // Find and consume from the appropriate tank
                for i in 0..<tankComponent.tanks.count {
                    if tankComponent.tanks[i].type == fluidInput.type {
                        tankComponent.tanks[i].remove(amount: fluidInput.amount)
                        break
                    }
                }
            }
            world.add(tankComponent, to: entity)
        }
    }

    private func completeRecipe(recipe: Recipe, inventory: inout InventoryComponent, buildingComponent: BuildingComponent, entity: Entity, world: World) {
        // Get building definition using the component we already have
        guard let buildingDef = buildingRegistry.get(buildingComponent.buildingId) else {
            // Fallback: place outputs anywhere if we can't determine building type
            print("CraftingSystem: FALLBACK - Building definition not found for '\(buildingComponent.buildingId)'")
            for output in recipe.outputs {
                let item = itemRegistry.get(output.itemId)
                let maxStack = item?.stackSize ?? output.maxStack
                inventory.add(itemId: output.itemId, count: output.count, maxStack: maxStack)
            }
            return
        }

        // Calculate output slot range: fuel slots + input slots to end
        let outputStartIndex = buildingDef.fuelSlots + buildingDef.inputSlots
        let outputEndIndex = outputStartIndex + buildingDef.outputSlots - 1

        // Place item outputs only in output slots
        for output in recipe.outputs {
            let item = itemRegistry.get(output.itemId)
            let maxStack = item?.stackSize ?? output.maxStack
            placeOutputInSlots(output: output, maxStack: maxStack, inventory: &inventory, startIndex: outputStartIndex, endIndex: outputEndIndex)
        }

        // Place fluid outputs into fluid tanks
        if var tankComponent = world.get(FluidTankComponent.self, for: entity) {
            for fluidOutput in recipe.fluidOutputs {
                // Find or create appropriate tank for this fluid type
                var tankFound = false
                for i in 0..<tankComponent.tanks.count {
                    if tankComponent.tanks[i].type == fluidOutput.type {
                        // Add to existing tank
                        tankComponent.tanks[i].add(amount: fluidOutput.amount)
                        tankFound = true
                        break
                    }
                }

                if !tankFound {
                    // Create new tank for this fluid type
                    let newTank = FluidStack(type: fluidOutput.type, amount: fluidOutput.amount, maxAmount: tankComponent.maxCapacity)
                    tankComponent.tanks.append(newTank)
                }
            }
            world.add(tankComponent, to: entity)
        }

        // Inventory is saved by caller
    }

    private func placeOutputInSlots(output: ItemStack, maxStack: Int, inventory: inout InventoryComponent, startIndex: Int, endIndex: Int) {
        var remaining = output.count

        // First, try to fill existing stacks of the same item in output slots
        for i in startIndex...endIndex {
            if var existingStack = inventory.slots[i], existingStack.itemId == output.itemId {
                let space = existingStack.maxStack - existingStack.count
                let toAdd = min(space, remaining)
                existingStack.count += toAdd
                inventory.slots[i] = existingStack
                remaining -= toAdd

                if remaining == 0 { return }
            }
        }

        // Then, use empty output slots
        for i in startIndex...endIndex {
            if inventory.slots[i] == nil {
                let toAdd = min(maxStack, remaining)
                inventory.slots[i] = ItemStack(itemId: output.itemId, count: toAdd, maxStack: maxStack)
                remaining -= toAdd

                if remaining == 0 { return }
            }
        }

        // If we still have remaining items and no output slots available,
        // this is an error - outputs should always fit in output slots
        if remaining > 0 {
            print("CraftingSystem: ERROR - Could not place \(remaining) \(output.itemId) in output slots \(startIndex)-\(endIndex)")
        }
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

