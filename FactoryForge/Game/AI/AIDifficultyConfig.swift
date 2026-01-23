import Foundation

/// Difficulty knobs for AI players (Task 5.4).
struct AIDifficultyConfig {
    var reactionDelay: TimeInterval
    var decisionInterval: TimeInterval
    var actionBudget: Int
    var resourceHandicap: Float
    var scoutingAccuracy: Float
    var tacticalSkill: Float

    init(
        reactionDelay: TimeInterval = 0.2,
        decisionInterval: TimeInterval = 1.0,
        actionBudget: Int = 3,
        resourceHandicap: Float = 1.0,
        scoutingAccuracy: Float = 1.0,
        tacticalSkill: Float = 0.5
    ) {
        self.reactionDelay = reactionDelay
        self.decisionInterval = decisionInterval
        self.actionBudget = actionBudget
        self.resourceHandicap = resourceHandicap
        self.scoutingAccuracy = scoutingAccuracy
        self.tacticalSkill = tacticalSkill
    }

    static let easy = AIDifficultyConfig(
        reactionDelay: 0.8,
        decisionInterval: 2.0,
        actionBudget: 1,
        resourceHandicap: 0.6,
        scoutingAccuracy: 0.4,
        tacticalSkill: 0.2
    )
    static let medium = AIDifficultyConfig(
        reactionDelay: 0.4,
        decisionInterval: 1.0,
        actionBudget: 2,
        resourceHandicap: 0.85,
        scoutingAccuracy: 0.7,
        tacticalSkill: 0.5
    )
    static let hard = AIDifficultyConfig(
        reactionDelay: 0.15,
        decisionInterval: 0.6,
        actionBudget: 4,
        resourceHandicap: 1.0,
        scoutingAccuracy: 0.9,
        tacticalSkill: 0.75
    )
    static let expert = AIDifficultyConfig(
        reactionDelay: 0.05,
        decisionInterval: 0.4,
        actionBudget: 6,
        resourceHandicap: 1.0,
        scoutingAccuracy: 1.0,
        tacticalSkill: 1.0
    )

    static func preset(for difficulty: AIDifficulty) -> AIDifficultyConfig {
        switch difficulty {
        case .easy: return .easy
        case .medium: return .medium
        case .hard: return .hard
        case .expert: return .expert
        }
    }
}
