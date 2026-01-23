import Foundation

/// AI economy: mining/production build order, resource prioritization, inventory.
/// Stub; extend with production-chain logic.
final class AIEconomyManager {
    func recommendBuild(near position: Vector2, inventory: InventoryComponent, buildingRegistry: BuildingRegistry) -> (buildingId: String, position: IntVector2, direction: Direction)? {
        let tile = IntVector2(from: position)
        if let def = buildingRegistry.get("burner-mining-drill"), inventory.has(items: def.cost) {
            return ("burner-mining-drill", IntVector2(x: tile.x + 2, y: tile.y), .north)
        }
        if let def = buildingRegistry.get("stone-furnace"), inventory.has(items: def.cost) {
            return ("stone-furnace", IntVector2(x: tile.x + 3, y: tile.y), .north)
        }
        return nil
    }
}
