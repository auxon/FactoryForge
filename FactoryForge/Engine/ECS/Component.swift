import Foundation

/// Base protocol for all components
protocol Component: Codable {}

/// Type-erased component storage
protocol AnyComponentStore: AnyObject {
    func remove(_ entity: Entity)
    func has(_ entity: Entity) -> Bool
    func clear()
}

/// Storage for a specific component type using sparse set for cache-efficient iteration
final class ComponentStore<T: Component>: AnyComponentStore {
    /// Dense array of components for cache-friendly iteration
    private var dense: [T] = []
    
    /// Dense array of entities (parallel to components)
    private var denseEntities: [Entity] = []
    
    /// Sparse map from entity ID to dense index
    private var sparse: [UInt32: Int] = [:]
    
    /// Number of components stored
    var count: Int {
        return dense.count
    }
    
    /// Adds or updates a component for an entity
    func set(_ component: T, for entity: Entity) {
        if let index = sparse[entity.id] {
            // Update existing
            dense[index] = component
        } else {
            // Add new
            let index = dense.count
            dense.append(component)
            denseEntities.append(entity)
            sparse[entity.id] = index
        }
    }
    
    /// Gets a component for an entity
    func get(_ entity: Entity) -> T? {
        guard let index = sparse[entity.id] else { return nil }
        return dense[index]
    }
    
    /// Gets a mutable reference to a component
    func getMutable(_ entity: Entity) -> UnsafeMutablePointer<T>? {
        guard let index = sparse[entity.id] else { return nil }
        return withUnsafeMutablePointer(to: &dense[index]) { $0 }
    }
    
    /// Removes a component from an entity
    func remove(_ entity: Entity) {
        guard let index = sparse[entity.id] else { return }
        
        // Swap with last element
        let lastIndex = dense.count - 1
        if index != lastIndex {
            dense[index] = dense[lastIndex]
            denseEntities[index] = denseEntities[lastIndex]
            sparse[denseEntities[index].id] = index
        }
        
        dense.removeLast()
        denseEntities.removeLast()
        sparse.removeValue(forKey: entity.id)
    }
    
    /// Checks if an entity has this component
    func has(_ entity: Entity) -> Bool {
        return sparse[entity.id] != nil
    }
    
    /// Clears all components
    func clear() {
        dense.removeAll()
        denseEntities.removeAll()
        sparse.removeAll()
    }
    
    /// Iterates over all components with their entities
    func forEach(_ body: (Entity, inout T) -> Void) {
        for i in 0..<dense.count {
            body(denseEntities[i], &dense[i])
        }
    }
    
    /// Returns all entities with this component
    var entities: [Entity] {
        return denseEntities
    }
    
    /// Returns all components
    var components: [T] {
        return dense
    }
}

// MARK: - Component Type Registry

/// Registry for component type information
final class ComponentTypeRegistry {
    static let shared = ComponentTypeRegistry()
    
    private var typeIds: [ObjectIdentifier: Int] = [:]
    private var nextTypeId = 0
    
    private init() {}
    
    func typeId<T: Component>(for type: T.Type) -> Int {
        let identifier = ObjectIdentifier(type)
        if let id = typeIds[identifier] {
            return id
        }
        let id = nextTypeId
        nextTypeId += 1
        typeIds[identifier] = id
        return id
    }
}

