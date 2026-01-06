import Foundation

/// Represents a complete automated test scenario
struct GameScenario {
    let name: String
    let description: String
    let steps: [ScenarioStep]
    let duration: TimeInterval?
    let successCriteria: [SuccessCondition]

    init(name: String, description: String, steps: [ScenarioStep], duration: TimeInterval?, successCriteria: [SuccessCondition]) {
        self.name = name
        self.description = description
        self.steps = steps
        self.duration = duration
        self.successCriteria = successCriteria
    }
}

/// Individual steps in a scenario
enum ScenarioStep {
    case wait(seconds: Double)
    case placeBuilding(type: String, position: IntVector2, direction: Direction)
    case connectBuildings(from: IntVector2, to: IntVector2)
    case startProduction(at: IntVector2)
    case setGameSpeed(GameSpeed)
    case takeScreenshot(name: String)

    public var duration: Double {
        switch self {
        case .wait(let seconds): return seconds
        case .setGameSpeed: return 0.0
        case .placeBuilding: return 0.0
        case .connectBuildings: return 0.0
        case .startProduction: return 0.0
        case .takeScreenshot: return 0.0
        }
    }
}

/// Game speed settings for auto-play
enum GameSpeed {
    case paused        // 0x speed
    case normal        // 1x speed
    case fast          // 2x speed
    case faster        // 4x speed
    case fastest       // 8x speed
    case unlimited     // Max speed for testing
}

/// Success conditions for scenario evaluation
enum SuccessCondition {
    case buildingCount(type: String, count: Int)
    case productionRate(item: String, rate: Double)
    case timeLimit(seconds: Double)
}
