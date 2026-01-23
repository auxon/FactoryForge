# PvP Online + PvAI Implementation Plan

## Codebase Analysis Summary

### Current State Issues

1. **GameNetworkManager.swift**: MCP/debug plumbing only (localhost WebSocket/HTTP + JSON commands). Not built for online PvP.
2. **GameLoop.swift**: Owns single `Player` instance, fixed system ordering. No multi-player orchestration.
3. **Player.swift**: Single-player entity, explicitly excluded from `World.serialize()`.
4. **UnitSystem.swift & CombatSystem.swift**: Assume "player vs enemy" (units spawn on `.player` layer; turrets target `EnemyComponent` only).
5. **PositionComponent.swift**: Only `.player` and `.enemy` collision layers — no team/ownership concept.
6. **SaveSystem.swift**: JSON-heavy snapshot path, excludes player entity.
7. **EnemyAISystem.swift**: Biter AI only.
8. **AutoPlaySystem.swift**: Scripted automation that can be repurposed as AI driver.

### Assumptions

- **Max Players**: 2-8 players (RTS-style)
- **Match Length**: 15-60 minutes typical
- **Server**: Dedicated authoritative server (cloud-hosted recommended)
- **PvAI**: Server-side AI (can also support offline/local AI)
- **Modes**: Both competitive PvP and co-op vs AI

## Implementation Plan

### Phase 1: Multiplayer Data Model Foundation

#### Task 1.1: Add Ownership & Team Components

**File**: `FactoryForge/Engine/ECS/Components/OwnershipComponent.swift` (NEW)
```swift
struct OwnershipComponent: Component {
    let ownerPlayerId: UInt32
    var canBeStolen: Bool = false  // For resources/buildings
    var teamId: UInt32?  // For team-based modes
}
```

**File**: `FactoryForge/Engine/ECS/Components/PlayerComponent.swift` (NEW)
```swift
struct PlayerComponent: Component {
    let playerId: UInt32  // Unique player identifier
    let playerName: String
    var teamId: UInt32?  // For team-based modes
    var isAI: Bool  // True for AI players
    var aiDifficulty: AIDifficulty?  // For AI players
    var networkEntityId: UInt32?  // Stable server-assigned ID
}
```

**File**: `FactoryForge/Engine/ECS/Components/PositionComponent.swift` (MODIFY)
- Add team-based collision layers:
```swift
extension CollisionLayer {
    static let team1 = CollisionLayer(rawValue: 1 << 6)
    static let team2 = CollisionLayer(rawValue: 1 << 7)
    static let team3 = CollisionLayer(rawValue: 1 << 8)
    static let team4 = CollisionLayer(rawValue: 1 << 9)
    // ... up to team8
}
```

#### Task 1.2: Create PlayerManager System

**File**: `FactoryForge/Game/Multiplayer/PlayerManager.swift` (NEW)
```swift
final class PlayerManager {
    private var players: [UInt32: Player] = [:]
    private var playerEntities: [UInt32: Entity] = [:]
    private var nextPlayerId: UInt32 = 1
    
    func createPlayer(name: String, isAI: Bool = false, teamId: UInt32? = nil) -> UInt32
    func removePlayer(playerId: UInt32)
    func getPlayer(playerId: UInt32) -> Player?
    func getPlayerEntity(playerId: UInt32) -> Entity?
    func getAllPlayers() -> [Player]
    func getPlayersOnTeam(teamId: UInt32) -> [Player]
}
```

**File**: `FactoryForge/Game/Multiplayer/PlayersSystem.swift` (NEW)
- System that manages multiple player entities
- Handles player spawning/despawning
- Routes input to correct player
- Manages player state synchronization

#### Task 1.3: Refactor Player Class

**File**: `FactoryForge/Game/Player/Player.swift` (MODIFY)
- Add `playerId: UInt32` property
- Remove singleton assumptions (support multiple instances)
- Add `PlayerComponent` to player entity
- Add `OwnershipComponent` to player entity
- Include player entity in serialization (remove exclusion)

#### Task 1.4: Update Systems for Ownership

**File**: `FactoryForge/Game/Systems/CombatSystem.swift` (MODIFY)
- Change target selection from `EnemyComponent` only to team-based
- Check `OwnershipComponent` for friendly fire rules
- Add team-based damage filtering

**File**: `FactoryForge/Game/Systems/UnitSystem.swift` (MODIFY)
- Add ownership validation: only accept commands from owning player
- Check `OwnershipComponent` before executing commands
- Spawn units with `OwnershipComponent` attached

**File**: `FactoryForge/Game/Systems/TurretSystem.swift` (if exists) (MODIFY)
- Change from targeting `EnemyComponent` only to team-based targeting
- Use `OwnershipComponent` to determine valid targets

**File**: `FactoryForge/Engine/Core/GameLoop.swift` (MODIFY)
- Replace single `player: Player` with `PlayerManager`
- Update all `gameLoop.player` references to use `PlayerManager`
- Support multiple players in game loop

### Phase 2: Decouple Simulation for Server Use

#### Task 2.1: Make GameLoop Headless-Safe

**File**: `FactoryForge/Engine/Core/GameLoop.swift` (MODIFY)
- Make `renderer` optional (weak reference, can be nil)
- Guard all UI/Metal code with `#if os(iOS)`
- Add `isHeadless: Bool` flag
- Skip rendering updates when headless

**File**: `FactoryForge/Engine/Core/Time.swift` (MODIFY)
- Add deterministic time source option
- Use explicit tick counter for server (avoid `CACurrentMediaTime()`)
- Add `serverTick: UInt64` property for deterministic simulation

#### Task 2.2: Extract Core Simulation Target

**Create**: `FactoryForge/Engine/Core/SimulationCore.swift` (NEW)
- Extract ECS logic that doesn't depend on UIKit/Metal
- Create protocol-based renderer interface
- Make systems work without rendering

**Project Structure**:
- Create new target: `FactoryForgeCore` (shared between client and server)
- Move ECS, Systems, Game Logic to shared target
- Keep UI, Rendering, Input in iOS-specific target

### Phase 3: Networking Architecture (Authoritative Server)

#### Task 3.1: Create Multiplayer Network Manager

**File**: `FactoryForge/Engine/Network/MultiplayerNetworkManager.swift` (NEW)
- Separate from `GameNetworkManager` (keep MCP separate)
- Handle client-server communication
- Implement connection lifecycle (connect, disconnect, reconnect)
- Message serialization/deserialization

**Protocol Message Types**:
```swift
enum NetworkMessage {
    case handshake(seed: UInt32, rules: GameRules)
    case snapshot(WorldData)  // Full state
    case delta([EntityDelta])  // Entity/component changes
    case command(PlayerAction)  // Player actions
    case ping(timestamp: TimeInterval)
    case pong(timestamp: TimeInterval)
    case ack(messageId: UInt32)
    case resync(WorldData)  // Force full sync
}
```

#### Task 3.2: Implement Network Entity ID Mapping

**File**: `FactoryForge/Engine/Network/NetworkEntityMapper.swift` (NEW)
- Map server entity IDs to client entities
- Handle entity creation/destruction across network
- Maintain stable `NetworkEntityId` for synchronization

**File**: `FactoryForge/Engine/ECS/Components/NetworkSyncComponent.swift` (NEW)
```swift
struct NetworkSyncComponent: Component {
    var networkEntityId: UInt32  // Stable server-assigned ID
    var lastSyncTime: TimeInterval
    var syncPriority: SyncPriority  // High/Medium/Low
    var ownerPlayerId: UInt32?  // Which player owns this entity
}
```

#### Task 3.3: Interest Management (Chunk-Based)

**File**: `FactoryForge/Engine/Network/InterestManager.swift` (NEW)
- Leverage existing `ChunkManager` for spatial partitioning
- Only send entities in loaded chunks to clients
- Implement chunk visibility based on player position
- Reduce network bandwidth with spatial culling

**Integration**:
- Use `ChunkManager.allLoadedChunks` to determine what to sync
- Only send entities in chunks near player positions
- Implement chunk loading/unloading over network

#### Task 3.4: Client-Side Prediction

**File**: `FactoryForge/Engine/Network/ClientPrediction.swift` (NEW)
- Predict local player movement immediately
- Reconcile with server state periodically
- Handle prediction errors gracefully
- Only predict movement (not combat/building)

### Phase 4: PvP Gameplay Specifics

#### Task 4.1: Lobby/Matchmaking System

**File**: `FactoryForge/Game/Multiplayer/LobbySystem.swift` (NEW)
- Pre-game lobby for match setup
- Player ready system
- Game mode selection
- Map selection
- Starting conditions configuration

**Integration Options**:
- Game Center (iOS native)
- Custom matchmaking service
- Direct IP connection

#### Task 4.2: Spawn Logic & Team Assignment

**File**: `FactoryForge/Game/Multiplayer/SpawnSystem.swift` (NEW)
- Spawn players at designated spawn points
- Assign teams based on game mode
- Handle respawn logic
- Manage starting resources per player

#### Task 4.3: Victory Conditions & Match Lifecycle

**File**: `FactoryForge/Game/Multiplayer/VictorySystem.swift` (NEW)
- Track victory conditions per game mode
- Free-for-All: Last player/team standing
- Team Deathmatch: Team elimination
- Territory Control: Control points
- King of the Hill: Time-based control
- End match and show results

#### Task 4.4: Fog of War (Optional)

**File**: `FactoryForge/Game/Multiplayer/FogOfWarSystem.swift` (NEW)
- Server-authoritative visibility
- Client renders partial state
- Reveal areas based on unit/building positions
- Hide enemy units in unexplored areas

### Phase 5: PvAI (Traditional AI)

#### Task 5.1: Create AIPlayerSystem

**File**: `FactoryForge/Game/AI/AIPlayerSystem.swift` (NEW)
- Manages AI player decision-making
- Issues same command messages as human players
- Reuses `AutoPlaySystem` patterns for scripted openings
- Switches to utility/goal-based behavior

**Integration**:
- AI players are regular `Player` instances with `isAI: true`
- AI issues commands through same `PlayerAction` protocol
- Server processes AI commands same as human commands

#### Task 5.2: Layered AI Architecture

**File**: `FactoryForge/Game/AI/AIEconomyManager.swift` (NEW)
- Mining/production build order
- Resource prioritization
- Production chain optimization
- Inventory management

**File**: `FactoryForge/Game/AI/AIResearchPlanner.swift` (NEW)
- Research priority selection
- Technology tree optimization
- Timing of research unlocks

**File**: `FactoryForge/Game/AI/AIDefenseManager.swift` (NEW)
- Turret placement
- Wall construction
- Unit patrol routes
- Base defense priorities

**File**: `FactoryForge/Game/AI/AIOffenseManager.swift` (NEW)
- Unit production decisions
- Attack target selection
- Unit composition optimization
- Assault coordination

**File**: `FactoryForge/Game/AI/AIDecisionEngine.swift` (NEW)
- Goal-based behavior system
- Utility functions for decision making
- Action planning and execution
- State evaluation

#### Task 5.3: Bootstrap AI with AutoPlaySystem

**File**: `FactoryForge/Game/AI/AIPlayerSystem.swift` (MODIFY)
- Use `AutoPlaySystem` for early game scripted openings
- Transition to goal-based AI after early game
- Combine scripted and dynamic behavior

#### Task 5.4: Difficulty Knobs

**File**: `FactoryForge/Game/AI/AIDifficulty.swift` (NEW)
```swift
struct AIDifficulty {
    var reactionDelay: TimeInterval  // How fast AI reacts
    var decisionFrequency: TimeInterval  // How often AI makes decisions
    var actionBudget: Int  // Actions per decision cycle
    var resourceHandicap: Float  // Resource gathering efficiency (0.5-1.0)
    var scoutingAccuracy: Float  // How well AI knows map (0.0-1.0)
    var tacticalSkill: Float  // Unit control skill (0.0-1.0)
}
```

**Difficulty Presets**:
- Easy: Slow reactions, low efficiency, poor tactics
- Medium: Balanced
- Hard: Fast reactions, high efficiency, good tactics
- Expert: Optimal play

### Phase 6: Testing & Tooling

#### Task 6.1: Record/Replay System

**File**: `FactoryForge/Engine/Network/ReplaySystem.swift` (NEW)
- Record command streams
- Validate deterministic server simulation
- Replay matches for debugging
- Support spectator mode

#### Task 6.2: Network Simulation Harness

**File**: `FactoryForge/Engine/Network/NetworkSimulator.swift` (NEW)
- Simulate latency/jitter/packet loss
- Test client prediction accuracy
- Validate state reconciliation
- Performance testing under network conditions

#### Task 6.3: Server Performance Telemetry

**File**: `FactoryForge/Engine/Core/PerformanceMonitor.swift` (NEW)
- Track tick cost (time per game tick)
- Monitor bandwidth usage
- Track entity counts
- Log performance metrics
- Alert on performance degradation

## Concrete Task List

### Week 1-2: Foundation
- [ ] Task 1.1: Add OwnershipComponent, PlayerComponent, team collision layers
- [ ] Task 1.2: Create PlayerManager and PlayersSystem
- [ ] Task 1.3: Refactor Player class for multi-instance support
- [ ] Task 1.4: Update CombatSystem, UnitSystem for ownership
- [ ] Task 2.1: Make GameLoop headless-safe

### Week 3-4: Networking Core
- [ ] Task 3.1: Create MultiplayerNetworkManager
- [ ] Task 3.2: Implement NetworkEntityId mapping
- [ ] Task 3.3: Interest management (chunk-based)
- [ ] Task 3.4: Client-side prediction
- [ ] Task 2.2: Extract core simulation target

### Week 5-6: PvP Gameplay
- [ ] Task 4.1: Lobby/matchmaking system
- [ ] Task 4.2: Spawn logic & team assignment
- [ ] Task 4.3: Victory conditions & match lifecycle
- [ ] Task 4.4: Fog of war (optional)

### Week 7-8: PvAI Core
- [ ] Task 5.1: Create AIPlayerSystem
- [ ] Task 5.2: Layered AI architecture (economy, research, defense, offense)
- [ ] Task 5.3: Bootstrap with AutoPlaySystem
- [ ] Task 5.4: Difficulty knobs

### Week 9-10: Polish & Testing
- [ ] Task 6.1: Record/replay system
- [ ] Task 6.2: Network simulation harness
- [ ] Task 6.3: Server performance telemetry
- [ ] Integration testing
- [ ] Performance optimization
- [ ] Bug fixes

## File Structure

### New Files
```
FactoryForge/Engine/ECS/Components/
├── OwnershipComponent.swift
├── PlayerComponent.swift
└── NetworkSyncComponent.swift

FactoryForge/Game/Multiplayer/
├── PlayerManager.swift
├── PlayersSystem.swift
├── LobbySystem.swift
├── SpawnSystem.swift
└── VictorySystem.swift

FactoryForge/Game/AI/
├── AIPlayerSystem.swift
├── AIDifficulty.swift
├── AIEconomyManager.swift
├── AIResearchPlanner.swift
├── AIDefenseManager.swift
├── AIOffenseManager.swift
└── AIDecisionEngine.swift

FactoryForge/Engine/Network/
├── MultiplayerNetworkManager.swift
├── NetworkEntityMapper.swift
├── InterestManager.swift
├── ClientPrediction.swift
├── ReplaySystem.swift
└── NetworkSimulator.swift

FactoryForge/Engine/Core/
├── SimulationCore.swift
└── PerformanceMonitor.swift
```

### Modified Files
```
FactoryForge/Game/Player/Player.swift
FactoryForge/Engine/Core/GameLoop.swift
FactoryForge/Engine/Core/Time.swift
FactoryForge/Game/Systems/CombatSystem.swift
FactoryForge/Game/Systems/UnitSystem.swift
FactoryForge/Engine/ECS/Components/PositionComponent.swift
FactoryForge/Data/SaveSystem.swift
```

## Key Design Decisions

### Server Architecture
- **Authoritative Server**: One authoritative server validates all actions
- **Client Prediction**: Only for movement, not combat/building
- **State Sync**: Delta compression with periodic full snapshots
- **Interest Management**: Chunk-based spatial culling

### AI Architecture
- **Server-Side**: AI runs on server (recommended for consistency)
- **Offline Support**: Can also run locally for single-player
- **Hybrid Approach**: Scripted early game + goal-based mid/late game
- **Difficulty Scaling**: Multiple knobs for fine-tuning

### Network Protocol
- **TCP**: Reliable delivery for critical messages
- **UDP**: Optional for high-frequency updates (with reliability layer)
- **Compression**: Delta encoding, entity ID references
- **Batching**: Group multiple updates per packet

## Risk Mitigation

### Technical Risks
1. **Network Complexity**: Start with simple client-server, iterate
2. **AI Performance**: Profile early, optimize hot paths, throttle decisions
3. **State Synchronization**: Use proven patterns, test thoroughly
4. **Determinism**: Fixed-point math where needed, synchronized RNG

### Design Risks
1. **Balance**: Extensive playtesting required
2. **AI Difficulty**: Tune based on player feedback
3. **Network Requirements**: Support offline AI mode as fallback

## Success Metrics

### PvP Metrics
- Average match duration: 15-60 minutes
- Player retention in PvP mode
- Network stability: <5% disconnect rate
- Player satisfaction scores

### PvAI Metrics
- AI win rate: 30-70% at Medium difficulty
- Average game duration: 20-40 minutes
- AI decision quality (subjective evaluation)
- Performance impact: <10% FPS drop during AI turns

## Open Questions (Resolved with Assumptions)

1. **Max players**: 2-8 players (RTS-style) ✅
2. **Match length**: 15-60 minutes typical ✅
3. **Server**: Dedicated authoritative server (cloud-hosted) ✅
4. **PvAI location**: Server-side recommended, offline support optional ✅
5. **Co-op vs competitive**: Both modes supported ✅

## Next Steps

1. Review and approve this plan
2. Set up development environment for server/client split
3. Begin Phase 1 implementation
4. Set up testing infrastructure
5. Create detailed design docs for each system
