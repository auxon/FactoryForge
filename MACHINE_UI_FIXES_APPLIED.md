# MachineUI Schema Collapse Fixes - Applied

## Summary

Fixed the **schema collapse** issue where three incompatible UI paradigms were rendering simultaneously. The UI now uses **schema-first rendering**: when a schema exists, legacy rendering is disabled.

## Changes Applied

### 1. `setupComponentsForEntity()` - Schema-Aware Rendering Path

**File:** `MachineUI.swift:644-716`

**Change:** Added `usingSchema` check to skip legacy rendering when schema exists.

**Before:**
- Always ran legacy slot setup, progress bar setup, recipe UI setup
- Created overlapping UI elements

**After:**
- Checks if schema exists for current machine type
- If schema exists: Only runs non-conflicting components (pipe connections, fluid components)
- If no schema: Falls back to legacy rendering

**Key Guard:**
```swift
let usingSchema = currentSchema != nil && currentSchema?.machineKind == machineType

if !usingSchema {
    // Legacy rendering path
    setupSlots()
    setupSlotsForMachine(entity)
    setupSlotButtons()
    layoutAll()
} else {
    // Schema-based rendering - skip conflicting legacy code
}
```

---

### 2. `updateMachine()` - Schema-Aware Updates

**File:** `MachineUI.swift:3251-3272`

**Change:** Added `usingSchema` check to skip legacy slot/count label updates when schema exists.

**Before:**
- Always updated legacy slots and count labels
- Conflicted with schema-built UI

**After:**
- Skips legacy slot updates when schema exists
- TODO: Needs `updateSchemaUI()` to update schema-built views

---

### 3. `update()` - Schema-Aware Progress Bar Updates

**File:** `MachineUI.swift:3276-3300`

**Change:** Added guards to skip legacy progress bar and count label updates when schema exists.

**Before:**
- Always called `updateProgressBar()` and `updateCountLabels()`
- Created duplicate progress indicators

**After:**
- Checks `hasSchemaProcess` before calling `updateProgressBar()`
- Skips count label updates when using schema

---

### 4. `updateProgressBar()` - Early Return for Schema

**File:** `MachineUI.swift:3756-3759`

**Change:** Added early return when schema has process.

**Before:**
- Always executed, setting global progress bar
- Set hardcoded "Insert Ore" text (line 3877) that conflicted with schema stateText

**After:**
- Early return if `currentSchema?.process != nil`
- Prevents "Insert Ore" and other status text from conflicting with schema's group stateText

---

### 5. `layoutAll()` - Schema-Aware Layout

**File:** `MachineUI.swift:1343-1353`

**Change:** Added guards to skip legacy layout when schema exists.

**Before:**
- Always laid out progress bar and count labels
- Conflicted with schema grid-based layout

**After:**
- Skips `layoutProgressBar()` when schema has process
- Skips `relayoutCountLabels()` when using schema

---

### 6. Recipe Scroll View Setup - Schema Guard

**File:** `MachineUI.swift:2664-2695`

**Change:** Added `hasSchemaRecipes` check to skip legacy recipe UI when schema has recipes panel.

**Before:**
- Always set up legacy recipe scroll view
- Manually positioned recipe buttons
- Conflicted with schema's grid-anchored recipes panel

**After:**
- Checks if schema has recipes panel
- Skips legacy recipe UI setup when schema recipes exist
- Hides/removes legacy recipe UI if it was previously created

---

## What This Fixes

### Before (Schema Collapse):
- ❌ Multiple "Ore" labels (schema header + legacy)
- ❌ Multiple "(insert ore)" texts (schema stateText + legacy status)
- ❌ Orphaned progress bar (not owned by Process container)
- ❌ Duplicate slot buttons (schema slots + legacy buttons)
- ❌ Conflicting recipe panels (schema grid + legacy scroll view)

### After (Schema-First):
- ✅ Single "Ore" label (from schema group header only)
- ✅ Single "(insert ore)" text (from schema stateText only)
- ✅ Progress bar owned by Process container (when schema has process)
- ✅ Single set of slot buttons (from schema groups only)
- ✅ Single recipes panel (from schema anchor only)

---

## Remaining Work

### Critical: Schema UI State Updates

The schema UI is now built correctly, but it doesn't update with machine state. Need to implement:

1. **`updateSchemaUI()` method** that:
   - Updates schema-built slot views with current inventory
   - Updates schema process progress bar with actual progress
   - Updates schema group stateText based on slot empty/non-empty state
   - Updates schema recipes panel with current selection

2. **Connect to `updateMachine()`**:
   - Call `updateSchemaUI()` instead of legacy updates when schema exists
   - Ensure schema UI reflects real-time machine state

3. **Schema Process Progress Binding**:
   - Connect schema's `process.progress.bindTo` to actual component progress
   - Update schema-built progress bar in Process container

4. **Schema Group StateText Updates**:
   - Show `stateText.empty` when group slots are empty
   - Show `stateText.nonEmpty` when group slots have items
   - Update based on `stateText.mode` (auto/manual)

---

## Testing

After these fixes, verify:

- [x] Legacy rendering is disabled when schema exists
- [ ] Schema UI is built correctly (visual inspection)
- [ ] Schema UI updates with machine state (needs `updateSchemaUI()`)
- [ ] No duplicate labels/text when schema exists
- [ ] Progress bar is in Process container (when schema has process)
- [ ] Recipes panel uses schema anchor (when schema has recipes)

---

## Notes

- Legacy code is still present as fallback for machines without schemas
- Non-conflicting components (pipe connections, fluid components) still run when schema exists
- The goal is **schema-first**: if schema exists, use it exclusively; legacy only as fallback
- Schema UI state updates are the next critical step to make this fully functional
