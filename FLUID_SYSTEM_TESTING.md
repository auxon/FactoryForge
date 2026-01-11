# Fluid System Integration Testing

## Test Overview
This document outlines comprehensive testing for the complete fluid production chains implemented in FactoryForge.

## Test Scenarios

### Scenario 1: Oil Production Chain
**Goal**: Verify oil well → refinery → chemical plant fluid processing

#### Setup:
1. Place oil well
2. Place pipes connecting oil well output
3. Place oil refinery connected to pipes
4. Place chemical plant connected to refinery output pipes
5. Place additional pipes for fluid transport

#### Expected Behavior:
1. **Oil Well Production**:
   - Produces 10 crude oil L/s when powered
   - Fluid appears in connected pipes
   - Pipes show crude oil fluid levels and tooltips

2. **Pipe Transport**:
   - Crude oil flows from oil well to refinery
   - Pipes show fluid type (crude oil) and fill levels
   - Network visualization shows connected network

3. **Oil Refinery Processing**:
   - Consumes crude oil fluid input
   - Produces petroleum gas, light oil, heavy oil outputs
   - Recipe selection works through UI
   - Fluid tanks show processing progress

4. **Chemical Plant Processing**:
   - Receives petroleum gas, light/heavy oil from refinery
   - Processes fluids in recipes (plastic bar, lubricant, etc.)
   - Shows fluid inputs/outputs in machine UI
   - Produces final products

#### Verification Points:
- [ ] Oil well produces crude oil at correct rate
- [ ] Pipes transport fluid without leaks
- [ ] Refinery processes crude oil into multiple products
- [ ] Chemical plant accepts fluid inputs
- [ ] Complete chain produces final items
- [ ] Network debugging shows proper connectivity

### Scenario 2: Steam Power Chain
**Goal**: Verify boiler → steam engine power generation

#### Setup:
1. Place boiler
2. Place water pump (or use water from other source)
3. Place pipes connecting water to boiler
4. Place pipes connecting boiler steam output to steam engine
5. Place steam engine
6. Ensure electrical connections for pump/engine

#### Expected Behavior:
1. **Water Supply**:
   - Water pump produces water fluid
   - Pipes transport water to boiler

2. **Boiler Operation**:
   - Consumes fuel (coal/wood) and water
   - Produces steam when both inputs available
   - Shows steam production in fluid indicators

3. **Steam Transport**:
   - Steam flows through pipes to steam engine
   - Pipes handle steam fluid type correctly
   - Pressure builds appropriately

4. **Steam Engine Operation**:
   - Consumes steam fluid
   - Produces electrical power
   - Shows steam consumption in UI
   - Power output matches steam input

#### Verification Points:
- [ ] Water pump provides water to boiler
- [ ] Boiler requires both fuel and water
- [ ] Steam production matches expected rates
- [ ] Steam transport through pipes works
- [ ] Steam engine consumes steam and produces power
- [ ] Power output proportional to steam consumption

### Scenario 3: Fluid Network Merging/Splitting
**Goal**: Test dynamic network behavior

#### Setup:
1. Create separate oil and steam networks
2. Place connecting pipes to merge networks
3. Remove pipes to split networks
4. Monitor network IDs and fluid flow

#### Expected Behavior:
1. **Network Merging**:
   - Separate networks have different IDs
   - Connecting pipe merges networks
   - Single network ID after merge
   - Fluid flows across merged network

2. **Network Splitting**:
   - Removing pipe splits network
   - Creates separate networks with new IDs
   - Fluid flow contained within split networks

#### Verification Points:
- [ ] Networks merge when pipes connect
- [ ] Networks split when pipes disconnect
- [ ] Network IDs update correctly
- [ ] Fluid flow respects network boundaries
- [ ] Debug visualization shows network changes

### Scenario 4: Complex Multi-Product Chain
**Goal**: Test refinery producing multiple products simultaneously

#### Setup:
1. Oil well → Refinery (producing all 3 outputs)
2. Separate pipe networks for each product
3. Chemical plants processing different refinery outputs
4. Plastic production from petroleum gas
5. Lubricant from heavy oil

#### Expected Behavior:
1. **Multi-Output Processing**:
   - Refinery handles all output types
   - Separate fluid streams for each product
   - No cross-contamination between fluids

2. **Parallel Processing**:
   - Multiple chemical plants work simultaneously
   - Each uses different refinery products
   - Independent fluid networks

#### Verification Points:
- [ ] Refinery produces all 3 fluid outputs
- [ ] Separate pipes maintain fluid separation
- [ ] Chemical plants process correct fluids
- [ ] Multiple production chains work in parallel

## Performance Testing

### Scenario 5: Large Network Stress Test
**Goal**: Verify performance with complex networks

#### Setup:
1. Create large pipe network (50+ pipes)
2. Multiple production/consumption points
3. Complex network topology with loops

#### Expected Behavior:
1. **Performance**:
   - No significant frame rate drops
   - Fluid calculations complete within frame time
   - Network updates don't cause lag

2. **Stability**:
   - No fluid leaks or infinite loops
   - Network merging/splitting works correctly
   - Debug visualization remains responsive

#### Verification Points:
- [ ] 60 FPS maintained with large networks
- [ ] No memory leaks during network changes
- [ ] Fluid calculations complete in <16ms
- [ ] Debug mode doesn't impact performance significantly

## Fluid Properties Testing

### Scenario 6: Fluid Type Interactions
**Goal**: Verify different fluid types behave correctly

#### Setup:
1. Multiple fluid types in same area
2. Different fluid properties (viscosity, etc.)
3. Mixing prevention verification

#### Expected Behavior:
1. **Type Safety**:
   - Fluids don't mix in pipes
   - Wrong fluid types rejected by consumers
   - Type-specific coloring in debug mode

2. **Property Effects**:
   - High-viscosity fluids flow slower
   - Temperature affects some fluid behaviors

#### Verification Points:
- [ ] Fluid types remain separate in pipes
- [ ] Consumers only accept correct fluid types
- [ ] Visual indicators show correct fluid colors
- [ ] Flow rates affected by viscosity

## Debug Tools Testing

### Scenario 7: Debug Visualization Verification
**Goal**: Test all debug visualization features

#### Setup:
1. Enable fluid debug mode
2. Create various network scenarios
3. Verify all debug features work

#### Expected Behavior:
1. **Network Boundaries**:
   - Color-coded network overlays
   - Correct grouping of connected pipes

2. **Pressure Maps**:
   - Color-coded pressure indicators
   - Accurate pressure calculations

3. **Flow Indicators**:
   - Directional flow arrows
   - Magnitude indicators

#### Verification Points:
- [ ] Debug button toggles visualization
- [ ] Network boundaries show correctly
- [ ] Pressure colors match fluid levels
- [ ] Flow indicators show direction/magnitude
- [ ] Performance acceptable with debug enabled

## Edge Cases Testing

### Scenario 8: Error Conditions
**Goal**: Test system robustness

#### Setup:
1. Disconnect fluid supplies
2. Overfill pipe networks
3. Invalid fluid type connections

#### Expected Behavior:
1. **Graceful Degradation**:
   - Producers stop when output blocked
   - Consumers stop when input unavailable
   - No crashes or infinite loops

2. **Recovery**:
   - System recovers when connections restored
   - Fluid levels stabilize after changes

#### Verification Points:
- [ ] No crashes with disconnected networks
- [ ] Producers handle output blocking
- [ ] Consumers handle input starvation
- [ ] System recovers from edge cases

## Test Results Summary

### Passed Tests: [ ]
### Failed Tests: [ ]
### Issues Found: [ ]
### Performance Metrics: [ ]
### Recommendations: [ ]

## Conclusion
This testing plan ensures the fluid system works correctly across all scenarios and edge cases. The focus is on verifying the complete production chains that represent the core gameplay value of fluid mechanics.