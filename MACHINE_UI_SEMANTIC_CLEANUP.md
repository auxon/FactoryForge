# MachineUI Semantic Cleanup - Final Fixes

## Status: Structurally Correct, Semantically Over-Expressive → Fixed

The UI is now **structurally coherent** but was still **semantically over-expressive**. These fixes remove redundant explanatory artifacts.

---

## Fixes Applied

### 1. Disabled Recipe Details with Arrows ✅

**Problem:** `showRecipeDetails()` was showing arrows (→) and item previews between Ore and Output, which is semantically redundant when using schema layout.

**Fix:**
- Added check in `showRecipeDetails()` to return early if `currentSchema != nil`
- Added check in `recipeButtonTapped()` to skip calling `showRecipeDetails()` when using schema
- Updated `clearRecipeDetails()` to ensure details stay cleared when using schema

**Result:** No more arrows or transformation previews when using schema. The left-to-right group layout (Fuel → Ore → Smelting → Output) already makes flow implicit.

---

### 2. Process Container is Now Minimal ✅

**Problem:** Process container could potentially contain transformation previews or arrows.

**Fix:**
- `buildProcess()` now only creates:
  - Process label ("Smelting")
  - Progress bar
- Explicitly documented that flow glyphs are NOT rendered (per spec: "Operators are optional and must be muted or omitted once flow is implicit")
- Added proper padding and constraints

**Result:** Process container is clean and focused - just shows process state (label + progress), not recipe explanations.

---

### 3. Flow Glyphs Intentionally Omitted ✅

**Problem:** Schema has `operators.showFlowGlyphs: true`, but rendering them would be redundant.

**Fix:**
- Process builder explicitly does NOT render flow glyphs
- Added comment explaining: "The left-to-right group layout already makes flow implicit. Adding arrows would be semantically redundant."

**Result:** No arrows between groups. Flow is implicit through layout.

---

## What the UI Now Shows (Spec-Compliant)

### Groups (Containers with Headers)
- ✅ **Fuel** - Contains fuel slot, shows "(empty)" when empty
- ✅ **Ore** - Contains ore slot, shows "(insert ore)" when empty  
- ✅ **Output** - Contains output slot, shows "(idle)" when empty
- ✅ **Smelting** - Process container with label and progress bar only

### Process
- ✅ Label: "Smelting"
- ✅ Progress bar: Inside Smelting container, below label
- ✅ No arrows
- ✅ No transformation previews
- ✅ No item icons

### Recipes Panel
- ✅ Title: "Available Recipes"
- ✅ Recipe buttons with textures
- ✅ No recipe details/arrows
- ✅ Pure selector functionality

---

## Semantic Rules Enforced

1. **One concept → one place**
   - Flow is shown through layout (left-to-right), not arrows
   - Process state is shown in Process container, not in recipe details
   - Empty states are in groups, not global

2. **No redundant explanations**
   - No arrows when flow is implicit
   - No transformation previews when groups show the flow
   - No recipe details when Recipes panel exists

3. **Process owns progress**
   - Progress bar is inside Process container
   - Progress bar is below Process label
   - No floating progress bars

---

## Remaining Work (If Any)

The UI should now be:
- ✅ Structurally correct (groups, containers, headers)
- ✅ Semantically minimal (no redundant explanations)
- ✅ Spec-compliant (one concept per place)

If there are still visual issues, they're likely:
- Layout/spacing tweaks (not semantic problems)
- Color/styling preferences (not structural problems)
- Missing functionality (not cleanup problems)

---

## Testing Checklist

- [x] No arrows between groups when using schema
- [x] No recipe details (item previews) when using schema
- [x] Process container only has label + progress bar
- [x] Progress bar is inside Process container
- [x] Recipe details are disabled when schema exists
- [x] Flow is implicit through left-to-right layout

---

## Notes

The schema's `operators.showFlowGlyphs: true` is intentionally ignored because:
- Flow is already implicit from group positioning
- Adding arrows would be semantically redundant
- Per spec: "Operators are optional and must be muted or omitted once flow is implicit"

This is the correct interpretation of the spec.
