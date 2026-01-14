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
    // rootView is now the single container for all MachineUI UIKit content

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

    // Single root view for all MachineUI UIKit content
    private(set) var rootView: UIView?

    var onOpenInventoryForMachine: ((Entity, Int) -> Void)?
    var onOpenResearchMenu: (() -> Void)?
    var onLaunchRocket: ((Entity) -> Void)?
    var onSelectRecipeForMachine: ((Entity, Recipe) -> Void)?
    var onScroll: ((Vector2, Vector2) -> Void)?
    var onClosePanel: (() -> Void)?

    // Callback for managing the root view
    var onAddRootView: ((UIView) -> Void)?
    var onRemoveRootView: ((UIView) -> Void)?

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
        // Only set up model data - UIKit UI is created separately in setupSlotButtons()
        // This method is called during init/setEntity and should not depend on rootView existing
        print("MachineUI: setupSlots() called - only setting up model data")
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
        
        // Recreate UIKit slot buttons if UI is open
        if isOpen {
            clearSlotUI()
            setupSlotButtons()
        }
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
        // Create scroll view for recipe buttons (in points, relative to root view)
        let panelBounds = rootView?.bounds ?? CGRect(x: 0, y: 0, width: 600, height: 350)

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

    private func clearSlotUI() {
        fuelSlotButtons.forEach { $0.removeFromSuperview() }
        inputSlotButtons.forEach { $0.removeFromSuperview() }
        outputSlotButtons.forEach { $0.removeFromSuperview() }

        fuelCountLabels.forEach { $0.removeFromSuperview() }
        inputCountLabels.forEach { $0.removeFromSuperview() }
        outputCountLabels.forEach { $0.removeFromSuperview() }

        fuelSlotButtons.removeAll()
        inputSlotButtons.removeAll()
        outputSlotButtons.removeAll()

        fuelCountLabels.removeAll()
        inputCountLabels.removeAll()
        outputCountLabels.removeAll()
    }

    private func layoutProgressBar() {
        guard let rootView, let progressBarBackground, let progressBarFill else { return }
        let b = rootView.bounds

        let buttonSize: CGFloat = 32
        let pad: CGFloat = 16

        let leftColumnX = b.width * 0.083
        let rightColumnX = b.width * 0.75

        // Make bar span between columns (with padding)
        let barX = leftColumnX + buttonSize + pad
        let barRight = rightColumnX - pad
        let unclampedWidth = barRight - barX

        // Clamp for aesthetics if panel is huge
        let barWidth = min(unclampedWidth, 360)

        let barHeight: CGFloat = 20
        let barY = b.height * 0.18   // put it above the recipe grid

        progressBarBackground.frame = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)
        progressBarFill.frame = CGRect(x: barX, y: barY, width: progressBarFill.frame.width, height: barHeight)

        progressBarBackground.layer.cornerRadius = 4
        progressBarFill.layer.cornerRadius = 4
    }

    private func relayoutCountLabels() {
        func layout(_ labels: [UILabel], for buttons: [UIKit.UIButton]) {
            for (label, button) in zip(labels, buttons) {
                let w = button.bounds.width * 0.65
                let h = button.bounds.height * 0.40
                let inset = button.bounds.width * 0.10
                label.frame = CGRect(
                    x: button.frame.maxX - w - inset,
                    y: button.frame.maxY - h - inset,
                    width: w,
                    height: h
                )
            }
        }

        layout(fuelCountLabels, for: fuelSlotButtons)
        layout(inputCountLabels, for: inputSlotButtons)
        layout(outputCountLabels, for: outputSlotButtons)
    }

    private func attachCountLabel(to button: UIKit.UIButton) -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = .white
        label.textAlignment = .right
        label.isUserInteractionEnabled = false
        label.backgroundColor = .clear

        let w: CGFloat = button.bounds.width * 0.65
        let h: CGFloat = button.bounds.height * 0.40
        let inset: CGFloat = button.bounds.width * 0.10
        label.frame = CGRect(
            x: button.frame.maxX - w - inset,
            y: button.frame.maxY - h - inset,
            width: w,
            height: h
        )
        return label
    }

    private func setupSlotButtons() {
        guard let entity = currentEntity,
              let gameLoop = gameLoop,
              let rootView = rootView else { return }

        // Get building definition to know how many slots
        guard let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) else { return }

        let inputCount = buildingDef.inputSlots
        let outputCount = buildingDef.outputSlots
        let fuelCount = buildingDef.fuelSlots
        let panelBounds = rootView.bounds

        // Common constants for all slot types
            let buttonSizePoints: CGFloat = 32  // Already in points
            let spacingPoints: CGFloat = 8

        // Create fuel slots (left side, top) - UIKit buttons

        for i in 0..<fuelCount {
            // Position relative to panel bounds
            let buttonX = panelBounds.width * 0.083  // 8.3% from left
            let buttonY = panelBounds.height * 0.1 + (buttonSizePoints + spacingPoints) * CGFloat(i)  // 10% from top

            let button = UIKit.UIButton(frame: CGRect(x: buttonX, y: buttonY, width: buttonSizePoints, height: buttonSizePoints))

            // Configure button appearance
            button.backgroundColor = UIColor(red: 0.5, green: 0.5, blue: 0.6, alpha: 1.0) // Distinct blue-gray for fuel
            button.layer.borderColor = UIColor.white.cgColor
            button.layer.borderWidth = 1.0
            button.layer.cornerRadius = 4.0
            button.translatesAutoresizingMaskIntoConstraints = true

            fuelSlotButtons.append(button)

            // Add tap handler
            button.tag = i
            button.addTarget(self, action: #selector(fuelSlotTapped(_:)), for: UIControl.Event.touchUpInside)

            // Add to root view
            rootView.addSubview(button)

            // Count label positioned relative to button
            let label = attachCountLabel(to: button)
            fuelCountLabels.append(label)
            rootView.addSubview(label)
        }

        // Create input slots (left side, below fuel) - UIKit buttons
        for i in 0..<inputCount {
            // Position relative to panel bounds - vertical column on left
            let buttonX = panelBounds.width * 0.083  // Same X as fuel
            let buttonY = panelBounds.height * 0.325 + (buttonSizePoints + spacingPoints) * CGFloat(i)  // 32.5% from top

            let button = UIKit.UIButton(frame: CGRect(x: buttonX, y: buttonY, width: buttonSizePoints, height: buttonSizePoints))

            // Configure button appearance
            button.backgroundColor = UIColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1.0) // Distinct purple-gray for input
            button.layer.borderColor = UIColor.white.cgColor
            button.layer.borderWidth = 1.0
            button.layer.cornerRadius = 4.0
            button.translatesAutoresizingMaskIntoConstraints = true

            inputSlotButtons.append(button)

            // Add tap handler
            button.tag = i
            button.addTarget(self, action: #selector(inputSlotTapped(_:)), for: UIControl.Event.touchUpInside)

            // Add to root view
            rootView.addSubview(button)
            print("MachineUI: Created input slot button \(i) at (\(buttonX), \(buttonY))")

            // Count label positioned relative to button
            let label = attachCountLabel(to: button)
            inputCountLabels.append(label)
            rootView.addSubview(label)
        }

        // Create output slots (right side) - UIKit buttons
        for i in 0..<outputCount {
            // Position relative to panel bounds - vertical column on right
            let buttonX = panelBounds.width * 0.75  // 75% from left
            let buttonY = panelBounds.height * 0.325 + (buttonSizePoints + spacingPoints) * CGFloat(i)  // Same Y as inputs

            let button = UIKit.UIButton(frame: CGRect(x: buttonX, y: buttonY, width: buttonSizePoints, height: buttonSizePoints))

            // Configure button appearance
            button.backgroundColor = UIColor(red: 0.3, green: 0.5, blue: 0.3, alpha: 1.0) // Green for output
            button.layer.borderColor = UIColor.white.cgColor
            button.layer.borderWidth = 1.0
            button.layer.cornerRadius = 4.0
            button.translatesAutoresizingMaskIntoConstraints = true

            outputSlotButtons.append(button)

            // Add tap handler
            button.tag = i
            button.addTarget(self, action: #selector(outputSlotTapped(_:)), for: UIControl.Event.touchUpInside)

            // Add to root view
            rootView.addSubview(button)

            // Add to root view
            rootView.addSubview(button)

            // Count label positioned relative to button
            let label = attachCountLabel(to: button)
            outputCountLabels.append(label)
            rootView.addSubview(label)
        }
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
        print("MachineUI: loadRecipeImage called for '\(textureId)'")
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
        default:
            // Replace underscores with nothing for some cases
            filename = textureId.replacingOccurrences(of: "-", with: "_")
        }

        print("MachineUI: Looking for image file '\(filename).png'")
        // Try to load from bundle
        if let imagePath = Bundle.main.path(forResource: filename, ofType: "png") {
            print("MachineUI: Found image at \(imagePath)")
            return UIImage(contentsOfFile: imagePath)
        }

        print("MachineUI: Image not found")
        return nil
    }

    private var selectedRecipe: Recipe?
    private var craftButton: UIKit.UIButton?
    private var recipeLabels: [UIView] = [] // Now contains both labels and image views

    @objc private func recipeButtonTapped(_ sender: Any) {
        guard let button = sender as? UIKit.UIButton else { return }
        guard let gameLoop = gameLoop else { return }

        let availableRecipes = gameLoop.recipeRegistry.enabled
        let recipeIndex = Int(button.tag)

        if recipeIndex >= 0 && recipeIndex < availableRecipes.count {
            let recipe = availableRecipes[recipeIndex]

            // Just select the recipe - don't craft yet
            selectedRecipe = recipe

            // Update recipe buttons appearance
            updateRecipeButtonStates()

            // Show recipe details
            showRecipeDetails(recipe)

            // Show craft button
            showCraftButton()

            // Show tooltip for the selected recipe
            showRecipeTooltip(recipe)
        }
    }

    private func showRecipeTooltip(_ recipe: Recipe) {
        var tooltip = recipe.name
        let timeString = String(format: "%.1f", recipe.craftTime)
        tooltip += " (\(timeString)s)"

        // Check if player can craft this recipe
        var canCraft = true
        if let gameLoop = gameLoop {
            for input in recipe.inputs {
                if !gameLoop.player.inventory.has(itemId: input.itemId, count: input.count) {
                    canCraft = false
                    break
                }
            }
        }

        if !canCraft {
            tooltip += " - Missing ingredients"
        }

        // Show the tooltip using the game's tooltip system
        gameLoop?.inputManager?.onTooltip?(tooltip)
    }

    private func updateRecipeButtonStates() {
        guard let gameLoop = gameLoop else { return }

        // Update all recipe button appearances based on selection and craftability
        for (index, button) in recipeUIButtons.enumerated() {
            let availableRecipes = gameLoop.recipeRegistry.enabled
            if index < availableRecipes.count {
                let recipe = availableRecipes[index]

                var config = button.configuration ?? .plain()

                if selectedRecipe?.id == recipe.id {
                    // Selected recipe - highlight it
                    config.baseBackgroundColor = UIColor.blue.withAlphaComponent(0.3)
                } else {
                    // Check if player can craft this recipe
                    var canCraft = true
                    for input in recipe.inputs {
                        if !gameLoop.player.inventory.has(itemId: input.itemId, count: input.count) {
                            canCraft = false
                            break
                        }
                    }

                    if canCraft {
                        config.baseBackgroundColor = UIColor.green.withAlphaComponent(0.2)
                    } else {
                        config.baseBackgroundColor = UIColor.red.withAlphaComponent(0.2)
                    }
                }

                button.configuration = config
            }
        }
    }

    private func showRecipeDetails(_ recipe: Recipe) {
        // Clear previous recipe details
        clearRecipeDetails()

        // Show recipe requirements with icons similar to CraftingMenu
        guard let rootView = rootView else { return }

        let detailsY = rootView.bounds.height - 80
        let iconSize: CGFloat = 30
        let iconSpacing: CGFloat = 40

        // Show input requirements
        var currentX: CGFloat = 20
        for input in recipe.inputs {
            // Create item icon
            if let image = loadRecipeImage(for: input.itemId) {
                let iconView = UIImageView(image: image)
                iconView.frame = CGRect(x: currentX, y: detailsY, width: iconSize, height: iconSize)
                iconView.contentMode = .scaleAspectFit
                rootView.addSubview(iconView)
                recipeLabels.append(iconView) // Reuse recipeLabels array for all views

                // Create count label if count > 1
                if input.count > 1 {
                    let countLabel = createCountLabel(text: "\(input.count)", for: iconView)
                    rootView.addSubview(countLabel)
                    recipeLabels.append(countLabel)
                }
            }

            currentX += iconSpacing
        }

        // Arrow
        let arrowLabel = UILabel()
        arrowLabel.text = "→"
        arrowLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        arrowLabel.textColor = .white
        arrowLabel.sizeToFit()
        arrowLabel.frame = CGRect(x: currentX, y: detailsY, width: arrowLabel.frame.width, height: iconSize)
        arrowLabel.textAlignment = .center
        rootView.addSubview(arrowLabel)
        recipeLabels.append(arrowLabel)

        currentX += arrowLabel.frame.width + 8

        // Show output
        for output in recipe.outputs {
            // Create item icon
            if let image = loadRecipeImage(for: output.itemId) {
                let iconView = UIImageView(image: image)
                iconView.frame = CGRect(x: currentX, y: detailsY, width: iconSize, height: iconSize)
                iconView.contentMode = .scaleAspectFit
                rootView.addSubview(iconView)
                recipeLabels.append(iconView)

                // Create count label if count > 1
                if output.count > 1 {
                    let countLabel = createCountLabel(text: "\(output.count)", for: iconView)
                    rootView.addSubview(countLabel)
                    recipeLabels.append(countLabel)
                }
            }

            currentX += iconSpacing
        }
    }

    private func createCountLabel(text: String, for iconView: UIImageView) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 8, weight: .bold)
        label.textColor = .white
        label.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0)
        label.textAlignment = .center
        label.layer.cornerRadius = 2
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = true

        label.sizeToFit()
        let padding: CGFloat = 2
        let labelWidth = max(label.frame.width + padding * 2, 16)
        let labelHeight = max(label.frame.height + padding, 12)

        // Position in bottom-right corner of icon
        let iconFrame = iconView.frame
        label.frame = CGRect(
            x: iconFrame.maxX - labelWidth,
            y: iconFrame.maxY - labelHeight,
            width: labelWidth,
            height: labelHeight
        )

        return label
    }

    private func clearRecipeDetails() {
        for view in recipeLabels {
            view.removeFromSuperview()
        }
        recipeLabels.removeAll()
    }

    private func showCraftButton() {
        guard let rootView = rootView else { return }

        // Remove existing craft button
        craftButton?.removeFromSuperview()

        // Create craft button in bottom right
        let buttonWidth: CGFloat = 80
        let buttonHeight: CGFloat = 30
        let buttonX = rootView.bounds.width - buttonWidth - 20
        let buttonY = rootView.bounds.height - buttonHeight - 20

        let button = UIKit.UIButton(type: .system)
        button.frame = CGRect(x: buttonX, y: buttonY, width: buttonWidth, height: buttonHeight)
        button.setTitle("Craft", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.blue.withAlphaComponent(0.7)
        button.layer.cornerRadius = 6
        button.addTarget(self, action: #selector(craftButtonTapped), for: .touchUpInside)

        // Enable/disable based on whether selected recipe can be crafted
        updateCraftButtonState()

        rootView.addSubview(button)
        craftButton = button
    }

    private func updateCraftButtonState() {
        guard let craftButton = craftButton,
              let recipe = selectedRecipe,
              let gameLoop = gameLoop,
              let entity = currentEntity else { return }

        // Check if player has all required items
        var canCraftFromInventory = true
        for input in recipe.inputs {
            if !gameLoop.player.inventory.has(itemId: input.itemId, count: input.count) {
                canCraftFromInventory = false
                break
            }
        }

        // Check if machine has available output slots
        var hasOutputSpace = false
        if let machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity),
           let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) {
            let outputStartIndex = buildingDef.fuelSlots + buildingDef.inputSlots
            let outputEndIndex = outputStartIndex + buildingDef.outputSlots - 1

            // Check if any output slot is empty or can accept more of the output items
            for output in recipe.outputs {
                for slotIndex in outputStartIndex...outputEndIndex {
                    if let existingStack = machineInventory.slots[slotIndex] {
                        // Slot has an item - check if it's the same item and not full
                        if existingStack.itemId == output.itemId &&
                           existingStack.count < existingStack.maxStack {
                            hasOutputSpace = true
                            break
                        }
                    } else {
                        // Empty slot available
                        hasOutputSpace = true
                        break
                    }
                }
                if hasOutputSpace { break }
            }
        }

        let canCraft = canCraftFromInventory && hasOutputSpace

        craftButton.isEnabled = canCraft
        if !canCraftFromInventory {
            craftButton.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
        } else if !hasOutputSpace {
            craftButton.backgroundColor = UIColor.orange.withAlphaComponent(0.7) // Orange to indicate output slots full
        } else {
            craftButton.backgroundColor = UIColor.blue.withAlphaComponent(0.7)
        }
    }

    @objc private func craftButtonTapped() {
        guard let recipe = selectedRecipe,
              let entity = currentEntity,
              let gameLoop = gameLoop else { return }

        // Check if player has all required items
        var canCraftFromInventory = true
        for input in recipe.inputs {
            if !gameLoop.player.inventory.has(itemId: input.itemId, count: input.count) {
                canCraftFromInventory = false
                break
            }
        }

        // Check if machine has available output slots
        var hasOutputSpace = false
        if let machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity),
           let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) {
            let outputStartIndex = buildingDef.fuelSlots + buildingDef.inputSlots
            let outputEndIndex = outputStartIndex + buildingDef.outputSlots - 1

            // Check if any output slot is empty or can accept more of the output items
            for output in recipe.outputs {
                for slotIndex in outputStartIndex...outputEndIndex {
                    if let existingStack = machineInventory.slots[slotIndex] {
                        // Slot has an item - check if it's the same item and not full
                        if existingStack.itemId == output.itemId &&
                           existingStack.count < existingStack.maxStack {
                            hasOutputSpace = true
                            break
                        }
                    } else {
                        // Empty slot available
                        hasOutputSpace = true
                        break
                    }
                }
                if hasOutputSpace { break }
            }
        }

        // If no output space, show tooltip and don't craft
        if !hasOutputSpace {
            gameLoop.inputManager?.onTooltip?("All output slots filled. Tap on an output slot to clear it.")
            return
        }

        // If can't craft from inventory, don't proceed (though this shouldn't happen due to button state)
        if !canCraftFromInventory {
            return
        }

        // Perform the crafting logic (transfer items and start production)
        var playerInventory = gameLoop.player.inventory
        // Transfer items from player inventory to machine input slots
            guard var machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity),
                  let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) else {
                return
            }

            // Transfer each input item to the appropriate machine input slot
            for (index, input) in recipe.inputs.enumerated() {
                let machineSlotIndex = buildingDef.fuelSlots + index
                if machineSlotIndex < machineInventory.slots.count {
                    // Remove from player
                    let _ = playerInventory.remove(itemId: input.itemId, count: input.count)

                    // Add to machine input slot
                    machineInventory.slots[machineSlotIndex] = ItemStack(
                        itemId: input.itemId,
                        count: input.count,
                        maxStack: input.count // Use the required count as max
                    )
                }
            }

            // Update inventories
            gameLoop.world.add(machineInventory, to: entity)
            gameLoop.player.inventory = playerInventory

            // Set the recipe on the machine
            onSelectRecipeForMachine?(entity, recipe)

            // Update the UI
            updateMachine(entity)

            // Clear selection and hide craft button
            selectedRecipe = nil
            craftButton?.removeFromSuperview()
            craftButton = nil
            clearRecipeDetails()
            updateRecipeButtonStates()

            // Also update after a short delay to catch production completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateMachine(entity)
            }
    }

    override func open() {
        super.open()

        // Create single root view for all MachineUI content
        if rootView == nil {
            rootView = UIView(frame: panelFrameInPoints())
            rootView!.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.95)
            rootView!.isUserInteractionEnabled = true
            rootView!.layer.cornerRadius = 12
            rootView!.layer.borderWidth = 1
            rootView!.layer.borderColor = UIColor(white: 1, alpha: 0.15).cgColor

            // Create progress bar views (layout will be done after slot setup)
            progressBarBackground = UIView()
            progressBarBackground!.backgroundColor = UIColor.gray
            progressBarBackground!.layer.cornerRadius = 4
            rootView!.addSubview(progressBarBackground!)

            progressBarFill = UIView()
            progressBarFill!.backgroundColor = UIColor.blue
            progressBarFill!.layer.cornerRadius = 4
            rootView!.addSubview(progressBarFill!)
        }

        // Set up UIKit components
        if recipeScrollView == nil {
            setupRecipeScrollView()
        }
        setupRecipeButtons()

        // Clear any previous recipe selection and update button states
        selectedRecipe = nil
        updateRecipeButtonStates()

        // Set up UIKit slot buttons (ensure they're created when opening)
        if currentEntity != nil {
            clearSlotUI()
            setupSlotButtons()
            layoutProgressBar()
            relayoutCountLabels()
            // Update the UI with current machine state
            updateMachine(currentEntity!)
        }

        // Add root view to hierarchy (AFTER content is added to it)
        if let rootView = rootView {
            onAddRootView?(rootView)
        }

        // Add scroll view inside panel view
        if let recipeScrollView = recipeScrollView, let rootView = rootView {
            rootView.addSubview(recipeScrollView)
        }

        // Add appropriate labels to the view (count labels are panel-local, not global)
        var allLabels: [UILabel] = []
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

        print("MachineUI: Total component labels to add: \(allLabels.count)")
        // Labels are now handled by components within the rootView

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

        // Component scroll views are handled by components within the rootView
    }

    // Public method to get all scroll views (needed for touch event handling)
    func getAllScrollViews() -> [UIScrollView] {
        var scrollViews: [UIScrollView] = []
        for component in machineComponents {
            scrollViews.append(contentsOf: component.getScrollViews())
        }
        if let recipeScrollView = recipeScrollView {
            scrollViews.append(recipeScrollView)
        }
        return scrollViews
    }

    func getTooltip(at screenPos: Vector2) -> String? {
        guard isOpen, let rootView = rootView, let recipeScrollView = recipeScrollView else { return nil }

        // Convert screen position to UIKit points
        let scale = Float(UIScreen.main.scale)
        let screenPosInPoints = screenPos / scale

        // Check if position is within the scroll view bounds
        let scrollViewFrame = recipeScrollView.frame
        let scrollViewBounds = CGRect(
            x: rootView.frame.minX + scrollViewFrame.minX,
            y: rootView.frame.minY + scrollViewFrame.minY,
            width: scrollViewFrame.width,
            height: scrollViewFrame.height
        )

        guard scrollViewBounds.contains(CGPoint(x: CGFloat(screenPosInPoints.x), y: CGFloat(screenPosInPoints.y))) else {
            // Check craft button if outside scroll view
            return getCraftButtonTooltip(at: screenPosInPoints)
        }

        // Convert to scroll view content coordinates
        let contentPos = CGPoint(
            x: CGFloat(screenPosInPoints.x) - scrollViewBounds.minX + recipeScrollView.contentOffset.x,
            y: CGFloat(screenPosInPoints.y) - scrollViewBounds.minY + recipeScrollView.contentOffset.y
        )

        // Check recipe buttons in content coordinates
        for (index, button) in recipeUIButtons.enumerated() {
            if button.frame.contains(contentPos) {
                let availableRecipes = gameLoop?.recipeRegistry.enabled ?? []
                if index < availableRecipes.count {
                    let recipe = availableRecipes[index]

                    // Show recipe name and crafting time
                    var tooltip = recipe.name
                    let timeString = String(format: "%.1f", recipe.craftTime)
                    tooltip += " (\(timeString)s)"

                    // If this recipe is selected, add a note
                    if selectedRecipe?.id == recipe.id {
                        tooltip += " [Selected]"
                    }

                    // Check if player can craft this recipe
                    var canCraft = true
                    if let gameLoop = gameLoop {
                        for input in recipe.inputs {
                            if !gameLoop.player.inventory.has(itemId: input.itemId, count: input.count) {
                                canCraft = false
                                break
                            }
                        }
                    }

                    if !canCraft {
                        tooltip += " - Missing ingredients"
                    }

                    return tooltip
                }
            }
        }

        return nil
    }

    private func getCraftButtonTooltip(at position: Vector2) -> String? {
        guard let craftButton = craftButton,
              let recipe = selectedRecipe,
              let entity = currentEntity,
              let gameLoop = gameLoop else { return nil }

        let buttonFrame = craftButton.frame
        let buttonBounds = CGRect(
            x: rootView!.frame.minX + buttonFrame.minX,
            y: rootView!.frame.minY + buttonFrame.minY,
            width: buttonFrame.width,
            height: buttonFrame.height
        )

        guard buttonBounds.contains(CGPoint(x: CGFloat(position.x), y: CGFloat(position.y))) else { return nil }

        // Check if output slots are full
        var hasOutputSpace = false
        if let machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity),
           let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) {
            let outputStartIndex = buildingDef.fuelSlots + buildingDef.inputSlots
            let outputEndIndex = outputStartIndex + buildingDef.outputSlots - 1

            // Check if any output slot is empty or can accept more of the output items
            for output in recipe.outputs {
                for slotIndex in outputStartIndex...outputEndIndex {
                    if let existingStack = machineInventory.slots[slotIndex] {
                        // Slot has an item - check if it's the same item and not full
                        if existingStack.itemId == output.itemId &&
                           existingStack.count < existingStack.maxStack {
                            hasOutputSpace = true
                            break
                        }
                    } else {
                        // Empty slot available
                        hasOutputSpace = true
                        break
                    }
                }
                if hasOutputSpace { break }
            }
        }

        if !hasOutputSpace {
            return "All output slots filled. Tap on an output slot to clear it."
        } else {
            return "Craft \(recipe.name)"
        }
    }


    override func close() {
        // Clear recipe selection and details
        selectedRecipe = nil
        craftButton?.removeFromSuperview()
        craftButton = nil
        clearRecipeDetails()

        // Remove global labels from the view (count labels are panel-local)
        var allLabels: [UILabel] = []
        allLabels += researchProgressLabels
        // Add labels from components
        for component in machineComponents {
            allLabels += component.getLabels()
        }
        if let powerLabel = powerLabel {
            allLabels.append(powerLabel)
        }
        // Labels are removed when rootView is removed

        // Clear label text to ensure they're properly reset
        for label in allLabels {
            label.text = ""
            label.isHidden = true
        }

        // Fluid labels cleared by component cleanup

        // Remove rocket launch button
        launchButton = nil

        // Clear UIKit slot UI
        clearSlotUI()

        // Remove root view from hierarchy
        if let rootView = rootView {
            onRemoveRootView?(rootView)
        }

        // Clear references
        rootView = nil
        recipeScrollView = nil

        // Component scroll views are removed when rootView is removed

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
            let startIndex = min(recipe.inputs.count, inputSlots.count)
            for i in startIndex..<inputSlots.count {
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
            let startIndex = min(recipe.outputs.count, outputSlots.count)
            for i in startIndex..<outputSlots.count {
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
        print("MachineUI: updateCountLabels called")
        guard let gameLoop = gameLoop,
              let inventory = gameLoop.world.get(InventoryComponent.self, for: entity) else {
            print("MachineUI: updateCountLabels - no inventory")
            return
        }
        print("MachineUI: updateCountLabels - found inventory with \(inventory.slots.count) slots")

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

        // Update fuel slot labels and button images
        for i in 0..<fuelCountLabels.count {
            if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                // Update button image
                if i < fuelSlotButtons.count {
                    if let image = loadRecipeImage(for: item.itemId) {
                        // Scale image to 80% of button size like InventoryUI does for icons
                        let buttonSizePoints: CGFloat = 32
                        let scaledSize = CGSize(width: buttonSizePoints * 0.8, height: buttonSizePoints * 0.8)
                        UIGraphicsBeginImageContextWithOptions(scaledSize, false, 0.0)
                        image.draw(in: CGRect(origin: .zero, size: scaledSize))
                        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                        UIGraphicsEndImageContext()

                        fuelSlotButtons[i].setImage(scaledImage, for: .normal)
                    } else {
                        fuelSlotButtons[i].setImage(nil, for: .normal)
                    }
                }

                // Update label - only show if count > 1
                if item.count > 1 {
                    fuelCountLabels[i].text = "\(item.count)"
                    fuelCountLabels[i].isHidden = false
            } else {
                    fuelCountLabels[i].text = ""
                fuelCountLabels[i].isHidden = true
                }
            } else {
                // Clear button image
                if i < fuelSlotButtons.count {
                    fuelSlotButtons[i].setImage(nil, for: .normal)
                }

                fuelCountLabels[i].text = ""
                fuelCountLabels[i].isHidden = true
            }
            inventoryIndex += 1
        }

        // Update input slot labels and button images
        for i in 0..<inputCountLabels.count {
            print("MachineUI: Updating input slot \(i), inventoryIndex \(inventoryIndex)")
            if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                print("MachineUI: Input slot \(i) has item: \(item.itemId) x\(item.count)")
                // Update button image
                if i < inputSlotButtons.count {
                    if let image = loadRecipeImage(for: item.itemId) {
                        print("MachineUI: Loading image for \(item.itemId)")
                        // Scale image to 80% of button size like InventoryUI does for icons
                        let buttonSizePoints: CGFloat = 32
                        let scaledSize = CGSize(width: buttonSizePoints * 0.8, height: buttonSizePoints * 0.8)
                        UIGraphicsBeginImageContextWithOptions(scaledSize, false, 0.0)
                        image.draw(in: CGRect(origin: .zero, size: scaledSize))
                        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                        UIGraphicsEndImageContext()

                        inputSlotButtons[i].setImage(scaledImage, for: .normal)
                        print("MachineUI: Set image for input slot \(i)")
                    } else {
                        print("MachineUI: No image found for \(item.itemId)")
                        inputSlotButtons[i].setImage(nil, for: .normal)
                    }
                }

                // Update label - only show if count > 1
                if item.count > 1 {
                    inputCountLabels[i].text = "\(item.count)"
                    inputCountLabels[i].isHidden = false
                } else {
                    inputCountLabels[i].text = ""
                    inputCountLabels[i].isHidden = true
                }
            } else {
                print("MachineUI: Input slot \(i) is empty")
                // Clear button image
                if i < inputSlotButtons.count {
                    inputSlotButtons[i].setImage(nil, for: .normal)
                }

                inputCountLabels[i].text = ""
                inputCountLabels[i].isHidden = true
            }
            inventoryIndex += 1
        }

        // Update output slot labels and button images
        for i in 0..<outputCountLabels.count {
            if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                // Update button image
                if i < outputSlotButtons.count {
                    if let image = loadRecipeImage(for: item.itemId) {
                        // Scale image to 80% of button size like InventoryUI does for icons
                        let buttonSizePoints: CGFloat = 32
                        let scaledSize = CGSize(width: buttonSizePoints * 0.8, height: buttonSizePoints * 0.8)
                        UIGraphicsBeginImageContextWithOptions(scaledSize, false, 0.0)
                        image.draw(in: CGRect(origin: .zero, size: scaledSize))
                        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                        UIGraphicsEndImageContext()

                        outputSlotButtons[i].setImage(scaledImage, for: .normal)
                    } else {
                        outputSlotButtons[i].setImage(nil, for: .normal)
                    }
                }

                // Update label - only show if count > 1
                if item.count > 1 {
                    outputCountLabels[i].text = "\(item.count)"
                    outputCountLabels[i].isHidden = false
            } else {
                    outputCountLabels[i].text = ""
                outputCountLabels[i].isHidden = true
                }
            } else {
                // Clear button image
                if i < outputSlotButtons.count {
                    outputSlotButtons[i].setImage(nil, for: .normal)
                }

                outputCountLabels[i].text = ""
                outputCountLabels[i].isHidden = true
            }
            inventoryIndex += 1
        }
    }

    func updateMachine(_ entity: Entity) {
        print("MachineUI: updateMachine called")
        setupSlotsForMachine(entity)
        updateCountLabels(entity)
        relayoutCountLabels()

        // Update machine components
        for component in machineComponents {
            component.updateUI(for: entity, in: self)
        }

        // Update craft button state if one is shown
        if selectedRecipe != nil {
            updateCraftButtonState()
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
        if let rootView = rootView {
            rootView.addSubview(button)
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
        print("MachineUI: fuelSlotTapped tag=\(sender.tag)")
        guard let entity = currentEntity, let gameLoop = gameLoop else { return }

        let slotIndex = sender.tag

        // Check if the slot has an item
        print("MachineUI: Checking slot \(slotIndex)")
        if let machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity) {
            print("MachineUI: Found inventory with \(machineInventory.slots.count) slots")
            if slotIndex < machineInventory.slots.count {
                if let item = machineInventory.slots[slotIndex] {
                    print("MachineUI: Slot \(slotIndex) has item: \(item.itemId) x\(item.count)")
                    // Slot has an item - take it out
                    handleSlotTap(entity: entity, slotIndex: slotIndex, gameLoop: gameLoop)
                } else {
                    print("MachineUI: Slot \(slotIndex) is empty")
                    // Slot is empty - open inventory to add items
                    handleEmptySlotTap(entity: entity, slotIndex: slotIndex)
                }
            } else {
                print("MachineUI: Slot index \(slotIndex) >= inventory count \(machineInventory.slots.count)")
                handleEmptySlotTap(entity: entity, slotIndex: slotIndex)
            }
        } else {
            print("MachineUI: No inventory found for entity")
            handleEmptySlotTap(entity: entity, slotIndex: slotIndex)
        }
    }

    @objc private func inputSlotTapped(_ sender: UIKit.UIButton) {
        print("MachineUI: inputSlotTapped tag=\(sender.tag)")
        guard let entity = currentEntity, let gameLoop = gameLoop else { return }

        guard let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) else { return }

        let slotIndex = buildingDef.fuelSlots + sender.tag

        // Check if the slot has an item
        if let machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity),
           slotIndex < machineInventory.slots.count,
           machineInventory.slots[slotIndex] != nil {
            // Slot has an item - take it out
            handleSlotTap(entity: entity, slotIndex: slotIndex, gameLoop: gameLoop)
        } else {
            // Slot is empty - open inventory to add items
            handleEmptySlotTap(entity: entity, slotIndex: slotIndex)
        }
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
        print("MachineUI: handleEmptySlotTap called for slot \(slotIndex)")
        // Open inventory UI in machine input mode for this slot
        onOpenInventoryForMachine?(entity, slotIndex)
        print("MachineUI: onOpenInventoryForMachine callback called")
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

        // Outside panel -> close and consume the tap
        if !frame.contains(position) {
            close()
            return true  // Consume to prevent other interactions
        }

        // Inside panel -> DO NOT consume; let UIKit hit-test buttons/scroll views
        return false
    }

    func handleScroll(at position: Vector2, delta: Vector2) -> Bool {
        // UIKit handles its own scrolling - no Metal scroll delegation needed
        return false
    }

    override func handleDrag(from startPos: Vector2, to endPos: Vector2) -> Bool {
        // Let UIKit handle scrolling/drags inside the panel
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
            let p = max(0, min(1, powerAvailability))
            fillWidth = backgroundFrame.width * CGFloat(p)
            fillColor = UIColor.blue
        } else {
            // Progress bar (green)
            let p = max(0, min(1, progress))
            fillWidth = backgroundFrame.width * CGFloat(p)
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
