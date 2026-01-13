import Foundation

/// Definition of a crafting recipe
struct Recipe: Identifiable, Codable {
    let id: String
    let name: String
    let inputs: [ItemStack]
    let outputs: [ItemStack]
    let fluidInputs: [FluidStack]
    let fluidOutputs: [FluidStack]
    let craftTime: Float
    let category: CraftingCategory
    let enabled: Bool
    let order: String

    init(
        id: String,
        name: String,
        inputs: [ItemStack] = [],
        outputs: [ItemStack] = [],
        fluidInputs: [FluidStack] = [],
        fluidOutputs: [FluidStack] = [],
        craftTime: Float = 0.5,
        category: CraftingCategory = .crafting,
        enabled: Bool = true,
        order: String = "a"
    ) {
        self.id = id
        self.name = name
        self.inputs = inputs
        self.outputs = outputs
        self.fluidInputs = fluidInputs
        self.fluidOutputs = fluidOutputs
        self.craftTime = craftTime
        self.category = category
        self.enabled = enabled
        self.order = order
    }
    
    /// Primary output item
    var primaryOutput: ItemStack? {
        return outputs.first
    }
    
    /// Gets the texture ID for display
    var textureId: String {
        return primaryOutput?.itemId.replacingOccurrences(of: "-", with: "_") ?? "solid_white"
    }
    
    /// Checks if inputs can be fulfilled by an inventory and fluid tanks
    func canCraft(with inventory: InventoryComponent, fluidTanks: [FluidStack] = []) -> Bool {
        // Check item inputs
        if !inventory.has(items: inputs) {
            return false
        }

        // Check fluid inputs
        for fluidInput in fluidInputs {
            var foundFluid = false
            for tank in fluidTanks {
                if tank.type == fluidInput.type && tank.amount >= fluidInput.amount {
                    foundFluid = true
                    break
                }
            }
            if !foundFluid {
                return false
            }
        }

        return true
    }
    
    /// Items per second output (at 1x crafting speed)
    var outputRate: Float {
        guard let output = primaryOutput else { return 0 }
        return Float(output.count) / craftTime
    }
}

/// Categories of crafting
enum CraftingCategory: String, Codable, CaseIterable {
    case crafting = "crafting"
    case advancedCrafting = "advanced-crafting"
    case smelting = "smelting"
    case chemistry = "chemistry"
    case oilProcessing = "oil-processing"
    case centrifuging = "centrifuging"
    case rocketBuilding = "rocket-building"
    
    var displayName: String {
        switch self {
        case .crafting: return "Crafting"
        case .advancedCrafting: return "Advanced Crafting"
        case .smelting: return "Smelting"
        case .chemistry: return "Chemistry"
        case .oilProcessing: return "Oil Processing"
        case .centrifuging: return "Centrifuging"
        case .rocketBuilding: return "Rocket Building"
        }
    }
    
    /// Buildings that can execute this category
    var allowedBuildings: [String] {
        switch self {
        case .crafting:
            return ["player", "assembling-machine-1", "assembling-machine-2", "assembling-machine-3"]
        case .advancedCrafting:
            return ["assembling-machine-2", "assembling-machine-3"]
        case .smelting:
            return ["stone-furnace", "steel-furnace", "electric-furnace"]
        case .chemistry:
            return ["chemical-plant"]
        case .oilProcessing:
            return ["oil-refinery"]
        case .centrifuging:
            return ["centrifuge"]
        case .rocketBuilding:
            return ["rocket-silo"]
        }
    }
}

