import Foundation

/// A unique identifier for an entity in the game world
struct Entity: Hashable, Codable {
    /// Unique ID within the current generation
    let id: UInt32
    
    /// Generation counter to detect stale entity references
    let generation: UInt16
    
    /// Invalid entity constant
    static let invalid = Entity(id: UInt32.max, generation: UInt16.max)
    
    var isValid: Bool {
        return self != Entity.invalid
    }
}

/// Manages entity creation, destruction, and recycling
final class EntityManager {
    private var nextId: UInt32 = 0
    private var generations: [UInt32: UInt16] = [:]
    private var freeList: [UInt32] = []
    private var livingEntities: Set<Entity> = []
    
    /// All currently living entities
    var entities: Set<Entity> {
        return livingEntities
    }
    
    /// Number of living entities
    var count: Int {
        return livingEntities.count
    }
    
    /// Creates a new entity
    func create() -> Entity {
        let id: UInt32
        let generation: UInt16
        
        if let recycledId = freeList.popLast() {
            id = recycledId
            generation = (generations[id] ?? 0) &+ 1
            generations[id] = generation
        } else {
            id = nextId
            nextId += 1
            generation = 0
            generations[id] = generation
        }
        
        let entity = Entity(id: id, generation: generation)
        livingEntities.insert(entity)
        return entity
    }
    
    /// Destroys an entity, making its ID available for reuse
    func destroy(_ entity: Entity) {
        guard isAlive(entity) else { return }
        livingEntities.remove(entity)
        freeList.append(entity.id)
    }
    
    /// Checks if an entity is currently alive
    func isAlive(_ entity: Entity) -> Bool {
        guard let currentGeneration = generations[entity.id] else {
            return false
        }
        return currentGeneration == entity.generation && livingEntities.contains(entity)
    }
    
    /// Resets the entity manager
    func reset() {
        nextId = 0
        generations.removeAll()
        freeList.removeAll()
        livingEntities.removeAll()
    }
}

// MARK: - Entity Builder

/// Fluent interface for building entities with components
final class EntityBuilder {
    private let entity: Entity
    private let world: World
    
    init(entity: Entity, world: World) {
        self.entity = entity
        self.world = world
    }
    
    @discardableResult
    func with<T: Component>(_ component: T) -> EntityBuilder {
        world.add(component, to: entity)
        return self
    }
    
    func build() -> Entity {
        return entity
    }
}

