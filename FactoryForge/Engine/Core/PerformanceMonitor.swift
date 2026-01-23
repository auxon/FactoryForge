import Foundation

/// Server/game performance telemetry: tick cost, entity counts, optional bandwidth.
final class PerformanceMonitor {
    private let lock = NSLock()
    private var tickStartTime: CFAbsoluteTime = 0
    private var lastTickDurationMs: Double = 0
    private var lastEntityCount: Int = 0
    private var bytesSentTotal: Int64 = 0
    private var bytesReceivedTotal: Int64 = 0
    private var sampleCount: Int = 0
    private var tickDurations: [Double] = []
    private let maxSamples = 60

    /// Log every N ticks (0 = no periodic log).
    var logIntervalTicks: Int = 300
    /// Alert when tick duration exceeds this (ms).
    var tickAlertThresholdMs: Double = 50
    /// Alert when entity count exceeds this.
    var entityAlertThreshold: Int = 10_000
    /// Called when an alert fires.
    var onAlert: ((String) -> Void)?

    // MARK: - Tick

    func startTick() {
        tickStartTime = CFAbsoluteTimeGetCurrent()
    }

    func endTick() {
        let elapsed = (CFAbsoluteTimeGetCurrent() - tickStartTime) * 1000
        lock.lock()
        lastTickDurationMs = elapsed
        tickDurations.append(elapsed)
        if tickDurations.count > maxSamples { tickDurations.removeFirst() }
        lock.unlock()
        if tickAlertThresholdMs > 0, elapsed >= tickAlertThresholdMs {
            onAlert?("Tick spike: \(String(format: "%.1f", elapsed)) ms")
        }
    }

    // MARK: - Entities & bandwidth

    func recordEntityCount(_ count: Int) {
        lock.lock()
        lastEntityCount = count
        lock.unlock()
        if entityAlertThreshold > 0, count >= entityAlertThreshold {
            onAlert?("Entity count high: \(count)")
        }
    }

    func recordBandwidth(sent: Int64, received: Int64) {
        lock.lock()
        bytesSentTotal += sent
        bytesReceivedTotal += received
        lock.unlock()
    }

    // MARK: - Sampling & log

    func sample(tick: UInt64) {
        lock.lock()
        sampleCount += 1
        let interval = logIntervalTicks
        let count = sampleCount
        let duration = lastTickDurationMs
        let entities = lastEntityCount
        let sent = bytesSentTotal
        let recv = bytesReceivedTotal
        let durations = tickDurations
        lock.unlock()
        guard interval > 0, count % interval == 0 else { return }
        let avg = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
        print("[Perf] tick=\(tick) tickMs=\(String(format: "%.1f", duration)) avgMs=\(String(format: "%.1f", avg)) entities=\(entities) sent=\(sent) recv=\(recv)")
    }

    /// Latest tick duration (ms).
    var lastTickDurationMsValue: Double {
        lock.lock()
        defer { lock.unlock() }
        return lastTickDurationMs
    }

    /// Latest entity count.
    var lastEntityCountValue: Int {
        lock.lock()
        defer { lock.unlock() }
        return lastEntityCount
    }

    func reset() {
        lock.lock()
        tickDurations.removeAll()
        sampleCount = 0
        bytesSentTotal = 0
        bytesReceivedTotal = 0
        lock.unlock()
    }
}
