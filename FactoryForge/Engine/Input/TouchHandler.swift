import UIKit

/// Low-level touch tracking for custom touch handling
final class TouchHandler {
    struct Touch {
        let id: Int
        var position: Vector2
        var previousPosition: Vector2
        var startPosition: Vector2
        var startTime: TimeInterval
        var phase: UITouch.Phase
        
        var delta: Vector2 {
            return position - previousPosition
        }
        
        var totalDelta: Vector2 {
            return position - startPosition
        }
        
        var duration: TimeInterval {
            return CACurrentMediaTime() - startTime
        }
    }
    
    private var activeTouches: [Int: Touch] = [:]
    private var nextTouchId = 0
    
    var touchCount: Int {
        return activeTouches.count
    }
    
    var touches: [Touch] {
        return Array(activeTouches.values)
    }
    
    var primaryTouch: Touch? {
        return activeTouches.values.min { $0.id < $1.id }
    }
    
    var secondaryTouch: Touch? {
        let sorted = activeTouches.values.sorted { $0.id < $1.id }
        return sorted.count > 1 ? sorted[1] : nil
    }
    
    /// Distance between two fingers
    var pinchDistance: Float? {
        guard let primary = primaryTouch, let secondary = secondaryTouch else {
            return nil
        }
        return primary.position.distance(to: secondary.position)
    }
    
    /// Center point between two fingers
    var pinchCenter: Vector2? {
        guard let primary = primaryTouch, let secondary = secondaryTouch else {
            return nil
        }
        return (primary.position + secondary.position) * 0.5
    }
    
    func processTouches(_ touches: Set<UITouch>, in view: UIView) {
        let scale = Float(UIScreen.main.scale)
        
        for touch in touches {
            let position = Vector2(
                Float(touch.location(in: view).x) * scale,
                Float(touch.location(in: view).y) * scale
            )
            let previousPosition = Vector2(
                Float(touch.previousLocation(in: view).x) * scale,
                Float(touch.previousLocation(in: view).y) * scale
            )
            
            switch touch.phase {
            case .began:
                let touchId = nextTouchId
                nextTouchId += 1
                
                activeTouches[touch.hash] = Touch(
                    id: touchId,
                    position: position,
                    previousPosition: position,
                    startPosition: position,
                    startTime: CACurrentMediaTime(),
                    phase: .began
                )
                
            case .moved:
                if var tracked = activeTouches[touch.hash] {
                    tracked.previousPosition = tracked.position
                    tracked.position = position
                    tracked.phase = .moved
                    activeTouches[touch.hash] = tracked
                }
                
            case .ended, .cancelled:
                activeTouches.removeValue(forKey: touch.hash)
                
            default:
                break
            }
        }
    }
    
    func reset() {
        activeTouches.removeAll()
    }
}

// MARK: - Gesture Detection

extension TouchHandler {
    /// Detects if the current gesture looks like a tap
    func isTapGesture(maxDuration: TimeInterval = 0.3, maxDistance: Float = 10) -> Bool {
        guard let touch = primaryTouch else { return false }
        return touch.duration < maxDuration && touch.totalDelta.length < maxDistance
    }
    
    /// Detects if the current gesture looks like a swipe
    func isSwipeGesture(minDistance: Float = 50, maxDuration: TimeInterval = 0.5) -> Direction? {
        guard let touch = primaryTouch else { return nil }
        guard touch.duration < maxDuration else { return nil }
        
        let delta = touch.totalDelta
        guard delta.length > minDistance else { return nil }
        
        let angle = atan2f(delta.y, delta.x)
        
        if abs(angle) < .pi / 4 {
            return .east
        } else if abs(angle) > .pi * 3 / 4 {
            return .west
        } else if angle > 0 {
            return .south
        } else {
            return .north
        }
    }
    
    /// Detects pinch scale change
    func pinchScale(previousDistance: Float) -> Float? {
        guard let currentDistance = pinchDistance else { return nil }
        guard previousDistance > 0 else { return nil }
        return currentDistance / previousDistance
    }
}

