import Foundation

/// The game world containing all entities and their components
final class World {
    private let entityManager = EntityManager()
    private var componentStores: [ObjectIdentifier: AnyComponentStore] = [:]
    
    /// Spatial index for quick position-based lookups
    private var spatialIndex: [IntVector2: Entity] = [:]
    
    /// Event queue for deferred entity operations
    private var pendingSpawns: [(Entity, [any Component])] = []
    private var pendingDespawns: [Entity] = []
    
    // MARK: - Entity Management
    
    /// Spawns a new entity
    func spawn() -> Entity {
        return entityManager.create()
    }
    
    /// Spawns a new entity with a builder
    func spawnWith() -> EntityBuilder {
        let entity = spawn()
        return EntityBuilder(entity: entity, world: self)
    }
    
    /// Despawns an entity
    func despawn(_ entity: Entity) {
        guard entityManager.isAlive(entity) else { return }
        
        // Remove from spatial index
        if let position = get(PositionComponent.self, for: entity) {
            spatialIndex.removeValue(forKey: position.tilePosition)
        }
        
        // Remove all components
        for (_, store) in componentStores {
            store.remove(entity)
        }
        
        entityManager.destroy(entity)
    }
    
    /// Queues an entity for deferred despawn
    func despawnDeferred(_ entity: Entity) {
        pendingDespawns.append(entity)
    }
    
    /// Processes all pending spawns and despawns
    func processPending() {
        for entity in pendingDespawns {
            despawn(entity)
        }
        pendingDespawns.removeAll()
    }
    
    /// Checks if an entity is alive
    func isAlive(_ entity: Entity) -> Bool {
        return entityManager.isAlive(entity)
    }
    
    /// All living entities
    var entities: Set<Entity> {
        return entityManager.entities
    }
    
    /// Number of entities
    var entityCount: Int {
        return entityManager.count
    }
    
    // MARK: - Component Management
    
    /// Adds a component to an entity
    func add<T: Component>(_ component: T, to entity: Entity) {
        // Special handling for PositionComponent: remove old position from spatial index
        if let oldPosition = get(PositionComponent.self, for: entity) {
            spatialIndex.removeValue(forKey: oldPosition.tilePosition)
        }

        let store = getOrCreateStore(for: T.self)
        store.set(component, for: entity)

        // Update spatial index for position components
        if let position = component as? PositionComponent {
            spatialIndex[position.tilePosition] = entity
        }
    }
    
    /// Gets a component from an entity
    func get<T: Component>(_ type: T.Type, for entity: Entity) -> T? {
        guard let store = componentStores[ObjectIdentifier(type)] as? ComponentStore<T> else {
            return nil
        }
        return store.get(entity)
    }
    
    /// Gets a mutable pointer to a component
    func getMutable<T: Component>(_ type: T.Type, for entity: Entity) -> UnsafeMutablePointer<T>? {
        guard let store = componentStores[ObjectIdentifier(type)] as? ComponentStore<T> else {
            return nil
        }
        return store.getMutable(entity)
    }
    
    /// Checks if an entity has a component
    func has<T: Component>(_ type: T.Type, for entity: Entity) -> Bool {
        guard let store = componentStores[ObjectIdentifier(type)] as? ComponentStore<T> else {
            return false
        }
        return store.has(entity)
    }
    
    /// Removes a component from an entity
    func remove<T: Component>(_ type: T.Type, from entity: Entity) {
        guard let store = componentStores[ObjectIdentifier(type)] as? ComponentStore<T> else {
            return
        }
        
        // Update spatial index for position components
        if type == PositionComponent.self, let position = store.get(entity) as? PositionComponent {
            spatialIndex.removeValue(forKey: position.tilePosition)
        }
        
        store.remove(entity)
    }
    
    // MARK: - Queries
    
    /// Queries entities with a specific component
    func query<T: Component>(_ type: T.Type) -> [Entity] {
        guard let store = componentStores[ObjectIdentifier(type)] as? ComponentStore<T> else {
            return []
        }
        return store.entities
    }
    
    /// Queries entities with two components
    func query<T1: Component, T2: Component>(_ type1: T1.Type, _ type2: T2.Type) -> [Entity] {
        guard let store1 = componentStores[ObjectIdentifier(type1)] as? ComponentStore<T1>,
              let store2 = componentStores[ObjectIdentifier(type2)] as? ComponentStore<T2> else {
            return []
        }

        let (primaryStore, secondaryStore) = store1.count <= store2.count
            ? (store1 as AnyComponentStore, store2 as AnyComponentStore)
            : (store2 as AnyComponentStore, store1 as AnyComponentStore)

        let primaryEntities: [Entity]
        if let typedStore1 = primaryStore as? ComponentStore<T1> {
            primaryEntities = typedStore1.entities
        } else if let typedStore2 = primaryStore as? ComponentStore<T2> {
            primaryEntities = typedStore2.entities
        } else {
            return []
        }

        var results: [Entity] = []
        results.reserveCapacity(primaryEntities.count)
        for entity in primaryEntities where secondaryStore.has(entity) {
            results.append(entity)
        }
        return results
    }
    
    /// Queries entities with three components
    func query<T1: Component, T2: Component, T3: Component>(
        _ type1: T1.Type, _ type2: T2.Type, _ type3: T3.Type
    ) -> [Entity] {
        guard let store1 = componentStores[ObjectIdentifier(type1)] as? ComponentStore<T1>,
              let store2 = componentStores[ObjectIdentifier(type2)] as? ComponentStore<T2>,
              let store3 = componentStores[ObjectIdentifier(type3)] as? ComponentStore<T3> else {
            return []
        }

        let stores: [(AnyComponentStore, [Entity])] = [
            (store1, store1.entities),
            (store2, store2.entities),
            (store3, store3.entities)
        ]
        guard let primary = stores.min(by: { $0.1.count < $1.1.count }) else {
            return []
        }

        let (primaryStore, primaryEntities) = primary
        let secondaryStores = stores.map { $0.0 }.filter { $0 !== primaryStore }

        var results: [Entity] = []
        results.reserveCapacity(primaryEntities.count)
        for entity in primaryEntities where secondaryStores.allSatisfy({ $0.has(entity) }) {
            results.append(entity)
        }
        return results
    }
    
    /// Iterates over all components of a type
    func forEach<T: Component>(_ type: T.Type, _ body: (Entity, inout T) -> Void) {
        guard let store = componentStores[ObjectIdentifier(type)] as? ComponentStore<T> else {
            return
        }
        store.forEach(body)
    }
    
    // MARK: - Spatial Queries
    
    /// Gets all entities at a tile position (doesn't prioritize, returns all matching entities)
    /// Includes entities at the exact position and multi-tile entities that overlap the position
    func getAllEntitiesAt(position: IntVector2) -> [Entity] {
        var allEntitiesAtPosition: [Entity] = []
        var checkedEntities: Set<Entity> = []

        // Check spatial index for the exact tile position
        if let entity = spatialIndex[position] {
            allEntitiesAtPosition.append(entity)
            checkedEntities.insert(entity)
        }

        // Check all entities with PositionComponent to find all entities at this position
        // This includes both single-tile entities (exact match) and multi-tile buildings (bounds check)
        let allEntitiesWithPosition = query(PositionComponent.self)
        // print("World: getAllEntitiesAt - checking \(allEntitiesWithPosition.count) entities with PositionComponent")
        
        for entity in allEntitiesWithPosition {
            guard !checkedEntities.contains(entity) else { continue }  // Skip already checked entities
            guard let pos = get(PositionComponent.self, for: entity) else { continue }

            let origin = pos.tilePosition
            
            // For single-tile entities (size 1x1), check exact position match
            // For multi-tile buildings, check if the target position is within bounds
            let sprite = get(SpriteComponent.self, for: entity)
            let width = sprite != nil ? Int32(ceil(sprite!.size.x)) : 1
            let height = sprite != nil ? Int32(ceil(sprite!.size.y)) : 1
            
            let hasInserter = has(InserterComponent.self, for: entity)
            let hasBelt = has(BeltComponent.self, for: entity)
            let hasFurnace = has(FurnaceComponent.self, for: entity)

            // Check if the tapped position matches exactly (for single-tile) or is within bounds (for multi-tile)
            let isExactMatch = (width == 1 && height == 1) && position.x == origin.x && position.y == origin.y
            let isWithinBounds = position.x >= origin.x && position.x < origin.x + width &&
                                 position.y >= origin.y && position.y < origin.y + height

            // Debug log entities at the target position
            if hasInserter || hasBelt || hasFurnace || isExactMatch || isWithinBounds {
                // print("World: getAllEntitiesAt - checking entity \(entity) at \(origin) (size \(width)x\(height)) - Inserter: \(hasInserter), Belt: \(hasBelt), Furnace: \(hasFurnace), isExactMatch: \(isExactMatch), isWithinBounds: \(isWithinBounds)")
            }

            if isExactMatch || isWithinBounds {
                allEntitiesAtPosition.append(entity)
                checkedEntities.insert(entity)
                // print("World: getAllEntitiesAt - added entity \(entity) at \(origin) to result list")
            }
        }
        
        // print("World: getAllEntitiesAt - returning \(allEntitiesAtPosition.count) entities")
        return allEntitiesAtPosition
    }
    
    /// Gets the entity at a tile position (checks exact match first, then checks if position is within any entity's bounds)
    /// Prioritizes buildings over belts and inserters
    func getEntityAt(position: IntVector2) -> Entity? {
        let allEntitiesAtPosition = getAllEntitiesAt(position: position)


        // If no entities found, return nil
        guard !allEntitiesAtPosition.isEmpty else { return nil }
        
        // If only one entity, return it
        if allEntitiesAtPosition.count == 1 {
            let entity = allEntitiesAtPosition[0]
            return entity
        }

        // Multiple entities - prioritize buildings over belts/inserters/poles
        // print("World: getEntityAt(\(position)) - found \(allEntitiesAtPosition.count) entities")
        // Priority order: Production buildings > Inserters > Power poles > Belts > Others

        // First, try to find a production building (entity with building-specific components, excluding poles)
        for entity in allEntitiesAtPosition {
            if has(FurnaceComponent.self, for: entity) ||
               has(AssemblerComponent.self, for: entity) ||
               has(MinerComponent.self, for: entity) ||
               has(GeneratorComponent.self, for: entity) ||
               has(ChestComponent.self, for: entity) ||
               has(LabComponent.self, for: entity) ||
               has(SolarPanelComponent.self, for: entity) ||
               has(AccumulatorComponent.self, for: entity) {
                return entity
            }
        }

        // Then check for inserters (highest priority among infrastructure that can share tiles)
        for entity in allEntitiesAtPosition {
            if has(InserterComponent.self, for: entity) {
                // print("World: getEntityAt(\(position)) - returning inserter \(entity)")
                return entity
            }
        }

        // Then check for power poles (lower priority than inserters)
        for entity in allEntitiesAtPosition {
            if has(PowerPoleComponent.self, for: entity) {
                return entity
            }
        }

        // Finally check for belts (lowest priority - they're infrastructure)
        for entity in allEntitiesAtPosition {
            if has(BeltComponent.self, for: entity) {
                // print("World: getEntityAt(\(position)) - returning belt \(entity)")
                return entity
            }
        }
        
        // Fallback: return the first entity found
        return allEntitiesAtPosition[0]
    }
    
    /// Checks if there's an entity at a position
    func hasEntityAt(position: IntVector2) -> Bool {
        return getEntityAt(position: position) != nil
    }
    

    /// Gets entities within a rectangular area (world coordinates)
    func getEntitiesIn(rect: Rect) -> [Entity] {
        var result: [Entity] = []
        
        let minX = Int(floorf(rect.minX))
        let maxX = Int(ceilf(rect.maxX))
        let minY = Int(floorf(rect.minY))
        let maxY = Int(ceilf(rect.maxY))
        
        for y in minY...maxY {
            for x in minX...maxX {
                if let entity = spatialIndex[IntVector2(x, y)] {
                    result.append(entity)
                }
            }
        }
        
        return result
    }
    
    /// Gets all entities within a world coordinate rectangle
    /// Includes entities that overlap the rectangle (multi-tile entities)
    func getAllEntitiesInWorldRect(_ worldRect: Rect) -> [Entity] {
        var allEntities: [Entity] = []
        var checkedEntities: Set<Entity> = []

        // Convert world rect to tile bounds for spatial index lookup
        let minTileX = Int32(floor(worldRect.minX))
        let maxTileX = Int32(ceil(worldRect.maxX))
        let minTileY = Int32(floor(worldRect.minY))
        let maxTileY = Int32(ceil(worldRect.maxY))

        // Check spatial index for tiles that intersect the world rect
        for y in minTileY...maxTileY {
            for x in minTileX...maxTileX {
                // Check if this tile actually intersects the world rect
                let tileMinX = Float(x)
                let tileMaxX = Float(x + 1)
                let tileMinY = Float(y)
                let tileMaxY = Float(y + 1)

                let tileIntersects = !(tileMaxX < worldRect.minX || tileMinX > worldRect.maxX ||
                                     tileMaxY < worldRect.minY || tileMinY > worldRect.maxY)

                if tileIntersects {
                    if let entity = spatialIndex[IntVector2(x: x, y: y)] {
                        if !checkedEntities.contains(entity) {
                            allEntities.append(entity)
                            checkedEntities.insert(entity)
                        }
                    }
                }
            }
        }

        print("World: Spatial index found \(allEntities.count) entities in rect")

        // Also check all entities with PositionComponent to find entities that overlap the world rect
        let allEntitiesWithPosition = query(PositionComponent.self)
        print("World: Checking \(allEntitiesWithPosition.count) entities with PositionComponent")

        var assemblerFurnaceFound = 0
        for entity in allEntitiesWithPosition {
            guard !checkedEntities.contains(entity) else { continue }
            guard let pos = get(PositionComponent.self, for: entity) else { continue }

            let hasAssembler = has(AssemblerComponent.self, for: entity)
            let hasFurnace = has(FurnaceComponent.self, for: entity)
            if hasAssembler || hasFurnace {
                assemblerFurnaceFound += 1
            }

            let worldPos = pos.worldPosition
            let sprite = get(SpriteComponent.self, for: entity)
            let spriteSize = sprite?.size ?? Vector2(1, 1)
            let isCentered = sprite?.centered ?? false

            // Calculate bounds based on whether the sprite is centered or not
            let entityMinX: Float
            let entityMaxX: Float
            let entityMinY: Float
            let entityMaxY: Float

            if isCentered {
                // Centered sprites: position is at center
                let halfWidth = spriteSize.x / 2.0
                let halfHeight = spriteSize.y / 2.0
                entityMinX = worldPos.x - halfWidth
                entityMaxX = worldPos.x + halfWidth
                entityMinY = worldPos.y - halfHeight
                entityMaxY = worldPos.y + halfHeight
            } else {
                // Non-centered sprites: position is at bottom-left
                entityMinX = worldPos.x
                entityMaxX = worldPos.x + spriteSize.x
                entityMinY = worldPos.y
                entityMaxY = worldPos.y + spriteSize.y
            }

            // Check for intersection with world rect
            let intersects = !(entityMaxX < worldRect.minX || entityMinX > worldRect.maxX ||
                             entityMaxY < worldRect.minY || entityMinY > worldRect.maxY)

            if intersects {
                allEntities.append(entity)
                checkedEntities.insert(entity)
            }
        }

        print("World: PositionComponent query found \(assemblerFurnaceFound) assembler/furnace entities in rect")
        return allEntities
    }

    /// Gets all entities within a rectangular tile area (tile coordinates)
    /// Includes entities that overlap the rectangle (multi-tile entities)
    func getAllEntitiesInRect(minX: Int32, maxX: Int32, minY: Int32, maxY: Int32) -> [Entity] {
        var allEntities: [Entity] = []
        var checkedEntities: Set<Entity> = []

        // Check spatial index for all tiles in the rectangle
        for y in minY...maxY {
            for x in minX...maxX {
                if let entity = spatialIndex[IntVector2(x: x, y: y)] {
                    if !checkedEntities.contains(entity) {
                        allEntities.append(entity)
                        checkedEntities.insert(entity)
                    }
                }
            }
        }

        // Also check all entities with PositionComponent to find multi-tile entities that overlap
        let allEntitiesWithPosition = query(PositionComponent.self)

        for entity in allEntitiesWithPosition {
            guard !checkedEntities.contains(entity) else { continue }
            guard let pos = get(PositionComponent.self, for: entity) else { continue }

            let origin = pos.tilePosition
            let sprite = get(SpriteComponent.self, for: entity)
            let width = sprite != nil ? Int32(ceil(sprite!.size.x)) : 1
            let height = sprite != nil ? Int32(ceil(sprite!.size.y)) : 1

            // Check if entity's bounds intersect with the selection rectangle
            let entityMinX = origin.x
            let entityMaxX = origin.x + width - 1
            let entityMinY = origin.y
            let entityMaxY = origin.y + height - 1

            // Check for intersection
            let intersects = !(entityMaxX < minX || entityMinX > maxX ||
                               entityMaxY < minY || entityMinY > maxY)

            if intersects {
                allEntities.append(entity)
                checkedEntities.insert(entity)
            }
        }

        return allEntities
    }
    
    /// Gets entities within a radius of a point
    func getEntitiesNear(position: Vector2, radius: Float) -> [Entity] {
        let rect = Rect(center: position, size: Vector2(repeating: radius * 2))
        let candidates = getEntitiesIn(rect: rect)
        
        return candidates.filter { entity in
            guard let pos = get(PositionComponent.self, for: entity) else { return false }
            return pos.worldPosition.distance(to: position) <= radius
        }
    }
    
    /// Checks if a position would collide with any entities
    func checkCollision(at position: Vector2, radius: Float, layer: CollisionLayer, excluding: Entity? = nil) -> Bool {
        let nearbyEntities = getEntitiesNear(position: position, radius: radius * 2)
        
        for entity in nearbyEntities {
            guard entity != excluding else { continue }
            guard let collision = get(CollisionComponent.self, for: entity) else { continue }
            guard let entityPos = get(PositionComponent.self, for: entity) else { continue }
            
            // Check if collision layers overlap
            guard !collision.layer.intersection(layer).isEmpty else { continue }
            
            // Check if circles overlap
            let distance = position.distance(to: entityPos.worldPosition)
            let combinedRadius = radius + collision.radius
            
            if distance < combinedRadius {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Rendering
    
    /// Renders all visible entities
    func render(renderer: MetalRenderer) {
        // Entities are rendered by the SpriteRenderer which queries the world
    }
    
    // MARK: - Private Helpers
    
    private func getOrCreateStore<T: Component>(for type: T.Type) -> ComponentStore<T> {
        let key = ObjectIdentifier(type)
        if let store = componentStores[key] as? ComponentStore<T> {
            return store
        }
        let store = ComponentStore<T>()
        componentStores[key] = store
        return store
    }
    
    /// Clears all entities and components
    func clear() {
        entityManager.reset()
        for (_, store) in componentStores {
            store.clear()
        }
        print("World: Clearing spatial index (had \(spatialIndex.count) entries)")
        spatialIndex.removeAll()
    }

    /// Rebuilds the spatial index from all entities with PositionComponents
    /// This ensures the spatial index is consistent with the current entity positions
    func rebuildSpatialIndex() {
        spatialIndex.removeAll()
        let entitiesWithPosition = query(PositionComponent.self)
        for entity in entitiesWithPosition {
            if let pos = get(PositionComponent.self, for: entity) {
                spatialIndex[pos.tilePosition] = entity
            }
        }
        print("World: Rebuilt spatial index with \(spatialIndex.count) entries")
    }
}

// MARK: - Serialization Support

extension World {
    /// Serializes the world state
    func serialize() -> WorldData {
        var entityDataList: [EntityData] = []
        
        for entity in entities {
            var components: [String: Data] = [:]
            
            // Serialize each component type
            if let pos = get(PositionComponent.self, for: entity) {
                components["position"] = try? JSONEncoder().encode(pos)
            }
            if let sprite = get(SpriteComponent.self, for: entity) {
                components["sprite"] = try? JSONEncoder().encode(sprite)
            }
            if let health = get(HealthComponent.self, for: entity) {
                components["health"] = try? JSONEncoder().encode(health)
            }
            if let tree = get(TreeComponent.self, for: entity) {
                components["tree"] = try? JSONEncoder().encode(tree)
            }
            if let inventory = get(InventoryComponent.self, for: entity) {
                components["inventory"] = try? JSONEncoder().encode(inventory)
            }
            if let miner = get(MinerComponent.self, for: entity) {
                components["miner"] = try? JSONEncoder().encode(miner)
            }
            if let belt = get(BeltComponent.self, for: entity) {
                components["belt"] = try? JSONEncoder().encode(belt)
            }
            if let inserter = get(InserterComponent.self, for: entity) {
                components["inserter"] = try? JSONEncoder().encode(inserter)
            }
            if let assembler = get(AssemblerComponent.self, for: entity) {
                components["assembler"] = try? JSONEncoder().encode(assembler)
            }
            if let furnace = get(FurnaceComponent.self, for: entity) {
                components["furnace"] = try? JSONEncoder().encode(furnace)
            }
            if let powerPole = get(PowerPoleComponent.self, for: entity) {
                components["powerPole"] = try? JSONEncoder().encode(powerPole)
            }
            if let generator = get(GeneratorComponent.self, for: entity) {
                components["generator"] = try? JSONEncoder().encode(generator)
            }
            if let powerConsumer = get(PowerConsumerComponent.self, for: entity) {
                components["powerConsumer"] = try? JSONEncoder().encode(powerConsumer)
            }
            if let chest = get(ChestComponent.self, for: entity) {
                components["chest"] = try? JSONEncoder().encode(chest)
            }
            if let lab = get(LabComponent.self, for: entity) {
                components["lab"] = try? JSONEncoder().encode(lab)
            }
            if let solarPanel = get(SolarPanelComponent.self, for: entity) {
                components["solarPanel"] = try? JSONEncoder().encode(solarPanel)
            }
            if let accumulator = get(AccumulatorComponent.self, for: entity) {
                components["accumulator"] = try? JSONEncoder().encode(accumulator)
            }
            if let turret = get(TurretComponent.self, for: entity) {
                components["turret"] = try? JSONEncoder().encode(turret)
            }
            if let wall = get(WallComponent.self, for: entity) {
                components["wall"] = try? JSONEncoder().encode(wall)
            }
            if let rocketSilo = get(RocketSiloComponent.self, for: entity) {
                components["rocketSilo"] = try? JSONEncoder().encode(rocketSilo)
            }

            // Fluid components
            if let pipe = get(PipeComponent.self, for: entity) {
                components["pipe"] = try? JSONEncoder().encode(pipe)
            }
            if let fluidProducer = get(FluidProducerComponent.self, for: entity) {
                components["fluidProducer"] = try? JSONEncoder().encode(fluidProducer)
            }
            if let fluidConsumer = get(FluidConsumerComponent.self, for: entity) {
                components["fluidConsumer"] = try? JSONEncoder().encode(fluidConsumer)
            }
            if let fluidTank = get(FluidTankComponent.self, for: entity) {
                components["fluidTank"] = try? JSONEncoder().encode(fluidTank)
            }
            if let fluidPump = get(FluidPumpComponent.self, for: entity) {
                components["fluidPump"] = try? JSONEncoder().encode(fluidPump)
            }
            
            // Exclude player entity from world serialization (it's saved separately in PlayerState)
            // Player entities have CollisionComponent with layer .player
            if let collision = get(CollisionComponent.self, for: entity),
               collision.layer == .player {
                continue  // Skip serializing player entity
            }
            
            entityDataList.append(EntityData(
                id: entity.id,
                generation: entity.generation,
                components: components
            ))
        }
        
        return WorldData(entities: entityDataList)
    }
    
    /// Deserializes world state
    func deserialize(_ data: WorldData) {
        clear()
        
        // Map old entity IDs to new entities for fixing references
        var oldIdToNewEntity: [UInt32: Entity] = [:]
        
        for entityData in data.entities {
            let entity = spawn()
            oldIdToNewEntity[entityData.id] = entity

            // Debug: Check what components this entity has
            if entityData.components.keys.contains("assembler") || entityData.components.keys.contains("furnace") {
                print("World: Entity \(entityData.id) has assembler/furnace data in save file, keys: \(entityData.components.keys)")
            }

            // Deserialize each component
            if let posData = entityData.components["position"] {
                do {
                    let pos = try JSONDecoder().decode(PositionComponent.self, from: posData)
                    add(pos, to: entity)
                } catch {
                    print("World: Failed to decode PositionComponent for entity \(entityData.id): \(error)")
                }
            }
            if let spriteData = entityData.components["sprite"],
               let sprite = try? JSONDecoder().decode(SpriteComponent.self, from: spriteData) {
                add(sprite, to: entity)
            }
            if let healthData = entityData.components["health"],
               let health = try? JSONDecoder().decode(HealthComponent.self, from: healthData) {
                add(health, to: entity)
            }
            if let treeData = entityData.components["tree"],
               let tree = try? JSONDecoder().decode(TreeComponent.self, from: treeData) {
                add(tree, to: entity)
            }
            if let invData = entityData.components["inventory"],
               let inventory = try? JSONDecoder().decode(InventoryComponent.self, from: invData) {
                add(inventory, to: entity)
            }
            if let minerData = entityData.components["miner"],
               let miner = try? JSONDecoder().decode(MinerComponent.self, from: minerData) {
                add(miner, to: entity)
            }
            if let beltData = entityData.components["belt"],
               let belt = try? JSONDecoder().decode(BeltComponent.self, from: beltData) {
                add(belt, to: entity)
            }
            if let inserterData = entityData.components["inserter"],
               let inserter = try? JSONDecoder().decode(InserterComponent.self, from: inserterData) {
                add(inserter, to: entity)
            }
            if let assemblerData = entityData.components["assembler"] {
                print("World: Found assembler data for entity \(entity), attempting decode...")
                do {
                    let assembler = try JSONDecoder().decode(AssemblerComponent.self, from: assemblerData)
                    add(assembler, to: entity)
                    print("World: Successfully deserialized assembler component for entity \(entity)")
                } catch {
                    print("World: Failed to decode assembler component for entity \(entity): \(error)")
                }
            }
            if let furnaceData = entityData.components["furnace"] {
                print("World: Found furnace data for entity \(entity), attempting decode...")
                do {
                    let furnace = try JSONDecoder().decode(FurnaceComponent.self, from: furnaceData)
                    add(furnace, to: entity)
                    print("World: Successfully deserialized furnace component for entity \(entity)")
                } catch {
                    print("World: Failed to decode furnace component for entity \(entity): \(error)")
                }
            }
            if let powerPoleData = entityData.components["powerPole"],
               let powerPole = try? JSONDecoder().decode(PowerPoleComponent.self, from: powerPoleData) {
                add(powerPole, to: entity)
            }
            if let generatorData = entityData.components["generator"],
               let generator = try? JSONDecoder().decode(GeneratorComponent.self, from: generatorData) {
                add(generator, to: entity)
            }
            if let powerConsumerData = entityData.components["powerConsumer"],
               let powerConsumer = try? JSONDecoder().decode(PowerConsumerComponent.self, from: powerConsumerData) {
                add(powerConsumer, to: entity)
            }
            if let chestData = entityData.components["chest"],
               let chest = try? JSONDecoder().decode(ChestComponent.self, from: chestData) {
                add(chest, to: entity)
            }
            if let labData = entityData.components["lab"],
               let lab = try? JSONDecoder().decode(LabComponent.self, from: labData) {
                add(lab, to: entity)
            }
            if let solarPanelData = entityData.components["solarPanel"],
               let solarPanel = try? JSONDecoder().decode(SolarPanelComponent.self, from: solarPanelData) {
                add(solarPanel, to: entity)
            }
            if let accumulatorData = entityData.components["accumulator"],
               let accumulator = try? JSONDecoder().decode(AccumulatorComponent.self, from: accumulatorData) {
                add(accumulator, to: entity)
            }
            if let turretData = entityData.components["turret"],
               let turret = try? JSONDecoder().decode(TurretComponent.self, from: turretData) {
                add(turret, to: entity)
            }
            if let wallData = entityData.components["wall"],
               let wall = try? JSONDecoder().decode(WallComponent.self, from: wallData) {
                add(wall, to: entity)
            }
            if let rocketSiloData = entityData.components["rocketSilo"],
               let rocketSilo = try? JSONDecoder().decode(RocketSiloComponent.self, from: rocketSiloData) {
                add(rocketSilo, to: entity)
            }

            // Fluid components
            if let pipeData = entityData.components["pipe"],
               let pipe = try? JSONDecoder().decode(PipeComponent.self, from: pipeData) {
                add(pipe, to: entity)
            }
            if let fluidProducerData = entityData.components["fluidProducer"],
               let fluidProducer = try? JSONDecoder().decode(FluidProducerComponent.self, from: fluidProducerData) {
                add(fluidProducer, to: entity)
            }
            if let fluidConsumerData = entityData.components["fluidConsumer"],
               let fluidConsumer = try? JSONDecoder().decode(FluidConsumerComponent.self, from: fluidConsumerData) {
                add(fluidConsumer, to: entity)
            }
            if let fluidTankData = entityData.components["fluidTank"],
               let fluidTank = try? JSONDecoder().decode(FluidTankComponent.self, from: fluidTankData) {
                add(fluidTank, to: entity)
            }
            if let fluidPumpData = entityData.components["fluidPump"],
               let fluidPump = try? JSONDecoder().decode(FluidPumpComponent.self, from: fluidPumpData) {
                add(fluidPump, to: entity)
            }

            if let collisionData = entityData.components["collision"],
               let collision = try? JSONDecoder().decode(CollisionComponent.self, from: collisionData) {
                add(collision, to: entity)
            }
        }

        // Debug: Check for assembler/furnace components after deserialization
        var assemblerCount = 0
        var furnaceCount = 0
        for entity in entities {
            let hasAssembler = has(AssemblerComponent.self, for: entity)
            let hasFurnace = has(FurnaceComponent.self, for: entity)
            if hasAssembler {
                assemblerCount += 1
                if let pos = get(PositionComponent.self, for: entity) {
                    print("World: Entity \(entity) has assembler component at \(pos.tilePosition)")
                }
            }
            if hasFurnace {
                furnaceCount += 1
                if let pos = get(PositionComponent.self, for: entity) {
                    print("World: Entity \(entity) has furnace component at \(pos.tilePosition)")
                }
            }
        }
        print("World: Found \(assemblerCount) assemblers and \(furnaceCount) furnaces after deserialization")

        // Fix entity references in InserterComponents after all entities are loaded
        for entity in entities {
            if let inserter = get(InserterComponent.self, for: entity) {
                var needsUpdate = false
                
                // Fix inputTarget reference
                if let oldInputTarget = inserter.inputTarget,
                   let newInputTarget = oldIdToNewEntity[oldInputTarget.id] {
                    inserter.inputTarget = newInputTarget
                    needsUpdate = true
                } else if inserter.inputTarget != nil {
                    // Old entity no longer exists, clear the reference
                    inserter.inputTarget = nil
                    inserter.inputPosition = nil
                    needsUpdate = true
                }
                
                // Fix outputTarget reference
                if let oldOutputTarget = inserter.outputTarget,
                   let newOutputTarget = oldIdToNewEntity[oldOutputTarget.id] {
                    inserter.outputTarget = newOutputTarget
                    needsUpdate = true
                } else if inserter.outputTarget != nil {
                    // Old entity no longer exists, clear the reference
                    inserter.outputTarget = nil
                    inserter.outputPosition = nil
                    needsUpdate = true
                }
                
                // Fix sourceEntity reference (if present)
                if let oldSourceEntity = inserter.sourceEntity,
                   let newSourceEntity = oldIdToNewEntity[oldSourceEntity.id] {
                    inserter.sourceEntity = newSourceEntity
                    needsUpdate = true
                } else if inserter.sourceEntity != nil {
                    inserter.sourceEntity = nil
                    needsUpdate = true
                }

                // Reset inserter state and ensure proper initialization for loaded inserters
                // This prevents issues with saved inserters being in invalid states
                inserter.state = .idle
                inserter.armAngle = 0
                inserter.heldItem = nil
                inserter.dropTimeout = 0
                // Clear any potentially invalid target references that couldn't be fixed
                if inserter.inputTarget == nil {
                    inserter.inputPosition = nil
                }
                if inserter.outputTarget == nil {
                    inserter.outputPosition = nil
                }
                needsUpdate = true

                if needsUpdate {
                    add(inserter, to: entity)
                }
            }
        }
    }
}

struct WorldData: Codable {
    let entities: [EntityData]
}

struct EntityData: Codable {
    let id: UInt32
    let generation: UInt16
    let components: [String: Data]
}
