# 🎮 Auto-Play System Plan for FactoryForge

## Overview

This document outlines a comprehensive auto-play system for FactoryForge that enables automated testing, performance validation, and demo creation. The system allows the game to run autonomously with predefined scenarios, automated building placement, and performance monitoring.

## Core Architecture

### New Components

- **`AutoPlaySystem`** - Main controller for automated gameplay
- **`ScenarioManager`** - Manages predefined test scenarios
- **`AutoBuilder`** - Handles automatic building placement and connection
- **`PerformanceMonitor`** - Tracks FPS, entity counts, production rates

### Integration Points

- **GameLoop**: Time controls and system integration
- **InputManager**: Automated input simulation
- **Entity Systems**: Automated interactions with buildings and belts

## Auto-Play Modes

### Mode Types

```swift
enum AutoPlayMode {
    case scenario(name: String)        // Run predefined scenarios
    case randomBuilds                  // Random building placement
    case performanceTest               // Stress test with many entities
    case demo                          // Showcase mode
    case productionChain               // Automated production chains
}
```

### Time Controls

```swift
enum GameSpeed {
    case paused        // 0x speed
    case normal        // 1x speed
    case fast          // 2x speed
    case faster        // 4x speed
    case fastest       // 8x speed
    case unlimited     // Max speed for testing
}
```

## Scenario System

### Scenario Definition

```swift
struct GameScenario {
    let name: String
    let description: String
    let steps: [ScenarioStep]
    let duration: TimeInterval?
    let successCriteria: [SuccessCondition]
}

enum ScenarioStep {
    case wait(seconds: Double)
    case placeBuilding(type: String, position: IntVector2, direction: Direction)
    case connectBuildings(from: IntVector2, to: IntVector2)
    case startProduction(at: IntVector2)
    case setGameSpeed(GameSpeed)
    case takeScreenshot(name: String)
}
```

### Example Scenarios

- **"Basic Mining"**: Miner → Furnace → Assembler production chain
- **"Belt Network"**: Complex belt routing and load balancing
- **"Performance Test"**: Spawn 100+ buildings, measure FPS
- **"Demo Loop"**: Automated showcase of all game features

## Automated Building System

### Smart Placement Logic

```swift
class AutoBuilder {
    func findOptimalPosition(for buildingType: String,
                           near existingBuildings: [Entity]) -> IntVector2?

    func placeProductionChain(resources: [String],
                             products: [String]) -> [Entity]

    func connectWithBelts(from source: Entity, to destination: Entity)
}
```

### Features

- **Collision Detection**: Avoid overlapping buildings
- **Resource Optimization**: Place miners near ore deposits
- **Belt Pathfinding**: Automatically route belts between buildings
- **Production Balancing**: Ensure supply meets demand

## Performance Monitoring

### Metrics Tracked

```swift
struct PerformanceMetrics {
    var fps: Double
    var entityCount: Int
    var buildingsByType: [String: Int]
    var productionRates: [String: Double]
    var memoryUsage: Int
    var renderTime: Double
}
```

### Automated Testing

- Run scenarios and collect performance data
- Generate reports on bottlenecks
- Compare performance across game versions
- Identify memory leaks and performance regressions

## Implementation Phases

### Phase 1: Basic Auto-Play ✅

- [x] Time controls (speed up/slow down)
- [x] Simple scenario playback
- [x] Basic automated building placement
- [x] iPhone-compatible UI (LoadingMenu + AutoPlayMenu)
- [x] Text-based configuration interface

### Phase 2: Advanced Scenarios

- [ ] Complex production chains
- [ ] Belt network automation
- [ ] Resource management AI

### Phase 3: Testing Framework

- [ ] Performance monitoring
- [ ] Automated test suites
- [ ] Regression testing
- [ ] Benchmark comparisons

### Phase 4: Demo System

- [ ] Automated game showcases
- [ ] Tutorial automation
- [ ] Marketing demo loops

## User Interface

### Debug Overlay

- Current scenario progress
- Performance metrics display
- Auto-play controls (play/pause/speed)

### Console Commands

```
/autoplay scenario basic_mining
/autoplay speed 4x
/autoplay performance_test 100_buildings
/autoplay demo
```

## Integration Strategy

### Minimal Changes Required

- Add `AutoPlaySystem` to `GameLoop.systems`
- Extend `GameLoop` with time control methods
- Add scenario loading from JSON/embedded data
- Hook into existing building placement logic

### Backward Compatibility

- Auto-play is opt-in, doesn't affect normal gameplay
- All existing features remain unchanged
- Can be toggled on/off at runtime

## Testing Benefits

### Automated Testing

- ✅ Regression testing for game mechanics
- ✅ Performance benchmarking
- ✅ Scenario validation
- ✅ Build stress testing

### Development Workflow

- ✅ Quick iteration testing
- ✅ Demo creation
- ✅ Performance profiling
- ✅ CI/CD integration

## Implementation Priority

**Recommended starting order:**

1. **Time controls** (speed up/down game) - High impact, low complexity
2. **Basic scenario system** (predefined test sequences) - Core functionality
3. **Automated building placement** - Useful for testing
4. **Performance monitoring** - Advanced testing features

## Success Criteria

- [ ] Game can run automated scenarios without user input
- [ ] Performance testing identifies bottlenecks
- [ ] Demo mode showcases game features effectively
- [ ] Automated testing catches regressions
- [ ] System doesn't impact normal gameplay performance
