import Foundation
import UIKit

/// Virtual joystick for player movement
final class VirtualJoystick {
    // Scale factor
    private let scale: Float = Float(UIScreen.main.scale)
    
    // Joystick dimensions (in points, will be scaled)
    private let baseRadiusPoints: Float = 70
    private let stickRadiusPoints: Float = 30
    private let marginPoints: Float = 40
    
    // Scaled dimensions
    var baseRadius: Float { baseRadiusPoints * scale }  // Made internal for touch detection
    private var stickRadius: Float { stickRadiusPoints * scale }
    private var margin: Float { marginPoints * scale }
    
    // Position - stored, updated on render
    private var screenSize: Vector2
    private var _baseCenter: Vector2
    private var stickCenter: Vector2
    
    // Expose for touch detection
    var baseCenter: Vector2 {
        return _baseCenter
    }
    
    // State
    private(set) var isActive: Bool = false
    private(set) var direction: Vector2 = .zero
    
    // Dead zone (percentage of base radius)
    private let deadZone: Float = 0.1
    
    // Callback
    var onDirectionChanged: ((Vector2) -> Void)?
    
    init() {
        // Get initial screen size - use landscape dimensions
        let screenScale = Float(UIScreen.main.scale)
        let width = Float(UIScreen.main.bounds.width) * screenScale
        let height = Float(UIScreen.main.bounds.height) * screenScale
        
        // Ensure landscape (width > height)
        screenSize = Vector2(max(width, height), min(width, height))
        
        // Calculate initial position (bottom-left corner, top-left origin)
        let baseR = baseRadiusPoints * screenScale
        let m = marginPoints * screenScale
        // Position at bottom-left: x = margin + radius, y = screenHeight - margin - radius
        _baseCenter = Vector2(m + baseR, screenSize.y - m - baseR)
        stickCenter = _baseCenter
    }
    
    func updateScreenSize(_ newSize: Vector2) {
        // Only update if screen size actually changed
        guard newSize.x != screenSize.x || newSize.y != screenSize.y else { return }
        
        screenSize = newSize
        
        // Recalculate joystick position (bottom-left corner, top-left origin coordinates)
        // screenSize.y - margin - baseRadius puts it at the bottom
        let newBaseCenter = Vector2(margin + baseRadius, screenSize.y - margin - baseRadius)
        
        // If joystick is active, adjust stickCenter by the difference to maintain relative position
        if isActive {
            let offset = stickCenter - _baseCenter
            stickCenter = newBaseCenter + offset
        } else {
            stickCenter = newBaseCenter
        }
        
        _baseCenter = newBaseCenter
    }
    
    // MARK: - Touch Handling
    
    func handleTouchBegan(at position: Vector2, touchId: Int) -> Bool {
        // Reset state first (in case it was left in a bad state)
        isActive = false
        stickCenter = _baseCenter
        direction = .zero

        // Check if touch is within the joystick activation area
        let activationRadius = baseRadius * 1.5
        let distance = (position - _baseCenter).length

        if distance <= activationRadius {
            isActive = true
            // When touch begins, set stick to touch position (might be outside base)
            stickCenter = position
            // Clamp to base radius
            let offset = stickCenter - _baseCenter
            let dist = offset.length
            if dist > baseRadius {
                stickCenter = _baseCenter + offset * (baseRadius / dist)
            }
            updateDirection()
            return true
        }

        return false
    }
    
    func handleTouchMoved(at position: Vector2, touchId: Int) {
        guard isActive else { return }
        
        // Calculate offset from base center to touch position
        let offset = position - _baseCenter
        let distance = offset.length
        
        // Clamp stick to base radius
        if distance > baseRadius {
            stickCenter = _baseCenter + offset * (baseRadius / distance)
        } else {
            stickCenter = position
        }
        
        updateDirection()
    }
    
    func handleTouchEnded(touchId: Int) {
        isActive = false
        stickCenter = _baseCenter
        direction = .zero
        onDirectionChanged?(.zero)
    }
    
    private func updateDirection() {
        let offset = stickCenter - _baseCenter
        let distance = offset.length
        let maxDistance = baseRadius
        
        if distance > 0.001 {
            let normalizedDistance = min(distance / maxDistance, 1.0)
            
            if normalizedDistance > deadZone {
                let magnitude = (normalizedDistance - deadZone) / (1.0 - deadZone)
                
                // Normalize offset to get direction vector
                let normalizedX = offset.x / distance
                let normalizedY = offset.y / distance
                
                // Convert from screen coordinates to world coordinates
                // Screen: (0,0) top-left, Y increases downward
                // World: Y increases upward, X increases right
                // X is correct as-is, Y needs negation (screen Y down -> world Y up)
                direction = Vector2(normalizedX, -normalizedY) * magnitude
            } else {
                direction = .zero
            }
        } else {
            direction = .zero
        }
        
        onDirectionChanged?(direction)
    }
    
    // MARK: - Rendering
    
    func render(renderer: MetalRenderer) {
        // Update screen size and positions
        updateScreenSize(renderer.screenSize)
        
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        
        // Render outer ring (base)
        renderer.queueSprite(SpriteInstance(
            position: _baseCenter,
            size: Vector2(baseRadius * 2, baseRadius * 2),
            textureRect: solidRect,
            color: Color(r: 0.2, g: 0.2, b: 0.3, a: isActive ? 0.7 : 0.4),
            layer: .ui
        ))
        
        // Render inner area
        let innerSize = baseRadius * 1.5
        renderer.queueSprite(SpriteInstance(
            position: _baseCenter,
            size: Vector2(innerSize, innerSize),
            textureRect: solidRect,
            color: Color(r: 0.15, g: 0.15, b: 0.25, a: isActive ? 0.5 : 0.3),
            layer: .ui
        ))
        
        // Render stick
        renderer.queueSprite(SpriteInstance(
            position: stickCenter,
            size: Vector2(stickRadius * 2, stickRadius * 2),
            textureRect: solidRect,
            color: Color(r: 0.6, g: 0.6, b: 0.7, a: isActive ? 1.0 : 0.6),
            layer: .ui
        ))
        
        // Render direction indicator when active
        if isActive && direction.lengthSquared > 0.01 {
            let indicatorSize = stickRadius * 0.4
            let indicatorOffset = direction.normalized * (stickRadius - indicatorSize)
            renderer.queueSprite(SpriteInstance(
                position: stickCenter + indicatorOffset,
                size: Vector2(indicatorSize, indicatorSize),
                textureRect: solidRect,
                color: Color(r: 0.9, g: 0.9, b: 1.0, a: 1.0),
                layer: .ui
            ))
        }
    }
    
    // MARK: - Properties
    
    var frame: Rect {
        let size = baseRadius * 3
        return Rect(center: _baseCenter, size: Vector2(size, size))
    }
}
