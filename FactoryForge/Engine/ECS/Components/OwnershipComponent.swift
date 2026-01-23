import Foundation

/// Component that tracks ownership of entities (units, buildings, etc.)
struct OwnershipComponent: Component {
    let ownerPlayerId: UInt32
    var canBeStolen: Bool = false
    var teamId: UInt32?
    
    init(ownerPlayerId: UInt32, teamId: UInt32? = nil, canBeStolen: Bool = false) {
        self.ownerPlayerId = ownerPlayerId
        self.teamId = teamId
        self.canBeStolen = canBeStolen
    }
}
