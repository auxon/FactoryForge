import Foundation
import UIKit

// Use UIKit's UIButton explicitly to avoid conflict with custom UIButton
typealias UIKitButton = UIKit.UIButton

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

        // Container border (behind everything) - only for tanks, slightly brighter
        if !isInput && !isProducer {
            let borderThickness: Float = 1.5
            renderer.queueSprite(SpriteInstance(
                position: frame.center,
                size: frame.size + Vector2(borderThickness * 2, borderThickness * 2),
                textureRect: solidRect,
                color: Color(r: 0.08, g: 0.08, b: 0.08, a: 1.0), // Slightly brighter border
                layer: .ui
            ))
        }

        // Background circle - slightly brighter for better visual prominence
        let bgColor = hasConnection ? Color(r: 0.35, g: 0.35, b: 0.35, a: 0.85) : Color(r: 0.25, g: 0.25, b: 0.25, a: 0.6)
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

/// Protocol for machine UI components
protocol MachineUIComponent {
    func setupUI(for entity: Entity, in ui: MachineUI)
    func updateUI(for entity: Entity, in ui: MachineUI)
    func getLabels() -> [UILabel]
    func getScrollViews() -> [UIScrollView]
    func render(in renderer: MetalRenderer)
}

/// Callback type for recipe selection
typealias RecipeSelectionCallback = (Entity, Recipe) -> Void

/// Base implementation for common machine UI functionality
class BaseMachineUIComponent: MachineUIComponent {
    func setupUI(for entity: Entity, in ui: MachineUI) {
        // Common setup - override in subclasses
    }

    func updateUI(for entity: Entity, in ui: MachineUI) {
        // Common updates - override in subclasses
    }

    func getLabels() -> [UILabel] {
        return []
    }

    func getScrollViews() -> [UIScrollView] {
        return []
    }

    func render(in renderer: MetalRenderer) {
        // Common rendering - override in subclasses
    }
}

/// Component for fluid-based machines (boilers, steam engines)
class FluidMachineUIComponent: BaseMachineUIComponent {
    private var fluidInputIndicators: [FluidIndicator] = []
    private var fluidOutputIndicators: [FluidIndicator] = []
    private var fluidInputLabels: [UILabel] = []
    private var fluidOutputLabels: [UILabel] = []

    override func setupUI(for entity: Entity, in ui: MachineUI) {
        setupFluidIndicators(for: entity, in: ui)
        positionLabels(in: ui)
    }

    override func updateUI(for entity: Entity, in ui: MachineUI) {
        updateFluidIndicators(for: entity, in: ui)
    }

    override func getLabels() -> [UILabel] {
        let labels = fluidInputLabels + fluidOutputLabels
        print("FluidMachineUIComponent: Returning \(labels.count) labels (\(fluidInputLabels.count) input, \(fluidOutputLabels.count) output)")
        return labels
    }

    override func render(in renderer: MetalRenderer) {
        // Render all fluid indicators (producers, consumers, tanks)
        for indicator in fluidInputIndicators + fluidOutputIndicators {
            indicator.render(renderer: renderer)
        }
    }

    func positionLabels(in ui: MachineUI) {
        let scale = UIScreen.main.scale

        // Position all fluid labels (inputs and outputs)
        let allLabels = fluidInputLabels + fluidOutputLabels
        let allIndicators = fluidInputIndicators + fluidOutputIndicators

        for (index, label) in allLabels.enumerated() {
            guard index < allIndicators.count else { continue }
            let indicator = allIndicators[index]

            // Position label centered below the indicator
            let labelWidth: Float = 90  // Slightly smaller now that visuals are clearer
            let labelHeight: Float = 20  // Slightly smaller for better balance

            let labelX = indicator.frame.center.x - labelWidth/2
            let labelY = indicator.frame.center.y + indicator.frame.size.y/2 + 4

            // Convert to UIView coordinates
            let uiX = CGFloat(labelX) / scale
            let uiY = CGFloat(labelY) / scale

            label.frame = CGRect(x: uiX, y: uiY, width: CGFloat(labelWidth), height: CGFloat(labelHeight))
        }
    }

    private func setupFluidIndicators(for entity: Entity, in ui: MachineUI) {
        guard let gameLoop = ui.gameLoop else { return }

        let indicatorSize: Float = 40 * UIScale  // Match fuel slot size

        // Position fluid indicators centered vertically in the panel
        let fluidY = ui.frame.center.y

        var fluidIndex = 0

        // Check for fluid consumers (water input) - place first
        if gameLoop.world.get(FluidConsumerComponent.self, for: entity) != nil {
            let spacing: Float = 100 * UIScale  // Increased spacing between indicators
            let fluidX = ui.frame.center.x - 150 * UIScale + Float(fluidIndex) * spacing

            let inputFrame = Rect(center: Vector2(fluidX, fluidY), size: Vector2(indicatorSize, indicatorSize))
            let inputIndicator = FluidIndicator(frame: inputFrame, isInput: true)
            fluidInputIndicators.append(inputIndicator)

            let inputLabel = ui.createFluidLabel()
            fluidInputLabels.append(inputLabel)

            fluidIndex += 1
        }

        // Check for fluid producers (steam output) - place next
        if gameLoop.world.get(FluidProducerComponent.self, for: entity) != nil {
            let spacing: Float = 100 * UIScale  // Increased spacing between indicators
            let fluidX = ui.frame.center.x - 150 * UIScale + Float(fluidIndex) * spacing

            let outputFrame = Rect(center: Vector2(fluidX, fluidY), size: Vector2(indicatorSize, indicatorSize))
            let outputIndicator = FluidIndicator(frame: outputFrame, isInput: false)
            outputIndicator.isProducer = true
            fluidOutputIndicators.append(outputIndicator)

            let outputLabel = ui.createFluidLabel()
            fluidOutputLabels.append(outputLabel)

            fluidIndex += 1
        }

        // Check for fluid tanks - boilers have tanks for water buffer and steam buffer
        if let tank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
            let tankSpacing: Float = 80 * UIScale  // Vertical spacing between stacked tanks
            let tankBaseX = ui.frame.center.x - 150 * UIScale + Float(fluidIndex) * 120 * UIScale  // Align tanks with the steam indicator

            for (index, _) in tank.tanks.enumerated() {
                if index >= 2 { break } // Limit to 2 visible tanks

                let tankY = fluidY + Float(index) * tankSpacing
                let tankFrame = Rect(center: Vector2(tankBaseX, tankY), size: Vector2(indicatorSize, indicatorSize))
                let tankIndicator = FluidIndicator(frame: tankFrame, isInput: false) // Tanks show as outputs
                fluidOutputIndicators.append(tankIndicator)

                // Add label for tank
                let tankLabel = ui.createFluidLabel()
                fluidOutputLabels.append(tankLabel)
            }
        }
    }

    private func updateFluidIndicators(for entity: Entity, in ui: MachineUI) {
        guard let gameLoop = ui.gameLoop else { return }

        // Update fluid producers
        if let producer = gameLoop.world.get(FluidProducerComponent.self, for: entity),
           fluidOutputIndicators.count > 0 && fluidOutputLabels.count > 0 {
            fluidOutputIndicators[0].fluidType = producer.outputType
            fluidOutputIndicators[0].amount = producer.currentProduction * 60.0
            fluidOutputIndicators[0].maxAmount = producer.productionRate * 60.0
            fluidOutputIndicators[0].hasConnection = !producer.connections.isEmpty

            let flowRateText = String(format: "%.1f L/s", producer.productionRate)
            let fluidName = producer.outputType == .steam ? "Steam" : producer.outputType.rawValue
            fluidOutputLabels[0].text = "\(fluidName): \(flowRateText)"
        }

        // Update fluid consumers
        if let consumer = gameLoop.world.get(FluidConsumerComponent.self, for: entity),
           fluidInputIndicators.count > 0 && fluidInputLabels.count > 0 {
            fluidInputIndicators[0].fluidType = consumer.inputType
            fluidInputIndicators[0].amount = consumer.currentConsumption * 60.0
            fluidInputIndicators[0].maxAmount = consumer.consumptionRate * 60.0
            fluidInputIndicators[0].hasConnection = !consumer.connections.isEmpty

            let flowRateText = String(format: "%.1f L/s", consumer.consumptionRate)
            let fluidName = consumer.inputType == .water ? "Water" : consumer.inputType!.rawValue
            fluidInputLabels[0].text = "\(fluidName): \(flowRateText)"
        }

        // Update fluid tanks (remaining output indicators)
        if let tank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
            let tankIndicatorStart = gameLoop.world.has(FluidProducerComponent.self, for: entity) ? 1 : 0
            for (index, stack) in tank.tanks.enumerated() {
                let indicatorIndex = tankIndicatorStart + index
                if indicatorIndex < fluidOutputIndicators.count {
                    fluidOutputIndicators[indicatorIndex].fluidType = stack.type
                    fluidOutputIndicators[indicatorIndex].amount = stack.amount
                    fluidOutputIndicators[indicatorIndex].maxAmount = stack.maxAmount
                    fluidOutputIndicators[indicatorIndex].hasConnection = !tank.connections.isEmpty

                    // Update tank label
                    let labelIndex = tankIndicatorStart + index
                    if labelIndex < fluidOutputLabels.count {
                        let tankText = String(format: "%.0f/%.0f L", stack.amount, stack.maxAmount)
                        fluidOutputLabels[labelIndex].text = "Tank: \(tankText)"
                    }
                }
            }
        }
    }
}

/// Metal-rendered recipe button for machine UI
class MachineRecipeButton: UIElement {
    var frame: Rect
    let recipe: Recipe
    var onTap: (() -> Void)?

    init(frame: Rect, recipe: Recipe) {
        self.frame = frame
        self.recipe = recipe
    }

    func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }
        onTap?()
        return true
    }

    func render(renderer: MetalRenderer) {
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")

        // Subtle background
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: solidRect,
            color: Color(r: 0.15, g: 0.15, b: 0.15, a: 0.8),
            layer: .ui
        ))

        // Subtle border
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: solidRect,
            color: Color(r: 0.3, g: 0.3, b: 0.3, a: 1.0),
            layer: .ui
        ))

        // Inner background (slightly smaller)
        let innerSize = frame.size * 0.95
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: innerSize,
            textureRect: solidRect,
            color: Color(r: 0.12, g: 0.12, b: 0.12, a: 0.9),
            layer: .ui
        ))

        // Recipe icon from texture atlas
        let textureRect = renderer.textureAtlas.getTextureRect(for: recipe.textureId)
        let iconSize = frame.size * 0.7
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: iconSize,
            textureRect: textureRect,
            color: .white,
            layer: .ui
        ))
    }
}

/// Component for assembly machines (furnaces, assemblers)
class AssemblyMachineUIComponent: BaseMachineUIComponent {
    private(set) var recipeButtons: [MachineRecipeButton] = []
    private var availableRecipes: [Recipe] = []
    private var recipeSelectionCallback: RecipeSelectionCallback?
    private weak var ui: MachineUI?

    // Scrolling support
    private(set) var scrollOffset: Float = 0
    private var maxScrollOffset: Float = 0
    private var scrollArea: Rect = Rect(center: Vector2.zero, size: Vector2.zero)
    private var lastDragPosition: Vector2?

    convenience init(recipeSelectionCallback: @escaping RecipeSelectionCallback) {
        self.init()
        self.recipeSelectionCallback = recipeSelectionCallback
    }

    override func setupUI(for entity: Entity, in ui: MachineUI) {
        self.ui = ui
    }

    override func getLabels() -> [UILabel] {
        return []
    }

    override func getScrollViews() -> [UIScrollView] {
        return []
    }

    func handleScroll(at position: Vector2, delta: Vector2) -> Bool {
        // Check if scroll is within the scroll area
        guard scrollArea.contains(position) else {
            lastDragPosition = nil  // Reset when not in scroll area
            return false
        }

        if maxScrollOffset <= 0 {
            return false  // Nothing to scroll
        }

        // Calculate incremental delta from last position
        let incrementalDelta: Vector2
        if let lastPos = lastDragPosition {
            incrementalDelta = position - lastPos
        } else {
            incrementalDelta = Vector2.zero  // First frame of drag
        }
        lastDragPosition = position

        // Update scroll offset based on vertical movement
        if abs(incrementalDelta.y) > 0.1 {  // Small threshold to avoid jitter
            scrollOffset = max(0, min(maxScrollOffset, scrollOffset - incrementalDelta.y * 2))
        }

        return true
    }

    func resetScrollState() {
        lastDragPosition = nil
    }

    override func render(in renderer: MetalRenderer) {
        // All rendering is now handled by UIKit - no Metal rendering needed
    }

}

/// UI for interacting with machines (assemblers, furnaces, etc.)
final class MachineUI: UIPanel_Base {
    private(set) var screenSize: Vector2
    private(set) weak var gameLoop: GameLoop?
    private(set) var currentEntity: Entity?

    // UI components for different machine types
    private var machineComponents: [MachineUIComponent] = []

    // Common UI elements - now UIKit buttons
    private var inputSlotButtons: [UIKit.UIButton] = []
    private var outputSlotButtons: [UIKit.UIButton] = []
    private var fuelSlotButtons: [UIKit.UIButton] = []

    // Legacy Metal slots (keeping for now during transition)
    private var inputSlots: [InventorySlot] = []
    private var outputSlots: [InventorySlot] = []
    private var fuelSlots: [InventorySlot] = []
    private var inputCountLabels: [UILabel] = []
    private var outputCountLabels: [UILabel] = []
    private var fuelCountLabels: [UILabel] = []


    // UIKit panel container view
    private var panelView: UIView?

    // UIKit progress bar
    private var progressBarBackground: UIView?
    private var progressBarFill: UIView?

    // UIKit scroll view for recipe buttons
    private var recipeScrollView: ClearScrollView?

    // UIKit recipe buttons
    private var recipeUIButtons: [UIKitButton] = []

    /// Convert Metal frame to UIKit points for panel container
    private func panelFrameInPoints() -> CGRect {
        let screenScale = UIScreen.main.scale
        return CGRect(
            x: CGFloat(frame.minX) / screenScale,
            y: CGFloat(frame.minY) / screenScale,
            width: CGFloat(frame.size.x) / screenScale,
            height: CGFloat(frame.size.y) / screenScale
        )
    }

    // Legacy Metal recipe buttons (kept for compatibility)
    private var recipeButtons: [RecipeButton] = []


    // Research progress labels for labs
    private var researchProgressLabels: [UILabel] = []

    // Power label for generators
    private var powerLabel: UILabel?

    // Rocket launch button for rocket silos
    private var launchButton: UIKit.UIButton?

    // Callbacks for managing UIKit labels
    var onAddLabels: (([UILabel]) -> Void)?
    var onRemoveLabels: (([UILabel]) -> Void)?

    var onOpenInventoryForMachine: ((Entity, Int) -> Void)?
    var onOpenResearchMenu: (() -> Void)?
    var onLaunchRocket: ((Entity) -> Void)?
    var onSelectRecipeForMachine: ((Entity, Recipe) -> Void)?
    var onScroll: ((Vector2, Vector2) -> Void)?
    var onClosePanel: (() -> Void)?

    // Callbacks for managing UIKit views (panels, scroll views)
    var onAddScrollView: ((UIView) -> Void)?
    var onRemoveScrollView: ((UIView) -> Void)?

    // Helper to check if current machine is a lab
    private var isLab: Bool {
        guard let entity = currentEntity, let gameLoop = gameLoop else { return false }
        return gameLoop.world.has(LabComponent.self, for: entity)
    }

    // Helper to check if current machine is a rocket silo
    private var isRocketSilo: Bool {
        guard let entity = currentEntity, let gameLoop = gameLoop else { return false }
        return gameLoop.world.has(RocketSiloComponent.self, for: entity)
    }

    // Helper to check if current machine is a generator
    private var isGenerator: Bool {
        guard let entity = currentEntity, let gameLoop = gameLoop else { return false }
        return gameLoop.world.has(GeneratorComponent.self, for: entity)
    }

    init(screenSize: Vector2, gameLoop: GameLoop?) {
        self.screenSize = screenSize

        // Create panel frame in pixels (Metal renderer expects pixel coordinates)
        // UIScale already converts from points to pixels, so use it directly
        let panelWidth: Float = 600 * UIScale
        let panelHeight: Float = 350 * UIScale
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(panelWidth, panelHeight)
        )

        super.init(frame: panelFrame)
        self.gameLoop = gameLoop

        setupSlots()
    }

    private func setupSlots() {
        // Clear existing slots and labels
        inputSlots.removeAll()
        outputSlots.removeAll()
        fuelSlots.removeAll()
        inputCountLabels.removeAll()
        outputCountLabels.removeAll()
        fuelCountLabels.removeAll()

        // Get machine building definition
        guard let entity = currentEntity,
              let gameLoop = gameLoop else {
            print("MachineUI: Missing entity or gameLoop")
            return
        }

        // Try to get building component (check specific types since inheritance might not work in ECS)
        let buildingEntity: BuildingComponent?
        if let miner = gameLoop.world.get(MinerComponent.self, for: entity) {
            buildingEntity = miner
            print("MachineUI: Entity has MinerComponent")
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            buildingEntity = furnace
            print("MachineUI: Entity has FurnaceComponent")
        } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            buildingEntity = assembler
            print("MachineUI: Entity has AssemblerComponent")
        } else if let generator = gameLoop.world.get(GeneratorComponent.self, for: entity) {
            buildingEntity = generator
            print("MachineUI: Entity has GeneratorComponent")
        } else if let lab = gameLoop.world.get(LabComponent.self, for: entity) {
            buildingEntity = lab
            print("MachineUI: Entity has LabComponent")
        } else if let rocketSilo = gameLoop.world.get(RocketSiloComponent.self, for: entity) {
            buildingEntity = rocketSilo
            print("MachineUI: Entity has RocketSiloComponent")
        } else if let fluidProducer = gameLoop.world.get(FluidProducerComponent.self, for: entity) {
            buildingEntity = fluidProducer
        } else if let fluidConsumer = gameLoop.world.get(FluidConsumerComponent.self, for: entity) {
            buildingEntity = fluidConsumer
        } else {
            print("MachineUI: No building component found for entity")
            return
        }

        guard let buildingDef = gameLoop.buildingRegistry.get(buildingEntity!.buildingId) else {
            print("MachineUI: Failed to get building definition for entity \(entity.id) buildingId: '\(buildingEntity!.buildingId)'")
            return
        }

        let slotSize: Float = 40 * UIScale
        let slotSpacing: Float = 5 * UIScale

        let inputCount = buildingDef.inputSlots
        let outputCount = buildingDef.outputSlots
        let fuelCount = buildingDef.fuelSlots


        // Create fuel slots (left side, top) - UIKit buttons
        for i in 0..<fuelCount {
            // Convert Metal pixel coordinates to UIKit points relative to panel
            let screenScale = UIScreen.main.scale
            let panelBounds = panelView?.bounds ?? CGRect(x: 0, y: 0, width: 600, height: 350)

            // Position relative to panel center
            let relativeX = -200 * UIScale  // Left side
            let relativeY = -120 * UIScale + Float(i) * (slotSize + slotSpacing)  // Top area

            // Convert to points and panel-relative coordinates
            let buttonX = panelBounds.midX + CGFloat(relativeX) / screenScale
            let buttonY = panelBounds.midY + CGFloat(relativeY) / screenScale
            let buttonSizePoints = CGFloat(slotSize) / screenScale

            let button = UIKit.UIButton(frame: CGRect(x: buttonX, y: buttonY, width: buttonSizePoints, height: buttonSizePoints))

            // Configure button appearance
            var config = UIKit.UIButton.Configuration.plain()
            config.background.backgroundColor = UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1.0) // Lighter gray for fuel
            config.background.strokeColor = UIColor.white
            config.background.strokeWidth = 1.0
            config.background.cornerRadius = 4.0
            button.configuration = config

            fuelSlotButtons.append(button)

            // Add tap handler
            button.tag = i
            button.addTarget(self, action: #selector(fuelSlotTapped(_:)), for: UIControl.Event.touchUpInside)

            // Add to panel view
            panelView?.addSubview(button)

            // Count label
            let label = UILabel()
            label.text = "0"
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = .white
            label.textAlignment = .center
            label.frame = CGRect(x: buttonX - 25, y: buttonY + buttonSizePoints + 2, width: 20, height: 12)
            fuelCountLabels.append(label)
            panelView?.addSubview(label)
        }

        // Create input slots (left side, below fuel) - UIKit buttons
        for i in 0..<inputCount {
            // Convert Metal pixel coordinates to UIKit points relative to panel
            let screenScale = UIScreen.main.scale
            let panelBounds = panelView?.bounds ?? CGRect(x: 0, y: 0, width: 600, height: 350)

            // Position relative to panel center
            let relativeX = -200 * UIScale  // Left side
            let relativeY = -80 * UIScale + Float(i) * (slotSize + slotSpacing)  // Below fuel area

            // Convert to points and panel-relative coordinates
            let buttonX = panelBounds.midX + CGFloat(relativeX) / screenScale
            let buttonY = panelBounds.midY + CGFloat(relativeY) / screenScale
            let buttonSizePoints = CGFloat(slotSize) / screenScale

            let button = UIKit.UIButton(frame: CGRect(x: buttonX, y: buttonY, width: buttonSizePoints, height: buttonSizePoints))

            // Configure button appearance
            var config = UIKit.UIButton.Configuration.plain()
            config.background.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0) // Standard slot color
            config.background.strokeColor = UIColor.white
            config.background.strokeWidth = 1.0
            config.background.cornerRadius = 4.0
            button.configuration = config

            inputSlotButtons.append(button)

            // Add tap handler
            button.tag = i
            button.addTarget(self, action: #selector(inputSlotTapped(_:)), for: UIControl.Event.touchUpInside)

            // Add to panel view
            panelView?.addSubview(button)

            // Count label
            let label = UILabel()
            label.text = "0"
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = .white
            label.textAlignment = .center
            label.frame = CGRect(x: buttonX - 25, y: buttonY + buttonSizePoints + 2, width: 20, height: 12)
            inputCountLabels.append(label)
            panelView?.addSubview(label)
        }

        // Create output slots (right side) - UIKit buttons
        for i in 0..<outputCount {
            // Convert Metal pixel coordinates to UIKit points relative to panel
            let screenScale = UIScreen.main.scale
            let panelBounds = panelView?.bounds ?? CGRect(x: 0, y: 0, width: 600, height: 350)

            // Position relative to panel center
            let relativeX = 200 * UIScale  // Right side
            let relativeY = -80 * UIScale + Float(i) * (slotSize + slotSpacing)  // Same Y as inputs

            // Convert to points and panel-relative coordinates
            let buttonX = panelBounds.midX + CGFloat(relativeX) / screenScale
            let buttonY = panelBounds.midY + CGFloat(relativeY) / screenScale
            let buttonSizePoints = CGFloat(slotSize) / screenScale

            let button = UIKit.UIButton(frame: CGRect(x: buttonX, y: buttonY, width: buttonSizePoints, height: buttonSizePoints))

            // Configure button appearance
            var config = UIKit.UIButton.Configuration.plain()
            config.background.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0) // Standard slot color
            config.background.strokeColor = UIColor.white
            config.background.strokeWidth = 1.0
            config.background.cornerRadius = 4.0
            button.configuration = config

            outputSlotButtons.append(button)

            // Add tap handler
            button.tag = i
            button.addTarget(self, action: #selector(outputSlotTapped(_:)), for: UIControl.Event.touchUpInside)

            // Add to panel view
            panelView?.addSubview(button)

            // Count label
            let label = UILabel()
            label.text = "0"
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = .white
            label.textAlignment = .center
            label.frame = CGRect(x: buttonX - 25, y: buttonY + buttonSizePoints + 2, width: 20, height: 12)
            outputCountLabels.append(label)
            panelView?.addSubview(label)
        }

        // Fluid indicators now set up by FluidMachineUIComponent
    }


    func setEntity(_ entity: Entity) {
        currentEntity = entity

        // Clear existing components
        machineComponents.removeAll()

        // Determine machine type and create appropriate components
        if let gameLoop = gameLoop {
            // Check for fluid-based machines
            let hasFluidProducer = gameLoop.world.has(FluidProducerComponent.self, for: entity)
            let hasFluidConsumer = gameLoop.world.has(FluidConsumerComponent.self, for: entity)
            if hasFluidProducer || hasFluidConsumer {
                print("MachineUI: Creating FluidMachineUIComponent (producer: \(hasFluidProducer), consumer: \(hasFluidConsumer))")
                machineComponents.append(FluidMachineUIComponent())
            }

            // Check for assembly machines
            if gameLoop.world.has(AssemblerComponent.self, for: entity) {
                let recipeCallback: RecipeSelectionCallback = { [weak self] (entity: Entity, recipe: Recipe) in
                    self?.onSelectRecipeForMachine?(entity, recipe)
                }
                machineComponents.append(AssemblyMachineUIComponent(recipeSelectionCallback: recipeCallback))
            }
        }

        print("MachineUI: Created \(machineComponents.count) components for entity \(entity.id)")

        // Setup common UI elements
        setupSlots()
        setupSlotsForMachine(entity)

        // Setup machine-specific UI components
        for (index, component) in machineComponents.enumerated() {
            print("MachineUI: Setting up component \(index) (\(type(of: component)))")
            component.setupUI(for: entity, in: self)
        }

        // Setup power label for generators
        setupPowerLabel(for: entity)
    }

    private func setupPowerLabel(for entity: Entity) {
        // Remove existing power label if any
        powerLabel = nil

        // Create power label if this is a generator
        if isGenerator {
            let label = UILabel()
            label.text = "Power"
            label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            label.textColor = .white
            label.textAlignment = .center
            powerLabel = label
        }
    }


    private func setupRecipeScrollView() {
        // Create scroll view for recipe buttons (in points, relative to panel)
        let panelBounds = panelView?.bounds ?? CGRect(x: 0, y: 0, width: 600, height: 350)

        // Position scroll view at bottom of panel with margins
        let margin: CGFloat = 20
        let scrollViewHeight: CGFloat = 150
        let scrollViewWidth: CGFloat = panelBounds.width - margin * 2
        let scrollViewX: CGFloat = margin
        let scrollViewY: CGFloat = panelBounds.height - scrollViewHeight - margin

        recipeScrollView = ClearScrollView(frame: CGRect(
            x: scrollViewX,
            y: scrollViewY,
            width: scrollViewWidth,
            height: scrollViewHeight
        ))

        guard let scrollView = recipeScrollView else { return }

        // Configure scroll view
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isScrollEnabled = true
        scrollView.alwaysBounceVertical = true
        scrollView.delaysContentTouches = false

        // Add background color to prevent see-through appearance
        scrollView.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 0.6)
        scrollView.layer.cornerRadius = 8
        scrollView.clipsToBounds = true

        // Content size will be set when buttons are added
        scrollView.contentSize = CGSize(width: scrollViewWidth, height: scrollViewHeight)
    }

    private func setupRecipeButtons() {
        guard let _ = currentEntity,
              let gameLoop = gameLoop,
              let scrollView = recipeScrollView else { return }

        // Get available recipes
        let availableRecipes = gameLoop.recipeRegistry.enabled
        if availableRecipes.isEmpty { return }

        let buttonsPerRow = 5
        let buttonSize: CGFloat = 32  // Points
        let buttonSpacing: CGFloat = 8  // Points

        // Calculate content size
        let rows = (availableRecipes.count + buttonsPerRow - 1) / buttonsPerRow
        let contentWidth = scrollView.frame.width
        let contentHeight = CGFloat(rows) * (buttonSize + buttonSpacing) + buttonSpacing
        scrollView.contentSize = CGSize(width: contentWidth, height: contentHeight)

        // Clear existing buttons
        for button in recipeUIButtons {
            button.removeFromSuperview()
        }
        recipeUIButtons.removeAll()

        // Create buttons
        for (index, recipe) in availableRecipes.enumerated() {
            let row = index / buttonsPerRow
            let col = index % buttonsPerRow

            // Calculate items in this row (for centering partial rows)
            let itemsInRow = min(buttonsPerRow, availableRecipes.count - row * buttonsPerRow)
            let thisRowWidth = CGFloat(itemsInRow) * buttonSize + CGFloat(max(0, itemsInRow - 1)) * buttonSpacing

            // Center the row within the scroll view
            let rowInset = max(buttonSpacing, (scrollView.bounds.width - thisRowWidth) * 0.5)

            let buttonX = rowInset + CGFloat(col) * (buttonSize + buttonSpacing)
            let buttonY = buttonSpacing + CGFloat(row) * (buttonSize + buttonSpacing)

            let buttonFrame = CGRect(
                x: buttonX,
                y: buttonY,
                width: buttonSize,
                height: buttonSize
            )
            let button = UIKit.UIButton(frame: buttonFrame)

            // Button appearance is now handled by UIButtonConfiguration below

            // Configure button appearance using UIButtonConfiguration
            var config = UIKit.UIButton.Configuration.plain()
            config.background.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 0.8)
            config.background.strokeColor = UIColor.white
            config.background.strokeWidth = 1.0
            config.background.cornerRadius = 4.0
            config.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)

            // Add recipe texture (if available)
            if !recipe.textureId.isEmpty {
                if let image = loadRecipeImage(for: recipe.textureId) {
                    // Scale image to 80% of button size like InventoryUI does for icons
                    let scaledSize = CGSize(width: buttonSize * 0.8, height: buttonSize * 0.8)
                    UIGraphicsBeginImageContextWithOptions(scaledSize, false, 0.0)
                    image.draw(in: CGRect(origin: .zero, size: scaledSize))
                    let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()

                    config.image = scaledImage
                    config.imagePlacement = .all
                    // Remove content insets since we're scaling the image directly
                } else {
                    // Fallback to text if image loading fails
                    config.title = "R"
                    config.baseForegroundColor = UIColor.white
                }
            } else {
                // No texture available
                config.title = "?"
                config.baseForegroundColor = UIColor.white
            }

            button.configuration = config

            // Add tap handler
            button.tag = index
            button.addTarget(self, action: #selector(recipeButtonTapped(_:)), for: UIControl.Event.touchUpInside)

            scrollView.addSubview(button)
            recipeUIButtons.append(button)
        }
    }

    private func loadRecipeImage(for textureId: String) -> UIImage? {
        // Map texture IDs to actual filenames (some have different names)
        var filename = textureId

        // Handle special mappings
        switch textureId {
        case "transport_belt":
            filename = "belt"
        case "fast_transport_belt":
            filename = "belt"  // Use same image
        case "express_transport_belt":
            filename = "belt"  // Use same image
        case "iron-plate":
            filename = "iron_plate"
        case "copper-plate":
            filename = "copper_plate"
        case "steel-plate":
            filename = "steel_plate"
        default:
            // Replace underscores with nothing for some cases
            filename = textureId.replacingOccurrences(of: "_", with: "")
        }

        // Try to load from bundle
        if let imagePath = Bundle.main.path(forResource: filename, ofType: "png") {
            return UIImage(contentsOfFile: imagePath)
        }

        // Try with underscore replacement
        let underscoreFilename = filename.replacingOccurrences(of: "-", with: "_")
        if let imagePath = Bundle.main.path(forResource: underscoreFilename, ofType: "png") {
            return UIImage(contentsOfFile: imagePath)
        }

        // Try original name with underscores
        if let imagePath = Bundle.main.path(forResource: textureId.replacingOccurrences(of: "-", with: "_"), ofType: "png") {
            return UIImage(contentsOfFile: imagePath)
        }

        return nil
    }

    @objc private func recipeButtonTapped(_ sender: Any) {
        guard let button = sender as? UIKit.UIButton else { return }
        guard let entity = currentEntity,
              let gameLoop = gameLoop else { return }

        let availableRecipes = gameLoop.recipeRegistry.enabled
        let recipeIndex = Int(button.tag)

        if recipeIndex >= 0 && recipeIndex < availableRecipes.count {
            let recipe = availableRecipes[recipeIndex]
            onSelectRecipeForMachine?(entity, recipe)
        }
    }

    override func open() {
        super.open()

        // Create UIKit panel container view
        if panelView == nil {
            panelView = UIView(frame: panelFrameInPoints())
        panelView!.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.95)
        panelView!.layer.cornerRadius = 12
        panelView!.layer.borderWidth = 1
        panelView!.layer.borderColor = UIColor(white: 1, alpha: 0.15).cgColor

        // Create progress bar views
        let panelBounds = panelView!.bounds
        let barWidth: CGFloat = 300
        let barHeight: CGFloat = 20
        let barX = panelBounds.midX - barWidth/2
        let barY = panelBounds.midY - 60

        // Background
        progressBarBackground = UIView(frame: CGRect(x: barX, y: barY, width: barWidth, height: barHeight))
        progressBarBackground!.backgroundColor = UIColor.gray
        progressBarBackground!.layer.cornerRadius = 4
        panelView!.addSubview(progressBarBackground!)

        // Fill
        progressBarFill = UIView(frame: CGRect(x: barX, y: barY, width: 0, height: barHeight))
        progressBarFill!.backgroundColor = UIColor.blue
        progressBarFill!.layer.cornerRadius = 4
        panelView!.addSubview(progressBarFill!)
        }

        // Add panel view to hierarchy
        if let panelView = panelView {
            onAddScrollView?(panelView)
        }

        // Set up UIKit components
        if recipeScrollView == nil {
            setupRecipeScrollView()
        }
        setupRecipeButtons()

        // Add scroll view inside panel view
        if let recipeScrollView = recipeScrollView, let panelView = panelView {
            panelView.addSubview(recipeScrollView)
        }

        // Add appropriate labels to the view
        var allLabels = inputCountLabels + outputCountLabels + fuelCountLabels
        if isLab {
            allLabels += researchProgressLabels
        }
        if isGenerator, let powerLabel = powerLabel {
            allLabels.append(powerLabel)
        }

        // Add labels from machine components
        for component in machineComponents {
            let componentLabels = component.getLabels()
            print("MachineUI: Component returned \(componentLabels.count) labels")
            allLabels += componentLabels
        }

        print("MachineUI: Total labels to add: \(allLabels.count) (fuel: \(fuelCountLabels.count), components: \(allLabels.count - inputCountLabels.count - outputCountLabels.count - fuelCountLabels.count))")
        onAddLabels?(allLabels)

        // Position the count labels
        positionCountLabels()

        // Position fluid labels after adding to view
        for component in machineComponents {
            if let fluidComponent = component as? FluidMachineUIComponent {
                fluidComponent.positionLabels(in: self)
            }
        }

        // Add rocket launch button for rocket silos
        if isRocketSilo {
            setupRocketLaunchButton()
        }

        // Add scroll views from machine components
        for component in machineComponents {
            for scrollView in component.getScrollViews() {
                onAddScrollView?(scrollView)
                scrollView.isHidden = false
            }
        }
    }

    // Public method to get all scroll views (needed for touch event handling)
    func getAllScrollViews() -> [UIScrollView] {
        var scrollViews: [UIScrollView] = []
        for component in machineComponents {
            scrollViews.append(contentsOf: component.getScrollViews())
        }
        return scrollViews
    }

    override func close() {
        // Remove all count labels from the view
        var allLabels = inputCountLabels + outputCountLabels + fuelCountLabels + researchProgressLabels
        // Add labels from components
        for component in machineComponents {
            allLabels += component.getLabels()
        }
        if let powerLabel = powerLabel {
            allLabels.append(powerLabel)
        }
        onRemoveLabels?(allLabels)

        // Clear label text to ensure they're properly reset
        for label in allLabels {
            label.text = ""
            label.isHidden = true
        }

        // Fluid labels cleared by component cleanup

        // Remove rocket launch button
        launchButton = nil

        // Remove UIKit components
        if let panelView = panelView {
            onRemoveScrollView?(panelView)
        }
        if let recipeScrollView = recipeScrollView {
            onRemoveScrollView?(recipeScrollView)
        }

        // Remove scroll views from components
        for component in machineComponents {
            for scrollView in component.getScrollViews() {
                onRemoveScrollView?(scrollView)
            }
        }

        super.close()
    }


    private func setupSlotsForMachine(_ entity: Entity) {
        guard let gameLoop = gameLoop else { return }

        // Clear all slots
        for slot in inputSlots {
            slot.item = nil
        }
        for slot in outputSlots {
            slot.item = nil
        }
        for slot in fuelSlots {
            slot.item = nil
        }

        // Get machine inventory and building definition
        guard let inventory = gameLoop.world.get(InventoryComponent.self, for: entity) else { return }

        // Try to get building component by checking specific types
        let buildingEntity: BuildingComponent?
        if let miner = gameLoop.world.get(MinerComponent.self, for: entity) {
            buildingEntity = miner
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            buildingEntity = furnace
        } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            buildingEntity = assembler
        } else if let generator = gameLoop.world.get(GeneratorComponent.self, for: entity) {
            buildingEntity = generator
        } else if let lab = gameLoop.world.get(LabComponent.self, for: entity) {
            buildingEntity = lab
        } else if let rocketSilo = gameLoop.world.get(RocketSiloComponent.self, for: entity) {
            buildingEntity = rocketSilo
        } else if let fluidProducer = gameLoop.world.get(FluidProducerComponent.self, for: entity) {
            buildingEntity = fluidProducer
        } else if let fluidConsumer = gameLoop.world.get(FluidConsumerComponent.self, for: entity) {
            buildingEntity = fluidConsumer
        } else {
            return
        }

        guard gameLoop.buildingRegistry.get(buildingEntity!.buildingId) != nil else { return }

        let totalSlots = inventory.slots.count
        var inventoryIndex = 0

        // Map fuel slots (first in inventory)
        for i in 0..<fuelSlots.count {
            if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                fuelSlots[i].item = item
                fuelSlots[i].isRequired = false
                fuelCountLabels[i].text = "\(item.count)"
                fuelCountLabels[i].isHidden = false
            } else {
                fuelSlots[i].item = nil
                fuelSlots[i].isRequired = false
                fuelCountLabels[i].text = "0"
                fuelCountLabels[i].isHidden = true
            }
            inventoryIndex += 1
        }

        // Check if this is an assembler with a recipe set
        var currentRecipe: Recipe? = nil
        if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            currentRecipe = assembler.recipe
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            currentRecipe = furnace.recipe
        }

        // Map input slots - show required ingredients for current recipe
        if let recipe = currentRecipe {
            for i in 0..<min(inputSlots.count, recipe.inputs.count) {
                let requiredItem = recipe.inputs[i]
                // Check if we have this item in inventory at the expected position
                if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex], item.itemId == requiredItem.itemId {
                    inputSlots[i].item = item
                    inputSlots[i].isRequired = false
                } else {
                    // Show required item even if not in inventory
                    inputSlots[i].item = ItemStack(itemId: requiredItem.itemId, count: 0)
                    inputSlots[i].isRequired = true
                }
                inventoryIndex += 1
            }
            // Clear remaining input slots
            for i in recipe.inputs.count..<inputSlots.count {
                inputSlots[i].item = nil
                inputSlots[i].isRequired = false
            }
        } else {
            // No recipe set - show actual inventory items
            for i in 0..<inputSlots.count {
                if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                    inputSlots[i].item = item
                    inputSlots[i].isRequired = false
                } else {
                    inputSlots[i].item = nil
                    inputSlots[i].isRequired = false
                }
                inventoryIndex += 1
            }
        }

        // Map output slots - show recipe outputs or actual inventory
        if let recipe = currentRecipe {
            for i in 0..<min(outputSlots.count, recipe.outputs.count) {
                let outputItem = recipe.outputs[i]
                // Check if we have this output in inventory
                if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex], item.itemId == outputItem.itemId {
                    outputSlots[i].item = item
                    outputSlots[i].isRequired = false
                } else {
                    // Show expected output
                    outputSlots[i].item = ItemStack(itemId: outputItem.itemId, count: 0)
                    outputSlots[i].isRequired = true // Expected output
                }
                inventoryIndex += 1
            }
            // Clear remaining output slots
            for i in recipe.outputs.count..<outputSlots.count {
                outputSlots[i].item = nil
                outputSlots[i].isRequired = false
            }
        } else {
            // No recipe set - show actual inventory items
            for i in 0..<outputSlots.count {
                if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                    outputSlots[i].item = item
                    outputSlots[i].isRequired = false
                } else {
                    outputSlots[i].item = nil
                    outputSlots[i].isRequired = false
                }
                inventoryIndex += 1
            }
        }
        // Update count labels
        updateCountLabels(entity)
    }

    private func updateCountLabels(_ entity: Entity) {
        guard let gameLoop = gameLoop,
              let inventory = gameLoop.world.get(InventoryComponent.self, for: entity) else { return }

        // Try to get building component by checking specific types
        let buildingEntity: BuildingComponent?
        if let miner = gameLoop.world.get(MinerComponent.self, for: entity) {
            buildingEntity = miner
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            buildingEntity = furnace
        } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            buildingEntity = assembler
        } else if let generator = gameLoop.world.get(GeneratorComponent.self, for: entity) {
            buildingEntity = generator
        } else if let lab = gameLoop.world.get(LabComponent.self, for: entity) {
            buildingEntity = lab
        } else if let rocketSilo = gameLoop.world.get(RocketSiloComponent.self, for: entity) {
            buildingEntity = rocketSilo
        } else {
            return
        }

        guard gameLoop.buildingRegistry.get(buildingEntity!.buildingId) != nil else { return }

        let totalSlots = inventory.slots.count
        var inventoryIndex = 0

        // Update fuel slot labels
        for i in 0..<fuelCountLabels.count {
            if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                fuelCountLabels[i].text = "\(item.count)"
                fuelCountLabels[i].isHidden = false
            } else {
                fuelCountLabels[i].text = "0"
                fuelCountLabels[i].isHidden = true
            }
            inventoryIndex += 1
        }

        // Update input slot labels
        for i in 0..<inputCountLabels.count {
            if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                inputCountLabels[i].text = "\(item.count)"
                inputCountLabels[i].isHidden = false
            } else {
                inputCountLabels[i].text = "0"
                inputCountLabels[i].isHidden = true
            }
            inventoryIndex += 1
        }

        // Update output slot labels
        for i in 0..<outputCountLabels.count {
            if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                outputCountLabels[i].text = "\(item.count)"
                outputCountLabels[i].isHidden = false
            } else {
                outputCountLabels[i].text = "0"
                outputCountLabels[i].isHidden = true
            }
            inventoryIndex += 1
        }
    }

    func updateMachine(_ entity: Entity) {
        setupSlotsForMachine(entity)
        updateCountLabels(entity)
        positionCountLabels()

        // Update machine components
        for component in machineComponents {
            component.updateUI(for: entity, in: self)
        }

        // Reposition fluid labels
        for component in machineComponents {
            if let fluidComponent = component as? FluidMachineUIComponent {
                fluidComponent.positionLabels(in: self)
            }
        }
    }

// Fluid updates now handled by FluidMachineUIComponent

    override func update(deltaTime: Float) {
        guard isOpen else { return }

        // Update progress bar
        updateProgressBar()

        // Update button states based on craftability and crafting status
        guard let player = gameLoop?.player,
              let gameLoop = gameLoop else { return }

        let recipes = gameLoop.recipeRegistry.enabled

        for uiButton in recipeUIButtons {
            let idx = uiButton.tag
            guard idx >= 0 && idx < recipes.count else { continue }

            let recipe = recipes[idx]
            let canCraft = recipe.canCraft(with: player.inventory)
            let isCrafting = player.isCrafting(recipe: recipe)

            // Update button configuration instead of direct backgroundColor
            var cfg = uiButton.configuration ?? .plain()

            // Choose color
            let bg: UIColor
            if isCrafting {
                bg = UIColor(red: 0.3, green: 0.4, blue: 0.6, alpha: 1.0) // Blue for crafting
            } else if canCraft {
                bg = UIColor(red: 0.4, green: 0.7, blue: 0.4, alpha: 1.0) // Green for can craft
            } else {
                bg = UIColor(red: 0.25, green: 0.2, blue: 0.2, alpha: 1.0) // Red for cannot craft
            }

            cfg.background.backgroundColor = bg
            uiButton.configuration = cfg
        }
    }


    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        // Panel background is now handled by UIKit panelView

        // Slots and progress bar are now handled by UIKit - no Metal rendering needed

        // Count labels are updated in updateMachine() which is called from update(deltaTime:)

        // Recipe buttons are now handled by UIKit - no Metal rendering needed

        // Rocket launch button is UIKit - no Metal rendering needed

        // Render machine components
        for component in machineComponents {
            component.render(in: renderer)
        }
    }

    // MARK: - Rocket Launch UI

    private func setupRocketLaunchButton() {
        guard let _ = gameLoop, let entity = currentEntity else { return }

        // Remove existing button if any
        launchButton = nil

        // Create UIKit launch button
        let screenScale = UIScreen.main.scale
        let buttonWidth: CGFloat = 200 / screenScale
        let buttonHeight: CGFloat = 50 / screenScale
        let centerX = CGFloat(frame.center.x)
        let centerY = CGFloat(frame.center.y)
        let sizeY = CGFloat(frame.size.y)
        let buttonX = (centerX - 100) / screenScale  // 200/2 = 100
        let buttonY = (centerY + sizeY/2 - 50 - 20) / screenScale  // 50 is buttonHeight, 20 is margin

        let buttonFrame = CGRect(x: buttonX, y: buttonY, width: buttonWidth, height: buttonHeight)
        let button = UIKit.UIButton(frame: buttonFrame)

        // Configure button appearance
        var config = UIKit.UIButton.Configuration.filled()
        config.title = "🚀 LAUNCH ROCKET"
        config.baseBackgroundColor = UIColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1.0) // Green
        config.baseForegroundColor = UIColor.white
        button.configuration = config

        // Add tap handler
        button.addTarget(self, action: #selector(launchRocketPressed), for: UIControl.Event.touchUpInside)

        // Check if rocket can be launched
        updateLaunchButtonState(button, for: entity)

        launchButton = button

        // Add to panel view
        if let panelView = panelView {
            panelView.addSubview(button)
        }
    }

    private func getBuildingDefinition(for entity: Entity, gameLoop: GameLoop) -> BuildingDefinition? {
        let buildingComponent: BuildingComponent?
        if let miner = gameLoop.world.get(MinerComponent.self, for: entity) {
            buildingComponent = miner
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            buildingComponent = furnace
        } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            buildingComponent = assembler
        } else if let generator = gameLoop.world.get(GeneratorComponent.self, for: entity) {
            buildingComponent = generator
        } else if let lab = gameLoop.world.get(LabComponent.self, for: entity) {
            buildingComponent = lab
        } else if let rocketSilo = gameLoop.world.get(RocketSiloComponent.self, for: entity) {
            buildingComponent = rocketSilo
        } else {
            return nil
        }

        guard let component = buildingComponent else { return nil }
        return gameLoop.buildingRegistry.get(component.buildingId)
    }

    @objc private func fuelSlotTapped(_ sender: UIKit.UIButton) {
        guard let entity = currentEntity, let gameLoop = gameLoop else { return }
        handleSlotTap(entity: entity, slotIndex: sender.tag, gameLoop: gameLoop)
    }

    @objc private func inputSlotTapped(_ sender: UIKit.UIButton) {
        guard let entity = currentEntity, let gameLoop = gameLoop else { return }

        guard let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) else { return }

        let slotIndex = buildingDef.fuelSlots + sender.tag
        handleSlotTap(entity: entity, slotIndex: slotIndex, gameLoop: gameLoop)
    }

    @objc private func outputSlotTapped(_ sender: UIKit.UIButton) {
        guard let entity = currentEntity, let gameLoop = gameLoop else { return }

        guard let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) else { return }

        let slotIndex = buildingDef.fuelSlots + buildingDef.inputSlots + sender.tag
        handleSlotTap(entity: entity, slotIndex: slotIndex, gameLoop: gameLoop)
    }

    @objc private func launchRocketPressed() {
        guard let entity = currentEntity else { return }
        onLaunchRocket?(entity)
        // Update button state after launch attempt
        if let button = launchButton {
            updateLaunchButtonState(button, for: entity)
        }
    }

    private func updateLaunchButtonState(_ button: UIKit.UIButton, for entity: Entity) {
        guard let gameLoop = gameLoop else { return }

        // Check if rocket silo has components for launch
        if let silo = gameLoop.world.get(RocketSiloComponent.self, for: entity),
           let _ = gameLoop.world.get(InventoryComponent.self, for: entity) {

            let canLaunch = !silo.isLaunching && silo.rocketAssembled

            var config = button.configuration ?? .filled()
            config.title = canLaunch ? "🚀 LAUNCH ROCKET" : (silo.isLaunching ? "⏳ LAUNCHING..." : "⚠️ ASSEMBLE ROCKET")
            config.baseBackgroundColor = canLaunch ? UIColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1.0) : UIColor.gray
            button.configuration = config
            button.isEnabled = canLaunch
        } else {
            var config = button.configuration ?? .filled()
            config.title = "❌ ERROR"
            config.baseBackgroundColor = UIColor.red
            button.configuration = config
            button.isEnabled = false
        }
    }

    private func handleSlotTap(entity: Entity, slotIndex: Int, gameLoop: GameLoop) {
        let world = gameLoop.world

        // Get machine inventory
        guard var machineInventory = world.get(InventoryComponent.self, for: entity),
              slotIndex < machineInventory.slots.count,
              let itemStack = machineInventory.slots[slotIndex] else {
            return
        }

        // Try to add the item to player inventory
        let remainingCount = gameLoop.player.inventory.add(itemStack)

        if remainingCount == 0 {
            // All items were successfully moved to player inventory
            machineInventory.slots[slotIndex] = nil
            world.add(machineInventory, to: entity)

            // Update the UI
            updateMachine(entity)

            print("MachineUI: Returned \(itemStack.count) \(itemStack.itemId) to player inventory")
        } else {
            // Some items couldn't be moved - update the machine slot with remaining items
            let remainingStack = ItemStack(itemId: itemStack.itemId, count: remainingCount, maxStack: itemStack.maxStack)
            machineInventory.slots[slotIndex] = remainingStack
            world.add(machineInventory, to: entity)

            // Update the UI
            updateMachine(entity)

            // Show feedback that only partial items were moved
            showInventoryFullTooltip()
            print("MachineUI: Returned \(itemStack.count - remainingCount) \(itemStack.itemId) to player inventory, \(remainingCount) remaining in machine")
        }
    }

    private func showInventoryFullTooltip() {
        // Show tooltip using the existing tooltip system
        gameLoop?.inputManager?.onTooltip?("Inventory is full!")
    }

    private func handleEmptySlotTap(entity: Entity, slotIndex: Int) {
        // Open inventory UI in machine input mode for this slot
        onOpenInventoryForMachine?(entity, slotIndex)
    }


    private func positionCountLabels() {
        let slotSize: Float = 40 * UIScale

        // Position fuel slot labels
        for i in 0..<fuelSlots.count {
            let slot = fuelSlots[i]
            let label = fuelCountLabels[i]

            // Label position: bottom-right corner of slot
            let labelWidth: Float = 24
            let labelHeight: Float = 12
            let labelX = slot.frame.center.x - slotSize/2 + slotSize - labelWidth
            let labelY = slot.frame.center.y - slotSize/2 + slotSize - labelHeight

            // Convert to UIView coordinates
            let scale = UIScreen.main.scale
            let uiX = CGFloat(labelX) / scale
            let uiY = CGFloat(labelY) / scale

            label.frame = CGRect(x: uiX, y: uiY, width: CGFloat(labelWidth), height: CGFloat(labelHeight))
        }

        // Position input slot labels
        for i in 0..<inputSlots.count {
            let slot = inputSlots[i]
            let label = inputCountLabels[i]

            // Label position: bottom-right corner of slot
            let labelWidth: Float = 24
            let labelHeight: Float = 12
            let labelX = slot.frame.center.x - slotSize/2 + slotSize - labelWidth
            let labelY = slot.frame.center.y - slotSize/2 + slotSize - labelHeight

            // Convert to UIView coordinates
            let scale = UIScreen.main.scale
            let uiX = CGFloat(labelX) / scale
            let uiY = CGFloat(labelY) / scale

            label.frame = CGRect(x: uiX, y: uiY, width: CGFloat(labelWidth), height: CGFloat(labelHeight))
        }

        // Position output slot labels
        for i in 0..<outputSlots.count {
            let slot = outputSlots[i]
            let label = outputCountLabels[i]

            // Label position: bottom-right corner of slot
            let labelWidth: Float = 20
            let labelHeight: Float = 12
            let labelX = slot.frame.center.x - slotSize/2 + slotSize - labelWidth
            let labelY = slot.frame.center.y - slotSize/2 + slotSize - labelHeight

            // Convert to UIView coordinates
            let scale = UIScreen.main.scale
            let uiX = CGFloat(labelX) / scale
            let uiY = CGFloat(labelY) / scale

            label.frame = CGRect(x: uiX, y: uiY, width: CGFloat(labelWidth), height: CGFloat(labelHeight))
        }

        // Position power label above the power bar
        if let powerLabel = powerLabel {
            let labelWidth: Float = 100
            let labelHeight: Float = 16
            let labelX = frame.center.x - labelWidth/2  // Center the label
            let labelY = frame.center.y - 85 * UIScale  // Position above the power bar

            // Convert to UIView coordinates
            let scale = UIScreen.main.scale
            let uiX = CGFloat(labelX) / scale
            let uiY = CGFloat(labelY) / scale

            powerLabel.frame = CGRect(x: uiX, y: uiY, width: CGFloat(labelWidth), height: CGFloat(labelHeight))
        }
    }

// Fluid label positioning is now handled by FluidMachineUIComponent

    // Helper method to create fluid labels with consistent styling
    func createFluidLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .medium) // Slightly smaller and less bold
        label.textColor = .white
        label.textAlignment = .center
        label.text = "0.0 L/s"
        label.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.25, alpha: 0.7) // More subtle
        label.layer.borderColor = UIColor.cyan.cgColor
        label.layer.borderWidth = 0.5 // Thinner border
        label.layer.cornerRadius = 3.0 // Smaller radius
        label.isHidden = false

        // Set initial frame (slightly smaller now that visuals are clearer)
        label.frame = CGRect(x: 0, y: 0, width: 90, height: 20)

        return label
    }

    override func handleTap(at position: Vector2) -> Bool {
        guard isOpen else { return false }

        // Rocket launch button is UIKit - taps handled by UIKit

        // Recipe buttons are now UIKit buttons - taps handled by UIKit

        // Recipe buttons are now UIKit buttons - taps handled by UIKit

        // Get building component for inventory index calculations
        guard let entity = currentEntity, let gameLoop = gameLoop else { return false }

        // Try to get building component by checking specific types
        let buildingEntity: BuildingComponent?
        if let miner = gameLoop.world.get(MinerComponent.self, for: entity) {
            buildingEntity = miner
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            buildingEntity = furnace
        } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            buildingEntity = assembler
        } else if let generator = gameLoop.world.get(GeneratorComponent.self, for: entity) {
            buildingEntity = generator
        } else if let lab = gameLoop.world.get(LabComponent.self, for: entity) {
            buildingEntity = lab
        } else if let rocketSilo = gameLoop.world.get(RocketSiloComponent.self, for: entity) {
            buildingEntity = rocketSilo
        } else if let fluidProducer = gameLoop.world.get(FluidProducerComponent.self, for: entity) {
            buildingEntity = fluidProducer
        } else if let fluidConsumer = gameLoop.world.get(FluidConsumerComponent.self, for: entity) {
            buildingEntity = fluidConsumer
        } else {
            return false
        }

        let inventory = gameLoop.world.get(InventoryComponent.self, for: entity)
        guard let buildingDef = gameLoop.buildingRegistry.get(buildingEntity!.buildingId) else {
            return false
        }

        // Check inventory-based slots only if machine has inventory
        if let inventory = inventory {
            // Check fuel slots
            for (index, slot) in fuelSlots.enumerated() {
                if slot.handleTap(at: position) {
                    let inventoryIndex = index  // Fuel slots are first in inventory
                    if inventoryIndex < inventory.slots.count,
                       inventory.slots[inventoryIndex] != nil {
                        // Slot has an item - remove it to player inventory
                        handleSlotTap(entity: entity, slotIndex: inventoryIndex, gameLoop: gameLoop)
                    } else {
                        // Slot is empty - open inventory for fuel
                        handleEmptySlotTap(entity: entity, slotIndex: inventoryIndex)
                    }
                    return true
                }
            }

            // Check input slots
            for (index, slot) in inputSlots.enumerated() {
                if slot.handleTap(at: position) {
                    let inventoryIndex = buildingDef.fuelSlots + index  // Input slots come after fuel slots
                    if inventoryIndex < inventory.slots.count,
                       inventory.slots[inventoryIndex] != nil {
                        // Slot has an item - remove it to player inventory
                        handleSlotTap(entity: entity, slotIndex: inventoryIndex, gameLoop: gameLoop)
                    } else {
                        // Slot is empty - open inventory for input
                        handleEmptySlotTap(entity: entity, slotIndex: inventoryIndex)
                    }
                    return true
                }
            }

            // Check output slots
            for (slotIndex, slot) in outputSlots.enumerated() {
                if slot.handleTap(at: position) {
                    let inventoryIndex = buildingDef.fuelSlots + buildingDef.inputSlots + slotIndex  // Output slots come after fuel and input slots
                    if inventoryIndex < inventory.slots.count,
                       inventory.slots[inventoryIndex] != nil {
                        // Slot has an item - remove it to player inventory
                        handleSlotTap(entity: entity, slotIndex: inventoryIndex, gameLoop: gameLoop)
                    } else {
                        // Slot is empty - could potentially open inventory for output, but for now just ignore
                        // Output slots are typically filled by machine production, not manual input
                    }
                    return true
                }
            }
        }

// Fluid indicator tap handling moved to components

        // If tap didn't hit any UI elements, close the panel
        onClosePanel?()
        return true // Consume the tap to prevent other interactions
    }

    func handleScroll(at position: Vector2, delta: Vector2) -> Bool {
        guard isOpen else { return false }

        // Check assembly component scroll area
        for component in machineComponents {
            if let assemblyComponent = component as? AssemblyMachineUIComponent {
                if assemblyComponent.handleScroll(at: position, delta: delta) {
                    return true
                }
            }
        }

        return false
    }

    override func handleDrag(from startPos: Vector2, to endPos: Vector2) -> Bool {
        // Check assembly component scroll area first
        for component in machineComponents {
            if let assemblyComponent = component as? AssemblyMachineUIComponent {
                // Use the current position for scrolling, not the delta from start
                if assemblyComponent.handleScroll(at: endPos, delta: Vector2.zero) {
                    return true
                }
            }
        }

        // Check if dragging to an empty input or output slot
        guard let _ = gameLoop, let _ = currentEntity else { return false }

        // Check fuel slots
        for (_, slot) in fuelSlots.enumerated() {
            if slot.frame.contains(endPos) && slot.item == nil {
                // Dropped on empty fuel slot - this would require drag state from inventory
                // For now, just return true to indicate drag was handled
                return true
            }
        }

        // Check input slots
        for (_, slot) in inputSlots.enumerated() {
            if slot.frame.contains(endPos) && slot.item == nil {
                // Dropped on empty input slot - this would require drag state from inventory
                // For now, just return true to indicate drag was handled
                return true
            }
        }

        // Check output slots
        for (_, slot) in outputSlots.enumerated() {
            if slot.frame.contains(endPos) && slot.item == nil {
                // Dropped on empty output slot - this would require drag state from inventory
                return true
            }
        }

        return false
    }

    private func updateProgressBar() {
        guard let entity = currentEntity, let gameLoop = gameLoop else { return }

        // Get progress from the appropriate component
        var progress: Float = 0
        var isGenerator = false
        var powerAvailability: Float = 1.0

        if let miner = gameLoop.world.get(MinerComponent.self, for: entity) {
            progress = miner.progress
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            progress = furnace.smeltingProgress
        } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            progress = assembler.craftingProgress
        } else if let pumpjack = gameLoop.world.get(PumpjackComponent.self, for: entity) {
            progress = pumpjack.progress
        } else if gameLoop.world.has(GeneratorComponent.self, for: entity) {
            // For generators, show power availability bar instead of progress
            isGenerator = true
            if let networkInfo = gameLoop.powerSystem.getNetworkInfo(for: entity) {
                powerAvailability = networkInfo.powerAvailability
            }
        } else {
            // No progress or power info to show
            return
        }

        // Update UIKit progress bar
        progressBarBackground?.isHidden = false
        progressBarFill?.isHidden = false

        guard let backgroundFrame = progressBarBackground?.frame else { return }

        // Update fill width and color
        var fillWidth: CGFloat
        var fillColor: UIColor

        if isGenerator {
            // Power availability bar (blue)
            fillWidth = backgroundFrame.width * CGFloat(powerAvailability)
            fillColor = UIColor.blue
        } else {
            // Progress bar (green)
            fillWidth = backgroundFrame.width * CGFloat(progress)
            fillColor = UIColor.green
        }

        progressBarFill?.frame = CGRect(
            x: backgroundFrame.origin.x,
            y: backgroundFrame.origin.y,
            width: fillWidth,
            height: backgroundFrame.height
        )
        progressBarFill?.backgroundColor = fillColor

        // UIKit progress bar updated above
    }
}
