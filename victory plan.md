[10 tools called]

Based on my analysis of the FactoryForge codebase, here's my plan for implementing victory status updates with fireworks particle animations when Space Science Packs are generated from rocket launches:

## **Victory System Plan**

### **1. Victory Detection & Triggering**
- **Location**: Modify `RocketSystem.generateSpaceSciencePacks()` in `RocketSystem.swift`
- **Trigger**: Detect when the first Space Science Pack is generated (when `generateSpaceSciencePacks()` is called)
- **Victory State**: Add victory tracking to `GameLoop` class with a `isVictoryAchieved` boolean flag
- **Research Check**: Ensure player has completed all required space science research before declaring victory

### **2. Victory Status UI Overlay**
- **New Component**: Create `VictoryUI` panel (similar to existing UI panels)
- **Content**: 
  - "🚀 VICTORY! Space Science Achieved!" header
  - Statistics: Time played, rockets launched, final space science pack count
  - "Return to Menu" button
- **Visual**: Large overlay covering most of screen with celebratory styling
- **Integration**: Add to `UISystem` and show when victory is triggered

### **3. Fireworks Particle Animation System**
- **New Method**: Add `spawnFireworks(at position: Vector2)` to `ParticleRenderer.swift`
- **Fireworks Characteristics**:
  - **Multiple Bursts**: 3-5 simultaneous explosions at different heights
  - **Colors**: Red, blue, green, yellow, purple bursts (randomly selected)
  - **Duration**: 3-5 seconds total with cascading effects
  - **Position**: Centered around the rocket silo that generated the packs
  - **Scale**: Large particles (size 0.5-1.0) for visibility
- **Implementation**: Use existing `ParticleEmitter` system with custom config for fireworks behavior

### **4. Victory Sequence Flow**
1. Rocket reaches space → `generateSpaceSciencePacks()` called
2. Check if victory conditions met (space science research completed)
3. If yes: Set `GameLoop.isVictoryAchieved = true`
4. Trigger fireworks: `renderer.particleRenderer.spawnFireworks(at: siloPosition)`
5. Show victory UI overlay via `UISystem`
6. Pause game and display celebration

### **5. Technical Details**
- **Particle Config**: Extend `ParticleEmitterConfig` or create fireworks-specific method
- **Audio**: Optionally play victory sound effect (reuse existing audio system)
- **Save State**: Ensure victory state persists in save files
- **Performance**: Fireworks should be GPU-efficient (reuse existing particle system)

## **Questions for Clarification:**

1. **Victory Conditions**: Should victory trigger on the *first* space science pack generation, or when the player has enough packs to complete space science research?

2. **Fireworks Positioning**: Should fireworks spawn around the specific rocket silo that launched the satellite, or at the center of the screen?

3. **Victory Persistence**: Should the victory screen persist until manually dismissed, or auto-dismiss after fireworks?

4. **Space Science Requirements**: Looking at the quickstart, it mentions "1000 space science packs generated automatically from successful launches." Is there a specific research that requires these packs?

5. **Audio**: Should we include victory sound effects, or just visual effects?

Let me know your preferences and I'll implement the system!