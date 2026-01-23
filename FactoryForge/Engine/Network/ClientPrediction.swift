import Foundation

/// Client-side prediction for local player movement.
/// Predicts movement immediately; reconciles with server state periodically.
/// Only movement is predicted (not combat/building).
final class ClientPrediction {
    /// Pending predicted positions (client tick → position) for reconciliation.
    private var predictedPositions: [UInt64: Vector2] = [:]
    private let maxStored: Int = 120  // ~2s at 60 Hz
    private let lock = NSLock()

    /// Record a predicted move for the given client tick (e.g. Time.shared.serverTick or frame).
    func recordPrediction(clientTick: UInt64, position: Vector2) {
        lock.lock()
        defer { lock.unlock() }
        predictedPositions[clientTick] = position
        if predictedPositions.count > maxStored {
            let minKey = predictedPositions.keys.min() ?? 0
            predictedPositions.removeValue(forKey: minKey)
        }
    }

    /// Reconcile with server: if server position differs from prediction, snap and drop older predictions.
    /// - Returns: (shouldSnap, serverPosition) when a correction is needed.
    func reconcile(serverTick: UInt64, serverPosition: Vector2, tolerance: Float = 0.01) -> (snap: Bool, position: Vector2)? {
        lock.lock()
        defer { lock.unlock() }
        guard let predicted = predictedPositions[serverTick] else {
            return (true, serverPosition)
        }
        let diff = (predicted - serverPosition).lengthSquared
        if diff > tolerance * tolerance {
            // Drop predictions at or before serverTick
            let toRemove = predictedPositions.keys.filter { $0 <= serverTick }
            toRemove.forEach { predictedPositions.removeValue(forKey: $0) }
            return (true, serverPosition)
        }
        return nil
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        predictedPositions.removeAll()
    }
}
