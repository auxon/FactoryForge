import Foundation
import UIKit

// Use UIKit's UIButton explicitly to avoid conflict with custom UIButton
typealias UIKitButton = UIKit.UIButton

/// Callback type for recipe selection
typealias RecipeSelectionCallback = (Entity, Recipe) -> Void

/// Unified layout system for MachineUI positioning
struct MachineUILayout {
    let W: CGFloat
    let H: CGFloat

    let margin: CGFloat = 16
    let slotSize: CGFloat = 32
    let slotSpacing: CGFloat = 8

    // Columns
    let leftColX: CGFloat
    let midColX: CGFloat
    let tankColX: CGFloat

    // Bands
    let topBandY: CGFloat
    let midBandY: CGFloat
    let boilerLaneY: CGFloat  // Centered position for boiler water/steam indicators
    let bottomBandY: CGFloat

    init(bounds: CGRect) {
        W = bounds.width
        H = bounds.height

        leftColX = max(margin, W * 0.083)           // consistent with standard layout
        tankColX = max(W * 0.78, W - 120)           // push tanks further right than 0.75
        midColX  = (leftColX + tankColX) * 0.5      // generic "middle"

        topBandY = H * 0.10
        midBandY = H * 0.28
        boilerLaneY = H * 0.42  // More centered for boiler indicators
        bottomBandY = H * 0.58
    }

    var recipeRegionX: CGFloat { leftColX + slotSize + margin }
    var recipeRegionWidth: CGFloat { (tankColX - margin) - recipeRegionX }

    // Chemical plant specific columns
    var chemOutputColX: CGFloat { tankColX - (slotSize + margin + 10) }
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

    // Fluid color utility method
    func getFluidColor(for fluidType: FluidType) -> UIColor {
        switch fluidType {
        case .water:
            return UIColor.blue.withAlphaComponent(0.7)
        case .steam:
            return UIColor.white.withAlphaComponent(0.7)
        case .crudeOil:
            return UIColor.black.withAlphaComponent(0.7)
        case .heavyOil:
            return UIColor.red.withAlphaComponent(0.7)
        case .lightOil:
            return UIColor.yellow.withAlphaComponent(0.7)
        case .petroleumGas:
            return UIColor.green.withAlphaComponent(0.7)
        case .sulfuricAcid:
            return UIColor.orange.withAlphaComponent(0.7)
        case .lubricant:
            return UIColor.purple.withAlphaComponent(0.7)
        }
    }

    // UIKit panel container view
    // rootView is now the single container for all MachineUI UIKit content

    // UIKit progress bar
    private var progressBarBackground: UIView?
    private var progressBarFill: UIView?
    private var progressStatusLabel: UILabel?

    // Chemical plant tank UI references
    private var chemTankViews: [UIView] = []
    private var chemFillViews: [UIView] = []
    private var chemTankLabels: [UILabel] = []
    private var chemHeaders: [UILabel] = []

    // Oil refinery tank UI references
    private var refineryTankViews: [UIView] = []
    private var refineryFillViews: [UIView] = []
    private var refineryTankLabels: [UILabel] = []
    private var refineryHeaders: [UILabel] = []

    // UIKit scroll view for recipe buttons
    private var recipeScrollView: ClearScrollView?

    // UIKit recipe buttons
    private var recipeUIButtons: [UIKitButton] = []

    // Filtered recipes for current machine (to ensure consistent indexing)
    private var filteredRecipes: [Recipe] = []

    /// Convert Metal frame to UIKit points for panel container
    func panelFrameInPoints() -> CGRect {
        let screenScale = UIScreen.main.scale
        return CGRect(
            x: CGFloat(frame.minX) / screenScale,
            y: CGFloat(frame.minY) / screenScale,
            width: CGFloat(frame.size.x) / screenScale,
            height: CGFloat(frame.size.y) / screenScale
        )
    }

    // Research progress labels for labs
    private var researchProgressLabels: [UILabel] = []

    // Power label for generators
    private var powerLabel: UILabel?

    // Rocket launch button for rocket silos
    private var launchButton: UIKit.UIButton?

    // Single root view for all MachineUI UIKit content
    private(set) var rootView: UIView?

    private var lastInventorySignature: Int?
    private var lastInventoryEntity: Entity?

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

        // Initialize slot arrays if we have current entity and building definition
        if let entity = currentEntity, let gameLoop = gameLoop,
           let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) {

            // Clear existing slots
            inputSlots.removeAll()
            outputSlots.removeAll()
            fuelSlots.removeAll()

            // Create InventorySlot objects for each slot type
            for i in 0..<buildingDef.inputSlots {
                inputSlots.append(InventorySlot(frame: Rect(x: 0, y: 0, width: 32, height: 32), index: i))
            }
            for i in 0..<buildingDef.outputSlots {
                outputSlots.append(InventorySlot(frame: Rect(x: 0, y: 0, width: 32, height: 32), index: i))
            }
            for i in 0..<buildingDef.fuelSlots {
                fuelSlots.append(InventorySlot(frame: Rect(x: 0, y: 0, width: 32, height: 32), index: i))
            }

        } else {
        }
    }

    func setEntity(_ entity: Entity) {
        currentEntity = entity
        lastInventoryEntity = nil
        lastInventorySignature = nil

        // Clear existing components
        machineComponents.removeAll()

        // Determine machine type and create appropriate components
        if let gameLoop = gameLoop {
            // Check for fluid-based machines (including tanks), but skip for chemical plants (handled in slot setup)
            let hasFluidProducer = gameLoop.world.has(FluidProducerComponent.self, for: entity)
            let hasFluidConsumer = gameLoop.world.has(FluidConsumerComponent.self, for: entity)
            let hasFluidTank = gameLoop.world.has(FluidTankComponent.self, for: entity)

            // Check building types for special handling
            var isChemicalPlant = false
            var isOilRefinery = false
            if let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) {
                isChemicalPlant = buildingDef.type == .chemicalPlant
                isOilRefinery = buildingDef.type == .oilRefinery
            }

            if (hasFluidProducer || hasFluidConsumer || hasFluidTank) && !(isChemicalPlant || isOilRefinery) {
                machineComponents.append(FluidMachineUIComponent())
            } else if isChemicalPlant {
            } else if isOilRefinery {
            } else {
            }

            // Check for pipes
            if gameLoop.world.has(PipeComponent.self, for: entity) {
                machineComponents.append(PipeConnectionUIComponent())
            }

            // Check for assembly machines
            if gameLoop.world.has(AssemblerComponent.self, for: entity) {
                let recipeCallback: RecipeSelectionCallback = { [weak self] (entity: Entity, recipe: Recipe) in
                    self?.onSelectRecipeForMachine?(entity, recipe)
                }
                machineComponents.append(AssemblyMachineUIComponent(recipeSelectionCallback: recipeCallback))
            }
        }


        // Setup common UI elements
        setupSlots()
        setupSlotsForMachine(entity)

        // Setup machine-specific UI components
        for (index, component) in machineComponents.enumerated() {
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


    private func setupRecipeScrollView(for entity: Entity, gameLoop: GameLoop) {
        // Create scroll view for recipe buttons (in points, relative to root view)
        guard let rootView = rootView else { return }
        let L = MachineUILayout(bounds: rootView.bounds)

        // Position scroll view at bottom of panel
        let scrollViewHeight: CGFloat = 130
        let scrollViewWidth: CGFloat = L.recipeRegionWidth
        let scrollViewX: CGFloat = L.recipeRegionX
        let scrollViewY: CGFloat = L.bottomBandY

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

        // Add subtle background/border for recipe panel
        scrollView.backgroundColor = UIColor(white: 0.1, alpha: 0.3)
        scrollView.layer.borderColor = UIColor.gray.cgColor
        scrollView.layer.borderWidth = 1.0
        scrollView.layer.cornerRadius = 4.0

        // Add recipe section header
        let headerLabel = UILabel(frame: CGRect(x: scrollViewX, y: scrollViewY - 18, width: scrollViewWidth, height: 16))
        headerLabel.text = "Available Recipes"
        headerLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        headerLabel.textColor = .lightGray
        headerLabel.textAlignment = .center
        rootView.addSubview(headerLabel)

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

    private func layoutAll() {
        layoutProgressBar()
        relayoutCountLabels()
        // Note: Tank updates are handled in updateMachine() for real-time updates
    }

    private func layoutProgressBar() {
        guard let rootView, let progressBarBackground, let progressBarFill else { return }
        let L = MachineUILayout(bounds: rootView.bounds)

        let pad: CGFloat = 16

        // Make bar span the recipe region (with padding)
        let barX = L.recipeRegionX + pad
        let barRight = L.recipeRegionX + L.recipeRegionWidth - pad
        let unclampedWidth = barRight - barX

        // Clamp for aesthetics if panel is huge
        let barWidth = min(unclampedWidth, 360)

        let barHeight: CGFloat = 20
        let barY = L.topBandY   // put it in the top band

        progressBarBackground.frame = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)
        progressBarFill.frame = CGRect(x: barX, y: barY, width: progressBarFill.frame.width, height: barHeight)

        progressBarBackground.layer.cornerRadius = 4
        progressBarFill.layer.cornerRadius = 4

        // Position status label below progress bar
        if let statusLabel = progressStatusLabel {
            statusLabel.frame = CGRect(x: barX, y: barY + barHeight + 4, width: barWidth, height: 14)
        }
    }

    func positionProgressStatusLabel(centerX: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat = 14) {
        guard let statusLabel = progressStatusLabel else { return }
        let labelWidth = max(width, 80)
        statusLabel.frame = CGRect(x: centerX - labelWidth * 0.5, y: y, width: labelWidth, height: height)
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
              let rootView = rootView else {
            return
        }
        
        // Get building definition to know how many slots
        guard let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) else {
            return
        }
        
        
        let inputCount = buildingDef.inputSlots
        let outputCount = buildingDef.outputSlots
        let fuelCount = buildingDef.fuelSlots
        let panelBounds = rootView.bounds
        
        // Common constants for all slot types
        let buttonSizePoints: CGFloat = 32  // Already in points
        let spacingPoints: CGFloat = 8
        
        // Special layout for chemical plants and oil refineries
        if buildingDef.type == .chemicalPlant {
            setupChemicalPlantSlotButtons(buildingDef, panelBounds: panelBounds)
            return
        } else if buildingDef.type == .oilRefinery {
            setupOilRefinerySlotButtons(buildingDef, panelBounds: panelBounds)
            return
        }

        // Standard slot layout for all other buildings
        setupStandardSlotButtons(buildingDef, inputCount: inputCount, outputCount: outputCount, fuelCount: fuelCount, panelBounds: panelBounds, buttonSizePoints: buttonSizePoints, spacingPoints: spacingPoints)
    }

    private func setupStandardSlotButtons(_ buildingDef: BuildingDefinition, inputCount: Int, outputCount: Int, fuelCount: Int, panelBounds: CGRect, buttonSizePoints: CGFloat, spacingPoints: CGFloat) {
        guard let rootView = rootView else { return }

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

            // Count label positioned relative to button
            let label = attachCountLabel(to: button)
            inputCountLabels.append(label)
            rootView.addSubview(label)
        }

        // Create output slots (right side, before tank column) - UIKit buttons
        for i in 0..<outputCount {
            let buttonX: CGFloat
            let buttonY: CGFloat
            if buildingDef.type == .miner && outputCount == 1 {
                buttonX = (panelBounds.width - buttonSizePoints) * 0.5
                buttonY = (panelBounds.height - buttonSizePoints) * 0.5
            } else {
                // Position relative to panel bounds - column between machine and tanks
                buttonX = panelBounds.width * 0.65  // 65% from left (between machine and tanks)
                buttonY = panelBounds.height * 0.325 + (buttonSizePoints + spacingPoints) * CGFloat(i)  // Same Y as inputs
            }

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

            // Count label positioned relative to button
            let label = attachCountLabel(to: button)
            outputCountLabels.append(label)
            rootView.addSubview(label)
        }
    }

    private func setupChemicalPlantSlotButtons(_ buildingDef: BuildingDefinition, panelBounds: CGRect) {
        let L = MachineUILayout(bounds: panelBounds)

        // Chemical plant layout using unified coordinate system:
        // - Input slots in left column
        // - Output slots to the left of tanks
        // - Fluid tank column on far right

        // Create input slots (left column) - 3 slots for chemical plant
        for i in 0..<buildingDef.inputSlots {
            let buttonX = L.leftColX
            let buttonY = L.midBandY + (L.slotSize + L.slotSpacing) * CGFloat(i)

            let button = UIKit.UIButton(frame: CGRect(x: buttonX, y: buttonY, width: L.slotSize, height: L.slotSize))
            button.backgroundColor = UIColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1.0)
            button.layer.borderColor = UIColor.white.cgColor
            button.layer.borderWidth = 1.0
            button.layer.cornerRadius = 4.0
            button.translatesAutoresizingMaskIntoConstraints = true

            inputSlotButtons.append(button)
            button.tag = i
            button.addTarget(self, action: #selector(inputSlotTapped(_:)), for: UIControl.Event.touchUpInside)
            rootView?.addSubview(button)

            let label = attachCountLabel(to: button)
            inputCountLabels.append(label)
            rootView?.addSubview(label)
        }

        // Create output slots (to the left of tanks) - 2 slots for chemical plant
        for i in 0..<buildingDef.outputSlots {
            let buttonX = L.chemOutputColX
            let buttonY = L.midBandY + (L.slotSize + L.slotSpacing) * CGFloat(i)

            let button = UIKit.UIButton(frame: CGRect(x: buttonX, y: buttonY, width: L.slotSize, height: L.slotSize))
            button.backgroundColor = UIColor(red: 0.3, green: 0.5, blue: 0.3, alpha: 1.0)
            button.layer.borderColor = UIColor.white.cgColor
            button.layer.borderWidth = 1.0
            button.layer.cornerRadius = 4.0
            button.translatesAutoresizingMaskIntoConstraints = true

            outputSlotButtons.append(button)
            button.tag = i
            button.addTarget(self, action: #selector(outputSlotTapped(_:)), for: UIControl.Event.touchUpInside)
            rootView?.addSubview(button)

            let label = attachCountLabel(to: button)
            outputCountLabels.append(label)
            rootView?.addSubview(label)
        }

        // Create fluid tank indicators (fixed column on right)
        setupChemicalPlantFluidTanks(panelBounds)
    }

    private func setupChemicalPlantFluidTanks(_ panelBounds: CGRect) {
        guard let entity = currentEntity,
              let gameLoop = gameLoop,
              let fluidTankComponent = gameLoop.world.get(FluidTankComponent.self, for: entity),
              let rootView = rootView else {
            return
        }

        let L = MachineUILayout(bounds: panelBounds)

        let tankWidth: CGFloat = 60
        let tankHeight: CGFloat = 40
        let tankSpacing: CGFloat = 20

        // Clear existing tank UI
        chemTankViews.forEach { $0.removeFromSuperview() }
        chemFillViews.forEach { $0.removeFromSuperview() }
        chemTankLabels.forEach { $0.removeFromSuperview() }
        chemHeaders.forEach { $0.removeFromSuperview() }

        chemTankViews.removeAll()
        chemFillViews.removeAll()
        chemTankLabels.removeAll()
        chemHeaders.removeAll()

        // Input Tanks Header
        let inputHeaderLabel = UILabel(frame: CGRect(x: L.tankColX, y: L.midBandY - 20, width: tankWidth, height: 15))
        inputHeaderLabel.text = "INPUT"
        inputHeaderLabel.font = UIFont.systemFont(ofSize: 8, weight: .bold)
        inputHeaderLabel.textColor = .cyan
        inputHeaderLabel.textAlignment = .center
        rootView.addSubview(inputHeaderLabel)
        chemHeaders.append(inputHeaderLabel)

        // Input tanks (top section)
        for i in 0..<min(fluidTankComponent.tanks.count, 2) {  // First 2 tanks as inputs
            let tankY = L.midBandY + CGFloat(i) * (tankHeight + tankSpacing)

            // Tank background
            let tankView = UIView(frame: CGRect(x: L.tankColX, y: tankY, width: tankWidth, height: tankHeight))
            tankView.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.8)
            tankView.layer.borderColor = UIColor.cyan.cgColor
            tankView.layer.borderWidth = 1.0
            tankView.layer.cornerRadius = 3.0
            tankView.clipsToBounds = true  // Enable clipping for fill views
            rootView.addSubview(tankView)
            chemTankViews.append(tankView)

            // Fluid fill indicator (inside tank view for proper clipping)
            if i < fluidTankComponent.tanks.count {
                let tank = fluidTankComponent.tanks[i]
                let fillLevel = fluidTankComponent.maxCapacity > 0 ? tank.amount / fluidTankComponent.maxCapacity : 0
                let fillHeight = tankHeight * CGFloat(fillLevel)

                let fillView = UIView(frame: CGRect(x: 0, y: tankHeight - fillHeight, width: tankWidth, height: fillHeight))
                let fluidColor = getFluidColor(for: tank.type)
                fillView.backgroundColor = fluidColor.withAlphaComponent(0.8)
                tankView.addSubview(fillView)
                chemFillViews.append(fillView)
            }

            // Tank label - positioned clearly below tank
            let labelY = tankY + tankHeight + 4  // 4px below tank for clear separation
            let label = UILabel(frame: CGRect(x: L.tankColX, y: labelY, width: tankWidth, height: 15))
            if i < fluidTankComponent.tanks.count {
                let tank = fluidTankComponent.tanks[i]
                let cap = fluidTankComponent.maxCapacity
                if tank.amount <= 0.0001 {
                    label.text = "Empty: 0/\(Int(cap))"
                } else {
                    label.text = "\(tank.type.rawValue): \(Int(tank.amount))/\(Int(cap))"
                }
            } else {
                label.text = "Empty: 0/\(Int(fluidTankComponent.maxCapacity))"
            }
            label.font = UIFont.systemFont(ofSize: 8, weight: .medium)
            label.textColor = .cyan
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            rootView.addSubview(label)
            chemTankLabels.append(label)
        }

        // Output Tanks Header
        let outputHeaderY = L.midBandY + 2 * (tankHeight + tankSpacing) + 5
        let outputHeaderLabel = UILabel(frame: CGRect(x: L.tankColX, y: outputHeaderY, width: tankWidth, height: 15))
        outputHeaderLabel.text = "OUTPUT"
        outputHeaderLabel.font = UIFont.systemFont(ofSize: 8, weight: .bold)
        outputHeaderLabel.textColor = .green
        outputHeaderLabel.textAlignment = .center
        rootView.addSubview(outputHeaderLabel)

        // Output tanks (bottom section)
        let outputTankStartY = outputHeaderY + 15 + 5  // Space after header
        for i in 2..<fluidTankComponent.tanks.count {  // Tanks 2+ as outputs
            let tankIndex = i - 2  // Local index for output tanks
            let tankY = outputTankStartY + CGFloat(tankIndex) * (tankHeight + tankSpacing)

            // Tank background
            let tankView = UIView(frame: CGRect(x: L.tankColX, y: tankY, width: tankWidth, height: tankHeight))
            tankView.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.8)
            tankView.layer.borderColor = UIColor.green.cgColor
            tankView.layer.borderWidth = 1.0
            tankView.layer.cornerRadius = 3.0
            tankView.clipsToBounds = true  // Enable clipping for fill views
            rootView.addSubview(tankView)
            chemTankViews.append(tankView)

            // Fluid fill indicator (inside tank view for proper clipping)
            let tank = fluidTankComponent.tanks[i]
            let fillLevel = fluidTankComponent.maxCapacity > 0 ? tank.amount / fluidTankComponent.maxCapacity : 0
            let fillHeight = tankHeight * CGFloat(fillLevel)

            let fillView = UIView(frame: CGRect(x: 0, y: tankHeight - fillHeight, width: tankWidth, height: fillHeight))
            let fluidColor = getFluidColor(for: tank.type)
            fillView.backgroundColor = fluidColor.withAlphaComponent(0.8)
            tankView.addSubview(fillView)
            chemFillViews.append(fillView)

            // Tank label - positioned clearly below tank
            let labelY = tankY + tankHeight + 4  // 4px below tank for clear separation
            let label = UILabel(frame: CGRect(x: L.tankColX, y: labelY, width: tankWidth, height: 15))
            let fluidName = tank.amount > 0 ? tank.type.rawValue : "Empty"
            let displayName = fluidName == "water" && tank.amount == 0 ? "Empty" : fluidName
            label.text = "\(displayName): \(Int(tank.amount))/\(Int(fluidTankComponent.maxCapacity))"
            label.font = UIFont.systemFont(ofSize: 8, weight: .medium)
            label.textColor = .green
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            rootView.addSubview(label)
        }
    }

    private func setupOilRefinerySlotButtons(_ buildingDef: BuildingDefinition, panelBounds: CGRect) {
        let L = MachineUILayout(bounds: panelBounds)

        // Oil refinery layout: no item slots, only fluid tanks
        // 2 input tanks (left): Crude Oil, Water
        // 3 output tanks (right): Heavy Oil, Light Oil, Petroleum Gas

        // Set up fluid tanks
        setupOilRefineryFluidTanks(panelBounds)
    }

    private func setupOilRefineryFluidTanks(_ panelBounds: CGRect) {
        guard let entity = currentEntity,
              let gameLoop = gameLoop,
              let fluidTankComponent = gameLoop.world.get(FluidTankComponent.self, for: entity),
              let rootView = rootView else {
            return
        }

        let L = MachineUILayout(bounds: panelBounds)

        let tankWidth: CGFloat = 60
        let tankHeight: CGFloat = 40
        let tankSpacing: CGFloat = 20

        // Clear existing refinery tank UI
        refineryTankViews.forEach { $0.removeFromSuperview() }
        refineryFillViews.forEach { $0.removeFromSuperview() }
        refineryTankLabels.forEach { $0.removeFromSuperview() }
        refineryHeaders.forEach { $0.removeFromSuperview() }

        refineryTankViews.removeAll()
        refineryFillViews.removeAll()
        refineryTankLabels.removeAll()
        refineryHeaders.removeAll()

        // Define stable tank roles for oil refinery
        // Input tanks (left column)
        let inputTankSpecs: [(role: String, color: UIColor)] = [
            ("Crude Oil", UIColor.cyan),
            ("Water", UIColor.cyan)
        ]

        // Output tanks (right column)
        let outputTankSpecs: [(role: String, color: UIColor)] = [
            ("Heavy Oil", UIColor.green),
            ("Light Oil", UIColor.green),
            ("Petrol Gas", UIColor.green)
        ]

        // Create input tanks header
        let inputHeaderY = L.midBandY - 20
        let inputHeaderLabel = UILabel(frame: CGRect(x: L.leftColX, y: inputHeaderY, width: tankWidth, height: 15))
        inputHeaderLabel.text = "INPUT"
        inputHeaderLabel.font = UIFont.systemFont(ofSize: 8, weight: .bold)
        inputHeaderLabel.textColor = .cyan
        inputHeaderLabel.textAlignment = .center
        rootView.addSubview(inputHeaderLabel)
        refineryHeaders.append(inputHeaderLabel)

        // Create input tanks (left column)
        for i in 0..<min(inputTankSpecs.count, fluidTankComponent.tanks.count) {
            let (roleName, accentColor) = inputTankSpecs[i]
            let tankY = L.midBandY + CGFloat(i) * (tankHeight + tankSpacing)

            // Tank background
            let tankView = UIView(frame: CGRect(x: L.leftColX, y: tankY, width: tankWidth, height: tankHeight))
            tankView.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.8)
            tankView.layer.borderColor = accentColor.cgColor
            tankView.layer.borderWidth = 1.0
            tankView.layer.cornerRadius = 3.0
            tankView.clipsToBounds = true
            rootView.addSubview(tankView)
            refineryTankViews.append(tankView)

            // Fluid fill indicator
            let tank = fluidTankComponent.tanks[i]
            let fillLevel = fluidTankComponent.maxCapacity > 0 ? tank.amount / fluidTankComponent.maxCapacity : 0
            let fillHeight = tankHeight * CGFloat(fillLevel)

            let fillView = UIView(frame: CGRect(x: 0, y: tankHeight - fillHeight, width: tankWidth, height: fillHeight))
            let fluidColor = getFluidColor(for: tank.type)
            fillView.backgroundColor = fluidColor.withAlphaComponent(0.8)
            tankView.addSubview(fillView)
            refineryFillViews.append(fillView)

            // Tank label
            let labelY = tankY + tankHeight + 4
            let label = UILabel(frame: CGRect(x: L.leftColX, y: labelY, width: tankWidth, height: 15))
            if tank.amount <= 0.0001 {
                label.text = "\(roleName)\nEmpty"
            } else {
                label.text = "\(roleName)\n\(Int(tank.amount))/\(Int(fluidTankComponent.maxCapacity))"
            }
            label.font = UIFont.systemFont(ofSize: 8, weight: .medium)
            label.textColor = accentColor
            label.textAlignment = .center
            label.numberOfLines = 2
            label.adjustsFontSizeToFitWidth = true
            rootView.addSubview(label)
            refineryTankLabels.append(label)
        }

        // Create output tanks header
        let outputHeaderY = L.midBandY - 20
        let outputHeaderLabel = UILabel(frame: CGRect(x: L.tankColX, y: outputHeaderY, width: tankWidth, height: 15))
        outputHeaderLabel.text = "OUTPUT"
        outputHeaderLabel.font = UIFont.systemFont(ofSize: 8, weight: .bold)
        outputHeaderLabel.textColor = .green
        outputHeaderLabel.textAlignment = .center
        rootView.addSubview(outputHeaderLabel)
        refineryHeaders.append(outputHeaderLabel)

        // Create output tanks (right column)
        for i in 0..<outputTankSpecs.count {
            let tankIndex = i + 2  // Output tanks start at index 2
            let (roleName, accentColor) = outputTankSpecs[i]
            let tankY = L.midBandY + CGFloat(i) * (tankHeight + tankSpacing)

            // Tank background
            let tankView = UIView(frame: CGRect(x: L.tankColX, y: tankY, width: tankWidth, height: tankHeight))
            tankView.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.8)
            tankView.layer.borderColor = accentColor.cgColor
            tankView.layer.borderWidth = 1.0
            tankView.layer.cornerRadius = 3.0
            tankView.clipsToBounds = true
            rootView.addSubview(tankView)
            refineryTankViews.append(tankView)

            // Fluid fill indicator (if tank exists)
            if tankIndex < fluidTankComponent.tanks.count {
                let tank = fluidTankComponent.tanks[tankIndex]
                let fillLevel = fluidTankComponent.maxCapacity > 0 ? tank.amount / fluidTankComponent.maxCapacity : 0
                let fillHeight = tankHeight * CGFloat(fillLevel)

                let fillView = UIView(frame: CGRect(x: 0, y: tankHeight - fillHeight, width: tankWidth, height: fillHeight))
                let fluidColor = getFluidColor(for: tank.type)
                fillView.backgroundColor = fluidColor.withAlphaComponent(0.8)
                tankView.addSubview(fillView)
                refineryFillViews.append(fillView)

                // Tank label
                let labelY = tankY + tankHeight + 4
                let label = UILabel(frame: CGRect(x: L.tankColX, y: labelY, width: tankWidth, height: 15))
                if tank.amount <= 0.0001 {
                    label.text = "\(roleName)\nEmpty"
                } else {
                    label.text = "\(roleName)\n\(Int(tank.amount))/\(Int(fluidTankComponent.maxCapacity))"
                }
                label.font = UIFont.systemFont(ofSize: 8, weight: .medium)
                label.textColor = accentColor
                label.textAlignment = .center
                label.numberOfLines = 2
                label.adjustsFontSizeToFitWidth = true
                rootView.addSubview(label)
                refineryTankLabels.append(label)
            }
        }
    }

    private func updateChemicalPlantTanks(_ entity: Entity) {
        guard let gameLoop = gameLoop,
              let fluidTankComponent = gameLoop.world.get(FluidTankComponent.self, for: entity) else {
            return
        }

        let tankHeight: CGFloat = 40
        let tankWidth: CGFloat = 60
        let cap = fluidTankComponent.maxCapacity

        // Update all tanks by their index in the component
        for i in 0..<fluidTankComponent.tanks.count {
            if i < chemFillViews.count && i < chemTankLabels.count {
                let tank = fluidTankComponent.tanks[i]
                let fillLevel = cap > 0 ? tank.amount / cap : 0
                let fillHeight = tankHeight * CGFloat(fillLevel)

                // Update fill view height and position (local coords within tank view)
                chemFillViews[i].frame = CGRect(x: 0, y: tankHeight - fillHeight, width: tankWidth, height: fillHeight)

                // Update fill color
                let fluidColor = getFluidColor(for: tank.type)
                chemFillViews[i].backgroundColor = fluidColor.withAlphaComponent(0.8)

                // Update label
                if tank.amount <= 0.0001 {
                    chemTankLabels[i].text = "Empty: 0/\(Int(cap))"
                } else {
                    chemTankLabels[i].text = "\(tank.type.rawValue): \(Int(tank.amount))/\(Int(cap))"
                }
            }
        }
    }

    private func updateOilRefineryTanks(_ entity: Entity) {
        guard let gameLoop = gameLoop,
              let fluidTankComponent = gameLoop.world.get(FluidTankComponent.self, for: entity) else {
            return
        }

        let tankHeight: CGFloat = 40
        let cap = fluidTankComponent.maxCapacity

        // Update input tanks (indices 0-1)
        for i in 0..<min(2, fluidTankComponent.tanks.count) {
            if i < refineryFillViews.count && i < refineryTankLabels.count {
                let tank = fluidTankComponent.tanks[i]
                let fillLevel = cap > 0 ? tank.amount / cap : 0
                let fillHeight = tankHeight * CGFloat(fillLevel)

                // Update fill view
                refineryFillViews[i].frame = CGRect(x: 0, y: tankHeight - fillHeight, width: 60, height: fillHeight)
                let fluidColor = getFluidColor(for: tank.type)
                refineryFillViews[i].backgroundColor = fluidColor.withAlphaComponent(0.8)

                // Update label
                if tank.amount <= 0.0001 {
                    refineryTankLabels[i].text = ["Crude Oil", "Water"][i] + "\nEmpty"
                } else {
                    refineryTankLabels[i].text = ["Crude Oil", "Water"][i] + "\n\(Int(tank.amount))/\(Int(cap))"
                }
            }
        }

        // Update output tanks (indices 2-4)
        for i in 2..<min(5, fluidTankComponent.tanks.count) {
            let localIndex = i - 2
            let fillViewIndex = i  // Input tanks are 0-1, outputs are 2-4
            let labelIndex = i

            if fillViewIndex < refineryFillViews.count && labelIndex < refineryTankLabels.count {
                let tank = fluidTankComponent.tanks[i]
                let fillLevel = cap > 0 ? tank.amount / cap : 0
                let fillHeight = tankHeight * CGFloat(fillLevel)

                // Update fill view
                refineryFillViews[fillViewIndex].frame = CGRect(x: 0, y: tankHeight - fillHeight, width: 60, height: fillHeight)
                let fluidColor = getFluidColor(for: tank.type)
                refineryFillViews[fillViewIndex].backgroundColor = fluidColor.withAlphaComponent(0.8)

                // Update label
                let roleNames = ["Heavy Oil", "Light Oil", "Petrol Gas"]
                if tank.amount <= 0.0001 {
                    refineryTankLabels[labelIndex].text = roleNames[localIndex] + "\nEmpty"
                } else {
                    refineryTankLabels[labelIndex].text = roleNames[localIndex] + "\n\(Int(tank.amount))/\(Int(cap))"
                }
            }
        }
    }

    private func setupRecipeButtons() {
        guard let entity = currentEntity,
              let gameLoop = gameLoop,
              let scrollView = recipeScrollView else { return }

        // Get available recipes, filtered by machine capabilities
        var availableRecipes = gameLoop.recipeRegistry.enabled

        // Filter recipes based on machine type
        if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            // For assemblers, only show recipes that match their crafting category
            availableRecipes = availableRecipes.filter { recipe in
                // Check if recipe category matches assembler category
                let categoryMatches = recipe.category.rawValue == assembler.craftingCategory

                // Allow fluid recipes only if the machine has fluid handling capabilities
                let hasFluidCapabilities = gameLoop.world.has(FluidTankComponent.self, for: entity)
                let fluidCheckPasses = hasFluidCapabilities || (recipe.fluidInputs.isEmpty && recipe.fluidOutputs.isEmpty)

                return categoryMatches && fluidCheckPasses
            }
        } else if gameLoop.world.has(FurnaceComponent.self, for: entity),
                  let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) {
            availableRecipes = availableRecipes.filter { recipe in
                recipe.category.rawValue == buildingDef.craftingCategory
            }
        } else if let _ = gameLoop.world.get(FluidTankComponent.self, for: entity),
                  let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) {
            // For fluid-based machines (like oil refineries), filter by building crafting category
            availableRecipes = availableRecipes.filter { recipe in
                // Check if recipe category matches building category
                let categoryMatches = recipe.category.rawValue == buildingDef.craftingCategory

                // Since this is a fluid machine, allow fluid recipes
                return categoryMatches
            }
        }
        // For oil refineries and chemical plants (which have AssemblerComponent + FluidTankComponent),
        // they can show fluid recipes because they have fluid handling capabilities

        if availableRecipes.isEmpty { return }

        // Store filtered recipes for consistent indexing
        filteredRecipes = availableRecipes

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

    func loadRecipeImage(for textureId: String) -> UIImage? {
        // Try to get image from texture atlas first
        if let textureAtlas = gameLoop?.renderer?.textureAtlas {
            // Convert texture ID to texture name (replace dashes with underscores)
            let textureName = textureId.replacingOccurrences(of: "-", with: "_")
            if let image = textureAtlas.getUIImage(for: textureName) {
                return image
            }
        }

        // Map texture IDs to actual filenames (some have different names)
        var filename = textureId

        // Handle special mappings
        switch textureId {
        case "transport_belt":
            filename = "belt"
        default:
            // Convert dashes to underscores for asset names
            filename = textureId.replacingOccurrences(of: "-", with: "_")
        }

        // Try to load from bundle as fallback
        if let imagePath = Bundle.main.path(forResource: filename, ofType: "png") {
            return UIImage(contentsOfFile: imagePath)
        }

        return nil
    }

    private var selectedRecipe: Recipe?
    private var craftButton: UIKit.UIButton?
    private var recipeLabels: [UIView] = [] // Now contains both labels and image views

    @objc private func recipeButtonTapped(_ sender: Any) {
        guard let button = sender as? UIKit.UIButton else { return }
        guard gameLoop != nil else { return }

        let recipeIndex = Int(button.tag)

        if recipeIndex >= 0 && recipeIndex < filteredRecipes.count {
            let recipe = filteredRecipes[recipeIndex]
            if let entity = currentEntity,
               let gameLoop = gameLoop,
               gameLoop.world.has(FurnaceComponent.self, for: entity) {
                selectedRecipe = recipe
                onSelectRecipeForMachine?(entity, recipe)
                updateMachine(entity)
                updateRecipeButtonStates()
                showRecipeDetails(recipe)
                craftButton?.removeFromSuperview()
                craftButton = nil
                return
            }

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

        // Check if this recipe can be crafted
        var canCraft = true
        var missingItems: [String] = []
        var missingFluids: [String] = []

        if let gameLoop = gameLoop {
            let isFurnace = currentEntity.map { gameLoop.world.has(FurnaceComponent.self, for: $0) } ?? false
            if isFurnace, let entity = currentEntity,
               let machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity) {
                for input in recipe.inputs {
                    if machineInventory.count(of: input.itemId) < input.count {
                        canCraft = false
                        missingItems.append("\(input.itemId) (\(input.count))")
                    }
                }
            } else {
                // Check item inputs from player inventory
                for input in recipe.inputs {
                    if !gameLoop.player.inventory.has(itemId: input.itemId, count: input.count) {
                        canCraft = false
                        missingItems.append("\(input.itemId) (\(input.count))")
                    }
                }
            }

            // Check fluid inputs from machine's fluid tanks
            if let currentEntity = currentEntity,
               let fluidTank = gameLoop.world.get(FluidTankComponent.self, for: currentEntity) {
                for fluidInput in recipe.fluidInputs {
                    var foundFluid = false
                    for tank in fluidTank.tanks {
                        if tank.type == fluidInput.type && tank.amount >= fluidInput.amount {
                            foundFluid = true
                            break
                        }
                    }
                    if !foundFluid {
                        canCraft = false
                        let fluidName = fluidInput.type.rawValue.replacingOccurrences(of: "-", with: " ").capitalized
                        missingFluids.append("\(fluidName) (\(fluidInput.amount)L)")
                    }
                }
            } else if !recipe.fluidInputs.isEmpty {
                canCraft = false
                for fluidInput in recipe.fluidInputs {
                    let fluidName = fluidInput.type.rawValue.replacingOccurrences(of: "-", with: " ").capitalized
                    missingFluids.append("\(fluidName) (\(fluidInput.amount)L)")
                }
            }
        }

        if !canCraft {
            let isFurnace = currentEntity.map { entity in
                gameLoop?.world.has(FurnaceComponent.self, for: entity) ?? false
            } ?? false
            let missingLabel = isFurnace ? "Missing in furnace" : "Missing"
            tooltip += " - \(missingLabel): "
            let missing = (missingItems + missingFluids).joined(separator: ", ")
            tooltip += missing
        }

        // Show the tooltip using the game's tooltip system
        gameLoop?.inputManager?.onTooltip?(tooltip)
    }

    private func updateRecipeButtonStates() {
        guard let gameLoop = gameLoop else { return }
        let isFurnace = currentEntity.map { gameLoop.world.has(FurnaceComponent.self, for: $0) } ?? false

        // Update all recipe button appearances based on selection and craftability
        for (index, button) in recipeUIButtons.enumerated() {
            if index < filteredRecipes.count {
                let recipe = filteredRecipes[index]

                var config = button.configuration ?? .plain()

                if selectedRecipe?.id == recipe.id {
                    // Selected recipe - highlight it
                    config.baseBackgroundColor = UIColor.blue.withAlphaComponent(0.3)
                } else {
                    // Check if this recipe can be crafted
                    var canCraft = true
                    if !isFurnace {
                        // Check item inputs from player inventory
                        for input in recipe.inputs {
                            if !gameLoop.player.inventory.has(itemId: input.itemId, count: input.count) {
                                canCraft = false
                                break
                            }
                        }

                        // Check fluid inputs from machine's fluid tanks
                        if canCraft && !recipe.fluidInputs.isEmpty {
                            if let currentEntity = currentEntity,
                               let fluidTank = gameLoop.world.get(FluidTankComponent.self, for: currentEntity) {
                                for fluidInput in recipe.fluidInputs {
                                    var foundFluid = false
                                    for tank in fluidTank.tanks {
                                        if tank.type == fluidInput.type && tank.amount >= fluidInput.amount {
                                            foundFluid = true
                                            break
                                        }
                                    }
                                    if !foundFluid {
                                        canCraft = false
                                        break
                                    }
                                }
                            } else {
                                canCraft = false
                            }
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
        let L = MachineUILayout(bounds: rootView.bounds)

        let detailsY = L.midBandY + 10  // Position between progress bar and recipe scrollview
        let iconSize: CGFloat = 30
        let iconSpacing: CGFloat = 40

        // Show input requirements (items and fluids) centered in recipe region
        let totalInputs = recipe.inputs.count + recipe.fluidInputs.count + recipe.outputs.count + recipe.fluidOutputs.count
        let estimatedTotalWidth = CGFloat(totalInputs) * iconSpacing - iconSpacing + iconSize // Total width of all icons + spacing
        let startOffset = max(0, (L.recipeRegionWidth - estimatedTotalWidth) / 2) // Center within recipe region

        var currentX: CGFloat = L.recipeRegionX + startOffset
        let maxX = L.recipeRegionX + L.recipeRegionWidth

        // Item inputs
        for input in recipe.inputs {
            if currentX + iconSize > maxX { break } // Don't overflow recipe region
            addItemIcon(input.itemId, count: input.count, atX: currentX, y: detailsY, iconSize: iconSize, to: rootView)
            currentX += iconSpacing
        }

        // Fluid inputs
        for fluidInput in recipe.fluidInputs {
            if currentX + iconSize > maxX { break } // Don't overflow recipe region
            addFluidIcon(fluidInput.type, amount: fluidInput.amount, atX: currentX, y: detailsY, iconSize: iconSize, to: rootView)
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

        // Show outputs (items and fluids)
        // Item outputs
        for output in recipe.outputs {
            if currentX + iconSize > maxX { break } // Don't overflow recipe region
            addItemIcon(output.itemId, count: output.count, atX: currentX, y: detailsY, iconSize: iconSize, to: rootView)
            currentX += iconSpacing
        }

        // Fluid outputs
        for fluidOutput in recipe.fluidOutputs {
            if currentX + iconSize > maxX { break } // Don't overflow recipe region
            addFluidIcon(fluidOutput.type, amount: fluidOutput.amount, atX: currentX, y: detailsY, iconSize: iconSize, to: rootView)
            currentX += iconSpacing
        }
    }

    private func addItemIcon(_ itemId: String, count: Int, atX x: CGFloat, y: CGFloat, iconSize: CGFloat, to rootView: UIView) {
        // Create item icon
        if let image = loadRecipeImage(for: itemId) {
            let iconView = UIImageView(image: image)
            iconView.frame = CGRect(x: x, y: y, width: iconSize, height: iconSize)
            iconView.contentMode = .scaleAspectFit
            rootView.addSubview(iconView)
            recipeLabels.append(iconView)

            // Create count label if count > 1
            if count > 1 {
                let countLabel = createCountLabel(text: "\(count)", for: iconView)
                rootView.addSubview(countLabel)
                recipeLabels.append(countLabel)
            }
        }
    }

    private func addFluidIcon(_ fluidType: FluidType, amount: Float, atX x: CGFloat, y: CGFloat, iconSize: CGFloat, to rootView: UIView) {
        // Convert fluid type to asset name (replace dashes with underscores)
        let assetName = fluidType.rawValue.replacingOccurrences(of: "-", with: "_")

        // Create fluid icon using existing image loading
        if let image = loadRecipeImage(for: assetName) {
            let iconView = UIImageView(image: image)
            iconView.frame = CGRect(x: x, y: y, width: iconSize, height: iconSize)
            iconView.contentMode = .scaleAspectFit
            rootView.addSubview(iconView)
            recipeLabels.append(iconView)

            // Add amount label if amount > 10
            if amount > 10 {
                let amountText = amount >= 100 ? "\(Int(amount/100))00" : "\(Int(amount))"
                let countLabel = createCountLabel(text: amountText, for: iconView)
                rootView.addSubview(countLabel)
                recipeLabels.append(countLabel)
            }
        } else {
            // Fallback: colored rectangle with text if icon not found
            let fluidView = UIView()
            fluidView.frame = CGRect(x: x, y: y, width: iconSize, height: iconSize)
            fluidView.layer.cornerRadius = 4
            fluidView.layer.borderWidth = 1
            fluidView.layer.borderColor = UIColor.white.cgColor
            fluidView.backgroundColor = colorForFluidType(fluidType)

            rootView.addSubview(fluidView)
            recipeLabels.append(fluidView)

            // Add fluid name text
            let fluidLabel = UILabel()
            fluidLabel.text = displayNameForFluidType(fluidType)
            fluidLabel.font = UIFont.systemFont(ofSize: 6, weight: .bold)
            fluidLabel.textColor = .white
            fluidLabel.textAlignment = .center
            fluidLabel.numberOfLines = 2
            fluidLabel.adjustsFontSizeToFitWidth = true
            fluidLabel.minimumScaleFactor = 0.5
            fluidLabel.frame = CGRect(x: 0, y: 0, width: iconSize, height: iconSize)
            fluidView.addSubview(fluidLabel)
        }
    }

    private func colorForFluidType(_ fluidType: FluidType) -> UIColor {
        switch fluidType {
        case .water:
            return UIColor.blue.withAlphaComponent(0.7)
        case .steam:
            return UIColor.lightGray.withAlphaComponent(0.7)
        case .crudeOil:
            return UIColor.black.withAlphaComponent(0.7)
        case .heavyOil:
            return UIColor.brown.withAlphaComponent(0.7)
        case .lightOil:
            return UIColor.orange.withAlphaComponent(0.7)
        case .petroleumGas:
            return UIColor.green.withAlphaComponent(0.7)
        case .sulfuricAcid:
            return UIColor.yellow.withAlphaComponent(0.7)
        case .lubricant:
            return UIColor.purple.withAlphaComponent(0.7)
        }
    }

    private func displayNameForFluidType(_ fluidType: FluidType) -> String {
        switch fluidType {
        case .water:
            return "Water"
        case .steam:
            return "Steam"
        case .crudeOil:
            return "Oil"
        case .heavyOil:
            return "Heavy\nOil"
        case .lightOil:
            return "Light\nOil"
        case .petroleumGas:
            return "Gas"
        case .sulfuricAcid:
            return "Acid"
        case .lubricant:
            return "Lube"
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
        guard let rootView = rootView,
              let entity = currentEntity,
              let gameLoop = gameLoop else { return }

        // Remove existing craft button
        craftButton?.removeFromSuperview()
        craftButton = nil

        if gameLoop.world.has(FurnaceComponent.self, for: entity) {
            return
        }

        // Check if this is an oil refinery (continuous processor)
        let isOilRefinery = getBuildingDefinition(for: entity, gameLoop: gameLoop)?.type == .oilRefinery

        // Create craft button below recipe ingredients
        let buttonWidth: CGFloat = 80
        let buttonHeight: CGFloat = 30

        // Position below recipe ingredients, centered in recipe region
        let L = MachineUILayout(bounds: rootView.bounds)
        let buttonX = L.recipeRegionX + (L.recipeRegionWidth - buttonWidth) / 2
        let buttonY = L.midBandY + 40  // Below recipe ingredients

        let button = UIKit.UIButton(type: .system)
        button.frame = CGRect(x: buttonX, y: buttonY, width: buttonWidth, height: buttonHeight)

        // Different text for different machine types
        let buttonTitle = isOilRefinery ? "Set Recipe" : "Craft"
        button.setTitle(buttonTitle, for: .normal)
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
        if gameLoop.world.has(FurnaceComponent.self, for: entity) {
            craftButton.isEnabled = true
            craftButton.backgroundColor = UIColor.blue.withAlphaComponent(0.7)
            return
        }

        // Check crafting requirements based on recipe type
        var canCraftFromInventory = true
        var canCraftFromFluids = true
        var hasOutputSpace = true

        // Check item inputs from player inventory
        for input in recipe.inputs {
            if !gameLoop.player.inventory.has(itemId: input.itemId, count: input.count) {
                canCraftFromInventory = false
                break
            }
        }

        // Check fluid inputs from machine's fluid tanks
        if !recipe.fluidInputs.isEmpty {
            if let fluidTank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
                for fluidInput in recipe.fluidInputs {
                    var foundFluid = false
                    for tank in fluidTank.tanks {
                        if tank.type == fluidInput.type && tank.amount >= fluidInput.amount {
                            foundFluid = true
                            break
                        }
                    }
                    if !foundFluid {
                        canCraftFromFluids = false
                        break
                    }
                }
            } else {
                canCraftFromFluids = false
            }
        }

        // Check output space
        if !recipe.outputs.isEmpty {
            // Check item output space
            if let machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity),
               let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) {
                let outputStartIndex = buildingDef.fuelSlots + buildingDef.inputSlots
                let outputEndIndex = outputStartIndex + buildingDef.outputSlots - 1

                hasOutputSpace = false
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
        } else if !recipe.fluidOutputs.isEmpty {
            // Check fluid output space
            if let fluidTank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
                for fluidOutput in recipe.fluidOutputs {
                    var hasSpace = false
                    for i in 0..<fluidTank.tanks.count {
                        let tank = fluidTank.tanks[i]
                        // Check if this tank can accept this fluid type and has space
                        // Tanks can only accept: same fluid type (to add more), or be empty (to accept any type)
                        let canAcceptFluid = (tank.amount == 0) || (tank.type == fluidOutput.type)

                        if canAcceptFluid && tank.availableSpace >= fluidOutput.amount {
                            hasSpace = true
                            break
                        }
                    }
                    if !hasSpace {
                        hasOutputSpace = false
                        break
                    }
                }
            } else {
                hasOutputSpace = false
            }
        }

        let canCraft = canCraftFromInventory && canCraftFromFluids && hasOutputSpace

        craftButton.isEnabled = canCraft
        if !canCraftFromInventory || !canCraftFromFluids {
            craftButton.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
        } else if !hasOutputSpace {
            craftButton.backgroundColor = UIColor.orange.withAlphaComponent(0.7) // Orange to indicate no output space
        } else {
            craftButton.backgroundColor = UIColor.blue.withAlphaComponent(0.7)
        }
    }

    @objc private func craftButtonTapped() {
        guard let recipe = selectedRecipe,
              let entity = currentEntity,
              let gameLoop = gameLoop else { return }

        // Check crafting requirements based on recipe type
        var canCraft = true
        var tooltipMessage = ""

        // For fluid-only recipes (oil processing), check fluid tanks
        if !recipe.inputs.isEmpty || !recipe.fluidInputs.isEmpty {
            // This is a recipe that requires inputs

            // Check item inputs from player inventory
            if !recipe.inputs.isEmpty {
                for input in recipe.inputs {
                    if !gameLoop.player.inventory.has(itemId: input.itemId, count: input.count) {
                        canCraft = false
                        tooltipMessage = "Missing items: \(input.itemId) (\(input.count))"
                        break
                    }
                }
            }

            // Check fluid inputs from machine's fluid tanks
            if !recipe.fluidInputs.isEmpty {
                if let fluidTank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
                    for fluidInput in recipe.fluidInputs {
                        var foundFluid = false
                        for tank in fluidTank.tanks {
                            if tank.type == fluidInput.type && tank.amount >= fluidInput.amount {
                                foundFluid = true
                                break
                            }
                        }
                        if !foundFluid {
                            canCraft = false
                            let fluidName = fluidInput.type.rawValue.replacingOccurrences(of: "-", with: " ").capitalized
                            tooltipMessage = "Missing fluid: \(fluidName) (\(fluidInput.amount)L)"
                            break
                        }
                    }
                } else {
                    canCraft = false
                    tooltipMessage = "Machine has no fluid tanks"
                }
            }
        }

        // Check output space
        var hasOutputSpace = true

        // Check item output space
        if !recipe.outputs.isEmpty {
            if let machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity),
               let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) {
                let outputStartIndex = buildingDef.fuelSlots + buildingDef.inputSlots
                let outputEndIndex = outputStartIndex + buildingDef.outputSlots - 1

                hasOutputSpace = false
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

                if !hasOutputSpace {
                    tooltipMessage = "All output slots filled. Tap on an output slot to clear it."
                }
            }
        }

        // Check fluid output space
        if !recipe.fluidOutputs.isEmpty {
            if let fluidTank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
                for fluidOutput in recipe.fluidOutputs {
                    var hasSpace = false
                    for i in 0..<fluidTank.tanks.count {
                        let tank = fluidTank.tanks[i]
                        // Check if this tank can accept this fluid type and has space
                        // Tanks can only accept: same fluid type (to add more), or be empty (to accept any type)
                        let canAcceptFluid = (tank.amount == 0) || (tank.type == fluidOutput.type)

                        if canAcceptFluid && tank.availableSpace >= fluidOutput.amount {
                            hasSpace = true
                            break
                        }
                    }
                    if !hasSpace {
                        hasOutputSpace = false
                        let fluidName = fluidOutput.type.rawValue.replacingOccurrences(of: "-", with: " ").capitalized
                        tooltipMessage = "No tank space for: \(fluidName) (\(fluidOutput.amount)L)"
                        break
                    }
                }
            } else {
                hasOutputSpace = false
                tooltipMessage = "Machine has no fluid tanks for outputs"
            }
        }

        // If can't craft, show tooltip and return
        if !canCraft || !hasOutputSpace {
            if tooltipMessage.isEmpty {
                tooltipMessage = "Cannot craft recipe"
            }
            gameLoop.inputManager?.onTooltip?(tooltipMessage)
            return
        }

        // Perform the crafting logic (transfer items/fluids and start production)
        var playerInventory = gameLoop.player.inventory

        // Transfer item inputs from player inventory to machine input slots
        if !recipe.inputs.isEmpty {
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

            // Update machine inventory
            gameLoop.world.add(machineInventory, to: entity)
        }

        // Transfer fluid inputs from machine tanks (consume fluids for crafting)
        if !recipe.fluidInputs.isEmpty {
            if var fluidTank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
                for fluidInput in recipe.fluidInputs {
                    // Find and consume fluid from tanks
                    for i in 0..<fluidTank.tanks.count {
                        if fluidTank.tanks[i].type == fluidInput.type && fluidTank.tanks[i].amount >= fluidInput.amount {
                            fluidTank.tanks[i].amount -= fluidInput.amount
                            break
                        }
                    }
                }
                gameLoop.world.add(fluidTank, to: entity)
            }
        }

        // For fluid-based recipes, just set the recipe and let the CraftingSystem handle timed processing
        if recipe.fluidInputs.isEmpty && recipe.fluidOutputs.isEmpty {
            // Item-based recipe - do the old instant logic
            var playerInventory = gameLoop.player.inventory

            // Transfer item inputs from player inventory to machine input slots
            if !recipe.inputs.isEmpty {
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

                // Update machine inventory
                gameLoop.world.add(machineInventory, to: entity)
            }

            // Add fluid outputs to machine tanks (for item recipes that also have fluid outputs)
            if !recipe.fluidOutputs.isEmpty {
                if var fluidTank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
                    for fluidOutput in recipe.fluidOutputs {
                        // Find a suitable tank for this fluid output
                        for i in 0..<fluidTank.tanks.count {
                            let tank = fluidTank.tanks[i]
                            // Check if this tank can accept this fluid type
                            var canAcceptFluid = false
                            if let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop),
                               buildingDef.type == .oilRefinery {
                                // Oil refinery tanks can accept: crude oil, water/steam (inputs), and petroleum gas/light oil/heavy oil (outputs)
                                let allowedTypes: [FluidType] = [.crudeOil, .water, .steam, .petroleumGas, .lightOil, .heavyOil]
                                canAcceptFluid = allowedTypes.contains(fluidOutput.type) &&
                                               (tank.amount == 0 || tank.type == fluidOutput.type || allowedTypes.contains(tank.type))
                            } else {
                                // Regular tanks: only accept same type or empty tanks
                                canAcceptFluid = (tank.type == fluidOutput.type || tank.amount == 0)
                            }

                            if canAcceptFluid && tank.availableSpace >= fluidOutput.amount {
                                // Add fluid to this tank
                                if tank.amount == 0 {
                                    // Tank is empty (regardless of previous type), set the new type and add fluid
                                    fluidTank.tanks[i] = FluidStack(type: fluidOutput.type, amount: fluidOutput.amount, temperature: fluidOutput.temperature, maxAmount: tank.maxAmount)
                                } else {
                                    // Tank has fluid, add to existing amount
                                    fluidTank.tanks[i].amount += fluidOutput.amount
                                }
                                break
                            }
                        }
                        // Note: If no tank can accept the fluid, it should have been caught in the space check above
                        // So we assume it gets added somewhere
                    }
                    gameLoop.world.add(fluidTank, to: entity)
                }
            }

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
        } else {
            // Fluid-based recipe - just set the recipe and let CraftingSystem handle timed processing
            onSelectRecipeForMachine?(entity, recipe)

            // Play craft sound
            AudioManager.shared.playClickSound()

            // Update the UI
            updateMachine(entity)

            // Clear selection and hide craft button
            selectedRecipe = nil
            craftButton?.removeFromSuperview()
            craftButton = nil
            clearRecipeDetails()
            updateRecipeButtonStates()
        }
    }

    override func open() {
        // Guard against double-opening
        if isOpen {
            return
        }
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

            // Status label below progress bar
            progressStatusLabel = UILabel()
            progressStatusLabel!.font = UIFont.systemFont(ofSize: 10, weight: .medium)
            progressStatusLabel!.textColor = .white
            progressStatusLabel!.textAlignment = .center
            progressStatusLabel!.text = "Ready"
            rootView!.addSubview(progressStatusLabel!)
        }

        // Root view now exists; allow components to attach UIKit subviews
        if let entity = currentEntity {
            for component in machineComponents {
                component.setupUI(for: entity, in: self)
            }
        } else {
        }

        // Set up UIKit components
        // Setup recipe UI for assemblers, furnaces, and fluid machines.
        if let entity = currentEntity, let gameLoop = gameLoop,
           (gameLoop.world.has(AssemblerComponent.self, for: entity) ||
            gameLoop.world.has(FurnaceComponent.self, for: entity) ||
            gameLoop.world.has(FluidTankComponent.self, for: entity)) {
            if recipeScrollView == nil {
                setupRecipeScrollView(for: entity, gameLoop: gameLoop)
            }
            setupRecipeButtons()

            // Clear any previous recipe selection and update button states
            selectedRecipe = nil
            updateRecipeButtonStates()
        } else {
            // No recipes for this machine - hide recipe UI
            recipeScrollView?.removeFromSuperview()
            recipeScrollView = nil
            recipeUIButtons.forEach { $0.removeFromSuperview() }
            recipeUIButtons.removeAll()
        }

        // Set up UIKit slot buttons (ensure they're created when opening)
        if currentEntity != nil {
            clearSlotUI()
            setupSlotButtons()
            layoutAll()
            // Update the UI with current machine state
            updateMachine(currentEntity!)
        }

        // Add root view to hierarchy (AFTER content is added to it)
        if let rootView = rootView {
            onAddRootView?(rootView)
        } else {
            close()
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
            allLabels += componentLabels
        }

        // Labels are now handled by components within the rootView

        // Position fluid labels after adding to view
        for component in machineComponents {
            if let fluidComponent = component as? FluidMachineUIComponent {
                fluidComponent.positionLabels(in: self)
            }
            if component is PipeConnectionUIComponent {
                // Pipe component positions its own elements in setupUI
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
                if index < filteredRecipes.count {
                    let recipe = filteredRecipes[index]

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

        // For fluid-only recipes (no item outputs), assume output space is always available
        // since fluids go into fluid tanks, not item slots
        if recipe.outputs.isEmpty && !recipe.fluidOutputs.isEmpty {
            hasOutputSpace = true
        } else if let machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity),
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
            let timeString = String(format: "%.1f", recipe.craftTime)
            return "Craft \(recipe.name) (\(timeString)s)"
        }
    }


    override func close() {
        // Call super.close() FIRST to flip isOpen and unregister from input stack
        super.close()

        // Clear recipe selection and details
        selectedRecipe = nil
        craftButton?.removeFromSuperview()
        craftButton = nil
        clearRecipeDetails()

        // Tear down scroll view FIRST (it has gesture recognizers)
        recipeScrollView?.removeFromSuperview()
        recipeScrollView = nil

        // Remove recipe buttons (they're in the scroll view)
        recipeUIButtons.forEach { $0.removeFromSuperview() }
        recipeUIButtons.removeAll()

        // Remove any rocket button
        launchButton?.removeFromSuperview()
        launchButton = nil

        // Clear UIKit slot UI
        clearSlotUI()

        // Remove progress bar views
        progressBarFill?.removeFromSuperview()
        progressBarFill = nil
        progressBarBackground?.removeFromSuperview()
        progressBarBackground = nil
        progressStatusLabel?.removeFromSuperview()
        progressStatusLabel = nil

        // Remove refinery tank UI
        refineryTankViews.forEach { $0.removeFromSuperview() }
        refineryFillViews.forEach { $0.removeFromSuperview() }
        refineryTankLabels.forEach { $0.removeFromSuperview() }
        refineryHeaders.forEach { $0.removeFromSuperview() }
        refineryTankViews.removeAll()
        refineryFillViews.removeAll()
        refineryTankLabels.removeAll()
        refineryHeaders.removeAll()

        // Remove root view from hierarchy *directly*
        if let rv = rootView {
            rv.isUserInteractionEnabled = false
            rv.removeFromSuperview()
            onRemoveRootView?(rv) // optional; OK if it also does bookkeeping
        }
        rootView = nil

        // Clear global labels (they persist across panels)
        var allLabels: [UILabel] = []
        allLabels += researchProgressLabels
        // Add labels from components
        for component in machineComponents {
            allLabels += component.getLabels()
        }
        if let powerLabel = powerLabel {
            allLabels.append(powerLabel)
        }
        // Clear label text to ensure they're properly reset
        for label in allLabels {
            label.text = ""
            label.isHidden = true
        }

        // Debug: confirm removal
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
                // Only update UI if labels exist
                if i < fuelCountLabels.count {
                    fuelCountLabels[i].text = "\(item.count)"
                    fuelCountLabels[i].isHidden = false
                } else {
                }
            } else {
                fuelSlots[i].item = nil
                fuelSlots[i].isRequired = false
                // Only update UI if labels exist
                if i < fuelCountLabels.count {
                    fuelCountLabels[i].text = "0"
                    fuelCountLabels[i].isHidden = true
                } else {
                }
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
        guard let gameLoop = gameLoop,
              let inventory = gameLoop.world.get(InventoryComponent.self, for: entity) else {
            return
        }

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
            if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                // Update button image
                if i < inputSlotButtons.count {
                    if let image = loadRecipeImage(for: item.itemId) {
                        // Scale image to 80% of button size like InventoryUI does for icons
                        let buttonSizePoints: CGFloat = 32
                        let scaledSize = CGSize(width: buttonSizePoints * 0.8, height: buttonSizePoints * 0.8)
                        UIGraphicsBeginImageContextWithOptions(scaledSize, false, 0.0)
                        image.draw(in: CGRect(origin: .zero, size: scaledSize))
                        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                        UIGraphicsEndImageContext()

                        inputSlotButtons[i].setImage(scaledImage, for: .normal)
                    } else {
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

    private func inventorySignature(for inventory: InventoryComponent) -> Int {
        var hasher = Hasher()
        hasher.combine(inventory.slots.count)
        for slot in inventory.slots {
            if let slot = slot {
                hasher.combine(slot.itemId)
                hasher.combine(slot.count)
                hasher.combine(slot.maxStack)
            } else {
                hasher.combine(0)
            }
        }
        return hasher.finalize()
    }

    func updateMachine(_ entity: Entity) {
        setupSlotsForMachine(entity)
        updateCountLabels(entity)
        relayoutCountLabels()

        // Update custom tank UIs
        if let gameLoop = gameLoop,
           let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) {
            if buildingDef.type == .chemicalPlant {
                updateChemicalPlantTanks(entity)
            } else if buildingDef.type == .oilRefinery {
                updateOilRefineryTanks(entity)
            }
        }

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

        if let entity = currentEntity,
           let gameLoop = gameLoop,
           let inventory = gameLoop.world.get(InventoryComponent.self, for: entity) {
            let signature = inventorySignature(for: inventory)
            if lastInventoryEntity != entity || lastInventorySignature != signature {
                lastInventoryEntity = entity
                lastInventorySignature = signature
                updateCountLabels(entity)
            }
        }

        // Update fluid components for real-time buffer displays
        if let entity = currentEntity {
            for component in machineComponents {
                if let fluidComponent = component as? FluidMachineUIComponent {
                    fluidComponent.updateUI(for: entity, in: self)
                }
            }
        }

        // Update button states based on craftability and crafting status
        guard let player = gameLoop?.player,
              let _ = gameLoop else { return }

        for uiButton in recipeUIButtons {
            let idx = uiButton.tag
            guard idx >= 0 && idx < filteredRecipes.count else { continue }

            let recipe = filteredRecipes[idx]
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

    func getBuildingDefinition(for entity: Entity, gameLoop: GameLoop) -> BuildingDefinition? {
        let buildingComponent: BuildingComponent?
        if let miner = gameLoop.world.get(MinerComponent.self, for: entity) {
            buildingComponent = miner
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            buildingComponent = furnace
        } else if let fluidTank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
            buildingComponent = fluidTank
        } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            buildingComponent = assembler
        } else if let generator = gameLoop.world.get(GeneratorComponent.self, for: entity) {
            buildingComponent = generator
        } else if let lab = gameLoop.world.get(LabComponent.self, for: entity) {
            buildingComponent = lab
        } else if let rocketSilo = gameLoop.world.get(RocketSiloComponent.self, for: entity) {
            buildingComponent = rocketSilo
        } else if let fluidProducer = gameLoop.world.get(FluidProducerComponent.self, for: entity) {
            buildingComponent = fluidProducer
        } else if let fluidConsumer = gameLoop.world.get(FluidConsumerComponent.self, for: entity) {
            buildingComponent = fluidConsumer
        } else {
            return nil
        }

        guard let component = buildingComponent else { 
            return nil 
        }
        let buildingDef = gameLoop.buildingRegistry.get(component.buildingId)
        if buildingDef == nil {
        } else {
        }
        return buildingDef
    }

    @objc private func fuelSlotTapped(_ sender: UIKit.UIButton) {
        guard let entity = currentEntity, let gameLoop = gameLoop else { return }

        let slotIndex = sender.tag

        // Check if the slot has an item
        if let machineInventory = gameLoop.world.get(InventoryComponent.self, for: entity) {
            if slotIndex < machineInventory.slots.count {
                if let item = machineInventory.slots[slotIndex] {
                    // Slot has an item - take it out
                    handleSlotTap(entity: entity, slotIndex: slotIndex, gameLoop: gameLoop)
                } else {
                    // Slot is empty - open inventory to add items
                    handleEmptySlotTap(entity: entity, slotIndex: slotIndex)
                }
            } else {
                handleEmptySlotTap(entity: entity, slotIndex: slotIndex)
            }
        } else {
            handleEmptySlotTap(entity: entity, slotIndex: slotIndex)
        }
    }

    @objc private func inputSlotTapped(_ sender: UIKit.UIButton) {
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

        } else {
            // Some items couldn't be moved - update the machine slot with remaining items
            let remainingStack = ItemStack(itemId: itemStack.itemId, count: remainingCount, maxStack: itemStack.maxStack)
            machineInventory.slots[slotIndex] = remainingStack
            world.add(machineInventory, to: entity)

            // Update the UI
            updateMachine(entity)

            // Show feedback that only partial items were moved
            showInventoryFullTooltip()
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
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        label.isHidden = false

        // Set initial frame with wider width to accommodate longer text
        label.frame = CGRect(x: 0, y: 0, width: 130, height: 18)

        return label
    }

    override func handleTap(at position: Vector2) -> Bool {
        guard isOpen else { return false }

        // Outside panel -> close and consume the tap
        if !frame.contains(position) {
            onClosePanel?()  // Notify UISystem to close panel and clear activePanel
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
        var statusText: String = "Ready"

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
            // No progress or power info to show - hide progress bars
            progressBarBackground?.isHidden = true
            progressBarFill?.isHidden = true

            // But still show status for boilers
            if let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop),
                buildingDef.id == "boiler" {
                let info = getBoilerStatusInfo(entity: entity, gameLoop: gameLoop)
                statusText = info.detail.isEmpty ? info.title : "\(info.title)\n\(info.detail)"
                progressStatusLabel?.numberOfLines = 2
                progressStatusLabel?.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
                switch info.state {
                case .running:
                    progressStatusLabel?.textColor = UIColor.systemGreen
                case .ready:
                    progressStatusLabel?.textColor = UIColor.white
                case .stalled:
                    progressStatusLabel?.textColor = UIColor.systemOrange
                }
            } else {
                statusText = "Ready"
                progressStatusLabel?.numberOfLines = 1
                progressStatusLabel?.font = UIFont.systemFont(ofSize: 10, weight: .medium)
                progressStatusLabel?.textColor = UIColor.white
            }

            // Set the status label and return early
            progressStatusLabel?.text = statusText
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
            statusText = String(format: "Power: %.0f%%", p * 100)
        } else {
            // Progress bar (green)
            let p = max(0, min(1, progress))
            fillWidth = backgroundFrame.width * CGFloat(p)
            fillColor = UIColor.green
            let isMiner = getBuildingDefinition(for: entity, gameLoop: gameLoop)?.type == .miner
            let isFurnace = gameLoop.world.has(FurnaceComponent.self, for: entity)

            if progress > 0 {
                let label = isMiner ? "Mining" : (isFurnace ? "Smelting" : "Crafting")
                statusText = String(format: "\(label): %.0f%%", p * 100)
            } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
                if assembler.recipe == nil {
                    statusText = "No Recipe Selected"
                } else if let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop),
                          buildingDef.type == .oilRefinery {
                    // Special status for oil refineries
                    statusText = getRefineryStatus(entity: entity, gameLoop: gameLoop, assembler: assembler)
                } else {
                    statusText = "Ready to Craft"
                }
            } else if isFurnace {
                statusText = "Insert Ore"
            } else if isMiner {
                statusText = "Ready to Mine"
            } else {
                statusText = "No Recipe Selected"
            }
        }

        progressBarFill?.frame = CGRect(
            x: backgroundFrame.origin.x,
            y: backgroundFrame.origin.y,
            width: fillWidth,
            height: backgroundFrame.height
        )
        progressBarFill?.backgroundColor = fillColor
        progressStatusLabel?.numberOfLines = 1
        progressStatusLabel?.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        progressStatusLabel?.textColor = UIColor.white
        progressStatusLabel?.text = statusText

        // UIKit progress bar updated above
    }

    private func getRefineryStatus(entity: Entity, gameLoop: GameLoop, assembler: AssemblerComponent) -> String {
        guard let recipe = assembler.recipe else { return "No Recipe" }

        var statusParts: [String] = []

        // Check fluid inputs (crude oil, water)
        if !recipe.fluidInputs.isEmpty {
            if let fluidTank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
                var inputsOK = true
                for fluidInput in recipe.fluidInputs {
                    var foundFluid = false
                    for tank in fluidTank.tanks {
                        if tank.type == fluidInput.type && tank.amount >= fluidInput.amount {
                            foundFluid = true
                            break
                        }
                    }
                    if !foundFluid {
                        inputsOK = false
                        break
                    }
                }
                statusParts.append(inputsOK ? "Inputs OK" : "No \(recipe.fluidInputs.first?.type.rawValue ?? "Input")")
            } else {
                statusParts.append("No Inputs")
            }
        }

        // Check fluid outputs (can accept products)
        if !recipe.fluidOutputs.isEmpty {
            if let fluidTank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
                var outputsOK = true
                for fluidOutput in recipe.fluidOutputs {
                    var canAccept = false
                    for tank in fluidTank.tanks {
                        if (tank.type == fluidOutput.type || tank.amount == 0) &&
                           tank.availableSpace >= fluidOutput.amount {
                            canAccept = true
                            break
                        }
                    }
                    if !canAccept {
                        outputsOK = false
                        break
                    }
                }
                if !outputsOK {
                    statusParts.append("Output Full")
                }
            }
        }

        // Determine overall status
        if assembler.craftingProgress > 0 {
            return "Running • " + statusParts.joined(separator: " • ")
        } else if statusParts.contains(where: { $0.contains("No ") || $0.contains("Full") }) {
            return "Stalled • " + statusParts.joined(separator: " • ")
        } else {
            return "Ready • " + statusParts.joined(separator: " • ")
        }
    }

    private enum BoilerStatusState {
        case running
        case ready
        case stalled
    }

    private func getBoilerStatusInfo(entity: Entity, gameLoop: GameLoop) -> (title: String, detail: String, state: BoilerStatusState) {
        // Check if boiler is currently running (producing steam)
        let producer = gameLoop.world.get(FluidProducerComponent.self, for: entity)
        let isRunning = producer?.isActive ?? false

        // Check fuel availability
        var hasFuel = false
        if let inventory = gameLoop.world.get(InventoryComponent.self, for: entity),
           let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) {
            let fuelSlotStart = buildingDef.inputSlots + buildingDef.outputSlots
            hasFuel = (fuelSlotStart..<inventory.slots.count).contains(where: {
                inventory.slots[$0]?.count ?? 0 > 0
            })
        }

        // Check water availability (connection or buffer)
        var hasWaterSource = false
        if let consumer = gameLoop.world.get(FluidConsumerComponent.self, for: entity) {
            hasWaterSource = !consumer.connections.isEmpty
            // Also check if there's water in the buffer
            if !hasWaterSource, let tank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
                let waterAmount = tank.tanks.first(where: { $0.type == .water })?.amount ?? 0
                hasWaterSource = waterAmount >= 0.001
            }
        }

        // Check steam output capacity
        var hasSteamSpace = false
        if let tank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
            let steamAvailableSpace = tank.tanks.first(where: { $0.type == .steam })?.availableSpace ?? 0
            hasSteamSpace = steamAvailableSpace >= 0.001
        }

        let fuelText = hasFuel ? "Fuel OK" : "No Fuel"
        let waterText = hasWaterSource ? "Water OK" : "No Water"
        let steamText = hasSteamSpace ? "Out OK" : "Out Blocked"

        if isRunning {
            let warnings = hasSteamSpace ? [] : [steamText]
            let detail = warnings.isEmpty ? "\(fuelText) • \(waterText) • \(steamText)" : warnings.joined(separator: " • ")
            return ("Running", detail, .running)
        }

        if !hasFuel || !hasWaterSource || !hasSteamSpace {
            var blockers: [String] = []
            if !hasFuel { blockers.append(fuelText) }
            if !hasWaterSource { blockers.append(waterText) }
            if !hasSteamSpace { blockers.append(steamText) }
            return ("Stalled", blockers.joined(separator: " • "), .stalled)
        }

        return ("Ready", "\(fuelText) • \(waterText) • \(steamText)", .ready)
    }

    private func getBoilerStatus(entity: Entity, gameLoop: GameLoop) -> String {
        let info = getBoilerStatusInfo(entity: entity, gameLoop: gameLoop)
        if info.detail.isEmpty {
            return info.title
        }
        return "\(info.title) • \(info.detail)"
    }
}
