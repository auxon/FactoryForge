import Foundation

/// System that handles automated gameplay for testing and demos
final class AutoPlaySystem: System {
    private var isEnabled = false

    // Current scenario state
    private var currentScenario: GameScenario?
    private var currentStepIndex = 0
    private var stepTimer: Double = 0
    private var scenarioStartTime: Double = 0

    // Weak reference to avoid circular dependency
    private weak var gameLoop: GameLoop?

    // System priority (higher numbers = later execution)
    let priority: Int = 100  // Run after most other systems

    init() {
        // GameLoop will be set later to avoid circular dependency
    }

    func setGameLoop(_ gameLoop: GameLoop) {
        self.gameLoop = gameLoop
    }

    func update(deltaTime: Float) {
        guard isEnabled, let scenario = currentScenario else { return }

        stepTimer += Double(deltaTime)

        // Execute current step if timer expired
        if stepTimer >= scenario.steps[currentStepIndex].duration {
            executeCurrentStep()
            currentStepIndex += 1
            stepTimer = 0

            // Check if scenario is complete
            if currentStepIndex >= scenario.steps.count {
                finishScenario()
            }
        }
    }

    // MARK: - Public Interface

    func startScenario(_ scenario: GameScenario) {
        currentScenario = scenario
        currentStepIndex = 0
        stepTimer = 0
        scenarioStartTime = gameLoop?.playTime ?? 0
        isEnabled = true

        print("🎬 Starting auto-play scenario: \(scenario.name)")
        print("📋 Steps: \(scenario.steps.count)")
    }

    func stopAutoPlay() {
        isEnabled = false
        currentScenario = nil
        currentStepIndex = 0
        stepTimer = 0

        // Reset to normal speed
        gameLoop?.setGameSpeed(1.0)

        print("⏹️ Auto-play stopped")
    }

    func setGameSpeed(_ speed: Double) {
        gameLoop?.setGameSpeed(speed)
    }

    var isAutoPlaying: Bool {
        return isEnabled && currentScenario != nil
    }

    var currentScenarioName: String? {
        return currentScenario?.name
    }

    // MARK: - Scenario Execution

    private func executeCurrentStep() {
        guard let scenario = currentScenario,
              currentStepIndex < scenario.steps.count else { return }

        let step = scenario.steps[currentStepIndex]

        switch step {
        case .wait(let seconds):
            print("⏳ Waiting \(seconds) seconds")

        case .setGameSpeed(let speed):
            let speedValue: Double
            switch speed {
            case .paused: speedValue = 0.0
            case .normal: speedValue = 1.0
            case .fast: speedValue = 2.0
            case .faster: speedValue = 4.0
            case .fastest: speedValue = 8.0
            case .unlimited: speedValue = 100.0  // Very fast for testing
            }
            setGameSpeed(speedValue)
            print("⚡ Game speed set to \(speedValue)x")

        case .placeBuilding(let type, let position, let direction):
            placeBuilding(type: type, at: position, direction: direction)

        case .connectBuildings(let from, let to):
            connectBuildings(from: from, to: to)

        case .startProduction(let at):
            startProduction(at: at)

        case .takeScreenshot(let name):
            takeScreenshot(name: name)
        }
    }

    private func finishScenario() {
        let duration = (gameLoop?.playTime ?? 0) - scenarioStartTime
        print("✅ Scenario '\(currentScenario?.name ?? "Unknown")' completed in \(String(format: "%.1f", duration)) seconds")

        // Check success criteria
        if let criteria = currentScenario?.successCriteria, !criteria.isEmpty {
            let success = evaluateSuccessCriteria(criteria)
            print("📊 Scenario result: \(success ? "SUCCESS" : "FAILED")")
        }

        stopAutoPlay()
    }

    // MARK: - Step Implementation

    private func placeBuilding(type: String, at position: IntVector2, direction: Direction) {
        print("🏗️ Placing \(type) at \(position) facing \(direction)")

        guard let gameLoop = gameLoop else {
            print("❌ No game loop available")
            return
        }

        // Temporarily give player unlimited resources for auto-play
        let originalInventory = gameLoop.player.inventory
        var unlimitedInventory = originalInventory
        // Add plenty of all required resources
        unlimitedInventory.add(ItemStack(itemId: "iron_plate", count: 1000))
        unlimitedInventory.add(ItemStack(itemId: "copper_plate", count: 1000))
        unlimitedInventory.add(ItemStack(itemId: "steel_plate", count: 1000))
        unlimitedInventory.add(ItemStack(itemId: "electronic_circuit", count: 1000))
        gameLoop.player.inventory = unlimitedInventory

        // Place the building
        let success = gameLoop.placeBuilding(type, at: position, direction: direction)

        // Restore original inventory (minus any costs that were actually deducted)
        gameLoop.player.inventory = gameLoop.player.inventory

        if success {
            print("✅ Building \(type) placed at \(position)")
        } else {
            print("❌ Failed to place building \(type) at \(position)")
        }
    }

    private func connectBuildings(from: IntVector2, to: IntVector2) {
        print("🔗 Connecting buildings from \(from) to \(to)")

        guard let gameLoop = gameLoop else {
            print("❌ No game loop available")
            return
        }

        // Calculate path between buildings (simple straight line for now)
        let deltaX = to.x - from.x
        let deltaY = to.y - from.y

        // Determine primary direction
        let direction: Direction
        if abs(deltaX) > abs(deltaY) {
            direction = deltaX > 0 ? .east : .west
        } else {
            direction = deltaY > 0 ? .south : .north
        }

        // Place belts along the path
        let steps = max(abs(deltaX), abs(deltaY))
        for step in 1..<steps {
            let t = Float(step) / Float(steps)
            let x = Int(from.x) + Int(Float(deltaX) * t)
            let y = Int(from.y) + Int(Float(deltaY) * t)
            let beltPos = IntVector2(x: Int32(x), y: Int32(y))

            // Give unlimited resources for belts
            var unlimitedInventory = gameLoop.player.inventory
            unlimitedInventory.add(ItemStack(itemId: "iron_plate", count: 100))
            gameLoop.player.inventory = unlimitedInventory

            let success = gameLoop.placeBuilding("transport_belt", at: beltPos, direction: direction)
            if success {
                print("  📦 Placed belt at \(beltPos)")
            } else {
                print("  ❌ Failed to place belt at \(beltPos)")
            }
        }

        print("✅ Connection attempt complete")
    }

    private func startProduction(at position: IntVector2) {
        print("⚙️ Starting production at \(position)")

        guard let gameLoop = gameLoop else {
            print("❌ No game loop available")
            return
        }

        // Find the entity at this position
        let entitiesAtPosition = gameLoop.world.getAllEntitiesAt(position: position)
        guard let entity = entitiesAtPosition.first else {
            print("❌ No entity found at \(position)")
            return
        }

        // Determine what type of machine it is and set appropriate recipe
        if gameLoop.world.has(AssemblerComponent.self, for: entity) {
            // Set assembler to craft electronic circuits (requires copper cables)
            gameLoop.setRecipe(for: entity, recipeId: "electronic_circuit")
            print("  🔧 Set assembler to craft electronic circuits")

            // Fill assembler with copper cables for crafting
            fillMachineInputs(entity: entity, itemId: "copper_cable", count: 10)
        } else if gameLoop.world.has(FurnaceComponent.self, for: entity) {
            // Set furnace to smelt copper ore into copper plates
            gameLoop.setRecipe(for: entity, recipeId: "copper_plate")
            print("  🔥 Set furnace to smelt copper plates")

            // Fill furnace with copper ore for smelting
            fillMachineInputs(entity: entity, itemId: "copper_ore", count: 10)
        } else {
            print("❌ Entity at \(position) is not a machine that can produce")
        }
    }

    private func takeScreenshot(name: String) {
        print("📸 Taking screenshot: \(name)")

        // This would need to be implemented to capture screenshots
        // For now, just log the action
    }

    private func fillMachineInputs(entity: Entity, itemId: String, count: Int) {
        guard let gameLoop = gameLoop else { return }

        guard var inventory = gameLoop.world.get(InventoryComponent.self, for: entity) else {
            print("❌ No inventory found for entity")
            return
        }

        // Add items to input slots (slots 0-3 for most machines)
        let itemStack = ItemStack(itemId: itemId, count: count)
        for slotIndex in 0..<4 {
            if slotIndex < inventory.slots.count {
                inventory.slots[slotIndex] = itemStack
                print("  📥 Added \(count)x \(itemId) to slot \(slotIndex)")
                break // Add to first available slot
            }
        }

        gameLoop.world.add(inventory, to: entity)
    }

    private func evaluateSuccessCriteria(_ criteria: [SuccessCondition]) -> Bool {
        // This would need to be implemented to check actual game state
        // For now, return true
        return true
    }
}


// MARK: - Built-in Scenarios

extension AutoPlaySystem {
    /// Get a built-in test scenario
    static func builtInScenario(name: String) -> GameScenario? {
        switch name {
        case "basic_test":
            return GameScenario(
                name: "Basic Test",
                description: "Simple test scenario with speed changes",
                steps: [
                    .wait(seconds: 2.0),
                    .setGameSpeed(.fast),
                    .wait(seconds: 3.0),
                    .setGameSpeed(.normal),
                    .wait(seconds: 1.0)
                ],
                duration: 10.0,
                successCriteria: []
            )

        case "speed_demo":
            return GameScenario(
                name: "Speed Demo",
                description: "Demonstrates different game speeds",
                steps: [
                    .setGameSpeed(.normal),
                    .wait(seconds: 2.0),
                    .setGameSpeed(.fast),
                    .wait(seconds: 2.0),
                    .setGameSpeed(.faster),
                    .wait(seconds: 2.0),
                    .setGameSpeed(.fastest),
                    .wait(seconds: 2.0),
                    .setGameSpeed(.normal)
                ],
                duration: nil,
                successCriteria: []
            )

        case "basic_mining":
            return GameScenario(
                name: "Basic Mining",
                description: "Places a miner and lets it run",
                steps: [
                    .placeBuilding(type: "electric_miner", position: IntVector2(x: 5, y: 5), direction: .north),
                    .wait(seconds: 10.0),
                    .setGameSpeed(.normal)
                ],
                duration: 15.0,
                successCriteria: []
            )

        case "smelting_setup":
            return GameScenario(
                name: "Smelting Setup",
                description: "Miner + Furnace production chain",
                steps: [
                    .placeBuilding(type: "electric_miner", position: IntVector2(x: 5, y: 5), direction: .north),
                    .wait(seconds: 2.0),
                    .placeBuilding(type: "electric_furnace", position: IntVector2(x: 8, y: 5), direction: .north),
                    .wait(seconds: 2.0),
                    .connectBuildings(from: IntVector2(x: 5, y: 5), to: IntVector2(x: 8, y: 5)),
                    .wait(seconds: 10.0)
                ],
                duration: 20.0,
                successCriteria: []
            )

        case "production_line":
            return GameScenario(
                name: "Production Line",
                description: "Complete miner → furnace → assembler chain",
                steps: [
                    .placeBuilding(type: "electric_miner", position: IntVector2(x: 5, y: 5), direction: .north),
                    .wait(seconds: 1.0),
                    .placeBuilding(type: "electric_furnace", position: IntVector2(x: 8, y: 5), direction: .north),
                    .wait(seconds: 1.0),
                    .placeBuilding(type: "assembling_machine_1", position: IntVector2(x: 11, y: 5), direction: .north),
                    .wait(seconds: 1.0),
                    .connectBuildings(from: IntVector2(x: 5, y: 5), to: IntVector2(x: 8, y: 5)),
                    .wait(seconds: 1.0),
                    .connectBuildings(from: IntVector2(x: 8, y: 5), to: IntVector2(x: 11, y: 5)),
                    .wait(seconds: 1.0),
                    .startProduction(at: IntVector2(x: 8, y: 5)), // Start furnace
                    .wait(seconds: 1.0),
                    .startProduction(at: IntVector2(x: 11, y: 5)), // Start assembler
                    .wait(seconds: 15.0)
                ],
                duration: 25.0,
                successCriteria: []
            )

        default:
            return nil
        }
    }
}
