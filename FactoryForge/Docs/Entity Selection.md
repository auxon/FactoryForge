# Entity Selection

This document describes how entity selection works in FactoryForge, including tap-based selection and drag operations.

## Tap-Based Entity Selection

### Single Entity Selection

When a player taps on the game world:

1. **Tap Detection**: `InputManager.handleTap()` receives the screen tap coordinates
2. **UI Priority**: The tap is first offered to any open UI panels (inventory, machine UI, etc.)
3. **World Position**: If no UI consumes the tap, screen coordinates are converted to world coordinates
4. **Entity Detection**: The system finds all interactable entities (machines, belts, inserters, etc.) at the tap location
5. **Selection Logic**:
   - **Single Entity**: If only one entity exists at the position, it is selected immediately
   - **Multiple Entities**: If multiple entities exist, the `EntitySelectionDialog` is displayed

### EntitySelectionDialog

When multiple entities exist at a tap location, a selection dialog appears showing all available entities:

1. **Dialog Display**: A grid of entity icons is shown, with up to 3 columns
2. **Entity Icons**: Each entity is represented by its appropriate texture (machines show their type, belts show directional sprites)
3. **Selection**: Player taps on the desired entity icon
4. **Callback Execution**: The selected entity's callback is executed, setting it as the game's `selectedEntity`
5. **Dialog Closure**: The dialog closes after a brief delay (0.1s) to prevent tap passthrough

### Selection Effects

When an entity is selected:

1. **InputManager State**: `selectedEntity` property is set to the chosen entity
2. **HUD Update**: The HUD reflects the selection (entity outline, info display)
3. **Tooltip Display**: Entity information tooltip appears
4. **Game State**: The selected entity becomes the target for subsequent operations

## Inserter Connection Mode

When configuring inserter input/output connections:

1. **Mode Activation**: Enter inserter connection mode for a specific inserter
2. **Target Selection**: Tap or drag to select target entities/belts
3. **Connection Logic**: System determines valid connection points
4. **Multiple Targets**: If multiple valid targets exist at the selection point, `EntitySelectionDialog` may appear
5. **Connection Establishment**: Selected entity becomes the inserter's input/output target

## Technical Implementation

### Key Classes

- **InputManager**: Handles tap/drag input, entity detection, selection logic
- **EntitySelectionDialog**: UI component for multi-entity selection
- **InventoryUI**: Manages inventory drag operations
- **MachineUI**: Handles machine slot drag targets
- **UISystem**: Coordinates UI panel interactions

### Selection Flow

```
Tap Event → InputManager.handleTap()
    ↓
UI Panels Check → Entity Detection
    ↓
Single Entity? → Direct Selection
    ↓
Multiple Entities → EntitySelectionDialog
    ↓
User Selection → Callback → selectedEntity Update
```

### Drag Flow

```
Touch Start → Drag Detection → UI Element Check
    ↓
Inventory/Machine UI → Handle Drag
    ↓
Valid Drop Target? → Transfer Item
    ↓
Update Inventories → Audio Feedback
```