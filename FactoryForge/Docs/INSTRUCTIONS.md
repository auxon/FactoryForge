# FactoryForge - Game Instructions

Welcome to **FactoryForge**, a factory automation game set in a procedurally generated world! Build factories, automate production, and defend against enemies in this 2D factory building game.

## 🎮 Game Overview

FactoryForge is a factory automation game where you start with basic resources and work your way up to complex automated production lines. Gather resources, craft items, build machines, and defend your factory from enemies.

### Key Features:
- **Procedural World Generation** - Every world is unique
- **Resource Mining** - Extract iron, copper, coal, and stone
- **Automated Production** - Build assemblers and furnaces for automated crafting
- **Factory Automation** - Use belts, inserters, and chests to create production lines
- **Combat System** - Defend against enemies with firearms and turrets
- **Research Tree** - Unlock new technologies and recipes

---

## 🕹️ Basic Controls

### Movement & Camera
- **Move**: Touch and drag anywhere on the screen to pan the camera
- **Zoom**: Use pinch gestures to zoom in/out
- **Zoom Levels**: Min 0.25x, Max 4.0x (starts at 4.0x for close-up view)

### Player Actions
- **Manual Mining**: Tap on resource deposits (iron ore, copper ore, coal, stone) to mine them manually
- **Combat**: Tap near enemies to shoot them (requires firearm magazine in inventory)
- **Building Interaction**: Tap on placed buildings to open their interfaces

---

## ⛏️ Resources & Mining

### Resource Types
- **Iron Ore** - Gray-blue patches, produces `iron-ore`
- **Copper Ore** - Brown patches, produces `copper-ore`
- **Coal** - Dark gray patches, produces `coal`
- **Stone** - Gray patches, produces `stone`

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
- **Cost**: 5 iron plates
- **Function**: Automatically mines resources
- **Fuel**: None required (burner technology)
- **Output**: 1 slot for mined resources

#### Stone Furnace
- **Cost**: 5 iron plates
- **Function**: Smelts ores into plates
- **Recipes**: Iron ore → Iron plate, Copper ore → Copper plate
- **Fuel**: Coal (place in furnace input)
- **Slots**: 4 total (2 input, 2 output)

#### Assembling Machine 1
- **Cost**: Custom recipe (unlock via research)
- **Function**: Crafts intermediate products
- **Recipes**: Various crafting recipes
- **Power**: 75 kW electricity required
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
- **Cost**: 1 iron plate
- **Function**: Move items between machines
- **Directions**: Can be rotated during placement
- **Speed**: Basic belts move 15 items/minute per lane

#### Inserters
- **Cost**: Various (basic inserter requires custom parts)
- **Function**: Move items between containers and machines
- **Range**: Pick up from input, drop to output
- **Speed**: Varies by inserter type

#### Chests
- **Cost**: Various woods/metals
- **Function**: Store large amounts of items
- **Capacity**: 16-48 slots depending on chest type

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
- **Cost**: Custom recipe (unlock via research)
- **Ammo**: Requires firearm magazines
- **Range**: 18 tiles
- **Damage**: 6 per shot

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
1. **Basic Automation** - Unlocks assemblers and inserters
2. **Logistics** - Better belts and storage
3. **Military** - Weapons and defense
4. **Production** - Advanced machines and recipes

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
- **Steam Power**: Boiler + Steam Engine (early game)
- **Solar Power**: Free energy but limited capacity
- **Accumulator**: Store excess power for nighttime

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

### Performance Tips
- **Zoom out** for better overview of large factories
- **Close UI panels** when not needed
- **Limit enemies** by controlling pollution levels

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

## 📝 Version Notes

**Current Features:**
- ✅ Procedural world generation
- ✅ Resource mining (manual + automated)
- ✅ Basic crafting and production
- ✅ Building placement system
- ✅ Inventory management
- ✅ Basic combat system
- ✅ Furnace automation
- ✅ Assembler automation
- ✅ Transport belts and inserters
- ✅ Research system
- ✅ UI improvements

**Planned Features:**
- 🚧 Electric mining drills
- 🚧 Advanced machines (steel furnaces, chemical plants)
- 🚧 Oil processing
- 🚧 Rail transport
- 🚧 Robot automation
- 🚧 Multiplayer support

---

*Enjoy building your automated factory empire in FactoryForge!* 🚀
