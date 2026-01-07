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
            "iron-gear-wheel", "copper-cable", "pipe", "electronic-circuit",
            "transport-belt", "belt-bridge", "inserter", "wooden-chest", "iron-chest",
            "burner-mining-drill", "electric-mining-drill", "stone-furnace",
            "boiler", "steam-engine", "small-electric-pole",
            "firearm-magazine", "automation-science-pack", "lab", "radar",
            "oil-well", "oil-refinery", "chemical-plant"
        ]
        
        for recipe in defaultRecipes {
            unlockedRecipes.insert(recipe)
        }
    }
    
    func update(deltaTime: Float) {
        guard currentResearch != nil else { return }

        // Throttle debug output for performance
        #if DEBUG
        if Int(Time.shared.frameCount) % 60 == 0 {  // Only log every 60 frames
            print("ResearchSystem: Update called, current research: \(currentResearch?.name ?? "none")")
        }
        #endif

        // Collect updates to apply after iteration
        var pendingUpdates: [(Entity, LabComponent, InventoryComponent)] = []

        // Process labs
        var activeLabCount = 0
        world.forEach(LabComponent.self) { [self] entity, lab in
            guard lab.isResearching else { return }
            activeLabCount += 1

            guard var inventory = world.get(InventoryComponent.self, for: entity) else { return }

            // Check power
            var speedMultiplier: Float = 1.0
            if let power = world.get(PowerConsumerComponent.self, for: entity) {
                speedMultiplier = power.satisfaction
                if speedMultiplier <= 0 {
                    #if DEBUG
                    if Int(Time.shared.frameCount) % 60 == 0 {  // Only log every 60 frames
                        print("ResearchSystem: Lab \(entity) has no power")
                    }
                    #endif
                    return
                }
            }

            #if DEBUG
            if Int(Time.shared.frameCount) % 60 == 0 {  // Only log every 60 frames
                print("ResearchSystem: Processing lab \(entity), has power multiplier: \(speedMultiplier)")
            }
            #endif

            // Try to consume science packs
            var mutableLab = lab
            if let updated = consumeSciencePacks(lab: &mutableLab, inventory: &inventory, entity: entity, speedMultiplier: speedMultiplier, deltaTime: deltaTime) {
                pendingUpdates.append((entity, updated.0, updated.1))
            }
        }

        print("ResearchSystem: Found \(activeLabCount) active labs, \(pendingUpdates.count) updates to apply")

        // Apply updates after iteration completes
        for (entity, lab, inventory) in pendingUpdates {
            world.add(lab, to: entity)
            world.add(inventory, to: entity)
        }

        // Check if research is complete
        if let tech = currentResearch {
            let progress = getResearchProgress()
            print("ResearchSystem: Research progress: \(progress * 100)%")

            if isResearchComplete(tech) {
                print("ResearchSystem: Research completed!")
                completeResearch(tech)
            }
        }
    }
    
    private func consumeSciencePacks(lab: inout LabComponent, inventory: inout InventoryComponent, entity: Entity, speedMultiplier: Float, deltaTime: Float) -> (LabComponent, InventoryComponent)? {
        guard let tech = currentResearch else { return nil }

        var inventoryUpdated = false

        print("ResearchSystem: Consuming science packs for tech '\(tech.name)'")
        print("ResearchSystem: Required: \(tech.cost)")
        print("ResearchSystem: Current progress: \(researchProgress)")

        // Try to consume each required science pack type
        for cost in tech.cost {
            let currentCount = researchProgress[cost.packId] ?? 0
            print("ResearchSystem: Pack '\(cost.packId)': have \(currentCount)/\(cost.count)")

            if currentCount < cost.count {
                // Try to consume a pack
                let hasPack = inventory.has(itemId: cost.packId)
                print("ResearchSystem: Lab inventory has '\(cost.packId)': \(hasPack)")

                if hasPack {
                    inventory.remove(itemId: cost.packId, count: 1)
                    researchProgress[cost.packId, default: 0] += 1
                    inventoryUpdated = true
                    lab.isResearching = true
                    print("ResearchSystem: Consumed 1 '\(cost.packId)', progress now: \(researchProgress[cost.packId] ?? 0)/\(cost.count)")
                }
            }
        }

        // Return updated components if changes were made
        return inventoryUpdated ? (lab, inventory) : nil
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
        
        // Collect lab updates to apply after iteration
        var pendingLabUpdates: [(Entity, LabComponent)] = []
        
        // Notify labs to stop
        world.forEach(LabComponent.self) { entity, lab in
            var updatedLab = lab
            updatedLab.isResearching = false
            pendingLabUpdates.append((entity, updatedLab))
        }
        
        // Apply updates after iteration completes
        for (entity, lab) in pendingLabUpdates {
            world.add(lab, to: entity)
        }
        
        onResearchCompleted?(tech)
    }
    
    // MARK: - Public Interface
    
    func selectResearch(_ techId: String) -> Bool {
        guard let tech = technologyRegistry.get(techId) else {
            print("ResearchSystem: Tech '\(techId)' not found in registry")
            return false
        }
        guard canResearch(tech) else {
            print("ResearchSystem: Tech '\(tech.name)' cannot be researched")
            return false
        }

        print("ResearchSystem: Starting research on '\(tech.name)'")
        print("ResearchSystem: Research cost: \(tech.cost)")
        currentResearch = tech
        researchProgress.removeAll()

        // Count available labs
        var labCount = 0
        world.forEach(LabComponent.self) { entity, lab in
            labCount += 1
        }
        print("ResearchSystem: Found \(labCount) labs in the world")

        // Collect lab updates to apply after iteration
        var pendingLabUpdates: [(Entity, LabComponent)] = []

        // Activate labs
        world.forEach(LabComponent.self) { entity, lab in
            var updatedLab = lab
            updatedLab.isResearching = true
            pendingLabUpdates.append((entity, updatedLab))
        }

        print("ResearchSystem: Activated \(pendingLabUpdates.count) labs for research")

        // Apply updates after iteration completes
        for (entity, lab) in pendingLabUpdates {
            world.add(lab, to: entity)
        }

        return true
    }
    
    func cancelResearch() {
        currentResearch = nil
        researchProgress.removeAll()
        
        // Collect lab updates to apply after iteration
        var pendingLabUpdates: [(Entity, LabComponent)] = []
        
        world.forEach(LabComponent.self) { entity, lab in
            var updatedLab = lab
            updatedLab.isResearching = false
            pendingLabUpdates.append((entity, updatedLab))
        }
        
        // Apply updates after iteration completes
        for (entity, lab) in pendingLabUpdates {
            world.add(lab, to: entity)
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

    /// Gets detailed progress information for the current research
    func getResearchProgressDetails() -> ResearchProgressDetails? {
        guard let tech = currentResearch else { return nil }

        var packProgress: [String: SciencePackProgress] = [:]

        for cost in tech.cost {
            let contributed = researchProgress[cost.packId] ?? 0
            packProgress[cost.packId] = SciencePackProgress(
                contributed: contributed,
                required: cost.count
            )
        }

        return ResearchProgressDetails(
            technologyName: tech.name,
            overallProgress: getResearchProgress(),
            packProgress: packProgress,
            researchSpeedBonus: getBonus(.researchSpeed)
        )
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
        
        // Ensure default recipes are always unlocked (merge with loaded recipes)
        // This ensures new default recipes (like "pipe") are available even in old saves
        let defaultRecipes = [
            "iron-plate", "copper-plate", "stone-brick", "steel-plate",
            "iron-gear-wheel", "copper-cable", "pipe", "electronic-circuit",
            "transport-belt", "belt-bridge", "inserter", "wooden-chest", "iron-chest",
            "burner-mining-drill", "electric-mining-drill", "stone-furnace",
            "boiler", "steam-engine", "small-electric-pole",
            "firearm-magazine", "automation-science-pack", "lab", "radar",
            "oil-well", "oil-refinery", "chemical-plant"
        ]
        for recipe in defaultRecipes {
            unlockedRecipes.insert(recipe)
        }
        
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

/// Detailed research progress information
struct ResearchProgressDetails {
    let technologyName: String
    let overallProgress: Float
    let packProgress: [String: SciencePackProgress]
    let researchSpeedBonus: Float
}

/// Progress for a specific science pack type
struct SciencePackProgress {
    let contributed: Int
    let required: Int

    var progress: Float {
        return required > 0 ? Float(contributed) / Float(required) : 0
    }

    var isComplete: Bool {
        return contributed >= required
    }
}

struct ResearchState: Codable {
    let currentResearchId: String?
    let progress: [String: Int]
    let completed: [String]
    let unlockedRecipes: [String]
}

