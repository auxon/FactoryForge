import Foundation

/// The biter enemy class with animation support
final class Biter {
    private var world: World
    private var entity: Entity

    /// The biter's entity (for external systems)
    var biterEntity: Entity { entity }

    /// Biter animations for different directions
    private var biterAnimationLeft: SpriteAnimation?
    private var biterAnimationRight: SpriteAnimation?

    init(world: World) {
        self.world = world
        self.entity = world.spawn()
        setupBiterEntity()
    }

    /// Recreates the biter entity (used when loading a game after world deserialization)
    func recreateEntity(in world: World) {
        self.world = world
        self.entity = world.spawn()
        setupBiterEntity()
    }

    private func setupBiterEntity() {
        // Set up biter entity
        world.add(PositionComponent(tilePosition: .zero), to: entity)

        // Create biter animation with all 16 frames for both directions
        let biterFramesRight = (0..<16).map { "biter_right_\($0)" }
        let biterFramesLeft = (0..<16).map { "biter_left_\($0)" }

        var biterAnimationRight = SpriteAnimation(
            frames: biterFramesRight,
            frameTime: 0.08,  // 80ms per frame for smooth walking animation
            isLooping: true
        )
        biterAnimationRight.pause()  // Start paused, will play when moving

        var biterAnimationLeft = SpriteAnimation(
            frames: biterFramesLeft,
            frameTime: 0.08,
            isLooping: true
        )
        biterAnimationLeft.pause()

        var spriteComponent = SpriteComponent(
            textureId: "biter_right_0",  // Default to first right frame
            size: Vector2(0.8, 0.8),     // Smaller than player
            tint: .white,
            layer: .enemy,
            centered: true
        )
        spriteComponent.animation = biterAnimationRight

        // Store references to both animations for switching directions
        self.biterAnimationRight = biterAnimationRight
        self.biterAnimationLeft = biterAnimationLeft

        world.add(spriteComponent, to: entity)
    }

    /// Update biter animation based on movement direction
    func updateAnimation(velocity: Vector2) {
        guard var sprite = world.get(SpriteComponent.self, for: entity) else { return }

        // Determine which animation to use based on horizontal movement
        let isMovingLeft = velocity.x < -0.1
        let isMovingRight = velocity.x > 0.1
        let isMoving = abs(velocity.x) > 0.1 || abs(velocity.y) > 0.1

        if isMoving {
            if isMovingLeft && sprite.animation?.frames.first != "biter_left_0" {
                // Switch to left animation
                if var leftAnim = biterAnimationLeft {
                    leftAnim.play()
                    sprite.animation = leftAnim
                    sprite.textureId = "biter_left_0"
                }
            } else if isMovingRight && sprite.animation?.frames.first != "biter_right_0" {
                // Switch to right animation
                if var rightAnim = biterAnimationRight {
                    rightAnim.play()
                    sprite.animation = rightAnim
                    sprite.textureId = "biter_right_0"
                }
            } else if !(sprite.animation?.isPlaying ?? true) {
                // Resume current animation if we started moving
                if var currentAnim = sprite.animation {
                    currentAnim.play()
                    sprite.animation = currentAnim
                }
            }
        } else {
            // Stop animation when not moving
            if var currentAnim = sprite.animation {
                currentAnim.pause()
                sprite.animation = currentAnim
            }
        }

        world.add(sprite, to: entity)
    }

    /// Get current position
    var position: Vector2 {
        get {
            return world.get(PositionComponent.self, for: entity)?.worldPosition ?? .zero
        }
        set {
            var pos = world.get(PositionComponent.self, for: entity) ?? PositionComponent(tilePosition: .zero)
            pos.tilePosition = IntVector2(from: newValue)
            pos.offset = Vector2(
                newValue.x - floorf(newValue.x),
                newValue.y - floorf(newValue.y)
            )
            world.add(pos, to: entity)
        }
    }

    /// Get current health
    var health: Float {
        world.get(HealthComponent.self, for: entity)?.current ?? 0
    }

    var maxHealth: Float {
        world.get(HealthComponent.self, for: entity)?.max ?? 0
    }

    /// Remove the biter entity
    func destroy() {
        world.despawn(entity)
    }
}
