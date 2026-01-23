# Player vs Player (PvP) and Player vs AI (PvAI) Implementation Plan

## Overview

This document outlines the implementation plan for adding multiplayer PvP and single-player PvAI (traditional AI opponent) modes to FactoryForge. The plan is designed to work with the existing ECS architecture, combat systems, and network infrastructure.

## Current Architecture Analysis

### Existing Systems
- **ECS Architecture**: Entity Component System with World, Components, and Systems
- **Player System**: Single `Player` class managing one player entity
- **Combat System**: Handles damage, health, armor, and combat mechanics
- **Unit System**: Manages player-controlled units with commands
- **Enemy AI System**: Handles enemy (biter) AI targeting the player
- **Network Manager**: Currently used for MCP communication (debugging/control)
- **Game Loop**: Coordinates all systems in a fixed timestep loop

### Key Components
- `Player`: Single player instance with inventory, position, health
- `UnitComponent`: Player-controlled combat units
- `EnemyComponent`: Enemy entities (biters)
- `CombatSystem`: Damage application and combat resolution
- `UnitSystem`: Unit command execution and AI
- `EnemyAISystem`: Enemy behavior and targeting

## Implementation Strategy

### Phase 1: Multi-Player Foundation

#### 1.1 Player Management System

**New Component: `PlayerComponent`**
```swift
struct PlayerComponent: Component {
    let playerId: UInt32  // Unique player identifier
    let playerName: String
    var teamId: UInt32?  // For team-based modes
    var isAI: Bool  // True for AI players
    var aiDifficulty: AIDifficulty?  // For AI players
}
```

**New System: `PlayerManagerSystem`**
- Manages multiple player instances
- Tracks player connections (for PvP)
- Handles player spawning/despawning
- Manages player teams/alliances
- Provides player lookup by ID

**Changes to `Player` class:**
- Add `playerId: UInt32` property
- Make it support multiple instances (remove singleton assumptions)
- Add team/ally tracking
- Support AI player mode

#### 1.2 Network Architecture for PvP

**Extend `GameNetworkManager`:**
- Add peer-to-peer or client-server networking
- Implement player connection/disconnection handling
- Add game state synchronization protocol
- Implement authoritative server or lockstep simulation

**Network Protocol:**
```
Message Types:
- player_join: New player connecting
- player_leave: Player disconnecting
- player_action: Player input (move, build, attack)
- game_state_sync: Periodic state synchronization
- player_state: Individual player state update
```

**Synchronization Strategy:**
- **Option A: Authoritative Server**: One client acts as server, others as clients
- **Option B: Lockstep**: All clients run simulation, sync deterministic events
- **Option C: Hybrid**: Server for critical events, clients for local prediction

**Recommended: Hybrid approach**
- Server validates critical actions (combat, building placement)
- Clients handle local prediction for movement/UI
- Periodic state reconciliation

#### 1.3 Game State Synchronization

**Synchronized State:**
- Player positions and health
- Unit positions and commands
- Building placement/destruction
- Resource deposits (shared or per-player)
- Combat events
- Research progress

**State Delta Compression:**
- Only send changed state
- Use entity IDs for references
- Batch updates to reduce network traffic

**New Component: `NetworkSyncComponent`**
```swift
struct NetworkSyncComponent: Component {
    var lastSyncTime: TimeInterval
    var syncPriority: SyncPriority  // High/Medium/Low
    var ownerPlayerId: UInt32?  // Which player owns this entity
}
```

### Phase 2: Player vs Player (PvP)

#### 2.1 PvP Game Modes

**Free-for-All:**
- All players compete independently
- Last player/team standing wins
- Shared or separate resource areas

**Team Deathmatch:**
- Players divided into teams
- Team-based victory conditions
- Shared team resources/units

**Territory Control:**
- Control key resource areas
- Capture points or resource nodes
- Victory based on territory held

**King of the Hill:**
- Control central objective
- Accumulate points over time
- First to target points wins

#### 2.2 PvP Combat Modifications

**Changes to `CombatSystem`:**
- Add player vs player damage rules
- Implement friendly fire toggle
- Add team-based damage filtering
- Track PvP kill/death statistics

**Changes to `UnitSystem`:**
- Units can target other players' units
- Add unit ownership tracking
- Implement unit command validation (can't control other player's units)

**New Component: `OwnershipComponent`**
```swift
struct OwnershipComponent: Component {
    let ownerPlayerId: UInt32
    var canBeStolen: Bool  // For resources/buildings
}
```

#### 2.3 PvP UI/UX

**New UI Elements:**
- Player list showing all players
- Team assignment interface
- Victory/defeat screens
- Spectator mode for eliminated players
- Minimap showing player positions
- Resource comparison display

**Lobby System:**
- Pre-game lobby for match setup
- Player ready system
- Game mode selection
- Map selection
- Starting conditions configuration

### Phase 3: Player vs AI (PvAI)

#### 3.1 AI Player System

**New System: `AIPlayerSystem`**
- Manages AI player decision-making
- Reuses existing `EnemyAISystem` patterns but for full player behavior
- Handles AI resource management, building, unit production

**AI Difficulty Levels:**

**Easy:**
- Slower resource gathering
- Less aggressive expansion
- Basic unit tactics
- Limited research focus

**Medium:**
- Balanced resource management
- Moderate expansion
- Standard unit tactics
- Balanced research

**Hard:**
- Efficient resource optimization
- Aggressive expansion
- Advanced unit tactics (flanking, formations)
- Strategic research priorities

**Expert:**
- Optimal resource management
- Very aggressive expansion
- Complex unit coordination
- Research optimization

#### 3.2 AI Decision Making

**AI Subsystems:**

**1. Resource Management AI:**
- Prioritize resource gathering based on needs
- Balance production vs consumption
- Optimize mining drill placement
- Manage inventory efficiently

**2. Building AI:**
- Strategic building placement
- Defense construction
- Production chain optimization
- Expansion planning

**3. Unit Production AI:**
- Unit type selection based on situation
- Production queue management
- Unit composition optimization

**4. Combat AI:**
- Unit positioning and formations
- Target prioritization
- Tactical retreats
- Coordinated attacks

**5. Research AI:**
- Research priority selection
- Technology tree optimization
- Timing of research unlocks

**AI State Machine:**
```
States:
- Early Game: Focus on resource gathering, basic production
- Expansion: Build new bases, expand territory
- Military: Produce units, prepare for combat
- Aggressive: Attack enemy bases/units
- Defensive: Fortify, defend against attacks
- Late Game: Advanced production, research, large-scale combat
```

#### 3.3 AI Implementation Details

**Reuse Existing Systems:**
- `UnitSystem` for unit control (AI issues commands)
- `CombatSystem` for combat resolution
- `EnemyAISystem` patterns for unit AI behavior

**New AI Components:**
```swift
struct AIPlayerComponent: Component {
    let difficulty: AIDifficulty
    var currentState: AIGameState
    var decisionTimer: Float
    var lastDecisionTime: TimeInterval
}

enum AIGameState {
    case earlyGame
    case expansion
    case military
    case aggressive
    case defensive
    case lateGame
}
```

**AI Decision Loop:**
1. Assess current situation (resources, threats, opportunities)
2. Evaluate goals (what needs to be done)
3. Generate action plan (sequence of actions)
4. Execute actions (build, move units, research)
5. Monitor results and adjust

**AI Action Queue:**
- Similar to unit command queue
- Prioritized action list
- Can be interrupted by urgent events (attacks)

### Phase 4: Integration and Testing

#### 4.1 Game Mode Selection

**New System: `GameModeSystem`**
- Manages current game mode
- Handles mode-specific rules
- Coordinates player setup

**Game Modes:**
```swift
enum GameMode {
    case singlePlayer
    case pvpFreeForAll(players: [PlayerConfig])
    case pvpTeamDeathmatch(teams: [Team])
    case pvai(difficulty: AIDifficulty, aiCount: Int)
    case pvpTerritoryControl(players: [PlayerConfig])
}
```

#### 4.2 Save/Load for Multiplayer

**Modifications to `SaveSystem`:**
- Save multiple player states
- Save network connection info
- Handle partial saves (spectator mode)
- Support replay system

#### 4.3 Performance Optimization

**Multiplayer Optimizations:**
- Entity culling (only sync visible entities)
- Level-of-detail for distant entities
- Network message batching
- Client-side prediction
- Lag compensation

**AI Optimizations:**
- Throttle AI decision frequency
- Cache AI calculations
- Use spatial partitioning for AI queries
- Async AI processing where possible

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)
1. Create `PlayerComponent` and `PlayerManagerSystem`
2. Refactor `Player` class to support multiple instances
3. Extend `GameNetworkManager` for multiplayer networking
4. Implement basic player connection/disconnection
5. Add player state synchronization

### Phase 2: PvP Core (Weeks 3-4)
1. Implement PvP combat rules
2. Add team/alliance system
3. Create ownership tracking
4. Implement basic PvP game modes
5. Add PvP UI elements

### Phase 3: PvAI Core (Weeks 5-6)
1. Create `AIPlayerSystem`
2. Implement resource management AI
3. Implement building AI
4. Implement unit production AI
5. Implement combat AI

### Phase 4: AI Advanced (Weeks 7-8)
1. Implement research AI
2. Add difficulty levels
3. Implement AI state machine
4. Add AI personality variations
5. Optimize AI performance

### Phase 5: Polish (Weeks 9-10)
1. Add lobby system
2. Implement spectator mode
3. Add victory conditions
4. Performance optimization
5. Testing and bug fixes

## Technical Considerations

### Network Latency Handling

**Client-Side Prediction:**
- Predict local actions immediately
- Reconcile with server state
- Handle prediction errors gracefully

**Lag Compensation:**
- Store recent game states
- Rewind time for hit detection
- Apply damage based on past positions

**Interpolation:**
- Smooth entity movement between updates
- Extrapolate for missing updates
- Handle jitter and packet loss

### Deterministic Simulation

**For Lockstep (if chosen):**
- Use fixed-point math where needed
- Ensure deterministic random number generation
- Synchronize random seeds
- Handle desync detection and recovery

### Security Considerations

**Anti-Cheat:**
- Server-side validation of all actions
- Rate limiting for actions
- Validate resource costs
- Detect impossible actions (teleportation, etc.)

**Network Security:**
- Encrypt sensitive data
- Validate player authentication
- Prevent connection hijacking
- Rate limit connections

## File Structure

### New Files

```
FactoryForge/Game/Multiplayer/
├── PlayerComponent.swift
├── PlayerManagerSystem.swift
├── OwnershipComponent.swift
├── NetworkSyncComponent.swift
├── GameModeSystem.swift
└── AIPlayerSystem.swift

FactoryForge/Game/AI/
├── AIPlayerComponent.swift
├── AIResourceManager.swift
├── AIBuildingPlanner.swift
├── AICombatTactics.swift
└── AIDecisionEngine.swift

FactoryForge/Engine/Network/
├── MultiplayerNetworkManager.swift
├── GameStateSync.swift
└── NetworkProtocol.swift

FactoryForge/UI/Multiplayer/
├── LobbyUI.swift
├── PlayerListUI.swift
├── TeamSelectionUI.swift
└── VictoryScreen.swift
```

### Modified Files

```
FactoryForge/Game/Player/Player.swift
FactoryForge/Engine/Network/GameNetworkManager.swift
FactoryForge/Game/Systems/CombatSystem.swift
FactoryForge/Game/Systems/UnitSystem.swift
FactoryForge/Engine/Core/GameLoop.swift
FactoryForge/Data/SaveSystem.swift
```

## Testing Strategy

### Unit Tests
- Player management
- Network message serialization
- AI decision making
- Combat calculations

### Integration Tests
- Multiplayer connection flow
- Game state synchronization
- AI behavior in various scenarios
- PvP combat scenarios

### Performance Tests
- Network bandwidth usage
- AI CPU usage
- Multiplayer frame rate
- Large-scale unit battles

## Future Enhancements

### Post-Release Features
- Replay system
- Matchmaking service
- Leaderboards
- Custom game modes
- Mod support for AI personalities
- Co-op vs AI mode
- Campaign mode with AI opponents

## Risk Mitigation

### Technical Risks
- **Network complexity**: Start with simple client-server, iterate
- **AI performance**: Profile early, optimize hot paths
- **State synchronization**: Use proven patterns, test thoroughly
- **Compatibility**: Test on multiple devices/networks

### Design Risks
- **Balance**: Extensive playtesting required
- **AI difficulty**: Tune based on player feedback
- **Network requirements**: Support offline AI mode

## Success Metrics

### PvP Metrics
- Average match duration
- Player retention in PvP mode
- Network stability (disconnect rate)
- Player satisfaction scores

### PvAI Metrics
- AI win rate at each difficulty
- Average game duration
- AI decision quality (subjective)
- Performance impact (FPS during AI turns)

## Conclusion

This plan provides a comprehensive roadmap for implementing PvP and PvAI modes. The phased approach allows for iterative development and testing. Key success factors:

1. **Solid Foundation**: Multiplayer infrastructure must be robust
2. **Balanced AI**: AI should be challenging but fair
3. **Smooth Networking**: Minimize lag and disconnects
4. **Clear Progression**: Players should understand how to improve

The implementation leverages existing systems where possible while adding new components for multiplayer and AI functionality. Regular testing and iteration will be crucial for success.
