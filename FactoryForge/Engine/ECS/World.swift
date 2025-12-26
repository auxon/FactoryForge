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
        let entities1 = Set(query(type1))
        let entities2 = Set(query(type2))
        return Array(entities1.intersection(entities2))
    }
    
    /// Queries entities with three components
    func query<T1: Component, T2: Component, T3: Component>(
        _ type1: T1.Type, _ type2: T2.Type, _ type3: T3.Type
    ) -> [Entity] {
        let entities1 = Set(query(type1))
        let entities2 = Set(query(type2))
        let entities3 = Set(query(type3))
        return Array(entities1.intersection(entities2).intersection(entities3))
    }
    
    /// Iterates over all components of a type
    func forEach<T: Component>(_ type: T.Type, _ body: (Entity, inout T) -> Void) {
        guard let store = componentStores[ObjectIdentifier(type)] as? ComponentStore<T> else {
            return
        }
        store.forEach(body)
    }
    
    // MARK: - Spatial Queries
    
    /// Gets the entity at a tile position (checks exact match first, then checks if position is within any entity's bounds)
    func getEntityAt(position: IntVector2) -> Entity? {
        // First try exact match (works for 1x1 entities)
        if let entity = spatialIndex[position] {
            return entity
        }
        
        // For multi-tile buildings, check all entities with PositionComponent and SpriteComponent
        // to see if the tapped position is within their bounds
        for entity in query(PositionComponent.self, SpriteComponent.self) {
            guard let pos = get(PositionComponent.self, for: entity),
                  let sprite = get(SpriteComponent.self, for: entity) else { continue }
            
            let origin = pos.tilePosition
            let width = Int32(sprite.size.x)
            let height = Int32(sprite.size.y)
            
            // Check if the tapped position is within this entity's bounds
            if position.x >= origin.x && position.x < origin.x + width &&
               position.y >= origin.y && position.y < origin.y + height {
                return entity
            }
        }
        
        return nil
    }
    
    /// Checks if there's an entity at a position
    func hasEntityAt(position: IntVector2) -> Bool {
        return spatialIndex[position] != nil
    }
    
    /// Gets entities within a rectangular area
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
    
    /// Gets entities within a radius of a point
    func getEntitiesNear(position: Vector2, radius: Float) -> [Entity] {
        let rect = Rect(center: position, size: Vector2(repeating: radius * 2))
        let candidates = getEntitiesIn(rect: rect)
        
        return candidates.filter { entity in
            guard let pos = get(PositionComponent.self, for: entity) else { return false }
            return pos.worldPosition.distance(to: position) <= radius
        }
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
        spatialIndex.removeAll()
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
        
        for entityData in data.entities {
            let entity = spawn()
            
            // Deserialize each component
            if let posData = entityData.components["position"],
               let pos = try? JSONDecoder().decode(PositionComponent.self, from: posData) {
                add(pos, to: entity)
            }
            if let spriteData = entityData.components["sprite"],
               let sprite = try? JSONDecoder().decode(SpriteComponent.self, from: spriteData) {
                add(sprite, to: entity)
            }
            if let healthData = entityData.components["health"],
               let health = try? JSONDecoder().decode(HealthComponent.self, from: healthData) {
                add(health, to: entity)
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
            if let assemblerData = entityData.components["assembler"],
               let assembler = try? JSONDecoder().decode(AssemblerComponent.self, from: assemblerData) {
                add(assembler, to: entity)
            }
            if let furnaceData = entityData.components["furnace"],
               let furnace = try? JSONDecoder().decode(FurnaceComponent.self, from: furnaceData) {
                add(furnace, to: entity)
            }
            if let collisionData = entityData.components["collision"],
               let collision = try? JSONDecoder().decode(CollisionComponent.self, from: collisionData) {
                add(collision, to: entity)
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

