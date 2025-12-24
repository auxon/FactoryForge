import Foundation

/// Definition of an item type
struct Item: Identifiable, Codable {
    let id: String
    let name: String
    let stackSize: Int
    let category: ItemCategory
    let subgroup: String
    let order: String
    let fuelValue: Float?
    let fuelCategory: String?
    let placedAs: String?  // Building ID if this item places a building
    
    init(
        id: String,
        name: String,
        stackSize: Int = 100,
        category: ItemCategory = .intermediate,
        subgroup: String = "other",
        order: String = "a",
        fuelValue: Float? = nil,
        fuelCategory: String? = nil,
        placedAs: String? = nil
    ) {
        self.id = id
        self.name = name
        self.stackSize = stackSize
        self.category = category
        self.subgroup = subgroup
        self.order = order
        self.fuelValue = fuelValue
        self.fuelCategory = fuelCategory
        self.placedAs = placedAs
    }
    
    var isFuel: Bool {
        return fuelValue != nil && fuelValue! > 0
    }
    
    var isBuilding: Bool {
        return placedAs != nil
    }
    
    var textureId: String {
        return id.replacingOccurrences(of: "-", with: "_")
    }
}

/// Categories of items
enum ItemCategory: String, Codable, CaseIterable {
    case raw = "raw"
    case intermediate = "intermediate"
    case production = "production"
    case logistics = "logistics"
    case combat = "combat"
    case science = "science"
    case fluid = "fluid"
    case ammo = "ammo"
}

/// Fuel types
enum FuelCategory: String, Codable {
    case chemical = "chemical"
    case nuclear = "nuclear"
}

