import Foundation

/// Game mode for PvP / PvAI matches.
enum GameMode: String, Codable {
    case freeForAll       // Last player/team standing
    case teamDeathmatch   // Team elimination
    case territoryControl // Control points (future)
    case kingOfTheHill    // Time-based control (future)
}

/// Configuration for a multiplayer match (lobby → match start).
struct MatchConfig: Codable {
    var gameMode: GameMode
    var seed: UInt64
    var maxPlayers: UInt32
    var teamCount: UInt32       // 0 = FFA (no teams), 2+ = team modes
    var spawnRadius: Float      // Distance from origin for spawn points
    var startingResourceMultiplier: Float  // 1.0 = default starting items

    init(
        gameMode: GameMode = .freeForAll,
        seed: UInt64 = UInt64.random(in: 0...UInt64.max),
        maxPlayers: UInt32 = 4,
        teamCount: UInt32 = 0,
        spawnRadius: Float = 12,
        startingResourceMultiplier: Float = 1.0
    ) {
        self.gameMode = gameMode
        self.seed = seed
        self.maxPlayers = maxPlayers
        self.teamCount = teamCount
        self.spawnRadius = spawnRadius
        self.startingResourceMultiplier = startingResourceMultiplier
    }
}

/// A slot in the pre-game lobby (player info + ready).
struct LobbySlot: Codable {
    var playerId: UInt32?
    var displayName: String
    var isReady: Bool
    var teamId: UInt32?
    var isAI: Bool

    init(displayName: String = "Empty", isReady: Bool = false, teamId: UInt32? = nil, isAI: Bool = false, playerId: UInt32? = nil) {
        self.playerId = playerId
        self.displayName = displayName
        self.isReady = isReady
        self.teamId = teamId
        self.isAI = isAI
    }
}
