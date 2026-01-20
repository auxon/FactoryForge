import Foundation

/// JSON configuration for building definitions
struct BuildingConfig: Codable {
    let id: String
    let name: String
    let type: String
    let width: Int?
    let height: Int?
    let maxHealth: Float
    let cost: [ItemCost]
    let textureId: String?

    // Building-specific properties
    let miningSpeed: Float?
    let powerConsumption: Float?
    let powerProduction: Float?
    let craftingSpeed: Float?
    let craftingCategory: String?
    let beltSpeed: Float?
    let inserterSpeed: Float?
    let inserterStackSize: Int?
    let wireReach: Float?
    let supplyArea: Float?
    let fuelCategory: String?
    let accumulatorCapacity: Float?
    let accumulatorChargeRate: Float?
    let researchSpeed: Float?
    let turretRange: Float?
    let turretDamage: Float?
    let turretFireRate: Float?
    let inventorySlots: Int?
    let fluidCapacity: Float?
    let fluidInputType: String?
    let fluidOutputType: String?
    let extractionRate: Float?
    let inputSlots: Int?
    let outputSlots: Int?
    let fuelSlots: Int?

    struct ItemCost: Codable {
        let itemId: String
        let count: Int
    }
}

/// Registry of all building definitions
final class BuildingRegistry {
    private var buildings: [String: BuildingDefinition] = [:]
    private var configDirectory: URL?
    
    /// Gets a building by ID
    func get(_ id: String) -> BuildingDefinition? {
        return buildings[id]
    }
    
    /// Gets a building by texture ID
    func getByTexture(_ textureId: String) -> BuildingDefinition? {
        return buildings.values.first { $0.textureId == textureId }
    }
    
    /// Gets all buildings
    var all: [BuildingDefinition] {
        return Array(buildings.values)
    }
    
    /// Gets buildings by type
    func buildings(ofType type: BuildingType) -> [BuildingDefinition] {
        return buildings.values.filter { $0.type == type }
    }
    
    /// Registers a building
    func register(_ building: BuildingDefinition) {
        buildings[building.id] = building
    }
    
    /// Loads building definitions from JSON files
    func loadBuildings() {
        // Set up config directory
        setupConfigDirectory()

        // Load bundled configurations first
        copyBundledConfigurationsIfNeeded()

        // Load all JSON configurations
        loadAllConfigurations()

        print("BuildingRegistry: Loaded \(buildings.count) building definitions")
    }

    /// Set up the configuration directory
    private func setupConfigDirectory() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if let documentsDir = paths.first {
            configDirectory = documentsDir.appendingPathComponent("building_configs")
            try? FileManager.default.createDirectory(at: configDirectory!, withIntermediateDirectories: true)
        }
    }

    /// Copy bundled configuration files to Documents directory if they don't exist
    private func copyBundledConfigurationsIfNeeded() {
        guard let configDir = configDirectory else { return }

        // List of building categories to load
        let categories = ["miners", "furnaces", "assemblers", "belts", "inserters", "power", "combat", "storage", "fluids", "nuclear", "rockets", "units"]

        for category in categories {
            if let bundledPath = Bundle.main.path(forResource: category, ofType: "json", inDirectory: "building_configs") {
                let destURL = configDir.appendingPathComponent("\(category).json")

                // Copy if file doesn't exist
                if !FileManager.default.fileExists(atPath: destURL.path) {
                    do {
                        try FileManager.default.copyItem(atPath: bundledPath, toPath: destURL.path)
                        print("BuildingRegistry: Copied bundled config: \(category)")
                    } catch {
                        print("BuildingRegistry: Error copying bundled config \(category): \(error)")
                    }
                }
            } else {
                print("BuildingRegistry: Could not find bundled config for \(category)")
            }
        }
    }

    /// Load all JSON configuration files
    private func loadAllConfigurations() {
        // First try to load embedded JSON data
        loadEmbeddedConfigurations()

        // Then try to load from files (for runtime updates)
        guard let configDir = configDirectory else { return }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: configDir, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == "json" }

            for fileURL in jsonFiles {
                if let configs = loadConfiguration(from: fileURL) {
                    for config in configs {
                        if let building = createBuildingDefinition(from: config) {
                            register(building)
                        }
                    }
                }
            }
        } catch {
            print("BuildingRegistry: Error loading configurations from files: \(error)")
        }

        // If no buildings were loaded, definitely load fallbacks
        if buildings.isEmpty {
            print("BuildingRegistry: No buildings loaded, using fallback")
            loadFallbackBuildings()
        }
    }

    /// Load embedded JSON configurations (fallback data)
    private func loadEmbeddedConfigurations() {
        // Load embedded JSON strings and parse them
        let embeddedConfigs = getEmbeddedBuildingConfigs()

        for jsonString in embeddedConfigs {
            if let data = jsonString.data(using: .utf8) {
                do {
                    let configs = try JSONDecoder().decode([BuildingConfig].self, from: data)
                    for config in configs {
                        if let building = createBuildingDefinition(from: config) {
                            register(building)
                        }
                    }
                } catch {
                    print("BuildingRegistry: Error parsing embedded config: \(error)")
                }
            }
        }
    }

    /// Get embedded building configurations as JSON strings
    private func getEmbeddedBuildingConfigs() -> [String] {
        // This will contain the JSON strings for all building categories
        return [
            getMinersConfig(),
            getFurnacesConfig(),
            getAssemblersConfig(),
            getBeltsConfig(),
            getInsertersConfig(),
            getPowerConfig(),
            getCombatConfig(),
            getStorageConfig(),
            getFluidsConfig(),
            getNuclearConfig(),
            getRocketsConfig(),
            getUnitsConfig()
        ]
    }

    /// Load a single configuration file
    private func loadConfiguration(from url: URL) -> [BuildingConfig]? {
        do {
            let data = try Data(contentsOf: url)
            let configs = try JSONDecoder().decode([BuildingConfig].self, from: data)
            return configs
        } catch {
            print("BuildingRegistry: Error loading config from \(url): \(error)")
            return nil
        }
    }

    /// Create a BuildingDefinition from JSON config
    private func createBuildingDefinition(from config: BuildingConfig) -> BuildingDefinition? {
        // Convert string type to BuildingType enum
        let buildingType: BuildingType
        switch config.type {
        case "miner": buildingType = .miner
        case "furnace": buildingType = .furnace
        case "assembler": buildingType = .assembler
        case "belt": buildingType = .belt
        case "inserter": buildingType = .inserter
        case "powerPole": buildingType = .powerPole
        case "generator": buildingType = .generator
        case "boiler": buildingType = .boiler
        case "steamEngine": buildingType = .steamEngine
        case "solarPanel": buildingType = .solarPanel
        case "accumulator": buildingType = .accumulator
        case "lab": buildingType = .lab
        case "turret": buildingType = .turret
        case "wall": buildingType = .wall
        case "chest": buildingType = .chest
        case "pumpjack": buildingType = .pumpjack
        case "waterPump": buildingType = .waterPump
        case "oilRefinery": buildingType = .oilRefinery
        case "chemicalPlant": buildingType = .chemicalPlant
        case "nuclearReactor": buildingType = .nuclearReactor
        case "centrifuge": buildingType = .centrifuge
        case "rocketSilo": buildingType = .rocketSilo
        case "pipe": buildingType = .pipe
        case "fluidTank": buildingType = .fluidTank
        case "unitProduction": buildingType = .unitProduction
        default:
            print("BuildingRegistry: Unknown building type: \(config.type)")
            return nil
        }

        // Convert cost array
        let cost = config.cost.map { ItemStack(itemId: $0.itemId, count: $0.count) }

        // Create basic building definition
        var building = BuildingDefinition(
            id: config.id,
            name: config.name,
            type: buildingType,
            width: config.width ?? 1,
            height: config.height ?? 1,
            maxHealth: config.maxHealth,
            textureId: config.textureId,
            cost: cost
        )

        // Set building-specific properties
        if let miningSpeed = config.miningSpeed {
            building.miningSpeed = miningSpeed
        }
        if let powerConsumption = config.powerConsumption {
            building.powerConsumption = powerConsumption
        }
        if let powerProduction = config.powerProduction {
            building.powerProduction = powerProduction
        }
        if let craftingSpeed = config.craftingSpeed {
            building.craftingSpeed = craftingSpeed
        }
        if let craftingCategory = config.craftingCategory {
            building.craftingCategory = craftingCategory
        }
        if let beltSpeed = config.beltSpeed {
            building.beltSpeed = beltSpeed
        }
        if let inserterSpeed = config.inserterSpeed {
            building.inserterSpeed = inserterSpeed
        }
        if let inserterStackSize = config.inserterStackSize {
            building.inserterStackSize = inserterStackSize
        }
        if let wireReach = config.wireReach {
            building.wireReach = wireReach
        }
        if let supplyArea = config.supplyArea {
            building.supplyArea = supplyArea
        }
        if let fuelCategory = config.fuelCategory {
            building.fuelCategory = fuelCategory
        }
        if let accumulatorCapacity = config.accumulatorCapacity {
            building.accumulatorCapacity = accumulatorCapacity
        }
        if let accumulatorChargeRate = config.accumulatorChargeRate {
            building.accumulatorChargeRate = accumulatorChargeRate
        }
        if let researchSpeed = config.researchSpeed {
            building.researchSpeed = researchSpeed
        }
        if let turretRange = config.turretRange {
            building.turretRange = turretRange
        }
        if let turretDamage = config.turretDamage {
            building.turretDamage = turretDamage
        }
        if let turretFireRate = config.turretFireRate {
            building.turretFireRate = turretFireRate
        }
        if let inventorySlots = config.inventorySlots {
            building.inventorySlots = inventorySlots
        }
        if let fluidCapacity = config.fluidCapacity {
            building.fluidCapacity = fluidCapacity
        }
        if let fluidInputTypeString = config.fluidInputType,
           let fluidInputType = FluidType(rawValue: fluidInputTypeString) {
            building.fluidInputType = fluidInputType
        }
        if let fluidOutputTypeString = config.fluidOutputType,
           let fluidOutputType = FluidType(rawValue: fluidOutputTypeString) {
            building.fluidOutputType = fluidOutputType
        }
        if let extractionRate = config.extractionRate {
            building.extractionRate = extractionRate
        }
        if let inputSlots = config.inputSlots {
            building.inputSlots = inputSlots
        }
        if let outputSlots = config.outputSlots {
            building.outputSlots = outputSlots
        }
        if let fuelSlots = config.fuelSlots {
            building.fuelSlots = fuelSlots
        }

        return building
    }

    /// Fallback method for minimal hardcoded buildings if JSON loading fails
    private func loadFallbackBuildings() {
        print("BuildingRegistry: Loading fallback buildings")

        // Just load a few essential buildings as fallback
        var burnerMiner = BuildingDefinition(
            id: "burner-mining-drill",
            name: "Burner Mining Drill",
            type: .miner,
            width: 2,
            height: 2,
            maxHealth: 150,
            cost: [ItemStack(itemId: "iron-plate", count: 5)]
        )
        burnerMiner.miningSpeed = 0.50
        burnerMiner.inputSlots = 0
        burnerMiner.outputSlots = 1
        burnerMiner.fuelSlots = 1
        register(burnerMiner)

        var stoneFurnace = BuildingDefinition(
            id: "stone-furnace",
            name: "Stone Furnace",
            type: .furnace,
            width: 2,
            height: 2,
            maxHealth: 200,
            cost: [ItemStack(itemId: "iron-plate", count: 5)]
        )
        stoneFurnace.craftingSpeed = 1
        stoneFurnace.craftingCategory = "smelting"
        stoneFurnace.inputSlots = 1
        stoneFurnace.outputSlots = 1
        stoneFurnace.fuelSlots = 1
        register(stoneFurnace)
    }

    /// Get configuration for a specific building
    func getBuildingConfig(for buildingId: String) -> BuildingConfig? {
        guard let building = buildings[buildingId] else { return nil }

        // Convert BuildingDefinition back to BuildingConfig
        let config = BuildingConfig(
            id: building.id,
            name: building.name,
            type: buildingTypeToString(building.type),
            width: building.width,
            height: building.height,
            maxHealth: Float(building.maxHealth),
            cost: building.cost.map { BuildingConfig.ItemCost(itemId: $0.itemId, count: $0.count) },
            textureId: building.textureId,
            miningSpeed: building.miningSpeed,
            powerConsumption: building.powerConsumption,
            powerProduction: building.powerProduction,
            craftingSpeed: building.craftingSpeed,
            craftingCategory: building.craftingCategory,
            beltSpeed: building.beltSpeed,
            inserterSpeed: building.inserterSpeed,
            inserterStackSize: building.inserterStackSize,
            wireReach: building.wireReach,
            supplyArea: building.supplyArea,
            fuelCategory: building.fuelCategory,
            accumulatorCapacity: building.accumulatorCapacity,
            accumulatorChargeRate: building.accumulatorChargeRate,
            researchSpeed: building.researchSpeed,
            turretRange: building.turretRange,
            turretDamage: building.turretDamage,
            turretFireRate: building.turretFireRate,
            inventorySlots: building.inventorySlots,
            fluidCapacity: building.fluidCapacity,
            fluidInputType: building.fluidInputType?.rawValue,
            fluidOutputType: building.fluidOutputType?.rawValue,
            extractionRate: building.extractionRate,
            inputSlots: building.inputSlots,
            outputSlots: building.outputSlots,
            fuelSlots: building.fuelSlots
        )

        return config
    }

    /// Update building configuration at runtime
    func updateBuildingConfig(_ config: BuildingConfig) -> Bool {
        guard let newBuilding = createBuildingDefinition(from: config) else { return false }

        buildings[config.id] = newBuilding

        // Save to file
        return saveBuildingConfig(config)
    }

    /// Get all building configurations
    func getAllBuildingConfigs() -> [BuildingConfig] {
        return buildings.keys.compactMap { getBuildingConfig(for: $0) }
    }

    /// Save building configuration to file
    private func saveBuildingConfig(_ config: BuildingConfig) -> Bool {
        guard let configDir = configDirectory else { return false }

        // Group by category (simple heuristic based on type)
        let category = getCategoryForBuilding(config)
        let fileURL = configDir.appendingPathComponent("\(category).json")

        // Load existing configs for this category
        var configs = loadConfiguration(from: fileURL) ?? []

        // Update or add the config
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index] = config
        } else {
            configs.append(config)
        }

        // Save back to file
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(configs)
            try data.write(to: fileURL)
            return true
        } catch {
            print("BuildingRegistry: Error saving config: \(error)")
            return false
        }
    }

    /// Get category string for a building configuration
    private func getCategoryForBuilding(_ config: BuildingConfig) -> String {
        switch config.type {
        case "miner", "pumpjack": return "miners"
        case "waterPump": return "fluids"
        case "furnace": return "furnaces"
        case "assembler": return "assemblers"
        case "belt": return "belts"
        case "inserter": return "inserters"
        case "powerPole", "generator", "boiler", "steamEngine", "solarPanel", "accumulator": return "power"
        case "turret", "wall": return "combat"
        case "chest": return "storage"
        case "oilRefinery", "chemicalPlant", "pipe", "fluidTank": return "fluids"
        case "nuclearReactor", "centrifuge": return "nuclear"
        case "rocketSilo": return "rockets"
        case "unitProduction": return "units"
        default: return "misc"
        }
    }

    /// Convert BuildingType to string
    private func buildingTypeToString(_ type: BuildingType) -> String {
        switch type {
        case .miner: return "miner"
        case .furnace: return "furnace"
        case .assembler: return "assembler"
        case .belt: return "belt"
        case .inserter: return "inserter"
        case .powerPole: return "powerPole"
        case .generator: return "generator"
        case .boiler: return "boiler"
        case .steamEngine: return "steamEngine"
        case .solarPanel: return "solarPanel"
        case .accumulator: return "accumulator"
        case .lab: return "lab"
        case .turret: return "turret"
        case .wall: return "wall"
        case .chest: return "chest"
        case .pumpjack: return "pumpjack"
        case .waterPump: return "waterPump"
        case .oilRefinery: return "oilRefinery"
        case .chemicalPlant: return "chemicalPlant"
        case .nuclearReactor: return "nuclearReactor"
        case .centrifuge: return "centrifuge"
        case .rocketSilo: return "rocketSilo"
        case .pipe: return "pipe"
        case .fluidTank: return "fluidTank"
        case .unitProduction: return "unitProduction"
        }
    }

    private func getMinersConfig() -> String {
        return """
        [
          {
            "id": "burner-mining-drill",
            "name": "Burner Mining Drill",
            "type": "miner",
            "width": 2,
            "height": 2,
            "maxHealth": 150,
            "cost": [
              {"itemId": "iron-plate", "count": 5}
            ],
            "miningSpeed": 0.5,
            "inputSlots": 0,
            "outputSlots": 1,
            "fuelSlots": 1,
            "fuelCategory": "chemical"
          },
          {
            "id": "electric-mining-drill",
            "name": "Electric Mining Drill",
            "type": "miner",
            "width": 3,
            "height": 3,
            "maxHealth": 300,
            "cost": [
              {"itemId": "electronic-circuit", "count": 3},
              {"itemId": "iron-gear-wheel", "count": 5},
              {"itemId": "iron-plate", "count": 10}
            ],
            "miningSpeed": 0.75,
            "powerConsumption": 90,
            "inputSlots": 0,
            "outputSlots": 1,
            "fuelSlots": 0
          }
        ]
        """
    }

    private func getFurnacesConfig() -> String {
        return """
        [
          {
            "id": "stone-furnace",
            "name": "Stone Furnace",
            "type": "furnace",
            "width": 2,
            "height": 2,
            "maxHealth": 200,
            "cost": [
              {"itemId": "iron-plate", "count": 5}
            ],
            "craftingSpeed": 1,
            "craftingCategory": "smelting",
            "inputSlots": 1,
            "outputSlots": 1,
            "fuelSlots": 1
          }
        ]
        """
    }

    private func getAssemblersConfig() -> String {
        return """
        [
          {
            "id": "assembling-machine-1",
            "name": "Assembling Machine 1",
            "type": "assembler",
            "width": 3,
            "height": 3,
            "maxHealth": 300,
            "cost": [
              {"itemId": "electronic-circuit", "count": 3},
              {"itemId": "iron-gear-wheel", "count": 5},
              {"itemId": "iron-plate", "count": 9}
            ],
            "craftingSpeed": 0.5,
            "craftingCategory": "crafting",
            "powerConsumption": 75,
            "inputSlots": 4,
            "outputSlots": 4,
            "fuelSlots": 0
          },
          {
            "id": "lab",
            "name": "Lab",
            "type": "lab",
            "width": 3,
            "height": 3,
            "maxHealth": 150,
            "cost": [
              {"itemId": "electronic-circuit", "count": 10},
              {"itemId": "iron-gear-wheel", "count": 10},
              {"itemId": "transport-belt", "count": 4}
            ],
            "researchSpeed": 1.0,
            "inputSlots": 2,
            "outputSlots": 0,
            "fuelSlots": 0,
            "powerConsumption": 60
          }
        ]
        """
    }

    private func getBeltsConfig() -> String {
        return """
        [
          {
            "id": "transport-belt",
            "name": "Transport Belt",
            "type": "belt",
            "maxHealth": 50,
            "cost": [
              {"itemId": "iron-gear-wheel", "count": 1},
              {"itemId": "iron-plate", "count": 1}
            ],
            "beltSpeed": 1.875
          }
        ]
        """
    }

    private func getInsertersConfig() -> String {
        return """
        [
          {
            "id": "inserter",
            "name": "Inserter",
            "type": "inserter",
            "maxHealth": 40,
            "cost": [
              {"itemId": "electronic-circuit", "count": 1},
              {"itemId": "iron-gear-wheel", "count": 1},
              {"itemId": "iron-plate", "count": 1}
            ],
            "inserterSpeed": 4.0,
            "inserterStackSize": 1,
            "powerConsumption": 13
          }
        ]
        """
    }

    private func getPowerConfig() -> String {
        return """
        [
          {
            "id": "small-electric-pole",
            "name": "Small Electric Pole",
            "type": "powerPole",
            "maxHealth": 100,
            "cost": [
              {"itemId": "wood", "count": 2},
              {"itemId": "copper-cable", "count": 2}
            ],
            "wireReach": 7.5,
            "supplyArea": 2.5
          },
          {
            "id": "solar-panel",
            "name": "Solar Panel",
            "type": "solarPanel",
            "width": 3,
            "height": 3,
            "maxHealth": 200,
            "cost": [
              {"itemId": "steel-plate", "count": 5},
              {"itemId": "electronic-circuit", "count": 15},
              {"itemId": "copper-plate", "count": 5}
            ],
            "powerProduction": 60,
            "inputSlots": 0,
            "outputSlots": 0,
            "fuelSlots": 0
          },
          {
            "id": "boiler",
            "name": "Boiler",
            "type": "boiler",
            "width": 2,
            "height": 3,
            "maxHealth": 200,
            "cost": [
              {"itemId": "iron-plate", "count": 5},
              {"itemId": "pipe", "count": 4}
            ],
            "powerConsumption": 0,
            "powerProduction": 0,
            "inputSlots": 1,
            "outputSlots": 0,
            "fuelSlots": 1,
            "fluidCapacity": 100,
            "fluidInputType": "water",
            "fluidOutputType": "steam"
          },
          {
            "id": "steam-engine",
            "name": "Steam Engine",
            "type": "steamEngine",
            "width": 3,
            "height": 5,
            "maxHealth": 400,
            "cost": [
              {"itemId": "iron-gear-wheel", "count": 8},
              {"itemId": "iron-plate", "count": 10},
              {"itemId": "pipe", "count": 5}
            ],
            "powerConsumption": 0,
            "powerProduction": 900,
            "inputSlots": 0,
            "outputSlots": 0,
            "fuelSlots": 0,
            "fluidCapacity": 200,
            "fluidInputType": "steam",
            "fluidOutputType": "water"
          }
        ]
        """
    }

    private func getCombatConfig() -> String {
        return """
        [
          {
            "id": "stone-wall",
            "name": "Wall",
            "type": "wall",
            "maxHealth": 350,
            "cost": [
              {"itemId": "stone-brick", "count": 5}
            ],
            "textureId": "wall"
          }
        ]
        """
    }

    private func getStorageConfig() -> String {
        return """
        [
          {
            "id": "wooden-chest",
            "name": "Wooden Chest",
            "type": "chest",
            "maxHealth": 100,
            "cost": [
              {"itemId": "wood", "count": 2}
            ],
            "inventorySlots": 16,
            "inputSlots": 0,
            "outputSlots": 0,
            "fuelSlots": 0
          }
        ]
        """
    }

    private func getFluidsConfig() -> String {
        return """
        [
          {
            "id": "pipe",
            "name": "Pipe",
            "type": "pipe",
            "maxHealth": 50,
            "cost": [
              {"itemId": "iron-plate", "count": 1}
            ],
            "fluidCapacity": 100
          },
          {
            "id": "offshore-pump",
            "name": "Offshore Pump",
            "type": "waterPump",
            "width": 1,
            "height": 1,
            "maxHealth": 80,
            "cost": [
              {"itemId": "electronic-circuit", "count": 2},
              {"itemId": "pipe", "count": 1},
              {"itemId": "iron-gear-wheel", "count": 1}
            ],
            "powerConsumption": 10,
            "fluidCapacity": 50,
            "fluidOutputType": "water"
          }
        ]
        """
    }

    private func getNuclearConfig() -> String {
        return """
        [
          {
            "id": "nuclear-reactor",
            "name": "Nuclear Reactor",
            "type": "nuclearReactor",
            "width": 5,
            "height": 5,
            "maxHealth": 500,
            "cost": [
              {"itemId": "steel-plate", "count": 400},
              {"itemId": "advanced-circuit", "count": 400},
              {"itemId": "copper-plate", "count": 400},
              {"itemId": "stone-brick", "count": 400}
            ],
            "powerProduction": 40000,
            "inputSlots": 0,
            "outputSlots": 0,
            "fuelSlots": 1
          }
        ]
        """
    }

    private func getRocketsConfig() -> String {
        return """
        [
          {
            "id": "rocket-silo",
            "name": "Rocket Silo",
            "type": "rocketSilo",
            "width": 9,
            "height": 9,
            "maxHealth": 5000,
            "cost": [
              {"itemId": "steel-plate", "count": 1000},
              {"itemId": "stone-brick", "count": 1000},
              {"itemId": "pipe", "count": 100},
              {"itemId": "processing-unit", "count": 200}
            ],
            "powerConsumption": 1000,
            "inventorySlots": 5,
            "inputSlots": 4,
            "outputSlots": 0,
            "fuelSlots": 1
          }
        ]
        """
    }

    private func getUnitsConfig() -> String {
        return """
        [
          {
            "id": "military-barracks",
            "name": "Military Barracks",
            "type": "unitProduction",
            "width": 4,
            "height": 3,
            "maxHealth": 300,
            "cost": [
              {"itemId": "iron-plate", "count": 20},
              {"itemId": "stone-brick", "count": 10},
              {"itemId": "electronic-circuit", "count": 5}
            ],
            "powerConsumption": 50,
            "inventorySlots": 10,
            "inputSlots": 0,
            "outputSlots": 10,
            "fuelSlots": 0
          }
        ]
        """
    }
}
