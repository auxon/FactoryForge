import Foundation

/// Maps server-assigned network entity IDs ↔ client/local Entity.
/// Used by client to resolve Entity from incoming delta/snapshot; server uses local Entity only.
final class NetworkEntityMapper {
    /// networkEntityId → Entity (client: server ID → local entity)
    private var serverToLocal: [UInt32: Entity] = [:]
    /// Entity.id (as key) → networkEntityId (client: local entity → server ID for outgoing commands)
    private var localToServer: [UInt32: UInt32] = [:]
    private let lock = NSLock()

    func register(networkEntityId: UInt32, entity: Entity) {
        lock.lock()
        defer { lock.unlock() }
        serverToLocal[networkEntityId] = entity
        localToServer[entity.id] = networkEntityId
    }

    func unregister(networkEntityId: UInt32) {
        lock.lock()
        defer { lock.unlock() }
        if let e = serverToLocal.removeValue(forKey: networkEntityId) {
            localToServer.removeValue(forKey: e.id)
        }
    }

    func unregister(entity: Entity) {
        lock.lock()
        defer { lock.unlock() }
        if let netId = localToServer.removeValue(forKey: entity.id) {
            serverToLocal.removeValue(forKey: netId)
        }
    }

    func entity(for networkEntityId: UInt32) -> Entity? {
        lock.lock()
        defer { lock.unlock() }
        return serverToLocal[networkEntityId]
    }

    func networkEntityId(for entity: Entity) -> UInt32? {
        lock.lock()
        defer { lock.unlock() }
        return localToServer[entity.id]
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        serverToLocal.removeAll()
        localToServer.removeAll()
    }
}
