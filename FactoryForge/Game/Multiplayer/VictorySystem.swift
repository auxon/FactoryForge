import Foundation

/// Victory result when match ends.
enum VictoryResult {
    case none
    case lastStanding(playerId: UInt32)
    case teamVictory(teamId: UInt32)
    case draw
}

/// Tracks victory conditions per game mode; ends match and reports result.
final class VictorySystem {
    private let world: World
    private let playerManager: PlayerManager
    private var gameMode: GameMode
    private var hasEnded: Bool = false

    var onMatchEnd: ((VictoryResult) -> Void)?

    init(world: World, playerManager: PlayerManager, gameMode: GameMode = .freeForAll) {
        self.world = world
        self.playerManager = playerManager
        self.gameMode = gameMode
    }

    func setGameMode(_ mode: GameMode) {
        gameMode = mode
    }

    func reset() {
        hasEnded = false
    }

    /// Call each tick (e.g. from GameLoop). Evaluates victory; calls onMatchEnd once when met.
    func update() {
        guard !hasEnded else { return }
        let result = evaluateVictory()
        switch result {
        case .none:
            break
        case .lastStanding, .teamVictory, .draw:
            hasEnded = true
            onMatchEnd?(result)
        }
    }

    private func evaluateVictory() -> VictoryResult {
        let all = playerManager.getAllPlayers()
        let alive = all.filter { !$0.isDead }
        if alive.isEmpty { return .draw }

        switch gameMode {
        case .freeForAll:
            if alive.count == 1 {
                return .lastStanding(playerId: alive[0].playerId)
            }
            return .none

        case .teamDeathmatch:
            let teamsWithAlive = Set(alive.compactMap { p in
                playerManager.getPlayerEntity(playerId: p.playerId).flatMap { e in
                    world.get(OwnershipComponent.self, for: e)?.teamId
                }
            })
            if teamsWithAlive.count == 1, let teamId = teamsWithAlive.first {
                return .teamVictory(teamId: teamId)
            }
            return .none

        case .territoryControl, .kingOfTheHill:
            // Placeholder: no victory until implemented
            return .none
        }
    }
}
