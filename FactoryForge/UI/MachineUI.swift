import Foundation
import UIKit

// Use UIKit's UIButton explicitly to avoid conflict with custom UIButton
typealias UIKitButton = UIKit.UIButton

/// Callback type for recipe selection
typealias RecipeSelectionCallback = (Entity, Recipe) -> Void

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

            print("MachineUI: Initialized \(inputSlots.count) input slots, \(outputSlots.count) output slots, \(fuelSlots.count) fuel slots")
        } else {
            print("MachineUI: setupSlots() - no currentEntity or buildingDef not found")
        }
    }

    func setEntity(_ entity: Entity) {
        print("MachineUI: setEntity called with entity \(entity.id)")
        currentEntity = entity

        // Clear existing components
        machineComponents.removeAll()

        // Determine machine type and create appropriate components
        if let gameLoop = gameLoop {
            // Check for fluid-based machines (including tanks), but skip for chemical plants (handled in slot setup)
            let hasFluidProducer = gameLoop.world.has(FluidProducerComponent.self, for: entity)
            let hasFluidConsumer = gameLoop.world.has(FluidConsumerComponent.self, for: entity)
            let hasFluidTank = gameLoop.world.has(FluidTankComponent.self, for: entity)

            // Check if this is a chemical plant - if so, don't create FluidMachineUIComponent
            var isChemicalPlant = false
            if let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) {
                isChemicalPlant = buildingDef.type == .chemicalPlant
            }

            print("MachineUI: Checking entity \(entity.id) - producer: \(hasFluidProducer), consumer: \(hasFluidConsumer), tank: \(hasFluidTank), chemicalPlant: \(isChemicalPlant)")
            if (hasFluidProducer || hasFluidConsumer || hasFluidTank) && !isChemicalPlant {
                print("MachineUI: Creating FluidMachineUIComponent (producer: \(hasFluidProducer), consumer: \(hasFluidConsumer), tank: \(hasFluidTank))")
                machineComponents.append(FluidMachineUIComponent())
            } else if isChemicalPlant {
                print("MachineUI: Skipping FluidMachineUIComponent for chemical plant - tanks handled in slot setup")
            } else {
                print("MachineUI: NOT creating FluidMachineUIComponent for entity \(entity.id)")
            }

            // Check for pipes
            if gameLoop.world.has(PipeComponent.self, for: entity) {
                print("MachineUI: Creating PipeConnectionUIComponent for pipe entity \(entity.id)")
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


    private func setupRecipeScrollView(for entity: Entity, gameLoop: GameLoop) {
        // Create scroll view for recipe buttons (in points, relative to root view)
        guard let rootView = rootView else { return }
        let panelBounds = rootView.bounds

        // Position scroll view at bottom of panel with margins
        let margin: CGFloat = 20
        let scrollViewHeight: CGFloat = 150

        // Adjust recipe area for chemical plants (leave space for tank column)
        var scrollViewWidth: CGFloat
        var scrollViewX: CGFloat

        if let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop),
           buildingDef.type == .chemicalPlant {
            // Chemical plant: center recipes in space before tank column
            let tankColumnStart = panelBounds.width * 0.75
            scrollViewWidth = tankColumnStart - margin * 2
            scrollViewX = margin
        } else {
            // Standard layout
            scrollViewWidth = panelBounds.width - margin * 2
            scrollViewX = margin
        }

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

        // Position status label below progress bar
        if let statusLabel = progressStatusLabel {
            statusLabel.frame = CGRect(x: barX, y: barY + barHeight + 4, width: barWidth, height: 14)
        }
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
            print("MachineUI: setupSlotButtons failed - missing entity, gameLoop, or rootView")
            return
        }
        
        // Get building definition to know how many slots
        guard let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) else {
            print("MachineUI: setupSlotButtons failed - could not get building definition for entity \(entity.id)")
            return
        }
        
        print("MachineUI: setupSlotButtons - building \(buildingDef.id) has \(buildingDef.fuelSlots) fuel slots, \(buildingDef.inputSlots) input slots, \(buildingDef.outputSlots) output slots")
        
        let inputCount = buildingDef.inputSlots
        let outputCount = buildingDef.outputSlots
        let fuelCount = buildingDef.fuelSlots
        let panelBounds = rootView.bounds
        
        // Common constants for all slot types
        let buttonSizePoints: CGFloat = 32  // Already in points
        let spacingPoints: CGFloat = 8
        
        // Special layout for chemical plants
        if buildingDef.type == .chemicalPlant {
            setupChemicalPlantSlotButtons(buildingDef, panelBounds: panelBounds)
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
            print("MachineUI: Created input slot button \(i) at (\(buttonX), \(buttonY))")

            // Count label positioned relative to button
            let label = attachCountLabel(to: button)
            inputCountLabels.append(label)
            rootView.addSubview(label)
        }

        // Create output slots (right side, before tank column) - UIKit buttons
        for i in 0..<outputCount {
            // Position relative to panel bounds - column between machine and tanks
            let buttonX = panelBounds.width * 0.65  // 65% from left (between machine and tanks)
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

            // Count label positioned relative to button
            let label = attachCountLabel(to: button)
            outputCountLabels.append(label)
            rootView.addSubview(label)
        }
    }

    private func setupChemicalPlantSlotButtons(_ buildingDef: BuildingDefinition, panelBounds: CGRect) {
        let buttonSizePoints: CGFloat = 32
        let spacingPoints: CGFloat = 8

        // Chemical plant layout:
        // - 3 input slots on left (25% from left)
        // - 2 output slots on right (55% from left, leaving space for fluid tanks)
        // - Fluid tank column reserved on far right (75%+ from left)

        // Create input slots (left side) - 3 slots for chemical plant
        for i in 0..<buildingDef.inputSlots {
            let buttonX = panelBounds.width * 0.25  // 25% from left
            let buttonY = panelBounds.height * 0.325 + (buttonSizePoints + spacingPoints) * CGFloat(i)

            let button = UIKit.UIButton(frame: CGRect(x: buttonX, y: buttonY, width: buttonSizePoints, height: buttonSizePoints))
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

        // Create output slots (right side, but not too far to leave space for fluid tanks) - 2 slots for chemical plant
        for i in 0..<buildingDef.outputSlots {
            let buttonX = panelBounds.width * 0.55  // 55% from left (leaves space for fluid tanks)
            let buttonY = panelBounds.height * 0.325 + (buttonSizePoints + spacingPoints) * CGFloat(i)

            let button = UIKit.UIButton(frame: CGRect(x: buttonX, y: buttonY, width: buttonSizePoints, height: buttonSizePoints))
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
              let fluidTankComponent = gameLoop.world.get(FluidTankComponent.self, for: entity) else {
            return
        }

        let tankWidth: CGFloat = 60
        let tankHeight: CGFloat = 40
        let tankSpacing: CGFloat = 8
        let tankStartX = panelBounds.width * 0.75  // 75% from left
        let tankStartY = panelBounds.height * 0.325

        // Input Tanks Header
        let inputHeaderLabel = UILabel(frame: CGRect(x: tankStartX, y: tankStartY - 20, width: tankWidth, height: 15))
        inputHeaderLabel.text = "INPUT"
        inputHeaderLabel.font = UIFont.systemFont(ofSize: 8, weight: .bold)
        inputHeaderLabel.textColor = .cyan
        inputHeaderLabel.textAlignment = .center
        rootView?.addSubview(inputHeaderLabel)

        // Input tanks (top section)
        for i in 0..<min(fluidTankComponent.tanks.count, 2) {  // First 2 tanks as inputs
            let tankY = tankStartY + CGFloat(i) * (tankHeight + tankSpacing)

            // Tank background
            let tankView = UIView(frame: CGRect(x: tankStartX, y: tankY, width: tankWidth, height: tankHeight))
            tankView.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.8)
            tankView.layer.borderColor = UIColor.cyan.cgColor
            tankView.layer.borderWidth = 1.0
            tankView.layer.cornerRadius = 3.0
            rootView?.addSubview(tankView)

            // Fluid fill indicator
            if i < fluidTankComponent.tanks.count {
                let tank = fluidTankComponent.tanks[i]
                let fillLevel = fluidTankComponent.maxCapacity > 0 ? tank.amount / fluidTankComponent.maxCapacity : 0
                let fillHeight = tankHeight * CGFloat(fillLevel)

                let fillView = UIView(frame: CGRect(x: tankStartX, y: tankY + tankHeight - fillHeight, width: tankWidth, height: fillHeight))
                let fluidColor = getFluidColor(for: tank.type)
                fillView.backgroundColor = fluidColor.withAlphaComponent(0.8)
                rootView?.addSubview(fillView)
            }

            // Tank label - positioned clearly below tank
            let labelY = tankY + tankHeight + 4  // 4px below tank for clear separation
            let label = UILabel(frame: CGRect(x: tankStartX, y: labelY, width: tankWidth, height: 15))
            if i < fluidTankComponent.tanks.count {
                let tank = fluidTankComponent.tanks[i]
                let fluidName = tank.amount > 0 ? tank.type.rawValue : "Empty"
                let displayName = fluidName == "water" && tank.amount == 0 ? "Empty" : fluidName
                label.text = "\(displayName): \(Int(tank.amount))/\(Int(fluidTankComponent.maxCapacity))"
            } else {
                label.text = "Empty: 0/\(Int(fluidTankComponent.maxCapacity))"
            }
            label.font = UIFont.systemFont(ofSize: 8, weight: .medium)
            label.textColor = .cyan
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            rootView?.addSubview(label)
        }

        // Output Tanks Header
        let outputHeaderY = tankStartY + 2 * (tankHeight + tankSpacing) + 5
        let outputHeaderLabel = UILabel(frame: CGRect(x: tankStartX, y: outputHeaderY, width: tankWidth, height: 15))
        outputHeaderLabel.text = "OUTPUT"
        outputHeaderLabel.font = UIFont.systemFont(ofSize: 8, weight: .bold)
        outputHeaderLabel.textColor = .green
        outputHeaderLabel.textAlignment = .center
        rootView?.addSubview(outputHeaderLabel)

        // Output tanks (bottom section)
        let outputTankStartY = outputHeaderY + 15 + 5  // Space after header
        for i in 2..<fluidTankComponent.tanks.count {  // Tanks 2+ as outputs
            let tankIndex = i - 2  // Local index for output tanks
            let tankY = outputTankStartY + CGFloat(tankIndex) * (tankHeight + tankSpacing)

            // Tank background
            let tankView = UIView(frame: CGRect(x: tankStartX, y: tankY, width: tankWidth, height: tankHeight))
            tankView.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.8)
            tankView.layer.borderColor = UIColor.green.cgColor
            tankView.layer.borderWidth = 1.0
            tankView.layer.cornerRadius = 3.0
            rootView?.addSubview(tankView)

            // Fluid fill indicator
            let tank = fluidTankComponent.tanks[i]
            let fillLevel = fluidTankComponent.maxCapacity > 0 ? tank.amount / fluidTankComponent.maxCapacity : 0
            let fillHeight = tankHeight * CGFloat(fillLevel)

            let fillView = UIView(frame: CGRect(x: tankStartX, y: tankY + tankHeight - fillHeight, width: tankWidth, height: fillHeight))
            let fluidColor = getFluidColor(for: tank.type)
            fillView.backgroundColor = fluidColor.withAlphaComponent(0.8)
            rootView?.addSubview(fillView)

            // Tank label - positioned clearly below tank
            let labelY = tankY + tankHeight + 4  // 4px below tank for clear separation
            let label = UILabel(frame: CGRect(x: tankStartX, y: labelY, width: tankWidth, height: 15))
            let fluidName = tank.amount > 0 ? tank.type.rawValue : "Empty"
            let displayName = fluidName == "water" && tank.amount == 0 ? "Empty" : fluidName
            label.text = "\(displayName): \(Int(tank.amount))/\(Int(fluidTankComponent.maxCapacity))"
            label.font = UIFont.systemFont(ofSize: 8, weight: .medium)
            label.textColor = .green
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            rootView?.addSubview(label)
        }
    }

    private func updateChemicalPlantTanks(_ entity: Entity) {
        guard let gameLoop = gameLoop,
              let fluidTankComponent = gameLoop.world.get(FluidTankComponent.self, for: entity),
              let rootView = rootView else {
            return
        }

        // Remove existing chemical plant tank views and labels
        // We identify them by their specific positioning (75%+ from left, specific size ranges)
        let tankSubviews = rootView.subviews.filter { subview in
            let frame = subview.frame
            // Tank views and labels are positioned at 75%+ from left and have specific dimensions
            return frame.origin.x >= rootView.bounds.width * 0.75 &&
                   ((frame.size.width >= 55 && frame.size.width <= 65) || // Tank width ~60
                    (frame.size.height >= 12 && frame.size.height <= 18))   // Label height ~15
        }

        tankSubviews.forEach { $0.removeFromSuperview() }

        // Recreate the tank display
        setupChemicalPlantFluidTanks(rootView.bounds)
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
        } else if let fluidTank = gameLoop.world.get(FluidTankComponent.self, for: entity),
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
        print("MachineUI: loadRecipeImage called for '\(textureId)'")
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
        guard gameLoop != nil else { return }

        let recipeIndex = Int(button.tag)

        if recipeIndex >= 0 && recipeIndex < filteredRecipes.count {
            let recipe = filteredRecipes[recipeIndex]

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
            // Check item inputs
            for input in recipe.inputs {
                if !gameLoop.player.inventory.has(itemId: input.itemId, count: input.count) {
                    canCraft = false
                    missingItems.append("\(input.itemId) (\(input.count))")
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
            tooltip += " - Missing: "
            let missing = (missingItems + missingFluids).joined(separator: ", ")
            tooltip += missing
        }

        // Show the tooltip using the game's tooltip system
        gameLoop?.inputManager?.onTooltip?(tooltip)
    }

    private func updateRecipeButtonStates() {
        guard let gameLoop = gameLoop else { return }

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

        // Show input requirements (items and fluids)
        var currentX: CGFloat = 20

        // Item inputs
        for input in recipe.inputs {
            addItemIcon(input.itemId, count: input.count, atX: currentX, y: detailsY, iconSize: iconSize, to: rootView)
            currentX += iconSpacing
        }

        // Fluid inputs
        for fluidInput in recipe.fluidInputs {
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
            addItemIcon(output.itemId, count: output.count, atX: currentX, y: detailsY, iconSize: iconSize, to: rootView)
            currentX += iconSpacing
        }

        // Fluid outputs
        for fluidOutput in recipe.fluidOutputs {
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
            print("MachineUI: Attempted to open already open panel")
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
            print("MachineUI: Setting up UI components for entity \(entity.id)")
            for component in machineComponents {
                component.setupUI(for: entity, in: self)
            }
        } else {
            print("MachineUI: No currentEntity set - cannot setup UI components")
        }

        // Set up UIKit components
        // Only setup recipe UI if this machine has AssemblerComponent (can select recipes)
        if let entity = currentEntity, let gameLoop = gameLoop,
           gameLoop.world.has(AssemblerComponent.self, for: entity) {
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
            layoutProgressBar()
            relayoutCountLabels()
            // Update the UI with current machine state
            updateMachine(currentEntity!)
        }

        // Add root view to hierarchy (AFTER content is added to it)
        if let rootView = rootView {
            print("MachineUI: Adding rootView to hierarchy")
            onAddRootView?(rootView)
            print("MachineUI: Opened panel with rootView at \(rootView.frame), superview = \(String(describing: rootView.superview))")
        } else {
            print("MachineUI: Failed to create rootView - closing panel")
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
        print("MachineUI close: rootView super = \(String(describing: rootView?.superview)), isOpen = \(isOpen)")
    }


    private func setupSlotsForMachine(_ entity: Entity) {
        guard let gameLoop = gameLoop else { return }

        print("MachineUI: setupSlotsForMachine called - fuelSlots.count=\(fuelSlots.count), fuelCountLabels.count=\(fuelCountLabels.count)")

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
            print("MachineUI: Processing fuel slot \(i) - fuelCountLabels.count=\(fuelCountLabels.count)")
            if inventoryIndex < totalSlots, let item = inventory.slots[inventoryIndex] {
                fuelSlots[i].item = item
                fuelSlots[i].isRequired = false
                // Only update UI if labels exist
                if i < fuelCountLabels.count {
                    fuelCountLabels[i].text = "\(item.count)"
                    fuelCountLabels[i].isHidden = false
                    print("MachineUI: Updated fuel label \(i) with count \(item.count)")
                } else {
                    print("MachineUI: Fuel label \(i) not available (only \(fuelCountLabels.count) labels exist)")
                }
            } else {
                fuelSlots[i].item = nil
                fuelSlots[i].isRequired = false
                // Only update UI if labels exist
                if i < fuelCountLabels.count {
                    fuelCountLabels[i].text = "0"
                    fuelCountLabels[i].isHidden = true
                    print("MachineUI: Cleared fuel label \(i)")
                } else {
                    print("MachineUI: Could not clear fuel label \(i) - label not available")
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

        // Check if this is a chemical plant and update its custom tanks
        if let gameLoop = gameLoop,
           let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop),
           buildingDef.type == .chemicalPlant {
            updateChemicalPlantTanks(entity)
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
            print("MachineUI: getBuildingDefinition found MinerComponent")
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            buildingComponent = furnace
            print("MachineUI: getBuildingDefinition found FurnaceComponent")
        } else if let fluidTank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
            buildingComponent = fluidTank
            print("MachineUI: getBuildingDefinition found FluidTankComponent")
        } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            buildingComponent = assembler
            print("MachineUI: getBuildingDefinition found AssemblerComponent")
        } else if let generator = gameLoop.world.get(GeneratorComponent.self, for: entity) {
            buildingComponent = generator
            print("MachineUI: getBuildingDefinition found GeneratorComponent")
        } else if let lab = gameLoop.world.get(LabComponent.self, for: entity) {
            buildingComponent = lab
            print("MachineUI: getBuildingDefinition found LabComponent")
        } else if let rocketSilo = gameLoop.world.get(RocketSiloComponent.self, for: entity) {
            buildingComponent = rocketSilo
            print("MachineUI: getBuildingDefinition found RocketSiloComponent")
        } else if let fluidProducer = gameLoop.world.get(FluidProducerComponent.self, for: entity) {
            buildingComponent = fluidProducer
            print("MachineUI: getBuildingDefinition found FluidProducerComponent")
        } else if let fluidConsumer = gameLoop.world.get(FluidConsumerComponent.self, for: entity) {
            buildingComponent = fluidConsumer
            print("MachineUI: getBuildingDefinition found FluidConsumerComponent")
        } else {
            print("MachineUI: getBuildingDefinition found no building component for entity \(entity.id)")
            return nil
        }

        guard let component = buildingComponent else { 
            print("MachineUI: buildingComponent was nil")
            return nil 
        }
        let buildingDef = gameLoop.buildingRegistry.get(component.buildingId)
        if buildingDef == nil {
            print("MachineUI: buildingRegistry.get(\(component.buildingId)) returned nil")
        } else {
            print("MachineUI: found building definition \(component.buildingId)")
        }
        return buildingDef
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
            return
        }

        // Update UIKit progress bar
        progressBarBackground?.isHidden = false
        progressBarFill?.isHidden = false

        guard let backgroundFrame = progressBarBackground?.frame else { return }

        // Update fill width and color
        var fillWidth: CGFloat
        var fillColor: UIColor
        var statusText: String

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

            if progress > 0 {
                statusText = String(format: "Crafting: %.0f%%", p * 100)
            } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity),
                      assembler.recipe != nil {
                statusText = "Ready to Craft"
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
        progressStatusLabel?.text = statusText

        // UIKit progress bar updated above
    }
}
