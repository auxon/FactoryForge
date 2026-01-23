import Foundation

/// Goal-based AI: evaluates state, picks goal, produces actions.
/// Stub implementation; extend with utility functions and layered managers.
final class AIDecisionEngine {
    private let world: World
    private let playerManager: PlayerManager
    private let chunkManager: ChunkManager
    private let buildingRegistry: BuildingRegistry
    private let itemRegistry: ItemRegistry

    init(world: World, playerManager: PlayerManager, chunkManager: ChunkManager, buildingRegistry: BuildingRegistry, itemRegistry: ItemRegistry) {
        self.world = world
        self.playerManager = playerManager
        self.chunkManager = chunkManager
        self.buildingRegistry = buildingRegistry
        self.itemRegistry = itemRegistry
    }

    /// Returns next goal and up to `actionBudget` actions for this AI player.
    func decide(player: Player, state: AIPlayerState, actionBudget: Int) -> (goal: AIGoal, actions: [AIAction]) {
        var actions: [AIAction] = []
        let goal: AIGoal = .expandEconomy
        if let build = suggestEconomyBuild(near: player.position, player: player), actionBudget > 0 {
            actions.append(build)
        }
        return (goal, actions)
    }

    /// Suggests a single economy build (e.g. miner, furnace) near position if affordable.
    private func suggestEconomyBuild(near position: Vector2, player: Player) -> AIAction? {
        let tile = IntVector2(from: position)
        let candidates: [(String, IntVector2, Direction)] = [
            ("burner-mining-drill", IntVector2(x: tile.x + 2, y: tile.y), .north),
            ("stone-furnace", IntVector2(x: tile.x + 3, y: tile.y), .north),
            ("transport_belt", IntVector2(x: tile.x + 1, y: tile.y), .east),
        ]
        for (id, pos, dir) in candidates {
            guard let def = buildingRegistry.get(id), player.inventory.has(items: def.cost) else { continue }
            return .build(buildingId: id, position: pos, direction: dir)
        }
        return nil
    }
}
