import Foundation

/// Registry of all items in the game
final class ItemRegistry {
    private var items: [String: Item] = [:]
    
    /// Gets an item by ID
    func get(_ id: String) -> Item? {
        return items[id]
    }
    
    /// Gets all items
    var all: [Item] {
        return Array(items.values).sorted { $0.order < $1.order }
    }
    
    /// Gets items by category
    func items(in category: ItemCategory) -> [Item] {
        return items.values.filter { $0.category == category }.sorted { $0.order < $1.order }
    }
    
    /// Gets fuel items
    var fuels: [Item] {
        return items.values.filter { $0.isFuel }.sorted { ($0.fuelValue ?? 0) < ($1.fuelValue ?? 0) }
    }
    
    /// Registers an item
    func register(_ item: Item) {
        items[item.id] = item
    }
    
    /// Loads items from embedded data
    func loadItems() {
        // Raw materials
        register(Item(id: "iron-ore", name: "Iron Ore", stackSize: 50, category: .raw, order: "a"))
        register(Item(id: "copper-ore", name: "Copper Ore", stackSize: 50, category: .raw, order: "b"))
        register(Item(id: "coal", name: "Coal", stackSize: 50, category: .raw, order: "c", fuelValue: 4000, fuelCategory: "chemical"))
        register(Item(id: "stone", name: "Stone", stackSize: 50, category: .raw, order: "d"))
        register(Item(id: "wood", name: "Wood", stackSize: 100, category: .raw, order: "e", fuelValue: 2000, fuelCategory: "chemical"))
        register(Item(id: "crude-oil", name: "Crude Oil", stackSize: 0, category: .fluid, order: "f"))
        register(Item(id: "uranium-ore", name: "Uranium Ore", stackSize: 50, category: .raw, order: "g"))
        
        // Intermediate products
        register(Item(id: "iron-plate", name: "Iron Plate", stackSize: 100, category: .intermediate, order: "a"))
        register(Item(id: "copper-plate", name: "Copper Plate", stackSize: 100, category: .intermediate, order: "b"))
        register(Item(id: "steel-plate", name: "Steel Plate", stackSize: 100, category: .intermediate, order: "c"))
        register(Item(id: "stone-brick", name: "Stone Brick", stackSize: 100, category: .intermediate, order: "d"))
        register(Item(id: "iron-gear-wheel", name: "Iron Gear Wheel", stackSize: 100, category: .intermediate, order: "e"))
        register(Item(id: "copper-cable", name: "Copper Cable", stackSize: 200, category: .intermediate, order: "f"))
        register(Item(id: "pipe", name: "Pipe", stackSize: 100, category: .intermediate, order: "f1"))
        register(Item(id: "electronic-circuit", name: "Electronic Circuit", stackSize: 200, category: .intermediate, order: "g"))
        register(Item(id: "advanced-circuit", name: "Advanced Circuit", stackSize: 200, category: .intermediate, order: "h"))
        register(Item(id: "processing-unit", name: "Processing Unit", stackSize: 100, category: .intermediate, order: "i"))
        register(Item(id: "engine-unit", name: "Engine Unit", stackSize: 50, category: .intermediate, order: "j"))
        register(Item(id: "electric-engine-unit", name: "Electric Engine Unit", stackSize: 50, category: .intermediate, order: "k"))
        
        // Science packs
        register(Item(id: "automation-science-pack", name: "Automation Science Pack", stackSize: 200, category: .science, order: "a"))
        register(Item(id: "logistic-science-pack", name: "Logistic Science Pack", stackSize: 200, category: .science, order: "b"))
        register(Item(id: "military-science-pack", name: "Military Science Pack", stackSize: 200, category: .science, order: "c"))
        register(Item(id: "chemical-science-pack", name: "Chemical Science Pack", stackSize: 200, category: .science, order: "d"))
        register(Item(id: "production-science-pack", name: "Production Science Pack", stackSize: 200, category: .science, order: "e"))
        register(Item(id: "utility-science-pack", name: "Utility Science Pack", stackSize: 200, category: .science, order: "f"))
        
        // Logistics items
        register(Item(id: "transport-belt", name: "Transport Belt", stackSize: 100, category: .logistics, order: "a", placedAs: "transport-belt"))
        register(Item(id: "fast-transport-belt", name: "Fast Transport Belt", stackSize: 100, category: .logistics, order: "b", placedAs: "fast-transport-belt"))
        register(Item(id: "express-transport-belt", name: "Express Transport Belt", stackSize: 100, category: .logistics, order: "c", placedAs: "express-transport-belt"))
        register(Item(id: "inserter", name: "Inserter", stackSize: 50, category: .logistics, order: "d", placedAs: "inserter"))
        register(Item(id: "long-handed-inserter", name: "Long Handed Inserter", stackSize: 50, category: .logistics, order: "e", placedAs: "long-handed-inserter"))
        register(Item(id: "fast-inserter", name: "Fast Inserter", stackSize: 50, category: .logistics, order: "f", placedAs: "fast-inserter"))
        register(Item(id: "wooden-chest", name: "Wooden Chest", stackSize: 50, category: .logistics, order: "g", placedAs: "wooden-chest"))
        register(Item(id: "iron-chest", name: "Iron Chest", stackSize: 50, category: .logistics, order: "h", placedAs: "iron-chest"))
        register(Item(id: "steel-chest", name: "Steel Chest", stackSize: 50, category: .logistics, order: "i", placedAs: "steel-chest"))
        
        // Production items
        register(Item(id: "burner-mining-drill", name: "Burner Mining Drill", stackSize: 50, category: .production, order: "a", placedAs: "burner-mining-drill"))
        register(Item(id: "electric-mining-drill", name: "Electric Mining Drill", stackSize: 50, category: .production, order: "b", placedAs: "electric-mining-drill"))
        register(Item(id: "stone-furnace", name: "Stone Furnace", stackSize: 50, category: .production, order: "c", placedAs: "stone-furnace"))
        register(Item(id: "steel-furnace", name: "Steel Furnace", stackSize: 50, category: .production, order: "d", placedAs: "steel-furnace"))
        register(Item(id: "electric-furnace", name: "Electric Furnace", stackSize: 50, category: .production, order: "e", placedAs: "electric-furnace"))
        register(Item(id: "assembling-machine-1", name: "Assembling Machine 1", stackSize: 50, category: .production, order: "f", placedAs: "assembling-machine-1"))
        register(Item(id: "assembling-machine-2", name: "Assembling Machine 2", stackSize: 50, category: .production, order: "g", placedAs: "assembling-machine-2"))
        register(Item(id: "assembling-machine-3", name: "Assembling Machine 3", stackSize: 50, category: .production, order: "h", placedAs: "assembling-machine-3"))
        register(Item(id: "lab", name: "Lab", stackSize: 10, category: .production, order: "i", placedAs: "lab"))
        
        // Power items
        register(Item(id: "boiler", name: "Boiler", stackSize: 50, category: .production, order: "j", placedAs: "boiler"))
        register(Item(id: "steam-engine", name: "Steam Engine", stackSize: 10, category: .production, order: "k", placedAs: "steam-engine"))
        register(Item(id: "solar-panel", name: "Solar Panel", stackSize: 50, category: .production, order: "l", placedAs: "solar-panel"))
        register(Item(id: "accumulator", name: "Accumulator", stackSize: 50, category: .production, order: "m", placedAs: "accumulator"))
        register(Item(id: "small-electric-pole", name: "Small Electric Pole", stackSize: 50, category: .production, order: "n", placedAs: "small-electric-pole"))
        register(Item(id: "medium-electric-pole", name: "Medium Electric Pole", stackSize: 50, category: .production, order: "o", placedAs: "medium-electric-pole"))
        register(Item(id: "big-electric-pole", name: "Big Electric Pole", stackSize: 50, category: .production, order: "p", placedAs: "big-electric-pole"))
        
        // Combat items
        register(Item(id: "firearm-magazine", name: "Firearm Magazine", stackSize: 200, category: .ammo, order: "a"))
        register(Item(id: "piercing-rounds-magazine", name: "Piercing Rounds Magazine", stackSize: 200, category: .ammo, order: "b"))
        register(Item(id: "gun-turret", name: "Gun Turret", stackSize: 50, category: .combat, order: "c", placedAs: "gun-turret"))
        register(Item(id: "laser-turret", name: "Laser Turret", stackSize: 50, category: .combat, order: "d", placedAs: "laser-turret"))
        register(Item(id: "wall", name: "Wall", stackSize: 100, category: .combat, order: "e", placedAs: "stone-wall"))
        register(Item(id: "grenade", name: "Grenade", stackSize: 100, category: .combat, order: "f"))
        register(Item(id: "radar", name: "Radar", stackSize: 50, category: .combat, order: "g", placedAs: "radar"))
    }
    
    // MARK: - Filters
    
    static let sciencePackFilter: (String) -> Bool = { id in
        return id.contains("science-pack")
    }

    static let allowedSciencePacks: [String] = [
        "automation-science-pack",
        "logistic-science-pack",
        "military-science-pack",
        "chemical-science-pack",
        "production-science-pack",
        "utility-science-pack",
        "space-science-pack"
    ]

    static let ammoFilter: (String) -> Bool = { id in
        return id.contains("magazine") || id == "grenade"
    }

    static let allowedAmmo: [String] = [
        "firearm-magazine",
        "piercing-rounds-magazine",
        "uranium-rounds-magazine",
        "grenade"
    ]
    
    static let fuelFilter: (String) -> Bool = { id in
        return ["coal", "wood", "solid-fuel", "rocket-fuel", "nuclear-fuel"].contains(id)
    }

    static let allowedFuel: [String] = [
        "coal", "wood", "solid-fuel", "rocket-fuel", "nuclear-fuel"
    ]
}

