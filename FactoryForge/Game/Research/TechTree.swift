import Foundation

/// Registry of all technologies
final class TechnologyRegistry {
    private var technologies: [String: Technology] = [:]
    
    /// Gets a technology by ID
    func get(_ id: String) -> Technology? {
        return technologies[id]
    }
    
    /// Gets all technologies
    var all: [Technology] {
        return Array(technologies.values).sorted { $0.order < $1.order }
    }
    
    /// Gets technologies by tier
    func technologies(tier: Int) -> [Technology] {
        return technologies.values.filter { $0.tier == tier }.sorted { $0.order < $1.order }
    }
    
    /// Registers a technology
    func register(_ tech: Technology) {
        technologies[tech.id] = tech
    }
    
    /// Loads all technologies
    func loadTechnologies() {
        // Tier 1 - Automation
        register(Technology(
            id: "automation",
            name: "Automation",
            description: "Unlocks assembling machines for automated crafting",
            cost: [ScienceCost("automation-science-pack", count: 10)],
            researchTime: 10,
            unlocks: TechnologyUnlocks(recipes: ["assembling-machine-1"]),
            order: "a",
            tier: 1
        ))
        
        register(Technology(
            id: "logistics",
            name: "Logistics",
            description: "Unlocks basic logistics items",
            cost: [ScienceCost("automation-science-pack", count: 20)],
            researchTime: 15,
            unlocks: TechnologyUnlocks(recipes: ["fast-inserter", "long-handed-inserter"]),
            order: "b",
            tier: 1
        ))
        
        register(Technology(
            id: "turrets",
            name: "Turrets",
            description: "Unlocks gun turrets for defense",
            cost: [ScienceCost("automation-science-pack", count: 10)],
            researchTime: 10,
            unlocks: TechnologyUnlocks(recipes: ["gun-turret"]),
            order: "c",
            tier: 1
        ))
        
        register(Technology(
            id: "stone-walls",
            name: "Stone Walls",
            description: "Unlocks walls for defense",
            cost: [ScienceCost("automation-science-pack", count: 10)],
            researchTime: 10,
            unlocks: TechnologyUnlocks(recipes: ["stone-wall"]),
            order: "d",
            tier: 1
        ))
        
        register(Technology(
            id: "steel-processing",
            name: "Steel Processing",
            description: "Unlocks steel plate smelting",
            cost: [ScienceCost("automation-science-pack", count: 50)],
            researchTime: 20,
            unlocks: TechnologyUnlocks(recipes: ["steel-plate"]),
            order: "e",
            tier: 1
        ))
        
        register(Technology(
            id: "military",
            name: "Military",
            description: "Unlocks better ammunition",
            cost: [ScienceCost("automation-science-pack", count: 20)],
            researchTime: 15,
            unlocks: TechnologyUnlocks(recipes: ["piercing-rounds-magazine"]),
            order: "f",
            tier: 1
        ))
        
        // Tier 2 - Logistics Science
        register(Technology(
            id: "logistic-science-pack",
            name: "Logistic Science Pack",
            description: "Unlocks green science packs",
            prerequisites: ["automation"],
            cost: [ScienceCost("automation-science-pack", count: 75)],
            researchTime: 30,
            unlocks: TechnologyUnlocks(recipes: ["logistic-science-pack"]),
            order: "a",
            tier: 2
        ))
        
        register(Technology(
            id: "automation-2",
            name: "Automation 2",
            description: "Unlocks faster assembling machines",
            prerequisites: ["automation", "logistic-science-pack"],
            cost: [
                ScienceCost("automation-science-pack", count: 40),
                ScienceCost("logistic-science-pack", count: 40)
            ],
            researchTime: 30,
            unlocks: TechnologyUnlocks(recipes: ["assembling-machine-2"]),
            order: "b",
            tier: 2
        ))
        
        register(Technology(
            id: "logistics-2",
            name: "Logistics 2",
            description: "Unlocks fast transport belts",
            prerequisites: ["logistics", "logistic-science-pack"],
            cost: [
                ScienceCost("automation-science-pack", count: 40),
                ScienceCost("logistic-science-pack", count: 40)
            ],
            researchTime: 30,
            unlocks: TechnologyUnlocks(recipes: ["fast-transport-belt"]),
            order: "c",
            tier: 2
        ))

        register(Technology(
            id: "advanced-logistics",
            name: "Advanced Logistics",
            description: "Unlocks underground belts, splitters, and mergers",
            prerequisites: ["logistics-2"],
            cost: [
                ScienceCost("automation-science-pack", count: 75),
                ScienceCost("logistic-science-pack", count: 75)
            ],
            researchTime: 45,
            unlocks: TechnologyUnlocks(recipes: ["underground-belt", "splitter", "merger"]),
            order: "d",
            tier: 3
        ))
        
        register(Technology(
            id: "advanced-material-processing",
            name: "Advanced Material Processing",
            description: "Unlocks steel furnaces",
            prerequisites: ["steel-processing"],
            cost: [
                ScienceCost("automation-science-pack", count: 50),
                ScienceCost("logistic-science-pack", count: 50)
            ],
            researchTime: 30,
            unlocks: TechnologyUnlocks(recipes: ["steel-furnace"]),
            order: "d",
            tier: 2
        ))
        
        register(Technology(
            id: "solar-energy",
            name: "Solar Energy",
            description: "Unlocks solar panels",
            prerequisites: ["logistic-science-pack"],
            cost: [
                ScienceCost("automation-science-pack", count: 100),
                ScienceCost("logistic-science-pack", count: 100)
            ],
            researchTime: 60,
            unlocks: TechnologyUnlocks(recipes: ["solar-panel"]),
            order: "e",
            tier: 2
        ))
        
        register(Technology(
            id: "electric-energy-accumulators",
            name: "Electric Energy Accumulators",
            description: "Unlocks accumulators for energy storage",
            prerequisites: ["solar-energy"],
            cost: [
                ScienceCost("automation-science-pack", count: 100),
                ScienceCost("logistic-science-pack", count: 100)
            ],
            researchTime: 60,
            unlocks: TechnologyUnlocks(recipes: ["accumulator"]),
            order: "f",
            tier: 2
        ))
        
        register(Technology(
            id: "laser-turrets",
            name: "Laser Turrets",
            description: "Unlocks laser turrets",
            prerequisites: ["turrets", "logistic-science-pack"],
            cost: [
                ScienceCost("automation-science-pack", count: 150),
                ScienceCost("logistic-science-pack", count: 150)
            ],
            researchTime: 60,
            unlocks: TechnologyUnlocks(recipes: ["laser-turret"]),
            order: "g",
            tier: 2
        ))
        
        // Mining productivity (infinite research)
        register(Technology(
            id: "mining-productivity-1",
            name: "Mining Productivity 1",
            description: "Increases mining output by 10%",
            prerequisites: ["logistic-science-pack"],
            cost: [
                ScienceCost("automation-science-pack", count: 100),
                ScienceCost("logistic-science-pack", count: 100)
            ],
            researchTime: 60,
            unlocks: TechnologyUnlocks(bonuses: [TechnologyBonus(type: .miningSpeed, modifier: 0.1)]),
            order: "z-a",
            tier: 2
        ))
        
        // Research speed
        register(Technology(
            id: "research-speed-1",
            name: "Research Speed 1",
            description: "Increases research speed by 20%",
            prerequisites: ["logistic-science-pack"],
            cost: [
                ScienceCost("automation-science-pack", count: 100),
                ScienceCost("logistic-science-pack", count: 100)
            ],
            researchTime: 60,
            unlocks: TechnologyUnlocks(bonuses: [TechnologyBonus(type: .researchSpeed, modifier: 0.2)]),
            order: "z-b",
            tier: 2
        ))
    }
    
    /// Gets prerequisites for a technology
    func getPrerequisites(for techId: String) -> [Technology] {
        guard let tech = technologies[techId] else { return [] }
        return tech.prerequisites.compactMap { technologies[$0] }
    }
    
    /// Gets technologies that require this one
    func getDependents(for techId: String) -> [Technology] {
        return technologies.values.filter { $0.prerequisites.contains(techId) }
    }
}

