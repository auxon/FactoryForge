## Drag Operations

### Item Transfer (Inventory ↔ Machines)

Drag operations allow transferring items between player inventory and machine slots:

#### Starting a Drag

1. **Inventory Drag**: Player touches and drags an item from the inventory UI
2. **State Tracking**: `InventoryUI` tracks the dragged item stack and original slot
3. **Visual Feedback**: A drag preview follows the finger/mouse cursor

#### Drop Targets

1. **Machine Slots**: Dragging over empty input/output slots in `MachineUI`
2. **Trash**: Dragging over the trash can in inventory to delete items
3. **Validation**: Drop targets validate if the item can be placed there

#### Completion

1. **Successful Transfer**: Item moves from source to destination
2. **Inventory Update**: Player inventory is updated
3. **Audio Feedback**: Click sound plays on successful transfer

### Belt/Pole Placement

For construction mode belt/pole placement:

1. **Start Placement**: Tap to set the starting tile
2. **Drag Preview**: Dragging shows a preview path of where belts/poles will be placed
3. **Path Calculation**: System calculates optimal path following placement rules
4. **Live Placement**: Entities are placed along the drag path
5. **End Placement**: Final tap or drag end completes the placement
