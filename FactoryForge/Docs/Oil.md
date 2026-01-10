# Oil Processing Guide

This guide explains how to discover, extract, and process oil in FactoryForge, from basic refining to advanced chemical production.

## Oil Discovery

### World Generation
Oil deposits appear as dark patches on the world map. They are less common than other resources:
- **Spawn Rate**: 0.2 (compared to coal at 0.6, copper at 0.8)
- **Appearance**: Dark brown/black patches on terrain
- **Accessibility**: Can only be mined by oil wells (pumpjacks)

### Research Requirements
To unlock oil processing, research these technologies in order:

#### 1. Oil Processing (Tier 3)
**Prerequisites:** Advanced Electronics
**Cost:** 50 Automation, 50 Logistic, 50 Chemical science packs
**Unlocks:** Oil Well, Water Pump, Basic Oil Processing recipes

#### 2. Advanced Oil Processing (Tier 3)
**Prerequisites:** Oil Processing
**Cost:** 50 Automation, 50 Logistic, 50 Chemical science packs
**Unlocks:** Oil Refinery, Advanced Oil Processing recipes

#### 3. Chemistry (Tier 3)
**Prerequisites:** Advanced Oil Processing
**Cost:** 100 Automation, 100 Logistic, 100 Chemical science packs
**Unlocks:** Chemical Plant, Plastic Bar, Sulfur, Chemical Science Pack recipes

#### 4. Sulfur Processing (Tier 3)
**Prerequisites:** Chemistry
**Cost:** 100 Automation, 100 Logistic, 100 Chemical science packs
**Unlocks:** Sulfuric Acid recipe

#### 5. Oil Cracking (Tier 3)
**Prerequisites:** Chemistry
**Cost:** 100 Automation, 100 Logistic, 100 Chemical science packs
**Unlocks:** Light Oil Cracking, Heavy Oil Cracking recipes

## Oil Well Construction

### Building Requirements
**Recipe:**
- 5 Steel Plates
- 10 Iron Gear Wheels
- 5 Electronic Circuits
- 10 Pipes
- Craft time: 10 seconds

### Placement Rules
- **Must be placed directly on oil deposits** (dark patches)
- Cannot be placed on regular terrain
- **Power Requirements**: 90 kW (significant power draw)
- **Output**: 1 crude oil per second at full power

### Operation
- **Extraction Rate**: 1 crude oil/second when fully powered
- **Storage**: Single output slot (stacks up to 100 crude oil)
- **Power Dependency**: Stops producing when power is insufficient
- **Infinite Deposits**: Oil deposits don't deplete

## Oil Refining

### Oil Refinery Construction
**Recipe:**
- 15 Steel Plates
- 10 Iron Gear Wheels
- 10 Electronic Circuits
- 10 Pipes
- 10 Stone Bricks
- Craft time: 20 seconds

### Basic Oil Processing
**Recipe:** Basic Oil Processing
- **Input:** 100 Crude Oil
- **Outputs:**
  - 45 Petroleum Gas
  - 30 Light Oil
  - 25 Heavy Oil
- **Craft Time:** 5 seconds
- **Power:** 420 kW

### Advanced Oil Processing
**Recipe:** Advanced Oil Processing
- **Inputs:**
  - 100 Crude Oil
  - 50 Water
- **Outputs:**
  - 55 Petroleum Gas
  - 45 Light Oil
  - 25 Heavy Oil
- **Craft Time:** 5 seconds
- **Power:** 420 kW

### Comparison
| Method | Petroleum Gas | Light Oil | Heavy Oil | Water Used |
|--------|---------------|-----------|-----------|------------|
| Basic | 45 | 30 | 25 | 0 |
| Advanced | 55 | 45 | 25 | 50 |

**Advanced processing yields more valuable products but requires water input.**

## Oil Cracking

Oil cracking converts heavy oil into light oil and light oil into petroleum gas for better yields.

### Light Oil Cracking
**Recipe:** Light Oil Cracking
- **Inputs:**
  - 30 Light Oil
  - 30 Water
- **Output:** 20 Petroleum Gas
- **Craft Time:** 5 seconds
- **Category:** Chemistry (requires Chemical Plant)

### Heavy Oil Cracking
**Recipe:** Heavy Oil Cracking
- **Inputs:**
  - 40 Heavy Oil
  - 30 Water
- **Output:** 30 Light Oil
- **Craft Time:** 5 seconds
- **Category:** Chemistry (requires Chemical Plant)

### Strategic Use
- **Heavy Oil Cracking**: Converts unwanted heavy oil into usable light oil
- **Light Oil Cracking**: Maximizes petroleum gas production when gas is in high demand
- **Water Consumption**: Both processes require significant water input

## Chemical Products

Chemical plants process oil products into advanced materials.

### Plastic Bar
**Recipe:** Plastic Bar
- **Inputs:**
  - 20 Petroleum Gas
  - 1 Coal
- **Output:** 2 Plastic Bars
- **Craft Time:** 1 second
- **Uses:** Advanced circuits, low density structures, rocket parts

### Sulfur
**Recipe:** Sulfur
- **Inputs:**
  - 30 Petroleum Gas
  - 30 Water
- **Output:** 2 Sulfur
- **Craft Time:** 1 second
- **Uses:** Chemical science packs, sulfuric acid, explosives

### Sulfuric Acid
**Recipe:** Sulfuric Acid
- **Inputs:**
  - 5 Sulfur
  - 1 Iron Plate
  - 100 Water
- **Output:** 50 Sulfuric Acid
- **Craft Time:** 1 second
- **Uses:** Battery production, processing units

### Solid Fuel
**Recipe:** Solid Fuel
- **Inputs:**
  - 1 Coal
  - 20 Petroleum Gas
- **Output:** 1 Solid Fuel
- **Craft Time:** 2 seconds
- **Uses:** Fuel for boilers, rocket fuel production

## Chemical Science Packs

**Recipe:** Chemical Science Pack
- **Inputs:**
  - 1 Engine Unit
  - 1 Advanced Circuit
  - 3 Sulfur
  - 30 Petroleum Gas
- **Output:** 1 Chemical Science Pack
- **Craft Time:** 24 seconds
- **Research Value:** Unlocks Tier 3 technologies

## Strategic Considerations

### Production Scaling

#### Oil Field Development
- **Multiple Wells**: Place multiple oil wells on large deposits
- **Power Infrastructure**: Oil wells require significant electricity (90 kW each)
- **Storage Solutions**: Use storage tanks or transport oil efficiently

#### Refining Capacity
- **Parallel Refineries**: Build multiple refineries for high-volume processing
- **Recipe Selection**: Use advanced processing for maximum yield
- **Water Supply**: Ensure adequate water for advanced processing and cracking

#### Chemical Production
- **Specialized Plants**: Dedicate chemical plants to specific products
- **Resource Balancing**: Balance petroleum gas between plastic, sulfur, and fuel production
- **Byproduct Management**: Use cracking to convert unwanted oil fractions

### Resource Optimization

#### Basic Oil Setup
```
Oil Well → Oil Refinery (Basic) → Petroleum Gas/Light Oil/Heavy Oil
```

#### Advanced Oil Setup
```
Oil Well → Oil Refinery (Advanced) → Enhanced yields + water consumption
Heavy Oil → Chemical Plant (Cracking) → Light Oil
Light Oil → Chemical Plant (Cracking) → Petroleum Gas
```

#### Full Chemical Chain
```
Crude Oil → Refining → Oil Products → Chemical Plant → Plastic/Sulfur/Fuel
Petroleum Gas + Coal → Chemical Plant → Plastic Bars
Petroleum Gas + Water → Chemical Plant → Sulfur
Coal + Petroleum Gas → Chemical Plant → Solid Fuel
```

### Power Considerations
- **Oil Wells**: 90 kW each
- **Oil Refineries**: 420 kW each
- **Chemical Plants**: 210 kW each
- **Total Load**: High electricity demand for oil infrastructure

### Logistics
- **Fluid Transport**: Oil products are fluids (can't use inserters)
- **Pipe Networks**: Extensive pipe systems for oil distribution
- **Storage**: Fluid storage requirements for buffering

## Advanced Strategies

### Mega-Base Oil Processing
- **Centralized Refining**: Large refinery complexes processing thousands of crude oil/second
- **Product Distribution**: Separate pipe networks for each oil product
- **Chemical Hubs**: Dedicated areas for plastic, sulfur, and fuel production

### Optimization Techniques
- **Yield Maximization**: Use advanced processing + cracking for optimal ratios
- **Byproduct Recycling**: Convert all oil fractions into desired products
- **Demand Matching**: Scale production to match research and construction needs

### Research Investment
Chemical science packs enable:
- **Advanced Electronics**: Processing units, advanced circuits
- **Rocket Technology**: Low density structures, rocket fuel
- **Military Technology**: Explosives, advanced turrets

## Troubleshooting

### Oil Well Issues
- **No Production**: Check if placed on oil deposit (dark patches)
- **Power Problems**: Ensure 90 kW power supply
- **Full Inventory**: Empty output slot or provide storage

### Refinery Problems
- **No Output**: Verify power (420 kW) and input crude oil
- **Wrong Recipe**: Select correct processing recipe in machine UI
- **Output Blockage**: Ensure space for all output fluids

### Chemical Plant Issues
- **Wrong Category**: Use Chemistry category for oil cracking recipes
- **Water Supply**: Ensure adequate water for cracking processes
- **Product Backlog**: Clear output inventories to prevent jams

### Common Mistakes
- **Missing Research**: Unlock all required technologies before building
- **Power Shortage**: Oil infrastructure has high power demands
- **Pipe Management**: Complex pipe networks can cause bottlenecks
- **Storage Limits**: Fluids don't stack, requiring careful storage planning

## End-Game Integration

Oil processing enables:
- **Advanced Manufacturing**: Plastic components for complex machinery
- **Energy Systems**: Solid fuel for boilers, rocket fuel for propulsion
- **Research Acceleration**: Chemical science packs for rapid technological progress
- **Rocket Program**: Essential components for space exploration

Mastering oil processing transforms FactoryForge from basic automation to advanced industrial production, unlocking the game's most sophisticated technologies and largest-scale operations.