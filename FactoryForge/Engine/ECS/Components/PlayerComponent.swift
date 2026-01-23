import Foundation

/// Difficulty levels for AI players
enum AIDifficulty: String, Codable {
    case easy
    case medium
    case hard
    case expert
}

/// Component attached to player entities to track player information
struct PlayerComponent: Component {
    let playerId: UInt32
    let playerName: String
    var teamId: UInt32?
    var isAI: Bool
    var aiDifficulty: AIDifficulty?
    var networkEntityId: UInt32?
    
    init(playerId: UInt32, playerName: String, teamId: UInt32? = nil, isAI: Bool = false, aiDifficulty: AIDifficulty? = nil) {
        self.playerId = playerId
        self.playerName = playerName
        self.teamId = teamId
        self.isAI = isAI
        self.aiDifficulty = aiDifficulty
        self.networkEntityId = nil
    }
}
