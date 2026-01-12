import Foundation
import QuartzCore

/// Manages game time and frame timing
final class Time {
    static let shared = Time()
    
    /// Time since the game started (in seconds)
    private(set) var totalTime: Float = 0
    
    /// Time elapsed since last frame (in seconds)
    private(set) var deltaTime: Float = 0
    
    /// Fixed timestep for physics updates (in seconds)
    let fixedDeltaTime: Float = 1.0 / 60.0
    
    /// Accumulated time for fixed updates
    private var accumulator: Float = 0
    
    /// Current frame number
    private(set) var frameCount: UInt64 = 0
    
    /// Time scale (1.0 = normal, 0.0 = paused)
    var timeScale: Float = 1.0
    
    /// Whether the game is paused
    var isPaused: Bool {
        get { timeScale == 0 }
        set { timeScale = newValue ? 0 : 1 }
    }
    
    /// Unscaled delta time (not affected by timeScale)
    private(set) var unscaledDeltaTime: Float = 0
    
    /// Last frame timestamp
    private var lastFrameTime: CFTimeInterval = 0
    
    /// Maximum delta time to prevent spiral of death
    private let maxDeltaTime: Float = 1.0/30.0
    
    private init() {
        lastFrameTime = CACurrentMediaTime()
    }
    
    /// Updates time values. Called once per frame.
    func update() {
        let currentTime = CACurrentMediaTime()
        unscaledDeltaTime = min(Float(currentTime - lastFrameTime), maxDeltaTime)
        lastFrameTime = currentTime
        
        deltaTime = unscaledDeltaTime * timeScale
        totalTime += deltaTime
        frameCount += 1
        
        accumulator += deltaTime
    }
    
    /// Consumes a fixed timestep if available
    /// - Returns: true if a fixed update should be performed
    func consumeFixedUpdate() -> Bool {
        if accumulator >= fixedDeltaTime {
            accumulator -= fixedDeltaTime
            return true
        }
        return false
    }
    
    /// The interpolation factor for rendering between fixed updates
    var fixedUpdateAlpha: Float {
        return accumulator / fixedDeltaTime
    }
    
    /// Frames per second (smoothed)
    var fps: Float {
        return unscaledDeltaTime > 0 ? 1.0 / unscaledDeltaTime : 0
    }
    
    /// Resets time state (used when loading a game)
    func reset() {
        totalTime = 0
        deltaTime = 0
        accumulator = 0
        frameCount = 0
        lastFrameTime = CACurrentMediaTime()
    }
}

// MARK: - Timer
final class GameTimer {
    private var duration: Float
    private var elapsed: Float = 0
    private var isRepeating: Bool
    private var action: (() -> Void)?
    
    var isComplete: Bool { elapsed >= duration }
    var progress: Float { min(elapsed / duration, 1.0) }
    var remaining: Float { max(duration - elapsed, 0) }
    
    init(duration: Float, repeating: Bool = false, action: (() -> Void)? = nil) {
        self.duration = duration
        self.isRepeating = repeating
        self.action = action
    }
    
    func update(deltaTime: Float) {
        guard !isComplete || isRepeating else { return }
        
        elapsed += deltaTime
        
        if elapsed >= duration {
            action?()
            if isRepeating {
                elapsed = elapsed.truncatingRemainder(dividingBy: duration)
            }
        }
    }
    
    func reset() {
        elapsed = 0
    }
    
    func reset(newDuration: Float) {
        duration = newDuration
        elapsed = 0
    }
}

// MARK: - Cooldown
struct Cooldown {
    private var cooldownTime: Float
    private var lastTriggerTime: Float = -Float.infinity
    
    var isReady: Bool {
        return Time.shared.totalTime - lastTriggerTime >= cooldownTime
    }
    
    var progress: Float {
        let elapsed = Time.shared.totalTime - lastTriggerTime
        return min(elapsed / cooldownTime, 1.0)
    }
    
    init(cooldown: Float) {
        self.cooldownTime = cooldown
    }
    
    mutating func trigger() -> Bool {
        if isReady {
            lastTriggerTime = Time.shared.totalTime
            return true
        }
        return false
    }
    
    mutating func reset() {
        lastTriggerTime = -Float.infinity
    }
    
    mutating func setCooldown(_ cooldown: Float) {
        cooldownTime = cooldown
    }
}

