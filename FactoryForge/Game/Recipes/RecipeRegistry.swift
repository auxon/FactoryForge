import Foundation

/// Registry of all recipes in the game
final class RecipeRegistry {
    private var recipes: [String: Recipe] = [:]
    private let itemRegistry: ItemRegistry
    
    init(itemRegistry: ItemRegistry) {
        self.itemRegistry = itemRegistry
    }
    
    /// Gets a recipe by ID
    func get(_ id: String) -> Recipe? {
        return recipes[id]
    }
    
    /// Gets all recipes
    var all: [Recipe] {
        return Array(recipes.values).sorted { $0.order < $1.order }
    }
    
    /// Gets enabled recipes
    var enabled: [Recipe] {
        return recipes.values.filter { $0.enabled }.sorted { $0.order < $1.order }
    }
    
    /// Gets recipes by category
    func recipes(in category: CraftingCategory) -> [Recipe] {
        return recipes.values.filter { $0.category == category }.sorted { $0.order < $1.order }
    }
    
    /// Gets recipes that output a specific item
    func recipes(producing itemId: String) -> [Recipe] {
        return recipes.values.filter { recipe in
            recipe.outputs.contains { $0.itemId == itemId }
        }
    }
    
    /// Gets recipes that use a specific item as input
    func recipes(using itemId: String) -> [Recipe] {
        return recipes.values.filter { recipe in
            recipe.inputs.contains { $0.itemId == itemId }
        }
    }
    
    /// Registers a recipe
    func register(_ recipe: Recipe) {
        recipes[recipe.id] = recipe
    }
    
    /// Loads recipes from embedded data
    func loadRecipes() {
        // Smelting recipes
        register(Recipe(
            id: "iron-plate",
            name: "Iron Plate",
            inputs: [ItemStack(itemId: "iron-ore", count: 1)],
            outputs: [ItemStack(itemId: "iron-plate", count: 1)],
            craftTime: 3.2,
            category: .smelting,
            order: "a"
        ))
        
        register(Recipe(
            id: "copper-plate",
            name: "Copper Plate",
            inputs: [ItemStack(itemId: "copper-ore", count: 1)],
            outputs: [ItemStack(itemId: "copper-plate", count: 1)],
            craftTime: 3.2,
            category: .smelting,
            order: "b"
        ))
        
        register(Recipe(
            id: "steel-plate",
            name: "Steel Plate",
            inputs: [ItemStack(itemId: "iron-plate", count: 5)],
            outputs: [ItemStack(itemId: "steel-plate", count: 1)],
            craftTime: 16,
            category: .smelting,
            order: "c"
        ))
        
        register(Recipe(
            id: "stone-brick",
            name: "Stone Brick",
            inputs: [ItemStack(itemId: "stone", count: 2)],
            outputs: [ItemStack(itemId: "stone-brick", count: 1)],
            craftTime: 3.2,
            category: .smelting,
            order: "d"
        ))
        
        // Basic crafting recipes
        register(Recipe(
            id: "iron-gear-wheel",
            name: "Iron Gear Wheel",
            inputs: [ItemStack(itemId: "iron-plate", count: 2)],
            outputs: [ItemStack(itemId: "iron-gear-wheel", count: 1)],
            craftTime: 0.5,
            category: .crafting,
            order: "a"
        ))
        
        register(Recipe(
            id: "copper-cable",
            name: "Copper Cable",
            inputs: [ItemStack(itemId: "copper-plate", count: 1)],
            outputs: [ItemStack(itemId: "copper-cable", count: 2)],
            craftTime: 0.5,
            category: .crafting,
            order: "b"
        ))
        
        register(Recipe(
            id: "pipe",
            name: "Pipe",
            inputs: [ItemStack(itemId: "iron-plate", count: 1)],
            outputs: [ItemStack(itemId: "pipe", count: 1)],
            craftTime: 0.5,
            category: .crafting,
            order: "b1"
        ))
        
        register(Recipe(
            id: "electronic-circuit",
            name: "Electronic Circuit",
            inputs: [
                ItemStack(itemId: "iron-plate", count: 1),
                ItemStack(itemId: "copper-cable", count: 3)
            ],
            outputs: [ItemStack(itemId: "electronic-circuit", count: 1)],
            craftTime: 0.5,
            category: .crafting,
            order: "c"
        ))
        
        register(Recipe(
            id: "advanced-circuit",
            name: "Advanced Circuit",
            inputs: [
                ItemStack(itemId: "electronic-circuit", count: 2),
                ItemStack(itemId: "copper-cable", count: 4),
                ItemStack(itemId: "plastic-bar", count: 2)
            ],
            outputs: [ItemStack(itemId: "advanced-circuit", count: 1)],
            craftTime: 6,
            category: .crafting,
            order: "d"
        ))

        register(Recipe(
            id: "processing-unit",
            name: "Processing Unit",
            inputs: [
                ItemStack(itemId: "advanced-circuit", count: 2),
                ItemStack(itemId: "electronic-circuit", count: 20),
                ItemStack(itemId: "sulfuric-acid", count: 5)
            ],
            outputs: [ItemStack(itemId: "processing-unit", count: 1)],
            craftTime: 10,
            category: .crafting,
            order: "e"
        ))

        // Science packs
        register(Recipe(
            id: "automation-science-pack",
            name: "Automation Science Pack",
            inputs: [
                ItemStack(itemId: "copper-plate", count: 1),
                ItemStack(itemId: "iron-gear-wheel", count: 1)
            ],
            outputs: [ItemStack(itemId: "automation-science-pack", count: 5)],
            craftTime: 5,
            category: .crafting,
            order: "e"
        ))
        
        register(Recipe(
            id: "logistic-science-pack",
            name: "Logistic Science Pack",
            inputs: [
                ItemStack(itemId: "inserter", count: 1),
                ItemStack(itemId: "transport-belt", count: 1)
            ],
            outputs: [ItemStack(itemId: "logistic-science-pack", count: 5)],
            craftTime: 6,
            category: .crafting,
            order: "f"
        ))
        
        // Combat items
        register(Recipe(
            id: "firearm-magazine",
            name: "Firearm Magazine",
            inputs: [ItemStack(itemId: "iron-plate", count: 4)],
            outputs: [ItemStack(itemId: "firearm-magazine", count: 1)],
            craftTime: 1,
            category: .crafting,
            order: "t"
        ))
        

        // Oil processing buildings
        register(Recipe(
            id: "water-pump",
            name: "Water Pump",
            inputs: [
                ItemStack(itemId: "iron-plate", count: 5),
                ItemStack(itemId: "pipe", count: 5),
                ItemStack(itemId: "electronic-circuit", count: 2)
            ],
            outputs: [ItemStack(itemId: "water-pump", count: 1)],
            craftTime: 5,
            category: .crafting,
            order: "w"
        ))


        // Oil processing recipes
        register(Recipe(
            id: "basic-oil-processing",
            name: "Basic Oil Processing",
            inputs: [ItemStack(itemId: "crude-oil", count: 100)],
            outputs: [
                ItemStack(itemId: "petroleum-gas", count: 45),
                ItemStack(itemId: "light-oil", count: 30),
                ItemStack(itemId: "heavy-oil", count: 25)
            ],
            craftTime: 5,
            category: .oilProcessing,
            order: "a"
        ))

        register(Recipe(
            id: "advanced-oil-processing",
            name: "Advanced Oil Processing",
            inputs: [
                ItemStack(itemId: "crude-oil", count: 100),
                ItemStack(itemId: "water", count: 50)
            ],
            outputs: [
                ItemStack(itemId: "petroleum-gas", count: 55),
                ItemStack(itemId: "light-oil", count: 45),
                ItemStack(itemId: "heavy-oil", count: 25)
            ],
            craftTime: 5,
            category: .oilProcessing,
            order: "b"
        ))

        register(Recipe(
            id: "light-oil-cracking",
            name: "Light Oil Cracking",
            inputs: [
                ItemStack(itemId: "light-oil", count: 30),
                ItemStack(itemId: "water", count: 30)
            ],
            outputs: [ItemStack(itemId: "petroleum-gas", count: 20)],
            craftTime: 5,
            category: .chemistry,
            order: "c"
        ))

        register(Recipe(
            id: "heavy-oil-cracking",
            name: "Heavy Oil Cracking",
            inputs: [
                ItemStack(itemId: "heavy-oil", count: 40),
                ItemStack(itemId: "water", count: 30)
            ],
            outputs: [ItemStack(itemId: "light-oil", count: 30)],
            craftTime: 5,
            category: .chemistry,
            order: "d"
        ))

        // Chemical products
        register(Recipe(
            id: "plastic-bar",
            name: "Plastic Bar",
            inputs: [
                ItemStack(itemId: "petroleum-gas", count: 20),
                ItemStack(itemId: "coal", count: 1)
            ],
            outputs: [ItemStack(itemId: "plastic-bar", count: 2)],
            craftTime: 1,
            category: .chemistry,
            order: "e"
        ))

        register(Recipe(
            id: "sulfur",
            name: "Sulfur",
            inputs: [
                ItemStack(itemId: "petroleum-gas", count: 30),
                ItemStack(itemId: "water", count: 30)
            ],
            outputs: [ItemStack(itemId: "sulfur", count: 2)],
            craftTime: 1,
            category: .chemistry,
            order: "f"
        ))

        register(Recipe(
            id: "sulfuric-acid",
            name: "Sulfuric Acid",
            inputs: [
                ItemStack(itemId: "sulfur", count: 5),
                ItemStack(itemId: "iron-plate", count: 1),
                ItemStack(itemId: "water", count: 100)
            ],
            outputs: [ItemStack(itemId: "sulfuric-acid", count: 50)],
            craftTime: 1,
            category: .chemistry,
            order: "g"
        ))

        register(Recipe(
            id: "lubricant",
            name: "Lubricant",
            inputs: [ItemStack(itemId: "heavy-oil", count: 10)],
            outputs: [ItemStack(itemId: "lubricant", count: 10)],
            craftTime: 1,
            category: .chemistry,
            order: "h"
        ))

        register(Recipe(
            id: "solid-fuel",
            name: "Solid Fuel",
            inputs: [
                ItemStack(itemId: "coal", count: 1),
                ItemStack(itemId: "petroleum-gas", count: 20)
            ],
            outputs: [ItemStack(itemId: "solid-fuel", count: 1)],
            craftTime: 2,
            category: .chemistry,
            order: "i"
        ))

        register(Recipe(
            id: "low-density-structure",
            name: "Low Density Structure",
            inputs: [
                ItemStack(itemId: "steel-plate", count: 2),
                ItemStack(itemId: "copper-plate", count: 20),
                ItemStack(itemId: "plastic-bar", count: 5)
            ],
            outputs: [ItemStack(itemId: "low-density-structure", count: 1)],
            craftTime: 20,
            category: .crafting,
            order: "j"
        ))

        register(Recipe(
            id: "battery",
            name: "Battery",
            inputs: [
                ItemStack(itemId: "iron-plate", count: 1),
                ItemStack(itemId: "copper-plate", count: 1),
                ItemStack(itemId: "sulfuric-acid", count: 20)
            ],
            outputs: [ItemStack(itemId: "battery", count: 1)],
            craftTime: 5,
            category: .chemistry,
            order: "i"
        ))

        register(Recipe(
            id: "explosives",
            name: "Explosives",
            inputs: [
                ItemStack(itemId: "coal", count: 1),
                ItemStack(itemId: "sulfur", count: 1),
                ItemStack(itemId: "water", count: 1)
            ],
            outputs: [ItemStack(itemId: "explosives", count: 2)],
            craftTime: 5,
            category: .chemistry,
            order: "j"
        ))

        // Advanced machinery




        // Chemical science pack
        // Nuclear processing
        register(Recipe(
            id: "uranium-processing",
            name: "Uranium Processing",
            inputs: [
                ItemStack(itemId: "uranium-ore", count: 10)
            ],
            outputs: [
                ItemStack(itemId: "uranium-235", count: 1),
                ItemStack(itemId: "uranium-238", count: 9)
            ],
            craftTime: 12,
            category: .centrifuging,
            order: "ab"
        ))

        register(Recipe(
            id: "nuclear-fuel",
            name: "Nuclear Fuel",
            inputs: [
                ItemStack(itemId: "uranium-235", count: 1),
                ItemStack(itemId: "uranium-238", count: 19)
            ],
            outputs: [ItemStack(itemId: "nuclear-fuel", count: 1)],
            craftTime: 60,
            category: .centrifuging,
            order: "ac"
        ))

        register(Recipe(
            id: "nuclear-reactor",
            name: "Nuclear Reactor",
            inputs: [
                ItemStack(itemId: "steel-plate", count: 400),
                ItemStack(itemId: "advanced-circuit", count: 400),
                ItemStack(itemId: "copper-plate", count: 400),
                ItemStack(itemId: "stone-brick", count: 400)
            ],
            outputs: [ItemStack(itemId: "nuclear-reactor", count: 1)],
            craftTime: 8,
            category: .crafting,
            order: "ad"
        ))

        register(Recipe(
            id: "centrifuge",
            name: "Centrifuge",
            inputs: [
                ItemStack(itemId: "steel-plate", count: 50),
                ItemStack(itemId: "advanced-circuit", count: 100),
                ItemStack(itemId: "processing-unit", count: 100),
                ItemStack(itemId: "stone-brick", count: 100)
            ],
            outputs: [ItemStack(itemId: "centrifuge", count: 1)],
            craftTime: 4,
            category: .crafting,
            order: "ae"
        ))

        // Rocket production
        register(Recipe(
            id: "rocket-fuel",
            name: "Rocket Fuel",
            inputs: [
                ItemStack(itemId: "solid-fuel", count: 10)
            ],
            outputs: [ItemStack(itemId: "rocket-fuel", count: 1)],
            craftTime: 30,
            category: .crafting,
            order: "af"
        ))

        register(Recipe(
            id: "rocket-part",
            name: "Rocket Part",
            inputs: [
                ItemStack(itemId: "steel-plate", count: 10),
                ItemStack(itemId: "low-density-structure", count: 10),
                ItemStack(itemId: "rocket-fuel", count: 10),
                ItemStack(itemId: "electronic-circuit", count: 10)
            ],
            outputs: [ItemStack(itemId: "rocket-part", count: 1)],
            craftTime: 3,
            category: .crafting,
            order: "ag"
        ))

        register(Recipe(
            id: "satellite",
            name: "Satellite",
            inputs: [
                ItemStack(itemId: "low-density-structure", count: 100),
                ItemStack(itemId: "solar-panel", count: 100),
                ItemStack(itemId: "accumulator", count: 100),
                ItemStack(itemId: "radar", count: 5),
                ItemStack(itemId: "processing-unit", count: 100),
                ItemStack(itemId: "rocket-fuel", count: 50)
            ],
            outputs: [ItemStack(itemId: "satellite", count: 1)],
            craftTime: 5,
            category: .crafting,
            order: "ah"
        ))

        register(Recipe(
            id: "rocket-silo",
            name: "Rocket Silo",
            inputs: [
                ItemStack(itemId: "steel-plate", count: 1000),
                ItemStack(itemId: "stone-brick", count: 1000),
                ItemStack(itemId: "pipe", count: 100),
                ItemStack(itemId: "processing-unit", count: 200)
            ],
            outputs: [ItemStack(itemId: "rocket-silo", count: 1)],
            craftTime: 30,
            category: .crafting,
            order: "ai"
        ))

        // Space science packs are generated by rocket launches, not crafted
        // This recipe serves as a placeholder for the technology unlock
        register(Recipe(
            id: "space-science-pack",
            name: "Space Science Pack (Generated by Rocket Launches)",
            inputs: [],  // No inputs - generated by rocket launches
            outputs: [ItemStack(itemId: "space-science-pack", count: 1000)],
            craftTime: 0,  // Instant generation
            category: .crafting,
            order: "aj"
        ))

        register(Recipe(
            id: "chemical-science-pack",
            name: "Chemical Science Pack",
            inputs: [
                ItemStack(itemId: "advanced-circuit", count: 3),
                ItemStack(itemId: "engine-unit", count: 2),
                ItemStack(itemId: "sulfuric-acid", count: 1)
            ],
            outputs: [ItemStack(itemId: "chemical-science-pack", count: 1)],
            craftTime: 24,
            category: .crafting,
            order: "aa"
        ))
    }
}

