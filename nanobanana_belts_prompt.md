# 🎨 Nano Banana Belt Animation Specification

## FactoryForge Transport Belt Animation System

**Created for:** Nano Banana - Belt Sprite Generation  
**Game:** FactoryForge - 2D Factory Automation Game  
**Date:** December 2025  
**Total Files:** 192 animated belt sprites

---

## 📋 Overview

FactoryForge requires animated belt sprites that show conveyor belt movement in 4 directions (north, east, south, west) across 3 belt speeds (transport, fast, express). Each animation consists of 16 frames that loop seamlessly to create smooth belt motion.

### Key Requirements
- **Sprite Size:** 32×32 pixels
- **Animation:** 16 frames per direction/speed combination
- **Loop:** Seamless (frame 16 → frame 1)
- **Movement:** 2 pixels per frame (32 pixel total loop)
- **Format:** PNG with transparency

---

## 🎨 Belt Surface Pattern Design

### Base Belt Texture
All belts use a diagonal ridge pattern that moves in the belt's direction. The pattern consists of:
- **Background:** Dark gray (#333333)
- **Ridges:** Medium gray (#666666) diagonal lines at 45°
- **Spacing:** 6 pixels between ridge centers
- **Thickness:** 2 pixels per ridge
- **Movement:** 2 pixels per frame

### Speed-Specific Enhancements
- **Transport Belt:** Standard gray pattern
- **Fast Belt:** Yellow accent highlights (#FFD700)
- **Express Belt:** Blue accent highlights (#00BFFF)

---

## 📐 Pixel-Perfect Frame Specifications

### Coordinate System
- **Origin:** Top-left (0,0)
- **X-axis:** Increases right
- **Y-axis:** Increases down
- **Movement:** Pattern shifts in belt direction

### Transport Belt - North Direction (Moving Up)
**Files:** `transport_belt_north_001.png` through `transport_belt_north_016.png`

#### Frame 001 (Starting Position)
```
32×32 Grid - North Movement (Up)
Y∧
31│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
30│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
29│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
28│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
27│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
26│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
25│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
24│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
23│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
22│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
21│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
20│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
19│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
18│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
17│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
16│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
15│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
14│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
13│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
12│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
11│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
10│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 9│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 8│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 7│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 6│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 5│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 4│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 3│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 2│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 1│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 0└────────────────────────────────┘X
   01234567890123456789012345678901
```

**Diagonal Ridge Pattern:**
- Ridge 1: (0,0) to (2,2) - pixels (0,0),(1,1),(2,2)
- Ridge 2: (6,0) to (8,2) - pixels (6,0),(7,1),(8,2)
- Ridge 3: (12,0) to (14,2) - pixels (12,0),(13,1),(14,2)
- Ridge 4: (18,0) to (20,2) - pixels (18,0),(19,1),(20,2)
- Ridge 5: (24,0) to (26,2) - pixels (24,0),(25,1),(26,2)
- Ridge 6: (30,0) to (31,1) - pixels (30,0),(31,1)

#### Frame 002 (2 pixels up)
```
Y∧
31│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
30│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
29│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
28│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
27│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
26│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
25│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
24│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
23│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
22│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
21│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
20│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
19│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
18│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
17│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
16│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
15│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
14│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
13│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
12│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
11│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
10│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 9│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 8│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 7│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 6│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 5│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 4│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 3│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 2│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 1│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
 0│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
  └────────────────────────────────┘X
```
**Ridge positions shifted 2 pixels up from Frame 001**

#### Frame 003 (4 pixels up)
**Ridge positions shifted 4 pixels up from Frame 001**

#### Frame 004 (6 pixels up)
**Ridge positions shifted 6 pixels up from Frame 001**

#### Frame 005 (8 pixels up)
**Ridge positions shifted 8 pixels up from Frame 001**

#### Frame 006 (10 pixels up)
**Ridge positions shifted 10 pixels up from Frame 001**

#### Frame 007 (12 pixels up)
**Ridge positions shifted 12 pixels up from Frame 001**

#### Frame 008 (14 pixels up)
**Ridge positions shifted 14 pixels up from Frame 001**

#### Frame 009 (16 pixels up)
**Ridge positions shifted 16 pixels up from Frame 001**

#### Frame 010 (18 pixels up)
**Ridge positions shifted 18 pixels up from Frame 001**

#### Frame 011 (20 pixels up)
**Ridge positions shifted 20 pixels up from Frame 001**

#### Frame 012 (22 pixels up)
**Ridge positions shifted 22 pixels up from Frame 001**

#### Frame 013 (24 pixels up)
**Ridge positions shifted 24 pixels up from Frame 001**

#### Frame 014 (26 pixels up)
**Ridge positions shifted 26 pixels up from Frame 001**

#### Frame 015 (28 pixels up)
**Ridge positions shifted 28 pixels up from Frame 001**

#### Frame 016 (30 pixels up)
**Ridge positions shifted 30 pixels up from Frame 001**

---

## 🔄 Other Directions

### East Direction (Moving Right)
**Files:** `transport_belt_east_001.png` through `transport_belt_east_016.png`

**Movement Pattern:** Same ridge pattern, shifted 2 pixels right per frame
- Frame 001: Base position
- Frame 002: 2 pixels right
- Frame 003: 4 pixels right
- ...
- Frame 016: 30 pixels right

### South Direction (Moving Down)
**Files:** `transport_belt_south_001.png` through `transport_belt_south_016.png`

**Movement Pattern:** Same ridge pattern, shifted 2 pixels down per frame
- Frame 001: Base position
- Frame 002: 2 pixels down
- Frame 003: 4 pixels down
- ...
- Frame 016: 30 pixels down

### West Direction (Moving Left)
**Files:** `transport_belt_west_001.png` through `transport_belt_west_016.png`

**Movement Pattern:** Same ridge pattern, shifted 2 pixels left per frame
- Frame 001: Base position
- Frame 002: 2 pixels left
- Frame 003: 4 pixels left
- ...
- Frame 016: 30 pixels left

---

## ⚡ Fast Transport Belt Variations

### Visual Differences from Transport Belt
- **Accent Color:** Yellow highlights (#FFD700) on ridge edges
- **Same Animation Pattern:** Identical movement to transport belt
- **Enhanced Contrast:** Slightly brighter ridges for visibility

**Files:**
```
fast_transport_belt_north_001.png → fast_transport_belt_north_016.png
fast_transport_belt_east_001.png → fast_transport_belt_east_016.png
fast_transport_belt_south_001.png → fast_transport_belt_south_016.png
fast_transport_belt_west_001.png → fast_transport_belt_west_016.png
```

---

## 💨 Express Transport Belt Variations

### Visual Differences from Transport Belt
- **Accent Color:** Blue highlights (#00BFFF) on ridge edges
- **Dynamic Effects:** Optional subtle glow or particle effects
- **Same Animation Pattern:** Identical movement to transport belt
- **Enhanced Visibility:** More prominent ridges for high-speed appearance

**Files:**
```
express_transport_belt_north_001.png → express_transport_belt_north_016.png
express_transport_belt_east_001.png → express_transport_belt_east_016.png
express_transport_belt_south_001.png → express_transport_belt_south_016.png
express_transport_belt_west_001.png → express_transport_belt_west_016.png
```

---

## 🎯 Detailed Ridge Pattern Specification

### Base Ridge Pixel Coordinates (Frame 001)
Each ridge consists of 3 pixels in a diagonal line:

```
Ridge 1: (x,y) coordinates
- Pixel A: (0, 0) - Top-left of ridge
- Pixel B: (1, 1) - Middle of ridge
- Pixel C: (2, 2) - Bottom-right of ridge

Ridge 2: (x,y) coordinates
- Pixel A: (6, 0)
- Pixel B: (7, 1)
- Pixel C: (8, 2)

Ridge 3: (x,y) coordinates
- Pixel A: (12, 0)
- Pixel B: (13, 1)
- Pixel C: (14, 2)

Ridge 4: (x,y) coordinates
- Pixel A: (18, 0)
- Pixel B: (19, 1)
- Pixel C: (20, 2)

Ridge 5: (x,y) coordinates
- Pixel A: (24, 0)
- Pixel B: (25, 1)
- Pixel C: (26, 2)

Ridge 6: (x,y) coordinates
- Pixel A: (30, 0)
- Pixel B: (31, 1)
- Pixel C: (31, 2) [wrapped to right edge]
```

### Color Values
- **Background:** #333333 (RGB: 51, 51, 51)
- **Ridge Base:** #666666 (RGB: 102, 102, 102)
- **Fast Belt Accent:** #FFD700 (RGB: 255, 215, 0)
- **Express Belt Accent:** #00BFFF (RGB: 0, 191, 255)

---

## 🔧 Technical Implementation Notes

### Seamless Looping
- **Frame 16** must exactly match **Frame 1** when shifted 32 pixels
- **Y-wraparound:** When ridges reach y=32, they wrap to y=0
- **X-wraparound:** When ridges reach x=32, they wrap to x=0

### Animation Speed Control
- **Transport Belt:** 8 FPS (120ms per frame)
- **Fast Belt:** 10 FPS (100ms per frame)
- **Express Belt:** 12 FPS (83ms per frame)

### File Organization
```
/belts/
├── transport/
│   ├── north/
│   │   ├── transport_belt_north_001.png
│   │   ├── transport_belt_north_002.png
│   │   └── ...
│   ├── east/
│   ├── south/
│   └── west/
├── fast/
│   └── [same structure as transport]
└── express/
    └── [same structure as transport]
```

### Quality Assurance
- **Seamless Loop Test:** Frame 16 + 2px shift should match Frame 1
- **Direction Consistency:** All directions should have consistent visual speed
- **Color Accuracy:** Exact RGB values for belt type differentiation
- **Transparency:** Clean edges with no artifacts

---

## 📊 Animation Frame Summary

| Frame | North (↑) | East (→) | South (↓) | West (←) |
|-------|-----------|----------|-----------|----------|
| 001   | Base      | Base     | Base      | Base     |
| 002   | ↑2px      | →2px     | ↓2px      | ←2px     |
| 003   | ↑4px      | →4px     | ↓4px      | ←4px     |
| ...   | ...       | ...      | ...       | ...      |
| 016   | ↑30px     | →30px    | ↓30px     | ←30px    |

**Total Movement:** 32 pixels (2px × 16 frames = seamless loop)

---

## 🎨 Visual Reference

### Transport Belt Pattern Example (ASCII)
```
Frame 001 (North):
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░▒▒░░░░░░░░▒▒░░░░░░░░▒▒░░░░
░░░░░░░░▒▒░░░░░░░░▒▒░░░░░░░░▒▒░░
░░░░░░▒▒░░░░░░░░▒▒░░░░░░░░▒▒░░░░
░░░░░░░░▒▒░░░░░░░░▒▒░░░░░░░░▒▒░░
░░░░░░▒▒░░░░░░░░▒▒░░░░░░░░▒▒░░░░
```

Where:
- ░ = Background (#333333)
- ▒ = Ridge pixels (#666666)

This specification provides everything needed to create professional, seamless belt animations for FactoryForge! 🚀🎨
