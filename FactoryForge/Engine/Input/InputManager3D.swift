import UIKit
import Foundation

/// 3D Input manager that handles raycasting and 3D picking
@available(iOS 17.0, *)
final class InputManager3D {
    private weak var camera: Camera3D?
    private weak var gameLoop: GameLoop?

    // Selection state
    private var selectedEntity: Entity?
    private var selectionBoxStart: Vector2?
    private var isDragSelecting: Bool = false

    // Callbacks
    var onEntitySelected: ((Entity?) -> Void)?
    var onGroundClicked: ((Vector3) -> Void)?
    var onTerrainModified: ((IntVector2, Float) -> Void)?

    init(camera: Camera3D, gameLoop: GameLoop) {
        self.camera = camera
        self.gameLoop = gameLoop
    }

    // MARK: - Raycasting

    /// Performs raycast from screen point into 3D world
    func raycastFromScreen(_ screenPoint: Vector2, screenSize: Vector2) -> RaycastResult? {
        guard camera != nil else { return nil }

        // Convert screen point to world ray
        let ray = createRayFromScreen(screenPoint, screenSize: screenSize)

        // Test against ground plane first
        if let groundHit = rayIntersectGround(ray) {
            // Test against entities
            if let entityHit = raycastEntities(ray, maxDistance: groundHit.distance) {
                return entityHit
            }

            // Return ground hit
            return RaycastResult(
                type: .ground,
                position: groundHit.position,
                distance: groundHit.distance,
                entity: nil
            )
        }

        return nil
    }

    private func createRayFromScreen(_ screenPoint: Vector2, screenSize: Vector2) -> Ray {
        guard let camera = camera else {
            return Ray(origin: .zero, direction: Vector3(0, 0, 1))
        }

        // Convert screen coordinates to normalized device coordinates (-1 to 1)
        let ndc = Vector2(
            (screenPoint.x / screenSize.x) * 2 - 1,
            (1 - screenPoint.y / screenSize.y) * 2 - 1  // Flip Y axis
        )

        // Create ray in world space
        let viewProjectionInverse = camera.viewProjectionMatrix.inverse

        // Near plane point
        let nearPoint = Vector4(ndc.x, ndc.y, -1, 1) // -1 for OpenGL-style NDC
        let nearWorld = viewProjectionInverse * nearPoint
        _ = Vector3(
            nearWorld.x / nearWorld.w,
            nearWorld.y / nearWorld.w,
            nearWorld.z / nearWorld.w
        )

        // Far plane point
        let farPoint = Vector4(ndc.x, ndc.y, 1, 1)
        let farWorld = viewProjectionInverse * farPoint
        let farWorldPos = Vector3(
            farWorld.x / farWorld.w,
            farWorld.y / farWorld.w,
            farWorld.z / farWorld.w
        )

        let origin = camera.position
        let direction = (farWorldPos - origin).normalized

        return Ray(origin: origin, direction: direction)
    }

    private func rayIntersectGround(_ ray: Ray) -> GroundHit? {
        // Intersect with ground plane (y = 0)

        // Ray equation: origin + t * direction
        // Ground plane: y = 0
        // So: origin.y + t * direction.y = 0
        // t = -origin.y / direction.y

        guard abs(ray.direction.y) > 0.001 else {
            return nil // Ray is parallel to ground
        }

        let t = -ray.origin.y / ray.direction.y

        guard t > 0 else {
            return nil // Intersection is behind camera
        }

        let position = ray.origin + ray.direction * t

        return GroundHit(position: position, distance: t)
    }

    private func raycastEntities(_ ray: Ray, maxDistance: Float) -> RaycastResult? {
        guard let gameLoop = gameLoop else { return nil }

        var closestHit: RaycastResult?
        var closestDistance = maxDistance

        // Check all entities with position and collision components
        for entity in gameLoop.world.entities {
            guard let position = gameLoop.world.get(PositionComponent.self, for: entity),
                  let collision = gameLoop.world.get(CollisionComponent.self, for: entity) else {
                continue
            }

            // Create bounding box for entity
            let entityPos = position.worldPosition3D
            let halfSize = Vector3(collision.radius, collision.height * 0.5, collision.radius)
            let box = BoundingBox(center: entityPos, halfSize: halfSize)

            // Test ray against bounding box
            if let hit = rayIntersectBox(ray, box) {
                if hit.distance < closestDistance {
                    closestDistance = hit.distance
                    closestHit = RaycastResult(
                        type: .entity,
                        position: hit.position,
                        distance: hit.distance,
                        entity: entity
                    )
                }
            }
        }

        return closestHit
    }

    private func rayIntersectBox(_ ray: Ray, _ box: BoundingBox) -> BoxHit? {
        let boxMin = box.center - box.halfSize
        let boxMax = box.center + box.halfSize

        var tMin: Float = 0
        var tMax: Float = Float.greatestFiniteMagnitude

        // Test X slab
        let tx1 = (boxMin.x - ray.origin.x) / ray.direction.x
        let tx2 = (boxMax.x - ray.origin.x) / ray.direction.x
        tMin = Swift.max(tMin, Swift.min(tx1, tx2))
        tMax = Swift.min(tMax, Swift.max(tx1, tx2))

        // Test Y slab
        let ty1 = (boxMin.y - ray.origin.y) / ray.direction.y
        let ty2 = (boxMax.y - ray.origin.y) / ray.direction.y
        tMin = Swift.max(tMin, Swift.min(ty1, ty2))
        tMax = Swift.min(tMax, Swift.max(ty1, ty2))

        // Test Z slab
        let tz1 = (boxMin.z - ray.origin.z) / ray.direction.z
        let tz2 = (boxMax.z - ray.origin.z) / ray.direction.z
        tMin = Swift.max(tMin, Swift.min(tz1, tz2))
        tMax = Swift.min(tMax, Swift.max(tz1, tz2))

        if tMin > tMax || tMax < 0 {
            return nil
        }

        let distance = tMin > 0 ? tMin : tMax
        let position = ray.origin + ray.direction * distance

        return BoxHit(position: position, distance: distance)
    }

    // MARK: - Touch Handling

    func handleTap(at screenPoint: Vector2, screenSize: Vector2) {
        if let result = raycastFromScreen(screenPoint, screenSize: screenSize) {
            switch result.type {
            case .entity:
                if let entity = result.entity {
                    selectEntity(entity)
                }
            case .ground:
                handleGroundTap(at: result.position)
            }
        }
    }

    func handleLongPress(at screenPoint: Vector2, screenSize: Vector2) {
        // For terrain modification (digging/building up)
        if let result = raycastFromScreen(screenPoint, screenSize: screenSize) {
            switch result.type {
            case .ground:
                let tilePos = IntVector2(from: Vector2(result.position.x, result.position.z))
                onTerrainModified?(tilePos, -0.5) // Dig down
            default:
                break
            }
        }
    }

    func handleDoubleTap(at screenPoint: Vector2, screenSize: Vector2) {
        // For terrain modification (building up)
        if let result = raycastFromScreen(screenPoint, screenSize: screenSize) {
            switch result.type {
            case .ground:
                let tilePos = IntVector2(from: Vector2(result.position.x, result.position.z))
                onTerrainModified?(tilePos, 0.5) // Build up
            default:
                break
            }
        }
    }

    // MARK: - Selection

    private func selectEntity(_ entity: Entity) {
        selectedEntity = entity
        onEntitySelected?(entity)
        print("InputManager3D: Selected entity \(entity)")
    }

    func clearSelection() {
        selectedEntity = nil
        onEntitySelected?(nil)
    }

    private func handleGroundTap(at position: Vector3) {
        // Move to ground position or perform ground action
        let groundPos2D = Vector2(position.x, position.z)
        print("InputManager3D: Ground tapped at \(groundPos2D)")

        // For now, just notify about ground click
        onGroundClicked?(position)
    }

    // MARK: - Camera Controls

    func handlePan(_ translation: Vector2, screenSize: Vector2) {
        guard let camera = camera else { return }

        let sensitivity: Float = 0.005

        if camera.mode == .orbital || camera.mode == .thirdPerson {
            // Orbit camera
            camera.rotate(
                yawDelta: translation.x * sensitivity,
                pitchDelta: -translation.y * sensitivity
            )
        } else {
            // Free camera - look around
            camera.rotate(
                yawDelta: translation.x * sensitivity,
                pitchDelta: -translation.y * sensitivity
            )
        }
    }

    func handlePinch(_ scale: Float) {
        guard let camera = camera else { return }

        let zoomAmount = (1.0 - scale) * 2.0
        camera.zoom(amount: zoomAmount)
    }

    // MARK: - Data Structures

    struct Ray {
        var origin: Vector3
        var direction: Vector3
    }

    struct RaycastResult {
        enum ResultType {
            case ground
            case entity
        }

        var type: ResultType
        var position: Vector3
        var distance: Float
        var entity: Entity?
    }

    struct GroundHit {
        var position: Vector3
        var distance: Float
    }

    struct BoxHit {
        var position: Vector3
        var distance: Float
    }

    struct BoundingBox {
        var center: Vector3
        var halfSize: Vector3
    }
}