# Fluid Mechanics Implementation Summary

## Overview
The fluid mechanics system in FactoryForge implements a Factorio-like fluid network with pipes, pumps, producers, consumers, and storage tanks. It supports complex fluid flow simulation, network management, and integration with the existing ECS architecture.

## Core Components

### 1. Fluid Data Structures

#### FluidType Enum
- `water`, `crudeOil`, `petroleumGas`, `lightOil`, `heavyOil`, `steam`
- Each with properties: density, viscosity, temperature, energyValue

#### FluidStack Struct
- Represents a quantity of fluid with type, current amount, and max capacity
- Methods: `add(amount:)`, `remove(amount:)`, `isEmpty`, `isFull`

#### FluidNetwork Struct
- Manages collections of pipes, producers, consumers, tanks, and pumps
- Network ID for merging/splitting logic
- Capacity calculations and flow distribution

### 2. Entity Components

#### PipeComponent
- `connections`: Set of Direction for pipe connections
- `fluidType`: Current fluid type (nil if empty)
- `fluidAmount`: Current fluid volume
- `maxCapacity`: Pipe capacity (10L default)
- `flowDirection`: Direction of fluid flow
- `networkId`: Network membership
- `pressure`: Current pressure in pipe

#### FluidProducerComponent
- `outputType`: FluidType being produced
- `productionRate`: Units per second
- `powerConsumption`: Electricity required (0 for passive producers)
- `networkId`: Network membership

#### FluidConsumerComponent
- `inputType`: FluidType being consumed
- `consumptionRate`: Units per second
- `efficiency`: Consumption efficiency multiplier
- `networkId`: Network membership

#### FluidTankComponent
- `tanks`: Array of FluidStack for multiple fluid types
- `maxCapacity`: Total capacity across all tanks
- `buildingId`: Associated building
- `networkId`: Network membership

#### FluidPumpComponent
- `inputDirection`: Direction fluid enters
- `outputDirection`: Direction fluid exits
- `pumpRate`: Flow rate multiplier
- `powerConsumption`: Electricity required
- `networkId`: Network membership

## FluidNetworkSystem

### Network Discovery
- Uses flood-fill algorithm starting from pipe entities
- Discovers connected networks of pipes, buildings, and tanks
- Assigns network IDs to all connected components

### Network Merging/Splitting
- **Merging**: When pipes connect, combines smaller networks into larger ones
- **Splitting**: When pipes disconnect, breaks networks apart
- Maintains flow continuity during topology changes

### Flow Simulation
- **Pressure Calculation**: Distributes pressure from producers through network
- **Flow Distribution**: Balances fluid flow based on pressure gradients
- **Backpressure**: Prevents overfilling by limiting flow to available capacity
- **Network Optimization**: Throttled updates for performance with large networks

### Performance Optimizations
- `entityPositions`, `entityConnections`, `networksByPosition` caches
- Throttled updates based on `maxNetworkSize` and `updateFrequency`
- Simplified flow calculations for large networks
- Periodic cache cleanup and optimization

## Building Integration

### Producers
- **Boiler**: Consumes water (1.8L/s) + fuel → produces steam (1.8L/s)
- **Water Pump**: Produces water (20L/s) from water tiles, no power required
- **Pumpjack**: Produces crude oil (varies by yield)

### Consumers
- **Steam Engine**: Consumes steam (1.8L/s) → generates electricity
- **Chemical Plant**: Consumes petroleum gas/light oil → produces various products

### Processors
- **Oil Refinery**: Crude oil → petroleum gas + light oil + heavy oil
- **Chemical Plant**: Various fluid + item processing recipes

### Storage
- **Storage Tank**: High-capacity fluid storage (25kL default)
- **Building Tanks**: Integrated storage for processing buildings

## UI and Visualization

### Pipe UI
- Connection dots showing pipe connections
- Flow direction arrows
- Fluid level indicators
- Pressure visualization (debug mode)

### Building UI
- Fluid input/output indicators
- Tank level bars
- Flow rate tooltips
- Recipe fluid requirements

### Debug Tools
- Network boundaries overlay
- Flow direction visualization
- Pressure maps
- Fluid type coloring

## Save/Load Integration

### Serialization
- All fluid components implement Codable
- PositionComponents automatically indexed in spatial index
- Network relationships preserved

### Loading Process
1. Deserialize entities with fluid components
2. Rebuild spatial index (ensures selectability)
3. Register belts and fluid networks
4. Add entities to chunks for spatial queries

## Flow Mechanics

### Basic Flow
1. Producers add fluid to connected pipes/tanks
2. Fluid flows through connected pipe networks
3. Consumers remove fluid from connected pipes/tanks
4. Excess fluid stored in tanks

### Advanced Features
- **Pressure Simulation**: Fluid flows from high to low pressure
- **Network Balancing**: Flow distributed based on resistance and capacity
- **Backpressure**: Consumers can limit flow when unable to process
- **Multi-fluid Support**: Different fluids don't mix in same network

### Performance
- O(n) network discovery with flood-fill
- Cached entity lookups for fast updates
- Throttled calculations prevent performance issues
- Spatial indexing for fast position queries

## Integration Points

### ECS Integration
- All components follow ECS patterns
- World.add() automatically manages spatial indexing
- Query system for efficient component access

### GameLoop Integration
- Building placement adds appropriate fluid components
- Crafting system handles fluid I/O for recipes
- Power system integration for powered producers/consumers

### Rendering Integration
- SpriteRenderer handles fluid visualizations
- Debug overlays toggleable via MetalRenderer
- Camera-aware culling for performance

## Balance and Tuning

### Production Rates
- Water Pump: 20L/s (matches Factorio offshore pump)
- Boiler: 1.8L/s steam production
- Steam Engine: 1.8L/s steam consumption
- Pumpjack: Variable based on yield

### Capacities
- Pipes: 10L default
- Storage Tanks: 25,000L
- Building tanks: Varies (540L for boiler water)

### Fluid Properties
- Water: density 1.0, viscosity 1.0
- Oil: density 0.8-0.9, viscosity 2.0-12.0
- Steam: energy value 500, high flow rate

## Testing and Validation

### Unit Tests
- FluidStack operations
- Network merging/splitting
- Flow calculations
- Component serialization

### Integration Tests
- Complete production chains
- Save/load persistence
- Performance with large networks
- UI responsiveness

## Future Extensions

### Planned Features
- Underground pipes
- Pipe pumps for long-distance transport
- Fluid mixing in chemical plants
- Advanced network optimization
- Multi-direction pumps

### Performance Improvements
- Parallel network processing
- Hierarchical network management
- GPU-accelerated flow simulation
- Advanced caching strategies

This implementation provides a solid foundation for fluid mechanics in FactoryForge, supporting complex production chains and network management with good performance characteristics.