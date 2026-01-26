# MachineUI Kill List: Elements to Remove/Disable

This document identifies all code that must be **disabled or removed** when using the formal MachineUI schema to prevent semantic duplication and visual overlap.

## Core Problem

When `applySchema()` is called, it builds the formal schema-based UI. However, `setupComponentsForEntity()` continues to execute legacy rendering code, creating **three overlapping UI layers**:

1. **Formal Schema UI** (from `MachineUIBuilder`)
2. **Legacy Slot-Based UI** (from `setupSlotButtons()`, `layoutAll()`)
3. **Legacy Progress/State UI** (from `updateProgressBar()`, `layoutProgressBar()`)

## Kill List: Code to Disable When Schema Exists

### 1. Legacy Slot Button Rendering

**Location:** `MachineUI.swift:710-712`
```swift
// Set up UIKit slot buttons and layout
clearSlotUI()
setupSlotButtons()
layoutAll()
```

**Action:** Guard with `if currentSchema == nil` check

**Why:** Schema's `MachineUIBuilder.buildGroup()` already creates slot containers. Legacy `setupSlotButtons()` creates duplicate floating buttons.

---

### 2. Legacy Progress Bar Layout

**Location:** `MachineUI.swift:1349-1396` (`layoutProgressBar()`)

**Action:** Skip when `currentSchema?.process != nil`

**Why:** Schema's `buildProcess()` already creates progress bars inside Process containers. Legacy progress bar is orphaned and conflicts.

---

### 3. Legacy Progress Bar Updates

**Location:** `MachineUI.swift:3689-3833` (`updateProgressBar()`)

**Action:** Skip when `currentSchema?.process != nil`

**Why:** Schema process should own its progress. Legacy `updateProgressBar()` sets global progress bar that conflicts with schema's process.progress.

**Specific conflicts:**
- Line 3812: `statusText = "Insert Ore"` — duplicates schema's `group.content.stateText.empty`
- Line 3799: `statusText = String(format: "\(label): %.0f%%", p * 100)` — duplicates process label

---

### 4. Legacy State Text Rendering

**Location:** `MachineUI.swift:3812` (hardcoded "Insert Ore")

**Action:** Remove entirely when schema has `group.content.stateText`

**Why:** Schema's `buildStateLabel()` already renders state text inside groups. Legacy status text is global and duplicates group-level state.

---

### 5. Legacy Recipe Scroll View Setup

**Location:** `MachineUI.swift:2637-2657` (recipe scroll view setup)

**Action:** Skip when `currentSchema?.recipes != nil`

**Why:** Schema's `buildRecipesPanel()` already creates recipes panel. Legacy recipe UI is manually positioned and conflicts.

---

### 6. Legacy Slot Setup Methods

**Location:** `MachineUI.swift:689-691`
```swift
setupSlots()
setupSlotsForMachine(entity)
```

**Action:** Guard with `if currentSchema == nil`

**Why:** These are Metal-based slot renderers that conflict with schema's UIKit-based slots.

---

### 7. Legacy Component Setup (Partial)

**Location:** `MachineUI.swift:694-696`
```swift
for (_, component) in machineComponents.enumerated() {
    component.setupUI(for: entity, in: self)
}
```

**Action:** Only run for non-schema components (pipe connections, etc.). Skip slot/progress components when schema exists.

**Why:** Some components (like pipe connections) are still needed, but slot/progress components conflict with schema.

---

## Implementation Status

### Phase 1: Stop Legacy Rendering ✅ COMPLETED
1. ✅ Guarded `setupSlotButtons()` and `layoutAll()` when schema exists (in `setupComponentsForEntity`)
2. ✅ Guarded `updateProgressBar()` when schema has process (early return in `updateProgressBar()` and guard in `update()`)
3. ✅ Guarded recipe scroll view setup when schema has recipes (in `open()` method)
4. ✅ Guarded legacy slot setup methods (`setupSlots()`, `setupSlotsForMachine()`) when schema exists
5. ✅ Guarded legacy count label updates when schema exists

### Phase 2: Connect Schema to State Updates ⚠️ PENDING
4. ⚠️ TODO: Create `updateSchemaUI()` method that updates schema-built views with current machine state
5. ⚠️ TODO: Call `updateSchemaUI()` from `updateMachine()` instead of legacy update methods
6. ⚠️ TODO: Connect schema process progress bar to actual machine progress
7. ⚠️ TODO: Connect schema group stateText to actual machine state (empty/non-empty)

### Phase 3: Remove Dead Code (After Validation)
6. Remove or comment out unused legacy rendering paths
7. Consolidate state update logic into schema-aware methods

---

## Schema-Aware Rendering Contract

When `currentSchema != nil`, the following must be true:

1. **Groups own their slots** — No floating slot buttons outside group containers
2. **Process owns its progress** — No global progress bar
3. **Groups own their state text** — No global "Insert Ore" or status labels
4. **Recipes panel is schema-driven** — No manual recipe scroll view positioning
5. **Grid is authoritative** — All positioning comes from `Anchor` grid coordinates

---

## Testing Checklist

After applying fixes, verify:

- [ ] Only one "Ore" label appears (from schema group header)
- [ ] Only one "(insert ore)" text appears (from schema stateText)
- [ ] Progress bar is inside Process container, not floating
- [ ] Recipes panel uses schema anchor, not manual positioning
- [ ] No duplicate slot buttons (schema slots only)
- [ ] State updates work (schema UI reflects machine state)

---

## Notes

- Some legacy code may still be needed for machines without schemas (fallback path)
- Pipe connections and other non-schema components may still need legacy setup
- The goal is **schema-first**: if schema exists, use it exclusively; legacy only as fallback
