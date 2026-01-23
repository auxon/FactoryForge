import Foundation

/// Manages AI players: decision loop, scripted opening, execution of build/move/attack.
/// Issues same logical actions as humans; uses GameLoop.placeBuilding(forPlayerId:) etc. for PvAI.
@available(iOS 17.0, *)
final class AIPlayerSystem: System {
    let priority: Int = SystemPriority.enemyAI.rawValue + 1

    private let world: World
    private let playerManager: PlayerManager
    private let chunkManager: ChunkManager
    private let buildingRegistry: BuildingRegistry
    private let itemRegistry: ItemRegistry
    private weak var gameLoop: GameLoop?

    private var aiState: [UInt32: AIPlayerState] = [:]
    private let decisionEngine: AIDecisionEngine
    private let economyManager: AIEconomyManager = AIEconomyManager()
    private let researchPlanner: AIResearchPlanner = AIResearchPlanner()
    private let defenseManager: AIDefenseManager = AIDefenseManager()
    private let offenseManager: AIOffenseManager = AIOffenseManager()

    /// Scripted opening: [(buildingId, offset from spawn, direction)]. Run before goal-based AI.
    private let openingBuilds: [(String, Int32, Int32, Direction)] = [
        ("burner-mining-drill", 2, 0, .north),
        ("stone-furnace", 3, 0, .north),
        ("transport_belt", 1, 0, .east),
    ]

    init(world: World, playerManager: PlayerManager, chunkManager: ChunkManager, buildingRegistry: BuildingRegistry, itemRegistry: ItemRegistry) {
        self.world = world
        self.playerManager = playerManager
        self.chunkManager = chunkManager
        self.buildingRegistry = buildingRegistry
        self.itemRegistry = itemRegistry
        self.decisionEngine = AIDecisionEngine(world: world, playerManager: playerManager, chunkManager: chunkManager, buildingRegistry: buildingRegistry, itemRegistry: itemRegistry)
    }

    func setGameLoop(_ gameLoop: GameLoop) {
        self.gameLoop = gameLoop
    }

    func update(deltaTime: Float) {
        guard let gameLoop = gameLoop else { return }

        for player in playerManager.getAllPlayers() {
            guard isAIPlayer(player) else { continue }
            let pid = player.playerId
            var state = aiState[pid] ?? AIPlayerState()
            let config = configFor(player)
            state.decisionInterval = Float(config.decisionInterval)
            state.decisionTimer -= deltaTime

            if state.decisionTimer <= 0 {
                state.decisionTimer = state.decisionInterval
                makeDecision(for: player, state: &state, gameLoop: gameLoop, config: config)
                aiState[pid] = state
            } else {
                aiState[pid] = state
            }
        }
    }

    /// Register state when adding an AI player (optional; we also create on first update).
    func registerAIPlayer(_ playerId: UInt32) {
        if aiState[playerId] == nil {
            aiState[playerId] = AIPlayerState()
        }
    }

    func unregisterAIPlayer(_ playerId: UInt32) {
        aiState.removeValue(forKey: playerId)
    }

    // MARK: - Private

    private func isAIPlayer(_ player: Player) -> Bool {
        guard let entity = playerManager.getPlayerEntity(playerId: player.playerId),
              let comp = world.get(PlayerComponent.self, for: entity) else { return false }
        return comp.isAI
    }

    private func configFor(_ player: Player) -> AIDifficultyConfig {
        guard let entity = playerManager.getPlayerEntity(playerId: player.playerId),
              let comp = world.get(PlayerComponent.self, for: entity),
              let d = comp.aiDifficulty else { return .medium }
        return AIDifficultyConfig.preset(for: d)
    }

    private func makeDecision(for player: Player, state: inout AIPlayerState, gameLoop: GameLoop, config: AIDifficultyConfig) {
        let pid = player.playerId

        if state.scriptedOpeningIndex < openingBuilds.count {
            runScriptedOpeningStep(for: player, state: &state, gameLoop: gameLoop)
            return
        }

        let (goal, actions) = decisionEngine.decide(player: player, state: state, actionBudget: config.actionBudget)
        state.currentGoal = goal
        for a in actions {
            execute(a, playerId: pid, player: player, gameLoop: gameLoop)
        }
    }

    private func runScriptedOpeningStep(for player: Player, state: inout AIPlayerState, gameLoop: GameLoop) {
        let idx = state.scriptedOpeningIndex
        guard idx < openingBuilds.count else { return }
        let (buildingId, dx, dy, dir) = openingBuilds[idx]
        let base = IntVector2(from: player.position)
        let pos = IntVector2(x: base.x + dx, y: base.y + dy)
        if gameLoop.placeBuilding(buildingId, at: pos, direction: dir, forPlayerId: player.playerId) {
            state.scriptedOpeningIndex += 1
        }
    }

    private func execute(_ action: AIAction, playerId: UInt32, player: Player, gameLoop: GameLoop) {
        switch action {
        case .build(let buildingId, let position, let direction):
            _ = gameLoop.placeBuilding(buildingId, at: position, direction: direction, forPlayerId: playerId)
        case .move(let position):
            player.position = position.toVector2 + Vector2(0.5, 0.5)
        case .attack:
            break
        }
    }
}
