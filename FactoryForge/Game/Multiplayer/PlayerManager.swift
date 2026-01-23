import Foundation

/// Manages multiple player instances for multiplayer support
final class PlayerManager {
    private var players: [UInt32: Player] = [:]
    private var playerEntities: [UInt32: Entity] = [:]
    private var nextPlayerId: UInt32 = 1
    private let world: World
    private let itemRegistry: ItemRegistry
    
    init(world: World, itemRegistry: ItemRegistry) {
        self.world = world
        self.itemRegistry = itemRegistry
    }
    
    /// Creates a new player and returns their player ID
    func createPlayer(name: String, isAI: Bool = false, teamId: UInt32? = nil, aiDifficulty: AIDifficulty? = nil) -> UInt32 {
        let playerId = nextPlayerId
        nextPlayerId += 1
        
        let player = Player(world: world, itemRegistry: itemRegistry, playerId: playerId)
        players[playerId] = player
        
        // Add PlayerComponent to player entity
        let playerComponent = PlayerComponent(
            playerId: playerId,
            playerName: name,
            teamId: teamId,
            isAI: isAI,
            aiDifficulty: aiDifficulty
        )
        world.add(playerComponent, to: player.playerEntity)
        
        // Add OwnershipComponent
        let ownership = OwnershipComponent(ownerPlayerId: playerId, teamId: teamId)
        world.add(ownership, to: player.playerEntity)
        
        playerEntities[playerId] = player.playerEntity
        return playerId
    }
    
    /// Removes a player from the game
    func removePlayer(playerId: UInt32) {
        if let entity = playerEntities[playerId] {
            world.despawn(entity)
        }
        players.removeValue(forKey: playerId)
        playerEntities.removeValue(forKey: playerId)
    }
    
    /// Gets a player by ID
    func getPlayer(playerId: UInt32) -> Player? {
        return players[playerId]
    }
    
    /// Gets the entity for a player
    func getPlayerEntity(playerId: UInt32) -> Entity? {
        return playerEntities[playerId]
    }
    
    /// Gets all players
    func getAllPlayers() -> [Player] {
        return Array(players.values)
    }
    
    /// Gets all players on a specific team
    func getPlayersOnTeam(teamId: UInt32) -> [Player] {
        return players.values.filter { player in
            if let entity = playerEntities[player.playerId],
               let playerComp = world.get(PlayerComponent.self, for: entity) {
                return playerComp.teamId == teamId
            }
            return false
        }
    }
    
    /// Gets the local player (first player for now, will be replaced with actual local player tracking)
    func getLocalPlayer() -> Player? {
        return players.values.first
    }
    
    /// Gets the local player ID
    func getLocalPlayerId() -> UInt32? {
        return players.keys.first
    }
}
