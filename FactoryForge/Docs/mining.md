# Mining Guide

This guide explains how resource extraction works in FactoryForge, covering mining drills, resource deposits, and tree harvesting.

## Overview

Mining is the foundation of FactoryForge's economy, providing raw materials for all production chains. The game features two types of mining drills and multiple resource types, each with different extraction mechanics.

## Mining Drills

### Burner Mining Drill

**Basic mining drill that runs on fuel**

**Recipe:**
- 3 Iron Gear Wheels
- 3 Iron Plates
- 1 Stone Furnace
- Craft time: 2 seconds

**Characteristics:**
- **Size:** 2x2 tiles
- **Mining Speed:** 0.5 items/second
- **Power:** Fuel-based (coal, wood, solid fuel)
- **Pollution:** 10 pollution/second
- **Resources:** Mines ore deposits and harvests trees
- **Cost:** Cheap and available from start

### Electric Mining Drill

**Advanced mining drill with higher efficiency**

**Recipe:**
- 3 Electronic Circuits
- 5 Iron Gear Wheels
- 10 Iron Plates
- Craft time: 2 seconds

**Characteristics:**
- **Size:** 3x3 tiles
- **Mining Speed:** 0.75 items/second (50% faster than burner)
- **Power:** 90 kW electricity
- **Pollution:** None
- **Resources:** Mines ore deposits only (cannot harvest trees)
- **Cost:** Requires electronics research

## Resource Types

### Ore Deposits

FactoryForge features several types of mineral resources:

#### Iron Ore
- **Color:** Steel blue
- **Tile Type:** Iron ore deposits
- **Output:** Iron ore
- **Uses:** Iron plates, gear wheels, steel production

#### Copper Ore
- **Color:** Orange-brown
- **Tile Type:** Copper ore deposits
- **Output:** Copper ore
- **Uses:** Copper plates, electronic circuits, batteries

#### Coal
- **Color:** Black
- **Tile Type:** Coal deposits
- **Output:** Coal
- **Uses:** Fuel, plastic production, chemical processes

#### Stone
- **Color:** Gray-brown
- **Tile Type:** Stone deposits
- **Output:** Stone
- **Uses:** Bricks, furnaces, concrete

#### Uranium Ore
- **Color:** Bright green
- **Tile Type:** Stone deposits (with green tint)
- **Output:** Uranium ore
- **Uses:** Nuclear fuel, Kovarex enrichment

### Oil

**Special fluid resource extracted by oil wells (pumpjacks)**
- **Color:** Dark brown/black patches
- **Tile Type:** Oil deposits
- **Output:** Crude oil (fluid)
- **Extraction:** Requires oil wells, not mining drills
- **Uses:** Petroleum products, rocket fuel, plastic

### Trees

**Renewable wood source**
- **Color:** Brown tree sprites
- **Output:** Wood
- **Harvesting:** Only by burner mining drills
- **Regeneration:** Trees don't regrow in FactoryForge
- **Yield:** 4 wood per tree (depletes over time)
- **Uses:** Fuel, paper, wooden chests

## Mining Mechanics

### Resource Deposits

#### Deposit Distribution
- **Generation:** Randomly placed during world generation
- **Density:** Varies by resource type (coal most common, uranium rarest)
- **Size:** Deposits range from small patches to large clusters
- **Exhaustion:** Deposits are infinite (Factorio-style) - don't deplete

#### Mining Range
- **Burner Drills:** Mine 3x3 area around drill
- **Electric Drills:** Mine 5x5 area around drill
- **Resource Detection:** Drills automatically find resources in their range
- **Multi-Resource:** Can mine different ores in the same area

### Extraction Process

#### Mining Speed
Mining time depends on:
1. **Drill Type:** Burner (0.5/s) vs Electric (0.75/s)
2. **Resource Richness:** Deposit quality multiplier
3. **Power Satisfaction:** Electric drills slow down with insufficient power

**Formula:** `Mining Time = 1 / (Mining Speed × Richness × Power Multiplier)`

#### Progress Tracking
- **Visual Feedback:** Drills show mining progress (0-100%)
- **Completion:** Resource extracted when progress reaches 100%
- **Continuous Operation:** Drills mine repeatedly until inventory full or no power

#### Inventory Management
- **Output Slot:** Single slot holds extracted resources
- **Capacity:** Limited by item stack sizes
- **Blockage:** Drills stop when output inventory is full
- **Automation:** Use inserters to empty drill inventories automatically

### Power Requirements

#### Electric Mining Drills
- **Consumption:** 90 kW per drill
- **Scaling:** Large mining operations require significant power infrastructure
- **Efficiency:** Reduced speed when power is insufficient
- **Backup:** No fuel backup - completely dependent on electricity

#### Burner Mining Drills
- **Fuel Types:** Coal, wood, solid fuel, rocket fuel
- **Consumption:** Variable based on fuel energy density
- **Independence:** Can operate without electricity
- **Pollution:** Generate pollution while operating

## Tree Harvesting

### Burner-Only Feature
- **Exclusive:** Only burner mining drills can harvest trees
- **Range:** 2x2 area around drill (smaller than ore mining range)
- **Process:** Same mining mechanics as ore extraction

### Tree Mechanics
- **Health System:** Trees have health that decreases with each mining operation
- **Wood Yield:** Each tree contains 4 wood initially
- **Progressive Harvesting:** Each mining operation yields 1 wood
- **Depletion:** Trees die when health reaches 0 or wood runs out
- **Removal:** Depleted trees are automatically removed from the world

### Strategic Considerations
- **Renewable Planning:** Trees don't regrow - harvest sustainably
- **Early Game:** Primary wood source before advanced fuel production
- **Fuel Source:** Wood can be burned directly in furnaces or converted to charcoal

## Placement Strategy

### Resource Analysis
- **Survey Area:** Identify high-density resource clusters
- **Mixed Deposits:** Place drills to mine multiple ore types efficiently
- **Expansion Planning:** Leave space for future drill placement

### Drill Configuration
- **Coverage:** Overlap drill ranges to maximize resource access
- **Bottleneck Avoidance:** Ensure inserters can reach all drills
- **Power Distribution:** Plan electrical grid for electric drills

### Logistics Integration
- **Inserter Networks:** Automate resource collection from drills
- **Belt Systems:** Transport ores to processing facilities
- **Storage Solutions:** Buffer chests for production smoothing

## Advanced Mining

### Mega-Mining Operations
- **Scale:** Hundreds of drills in large resource fields
- **Automation:** Robotic networks for maintenance and expansion
- **Efficiency:** Optimize drill placement for maximum throughput

### Mixed Mining
- **Multi-Resource Fields:** Single operation mines multiple ore types
- **Product Separation:** Use filters and splitters for ore sorting
- **Integrated Processing:** Smelters placed near mining fields

### Power Infrastructure
- **Grid Design:** Steam engines or solar fields for electric drills
- **Backup Systems:** Maintain fuel supplies for burner drills
- **Load Balancing:** Distribute power evenly across mining operations

## Optimization Tips

### Performance Tuning
- **Cache System:** Mining system uses spatial caching for performance
- **Range Optimization:** Drills search in optimized patterns
- **Update Frequency:** Resource detection updates every 0.5 seconds

### Resource Management
- **Inventory Monitoring:** Regularly empty drill inventories
- **Inserter Balancing:** Match inserter capacity to drill output
- **Buffer Systems:** Use chests to prevent production bottlenecks

### Expansion Planning
- **Scouting:** Explore for new resource deposits
- **Infrastructure Scaling:** Plan power and logistics for growth
- **Technology Integration:** Upgrade to electric drills when available

## Troubleshooting

### Common Issues

#### Drills Not Mining
- **No Resources:** Check if drill is placed on valid resource tiles
- **Power Problems:** Electric drills need 90 kW electricity
- **Fuel Depleted:** Burner drills need fuel in their furnaces
- **Inventory Full:** Clear output slot or add inserters

#### Slow Mining Speed
- **Power Shortage:** Electric drills reduce speed with insufficient power
- **Low Richness:** Some deposits have lower mining multipliers
- **Range Issues:** Resources might be just outside drill range

#### Tree Harvesting Problems
- **Electric Drills:** Cannot harvest trees - use burner drills only
- **Tree Depleted:** Trees with 0 wood are removed automatically
- **Range:** Trees must be within 2x2 area of burner drill

### Performance Issues
- **Large Operations:** Hundreds of drills can impact performance
- **Cache Updates:** Mining system caches resource locations
- **Chunk Loading:** Mining works across loaded world chunks

### Resource Scarcity
- **Exploration:** Venture further for new deposits
- **Alternative Sources:** Some resources can be created synthetically
- **Import Strategies:** Use trading or other acquisition methods

## End-Game Integration

Mining forms the backbone of FactoryForge's economy:

- **Raw Materials:** All production starts with mined resources
- **Scaling Challenge:** Mining operations grow from manual to mega-factories
- **Technology Driver:** Advanced mining enables complex manufacturing chains
- **Sustainability:** Balance extraction with production capacity

Mastering mining techniques transforms scattered drills into efficient, automated resource extraction networks that fuel your industrial empire.