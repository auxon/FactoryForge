import Foundation
import UIKit

// Use UIKit's UIButton explicitly to avoid conflict with custom UIButton
typealias UIKitButton = UIKit.UIButton

/// Callback type for recipe selection
typealias RecipeSelectionCallback = (Entity, Recipe) -> Void

/// JSON-based UI configuration structures
struct MachineUIConfig: Codable {
    let machineType: String
    let layout: LayoutConfig
    let components: [ComponentConfig]

    struct LayoutConfig: Codable {
        let panelWidth: CGFloat
        let panelHeight: CGFloat
        let backgroundColor: String
        let borderWidth: CGFloat
        let cornerRadius: CGFloat
    }

    struct ComponentConfig: Codable {
        let type: String
        let position: PositionConfig
        let properties: [String: PropertyValue]

        struct PositionConfig: Codable {
            let x: CGFloat
            let y: CGFloat
            let width: CGFloat
            let height: CGFloat
        }
    }

    enum PropertyValue: Codable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
            } else if let intValue = try? container.decode(Int.self) {
                self = .int(intValue)
            } else if let doubleValue = try? container.decode(Double.self) {
                self = .double(doubleValue)
            } else if let boolValue = try? container.decode(Bool.self) {
                self = .bool(boolValue)
            } else {
                throw DecodingError.typeMismatch(PropertyValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported property type"))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value): try container.encode(value)
            case .int(let value): try container.encode(value)
            case .double(let value): try container.encode(value)
            case .bool(let value): try container.encode(value)
            }
        }

        var stringValue: String? {
            if case .string(let value) = self { return value }
            return nil
        }

        var intValue: Int? {
            if case .int(let value) = self { return value }
            return nil
        }

        var doubleValue: Double? {
            if case .double(let value) = self { return value }
            return nil
        }

        var boolValue: Bool? {
            if case .bool(let value) = self { return value }
            return nil
        }
    }
}

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

    var recipeRegionX: CGFloat { W * 0.28 }
    var recipeRegionWidth: CGFloat { W * 0.44 }

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
    private var pendingEntitySetup: Entity?

    // JSON-based UI configuration system
    private var uiConfigs: [String: MachineUIConfig] = [:]
    private var configDirectory: URL?

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
    private var recipeHeaderLabel: UILabel?
    private var noRecipeSelectedLabel: UILabel?

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

    var openPipeTankSelectionOnOpen: Bool = false

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

        // Initialize config directory
        setupConfigDirectory()

        // Load all UI configurations
        loadAllConfigurations()

        setupSlots()
    }

    /// Set up the configuration directory
    private func setupConfigDirectory() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if let documentsDir = paths.first {
            configDirectory = documentsDir.appendingPathComponent("machine_ui_configs")
            try? FileManager.default.createDirectory(at: configDirectory!, withIntermediateDirectories: true)
        }
    }

    /// Load all JSON configuration files
    private func loadAllConfigurations() {
        guard let configDir = configDirectory else { return }

        // First, ensure default configurations exist in Documents directory
        copyBundledConfigurationsIfNeeded()

        do {
            let files = try FileManager.default.contentsOfDirectory(at: configDir, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == "json" }

            for fileURL in jsonFiles {
                if let config = loadConfiguration(from: fileURL) {
                    uiConfigs[config.machineType] = config
                }
            }

            print("MachineUI: Loaded \(uiConfigs.count) UI configurations")
        } catch {
            print("MachineUI: Error loading configurations: \(error)")
            // Load default configurations if no files exist
            createDefaultConfigurations()
        }
    }

    /// Copy bundled configuration files to Documents directory if they don't exist
    private func copyBundledConfigurationsIfNeeded() {
        guard let configDir = configDirectory else { return }

        let bundledConfigs = ["assembler", "furnace", "mining_drill", "rocket_silo"]

        for configName in bundledConfigs {
            let fileName = "\(configName).json"
            let destURL = configDir.appendingPathComponent(fileName)

            // Skip if file already exists
            if FileManager.default.fileExists(atPath: destURL.path) {
                continue
            }

            // Try to copy from bundled resources
            if let bundledURL = Bundle.main.url(forResource: configName, withExtension: "json") {
                do {
                    try FileManager.default.copyItem(at: bundledURL, to: destURL)
                    print("MachineUI: Copied bundled config: \(configName)")
                } catch {
                    print("MachineUI: Error copying bundled config \(configName): \(error)")
                }
            }
        }
    }

    /// Load a single configuration from JSON file
    private func loadConfiguration(from url: URL) -> MachineUIConfig? {
        do {
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(MachineUIConfig.self, from: data)
            return config
        } catch {
            print("MachineUI: Error loading config from \(url): \(error)")
            return nil
        }
    }

    /// Save a configuration to JSON file
    private func saveConfiguration(_ config: MachineUIConfig) {
        guard let configDir = configDirectory else { return }

        let fileName = "\(config.machineType).json"
        let fileURL = configDir.appendingPathComponent(fileName)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: fileURL)
            uiConfigs[config.machineType] = config
            print("MachineUI: Saved configuration for \(config.machineType)")
        } catch {
            print("MachineUI: Error saving config: \(error)")
        }
    }

    /// Create default configurations for all machine types
    private func createDefaultConfigurations() {
        let assemblerConfig = MachineUIConfig(
            machineType: "assembler",
            layout: MachineUIConfig.LayoutConfig(
                panelWidth: 600,
                panelHeight: 350,
                backgroundColor: "#1a1a1a",
                borderWidth: 2,
                cornerRadius: 8
            ),
            components: [
                MachineUIConfig.ComponentConfig(
                    type: "slotButtons",
                    position: MachineUIConfig.ComponentConfig.PositionConfig(
                        x: 20, y: 60, width: 200, height: 100
                    ),
                    properties: [
                        "inputSlots": .int(2),
                        "outputSlots": .int(1),
                        "fuelSlots": .int(0)
                    ]
                ),
                MachineUIConfig.ComponentConfig(
                    type: "recipeSelector",
                    position: MachineUIConfig.ComponentConfig.PositionConfig(
                        x: 240, y: 60, width: 320, height: 200
                    ),
                    properties: [
                        "showHeader": .bool(true),
                        "scrollable": .bool(true)
                    ]
                ),
                MachineUIConfig.ComponentConfig(
                    type: "progressBar",
                    position: MachineUIConfig.ComponentConfig.PositionConfig(
                        x: 20, y: 180, width: 200, height: 20
                    ),
                    properties: [
                        "showPercentage": .bool(true),
                        "color": .string("#0000FF")
                    ]
                )
            ]
        )

        let furnaceConfig = MachineUIConfig(
            machineType: "furnace",
            layout: MachineUIConfig.LayoutConfig(
                panelWidth: 400,
                panelHeight: 300,
                backgroundColor: "#1a1a1a",
                borderWidth: 2,
                cornerRadius: 8
            ),
            components: [
                MachineUIConfig.ComponentConfig(
                    type: "slotButtons",
                    position: MachineUIConfig.ComponentConfig.PositionConfig(
                        x: 20, y: 60, width: 150, height: 100
                    ),
                    properties: [
                        "inputSlots": .int(1),
                        "outputSlots": .int(1),
                        "fuelSlots": .int(1)
                    ]
                ),
                MachineUIConfig.ComponentConfig(
                    type: "progressBar",
                    position: MachineUIConfig.ComponentConfig.PositionConfig(
                        x: 20, y: 180, width: 150, height: 20
                    ),
                    properties: [
                        "showPercentage": .bool(true),
                        "color": .string("#FFA500")
                    ]
                )
            ]
        )

        let miningDrillConfig = MachineUIConfig(
            machineType: "mining_drill",
            layout: MachineUIConfig.LayoutConfig(
                panelWidth: 400,
                panelHeight: 250,
                backgroundColor: "#1a1a1a",
                borderWidth: 2,
                cornerRadius: 8
            ),
            components: [
                MachineUIConfig.ComponentConfig(
                    type: "slotButtons",
                    position: MachineUIConfig.ComponentConfig.PositionConfig(
                        x: 20, y: 60, width: 360, height: 120
                    ),
                    properties: [
                        "inputSlots": .int(0),
                        "outputSlots": .int(1),
                        "fuelSlots": .int(1),
                        "layout": .string("fuel_left_output_center")
                    ]
                ),
                MachineUIConfig.ComponentConfig(
                    type: "progressBar",
                    position: MachineUIConfig.ComponentConfig.PositionConfig(
                        x: 140, y: 80, width: 120, height: 20
                    ),
                    properties: [
                        "showPercentage": .bool(true),
                        "color": .string("#00FF00")
                    ]
                )
            ]
        )

        let labConfig = MachineUIConfig(
            machineType: "lab",
            layout: MachineUIConfig.LayoutConfig(
                panelWidth: 400,
                panelHeight: 300,
                backgroundColor: "#2a2a4a",
                borderWidth: 2,
                cornerRadius: 8
            ),
            components: [
                MachineUIConfig.ComponentConfig(
                    type: "headerLabel",
                    position: MachineUIConfig.ComponentConfig.PositionConfig(
                        x: 20, y: 20, width: 360, height: 30
                    ),
                    properties: [
                        "text": .string("Research Lab"),
                        "fontSize": .double(18.0),
                        "textColor": .string("#FFFFFF")
                    ]
                ),
                MachineUIConfig.ComponentConfig(
                    type: "slotButtons",
                    position: MachineUIConfig.ComponentConfig.PositionConfig(
                        x: 20, y: 60, width: 360, height: 200
                    ),
                    properties: [
                        "inputSlots": .int(2),
                        "outputSlots": .int(0),
                        "fuelSlots": .int(0)
                    ]
                ),
                MachineUIConfig.ComponentConfig(
                    type: "statusLabel",
                    position: MachineUIConfig.ComponentConfig.PositionConfig(
                        x: 20, y: 270, width: 360, height: 20
                    ),
                    properties: [
                        "text": .string("Research in progress..."),
                        "fontSize": .double(12.0),
                        "textColor": .string("#CCCCCC")
                    ]
                )
            ]
        )

        // Save default configurations
        saveConfiguration(assemblerConfig)
        saveConfiguration(furnaceConfig)
        saveConfiguration(miningDrillConfig)
        saveConfiguration(labConfig)
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

        // Store entity for setup when rootView is available
        pendingEntitySetup = entity

        // If UI is already open with rootView, set up immediately
        if isOpen && rootView != nil {
            setupComponentsForEntity(entity)
            pendingEntitySetup = nil
        }
    }

    private func setupComponentsForEntity(_ entity: Entity) {
        // Clear existing components
        machineComponents.removeAll()

        // Try to load configuration for this machine type
        if let gameLoop = gameLoop {
            let machineType = determineMachineType(for: entity, in: gameLoop)

            // Check if there's a current schema for this machine type
            if let schema = currentSchema, schema.machineKind == machineType {
                // Use the current schema
                do {
                    try applySchema(schema)
                } catch {
                    print("MachineUI: Error applying current schema: \(error)")
                    // Fall back to stored config
                    if let config = uiConfigs[machineType] {
                        applyConfiguration(config)
                    } else {
                        setupLegacyComponents(for: entity, in: gameLoop)
                    }
                }
            } else if let schema = loadSchema(for: machineType) {
                // Load schema from disk and use it
                currentSchema = schema
                do {
                    try applySchema(schema)
                } catch {
                    print("MachineUI: Error applying loaded schema: \(error)")
                    // Fall back to stored config
                    if let config = uiConfigs[machineType] {
                        applyConfiguration(config)
                    } else {
                        setupLegacyComponents(for: entity, in: gameLoop)
                    }
                }
            } else if let config = uiConfigs[machineType] {
                // Use stored JSON configuration
                applyConfiguration(config)
            } else {
                // Fallback to legacy component-based system
                setupLegacyComponents(for: entity, in: gameLoop)
            }
        }

        // Setup common UI elements (legacy compatibility)
        setupSlots()
        setupSlotsForMachine(entity)

        // Setup machine-specific UI components
        for (_, component) in machineComponents.enumerated() {
            component.setupUI(for: entity, in: self)
        }

        if openPipeTankSelectionOnOpen {
            for component in machineComponents {
                if let pipeComponent = component as? PipeConnectionUIComponent {
                    pipeComponent.openTankSelection()
                }
            }
            openPipeTankSelectionOnOpen = false
        }

        // Setup power label for generators (legacy compatibility)
        setupPowerLabel(for: entity)

        // Set up UIKit slot buttons and layout
        clearSlotUI()
        setupSlotButtons()
        layoutAll()
        // Update the UI with current machine state
        updateMachine(entity)
    }

    // MARK: - New Formal Schema Support

    /// Load and apply a formal MachineUI schema
    func applySchema(_ schema: MachineUISchema) throws {
        guard let rootView = rootView else {
            throw SchemaError.rootViewNotAvailable
        }

        // Validate invariants
        let layoutEngine = MachineUILayoutEngine(schema: schema, rootView: rootView)
        try layoutEngine.validateInvariants()

        // Clear existing content
        clearSlotUI()
        machineComponents.removeAll()

        // Build new UI using schema
        let builder = MachineUIBuilder(schema: schema)
        _ = builder.build(in: rootView)

        // Store schema for later reference
        self.currentSchema = schema

        // Convert schema to MachineUIConfig format and save for persistence
        let config = convertSchemaToConfig(schema)
        saveConfiguration(config)

        // Also save the schema itself for future reference
        saveSchema(schema)
    }

    /// Load schema from JSON file in bundle
    func loadSchemaFromBundle(named filename: String) throws -> MachineUISchema {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            throw SchemaError.schemaFileNotFound(filename)
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(MachineUISchema.self, from: data)
    }

    // MARK: - Schema Conversion and Persistence

    /// Convert a MachineUISchema to MachineUIConfig for persistence
    private func convertSchemaToConfig(_ schema: MachineUISchema) -> MachineUIConfig {
        // Calculate panel dimensions based on grid and layout
        let panelWidth = CGFloat(schema.layout.grid.columns) * 80.0 + 48.0 // Rough estimate
        let panelHeight = CGFloat(schema.layout.grid.rows) * 60.0 + 48.0 // Rough estimate

        let layout = MachineUIConfig.LayoutConfig(
            panelWidth: panelWidth,
            panelHeight: panelHeight,
            backgroundColor: "#1a1a1a",
            borderWidth: 1.0,
            cornerRadius: 8.0
        )

        var components: [MachineUIConfig.ComponentConfig] = []

        // Convert groups to components
        for group in schema.groups {
            // Add group header as a label component
            let headerY = CGFloat(group.anchor.gridY) * 60.0 + 8.0
            let headerTextColor = colorForStyleRole(group.header.styleRole, palette: schema.style.palette)
            let headerBackgroundColor = headerTextColor + "20" // Add transparency
            let headerComponent = MachineUIConfig.ComponentConfig(
                type: "label",
                position: MachineUIConfig.ComponentConfig.PositionConfig(
                    x: CGFloat(group.anchor.gridX) * 80.0 + 8.0,
                    y: headerY,
                    width: CGFloat(group.anchor.spanX) * 80.0 - 16.0,
                    height: 20.0
                ),
                properties: [
                    "text": .string(group.header.text),
                    "fontSize": .double(14.0),
                    "textColor": .string(headerTextColor),
                    "backgroundColor": .string(headerBackgroundColor)
                ]
            )
            components.append(headerComponent)

            // Add slot buttons for the group
            let slotsY = headerY + 24.0
            for (index, slot) in group.content.slots.enumerated() {
                let inputSlots = slot.slotKind == .item && group.role == .input ? 1 : 0
                let outputSlots = slot.slotKind == .item && group.role == .output ? 1 : 0
                let fuelSlots = slot.slotKind == .item && group.role == .fuel ? 1 : 0
                let slotComponent = MachineUIConfig.ComponentConfig(
                    type: "slotButtons",
                    position: MachineUIConfig.ComponentConfig.PositionConfig(
                        x: CGFloat(group.anchor.gridX) * 80.0 + 8.0,
                        y: slotsY + CGFloat(index) * 60.0,
                        width: CGFloat(group.anchor.spanX) * 80.0 - 16.0,
                        height: 50.0
                    ),
                    properties: [
                        "inputSlots": .int(inputSlots),
                        "outputSlots": .int(outputSlots),
                        "fuelSlots": .int(fuelSlots)
                    ]
                )
                components.append(slotComponent)
            }

            // Add state text as a label component
            if let stateText = group.content.stateText {
                let stateY = slotsY + CGFloat(group.content.slots.count) * 60.0 + 8.0
                let stateComponent = MachineUIConfig.ComponentConfig(
                    type: "label",
                position: MachineUIConfig.ComponentConfig.PositionConfig(
                    x: CGFloat(group.anchor.gridX) * 80.0 + 8.0,
                    y: stateY,
                    width: CGFloat(group.anchor.spanX) * 80.0 - 16.0,
                    height: 16.0
                ),
                    properties: [
                        "text": .string(stateText.empty),
                        "fontSize": .double(10.0),
                        "textColor": .string(schema.style.palette.mutedText)
                    ]
                )
                components.append(stateComponent)
            }
        }

        // Convert process to components
        if let process = schema.process {
            let processY = CGFloat(process.anchor.gridY) * 60.0 + 8.0
            // Add process label
            let processLabelComponent = MachineUIConfig.ComponentConfig(
                type: "label",
                position: MachineUIConfig.ComponentConfig.PositionConfig(
                    x: CGFloat(process.anchor.gridX) * 80.0 + 8.0,
                    y: processY,
                    width: CGFloat(process.anchor.spanX) * 80.0 - 16.0,
                    height: 20.0
                ),
                properties: [
                    "text": .string(process.label.text),
                    "fontSize": .double(14.0),
                    "textColor": .string(colorForStyleRole(.process, palette: schema.style.palette))
                ]
            )
            components.append(processLabelComponent)

            // Add progress bar
            let progressY = processY + 24.0
            let progressComponent = MachineUIConfig.ComponentConfig(
                type: "progressBar",
                position: MachineUIConfig.ComponentConfig.PositionConfig(
                    x: CGFloat(process.anchor.gridX) * 80.0 + 8.0,
                    y: progressY,
                    width: CGFloat(process.anchor.spanX) * 80.0 - 16.0,
                    height: 20.0
                ),
                properties: [
                    "showPercentage": .bool(process.progress.showPercent),
                    "color": .string(colorForStyleRole(.process, palette: schema.style.palette))
                ]
            )
            components.append(progressComponent)
        }

        // Convert recipes to components
        if let recipes = schema.recipes {
            let recipesY = CGFloat(recipes.anchor.gridY) * 60.0 + 8.0
            let recipesComponent = MachineUIConfig.ComponentConfig(
                type: "recipeSelector",
                position: MachineUIConfig.ComponentConfig.PositionConfig(
                    x: CGFloat(recipes.anchor.gridX) * 80.0 + 8.0,
                    y: recipesY,
                    width: CGFloat(recipes.anchor.spanX) * 80.0 - 16.0,
                    height: CGFloat(recipes.anchor.spanY) * 60.0 - 16.0
                ),
                properties: [
                    "showHeader": .bool(true),
                    "scrollable": .bool(true)
                ]
            )
            components.append(recipesComponent)
        }

        return MachineUIConfig(
            machineType: schema.machineKind,
            layout: layout,
            components: components
        )
    }

    private func colorForStyleRole(_ role: Group.GroupHeader.StyleRole, palette: Style.Palette) -> String {
        switch role {
        case .fuel: return palette.fuel
        case .input: return palette.input
        case .output: return palette.output
        case .process: return palette.process
        case .neutral: return palette.mutedText
        }
    }

    // MARK: - Schema State
    private var currentSchema: MachineUISchema?

    enum SchemaError: Error {
        case rootViewNotAvailable
        case schemaFileNotFound(String)
        case validationFailed(String)
    }

    /// Fallback method for machine types not yet converted to JSON config
    private func setupLegacyComponents(for entity: Entity, in gameLoop: GameLoop) {
        // Check for fluid-based machines (including tanks)
        let hasFluidProducer = gameLoop.world.has(FluidProducerComponent.self, for: entity)
        let hasFluidConsumer = gameLoop.world.has(FluidConsumerComponent.self, for: entity)
        let hasFluidTank = gameLoop.world.has(FluidTankComponent.self, for: entity)

        if hasFluidProducer || hasFluidConsumer || hasFluidTank {
            machineComponents.append(FluidMachineUIComponent())
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

        // Check for lab machines (research facilities)
        if gameLoop.world.has(LabComponent.self, for: entity) {
            // Labs don't need special components, just show inventory slots
            // The slot setup will handle the input slots automatically
        }
    }

    /// Apply a JSON-based configuration to the UI
    private func applyConfiguration(_ config: MachineUIConfig) {
        // Update panel size if needed
        let newWidth = Float(config.layout.panelWidth * CGFloat(UIScale))
        let newHeight = Float(config.layout.panelHeight * CGFloat(UIScale))

        // Only resize if significantly different
        if abs(Float(frame.size.x) - newWidth) > 10 || abs(Float(frame.size.y) - newHeight) > 10 {
            frame = Rect(center: Vector2(screenSize.x / 2, screenSize.y / 2), size: Vector2(newWidth, newHeight))
        }

        // Create components based on configuration
        for componentConfig in config.components {
            createComponentFromConfig(componentConfig)
        }
    }

    /// Create UI components from JSON configuration
    private func createComponentFromConfig(_ config: MachineUIConfig.ComponentConfig) {
        let position = CGRect(
            x: config.position.x,
            y: config.position.y,
            width: config.position.width,
            height: config.position.height
        )

        switch config.type {
        case "slotButtons":
            // Check if custom layout is specified
            if case let .string(layout) = config.properties["layout"], layout == "fuel_left_output_center" {
                setupMiningDrillSlotLayout(config, position: position)
            } else {
                // Default slot layout
                // Slot buttons are handled by the existing setupSlotButtons method
            }
            break
        case "headerLabel":
            setupHeaderLabelFromConfig(config, position: position)
        case "statusLabel":
            setupStatusLabelFromConfig(config, position: position)
        case "label":
            setupLabelFromConfig(config, position: position)
        case "recipeSelector":
            setupRecipeSelectorFromConfig(config, position: position)
        case "progressBar":
            setupProgressBarFromConfig(config, position: position)
        case "powerLabel":
            setupPowerLabelFromConfig(config, position: position)
        case "fluidDisplay":
            setupFluidDisplayFromConfig(config, position: position)
        case "launchButton":
            setupLaunchButtonFromConfig(config, position: position)
        default:
            print("MachineUI: Unknown component type: \(config.type)")
        }
    }

    /// Setup recipe selector from config
    private func setupRecipeSelectorFromConfig(_ config: MachineUIConfig.ComponentConfig, position: CGRect) {
        // This would integrate with the existing recipe selector setup
        // For now, use existing logic but with configurable position
    }

    /// Setup progress bar from config
    private func setupProgressBarFromConfig(_ config: MachineUIConfig.ComponentConfig, position: CGRect) {
        // Configure progress bar appearance and position
    }

    /// Setup header label from config
    private func setupHeaderLabelFromConfig(_ config: MachineUIConfig.ComponentConfig, position: CGRect) {
        let label = UILabel(frame: position)
        label.textAlignment = .center
        label.font = UIFont.boldSystemFont(ofSize: 18)

        // Apply config properties
        if case let .string(text) = config.properties["text"] {
            label.text = text
        }
        if case let .double(fontSize) = config.properties["fontSize"] {
            label.font = UIFont.boldSystemFont(ofSize: CGFloat(fontSize))
        }
        if case let .string(colorHex) = config.properties["textColor"] {
            label.textColor = UIColor(hex: colorHex) ?? .white
        }

        rootView?.addSubview(label)
    }

    /// Setup mining drill slot layout (fuel left, output center)
    private func setupMiningDrillSlotLayout(_ config: MachineUIConfig.ComponentConfig, position: CGRect) {
        guard let entity = currentEntity,
              let gameLoop = gameLoop,
              let rootView = rootView else {
            return
        }

        // Get building definition
        guard let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop) else {
            return
        }

        let fuelCount = buildingDef.fuelSlots
        let outputCount = buildingDef.outputSlots
        let buttonSizePoints: CGFloat = 32
        let spacingPoints: CGFloat = 8

        // Fuel slots on the left
        for i in 0..<fuelCount {
            let buttonX = position.minX + 10 // Left side within component area
            let buttonY = position.minY + 10 + (buttonSizePoints + spacingPoints) * CGFloat(i)

            let button = UIKit.UIButton(frame: CGRect(x: buttonX, y: buttonY, width: buttonSizePoints, height: buttonSizePoints))
            button.backgroundColor = UIColor(red: 0.5, green: 0.5, blue: 0.6, alpha: 1.0) // Blue-gray for fuel
            button.layer.borderColor = UIColor.white.cgColor
            button.layer.borderWidth = 1.0
            button.layer.cornerRadius = 4.0
            button.translatesAutoresizingMaskIntoConstraints = true

            fuelSlotButtons.append(button)
            button.tag = i
            button.addTarget(self, action: #selector(fuelSlotTapped(_:)), for: UIControl.Event.touchUpInside)
            rootView.addSubview(button)

            // Count label
            let label = attachCountLabel(to: button)
            fuelCountLabels.append(label)
            rootView.addSubview(label)
        }

        // Output slots in the center
        for i in 0..<outputCount {
            let buttonX = position.midX - buttonSizePoints / 2 // Center horizontally
            let buttonY = position.midY - buttonSizePoints / 2 // Center vertically

            let button = UIKit.UIButton(frame: CGRect(x: buttonX, y: buttonY, width: buttonSizePoints, height: buttonSizePoints))
            button.backgroundColor = UIColor(red: 0.3, green: 0.5, blue: 0.3, alpha: 1.0) // Green for output
            button.layer.borderColor = UIColor.white.cgColor
            button.layer.borderWidth = 1.0
            button.layer.cornerRadius = 4.0
            button.translatesAutoresizingMaskIntoConstraints = true

            outputSlotButtons.append(button)
            button.tag = i
            button.addTarget(self, action: #selector(outputSlotTapped(_:)), for: UIControl.Event.touchUpInside)
            rootView.addSubview(button)

            // Count label
            let label = attachCountLabel(to: button)
            outputCountLabels.append(label)
            rootView.addSubview(label)
        }
    }

    /// Setup status label from config
    private func setupStatusLabelFromConfig(_ config: MachineUIConfig.ComponentConfig, position: CGRect) {
        let label = UILabel(frame: position)
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 12)

        // Apply config properties
        if case let .string(text) = config.properties["text"] {
            label.text = text
        }
        if case let .double(fontSize) = config.properties["fontSize"] {
            label.font = UIFont.systemFont(ofSize: CGFloat(fontSize))
        }
        if case let .string(colorHex) = config.properties["textColor"] {
            label.textColor = UIColor(hex: colorHex) ?? .gray
        }

        rootView?.addSubview(label)
    }

    /// Setup generic label from config
    private func setupLabelFromConfig(_ config: MachineUIConfig.ComponentConfig, position: CGRect) {
        let label = UILabel(frame: position)
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)

        // Apply config properties
        if case let .string(text) = config.properties["text"] {
            label.text = text
        }
        if case let .double(fontSize) = config.properties["fontSize"] {
            label.font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: .medium)
        }
        if case let .string(colorHex) = config.properties["textColor"] {
            label.textColor = UIColor(hex: colorHex) ?? .white
        }
        if case let .string(bgColorHex) = config.properties["backgroundColor"] {
            if let bgColor = UIColor(hex: bgColorHex) {
                label.backgroundColor = bgColor
                label.layer.cornerRadius = 4
                label.layer.masksToBounds = true
            }
        }

        rootView?.addSubview(label)
    }

    /// Setup power label from config
    private func setupPowerLabelFromConfig(_ config: MachineUIConfig.ComponentConfig, position: CGRect) {
        // Configure power label
    }

    /// Setup fluid display from config
    private func setupFluidDisplayFromConfig(_ config: MachineUIConfig.ComponentConfig, position: CGRect) {
        // Configure fluid display
    }

    /// Setup launch button from config
    private func setupLaunchButtonFromConfig(_ config: MachineUIConfig.ComponentConfig, position: CGRect) {
        // Configure launch button for rocket silos
    }

    /// Get a UI configuration for runtime editing
    func getConfiguration(for machineType: String) -> MachineUIConfig? {
        return uiConfigs[machineType]
    }

    /// Save a schema to disk
    private func saveSchema(_ schema: MachineUISchema) {
        guard let configDirectory = configDirectory else { return }

        do {
            let schemaURL = configDirectory.appendingPathComponent("\(schema.machineKind)_schema.json")
            let jsonData = try JSONEncoder().encode(schema)
            try jsonData.write(to: schemaURL)
            print("MachineUI: Saved schema for \(schema.machineKind)")
        } catch {
            print("MachineUI: Error saving schema: \(error)")
        }
    }

    /// Load a schema from disk
    private func loadSchema(for machineType: String) -> MachineUISchema? {
        guard let configDirectory = configDirectory else { return nil }

        do {
            let schemaURL = configDirectory.appendingPathComponent("\(machineType)_schema.json")
            let jsonData = try Data(contentsOf: schemaURL)
            let schema = try JSONDecoder().decode(MachineUISchema.self, from: jsonData)
            return schema
        } catch {
            // Schema file doesn't exist or can't be loaded, return nil
            return nil
        }
    }

    /// Update a UI configuration at runtime
    func updateConfiguration(_ config: MachineUIConfig) {
        saveConfiguration(config)

        // If this machine type is currently being displayed, refresh the UI
        if let currentEntity = currentEntity, let gameLoop = gameLoop {
            let currentMachineType = determineMachineType(for: currentEntity, in: gameLoop)
            if currentMachineType == config.machineType && isOpen {
                // Reapply the configuration
                clearSlotUI()
                applyConfiguration(config)
                setupSlotButtons()
                setupRecipeButtons()
            }
        }
    }

    /// Get all available machine type configurations
    func getAllConfigurations() -> [String: MachineUIConfig] {
        return uiConfigs
    }

    /// Determine machine type for an entity
    private func determineMachineType(for entity: Entity, in gameLoop: GameLoop) -> String {
        if gameLoop.world.has(AssemblerComponent.self, for: entity) {
            return "assembler"
        } else if gameLoop.world.has(FurnaceComponent.self, for: entity) {
            return "furnace"
        } else if gameLoop.world.has(MinerComponent.self, for: entity) {
            return "mining_drill"
        } else if gameLoop.world.has(RocketSiloComponent.self, for: entity) {
            return "rocket_silo"
        } else if gameLoop.world.has(LabComponent.self, for: entity) {
            return "lab"
        } else if gameLoop.world.has(GeneratorComponent.self, for: entity) {
            return "generator"
        } else {
            return "unknown"
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
        recipeHeaderLabel = headerLabel

        let emptyLabel = UILabel(frame: CGRect(x: scrollViewX, y: scrollViewY - 36, width: scrollViewWidth, height: 16))
        emptyLabel.text = "No recipe selected"
        emptyLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        emptyLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = selectedRecipe != nil
        rootView.addSubview(emptyLabel)
        noRecipeSelectedLabel = emptyLabel

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

        // For machines without recipes (like miners), position progress bar more centrally
        var barX: CGFloat
        var barWidth: CGFloat

        if recipeScrollView != nil && !recipeUIButtons.isEmpty {
            // Machine has recipes - use recipe region positioning
            barX = L.recipeRegionX + pad
            let barRight = L.recipeRegionX + L.recipeRegionWidth - pad
            let unclampedWidth = barRight - barX
            barWidth = min(unclampedWidth, 360)
        } else {
            // Machine has no recipes - center the progress bar
            barWidth = min(L.W - 2 * pad, 300)
            barX = (L.W - barWidth) / 2
        }

        let barHeight: CGFloat = 20
        let barY = L.topBandY   // put it in the top band

        progressBarBackground.frame = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)
        progressBarFill.frame = CGRect(x: barX, y: barY, width: progressBarFill.frame.width, height: barHeight)

        progressBarBackground.layer.cornerRadius = 4
        progressBarFill.layer.cornerRadius = 4

        // Position status label below progress bar (or below centered input slots when used)
        if let statusLabel = progressStatusLabel {
            var labelY = barY + barHeight + 4
            if let entity = currentEntity,
               let gameLoop = gameLoop,
               let buildingDef = getBuildingDefinition(for: entity, gameLoop: gameLoop),
               shouldCenterInputSlots(for: buildingDef),
               buildingDef.inputSlots > 0 {
                let buttonSizePoints: CGFloat = 32
                let spacingPoints: CGFloat = 8
                let maxPerRow = max(1, Int((barWidth + spacingPoints) / (buttonSizePoints + spacingPoints)))
                let rowCount = Int(ceil(Double(buildingDef.inputSlots) / Double(maxPerRow)))
                labelY = barY + barHeight + 4 + CGFloat(rowCount) * (buttonSizePoints + spacingPoints)
            }
            statusLabel.frame = CGRect(x: barX, y: labelY, width: barWidth, height: 32)
        }
    }

    func positionProgressStatusLabel(centerX: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat = 32) {
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
        let useCenteredInputs = shouldCenterInputSlots(for: buildingDef)
        var centeredStartX: CGFloat = 0
        var centeredStartY: CGFloat = 0
        var centeredMaxPerRow: Int = 1
        if useCenteredInputs {
            let L = MachineUILayout(bounds: panelBounds)
            let pad: CGFloat = 16
            let barX = L.recipeRegionX + pad
            let barRight = L.recipeRegionX + L.recipeRegionWidth - pad
            let barWidth = min(barRight - barX, 360)
            centeredStartX = barX
            centeredStartY = L.topBandY + 20 + 6
            centeredMaxPerRow = max(1, Int((barWidth + spacingPoints) / (buttonSizePoints + spacingPoints)))
        }

        for i in 0..<inputCount {
            let buttonX: CGFloat
            let buttonY: CGFloat
            if useCenteredInputs {
                let row = i / centeredMaxPerRow
                let col = i % centeredMaxPerRow
                buttonX = centeredStartX + CGFloat(col) * (buttonSizePoints + spacingPoints)
                buttonY = centeredStartY + CGFloat(row) * (buttonSizePoints + spacingPoints)
            } else {
                // Position relative to panel bounds - vertical column on left
                buttonX = panelBounds.width * 0.083  // Same X as fuel
                buttonY = panelBounds.height * 0.325 + (buttonSizePoints + spacingPoints) * CGFloat(i)  // 32.5% from top
            }

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
                // Position relative to panel bounds - column on the right side with padding
                buttonX = panelBounds.width * 0.85  // 85% from left (right side with padding)
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

    private func shouldCenterInputSlots(for buildingDef: BuildingDefinition) -> Bool {
        return buildingDef.type == .chemicalPlant
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

    func activeFluidRecipe(for entity: Entity) -> Recipe? {
        if let selectedRecipe {
            return selectedRecipe
        }
        guard let gameLoop else { return nil }
        if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            return assembler.recipe
        }
        if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            return furnace.recipe
        }
        return nil
    }

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
            noRecipeSelectedLabel?.isHidden = true

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
        noRecipeSelectedLabel?.isHidden = true

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
            if let fluidTank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
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
                if let fluidTank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
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
            noRecipeSelectedLabel?.isHidden = false
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

        // Set up components now that rootView exists
        if let entity = pendingEntitySetup {
            print("MachineUI: Setting up components for pending entity")
            setupComponentsForEntity(entity)
            pendingEntitySetup = nil
        }

        // Add root view to hierarchy (AFTER content is added to it)
        if let rootView = rootView {
            print("MachineUI: Calling onAddRootView with rootView frame: \(rootView.frame)")
            if onAddRootView != nil {
                print("MachineUI: onAddRootView callback is set, calling it")
                onAddRootView?(rootView)
                print("MachineUI: onAddRootView callback completed")
            } else {
                print("MachineUI: ERROR - onAddRootView callback is nil!")
            }
        } else {
            print("MachineUI: ERROR - rootView is nil, closing")
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
        noRecipeSelectedLabel?.isHidden = false
        craftButton?.removeFromSuperview()
        craftButton = nil
        clearRecipeDetails()

        // Tear down scroll view FIRST (it has gesture recognizers)
        recipeScrollView?.removeFromSuperview()
        recipeScrollView = nil

        // Remove recipe buttons (they're in the scroll view)
        recipeUIButtons.forEach { $0.removeFromSuperview() }
        recipeUIButtons.removeAll()
        recipeHeaderLabel?.removeFromSuperview()
        recipeHeaderLabel = nil
        noRecipeSelectedLabel?.removeFromSuperview()
        noRecipeSelectedLabel = nil

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
            let updateFluidUI = { [weak self] in
                guard let self else { return }
                for component in self.machineComponents {
                    if let fluidComponent = component as? FluidMachineUIComponent {
                        fluidComponent.updateUI(for: entity, in: self)
                    }
                }
            }

            if Thread.isMainThread {
                updateFluidUI()
            } else {
                DispatchQueue.main.async {
                    updateFluidUI()
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
                if machineInventory.slots[slotIndex] != nil {
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
        var isPumpjack = false
        var powerAvailability: Float = 1.0
        var statusText: String = "Ready"
        var statusColor: UIColor = .white
        var statusFont: UIFont = UIFont.systemFont(ofSize: 10, weight: .medium)
        var statusLines: Int = 1

        if let miner = gameLoop.world.get(MinerComponent.self, for: entity) {
            progress = miner.progress
        } else if let furnace = gameLoop.world.get(FurnaceComponent.self, for: entity) {
            progress = furnace.smeltingProgress
        } else if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
            progress = assembler.craftingProgress
        } else if let pumpjack = gameLoop.world.get(PumpjackComponent.self, for: entity) {
            progress = pumpjack.progress
            isPumpjack = true
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
                statusLines = 2
                statusFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
                switch info.state {
                case .running:
                    statusColor = UIColor.systemGreen
                case .ready:
                    statusColor = UIColor.white
                case .stalled:
                    statusColor = UIColor.systemOrange
                }
            } else if let fluidProducer = gameLoop.world.get(FluidProducerComponent.self, for: entity),
                      fluidProducer.buildingId != "boiler" {
                let info = getFluidProducerStatusInfo(entity: entity, gameLoop: gameLoop)
                statusText = info.detail.isEmpty ? info.title : "\(info.title)\n\(info.detail)"
                statusLines = 2
                statusFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
                switch info.state {
                case .running:
                    statusColor = UIColor.systemGreen
                case .ready:
                    statusColor = UIColor.white
                case .stalled:
                    statusColor = UIColor.systemOrange
                }
            } else {
                statusText = "Ready"
            }

            // Set the status label and return early
            progressStatusLabel?.numberOfLines = statusLines
            progressStatusLabel?.font = statusFont
            progressStatusLabel?.textColor = statusColor
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

            if isPumpjack {
                let info = getFluidProducerStatusInfo(entity: entity, gameLoop: gameLoop)
                statusText = info.detail.isEmpty ? info.title : "\(info.title) • \(info.detail)"
                switch info.state {
                case .running:
                    statusColor = UIColor.systemGreen
                case .ready:
                    statusColor = UIColor.white
                case .stalled:
                    statusColor = UIColor.systemOrange
                }
            } else if progress > 0 {
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
        progressStatusLabel?.numberOfLines = statusLines
        progressStatusLabel?.font = statusFont
        progressStatusLabel?.textColor = statusColor
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

    private enum ProducerStatusState {
        case running
        case ready
        case stalled
    }

    private func getFluidProducerStatusInfo(entity: Entity, gameLoop: GameLoop) -> (title: String, detail: String, state: ProducerStatusState) {
        guard let producer = gameLoop.world.get(FluidProducerComponent.self, for: entity) else {
            return ("Inactive", "No Producer", .stalled)
        }

        let isActive = producer.isActive
        let powerSatisfaction = gameLoop.world.get(PowerConsumerComponent.self, for: entity)?.satisfaction ?? 1.0
        let hasPower = producer.powerConsumption == 0 || powerSatisfaction > 0.5

        var blockers: [String] = []

        if !hasPower {
            blockers.append("No Power")
        }

        if producer.buildingId == "water-pump" {
            let onWater = isAnyOccupiedTile(entity: entity, gameLoop: gameLoop) { tilePos in
                gameLoop.chunkManager.getTile(at: tilePos)?.type == .water
            }
            if !onWater {
                blockers.append("No Water Tile")
            }
        } else if producer.buildingId == "pumpjack" {
            let onOil = isAnyOccupiedTile(entity: entity, gameLoop: gameLoop) { tilePos in
                gameLoop.chunkManager.getResource(at: tilePos)?.type == .oil
            }
            if !onOil {
                blockers.append("No Oil")
            }
        }

        let hasConnections = !producer.connections.isEmpty
        if !hasConnections {
            blockers.append("No Pipe Connection")
        } else if !hasFluidOutputCapacity(producer: producer, gameLoop: gameLoop) {
            let detail = outputBlockDetail(producer: producer, gameLoop: gameLoop)
            blockers.append(detail.isEmpty ? "Output Blocked" : "Output Blocked: \(detail)")
        }

        if blockers.isEmpty {
            let title = isActive ? "Running" : "Ready"
            return (title, "Output OK", isActive ? .running : .ready)
        }

        return ("Stalled", blockers.joined(separator: " • "), .stalled)
    }

    private func hasFluidOutputCapacity(producer: FluidProducerComponent, gameLoop: GameLoop) -> Bool {
        for connectedEntity in producer.connections {
            if let pipe = gameLoop.world.get(PipeComponent.self, for: connectedEntity) {
                if pipe.fluidAmount < pipe.maxCapacity &&
                    (pipe.fluidType == nil || pipe.fluidType == producer.outputType) {
                    return true
                }
            } else if let tank = gameLoop.world.get(FluidTankComponent.self, for: connectedEntity) {
                let totalCapacity = tank.maxCapacity
                let currentAmount = tank.tanks.reduce(0) { $0 + $1.amount }
                if currentAmount < totalCapacity {
                    return true
                }
            }
        }
        return false
    }

    private func outputBlockDetail(producer: FluidProducerComponent, gameLoop: GameLoop) -> String {
        var pipeFullCount = 0
        var pipeMismatchCount = 0
        var tankFullCount = 0
        var pipeCount = 0
        var tankCount = 0
        var otherCount = 0

        for connectedEntity in producer.connections {
            if let pipe = gameLoop.world.get(PipeComponent.self, for: connectedEntity) {
                pipeCount += 1
                if pipe.fluidAmount >= pipe.maxCapacity {
                    pipeFullCount += 1
                } else if pipe.fluidType != nil && pipe.fluidType != producer.outputType {
                    pipeMismatchCount += 1
                }
            } else if let tank = gameLoop.world.get(FluidTankComponent.self, for: connectedEntity) {
                tankCount += 1
                let totalCapacity = tank.maxCapacity
                let currentAmount = tank.tanks.reduce(0) { $0 + $1.amount }
                if currentAmount >= totalCapacity {
                    tankFullCount += 1
                }
            } else {
                otherCount += 1
            }
        }

        var parts: [String] = []
        if pipeCount > 0 {
            if pipeFullCount == pipeCount {
                parts.append("Pipes Full")
            } else if pipeMismatchCount == pipeCount {
                parts.append("Wrong Fluid In Pipes")
            } else if pipeFullCount + pipeMismatchCount > 0 {
                parts.append("Some Pipes Blocked")
            }
        }
        if tankCount > 0 && tankFullCount == tankCount {
            parts.append("Tanks Full")
        }
        if pipeCount == 0 && tankCount == 0 && otherCount > 0 {
            parts.append("No Storage Connected")
        }

        return parts.joined(separator: " • ")
    }

    private func isAnyOccupiedTile(entity: Entity, gameLoop: GameLoop, predicate: (IntVector2) -> Bool) -> Bool {
        guard let pos = gameLoop.world.get(PositionComponent.self, for: entity)?.tilePosition else {
            return false
        }
        let size = getEntitySize(entity: entity, gameLoop: gameLoop)
        for x in 0..<size.width {
            for y in 0..<size.height {
                let tilePos = pos + IntVector2(x: Int32(x), y: Int32(y))
                if predicate(tilePos) {
                    return true
                }
            }
        }
        return false
    }

    private func getEntitySize(entity: Entity, gameLoop: GameLoop) -> (width: Int, height: Int) {
        var buildingId: String?

        if let producer = gameLoop.world.get(FluidProducerComponent.self, for: entity) {
            buildingId = producer.buildingId
        } else if let pumpjack = gameLoop.world.get(PumpjackComponent.self, for: entity) {
            buildingId = pumpjack.buildingId
        } else if let consumer = gameLoop.world.get(FluidConsumerComponent.self, for: entity) {
            buildingId = consumer.buildingId
        } else if let tank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
            buildingId = tank.buildingId
        }

        if let buildingId = buildingId, let def = gameLoop.buildingRegistry.get(buildingId) {
            return (def.width, def.height)
        }

        return (1, 1)
    }
}

// UIColor extension for hex color support
extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
