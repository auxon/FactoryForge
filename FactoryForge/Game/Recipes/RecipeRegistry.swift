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
        
        // Science packs
        register(Recipe(
            id: "automation-science-pack",
            name: "Automation Science Pack",
            inputs: [
                ItemStack(itemId: "copper-plate", count: 1),
                ItemStack(itemId: "iron-gear-wheel", count: 1)
            ],
            outputs: [ItemStack(itemId: "automation-science-pack", count: 1)],
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
            outputs: [ItemStack(itemId: "logistic-science-pack", count: 1)],
            craftTime: 6,
            category: .crafting,
            order: "f"
        ))
        
        // Logistics items
        register(Recipe(
            id: "transport-belt",
            name: "Transport Belt",
            inputs: [
                ItemStack(itemId: "iron-plate", count: 1),
                ItemStack(itemId: "iron-gear-wheel", count: 1)
            ],
            outputs: [ItemStack(itemId: "transport-belt", count: 2)],
            craftTime: 0.5,
            category: .crafting,
            order: "g"
        ))
        
        register(Recipe(
            id: "inserter",
            name: "Inserter",
            inputs: [
                ItemStack(itemId: "electronic-circuit", count: 1),
                ItemStack(itemId: "iron-gear-wheel", count: 1),
                ItemStack(itemId: "iron-plate", count: 1)
            ],
            outputs: [ItemStack(itemId: "inserter", count: 1)],
            craftTime: 0.5,
            category: .crafting,
            order: "h"
        ))
        
        register(Recipe(
            id: "wooden-chest",
            name: "Wooden Chest",
            inputs: [ItemStack(itemId: "wood", count: 2)],
            outputs: [ItemStack(itemId: "wooden-chest", count: 1)],
            craftTime: 0.5,
            category: .crafting,
            order: "i"
        ))
        
        register(Recipe(
            id: "iron-chest",
            name: "Iron Chest",
            inputs: [ItemStack(itemId: "iron-plate", count: 8)],
            outputs: [ItemStack(itemId: "iron-chest", count: 1)],
            craftTime: 0.5,
            category: .crafting,
            order: "j"
        ))
        
        // Production buildings
        register(Recipe(
            id: "burner-mining-drill",
            name: "Burner Mining Drill",
            inputs: [
                ItemStack(itemId: "iron-gear-wheel", count: 3),
                ItemStack(itemId: "iron-plate", count: 3),
                ItemStack(itemId: "stone-furnace", count: 1)
            ],
            outputs: [ItemStack(itemId: "burner-mining-drill", count: 1)],
            craftTime: 2,
            category: .crafting,
            order: "k"
        ))
        
        register(Recipe(
            id: "electric-mining-drill",
            name: "Electric Mining Drill",
            inputs: [
                ItemStack(itemId: "electronic-circuit", count: 3),
                ItemStack(itemId: "iron-gear-wheel", count: 5),
                ItemStack(itemId: "iron-plate", count: 10)
            ],
            outputs: [ItemStack(itemId: "electric-mining-drill", count: 1)],
            craftTime: 2,
            category: .crafting,
            order: "l"
        ))
        
        register(Recipe(
            id: "stone-furnace",
            name: "Stone Furnace",
            inputs: [ItemStack(itemId: "stone", count: 5)],
            outputs: [ItemStack(itemId: "stone-furnace", count: 1)],
            craftTime: 0.5,
            category: .crafting,
            order: "m"
        ))
        
        register(Recipe(
            id: "assembling-machine-1",
            name: "Assembling Machine 1",
            inputs: [
                ItemStack(itemId: "electronic-circuit", count: 3),
                ItemStack(itemId: "iron-gear-wheel", count: 5),
                ItemStack(itemId: "iron-plate", count: 9)
            ],
            outputs: [ItemStack(itemId: "assembling-machine-1", count: 1)],
            craftTime: 0.5,
            category: .crafting,
            order: "n"
        ))
        
        register(Recipe(
            id: "lab",
            name: "Lab",
            inputs: [
                ItemStack(itemId: "electronic-circuit", count: 10),
                ItemStack(itemId: "iron-gear-wheel", count: 10),
                ItemStack(itemId: "transport-belt", count: 4)
            ],
            outputs: [ItemStack(itemId: "lab", count: 1)],
            craftTime: 2,
            category: .crafting,
            order: "o"
        ))
        
        // Power buildings
        register(Recipe(
            id: "boiler",
            name: "Boiler",
            inputs: [
                ItemStack(itemId: "stone-furnace", count: 1),
                ItemStack(itemId: "pipe", count: 4)
            ],
            outputs: [ItemStack(itemId: "boiler", count: 1)],
            craftTime: 0.5,
            category: .crafting,
            order: "p"
        ))
        
        register(Recipe(
            id: "steam-engine",
            name: "Steam Engine",
            inputs: [
                ItemStack(itemId: "iron-gear-wheel", count: 8),
                ItemStack(itemId: "iron-plate", count: 10),
                ItemStack(itemId: "pipe", count: 5)
            ],
            outputs: [ItemStack(itemId: "steam-engine", count: 1)],
            craftTime: 0.5,
            category: .crafting,
            order: "q"
        ))
        
        register(Recipe(
            id: "small-electric-pole",
            name: "Small Electric Pole",
            inputs: [
                ItemStack(itemId: "wood", count: 1),
                ItemStack(itemId: "copper-cable", count: 2)
            ],
            outputs: [ItemStack(itemId: "small-electric-pole", count: 2)],
            craftTime: 0.5,
            category: .crafting,
            order: "r"
        ))
        
        register(Recipe(
            id: "solar-panel",
            name: "Solar Panel",
            inputs: [
                ItemStack(itemId: "steel-plate", count: 5),
                ItemStack(itemId: "electronic-circuit", count: 15),
                ItemStack(itemId: "copper-plate", count: 5)
            ],
            outputs: [ItemStack(itemId: "solar-panel", count: 1)],
            craftTime: 10,
            category: .crafting,
            order: "s"
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
        
        register(Recipe(
            id: "gun-turret",
            name: "Gun Turret",
            inputs: [
                ItemStack(itemId: "iron-gear-wheel", count: 10),
                ItemStack(itemId: "copper-plate", count: 10),
                ItemStack(itemId: "iron-plate", count: 20)
            ],
            outputs: [ItemStack(itemId: "gun-turret", count: 1)],
            craftTime: 8,
            category: .crafting,
            order: "u"
        ))
        
        register(Recipe(
            id: "wall",
            name: "Wall",
            inputs: [ItemStack(itemId: "stone-brick", count: 5)],
            outputs: [ItemStack(itemId: "wall", count: 1)],
            craftTime: 0.5,
            category: .crafting,
            order: "v"
        ))
        
        register(Recipe(
            id: "radar",
            name: "Radar",
            inputs: [
                ItemStack(itemId: "electronic-circuit", count: 5),
                ItemStack(itemId: "iron-gear-wheel", count: 5),
                ItemStack(itemId: "iron-plate", count: 10)
            ],
            outputs: [ItemStack(itemId: "radar", count: 1)],
            craftTime: 0.5,
            category: .crafting,
            order: "w"
        ))
    }
}

