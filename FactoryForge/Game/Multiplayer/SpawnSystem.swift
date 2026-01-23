import Foundation

/// Spawns players at designated spawn points, assigns teams, optionally grants starting resources.
/// Use after LobbySystem.startMatch; operates on PlayerManager + ChunkManager.
final class SpawnSystem {
    private let world: World
    private let playerManager: PlayerManager
    private let chunkManager: ChunkManager
    private let itemRegistry: ItemRegistry

    init(world: World, playerManager: PlayerManager, chunkManager: ChunkManager, itemRegistry: ItemRegistry) {
        self.world = world
        self.playerManager = playerManager
        self.chunkManager = chunkManager
        self.itemRegistry = itemRegistry
    }

    /// Spawn points: equidistant on a circle of radius `spawnRadius` around origin.
    func spawnPoints(count: Int, radius: Float) -> [Vector2] {
        guard count > 0 else { return [] }
        if count == 1 { return [Vector2(0, 0)] }
        var points: [Vector2] = []
        let step = (2.0 * Float.pi) / Float(count)
        for i in 0..<count {
            let a = Float(i) * step
            let x = radius * cosf(a)
            let y = radius * sinf(a)
            points.append(Vector2(x, y))
        }
        return points
    }

    /// Place existing players at spawn points, assign teams from lobby slots, force-load chunks, optionally add starting resources.
    func spawnPlayers(config: MatchConfig, participants: [LobbySlot]) {
        let points = spawnPoints(count: participants.count, radius: config.spawnRadius)
        for (i, slot) in participants.enumerated() {
            guard let playerId = slot.playerId,
                  let player = playerManager.getPlayer(playerId: playerId) else { continue }
            let pos = i < points.count ? points[i] : Vector2(0, 0)
            player.position = pos

            if let entity = playerManager.getPlayerEntity(playerId: playerId) {
                if var ownership = world.get(OwnershipComponent.self, for: entity) {
                    ownership.teamId = slot.teamId
                    world.add(ownership, to: entity)
                }
                if var playerComp = world.get(PlayerComponent.self, for: entity) {
                    playerComp.teamId = slot.teamId
                    world.add(playerComp, to: entity)
                }
            }

            applyStartingResources(player: player, multiplier: config.startingResourceMultiplier)
        }

        for p in points {
            chunkManager.forceLoadInitialArea(at: p)
        }
    }

    /// Grant starting resources (e.g. iron-plate, copper-plate) scaled by multiplier.
    private func applyStartingResources(player: Player, multiplier: Float) {
        let defaults: [(String, Int)] = [
            ("iron-plate", 8),
            ("copper-plate", 8),
            ("wood", 4),
        ]
        for (itemId, base) in defaults {
            let count = max(0, Int(Float(base) * multiplier))
            guard count > 0, let def = itemRegistry.get(itemId) else { continue }
            _ = player.inventory.add(itemId: itemId, count: count, maxStack: def.stackSize)
        }
    }
}
