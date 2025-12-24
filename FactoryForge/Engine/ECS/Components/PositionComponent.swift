import Foundation

/// Position and orientation of an entity in the game world
struct PositionComponent: Component {
    /// Tile position (discrete grid position)
    var tilePosition: IntVector2
    
    /// Direction the entity is facing
    var direction: Direction
    
    /// Offset from tile center (for smooth movement)
    var offset: Vector2
    
    /// World position in continuous coordinates
    var worldPosition: Vector2 {
        return tilePosition.toVector2 + offset + Vector2(0.5, 0.5)
    }
    
    init(tilePosition: IntVector2, direction: Direction = .north, offset: Vector2 = .zero) {
        self.tilePosition = tilePosition
        self.direction = direction
        self.offset = offset
    }
    
    init(x: Int, y: Int, direction: Direction = .north) {
        self.tilePosition = IntVector2(x, y)
        self.direction = direction
        self.offset = .zero
    }
}

/// Velocity component for moving entities
struct VelocityComponent: Component {
    var velocity: Vector2
    var angularVelocity: Float
    
    init(velocity: Vector2 = .zero, angularVelocity: Float = 0) {
        self.velocity = velocity
        self.angularVelocity = angularVelocity
    }
}

/// Collision component for physics
struct CollisionComponent: Component {
    var radius: Float
    var isStatic: Bool
    var layer: CollisionLayer
    var mask: CollisionLayer
    
    init(radius: Float, isStatic: Bool = false, layer: CollisionLayer = .default, mask: CollisionLayer = .all) {
        self.radius = radius
        self.isStatic = isStatic
        self.layer = layer
        self.mask = mask
    }
}

struct CollisionLayer: OptionSet, Codable {
    let rawValue: UInt32
    
    static let none = CollisionLayer([])
    static let `default` = CollisionLayer(rawValue: 1 << 0)
    static let player = CollisionLayer(rawValue: 1 << 1)
    static let enemy = CollisionLayer(rawValue: 1 << 2)
    static let building = CollisionLayer(rawValue: 1 << 3)
    static let projectile = CollisionLayer(rawValue: 1 << 4)
    static let resource = CollisionLayer(rawValue: 1 << 5)
    static let all = CollisionLayer(rawValue: UInt32.max)
}

