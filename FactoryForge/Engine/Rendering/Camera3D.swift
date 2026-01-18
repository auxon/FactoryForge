import Foundation
import QuartzCore

/// 3D Camera system for FactoryForge - handles positioning, rotation, and projection
@available(iOS 17.0, *)
final class Camera3D {
    // MARK: - Camera Properties

    // Position and orientation
    var position: Vector3 = Vector3(0, 10, 10)
    var target: Vector3 = Vector3(0, 0, 0)  // Look-at target
    var up: Vector3 = Vector3(0, 1, 0)

    // Euler angles (for FPS-style controls)
    var yaw: Float = -.pi / 4    // Rotation around Y axis (left/right)
    var pitch: Float = -.pi / 6  // Rotation around X axis (up/down)
    var roll: Float = 0          // Rotation around Z axis

    // Camera settings
    var fieldOfView: Float = .pi / 3  // 60 degrees
    var aspectRatio: Float = 16.0 / 9.0
    var nearPlane: Float = 0.1
    var farPlane: Float = 1000.0

    // Movement settings
    var moveSpeed: Float = 20.0
    var rotationSpeed: Float = 2.0
    var zoomSpeed: Float = 10.0

    // Distance from target (for orbital/third-person controls)
    var distance: Float = 15.0
    var minDistance: Float = 2.0
    var maxDistance: Float = 100.0

    // Smooth movement
    private var targetPosition: Vector3 = Vector3(0, 10, 10)
    private var targetYaw: Float = -.pi / 4
    private var targetPitch: Float = -.pi / 6
    private var targetDistance: Float = 15.0

    // Damping for smooth movement
    private let positionDamping: Float = 5.0
    private let rotationDamping: Float = 8.0
    private let zoomDamping: Float = 6.0

    // MARK: - Computed Properties

    var forward: Vector3 {
        // Calculate forward vector from yaw and pitch
        let cosYaw = cosf(yaw)
        let sinYaw = sinf(yaw)
        let cosPitch = cosf(pitch)
        let sinPitch = sinf(pitch)

        return Vector3(
            cosYaw * cosPitch,
            sinPitch,
            sinYaw * cosPitch
        ).normalized
    }

    var right: Vector3 {
        return forward.cross(up).normalized
    }

    var viewMatrix: Matrix4 {
        // Create view matrix from position, target, and up vector
        let targetPos = position + forward
        return Matrix4.lookAt(eye: position, center: targetPos, up: up)
    }

    var projectionMatrix: Matrix4 {
        return Matrix4.perspective(
            fovY: fieldOfView,
            aspect: aspectRatio,
            near: nearPlane,
            far: farPlane
        )
    }

    var viewProjectionMatrix: Matrix4 {
        return projectionMatrix * viewMatrix
    }

    // MARK: - Camera Modes

    enum CameraMode {
        case free         // Full 6DOF movement
        case orbital      // Orbit around target point
        case firstPerson  // FPS-style movement
        case thirdPerson  // Follow target with distance
    }

    var mode: CameraMode = .orbital

    // MARK: - Initialization

    init() {
        // Set initial target position to match current position calculations
        updateTargetPosition()
    }

    // MARK: - Update

    func update(deltaTime: Float) {
        // Smooth movement interpolation
        let positionT = min(deltaTime * positionDamping, 1.0)
        let rotationT = min(deltaTime * rotationDamping, 1.0)
        let zoomT = min(deltaTime * zoomDamping, 1.0)

        // Interpolate position
        position = position.lerp(to: targetPosition, t: positionT)

        // Interpolate rotation
        yaw = lerpAngle(current: yaw, target: targetYaw, t: rotationT)
        pitch = lerpAngle(current: pitch, target: targetPitch, t: rotationT)

        // Interpolate distance/zoom
        distance = distance.lerp(to: targetDistance, t: zoomT)

        // Clamp values
        pitch = pitch.clamped(to: -.pi/2 + 0.1 ... .pi/2 - 0.1)  // Prevent camera flipping
        distance = distance.clamped(to: minDistance ... maxDistance)

        // Update position based on mode
        switch mode {
        case .orbital, .thirdPerson:
            updateOrbitalPosition()
        case .free, .firstPerson:
            // Position is set directly for free/first-person modes
            break
        }
    }

    private func updateOrbitalPosition() {
        // Calculate position based on target, distance, yaw, and pitch
        let cosYaw = cosf(yaw)
        let sinYaw = sinf(yaw)
        let cosPitch = cosf(pitch)
        let sinPitch = sinf(pitch)

        position.x = target.x + distance * cosYaw * cosPitch
        position.y = target.y + distance * sinPitch
        position.z = target.z + distance * sinYaw * cosPitch
    }

    private func updateTargetPosition() {
        targetPosition = position
        targetYaw = yaw
        targetPitch = pitch
        targetDistance = distance
    }

    // MARK: - Movement Controls

    func moveForward(amount: Float) {
        let delta = forward * amount * moveSpeed
        targetPosition += delta
        if mode == .orbital || mode == .thirdPerson {
            target += delta
        }
    }

    func moveRight(amount: Float) {
        let delta = right * amount * moveSpeed
        targetPosition += delta
        if mode == .orbital || mode == .thirdPerson {
            target += delta
        }
    }

    func moveUp(amount: Float) {
        let delta = up * amount * moveSpeed
        targetPosition += delta
        if mode == .orbital || mode == .thirdPerson {
            target += delta
        }
    }

    func rotate(yawDelta: Float, pitchDelta: Float) {
        targetYaw += yawDelta * rotationSpeed
        targetPitch += pitchDelta * rotationSpeed

        // Normalize yaw to keep it in reasonable range
        while targetYaw > .pi * 2 { targetYaw -= .pi * 2 }
        while targetYaw < -.pi * 2 { targetYaw += .pi * 2 }
    }

    func zoom(amount: Float) {
        targetDistance -= amount * zoomSpeed
    }

    func setTarget(_ newTarget: Vector3) {
        target = newTarget
        if mode == .orbital || mode == .thirdPerson {
            updateOrbitalPosition()
        }
    }

    func setPosition(_ newPosition: Vector3) {
        position = newPosition
        targetPosition = newPosition
        updateTargetPosition()
    }

    func setRotation(yaw: Float, pitch: Float) {
        self.yaw = yaw
        self.pitch = pitch
        targetYaw = yaw
        targetPitch = pitch
        updateTargetPosition()
    }

    func setDistance(_ newDistance: Float) {
        distance = newDistance
        targetDistance = newDistance
        updateTargetPosition()
    }

    func setAspectRatio(_ ratio: Float) {
        aspectRatio = ratio
    }

    // MARK: - Camera Utilities

    func screenToWorld(screenPoint: Vector2, screenSize: Vector2) -> Vector3? {
        // Convert screen coordinates to normalized device coordinates (-1 to 1)
        let ndc = Vector2(
            (screenPoint.x / screenSize.x) * 2 - 1,
            (1 - screenPoint.y / screenSize.y) * 2 - 1  // Flip Y axis
        )

        // Create ray in world space
        let viewProjectionInverse = viewProjectionMatrix.inverse

        // Near plane point
        let nearPoint = Vector4(ndc.x, ndc.y, 0, 1)
        let nearWorld = viewProjectionInverse * nearPoint
        let nearWorldPos = Vector3(nearWorld.x / nearWorld.w, nearWorld.y / nearWorld.w, nearWorld.z / nearWorld.w)

        // Far plane point
        let farPoint = Vector4(ndc.x, ndc.y, 1, 1)
        let farWorld = viewProjectionInverse * farPoint
        let farWorldPos = Vector3(farWorld.x / farWorld.w, farWorld.y / farWorld.w, farWorld.z / farWorld.w)

        // Ray direction
        let rayDirection = (farWorldPos - nearWorldPos).normalized

        // For now, intersect with ground plane (y = 0)
        // In a full implementation, you'd do proper raycasting against terrain/meshes
        let groundPlaneY = Float(0)
        let t = (groundPlaneY - nearWorldPos.y) / rayDirection.y

        if t > 0 {
            let intersection = nearWorldPos + rayDirection * t
            return intersection
        }

        return nil
    }

    func worldToScreen(worldPoint: Vector3, screenSize: Vector2) -> Vector2? {
        // Transform world point to clip space
        let worldPos4 = Vector4(worldPoint.x, worldPoint.y, worldPoint.z, 1)
        let clipPos = viewProjectionMatrix * worldPos4

        // Check if point is behind camera
        if clipPos.w <= 0 {
            return nil
        }

        // Convert to normalized device coordinates
        let ndc = Vector3(
            clipPos.x / clipPos.w,
            clipPos.y / clipPos.w,
            clipPos.z / clipPos.w
        )

        // Convert to screen coordinates
        let screenX = (ndc.x + 1) * 0.5 * screenSize.x
        let screenY = (1 - ndc.y) * 0.5 * screenSize.y  // Flip Y axis

        return Vector2(screenX, screenY)
    }

    func getFrustumPlanes() -> [Vector4] {
        // Extract frustum planes from view-projection matrix
        let m = viewProjectionMatrix
        var planes: [Vector4] = []

        // Left plane
        planes.append(Vector4(
            m.m41 + m.m11,
            m.m42 + m.m12,
            m.m43 + m.m13,
            m.m44 + m.m14
        ))

        // Right plane
        planes.append(Vector4(
            m.m41 - m.m11,
            m.m42 - m.m12,
            m.m43 - m.m13,
            m.m44 - m.m14
        ))

        // Bottom plane
        planes.append(Vector4(
            m.m41 + m.m21,
            m.m42 + m.m22,
            m.m43 + m.m23,
            m.m44 + m.m24
        ))

        // Top plane
        planes.append(Vector4(
            m.m41 - m.m21,
            m.m42 - m.m22,
            m.m43 - m.m23,
            m.m44 - m.m24
        ))

        // Near plane
        planes.append(Vector4(
            m.m41 + m.m31,
            m.m42 + m.m32,
            m.m43 + m.m33,
            m.m44 + m.m34
        ))

        // Far plane
        planes.append(Vector4(
            m.m41 - m.m31,
            m.m42 - m.m32,
            m.m43 - m.m33,
            m.m44 - m.m34
        ))

        // Normalize planes
        for i in 0..<planes.count {
            let length = sqrtf(planes[i].x * planes[i].x +
                              planes[i].y * planes[i].y +
                              planes[i].z * planes[i].z)
            planes[i] = planes[i] / length
        }

        return planes
    }

    // MARK: - Utility Functions

    private func lerpAngle(current: Float, target: Float, t: Float) -> Float {
        var delta = target - current

        // Handle angle wrapping
        while delta > .pi { delta -= .pi * 2 }
        while delta < -.pi { delta += .pi * 2 }

        return current + delta * t
    }
}

// MARK: - Transform3D

struct Transform3D {
    var position: Vector3 = .zero
    var rotation: Vector3 = .zero  // Euler angles in radians
    var scale: Vector3 = Vector3(1, 1, 1)

    var modelMatrix: Matrix4 {
        let translation = Matrix4.translation(position)
        let rotationX = Matrix4.rotationX(rotation.x)
        let rotationY = Matrix4.rotationY(rotation.y)
        let rotationZ = Matrix4.rotationZ(rotation.z)
        let scaling = Matrix4.scale(scale)

        return translation * rotationY * rotationX * rotationZ * scaling
    }

    var normalMatrix: Matrix3 {
        let rotationX = Matrix4.rotationX(rotation.x)
        let rotationY = Matrix4.rotationY(rotation.y)
        let rotationZ = Matrix4.rotationZ(rotation.z)
        let rotationMatrix = rotationY * rotationX * rotationZ

        // Extract 3x3 rotation matrix and invert/transpose for normals
        let normalMat = Matrix3(
            SIMD3(rotationMatrix.m11, rotationMatrix.m12, rotationMatrix.m13),
            SIMD3(rotationMatrix.m21, rotationMatrix.m22, rotationMatrix.m23),
            SIMD3(rotationMatrix.m31, rotationMatrix.m32, rotationMatrix.m33)
        )
        // Transpose the matrix manually (swap elements across diagonal)
        let transposed = Matrix3(
            SIMD3(normalMat.columns.0.x, normalMat.columns.1.x, normalMat.columns.2.x),
            SIMD3(normalMat.columns.0.y, normalMat.columns.1.y, normalMat.columns.2.y),
            SIMD3(normalMat.columns.0.z, normalMat.columns.1.z, normalMat.columns.2.z)
        )
        return transposed.inverse
    }
}