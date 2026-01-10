# MachineUI Updates

## Overview
The MachineUI has been significantly refactored and enhanced to support rocket silo interactions. The changes include major code simplification, improved UI structure, and new rocket launch functionality.

## Key Changes Summary
- **Total Changes**: 853 lines modified (168 insertions, 685 deletions)
- **Major Refactoring**: Simplified and cleaned up the UI code structure
- **New Feature**: Added rocket silo launch button and functionality
- **Improved Architecture**: Better separation of concerns and cleaner code organization

## Detailed Changes

### 1. Added Rocket Silo Support
- **New Property**: `launchButton: UIButton?` - Button for launching rockets from silos
- **New Callback**: `onLaunchRocket: ((Entity) -> Void)?` - Callback when rocket launch is initiated
- **New Helper Property**: `isRocketSilo` - Computed property to check if current machine is a rocket silo

### 2. Rocket Launch UI Implementation
- **setupRocketLaunchButton()**: Creates and configures the launch button with proper styling and positioning
- **updateLaunchButtonState()**: Dynamically updates button appearance based on silo state:
  - Green "🚀 LAUNCH ROCKET" when ready to launch
  - Gray "⏳ LAUNCHING..." during launch sequence
  - Gray "⚠️ ASSEMBLE ROCKET" when rocket not assembled
- **launchRocketPressed()**: Objective-C method that triggers the launch callback

### 3. UI State Management
- **Enhanced open() method**: Now conditionally adds rocket launch button for rocket silos
- **Enhanced close() method**: Properly removes rocket launch button and cleans up UI state

### 4. Code Structure Improvements
- **Simplified slot setup**: Cleaner organization of input/output slots
- **Better label management**: Improved count label positioning and styling
- **Removed redundant code**: Eliminated duplicate UI setup and styling code
- **Improved readability**: More concise and maintainable code structure

### 5. Integration with Game Systems
- **RocketSystem integration**: Connects UI button to the rocket launch system
- **Inventory checking**: Validates rocket components before enabling launch
- **State synchronization**: Button state reflects actual game state (launching, assembled, etc.)

## Technical Details

### Button States
The launch button dynamically changes based on rocket silo conditions:
- **Enabled + Green**: Rocket assembled and not currently launching
- **Disabled + Gray**: Either launching or rocket not assembled
- **Error State**: If silo components are missing or invalid

### UI Layout
- **Input/Output Slots**: Positioned at ±200 units from center (increased from ±150) to provide more space for recipe buttons
- **Count Labels**: Repositioned relative to slot locations for proper alignment
- **Recipe Buttons**: Properly centered horizontally using corrected spacing calculation: `startX = center - ((buttonsPerRow - 1) × (buttonSize + spacing) + buttonSize) / 2`
- **Rocket Launch Button**: Positioned below the main machine interface, centered horizontally with 200x50 pixel dimensions using system green color scheme

### Callback Integration
The machine UI integrates with multiple callback systems:
- `onLaunchRocket` callback triggers rocket launch logic in `RocketSystem`
- `onClosePanel` callback allows closing the panel by tapping anywhere in empty space (inside or outside panel bounds)
- `onOpenInventoryForMachine` callback handles inventory slot interactions
- Button state updates after launch attempts
- UI closes automatically after successful launch or when tapping in non-interactive areas

## Files Modified
- `FactoryForge/UI/MachineUI.swift` - Major refactoring and rocket silo support
- `FactoryForge/UI/UISystem.swift` - Integration with rocket launch callbacks
- `FactoryForge/Game/Systems/RocketSystem.swift` - Launch logic implementation
- `FactoryForge/Engine/Core/GameLoop.swift` - Building component setup

## Benefits
1. **Enhanced Gameplay**: Players can now launch rockets directly from the machine UI
2. **Better UX**: Clear visual feedback on launch readiness and status
3. **Cleaner Code**: Simplified and more maintainable UI architecture
4. **Modular Design**: Rocket functionality is properly separated and integrated
5. **Consistent Styling**: Launch button follows iOS design guidelines

## Implementation Notes
The MachineUI refactoring introduced several compilation errors that were subsequently fixed:

### Issues Resolved:
1. **InventorySlot Constructor**: Removed invalid `isInput` parameter
2. **Missing addChild Method**: Replaced with direct rendering of UI elements
3. **Type Conversion Errors**: Fixed Float/CGFloat conversions for UIKit labels
4. **RecipeButton Constructor**: Removed invalid `gameLoop` parameter
5. **UIKit UIButton Usage**: Replaced with custom UIButton from UI system
6. **Invalid Property Access**: Removed non-existent `isEnabled` and `slotIndex` properties
7. **Missing Render Method**: Added comprehensive render method for all UI elements
8. **Missing Tap Handling**: Added handleTap method for interactive elements
9. **Layout Overlap**: Moved input slots further left (-200) and output slots further right (+200) to prevent overlap with recipe buttons
10. **Button Centering**: Fixed recipe button centering formula to properly account for spacing (no spacing after last button)
11. **Panel Closing**: Enhanced tap handling to close machine UI when tapping in empty space (anywhere not on interactive elements)
12. **Tap Handling**: Fixed issue where taps were not detected after closing MachineUI by allowing taps to proceed to HUD when panels close themselves during tap handling
13. **EntitySelectionDialog**: Fixed tap consumption issues by making entity selection synchronous and ensuring taps outside dialog properly close it
14. **HUD Tap Handling**: Removed redundant panel state check that was preventing HUD taps after closing panels
15. **Panel State Management**: Fixed activePanel state not being cleared when panels close themselves via close buttons
16. **Smart Slot Interaction**: Implemented intelligent slot tapping - occupied slots return items to inventory, empty input slots open inventory for item selection; added proper handling for partial item transfers when inventory is full; integrated with existing tooltip system for user feedback
17. **Adaptive Slot Display**: Implemented dynamic slot creation that shows only the relevant number of slots for each machine - 1-slot machines show 1 slot, 4-slot machines show 4 slots, etc.
18. **Centrifuge Enhancement**: Increased centrifuge inventory slots from 2 to 4 and moved uranium processing recipes to use centrifuging category for proper nuclear fuel production
19. **Count Labels**: Restored stack count labels for machine inventory slots, positioned at bottom-right corner of each slot showing counts > 1

### Architecture Changes:
- **UI Element Management**: Elements are stored in arrays and rendered directly in the panel's render method
- **Event Handling**: Tap events are handled by the panel and delegated to child elements
- **Rocket Launch UI**: Custom UIButton with onTap callback instead of UIKit target-action pattern
- **State Management**: Button states managed through `isEnabled` and `label` properties

## Future Considerations
- Could add launch progress visualization
- Could add sound effects for launch feedback
- Could add animation effects for rocket launch sequence
- Could add launch history or statistics display