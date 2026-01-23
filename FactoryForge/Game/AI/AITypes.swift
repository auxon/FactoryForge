import Foundation

/// High-level goal for AI decision-making.
enum AIGoal {
    case idle
    case expandEconomy
    case research(techId: String)
    case defend
    case attack
}

/// Concrete action the AI can execute (maps to PlayerAction / GameLoop APIs).
enum AIAction {
    case build(buildingId: String, position: IntVector2, direction: Direction)
    case move(position: IntVector2)
    case attack(entityId: UInt32)
}

/// Per–AI-player state (decision timer, goal, action queue).
struct AIPlayerState {
    var decisionTimer: Float = 0
    var decisionInterval: Float = 1.0
    var currentGoal: AIGoal = .idle
    var actionQueue: [AIAction] = []
    var scriptedOpeningIndex: Int = 0
}
