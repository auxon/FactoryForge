//
//  FluidIndicator.swift
//  FactoryForge
//
//  Created by Richard Anthony Hein on 2026-01-15.
//
import Foundation
import UIKit

/// Visual indicator for fluid inputs/outputs in machine UI
final class FluidIndicator {
    let frame: Rect
    let isInput: Bool
    var isProducer: Bool = false  // True for production indicators, false for tanks
    var fluidType: FluidType?
    var amount: Float = 0
    var maxAmount: Float = 0
    var hasConnection: Bool = false

    init(frame: Rect, isInput: Bool) {
        self.frame = frame
        self.isInput = isInput
    }

    func render(renderer: MetalRenderer) {
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")

        // Container border (behind everything) - only for tanks, white for visibility
        if !isInput && !isProducer {
            let borderThickness: Float = 1.5
            renderer.queueSprite(SpriteInstance(
                position: frame.center,
                size: frame.size + Vector2(borderThickness * 2, borderThickness * 2),
                textureRect: solidRect,
                color: Color(r: 1.0, g: 1.0, b: 1.0, a: 1.0), // White border for visibility
                layer: .ui
            ))
        }

        // Background circle - brighter for tanks to make them more visible
        let bgColor = (!isInput && !isProducer) ?
            Color(r: 0.4, g: 0.4, b: 0.4, a: 0.8) : // Brighter background for tanks
            (hasConnection ? Color(r: 0.35, g: 0.35, b: 0.35, a: 0.85) : Color(r: 0.25, g: 0.25, b: 0.25, a: 0.6))
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: solidRect,
            color: bgColor,
            layer: .ui
        ))

        // Fluid fill indicator
        if let fluidType = fluidType, maxAmount > 0 {
            let fillLevel = amount / maxAmount
            let fluidColor = getFluidColor(fluidType)

            if isInput {
                // Input: show connection status with colored ring
                if hasConnection {
                    let ringThickness: Float = 3
                    let innerSize = frame.size - Vector2(ringThickness * 2, ringThickness * 2)
                    renderer.queueSprite(SpriteInstance(
                        position: frame.center,
                        size: innerSize,
                        textureRect: solidRect,
                        color: fluidColor.withAlpha(0.7),
                        layer: .ui
                    ))
                }
            } else {
                if isProducer {
                    // Producer (steam): show activity with enhanced temporal instability for gas perception
                    let activityLevel = min(fillLevel, 1.0) // Cap at 1.0

                    // Enhanced temporal effects for gas-like appearance
                    let time = Float(CACurrentMediaTime())
                    let slowFlicker = sin(time * 2.0) * 0.08 + 0.92 // ±8% slow modulation
                    let fastFlicker = sin(time * 8.0) * 0.05 + 0.95 // ±5% fast noise
                    let combinedFlicker = slowFlicker * fastFlicker

                    let baseAlpha = 0.4 + activityLevel * 0.4
                    let pulseColor = Color(r: 0.85, g: 0.9, b: 0.95, a: baseAlpha * combinedFlicker)

                    // Draw animated steam overlay with subtle vertical drift
                    let driftOffset = sin(time * 1.5) * 0.5 // ±0.5 px vertical movement
                    let driftPos = Vector2(frame.center.x, frame.center.y + driftOffset)

                    renderer.queueSprite(SpriteInstance(
                        position: driftPos,
                        size: frame.size,
                        textureRect: solidRect,
                        color: pulseColor,
                        layer: .ui
                    ))

                    // Add wispy steam layers with entropy
                    if activityLevel > 0.1 {
                        let steamLayers = 4 // More layers for richer effect
                        for i in 0..<steamLayers {
                            let layerOffset = Float(i) * 1.2
                            let layerSize = frame.size - Vector2(layerOffset * 2, layerOffset * 2)
                            let layerDrift = sin(time * (1.0 + Float(i) * 0.3)) * 0.8
                            let layerPos = Vector2(frame.center.x, frame.center.y + layerDrift)

                            let layerAlpha = 0.15 * activityLevel * (1.0 - Float(i) / Float(steamLayers)) * combinedFlicker
                            let layerColor = Color(r: 0.75, g: 0.85, b: 0.95, a: layerAlpha)

                            renderer.queueSprite(SpriteInstance(
                                position: layerPos,
                                size: layerSize,
                                textureRect: solidRect,
                                color: layerColor,
                                layer: .ui
                            ))
                        }

                        // Add diffuse particle cloud for gas phase
                        let particleCount = 8
                        for i in 0..<particleCount {
                            let angle = Float(i) * (2 * Float.pi / Float(particleCount)) + time * 1.2
                            let radius = frame.size.x * 0.25 + sin(time * 3.0 + Float(i)) * 3.0
                            let particleX = frame.center.x + cos(angle) * radius
                            let particleY = frame.center.y + sin(angle) * radius

                            let particleSize: Float = 1.0 + sin(time * 4.0 + Float(i) * 0.5) * 0.5
                            let particleAlpha = 0.3 * activityLevel * combinedFlicker * (0.5 + 0.5 * sin(time * 2.0 + Float(i)))
                            let particleColor = Color(r: 0.9, g: 0.95, b: 1.0, a: particleAlpha)

                            renderer.queueSprite(SpriteInstance(
                                position: Vector2(particleX, particleY),
                                size: Vector2(particleSize, particleSize),
                                textureRect: solidRect,
                                color: particleColor,
                                layer: .ui
                            ))
                        }
                    }
                } else {
                    // Tank: show fill level with nonlinear scaling for better low-volume perception
                    // Use square root scaling to amplify small fill differences: r_visual = sqrt(r)
                    let visualFillLevel = sqrt(fillLevel)
                    let minFillHeight: Float = 3.0 // Slightly larger minimum for visibility
                    let rawFillHeight = frame.size.y * visualFillLevel
                    let fillHeight = max(rawFillHeight, fillLevel > 0 ? minFillHeight : 0)
                    let fillSize = Vector2(frame.size.x, fillHeight)
                    let fillPos = Vector2(frame.center.x, frame.maxY - fillHeight/2)

                    // Enhanced gradient: empty (very dark) → full (bright fluid + luminance boost)
                    let emptyColor = Color(r: 0.08, g: 0.08, b: 0.08, a: 0.9) // Much darker empty
                    let fullColor = Color(
                        r: min(fluidColor.r * 1.2, 1.0), // Boosted brightness
                        g: min(fluidColor.g * 1.2, 1.0),
                        b: min(fluidColor.b * 1.2, 1.0),
                        a: 0.95
                    )
                    let fillColor = Color(
                        r: emptyColor.r + (fullColor.r - emptyColor.r) * visualFillLevel,
                        g: emptyColor.g + (fullColor.g - emptyColor.g) * visualFillLevel,
                        b: emptyColor.b + (fullColor.b - emptyColor.b) * visualFillLevel,
                        a: emptyColor.a + (fullColor.a - emptyColor.a) * visualFillLevel
                    )

                    // Add container depth with enhanced micro-contrast
                    let wellInset: Float = 2.0
                    let wellSize = frame.size - Vector2(wellInset * 2, wellInset * 2)
                    renderer.queueSprite(SpriteInstance(
                        position: frame.center,
                        size: wellSize,
                        textureRect: solidRect,
                        color: Color(r: 0.14, g: 0.14, b: 0.14, a: 0.9), // Enhanced well contrast
                        layer: .ui
                    ))

                    // Add inner bevel for material definition
                    let bevelInset: Float = 1.0
                    let bevelSize = wellSize - Vector2(bevelInset * 2, bevelInset * 2)
                    renderer.queueSprite(SpriteInstance(
                        position: frame.center,
                        size: bevelSize,
                        textureRect: solidRect,
                        color: Color(r: 0.2, g: 0.2, b: 0.2, a: 0.7), // Lighter inner bevel
                        layer: .ui
                    ))

                    // Draw fill on top with enhanced visibility
                    renderer.queueSprite(SpriteInstance(
                        position: fillPos,
                        size: fillSize,
                        textureRect: solidRect,
                        color: fillColor,
                        layer: .ui
                    ))

                    // Add liquid-like highlights for water with better visibility
                    if fluidType == .water && visualFillLevel > 0.15 {
                        let highlightWidth: Float = fillSize.x * 0.7
                        let highlightHeight: Float = 4.0
                        let highlightPos = Vector2(fillPos.x, fillPos.y - fillHeight/2 + highlightHeight/2 + 3)

                        renderer.queueSprite(SpriteInstance(
                            position: highlightPos,
                            size: Vector2(highlightWidth, highlightHeight),
                            textureRect: solidRect,
                            color: Color(r: 0.9, g: 0.95, b: 1.0, a: 0.4), // More visible highlight
                            layer: .ui
                        ))
                    }
                }
            }
        }

        // Connection indicator dot
        if hasConnection {
            let dotSize: Float = 6
            let dotOffset: Float = frame.size.x * 0.35
            let dotPos = isInput ?
                Vector2(frame.center.x - dotOffset, frame.center.y) : // Left side for inputs
                Vector2(frame.center.x + dotOffset, frame.center.y)   // Right side for outputs

            renderer.queueSprite(SpriteInstance(
                position: dotPos,
                size: Vector2(dotSize, dotSize),
                textureRect: solidRect,
                color: Color(r: 0.9, g: 0.9, b: 0.2, a: 1.0), // Yellow dot
                layer: .ui
            ))

            // Add directional flow hint for producers (steam flowing to tanks)
            if isProducer && hasConnection {
                let arrowSize: Float = 4
                let arrowOffset: Float = frame.size.x * 0.45
                let arrowPos = Vector2(frame.center.x + arrowOffset, frame.center.y)

                // Simple arrow pointing right (toward tanks)
                renderer.queueSprite(SpriteInstance(
                    position: arrowPos,
                    size: Vector2(arrowSize, arrowSize),
                    textureRect: solidRect,
                    color: Color(r: 0.7, g: 0.9, b: 1.0, a: 0.6), // Light blue arrow
                    layer: .ui
                ))

                // Add subtle connecting glow line to suggest flow continuity
                let glowLength: Float = 30
                let glowWidth: Float = 2
                let glowPos = Vector2(frame.center.x + frame.size.x/2 + glowLength/2, frame.center.y)

                renderer.queueSprite(SpriteInstance(
                    position: glowPos,
                    size: Vector2(glowLength, glowWidth),
                    textureRect: solidRect,
                    color: Color(r: 0.6, g: 0.8, b: 0.9, a: 0.4), // Subtle connecting glow
                    layer: .ui
                ))
            }
        }
    }

    private func getFluidColor(_ fluidType: FluidType) -> Color {
        switch fluidType {
        case .water:
            return Color(r: 0.2, g: 0.4, b: 0.9, a: 1.0)  // Blue
        case .steam:
            return Color(r: 0.8, g: 0.8, b: 0.9, a: 0.7)  // Light blue-gray
        case .crudeOil:
            return Color(r: 0.3, g: 0.2, b: 0.1, a: 1.0)  // Dark brown
        case .heavyOil:
            return Color(r: 0.4, g: 0.3, b: 0.2, a: 1.0)  // Brown
        case .lightOil:
            return Color(r: 0.5, g: 0.4, b: 0.2, a: 1.0)  // Light brown
        case .petroleumGas:
            return Color(r: 0.9, g: 0.8, b: 0.2, a: 0.6)  // Yellow gas
        case .sulfuricAcid:
            return Color(r: 0.9, g: 0.9, b: 0.1, a: 1.0)  // Yellow
        case .lubricant:
            return Color(r: 0.6, g: 0.5, b: 0.3, a: 1.0)  // Tan
        }
    }
}
