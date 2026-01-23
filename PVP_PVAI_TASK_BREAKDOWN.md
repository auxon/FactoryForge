# PvP + PvAI Concrete Task Breakdown

This document provides specific, actionable tasks with exact code changes needed.

## Phase 1: Multiplayer Data Model Foundation

### Task 1.1: Add Ownership & Team Components

#### Create `OwnershipComponent.swift`
**Path**: `FactoryForge/Engine/ECS/Components/OwnershipComponent.swift`

```swift
import Foundation

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
```

#### Create `PlayerComponent.swift`
**Path**: `FactoryForge/Engine/ECS/Components/PlayerComponent.swift`

```swift
import Foundation

enum AIDifficulty: String, Codable {
    case easy, medium, hard, expert
}

struct PlayerComponent: Component {
    let playerId: UInt32
    let playerName: String
    var teamId: UInt32?
    var isAI: Bool
    var aiDifficulty: AIDifficulty?
    var networkEntityId: UInt32?
    
    init(playerId: UInt32, playerName: String, teamId: UInt32? = nil, isAI: Bool = false, aiDifficulty: AIDifficulty? = nil) {
        self.playerId = playerId
        self.playerName = playerName
        self.teamId = teamId
        self.isAI = isAI
        self.aiDifficulty = aiDifficulty
        self.networkEntityId = nil
    }
}
```

#### Modify `PositionComponent.swift`
**Path**: `FactoryForge/Engine/ECS/Components/PositionComponent.swift`

**Find** (around line 78):
```swift
struct CollisionLayer: OptionSet, Codable {
    let rawValue: UInt32
    
    static let none = CollisionLayer([])
    static let `default` = CollisionLayer(rawValue: 1 << 0)
    static let player = CollisionLayer(rawValue: 1 << 1)
    static let enemy = CollisionLayer(rawValue: 1 << 2)
    static let building = CollisionLayer(rawValue: 1 << 3)
    static let projectile = CollisionLayer(rawValue: 1 << 4)
    static let resource = CollisionLayer(rawValue: 1 << 5)
    static let all = CollisionLayer(rawValue: UInt32.max)
}
```

**Replace with**:
```swift
struct CollisionLayer: OptionSet, Codable {
    let rawValue: UInt32
    
    static let none = CollisionLayer([])
    static let `default` = CollisionLayer(rawValue: 1 << 0)
    static let player = CollisionLayer(rawValue: 1 << 1)
    static let enemy = CollisionLayer(rawValue: 1 << 2)
    static let building = CollisionLayer(rawValue: 1 << 3)
    static let projectile = CollisionLayer(rawValue: 1 << 4)
    static let resource = CollisionLayer(rawValue: 1 << 5)
    
    // Team-based collision layers
    static let team1 = CollisionLayer(rawValue: 1 << 6)
    static let team2 = CollisionLayer(rawValue: 1 << 7)
    static let team3 = CollisionLayer(rawValue: 1 << 8)
    static let team4 = CollisionLayer(rawValue: 1 << 9)
    static let team5 = CollisionLayer(rawValue: 1 << 10)
    static let team6 = CollisionLayer(rawValue: 1 << 11)
    static let team7 = CollisionLayer(rawValue: 1 << 12)
    static let team8 = CollisionLayer(rawValue: 1 << 13)
    
    static let all = CollisionLayer(rawValue: UInt32.max)
    
    // Helper to get team layer by ID (1-8)
    static func team(_ teamId: UInt32) -> CollisionLayer {
        guard teamId >= 1 && teamId <= 8 else { return .none }
        return CollisionLayer(rawValue: 1 << (5 + Int(teamId)))
    }
}
```

### Task 1.2: Create PlayerManager

#### Create `PlayerManager.swift`
**Path**: `FactoryForge/Game/Multiplayer/PlayerManager.swift`

```swift
import Foundation

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
    
    func removePlayer(playerId: UInt32) {
        if let entity = playerEntities[playerId] {
            world.despawn(entity)
        }
        players.removeValue(forKey: playerId)
        playerEntities.removeValue(forKey: playerId)
    }
    
    func getPlayer(playerId: UInt32) -> Player? {
        return players[playerId]
    }
    
    func getPlayerEntity(playerId: UInt32) -> Entity? {
        return playerEntities[playerId]
    }
    
    func getAllPlayers() -> [Player] {
        return Array(players.values)
    }
    
    func getPlayersOnTeam(teamId: UInt32) -> [Player] {
        return players.values.filter { player in
            if let entity = playerEntities[player.playerId],
               let playerComp = world.get(PlayerComponent.self, for: entity) {
                return playerComp.teamId == teamId
            }
            return false
        }
    }
    
    func getLocalPlayer() -> Player? {
        // For now, return first player (will be replaced with actual local player tracking)
        return players.values.first
    }
}
```

### Task 1.3: Refactor Player Class

#### Modify `Player.swift`
**Path**: `FactoryForge/Game/Player/Player.swift`

**Add property** (around line 4):
```swift
final class Player {
    let playerId: UInt32
    private var world: World
    // ... rest of existing properties
```

**Modify init** (around line 64):
```swift
init(world: World, itemRegistry: ItemRegistry, playerId: UInt32 = 1) {
    self.playerId = playerId
    self.world = world
    self.itemRegistry = itemRegistry
    // ... rest of existing init
```

**Modify `setupPlayerEntity`** (around line 85):
```swift
private func setupPlayerEntity() {
    // ... existing setup code ...
    
    // Add PlayerComponent (if not already added by PlayerManager)
    if world.get(PlayerComponent.self, for: entity) == nil {
        let playerComponent = PlayerComponent(playerId: playerId, playerName: "Player \(playerId)")
        world.add(playerComponent, to: entity)
    }
    
    // Add OwnershipComponent
    if world.get(OwnershipComponent.self, for: entity) == nil {
        let ownership = OwnershipComponent(ownerPlayerId: playerId)
        world.add(ownership, to: entity)
    }
}
```

### Task 1.4: Update Systems for Ownership

#### Modify `CombatSystem.swift`
**Path**: `FactoryForge/Game/Systems/CombatSystem.swift`

**Find** `applyDamage` method (around line 259):
```swift
private func applyDamage(_ damage: Float, to entity: Entity, from source: Entity?) {
    // ... existing code ...
}
```

**Add team checking**:
```swift
private func applyDamage(_ damage: Float, to entity: Entity, from source: Entity?) {
    // Check if source and target are on same team (friendly fire check)
    if let source = source,
       let sourceOwnership = world.get(OwnershipComponent.self, for: source),
       let targetOwnership = world.get(OwnershipComponent.self, for: entity) {
        
        // Same team - check friendly fire rules
        if sourceOwnership.teamId != nil && sourceOwnership.teamId == targetOwnership.teamId {
            // TODO: Check game rules for friendly fire
            // For now, allow friendly fire (can be disabled later)
        }
    }
    
    // ... rest of existing damage application code ...
}
```

#### Modify `UnitSystem.swift`
**Path**: `FactoryForge/Game/Systems/UnitSystem.swift`

**Find** `spawnUnit` method (around line 53):
```swift
private func spawnUnit(_ unitType: UnitType, near position: Vector2) {
    // ... existing code ...
    world.add(CollisionComponent(radius: 0.4, layer: .player, mask: [.enemy, .building]), to: entity)
}
```

**Add ownership**:
```swift
private func spawnUnit(_ unitType: UnitType, near position: Vector2, ownerPlayerId: UInt32? = nil) {
    // ... existing spawn code ...
    
    // Add ownership if provided
    if let ownerId = ownerPlayerId {
        let ownership = OwnershipComponent(ownerPlayerId: ownerId)
        world.add(ownership, to: entity)
    }
    
    // ... rest of existing code ...
}
```

**Find** `executeCommand` method (around line 112):
```swift
private func executeCommand(_ command: UnitCommand, for entity: Entity, unit: UnitComponent) {
    // Add ownership check
    guard let ownership = world.get(OwnershipComponent.self, for: entity) else {
        print("UnitSystem: Unit \(entity.id) has no ownership, skipping command")
        return
    }
    
    // TODO: Verify command is from owning player
    // For now, allow any command (will be validated by server in multiplayer)
    
    // ... rest of existing command execution ...
}
```

#### Modify `GameLoop.swift`
**Path**: `FactoryForge/Engine/Core/GameLoop.swift`

**Replace** single player (around line 43):
```swift
// Player
let player: Player
```

**With**:
```swift
// Player Management
let playerManager: PlayerManager
var localPlayerId: UInt32?  // ID of the local player
```

**Modify init** (around line 65):
```swift
init(world: World, chunkManager: ChunkManager, itemRegistry: ItemRegistry, recipeRegistry: RecipeRegistry, buildingRegistry: BuildingRegistry, technologyRegistry: TechnologyRegistry, renderer: MetalRenderer?) {
    // ... existing init code ...
    
    // Create player manager
    playerManager = PlayerManager(world: world, itemRegistry: itemRegistry)
    
    // Create local player (for single-player compatibility)
    localPlayerId = playerManager.createPlayer(name: "Player", isAI: false)
    
    // Get player for backward compatibility
    let player = playerManager.getPlayer(playerId: localPlayerId!)!
    
    // ... rest of existing init, but use playerManager.getPlayer() instead of direct player access ...
}
```

**Add helper method**:
```swift
var player: Player? {
    guard let localId = localPlayerId else { return nil }
    return playerManager.getPlayer(playerId: localId)
}
```

**Update all `gameLoop.player` references** throughout the codebase to use the computed property or `playerManager.getPlayer()`.

### Task 2.1: Make GameLoop Headless-Safe

#### Modify `GameLoop.swift`
**Path**: `FactoryForge/Engine/Core/GameLoop.swift`

**Add property**:
```swift
var isHeadless: Bool = false
```

**Modify render calls** (around line 1759):
```swift
func render(renderer: MetalRenderer) {
    guard !isHeadless else { return }
    
    // ... existing render code ...
}
```

**Guard UI updates**:
```swift
// Update UI (skip if game is effectively paused to save performance)
if gameSpeed > 0.01 && !isHeadless {
    uiSystem?.update(deltaTime: deltaTime)
}
```

## Phase 2: Networking Core

### Task 3.1: Create Multiplayer Network Manager

#### Create `MultiplayerNetworkManager.swift`
**Path**: `FactoryForge/Engine/Network/MultiplayerNetworkManager.swift`

```swift
import Foundation
import Network

enum NetworkMessage: Codable {
    case handshake(seed: UInt32, rules: GameRules)
    case snapshot(WorldData)
    case delta([EntityDelta])
    case command(PlayerAction)
    case ping(timestamp: TimeInterval)
    case pong(timestamp: TimeInterval)
    case ack(messageId: UInt32)
    case resync(WorldData)
}

enum PlayerAction: Codable {
    case move(position: IntVector2)
    case build(buildingId: String, position: IntVector2, direction: Direction)
    case attack(targetEntityId: UInt32)
    case unitCommand(unitId: UInt32, command: UnitCommand)
    // ... more actions
}

final class MultiplayerNetworkManager {
    private var connection: NWConnection?
    private var isConnected = false
    private var messageQueue: [NetworkMessage] = []
    
    func connect(to host: String, port: UInt16) {
        // Implementation
    }
    
    func send(_ message: NetworkMessage) {
        // Implementation
    }
    
    func receive() -> NetworkMessage? {
        // Implementation
        return nil
    }
}
```

## Phase 3: PvAI Core

### Task 5.1: Create AIPlayerSystem

#### Create `AIPlayerSystem.swift`
**Path**: `FactoryForge/Game/AI/AIPlayerSystem.swift`

```swift
import Foundation

final class AIPlayerSystem: System {
    let priority = SystemPriority.enemyAI.rawValue + 1
    
    private let world: World
    private let playerManager: PlayerManager
    private var aiPlayers: [UInt32: AIPlayerState] = [:]
    
    init(world: World, playerManager: PlayerManager) {
        self.world = world
        self.playerManager = playerManager
    }
    
    func update(deltaTime: Float) {
        // Process each AI player
        for (playerId, state) in aiPlayers {
            guard let player = playerManager.getPlayer(playerId: playerId) else { continue }
            
            state.decisionTimer -= deltaTime
            
            if state.decisionTimer <= 0 {
                makeDecision(for: player, state: &state)
                state.decisionTimer = state.decisionInterval
            }
        }
    }
    
    private func makeDecision(for player: Player, state: inout AIPlayerState) {
        // AI decision making logic
    }
}

struct AIPlayerState {
    var decisionTimer: Float = 0
    var decisionInterval: Float = 1.0  // Make decisions every second
    var currentGoal: AIGoal?
    var actionQueue: [AIAction] = []
}
```

This provides the foundation. Each task can be implemented incrementally and tested independently.
