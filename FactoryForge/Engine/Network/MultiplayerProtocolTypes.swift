import Foundation

// MARK: - Game Rules (handshake)

/// Server-defined game rules sent during handshake.
struct GameRules: Codable, Equatable {
    var seed: UInt64
    var friendlyFire: Bool
    var maxPlayers: UInt32
    var tickRate: Float  // e.g. 60

    init(seed: UInt64, friendlyFire: Bool = false, maxPlayers: UInt32 = 8, tickRate: Float = 60) {
        self.seed = seed
        self.friendlyFire = friendlyFire
        self.maxPlayers = maxPlayers
        self.tickRate = tickRate
    }
}

// MARK: - Entity Delta (state sync)

/// Represents a change to a networked entity (delta sync).
enum EntityDelta: Codable {
    /// Full entity add/update (use EntityData from World)
    case upsert(networkEntityId: UInt32, entityData: EntityData)
    /// Entity removed
    case remove(networkEntityId: UInt32)
}

// MARK: - Network Unit Command (entity refs as UInt32)

/// Network-safe unit command (uses network entity IDs instead of Entity).
enum NetworkUnitCommand: Codable, Equatable {
    case move(to: IntVector2)
    case attack(entityId: UInt32)
    case attackGround(position: IntVector2)
    case patrol(from: IntVector2, to: IntVector2)
    case holdPosition
    case useAbility(ability: UnitAbility, target: NetworkCommandTarget?)

    enum NetworkCommandTarget: Codable, Equatable {
        case entity(UInt32)
        case position(IntVector2)
    }
}

// MARK: - Player Action (client → server commands)

/// Player action sent from client to server.
enum PlayerAction: Codable, Equatable {
    case move(position: IntVector2)
    case build(buildingId: String, position: IntVector2, direction: Direction)
    case attack(targetEntityId: UInt32)
    case unitCommand(unitId: UInt32, command: NetworkUnitCommand)
}

// MARK: - Network Message (wire format)

/// Wire-level message types for multiplayer protocol.
enum NetworkMessage: Codable {
    case handshake(seed: UInt64, rules: GameRules)
    case snapshot(WorldData)
    case delta([EntityDelta])
    case command(PlayerAction)
    case ping(timestamp: TimeInterval)
    case pong(timestamp: TimeInterval)
    case ack(messageId: UInt32)
    case resync(WorldData)
}
