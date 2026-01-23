import Foundation

// MARK: - Replay Data

/// Single recorded command: tick index and player action.
struct ReplayEntry: Codable, Equatable {
    let tick: UInt64
    let action: PlayerAction
}

/// Full replay: seed, optional initial snapshot, and command stream.
struct ReplayData: Codable {
    var seed: UInt64
    var initialSnapshot: WorldData?
    var entries: [ReplayEntry]
}

// MARK: - Replay Recorder

/// Records command streams for later replay. Use to validate deterministic sim or debug matches.
final class ReplayRecorder {
    private var seed: UInt64 = 0
    private var snapshot: WorldData?
    private var entries: [ReplayEntry] = []
    private let lock = NSLock()

    func setSeed(_ seed: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        self.seed = seed
    }

    func record(tick: UInt64, action: PlayerAction) {
        lock.lock()
        defer { lock.unlock() }
        entries.append(ReplayEntry(tick: tick, action: action))
    }

    func recordSnapshot(_ data: WorldData) {
        lock.lock()
        defer { lock.unlock() }
        snapshot = data
    }

    func finish() -> ReplayData {
        lock.lock()
        defer { lock.unlock() }
        return ReplayData(seed: seed, initialSnapshot: snapshot, entries: entries)
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        seed = 0
        snapshot = nil
        entries.removeAll()
    }

    func write(to url: URL) throws {
        let data = finish()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let raw = try encoder.encode(data)
        try raw.write(to: url)
    }
}

// MARK: - Replay Player

/// Plays back a recorded replay. Supports spectator-style iteration over ticks.
final class ReplayPlayer {
    private let data: ReplayData
    private var index: Int = 0

    init(data: ReplayData) {
        self.data = data
    }

    /// Initial world snapshot, if recorded.
    var initialSnapshot: WorldData? { data.initialSnapshot }

    /// Seed used for the match.
    var seed: UInt64 { data.seed }

    /// All actions for the given tick, in order.
    func actions(forTick tick: UInt64) -> [PlayerAction] {
        return data.entries.filter { $0.tick == tick }.map { $0.action }
    }

    /// Advance internal cursor to the next distinct tick that has actions; returns that tick or nil if done.
    func advanceToNextTickWithActions() -> UInt64? {
        guard index < data.entries.count else { return nil }
        let tick = data.entries[index].tick
        while index < data.entries.count, data.entries[index].tick == tick {
            index += 1
        }
        return tick
    }

    /// All remaining (tick, actions) pairs for spectator-style playback.
    func remainingTickActionPairs() -> [(tick: UInt64, actions: [PlayerAction])] {
        var result: [(UInt64, [PlayerAction])] = []
        var pending: [ReplayEntry] = Array(data.entries.dropFirst(index))
        var i = 0
        while i < pending.count {
            let t = pending[i].tick
            var actions: [PlayerAction] = []
            while i < pending.count, pending[i].tick == t {
                actions.append(pending[i].action)
                i += 1
            }
            result.append((t, actions))
        }
        index = data.entries.count
        return result
    }

    /// Load replay from file.
    static func load(from url: URL) throws -> ReplayPlayer {
        let raw = try Data(contentsOf: url)
        let data = try JSONDecoder().decode(ReplayData.self, from: raw)
        return ReplayPlayer(data: data)
    }
}
