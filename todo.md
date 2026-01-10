# FactoryForge TODO List

This document contains a comprehensive list of major issues identified in the FactoryForge codebase that need to be addressed for improved stability, performance, and user experience.

## Critical Issues

### Memory & Resource Management
- [ ] **memory_leaks_ui_panels**: Fix potential memory leaks in UI panels - close() methods should properly clean up all references and remove UIKit labels from superview
- [ ] **itemstack_negative_count**: Fix ItemStack.isEmpty property - count can become negative, causing incorrect empty state

### Safety & Validation
- [ ] **bounds_checking_inventory**: Add bounds checking in InventoryUI drag operations to prevent crashes when accessing arrays with invalid indices
- [ ] **inventory_validation**: Add validation to prevent negative item counts and handle overflow in inventory operations
- [ ] **inventory_remove_validation**: Add validation in InventoryComponent.remove() to prevent negative item counts
- [ ] **inventory_slot_bounds_crash**: Fix potential crash in inventory drag operations when slotIndex is out of bounds
- [ ] **input_validation**: Add proper input validation to prevent invalid game states (negative resources, impossible crafting, etc.)

### Error Handling
- [ ] **save_load_error_handling**: Implement proper error handling for save/load operations - currently no user feedback for failures
- [ ] **texture_loading_error_handling**: Implement proper error recovery for failed texture loading in MetalRenderer

### Performance & Threading
- [ ] **thread_safety**: Implement proper thread safety for game state access - UI and game loop may access data simultaneously
- [ ] **performance_monitoring**: Add performance monitoring and optimization for large factory layouts with many entities
- [ ] **game_pause_resume**: Implement proper game pause/resume functionality for when panels are open

### UI/UX Issues
- [ ] **research_cost_display_bug**: Fix inconsistent research cost display - some technologies show costs twice or incorrectly
- [ ] **accessibility_support**: Add accessibility support for screen readers and keyboard navigation in UI panels
- [ ] **division_by_zero**: Fix potential division by zero in math calculations and UI scaling operations

### Code Quality & Testing
- [ ] **logging_system**: Add comprehensive logging system for debugging and error tracking
- [ ] **code_organization**: Review and fix inconsistent naming conventions across the codebase
- [ ] **unit_tests**: Add unit tests for critical game systems (inventory, crafting, research, etc.)
- [ ] **rendering_optimization**: Optimize Metal rendering for better performance on lower-end devices

## Implementation Notes

- Each TODO item includes a unique ID for easy reference
- Items are prioritized by criticality (memory leaks, crashes, etc. at the top)
- Some items may have dependencies (e.g., thread safety should be addressed before performance monitoring)
- Consider implementing automated tests alongside fixes where possible
- Performance improvements should include benchmarking before and after changes

## Progress Tracking

Use this format to track progress on each item:
- [ ] Not started
- [x] Completed
- [WIP] Work in progress

## Testing Checklist

For each fix, verify:
- No crashes occur under normal usage
- Performance hasn't regressed
- UI/UX remains consistent
- Save/load functionality works correctly
- Memory usage is reasonable
- Thread safety is maintained