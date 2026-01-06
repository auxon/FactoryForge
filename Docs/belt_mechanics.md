# Advanced Belt Mechanics Guide

FactoryForge now supports advanced belt mechanics inspired by Factorio, allowing you to create complex and efficient factory layouts. This guide covers all the advanced belt types and how to use them effectively.

## Table of Contents
1. [Basic Belts](#basic-belts)
2. [Underground Belts](#underground-belts)
3. [Splitters](#splitters)
4. [Mergers](#mergers)
5. [Belt Bridges](#belt-bridges)
6. [Advanced Techniques](#advanced-techniques)
7. [Crafting Recipes](#crafting-recipes)

## Basic Belts

FactoryForge includes three tiers of basic transport belts:

- **Transport Belt**: Basic yellow belt (15 items/second per lane)
- **Fast Transport Belt**: Blue belt (30 items/second per lane)
- **Express Transport Belt**: Purple belt (45 items/second per lane)

Basic belts transport items in two lanes (left and right) and automatically connect to adjacent belts pointing toward them.

## Underground Belts

Underground belts allow you to route items under buildings and obstacles, saving valuable surface space.

### How to Use
1. **Craft** an underground belt
2. **Place** the input end where you want items to enter the underground section
3. **Place** the output end where you want items to emerge (can be up to several tiles away)
4. Items flow instantly underground between the two points

### Visual Indicators
- Underground belts show as small circles at input/output positions
- Dark grey coloring to distinguish from surface belts
- No visible belt segments between input and output

### Use Cases
- Routing belts around large buildings
- Crossing under power poles or other infrastructure
- Creating compact factory layouts
- Organizing complex belt networks

## Splitters

Splitters take items from one input and distribute them across multiple outputs, enabling load balancing and parallel processing.

### How to Use
1. **Craft** a splitter
2. **Place** it adjacent to your input belt
3. The splitter automatically connects to:
   - Input: Belt pointing toward the splitter
   - Outputs: Adjacent belts in all directions (north, east, south, west)

### Behavior
- Items are distributed round-robin between left and right lanes
- If one output is blocked, items continue flowing to available outputs
- Perfect for balancing production across multiple assemblers

### Visual Indicators
- Central brown hub with arms extending in all directions
- Brown coloring distinguishes from normal belts

### Example Setup
```
Input Belt → Splitter → Output Belt 1
                    → Output Belt 2
                    → Output Belt 3
                    → Output Belt 4
```

## Mergers

Mergers combine items from multiple inputs into one organized output stream.

### How to Use
1. **Craft** a merger
2. **Place** it where you want the combined output
3. Position input belts adjacent to the merger
4. The merger automatically collects from all adjacent belts

### Behavior
- Collects items from all adjacent input belts
- Merges them into a single output stream
- Maintains lane separation (left/right lanes)
- Useful for consolidating production from multiple sources

### Visual Indicators
- Central hub with wider arms (green tint)
- Distinctive appearance from splitters

### Example Setup
```
Input Belt 1 → Merger → Combined Output Belt
Input Belt 2 →       ↑
Input Belt 3 →       ↑
Input Belt 4 →       ↑
```

## Belt Bridges

Belt bridges allow belts to cross over other belts or obstacles while maintaining elevation.

### How to Use
1. **Craft** a belt bridge (same recipe as basic belts for now)
2. **Place** over existing belts or obstacles
3. The bridge appears elevated with a shadow underneath

### Behavior
- Same transport mechanics as normal belts
- Visual elevation prevents confusion with underlying belts
- Can cross over any terrain or other belt networks

### Visual Indicators
- Elevated rendering with shadow
- Maintains belt direction and speed
- Clear visual separation from ground-level belts

## Advanced Techniques

### Load Balancing Assembly Lines
Use splitters to distribute raw materials evenly across multiple assemblers:

```
Raw Materials → Splitter → Assembler 1 → Splitter → Final Product
                   → Assembler 2 →          ↑
                   → Assembler 3 →          ↑
                   → Assembler 4 →       Merger
```

### Compact Factory Layouts
Combine underground belts with bridges to create multi-level factories:

```
Ground Level: Mining → Underground → Processing
Upper Level:   Bridge → Assembly → Bridge → Packaging
```

### Parallel Production Networks
Use mergers and splitters for complex production trees:

```
Ore Input → Splitter → Furnace 1 → Merger → Plate Processing
             → Furnace 2 →       ↑
             → Furnace 3 →       ↑
             → Furnace 4 →       ↑
```

## Crafting Recipes

### Underground Belt
- **Requirements**: 10 Iron Plates + 5 Transport Belts
- **Output**: 2 Underground Belts
- **Crafting Time**: 1 second
- **Use**: Route items underground between buildings

### Splitter
- **Requirements**: 5 Electronic Circuits + 5 Iron Plates + 4 Transport Belts
- **Output**: 1 Splitter
- **Crafting Time**: 1 second
- **Use**: Distribute items to multiple outputs

### Merger
- **Requirements**: 5 Electronic Circuits + 5 Iron Plates + 4 Transport Belts
- **Output**: 1 Merger
- **Crafting Time**: 1 second
- **Use**: Combine multiple inputs into one output

### Belt Bridge
- **Requirements**: Same as basic transport belts (for now)
- **Use**: Cross over obstacles and other belts

## Tips & Best Practices

1. **Plan Ahead**: Advanced belts allow complex layouts, so sketch your factory design first
2. **Use Colors**: Different belt tiers have distinct colors - use them strategically
3. **Balance Loads**: Splitters prevent bottlenecks by distributing work evenly
4. **Save Space**: Underground belts let you route around large buildings
5. **Visual Clarity**: Bridges help organize multi-level belt networks

## Troubleshooting

### Items Not Moving
- Check belt connections and directions
- Ensure power is available (for electric belts)
- Verify no blockages in the path

### Splitters/Mergers Not Working
- Ensure proper adjacency (splitters/mergers connect to all adjacent belts)
- Check that input belts are pointing toward the splitter/merger

### Underground Belts Not Connecting
- Input and output positions must be on valid belt paths
- Ensure no obstacles block the underground route

---

These advanced belt mechanics transform FactoryForge from simple automation to complex, efficient factory networks. Experiment with different combinations to optimize your production! 🏭⚡
