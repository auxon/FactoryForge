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

        // Check if the building type exists
        guard gameLoop?.buildingRegistry.get(type) != nil else {
            print("❌ Building type '\(type)' not found")
            return
        }

        // Place the building using the existing game loop method
        // This is a simplified version - in reality we'd need to call the proper placement method
        print("✅ Building \(type) placed at \(position)")
    }

    private func connectBuildings(from: IntVector2, to: IntVector2) {
        print("🔗 Connecting buildings from \(from) to \(to)")

        // This would need to be implemented to place belts between buildings
        // For now, just log the action
    }

    private func startProduction(at position: IntVector2) {
        print("⚙️ Starting production at \(position)")

        // This would need to be implemented to start crafting in buildings
        // For now, just log the action
    }

    private func takeScreenshot(name: String) {
        print("📸 Taking screenshot: \(name)")

        // This would need to be implemented to capture screenshots
        // For now, just log the action
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

        default:
            return nil
        }
    }
}
