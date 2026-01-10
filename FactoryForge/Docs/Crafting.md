# Crafting Guide

This guide explains how crafting works in FactoryForge, covering both manual player crafting and automated machine production.

## Overview

Crafting is the process of converting raw materials into useful items and components. FactoryForge features two distinct crafting systems:

- **Player Crafting**: Manual crafting using the player's inventory
- **Machine Crafting**: Automated production using assembling machines and furnaces

## Player Crafting

### Accessing the Crafting Menu

1. **Open Crafting Menu**: Press the crafting button (hammer icon) or use the menu
2. **Recipe Grid**: View all unlocked recipes in a scrollable grid
3. **Recipe Selection**: Tap any recipe to craft it
4. **Requirements Check**: System verifies you have required materials

### Crafting Mechanics

#### Queue System
- **Instant Crafting**: Recipes are queued and crafted over time
- **Progress Tracking**: See crafting progress (0-100%)
- **Multiple Queues**: Craft multiple recipes simultaneously
- **Completion**: Items added to inventory automatically

#### Speed and Efficiency
- **Base Speed**: Player crafts at 1x speed
- **No Power Required**: Works anywhere, anytime
- **Limited Parallelism**: Can only craft one item at a time
- **No Upgrades**: Player crafting speed cannot be improved

### Recipe Categories

Player can craft recipes from these categories:
- **Crafting**: Basic components (gears, circuits, plates)
- **Smelting**: Metal processing (requires furnaces for automation)
- **Chemistry**: Advanced materials (plastic, sulfur, explosives)

## Machine Crafting

### Assembling Machines

FactoryForge features three tiers of assembling machines for automated production.

#### Assembling Machine 1
**Basic automated crafter**
- **Recipe**: 3 Electronic Circuits, 5 Iron Gear Wheels, 10 Iron Plates
- **Crafting Speed**: 0.5x (50% of optimal)
- **Power**: 75 kW electricity
- **Categories**: Basic crafting only
- **Size**: 3x3 tiles

#### Assembling Machine 2
**Intermediate automated crafter**
- **Recipe**: 2 Assembling Machine 1, 3 Electronic Circuits, 5 Iron Gear Wheels, 9 Iron Plates
- **Crafting Speed**: 0.75x (75% of optimal)
- **Power**: 150 kW electricity
- **Categories**: Basic and advanced crafting
- **Size**: 3x3 tiles

#### Assembling Machine 3
**Advanced automated crafter**
- **Recipe**: 2 Assembling Machine 2, 3 Speed Modules, 9 Electronic Circuits, 5 Iron Gear Wheels, 19 Iron Plates
- **Crafting Speed**: 1.25x (125% of optimal)
- **Power**: 375 kW electricity
- **Categories**: All crafting types
- **Size**: 3x3 tiles

### Furnace System

#### Stone Furnace
**Basic smelting furnace**
- **Recipe**: 5 Stone
- **Smelting Speed**: 1x (base speed)
- **Fuel**: Coal, wood, solid fuel
- **Power**: Manual fuel consumption
- **Pollution**: 10 pollution/second

#### Steel Furnace
**Improved smelting furnace**
- **Recipe**: 6 Steel Plates, 10 Stone Bricks, 5 Stone
- **Smelting Speed**: 2x (doubles base speed)
- **Fuel**: All fuel types
- **Power**: Manual fuel consumption
- **Pollution**: 15 pollution/second

#### Electric Furnace
**High-efficiency smelting furnace**
- **Recipe**: 10 Advanced Circuits, 10 Steel Plates, 20 Stone Bricks, 5 Stone
- **Smelting Speed**: 2x (doubles base speed)
- **Fuel**: Electricity only
- **Power**: 180 kW electricity
- **Pollution**: None

### Machine Operation

#### Loading Recipes
1. **Open Machine UI**: Click on any assembling machine or furnace
2. **Recipe Selection**: Choose from available recipes for that machine type
3. **Input Loading**: Insert required materials into input slots
4. **Automatic Production**: Machine crafts continuously when materials are available

#### Production Mechanics
- **Continuous Operation**: Machines run 24/7 when powered and supplied
- **Input Buffering**: Multiple input slots for different materials
- **Output Collection**: Products accumulate in output slots
- **Inserter Automation**: Use inserters to keep machines fed

## Research Requirements

### Automation Research Tree

#### Automation (Tier 1)
**Prerequisites:** None
**Cost:** 10 Automation science packs
**Unlocks:** Assembling Machine 1, basic automation recipes

#### Automation 2 (Tier 2)
**Prerequisites:** Automation, Logistic science packs
**Cost:** 40 Automation science packs
**Unlocks:** Assembling Machine 2, intermediate recipes

#### Automation 3 (Tier 3)
**Prerequisites:** Automation 2, Advanced electronics
**Cost:** 100 Automation science packs
**Unlocks:** Assembling Machine 3, advanced recipes

### Furnace Research

#### Advanced Material Processing (Tier 2)
**Prerequisites:** Steel processing
**Cost:** 50 Automation science packs
**Unlocks:** Steel Furnace

#### Advanced Electronics (Tier 3)
**Prerequisites:** Plastics, Sulphur processing
**Cost:** 75 Automation, 75 Logistic, 75 Chemical science packs
**Unlocks:** Electric Furnace, advanced circuits

## Recipe System

### Recipe Categories

#### Crafting
**Basic component assembly**
- **Machines**: Assembling Machine 1, 2, 3
- **Examples**: Gears, circuits, inserters, transport belts
- **Complexity**: Simple to complex components

#### Advanced Crafting
**Complex component assembly**
- **Machines**: Assembling Machine 2, 3 only
- **Examples**: Processing units, rocket parts, advanced machinery
- **Requirements**: Higher-tier machines needed

#### Smelting
**Material transformation**
- **Machines**: All furnace types
- **Examples**: Iron ore → Iron plates, Copper ore → Copper plates
- **Fuel**: Coal/wood for manual furnaces, electricity for electric furnaces

#### Chemistry
**Chemical processing**
- **Machines**: Chemical Plant
- **Examples**: Plastic, sulfur, sulfuric acid, explosives
- **Requirements**: Oil processing technology

### Recipe Mechanics

#### Input/Output System
- **Fixed Ratios**: Each recipe has specific input → output ratios
- **Craft Time**: Time required per crafting cycle
- **Stack Efficiency**: Higher stack sizes improve throughput

#### Production Rate
```
Items per second = (Items per craft × Crafting speed) / Craft time
```

**Example**: Electronic circuit (craft time: 0.5s, output: 1 circuit, speed: 0.75x)
```
Rate = (1 × 0.75) / 0.5 = 1.5 circuits/second
```

## Production Optimization

### Machine Selection

#### Early Game (Tier 1)
- **Player Crafting**: For small quantities and research
- **Assembling Machine 1**: For basic automation
- **Stone Furnaces**: For essential smelting

#### Mid Game (Tier 2)
- **Assembling Machine 2**: For most production
- **Steel Furnaces**: For increased smelting capacity
- **Chemical Plants**: For oil-based products

#### Late Game (Tier 3)
- **Assembling Machine 3**: For maximum throughput
- **Electric Furnaces**: For pollution-free smelting
- **Module Integration**: Speed/productivity/quality modules

### Factory Layout

#### Basic Automation
```
Resource → Furnace → Plates → Assembler → Components → Products
```

#### Advanced Setup
```
Mining → Crushing → Washing → Smelting → Assembly → Quality Control
```

#### Mega-Base Design
- **Dedicated Lines**: Separate production lines for each component
- **Buffer Chests**: Storage between production stages
- **Inserter Networks**: Automated material transport
- **Power Distribution**: Reliable electricity to all machines

### Bottleneck Identification

#### Common Issues
- **Input Starvation**: Machines waiting for materials
- **Output Blockage**: Full output slots stopping production
- **Power Shortage**: Insufficient electricity supply
- **Inserter Limits**: Transport capacity exceeded

#### Optimization Techniques
- **Buffer Systems**: Extra storage to prevent starvation
- **Parallel Machines**: Multiple machines per recipe
- **Inserter Balancing**: Match inserter capacity to machine output
- **Power Redundancy**: Backup generators for reliability

## Advanced Techniques

### Module Integration

#### Speed Modules
- **Increase**: Production speed by 20-50%
- **Power Cost**: 50% more electricity consumption
- **Stack Limit**: Maximum 4 modules per machine

#### Productivity Modules
- **Increase**: Output by 4-10% per module
- **Speed Decrease**: 15% slower operation
- **Input Increase**: 12% more input materials required

#### Quality Modules
- **Increase**: Product quality tiers
- **Requirements**: Quality research technology
- **Complexity**: Advanced quality-based production

### Quality Production

#### Quality Tiers
- **Normal**: Base quality (100%)
- **Uncommon**: Improved quality (125%)
- **Rare**: High quality (150%)
- **Epic**: Superior quality (175%)
- **Legendary**: Ultimate quality (200%)

#### Quality Mechanics
- **Quality Modules**: Required for quality production
- **Success Chance**: Probability-based quality upgrades
- **Quality Decay**: Lower quality inputs reduce output quality

### Research Acceleration

#### Science Pack Production
- **Automation Science**: Red circuits, gears, iron plates
- **Logistic Science**: Inserters, transport belts, green circuits
- **Chemical Science**: Advanced circuits, sulfur, engine units
- **Production Science**: Productivity modules, rail signals
- **Utility Science**: Processing units, flying robot frames

#### Research Optimization
- **Parallel Labs**: Multiple research facilities
- **Science Distribution**: Efficient transport to labs
- **Research Priority**: Focus on bottleneck technologies

## Troubleshooting

### Machine Issues

#### Not Producing
- **Power Supply**: Check electricity connection and consumption
- **Input Materials**: Verify required items are in input slots
- **Recipe Selection**: Ensure correct recipe is loaded
- **Output Space**: Clear full output slots

#### Slow Production
- **Power Shortage**: Insufficient electricity (brownout effect)
- **Input Starvation**: Waiting for materials
- **Module Effects**: Productivity modules reduce speed
- **Machine Tier**: Upgrade to faster machines

### Recipe Problems

#### Recipe Not Available
- **Research Missing**: Unlock required technologies
- **Wrong Machine**: Use appropriate machine type for recipe category
- **Quality Requirements**: Meet quality thresholds for advanced recipes

#### Materials Not Consumed
- **Wrong Recipe**: Verify recipe matches loaded materials
- **Quality Mismatch**: Input quality affects production
- **Module Effects**: Productivity modules increase input requirements

### Performance Issues

#### Factory Bottlenecks
- **Identify Limits**: Find slowest production stage
- **Scale Up**: Add more machines to bottleneck stages
- **Balance Lines**: Ensure all stages have equal capacity

#### Power Management
- **Consumption Tracking**: Monitor total factory power needs
- **Generation Scaling**: Increase power production capacity
- **Distribution**: Ensure reliable power delivery to all machines

## Production Calculator

### Basic Formula
```
Production Rate = (Outputs per craft × Machine speed × Modules) / Craft time
```

### Example Calculation
**Electronic Circuit Production:**
- Machine: Assembling Machine 2 (0.75x speed)
- Recipe: 1 circuit, 0.5 seconds
- 2 Speed modules (+40% speed each)
- Total speed multiplier: 0.75 × 1.4 × 1.4 = 1.47x

```
Rate = (1 × 1.47) / 0.5 = 2.94 circuits/second
```

### Scaling Calculator
```
Machines needed = Desired rate / (Single machine rate × Efficiency)
```

**Example**: 100 circuits/second with 80% efficiency machines:
```
Machines = 100 / (2.94 × 0.8) ≈ 43 machines
```

## End-Game Mastery

### Infinite Production
- **Self-Sustaining Research**: Science packs fuel further research
- **Factory Optimization**: Continuous efficiency improvements
- **Quality Focus**: Maximize production quality
- **Automation**: Robotic networks for maintenance

### Mega-Factory Design
- **Modular Construction**: Expandable production modules
- **Resource Independence**: Self-sufficient material supply
- **Quality Control**: Automated quality assurance
- **Research Integration**: Labs fed by dedicated science lines

### Ultimate Goals
- **Space Exploration**: Rocket production requires mastery of all crafting systems
- **Infinite Expansion**: Factory grows without bounds
- **Technological Singularity**: Research enables increasingly advanced automation

Mastering crafting transforms FactoryForge from manual production to fully automated mega-factories capable of unlimited expansion and technological advancement.