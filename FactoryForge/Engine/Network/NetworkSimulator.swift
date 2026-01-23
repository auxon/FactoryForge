import Foundation

/// Config for simulated network conditions.
struct NetworkSimulatorConfig {
    var latencyMs: Double
    var jitterMs: Double
    var packetLossRatio: Float

    init(latencyMs: Double = 50, jitterMs: Double = 10, packetLossRatio: Float = 0) {
        self.latencyMs = latencyMs
        self.jitterMs = jitterMs
        self.packetLossRatio = packetLossRatio
    }

    static let none = NetworkSimulatorConfig(latencyMs: 0, jitterMs: 0, packetLossRatio: 0)
    static let good = NetworkSimulatorConfig(latencyMs: 30, jitterMs: 5, packetLossRatio: 0)
    static let bad = NetworkSimulatorConfig(latencyMs: 150, jitterMs: 40, packetLossRatio: 0.05)
    static let terrible = NetworkSimulatorConfig(latencyMs: 300, jitterMs: 80, packetLossRatio: 0.15)
}

/// Simulated channel: delay, jitter, packet loss. Use to test client prediction and reconciliation.
final class NetworkSimulator {
    private let queue = DispatchQueue(label: "com.factoryforge.network-simulator", qos: .userInitiated)
    private var config: NetworkSimulatorConfig
    private var pending: [(deliverAt: CFAbsoluteTime, data: Data)] = []
    private var deliveryWorkItem: DispatchWorkItem?

    /// Called when a packet is delivered (after simulated delay). Run assertions or forward to decoder.
    var onDelivered: ((Data) -> Void)?

    /// Bytes passed to send (before loss).
    private(set) var bytesSent: Int64 = 0
    /// Bytes delivered to onDelivered.
    private(set) var bytesReceived: Int64 = 0
    /// Packets dropped due to loss.
    private(set) var packetsDropped: Int64 = 0

    init(config: NetworkSimulatorConfig = .none) {
        self.config = config
    }

    func updateConfig(_ config: NetworkSimulatorConfig) {
        queue.async { [weak self] in
            self?.config = config
        }
    }

    /// Enqueue data for simulated send. May drop (loss); otherwise delivers after delay ± jitter.
    func send(_ data: Data) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.bytesSent += Int64(data.count)
            if Float.random(in: 0 ..< 1) < self.config.packetLossRatio {
                self.packetsDropped += 1
                return
            }
            let jitter = Double.random(in: -self.config.jitterMs ... self.config.jitterMs) / 1000.0
            let delay = max(0, self.config.latencyMs / 1000.0 / 2.0 + jitter)
            let deliverAt = CFAbsoluteTimeGetCurrent() + delay
            self.pending.append((deliverAt, data))
            self.pending.sort { $0.deliverAt < $1.deliverAt }
            self.scheduleDelivery()
        }
    }

    private func scheduleDelivery() {
        deliveryWorkItem?.cancel()
        guard let first = pending.first else { return }
        let now = CFAbsoluteTimeGetCurrent()
        let delay = max(0, first.deliverAt - now)
        let work = DispatchWorkItem { [weak self] in
            self?.deliverPending()
        }
        deliveryWorkItem = work
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func deliverPending() {
        let now = CFAbsoluteTimeGetCurrent()
        var delivered: [Data] = []
        while let f = pending.first, f.deliverAt <= now {
            pending.removeFirst()
            delivered.append(f.data)
        }
        for data in delivered {
            bytesReceived += Int64(data.count)
            onDelivered?(data)
        }
        if !pending.isEmpty {
            scheduleDelivery()
        }
    }

    func resetStats() {
        queue.async { [weak self] in
            self?.bytesSent = 0
            self?.bytesReceived = 0
            self?.packetsDropped = 0
        }
    }

    func flush() {
        queue.async { [weak self] in
            guard let self = self else { return }
            for (_, data) in self.pending {
                self.bytesReceived += Int64(data.count)
                self.onDelivered?(data)
            }
            self.pending.removeAll()
            self.deliveryWorkItem?.cancel()
            self.deliveryWorkItem = nil
        }
    }
}
