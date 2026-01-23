import Foundation

/// Pre-game lobby: match setup, player ready, game mode / map selection.
/// Drives MatchConfig; startMatch() yields config for SpawnSystem + game start.
final class LobbySystem {
    private(set) var config: MatchConfig
    private(set) var slots: [LobbySlot]
    private(set) var isInProgress: Bool = false

    var onMatchStart: ((MatchConfig, [LobbySlot]) -> Void)?
    var onSlotUpdated: ((Int, LobbySlot) -> Void)?

    init(config: MatchConfig = MatchConfig()) {
        self.config = config
        self.slots = (0..<Int(config.maxPlayers)).map { _ in LobbySlot() }
    }

    func setConfig(_ config: MatchConfig) {
        guard !isInProgress else { return }
        self.config = config
        let n = Int(config.maxPlayers)
        if slots.count != n {
            slots = (0..<n).map { _ in LobbySlot() }
        }
    }

    func setGameMode(_ mode: GameMode) {
        guard !isInProgress else { return }
        config.gameMode = mode
        config.teamCount = (mode == .teamDeathmatch) ? 2 : 0
    }

    func setSeed(_ seed: UInt64) {
        guard !isInProgress else { return }
        config.seed = seed
    }

    func joinSlot(_ index: Int, playerId: UInt32, displayName: String, isAI: Bool = false) {
        guard index >= 0, index < slots.count, !isInProgress else { return }
        var s = slots[index]
        s.playerId = playerId
        s.displayName = displayName
        s.isAI = isAI
        s.teamId = teamForSlot(index)
        slots[index] = s
        onSlotUpdated?(index, s)
    }

    func leaveSlot(_ index: Int) {
        guard index >= 0, index < slots.count, !isInProgress else { return }
        slots[index] = LobbySlot()
        onSlotUpdated?(index, slots[index])
    }

    func setReady(_ index: Int, ready: Bool) {
        guard index >= 0, index < slots.count, !isInProgress else { return }
        slots[index].isReady = ready
        onSlotUpdated?(index, slots[index])
    }

    func setTeam(_ index: Int, teamId: UInt32?) {
        guard index >= 0, index < slots.count, !isInProgress else { return }
        slots[index].teamId = teamId
        onSlotUpdated?(index, slots[index])
    }

    /// Returns true if all joined, non-AI players are ready and at least one joined.
    func canStartMatch() -> Bool {
        let joined = slots.filter { $0.playerId != nil }
        guard !joined.isEmpty else { return false }
        let human = joined.filter { !$0.isAI }
        if human.isEmpty { return true }
        return human.allSatisfy { $0.isReady }
    }

    func startMatch() {
        guard canStartMatch(), !isInProgress else { return }
        isInProgress = true
        let participants = slots.filter { $0.playerId != nil }
        onMatchStart?(config, participants)
    }

    func reset() {
        isInProgress = false
        slots = (0..<Int(config.maxPlayers)).map { _ in LobbySlot() }
    }

    private func teamForSlot(_ index: Int) -> UInt32? {
        guard config.teamCount > 0 else { return nil }
        return UInt32(index % Int(config.teamCount)) + 1
    }
}
