# Fluid Mechanics Implementation Plan

## Overview

This document outlines the comprehensive implementation of fluid pipes and fluid mechanics in FactoryForge, bringing the game closer to Factorio's fluid handling system.

## Current State Analysis

### Existing Components
- `PipeComponent`: Basic pipe with direction and fluid storage
- Fluid types: water, crude-oil (mentioned in code)
- Basic fluid storage in pipes (maxCapacity: 100)

### Buildings with Fluid Interactions
- **Producers**: Oil wells (crude oil), water pumps (water), boilers (steam)
- **Consumers**: Steam engines (steam), chemical plants, oil refineries
- **Storage**: Currently minimal fluid storage

### Missing Mechanics
- Fluid flow between connected pipes
- Fluid networks (like power networks)
- Fluid consumption/production balancing
- Pipe connections and visualization

## Phase 1: Core Fluid Data Structures

### 1.1 Fluid Types Definition
```swift
enum FluidType: String, Codable {
    case water
    case steam
    case crudeOil = "crude-oil"
    case heavyOil = "heavy-oil"
    case lightOil = "light-oil"
    case petroleumGas = "petroleum-gas"
    case sulfuricAcid = "sulfuric-acid"
    case lubricant
}
```

### 1.2 Fluid Properties
```swift
struct FluidProperties {
    let density: Float  // kg/L
    let viscosity: Float  // Flow resistance
    let temperature: Float  // °C
    let energyValue: Float  // For steam, etc.
}
```

### 1.3 Fluid Stack
```swift
struct FluidStack {
    let type: FluidType
    var amount: Float  // Liters
    let temperature: Float
    let maxAmount: Float
}
```

## Phase 2: Component Updates

### 2.1 Enhanced PipeComponent
```swift
class PipeComponent: BuildingComponent {
    // Existing properties
    var direction: Direction
    var fluidType: FluidType?
    var fluidAmount: Float
    var maxCapacity: Float

    // New properties
    var connections: [Entity]  // Connected pipes
    var flowRate: Float  // Current flow rate L/s
    var pressure: Float  // System pressure
    var networkId: Int?  // Which fluid network this belongs to
}
```

### 2.2 FluidTankComponent
```swift
class FluidTankComponent: BuildingComponent {
    var tanks: [FluidStack]  // Multiple fluid types
    var maxCapacity: Float
    var connections: [Entity]  // Connected pipes
}
```

### 2.3 FluidPumpComponent
```swift
class FluidPumpComponent: BuildingComponent {
    var inputConnection: Entity?
    var outputConnection: Entity?
    var flowRate: Float  // L/s
    var powerConsumption: Float
    var isActive: Bool
}
```

### 2.4 FluidProducerComponent
```swift
class FluidProducerComponent: BuildingComponent {
    var outputType: FluidType
    var productionRate: Float  // L/s
    var currentProduction: Float
    var powerConsumption: Float
}
```

### 2.5 FluidConsumerComponent
```swift
class FluidConsumerComponent: BuildingComponent {
    var inputType: FluidType
    var consumptionRate: Float  // L/s
    var currentConsumption: Float
    var efficiency: Float  // 0-1
}
```

## Phase 3: Fluid Network System

### 3.1 FluidNetwork Structure
```swift
struct FluidNetwork {
    var id: Int
    var fluidType: FluidType?
    var pipes: [Entity] = []
    var producers: [Entity] = []
    var consumers: [Entity] = []
    var tanks: [Entity] = []
    var totalCapacity: Float = 0
    var totalFluid: Float = 0
    var pressure: Float = 0
}
```

### 3.2 FluidNetworkSystem
- **Network Discovery**: Flood-fill algorithm to find connected pipes
- **Network Merging**: Combine networks when pipes connect
- **Network Splitting**: Split networks when pipes disconnect
- **Flow Calculation**: Determine fluid flow rates and directions

### 3.3 FluidFlowSystem
- **Pressure Simulation**: Calculate pressure gradients
- **Flow Balancing**: Distribute fluids based on pressure and demand
- **Network Updates**: Update fluid levels across the network

## Phase 4: Building Updates

### 4.1 Boiler Updates
```swift
// Current: Simple generator
// Future: Fluid producer + fuel consumer
- Consumes: Fuel (coal/wood) + Water
- Produces: Steam (fluid)
- Requires: Water input pipe + fuel inventory
```

### 4.2 Steam Engine Updates
```swift
// Current: Constant power generator
// Future: Fluid consumer + power producer
- Consumes: Steam (fluid)
- Produces: Electricity
- Requires: Steam input pipe
- Stops when steam unavailable
```

### 4.3 Oil Refinery Updates
```swift
// Current: Item processor
// Future: Fluid processor
- Consumes: Crude oil (fluid)
- Produces: Petroleum gas, light oil, heavy oil (fluids)
- Requires: Input/output fluid connections
```

### 4.4 Chemical Plant Updates
```swift
// Current: Item processor
// Future: Mixed fluid/item processor
- Consumes: Various fluids + items
- Produces: Various fluids + items
- Complex fluid routing
```

## Phase 5: Pipe Connection Mechanics

### 5.1 Connection Rules
- Pipes connect to adjacent pipes automatically
- Buildings connect to pipes based on proximity and direction
- Underground pipes create virtual connections
- Pumps create directional flow

### 5.2 Connection Visualization
- Highlight connected pipes when selecting buildings
- Show flow direction arrows
- Color-code fluid types in pipes
- Visual indicators for pressure/flow rate

### 5.3 Pipe Placement Logic
- Automatic connection detection during placement
- Network merging when pipes connect
- Network splitting when pipes removed

## Phase 6: UI and User Experience

### 6.1 Pipe UI
- Pipe connection overlay when placing buildings
- Fluid level indicators on pipes
- Flow rate tooltips
- Pipe content visualization

### 6.2 Building UI Updates
- Fluid input/output indicators
- Tank level displays
- Production/consumption rates
- Fluid routing configuration

### 6.3 Fluid Network Tools
- Network visualization mode
- Flow rate debugging
- Pressure maps
- Bottleneck identification

## Phase 7: Fluid Balance and Gameplay

### 7.1 Fluid Properties
```
Water:     Density 1.0, Flow rate 100 L/s
Steam:     Density 0.5, Flow rate 200 L/s, Temperature 165°C
Crude Oil: Density 0.8, Flow rate 75 L/s, Viscosity high
Light Oil: Density 0.7, Flow rate 90 L/s
Heavy Oil: Density 0.9, Flow rate 60 L/s
```

### 7.2 Production Rates
- Oil well: 10 crude oil/s
- Water pump: 20 water/s
- Boiler: 30 steam/s (when fueled + water available)
- Steam engine: 30 steam/s consumption = 510 kW output

### 7.3 Storage Capacities
- Basic pipe: 100L
- Underground pipe: 300L
- Storage tank: 25000L
- Chemical plant tank: 500L per fluid type

## Phase 8: Implementation Order

### 8.1 Phase 1 Priority (Core Infrastructure)
1. Fluid types and properties
2. Enhanced PipeComponent
3. Basic FluidNetworkSystem
4. Pipe connection mechanics

### 8.2 Phase 2 Priority (Producer/Consumer)
1. FluidProducerComponent (oil wells, water pumps)
2. FluidConsumerComponent (steam engines)
3. Update existing buildings
4. Basic flow simulation

### 8.3 Phase 3 Priority (Complex Systems)
1. FluidTankComponent
2. FluidPumpComponent
3. Chemical plant fluid processing
4. Advanced flow balancing

### 8.4 Phase 4 Priority (Polish)
1. UI improvements
2. Visual effects
3. Performance optimization
4. Balance tuning

## Phase 9: Testing and Validation

### 9.1 Unit Tests
- Fluid flow calculations
- Network merging/splitting
- Building interactions

### 9.2 Integration Tests
- Complete production chains (oil → refinery → chemical plant)
- Power generation (boiler → steam engine)
- Large-scale factory setups

### 9.3 Performance Testing
- Network size limits
- Flow calculation efficiency
- Memory usage with many pipes

## Phase 10: Future Extensions

### 10.1 Advanced Features
- Fluid mixing and separation
- Temperature-based flow changes
- Fluid cooling/heating mechanics
- Fluid pollution and cleanup

### 10.2 Multiplayer Considerations
- Network synchronization
- Fluid state consistency
- Real-time flow updates

### 10.3 Modding Support
- Custom fluid types
- Custom fluid processors
- Fluid recipe system

## Dependencies and Prerequisites

### Required Before Implementation
- [x] Building component system
- [x] Power network system (as reference)
- [x] Inventory system
- [ ] Pipe placement and rotation
- [ ] Basic fluid storage in pipes

### Skills Needed
- Network graph algorithms
- Fluid dynamics simulation
- Real-time system optimization
- UI state management

## Risk Assessment

### High Risk
- Complex fluid flow simulation
- Performance with large pipe networks
- UI complexity for fluid management

### Medium Risk
- Network merging/splitting logic
- Building-fluid interactions
- Balance tuning

### Low Risk
- Fluid type definitions
- Basic pipe connections
- Visual indicators

## Success Metrics

### Functional
- [ ] Pipes connect and transport fluids correctly
- [ ] Buildings consume/produce fluids as expected
- [ ] Fluid networks merge/split properly
- [ ] No fluid leaks or infinite loops

### Performance
- [ ] <50ms for network calculations
- [ ] <100MB memory for 1000+ pipes
- [ ] 60 FPS with fluid animations

### Usability
- [ ] Intuitive pipe placement
- [ ] Clear fluid flow visualization
- [ ] Easy debugging of fluid issues

## Conclusion

Implementing fluid mechanics will significantly enhance FactoryForge's fidelity to Factorio while adding depth to factory design. The modular approach allows for incremental implementation, starting with basic fluid transport and gradually adding complexity.

The system will enable complex production chains like oil processing, steam power generation, and chemical manufacturing that are core to Factorio's gameplay.