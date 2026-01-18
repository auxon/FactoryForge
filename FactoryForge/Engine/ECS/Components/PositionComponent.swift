import Foundation

/// Position and orientation of an entity in the game world
struct PositionComponent: Component {
    /// Tile position (discrete grid position)
    var tilePosition: IntVector2

    /// Direction the entity is facing
    var direction: Direction

    /// Offset from tile center (for smooth movement in X/Z plane)
    var offset: Vector2

    /// Height above ground level (for 3D positioning)
    var height: Float

    /// World position in continuous coordinates (2D for compatibility)
    var worldPosition: Vector2 {
        return tilePosition.toVector2 + offset + Vector2(0.5, 0.5)
    }

    /// 3D world position including height
    var worldPosition3D: Vector3 {
        let groundPos = worldPosition
        return Vector3(groundPos.x, height, groundPos.y)
    }
    
    init(tilePosition: IntVector2, direction: Direction = .north, offset: Vector2 = .zero, height: Float = 0) {
        self.tilePosition = tilePosition
        self.direction = direction
        self.offset = offset
        self.height = height
    }
    
    init(x: Int, y: Int, direction: Direction = .north) {
        self.tilePosition = IntVector2(x, y)
        self.direction = direction
        self.offset = .zero
        self.height = 0
    }
}

/// Velocity component for moving entities
struct VelocityComponent: Component {
    var velocity: Vector2  // Ground plane velocity (X/Z)
    var verticalVelocity: Float  // Up/down velocity (Y)
    var angularVelocity: Float  // Rotation velocity

    init(velocity: Vector2 = .zero, verticalVelocity: Float = 0, angularVelocity: Float = 0) {
        self.velocity = velocity
        self.verticalVelocity = verticalVelocity
        self.angularVelocity = angularVelocity
    }

    /// 3D velocity vector
    var velocity3D: Vector3 {
        return Vector3(velocity.x, verticalVelocity, velocity.y)
    }
}

/// Collision component for physics
struct CollisionComponent: Component {
    var radius: Float  // Collision radius in X/Z plane
    var height: Float  // Collision height in Y axis
    var isStatic: Bool
    var layer: CollisionLayer
    var mask: CollisionLayer

    init(radius: Float, height: Float = 1.0, isStatic: Bool = false, layer: CollisionLayer = .default, mask: CollisionLayer = .all) {
        self.radius = radius
        self.height = height
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

