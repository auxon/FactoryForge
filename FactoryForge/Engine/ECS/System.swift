import Foundation

/// Base protocol for all game systems
protocol System: AnyObject {
    /// Called every fixed update tick
    func update(deltaTime: Float)
    
    /// Priority for system execution order (lower = earlier)
    var priority: Int { get }
}

extension System {
    var priority: Int { return 0 }
}

/// Manages and executes systems in order
final class SystemManager {
    private var systems: [System] = []
    private var needsSort = false
    
    /// Registers a system
    func register(_ system: System) {
        systems.append(system)
        needsSort = true
    }
    
    /// Removes a system
    func unregister(_ system: System) {
        systems.removeAll { $0 === system }
    }
    
    /// Updates all systems
    func update(deltaTime: Float) {
        if needsSort {
            systems.sort { $0.priority < $1.priority }
            needsSort = false
        }
        
        for system in systems {
            system.update(deltaTime: deltaTime)
        }
    }
    
    /// Gets a system by type
    func get<T: System>(_ type: T.Type) -> T? {
        return systems.first { $0 is T } as? T
    }
}

// MARK: - System Priorities

enum SystemPriority: Int {
    case input = 0
    case physics = 100
    case mining = 200
    case logistics = 300
    case production = 400
    case power = 500
    case research = 600
    case pollution = 700
    case enemyAI = 800
    case combat = 900
    case cleanup = 1000
}

