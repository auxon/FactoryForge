# 🎯 FactoryForge - Complete Game Instructions

> **FactoryForge** is a comprehensive factory automation game inspired by Factorio, featuring procedural world generation, complex production chains, and advanced automation systems.

---

## 📋 Table of Contents

### 🎮 Getting Started
- [Game Overview](#-game-overview)
- [Basic Controls](#-basic-controls)

### ⛏️ Core Gameplay
- [Resources & Mining](#-resources--mining)
- [Production & Crafting](#-production--crafting)
- [Building & Automation](#-building--automation)
- [Inventory Management](#-inventory-management)

### ⚡ Advanced Systems
- [Fluid Systems & Water Management](#-fluid-systems--water-management)
- [Oil Processing & Chemical Production](#️-oil-processing--chemical-production)
- [Power Systems](#-power-systems)
- [Research & Progression](#-research--progression)
- [Combat & Defense](#-combat--defense)

### 🛠️ Special Features
- [In-App Store](#-in-app-store)
- [Auto-Play System](#-auto-play-system)

### 📚 Reference
- [User Interface](#-user-interface)
- [Tips & Strategies](#-tips--strategies)
- [Troubleshooting](#-troubleshooting)
- [Game Goals](#-game-goals)
- [Version Notes](#-version-notes)

---

## 🎮 Game Overview

FactoryForge is a factory automation game where you start with basic resources and work your way up to complex automated production lines. Gather resources, craft items, build machines, and defend your factory from enemies.

### 🌟 Key Features:
- **🌍 Procedural World Generation** - Every world is unique
- **⛏️ Resource Mining** - Extract iron, copper, coal, stone, uranium, and crude oil
- **🏭 Automated Production** - Build multiple tiers of assemblers and furnaces
- **🔄 Advanced Factory Automation** - Use belts, inserters, underground belts, splitters, and mergers
- **🌊 Fluid Systems** - Realistic fluid simulation with pipes, pumps, and networks
- **🛢️ Oil Processing** - Extract and refine crude oil into advanced materials
- **⚗️ Chemical Production** - Create plastics, explosives, batteries, and more
- **⚔️ Combat System** - Defend against enemies with firearms, gun turrets, and laser turrets
- **🧪 Research Tree** - Unlock advanced technologies and bonuses
- **⚡ Power Systems** - Steam, solar, and electric power generation
- **🛒 In-App Purchases** - Buy resources and upgrades through the store

---

## 🕹️ Basic Controls

### 🎥 Movement & Camera
- **📍 Move**: Touch and drag anywhere on the screen to pan the camera
- **🔍 Zoom**: Use pinch gestures to zoom in/out
- **📏 Zoom Levels**: Min 0.25x, Max 4.0x (starts at 4.0x for close-up view)

### 👤 Player Actions
- **⛏️ Manual Mining**: Tap on resource deposits to mine them manually
- **🔫 Combat**: Tap near enemies to shoot them (requires firearm magazine in inventory)
- **🏭 Building Interaction**: Tap on placed buildings to open their interfaces

---

## ⛏️ Resources & Mining

### 🔍 Resource Types
| Resource | Appearance | Item Produced | Notes |
|----------|------------|---------------|-------|
| **Iron Ore** | 🔵 Gray-blue patches | `iron-ore` | Basic metal, essential for everything |
| **Copper Ore** | 🟤 Brown patches | `copper-ore` | Used for electronics and cables |
| **Coal** | ⚫ Dark gray patches | `coal` | Fuel source, also used in chemical processes |
| **Stone** | 🔘 Gray patches | `stone` | Building material and furnace fuel |
| **Uranium Ore** | 🟢 Green patches | `uranium-ore` | Advanced resource (requires research) |
| **Crude Oil** | 🫧 Black liquid deposits | `crude-oil` | Complex processing required (requires research) |

### Manual Mining
1. Find resource deposits on the ground
2. Tap directly on them
3. Items appear in your inventory after a short animation
4. **Note**: Manual mining is disabled when placing buildings

### Automated Mining
Use **Burner Mining Drills** for automated resource extraction:

1. **Craft a Burner Mining Drill** (requires 5 iron plates)
2. **Place it on or adjacent to resource deposits**
3. **The drill automatically mines** the 3×3 area around it
4. **Green progress bar** shows mining progress
5. **Tap the drill** to collect mined resources from its output slot

---

## 🏭 Production & Crafting

### Crafting System
- **Manual Crafting**: Use the crafting menu (bottom-right button) to craft items
- **Automated Production**: Use machines for continuous production

### Key Machines

#### Burner Mining Drill
- **Cost**: 3 Iron Gear Wheels + 3 Iron Plates + 1 Stone Furnace
- **Function**: Automatically mines 3×3 area around placement
- **Fuel**: None required (burner technology)
- **Mining Speed**: 0.5 (items per second)
- **Output**: 1 slot for mined resources

#### Electric Mining Drill
- **Cost**: 3 Electronic Circuits + 5 Iron Gear Wheels + 10 Iron Plates
- **Function**: Automatically mines 3×3 area around placement
- **Power**: 90 kW electricity required
- **Mining Speed**: 0.75 (items per second)
- **Output**: 1 slot for mined resources

#### Stone Furnace
- **Cost**: 5 Stone
- **Function**: Smelts ores into plates
- **Recipes**: Iron ore → Iron plate, Copper ore → Copper plate, Stone → Stone brick
- **Fuel**: Coal or Wood (4000/2000 energy units respectively)
- **Crafting Speed**: 1.0 (base speed)
- **Slots**: 4 total (2 input, 2 output)

#### Steel Furnace
- **Cost**: 1 Steel Furnace (unlocked via research)
- **Function**: Faster smelting with higher fuel efficiency
- **Recipes**: All Stone Furnace recipes plus Steel Plate production
- **Fuel**: Coal or Wood (more efficient than stone furnace)
- **Crafting Speed**: 2.0 (2x faster than stone furnace)
- **Slots**: 4 total (2 input, 2 output)

#### Electric Furnace
- **Cost**: 1 Electric Furnace (unlocked via research)
- **Function**: Fastest smelting, no fuel required
- **Recipes**: All furnace recipes
- **Power**: 180 kW electricity required
- **Crafting Speed**: 2.0 (2x faster than stone furnace)
- **Slots**: 4 total (2 input, 2 output)

#### Assembling Machine 1
- **Cost**: 3 Electronic Circuits + 5 Iron Gear Wheels + 9 Iron Plates
- **Function**: Crafts intermediate products
- **Recipes**: Basic crafting recipes (gears, circuits, etc.)
- **Power**: 75 kW electricity required
- **Crafting Speed**: 0.5 (base speed)
- **Slots**: 8 total (4 input, 4 output)

#### Assembling Machine 2
- **Cost**: Unlocked via Automation 2 research
- **Function**: Advanced crafting with more recipes
- **Recipes**: Advanced crafting recipes (advanced circuits, processing units)
- **Power**: 150 kW electricity required
- **Crafting Speed**: 0.75 (50% faster than Assembling Machine 1)
- **Slots**: 8 total (4 input, 4 output)

#### Assembling Machine 3
- **Cost**: Unlocked via advanced research
- **Function**: Fastest automated crafting
- **Recipes**: All crafting recipes including complex items
- **Power**: 375 kW electricity required
- **Crafting Speed**: 1.25 (2.5x faster than Assembling Machine 1)
- **Slots**: 8 total (4 input, 4 output)

### Production Chain Examples

#### Basic Iron Processing
1. **Mine Iron Ore** → Burner Mining Drill
2. **Smelt to Iron Plates** → Stone Furnace + Coal
3. **Craft Iron Gear Wheels** → Assembling Machine

#### Electronic Circuit Production
1. **Mine Copper Ore** → Burner Mining Drill
2. **Smelt to Copper Plates** → Stone Furnace + Coal
3. **Mine Iron Ore** → Burner Mining Drill
4. **Smelt to Iron Plates** → Stone Furnace + Coal
5. **Craft Electronic Circuits** → Assembling Machine (Copper + Iron plates)

---

## 🏗️ Building & Automation

### Building Placement
1. **Open Build Menu** (bottom-left hammer icon)
2. **Select a building** from categories
3. **Find valid placement location** (green = valid, red = invalid)
4. **Tap to place** the building
5. **Requirements**: Sufficient materials in inventory

### Automation Tools

#### Transport Belts
- **Yellow Belt Cost**: 1 Iron Plate + 1 Iron Gear Wheel (5 belts)
- **Function**: Move items between machines
- **Directions**: Can be rotated during placement
- **Speed**: 15 items/minute per lane (1.875 items/second per lane)

#### Fast Transport Belts
- **Blue Belt Cost**: 5 Iron Gear Wheels + 1 Iron Plate
- **Function**: Faster item transport
- **Speed**: 30 items/minute per lane (3.75 items/second per lane)

#### Express Transport Belts
- **Purple Belt Cost**: 10 Iron Gear Wheels + 2 Advanced Circuits + 1 Steel Plate
- **Function**: Fastest item transport
- **Speed**: 45 items/minute per lane (5.625 items/second per lane)

#### Underground Belts
- **Cost**: 10 Iron Plates + 5 Transport Belts (makes 2 underground belts)
- **Function**: Route items underground between buildings
- **Range**: Connect input and output points up to several tiles apart
- **Speed**: Same as transport belt type used

#### Splitters
- **Cost**: 5 Electronic Circuits + 5 Iron Plates + 4 Transport Belts
- **Function**: Distribute items from one input to multiple outputs
- **Behavior**: Items distributed round-robin between left and right lanes

#### Mergers
- **Cost**: 5 Electronic Circuits + 5 Iron Plates + 4 Transport Belts
- **Function**: Combine items from multiple inputs into one output stream
- **Behavior**: Merges all input streams into organized output lanes

#### Belt Bridges
- **Cost**: Same as basic transport belts (for now)
- **Function**: Allow belts to cross over other belts or obstacles
- **Visual**: Elevated rendering with shadow underneath

#### Inserters
- **Basic Inserter Cost**: 1 Electronic Circuit + 1 Iron Gear Wheel + 1 Iron Plate
- **Function**: Move items between containers and machines
- **Range**: Standard pickup and drop range
- **Speed**: 4 seconds per operation (0.25 operations/second)

#### Long Handed Inserters
- **Cost**: Unlocked via Logistics research
- **Function**: Extended range item transfer
- **Range**: Longer pickup and drop distance
- **Speed**: 1.2 seconds per operation (0.83 operations/second)

#### Fast Inserters
- **Cost**: Unlocked via Logistics research
- **Function**: Faster item transfer
- **Range**: Standard pickup and drop range
- **Speed**: 2.31 seconds per operation (~0.43 operations/second)

#### Chests
- **Wooden Chest Cost**: 2 Wood
- **Capacity**: 16 slots
- **Function**: Basic item storage

- **Iron Chest Cost**: 8 Iron Plates
- **Capacity**: 32 slots
- **Function**: Intermediate item storage

- **Steel Chest Cost**: 1 Steel Chest (unlocked via research)
- **Capacity**: 48 slots
- **Function**: Large-scale item storage

---

## 🌊 Fluid Systems & Water Management

### How Fluids Work
FactoryForge features a realistic fluid simulation system inspired by Factorio. Unlike items that are transported via belts, fluids flow through pipes and are stored in specialized containers. Fluid systems require careful planning and infrastructure.

### Key Fluid Concepts
- **Fluid Networks**: Connected pipes automatically form networks that share fluid
- **Pressure**: Fluids flow from high-pressure to low-pressure areas
- **Viscosity**: Different fluids flow at different speeds (water flows easily, oil is viscous)
- **Storage**: Fluids are stored in tanks and transported through pipes
- **Consumption**: Machines consume fluids at specific rates

### Fluid Buildings

#### Pipes
- **Cost**: 1 Iron Plate
- **Function**: Transport fluids between buildings
- **Capacity**: 100 units per pipe segment
- **Connections**: Up to 4 directions (north, south, east, west)
- **Placement**: Drag to place multiple segments; rotate to control which sides connect
- **Flow**: Automatic pressure-based distribution

#### Water Pumps
- **Cost**: 5 Iron Plates + 5 Pipes + 2 Electronic Circuits
- **Placement**: **Must be placed directly on water tiles** (shoreline only)
- **Power**: No power required (passive extraction)
- **Output**: 20 water/second directly into connected pipes
- **Function**: Infinite water source - extracts from the ocean/lakes

#### Boilers
- **Cost**: 1 Stone Furnace + 4 Pipes
- **Function**: Converts fuel + water into steam for power generation
- **Fuel**: Coal or Wood (4000/2000 energy units respectively)
- **Water Input**: 1.8 water/second (540L tank capacity = 5 minutes runtime)
- **Steam Output**: 1.8 steam/second (connects to steam engines)
- **Power**: No electricity required (chemical reaction)
- **Requirements**: Both fuel AND water must be available to produce steam

#### Steam Engines
- **Cost**: 8 Iron Gear Wheels + 10 Iron Plates + 5 Pipes
- **Function**: Converts steam into electrical power
- **Steam Input**: 1.8 steam/second
- **Power Output**: 900 kW electricity
- **Efficiency**: 100% (no energy loss in conversion)

#### Fluid Tanks
- **Cost**: 20 Iron Plates + 5 Steel Plates
- **Capacity**: 2500 units per tank
- **Function**: Store fluids for buffering production
- **Connections**: Connect to pipes for fluid input/output

### Steam Power Setup
The complete steam power chain requires careful fluid management:

1. **Place Water Pump** on water tile
2. **Connect Pipes** from water pump to boiler
3. **Add Fuel** to boiler (coal/wood)
4. **Connect Pipes** from boiler to steam engine
5. **Power Generated** automatically when water + fuel are available

**Critical Notes:**
- Boilers will stop producing steam if they run out of water
- Water pumps must be placed on actual water tiles (not just anywhere)
- Steam engines require continuous steam flow for power generation
- The 540L boiler water tank provides ~5 minutes of runtime without water input

### Fluid Network Tips
- **Plan Ahead**: Design fluid networks before building
- **Monitor Flow**: Check pipe connections and fluid levels
- **Buffer Storage**: Use fluid tanks to prevent production interruptions
- **Pressure Management**: High-pressure areas push fluid to low-pressure areas
- **Network Size**: Large pipe networks may need pumps for proper flow

---

## 🛢️ Oil Processing & Chemical Production

### Oil Extraction
- **Pumpjacks**: Extract crude oil from deposits (requires Oil Processing research)
- **Cost**: 5 Steel Plates + 10 Iron Gear Wheels + 5 Electronic Circuits + 10 Pipes
- **Power**: 90 kW electricity required
- **Output**: 10 crude oil/second directly into connected pipes
- **Placement**: Must be placed directly over oil deposits
- **Resource**: Oil wells are infinite (unlike Factorio's depleting wells)

### Oil Refining
- **Oil Refineries**: Process crude oil into petroleum gas, light oil, and heavy oil
- **Cost**: 15 Steel Plates + 10 Iron Gear Wheels + 10 Electronic Circuits + 10 Pipes + 10 Stone Bricks
- **Power**: 420 kW electricity required
- **Fluid Input**: Crude oil from pumpjacks via pipes
- **Fluid Output**: Petroleum gas, light oil, heavy oil via pipes
- **Recipes**:
  - **Basic Oil Processing**: 100 Crude Oil → 45 Petroleum Gas + 30 Light Oil + 25 Heavy Oil
  - **Advanced Oil Processing**: 100 Crude Oil + 50 Water → 55 Petroleum Gas + 45 Light Oil + 25 Heavy Oil
- **Processing Time**: 5 seconds per batch

### Oil Cracking
- **Chemical Plants**: Process fluids for advanced oil products (210 kW power)
- **Cost**: 5 Steel Plates + 5 Iron Gear Wheels + 5 Electronic Circuits + 5 Pipes
- **Light Oil Cracking**: 30 Light Oil + 30 Water → 20 Petroleum Gas
- **Heavy Oil Cracking**: 40 Heavy Oil + 30 Water → 30 Light Oil
- **Processing Time**: 5 seconds per batch

### Fluid Storage
- **Storage Tanks**: Store large quantities of fluids
- **Cost**: 20 Iron Plates + 5 Steel Plates
- **Capacity**: 2500 units per tank
- **Function**: Buffer fluids to prevent production interruptions
- **Connections**: Connect to pipes for input/output

### Chemical Products
- **Plastic Bar**: 20 Petroleum Gas + 1 Coal → 2 Plastic Bars
- **Sulfur**: 30 Petroleum Gas + 30 Water → 2 Sulfur
- **Sulfuric Acid**: 5 Sulfur + 1 Iron Plate + 100 Water → 50 Sulfuric Acid
- **Lubricant**: 10 Heavy Oil → 10 Lubricant
- **Battery**: 1 Iron Plate + 1 Copper Plate + 20 Sulfuric Acid → 1 Battery
- **Explosives**: 1 Coal + 1 Sulfur + 1 Water → 2 Explosives

### Chemical Science Pack Production
- **Requirements**: 3 Advanced Circuits + 2 Engine Units + 1 Sulfuric Acid
- **Output**: 1 Chemical Science Pack (unlocks advanced research)

---

## ⚡ Power Systems

### Steam Power (Early Game)
Steam power is the first power generation method and requires careful fluid management:

- **Boiler Setup**:
  - **Building**: 1 Stone Furnace + 4 Pipes
  - **Water Input**: 1.8 water/second (from water pump via pipes)
  - **Fuel**: Coal (4000 energy) or Wood (2000 energy) in fuel slot
  - **Steam Output**: 1.8 steam/second via pipes
  - **Water Tank**: 540L internal capacity (5 minutes runtime)

- **Steam Engine**:
  - **Building**: 8 Iron Gear Wheels + 10 Iron Plates + 5 Pipes
  - **Steam Input**: 1.8 steam/second via pipes
  - **Power Output**: 900 kW electricity
  - **Efficiency**: 100% conversion rate

**Complete Setup Requirements:**
1. Water Pump placed on water tile
2. Pipes connecting water pump → boiler → steam engine
3. Fuel in boiler inventory
4. All buildings connected to power network

### Solar Power (Mid Game)
- **Solar Panels**: Generate 60 kW each during daylight
- **Cost**: 5 Steel Plates + 15 Electronic Circuits + 5 Copper Plates
- **Accumulators**: Store excess power for nighttime use
- **Cost**: Unlocked via Electric Energy Accumulators research
- **Capacity**: 5000 kJ per accumulator

### Power Distribution
- **Small Electric Pole**: 7.5 tile wire reach, 2.5 tile supply area
- **Medium Electric Pole**: 9 tile wire reach, 3.5 tile supply area
- **Big Electric Pole**: 30 tile wire reach, 2 tile supply area (2×2 size)

---

## 🛒 In-App Store

### Available Purchases
- **Resource Packs**: Buy stacks of iron ore, copper ore, coal, stone, wood, crude oil
- **Upgrade Packs**: Purchase advanced materials and components
- **Convenience Items**: Skip grinding by buying intermediate products

### How to Access
1. Tap the shopping cart icon in the main menu
2. Browse available products and their costs
3. Complete purchase to add items to your inventory
4. Items are delivered instantly to your player inventory

---

## 🎒 Inventory Management

### Player Inventory
- **40 slots** total (4 rows × 10 columns)
- **Stack sizes** vary by item type
- **Item counts** shown in bottom-right corner of each slot
- **Quick access** to frequently used items

### Machine Inventories
- **Mining Drills**: 1 output slot
- **Furnaces**: 4 slots (2 input, 2 output)
- **Assemblers**: 8 slots (4 input, 4 output)
- **Tap machines** to open their inventory interface

### Transferring Items
1. **Tap a machine** to open its inventory
2. **Tap an item** in your inventory
3. **Tap an empty slot** in the machine inventory
4. **Items move** between inventories

---

## ⚔️ Combat & Defense

### Player Combat
- **Weapon**: Firearm (requires firearm magazine)
- **Ammo**: Firearm magazines (craft from iron plates)
- **Range**: Tap near enemies to shoot
- **Auto-targeting**: Targets nearest enemy within range

### Turrets
- **Gun Turret**: Automatic defense against enemies
- **Cost**: 10 Iron Gear Wheels + 10 Copper Plates + 20 Iron Plates
- **Ammo**: Requires firearm magazines or piercing rounds magazines
- **Range**: 18 tiles
- **Damage**: 6 per shot (firearm magazine) or 8 per shot (piercing rounds)
- **Fire Rate**: 10 shots per second

- **Laser Turret**: Advanced defense with high damage
- **Cost**: Unlocked via Laser Turrets research
- **Power**: 800 kW electricity required
- **Range**: 24 tiles
- **Damage**: 20 per shot
- **Fire Rate**: 20 shots per second

### Ammunition
- **Firearm Magazine**: Basic ammo (4 Iron Plates each)
- **Piercing Rounds Magazine**: Advanced ammo with higher damage (unlocked via Military research)

### Enemy Types
- **Biters**: Basic enemies that attack your factory
- **Spawners**: Generate more enemies over time
- **Pollution**: Attracts enemies (generated by machines)

---

## 🔬 Research & Progression

### Research System
- **Access**: Lab building + science packs
- **Science Packs**: Different colors for different technologies
- **Requirements**: Labs consume science packs to generate research points

### Research Tree

#### Tier 1 - Basic Technologies (Red Science Only)
- **Automation** - Unlocks Assembling Machine 1 (10 Red packs)
- **Logistics** - Unlocks Fast/Long Handed Inserters (20 Red packs)
- **Turrets** - Unlocks Gun Turret (10 Red packs)
- **Stone Walls** - Unlocks defensive walls (10 Red packs)
- **Steel Processing** - Unlocks Steel Plate smelting (50 Red packs)
- **Military** - Unlocks Piercing Rounds Magazine (20 Red packs)

#### Tier 2 - Advanced Technologies (Red + Green Science)
- **Logistic Science Pack** - Enables green science production (75 Red packs)
- **Automation 2** - Unlocks Assembling Machine 2 (40 Red + 40 Green packs)
- **Logistics 2** - Unlocks Fast Transport Belts (40 Red + 40 Green packs)
- **Advanced Logistics** - Unlocks Underground Belts, Splitters, Mergers (75 Red + 75 Green packs)
- **Advanced Material Processing** - Unlocks Steel Furnace (50 Red + 50 Green packs)
- **Solar Energy** - Unlocks Solar Panels (100 Red + 100 Green packs)
- **Electric Energy Accumulators** - Unlocks Accumulators (100 Red + 100 Green packs)
- **Laser Turrets** - Unlocks Laser Turrets (150 Red + 150 Green packs)
- **Mining Productivity 1** - +10% mining output bonus (100 Red + 100 Green packs)
- **Research Speed 1** - +20% research speed bonus (100 Red + 100 Green packs)

#### Tier 3 - Oil & Chemical Processing (Red + Green + Blue Science)
- **Oil Processing** - Unlocks Pumpjacks and basic refining (50 Red + 50 Green + 50 Blue packs)
- **Advanced Oil Processing** - Unlocks Oil Refineries and advanced refining (50 Red + 50 Green + 50 Blue packs)
- **Chemistry** - Unlocks Chemical Plants and basic chemical production (100 Red + 100 Green + 100 Blue packs)
- **Oil Cracking** - Unlocks oil cracking for better yields (100 Red + 100 Green + 100 Blue packs)
- **Sulfur Processing** - Unlocks sulfuric acid production (100 Red + 100 Green + 100 Blue packs)
- **Battery** - Unlocks battery production (100 Red + 100 Green + 100 Blue packs)
- **Explosives** - Unlocks explosive production (100 Red + 100 Green + 100 Blue packs)

---

## 🎛️ User Interface

### HUD Elements
- **Top-left**: Resource counters (moved to inventory)
- **Bottom-left**: Build menu button (hammer)
- **Bottom-right**: Crafting menu button (wrench)
- **Inventory**: Always visible at bottom of screen

### Tooltips
- **Hover over items** to see names and descriptions
- **Hover over resources** to see what they contain
- **Building placement** shows valid/invalid placement

### Machine Interfaces
- **Mining Drills**: Single centered output slot
- **Furnaces/Assemblers**: Recipe selection + input/output slots
- **Progress bars**: Green bars show machine progress

---

## 💡 Tips & Strategies

### Getting Started
1. **Gather initial resources** - Mine iron ore and stone manually
2. **Build a furnace** - Smelt iron ore into plates
3. **Craft a mining drill** - Automate iron ore collection
4. **Expand production** - Build more furnaces and drills

### Efficient Factory Design
- **Layout matters**: Place machines logically (inputs → processing → outputs)
- **Use belts**: Connect machines with transport belts
- **Inserters**: Automate item transfer between containers
- **Balance production**: Don't overproduce one resource

### Defense Strategy
- **Early game**: Manual combat with firearms
- **Mid game**: Build turrets for automatic defense
- **Pollution control**: Use efficient machines to reduce enemy attraction
- **Wall off**: Use stone walls to protect your factory

### Resource Management
- **Don't waste**: Only build what you need
- **Stockpile**: Keep buffer inventories for production stability
- **Recycle**: Deconstruct buildings to recover materials
- **Research priority**: Focus on automation first, then defense

### Power Management
- **Steam Power**: Boiler + Steam Engine (early game) - requires water pump + pipes
- **Solar Power**: Free energy but limited capacity
- **Accumulator**: Store excess power for nighttime

### Fluid System Management
- **Water Supply**: Always place water pumps on water tiles, not land
- **Pipe Networks**: Plan complete pipe connections before building fluid machines
- **Buffer Tanks**: Use fluid tanks to prevent production interruptions
- **Monitor Boiler Water**: Boilers stop producing steam when water runs out

---

## 🏆 Advanced Techniques

### Mega Base Building
- **Mass production**: Large-scale automated factories
- **Rail transport**: For long-distance logistics (future feature)
- **Oil processing**: Advanced recipes using petroleum
- **Robotics**: Automated construction and logistics

### Combat Strategies
- **Turret walls**: Layered defense systems
- **Biter management**: Control pollution to reduce enemy spawns
- **Mobile defense**: Player + turret combinations

### Optimization
- **Belt balancing**: Ensure equal throughput on all belt lanes
- **Inserter timing**: Synchronize inserter operations
- **Beacon networks**: Boost machine efficiency (future feature)

---

## 🔧 Troubleshooting

### Common Issues
- **Can't place buildings**: Check for obstacles, resources, or insufficient materials
- **Machines not working**: Ensure proper power connection and input materials
- **No resources showing**: Mine manually first to discover deposits
- **Combat not working**: Check ammo in inventory and enemy proximity
- **Boilers not producing steam**: Check water pump placement (must be on water tiles) and pipe connections
- **No water flow**: Ensure water pumps are placed on actual water tiles, not just land
- **Oil wells not working**: Must be placed directly over oil deposits (not adjacent)
- **Fluids not flowing**: Check pipe connections form complete networks

### Performance Tips
- **Zoom out** for better overview of large factories
- **Close UI panels** when not needed
- **Limit enemies** by controlling pollution levels

---

## 🤖 Auto-Play System

### Overview
FactoryForge includes an advanced auto-play system for automated testing, performance validation, and demo creation. This system allows the game to run autonomously with predefined scenarios.

### Features
- **Time Controls**: Speed up game time for faster testing (up to 8x speed)
- **Scenario Playback**: Run predefined automated sequences
- **Performance Monitoring**: Track FPS, entity counts, and production rates
- **Automated Building**: Smart placement of production chains

### Access Auto-Play
1. Look for the auto-play menu in the loading screen
2. Select from predefined scenarios or create custom ones
3. Control playback speed and monitor performance metrics

### Use Cases
- **Development Testing**: Automated regression testing
- **Performance Benchmarking**: Stress test with many entities
- **Demo Creation**: Automated showcases of game features
- **Tutorial Automation**: Guided automated learning sequences

---

## 🎯 Game Goals

### Short Term
- Establish basic resource gathering (iron + copper)
- Build your first automated furnace
- Craft essential tools and weapons

### Medium Term
- Create automated production lines
- Research new technologies
- Build defensive structures

### Long Term
- Create massive automated factories
- Achieve full automation
- Defend against increasingly difficult enemies

---

## 📚 Additional Documentation

FactoryForge includes detailed guides for specific game mechanics:

### 📖 Available Guides
- **[Belt Mechanics Guide](Belt Mechanics.md)** - Advanced belt systems (underground belts, splitters, mergers)
- **[Fluid Mechanics](Fluid Mechanics.md)** - Complete guide to fluid systems, pipes, and networks
- **[Oil Processing Guide](Oil.md)** - Detailed oil extraction and refining instructions
- **[Research Guide](Research.md)** - Complete research tree and technology details
- **[Furnace Usage Guide](How to Use a Furnace.md)** - Detailed furnace operation instructions
- **[Auto-Play Plan](autoplay_plan.md)** - Automated testing and demo system documentation

### 📱 Accessing Help In-Game
1. Tap the **question mark (?) icon** in the main menu
2. Browse available documentation topics
3. Each guide covers specific aspects of gameplay in detail

---

## 📝 Version Notes

**Current Features:**
- ✅ Procedural world generation
- ✅ Resource mining (manual + automated, including uranium)
- ✅ Multi-tier crafting and production (stone/steel/electric furnaces, 3 assembler tiers)
- ✅ Advanced factory automation (underground belts, splitters, mergers, belt bridges)
- ✅ Realistic fluid systems (pipes, pumps, networks, pressure simulation)
- ✅ Complete oil processing (extraction, refining, and cracking)
- ✅ Full chemical production (plastics, sulfur, sulfuric acid, batteries, explosives)
- ✅ Research tree (3 tiers, 20+ technologies, some advanced tech locked)
- ✅ Advanced power systems (steam, solar, accumulators)
- ✅ Multi-tier combat (gun turrets, laser turrets, piercing ammo)
- ✅ Comprehensive inventory and logistics systems
- ✅ In-app purchase store system
- ✅ Auto-play system for testing and demos
- ✅ Performance monitoring and benchmarking
- ✅ Advanced UI with research, crafting, and machine interfaces

**Planned Features:**
- 🚧 Nuclear power generation
- 🚧 Rail transport system
- 🚧 Robot automation (logistic robots, construction robots)
- 🚧 Nuclear power generation
- 🚧 Advanced weapons and defense
- 🚧 Multiplayer support
- 🚧 Modding support

---

*Enjoy building your automated factory empire in FactoryForge!* 🚀
