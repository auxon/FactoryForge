import Foundation

/// System that handles research progression
final class ResearchSystem: System {
    let priority = SystemPriority.research.rawValue
    
    private let world: World
    private let technologyRegistry: TechnologyRegistry
    
    /// Currently researched technology
    private(set) var currentResearch: Technology?
    
    /// Progress toward current research (science packs contributed)
    private var researchProgress: [String: Int] = [:]
    
    /// Completed technologies
    private(set) var completedTechnologies: Set<String> = []
    
    /// Unlocked recipes
    private(set) var unlockedRecipes: Set<String> = []
    
    /// Research bonuses from completed tech
    private var bonuses: [TechnologyBonus.BonusType: Float] = [:]
    
    /// Callback when research completes
    var onResearchCompleted: ((Technology) -> Void)?
    
    init(world: World, technologyRegistry: TechnologyRegistry) {
        self.world = world
        self.technologyRegistry = technologyRegistry
        
        // Initialize default unlocked recipes
        initializeDefaultUnlocks()
    }
    
    private func initializeDefaultUnlocks() {
        // Recipes available from the start
        let defaultRecipes = [
            "iron-plate", "copper-plate", "stone-brick", "steel-plate",
            "iron-gear-wheel", "copper-cable", "electronic-circuit",
            "transport-belt", "inserter", "wooden-chest", "iron-chest",
            "burner-mining-drill", "electric-mining-drill", "stone-furnace",
            "boiler", "steam-engine", "small-electric-pole",
            "firearm-magazine", "automation-science-pack", "lab", "radar"
        ]
        
        for recipe in defaultRecipes {
            unlockedRecipes.insert(recipe)
        }
    }
    
    func update(deltaTime: Float) {
        guard currentResearch != nil else { return }
        
        // Process labs
        world.forEach(LabComponent.self) { [self] entity, lab in
            guard lab.isResearching else { return }
            guard var inventory = world.get(InventoryComponent.self, for: entity) else { return }
            
            // Check power
            var speedMultiplier: Float = 1.0
            if let power = world.get(PowerConsumerComponent.self, for: entity) {
                speedMultiplier = power.satisfaction
                if speedMultiplier <= 0 { return }
            }
            
            // Try to consume science packs
            consumeSciencePacks(lab: &lab, inventory: &inventory, entity: entity, speedMultiplier: speedMultiplier, deltaTime: deltaTime)
        }
        
        // Check if research is complete
        if let tech = currentResearch, isResearchComplete(tech) {
            completeResearch(tech)
        }
    }
    
    private func consumeSciencePacks(lab: inout LabComponent, inventory: inout InventoryComponent, entity: Entity, speedMultiplier: Float, deltaTime: Float) {
        guard let tech = currentResearch else { return }
        
        // Try to consume each required science pack type
        for cost in tech.cost {
            let currentCount = researchProgress[cost.packId] ?? 0
            if currentCount < cost.count {
                // Try to consume a pack
                if inventory.has(itemId: cost.packId) {
                    inventory.remove(itemId: cost.packId, count: 1)
                    researchProgress[cost.packId, default: 0] += 1
                    world.add(inventory, to: entity)
                    
                    lab.isResearching = true
                }
            }
        }
    }
    
    private func isResearchComplete(_ tech: Technology) -> Bool {
        for cost in tech.cost {
            let currentCount = researchProgress[cost.packId] ?? 0
            if currentCount < cost.count {
                return false
            }
        }
        return true
    }
    
    private func completeResearch(_ tech: Technology) {
        completedTechnologies.insert(tech.id)
        
        // Unlock recipes
        for recipe in tech.unlocks.recipes {
            unlockedRecipes.insert(recipe)
        }
        
        // Apply bonuses
        for bonus in tech.unlocks.bonuses {
            bonuses[bonus.type, default: 0] += bonus.modifier
        }
        
        currentResearch = nil
        researchProgress.removeAll()
        
        // Notify labs to stop
        world.forEach(LabComponent.self) { entity, lab in
            var updatedLab = lab
            updatedLab.isResearching = false
            world.add(updatedLab, to: entity)
        }
        
        onResearchCompleted?(tech)
    }
    
    // MARK: - Public Interface
    
    func selectResearch(_ techId: String) -> Bool {
        guard let tech = technologyRegistry.get(techId) else { return false }
        guard canResearch(tech) else { return false }
        
        currentResearch = tech
        researchProgress.removeAll()
        
        // Activate labs
        world.forEach(LabComponent.self) { entity, lab in
            var updatedLab = lab
            updatedLab.isResearching = true
            world.add(updatedLab, to: entity)
        }
        
        return true
    }
    
    func cancelResearch() {
        currentResearch = nil
        researchProgress.removeAll()
        
        world.forEach(LabComponent.self) { entity, lab in
            var updatedLab = lab
            updatedLab.isResearching = false
            world.add(updatedLab, to: entity)
        }
    }
    
    func canResearch(_ tech: Technology) -> Bool {
        // Already completed
        if completedTechnologies.contains(tech.id) {
            return false
        }
        
        // Check prerequisites
        for prereq in tech.prerequisites {
            if !completedTechnologies.contains(prereq) {
                return false
            }
        }
        
        return true
    }
    
    func getResearchProgress() -> Float {
        guard let tech = currentResearch else { return 0 }
        
        var totalRequired = 0
        var totalContributed = 0
        
        for cost in tech.cost {
            totalRequired += cost.count
            totalContributed += researchProgress[cost.packId] ?? 0
        }
        
        return totalRequired > 0 ? Float(totalContributed) / Float(totalRequired) : 0
    }
    
    func isRecipeUnlocked(_ recipeId: String) -> Bool {
        return unlockedRecipes.contains(recipeId)
    }
    
    func getBonus(_ type: TechnologyBonus.BonusType) -> Float {
        return bonuses[type] ?? 0
    }
    
    func getAvailableResearch() -> [Technology] {
        return technologyRegistry.all.filter { canResearch($0) }
    }
    
    // MARK: - Serialization
    
    func getState() -> ResearchState {
        return ResearchState(
            currentResearchId: currentResearch?.id,
            progress: researchProgress,
            completed: Array(completedTechnologies),
            unlockedRecipes: Array(unlockedRecipes)
        )
    }
    
    func loadState(_ state: ResearchState) {
        if let currentId = state.currentResearchId {
            currentResearch = technologyRegistry.get(currentId)
        }
        researchProgress = state.progress
        completedTechnologies = Set(state.completed)
        unlockedRecipes = Set(state.unlockedRecipes)
        
        // Rebuild bonuses
        bonuses.removeAll()
        for techId in completedTechnologies {
            if let tech = technologyRegistry.get(techId) {
                for bonus in tech.unlocks.bonuses {
                    bonuses[bonus.type, default: 0] += bonus.modifier
                }
            }
        }
    }
}

struct ResearchState: Codable {
    let currentResearchId: String?
    let progress: [String: Int]
    let completed: [String]
    let unlockedRecipes: [String]
}

