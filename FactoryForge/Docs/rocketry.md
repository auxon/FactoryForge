# Rocketry Guide

This guide explains how the rocket system works in FactoryForge, from basic components to launching rockets into space.

## Overview

The rocket system allows players to construct and launch rockets containing satellites to generate space science packs. This is the end-game goal of FactoryForge, requiring advanced technology and massive resource production.

## Rocket Components

### Rocket Parts

Rocket parts are the structural components of rockets. Each rocket requires **100 rocket parts**.

**Recipe:**
- 10 Steel Plates
- 10 Low Density Structures
- 10 Rocket Fuel
- 10 Electronic Circuits
- Craft time: 3 seconds

### Rocket Fuel

Rocket fuel powers the rocket's ascent. Each rocket requires **50 rocket fuel**.

**Recipe:**
- 10 Solid Fuel
- Craft time: 30 seconds

### Satellite

The satellite is the payload that enables space science generation. Each rocket requires **1 satellite**.

**Recipe:**
- 100 Low Density Structures
- 100 Solar Panels
- 100 Accumulators
- 5 Radars
- 100 Processing Units
- 50 Rocket Fuel
- Craft time: 5 seconds

## Research Requirements

To unlock rocketry, you must research these technologies in order:

### 1. Rocket Fuel (Tier 3)
**Prerequisites:** Advanced Oil Processing
**Cost:** 200 Automation, 200 Logistic, 200 Chemical science packs
**Unlocks:** Solid Fuel, Rocket Fuel recipes

### 2. Low Density Structure (Tier 3)
**Prerequisites:** Rocket Fuel
**Cost:** 200 Automation, 200 Logistic, 200 Chemical science packs
**Unlocks:** Low Density Structure recipe

### 3. Rocket Parts (Tier 3)
**Prerequisites:** Low Density Structure
**Cost:** 300 Automation, 300 Logistic, 300 Chemical science packs
**Unlocks:** Rocket Part recipe

### 4. Satellite (Tier 3)
**Prerequisites:** Rocket Parts, Solar Energy
**Cost:** 400 Automation, 400 Logistic, 400 Chemical science packs
**Unlocks:** Satellite recipe

### 5. Rocket Silo (Tier 3)
**Prerequisites:** Satellite
**Cost:** 500 Automation, 500 Logistic, 500 Chemical science packs
**Unlocks:** Rocket Silo construction

## Rocket Silo Construction

Rocket silos are massive structures that assemble and launch rockets. They have a large inventory (typically 8+ slots) for storing rocket components.

**Recipe:**
- 1000 Steel Plates
- 1000 Concrete
- 1000 Pipes
- 1000 Processing Units
- Craft time: 30 seconds

## Rocket Assembly

### Component Requirements

To assemble a rocket, the rocket silo needs:
- **100 Rocket Parts**
- **50 Rocket Fuel**
- **1 Satellite**

### Assembly Process

1. **Load Components**: Place the required rocket parts, fuel, and satellite into the rocket silo's inventory
2. **Automatic Assembly**: Once all components are present, the rocket assembles automatically
3. **Visual Feedback**: The silo shows assembly progress in its machine UI

### Machine UI

When viewing a rocket silo in the machine UI:
- Shows the rocket assembly status
- Displays a "🚀 LAUNCH ROCKET" button when ready
- Shows "⚠️ ASSEMBLE ROCKET" when components are missing
- Shows "⏳ LAUNCHING..." during launch countdown

## Rocket Launch

### Launch Initiation

1. **Open Silo UI**: Click on the rocket silo to open its machine interface
2. **Check Status**: Ensure the rocket is assembled (all components present)
3. **Launch Button**: Click the "🚀 LAUNCH ROCKET" button
4. **Launch Sequence**: A 10-second launch countdown begins

### Launch Sequence

During the 10-second launch:
- The silo shows launch progress (0-100%)
- Visual and audio effects indicate the launch buildup
- The rocket cannot be interrupted once started

### Launch Completion

When the countdown reaches 10 seconds:
- The rocket consumes the components from the silo inventory
- A flying rocket entity is created and begins ascent
- The silo becomes ready for another rocket assembly

## Rocket Flight

### Physics Simulation

Launched rockets follow realistic physics:
- **Acceleration**: 50 units/second² upward acceleration
- **Max Altitude**: 1000 units above the silo
- **Flight Time**: Approximately 20-30 seconds depending on acceleration curve

### Visual Effects

- Rockets appear as flying entities moving upward from the silo
- Position updates show the rocket climbing into the sky
- Flight progress tracks from 0% to 100%

## Space Science Generation

### Mission Success

When a rocket reaches maximum altitude:
- The mission is considered successful
- The rocket entity is removed from the game world
- Space science packs are generated

### Science Pack Rewards

Each successful rocket launch generates:
- **1000 Space Science Packs**
- Deposited directly into a nearby rocket silo's inventory
- Can be collected and used for advanced research

### Collection

Space science packs are automatically added to rocket silo inventories. Players must:
1. Visit the rocket silo
2. Open its inventory
3. Collect the space science packs
4. Transport them to labs for research

## Strategic Considerations

### Resource Requirements

Launching a single rocket requires:
- **Massive Steel Production**: 1000+ steel plates for silo + 100 for rocket parts
- **Advanced Electronics**: Processing units, circuits for satellite
- **Energy Infrastructure**: Solar panels, accumulators for satellite
- **Fuel Production**: Solid fuel → Rocket fuel production chain

### Production Scaling

For continuous rocket launches:
- **Parallel Silos**: Build multiple rocket silos for simultaneous launches
- **Supply Chains**: Dedicated production lines for each component
- **Logistics**: Efficient transport between production facilities and silos

### Research Investment

Space science enables:
- **Tier 4 Technologies**: Most advanced research options
- **End-Game Content**: Ultimate factory automation and optimization
- **Infinite Progression**: Continuous science pack generation

## Troubleshooting

### Rocket Won't Assemble
- **Missing Components**: Ensure all 100 rocket parts, 50 rocket fuel, and 1 satellite are in silo inventory
- **Wrong Items**: Check that items are placed in the correct inventory slots
- **Research**: Verify all required technologies are researched

### Launch Button Disabled
- **Not Assembled**: Rocket must be fully assembled before launch
- **Already Launching**: Wait for current launch to complete
- **UI Glitch**: Close and reopen the machine UI

### No Science Packs Generated
- **Flight Incomplete**: Rocket must reach maximum altitude for success
- **No Nearby Silo**: System deposits packs in nearest rocket silo
- **Inventory Full**: Ensure silo has space for 1000 science packs

## Advanced Strategies

### Mega-Base Design
- **Centralized Production**: Massive factories producing rocket components
- **Automated Transport**: Belts/rails connecting production to silos
- **Buffer Storage**: Large warehouses for component stockpiling

### Research Optimization
- **Parallel Labs**: Multiple labs processing space science packs simultaneously
- **Science Pack Logistics**: Efficient transport from silos to research facilities
- **Technology Prioritization**: Focus research on productivity and speed modules

### Infinite Production
Once space science is unlocked, players can achieve:
- **Self-Sustaining Research**: Space science enables more advanced automation
- **Factory Optimization**: Endless improvement of production efficiency
- **Creative Mode**: Build increasingly complex and efficient factories

The rocket system represents the culmination of FactoryForge's progression, requiring mastery of all production systems to achieve space exploration and unlimited technological advancement.