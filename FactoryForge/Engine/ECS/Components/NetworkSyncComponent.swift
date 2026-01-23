import Foundation

/// Sync priority for network replication (interest management).
enum SyncPriority: String, Codable {
    case high   // Player, nearby units
    case medium // Buildings in loaded chunks
    case low    // Distant entities
}

/// Tracks network replication for an entity (server-assigned ID, sync priority).
struct NetworkSyncComponent: Component {
    var networkEntityId: UInt32
    var lastSyncTime: TimeInterval
    var syncPriority: SyncPriority
    var ownerPlayerId: UInt32?

    init(networkEntityId: UInt32, lastSyncTime: TimeInterval = 0, syncPriority: SyncPriority = .medium, ownerPlayerId: UInt32? = nil) {
        self.networkEntityId = networkEntityId
        self.lastSyncTime = lastSyncTime
        self.syncPriority = syncPriority
        self.ownerPlayerId = ownerPlayerId
    }
}
