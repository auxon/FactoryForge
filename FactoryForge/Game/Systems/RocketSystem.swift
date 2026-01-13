import Foundation

/// System that manages rocket launching and space science pack generation
final class RocketSystem: System {
    private let world: World
    private let itemRegistry: ItemRegistry

    init(world: World, itemRegistry: ItemRegistry) {
        self.world = world
        self.itemRegistry = itemRegistry
    }

    func update(deltaTime: Float) {
        // Update rocket silos
        updateRocketSilos(deltaTime: deltaTime)

        // Update flying rockets
        updateFlyingRockets(deltaTime: deltaTime)
    }

    private func updateRocketSilos(deltaTime: Float) {
        for entity in world.entities {
            guard let silo = world.get(RocketSiloComponent.self, for: entity),
                  let position = world.get(PositionComponent.self, for: entity),
                  let inventory = world.get(InventoryComponent.self, for: entity) else {
                continue
            }

            // Check if rocket can be assembled
            if !silo.rocketAssembled && canAssembleRocket(inventory: inventory) {
                silo.rocketAssembled = true
                print("Rocket assembled in silo at (\(position.tilePosition.x), \(position.tilePosition.y))")
            }

            // Handle launch sequence
            if silo.isLaunching {
                silo.launchTimer += deltaTime
                silo.launchProgress = min(silo.launchTimer / silo.launchDuration, 1.0)

                if silo.launchTimer >= silo.launchDuration {
                    // Launch complete!
                    launchRocket(from: entity, silo: silo)
                    silo.isLaunching = false
                    silo.launchProgress = 0.0
                    silo.launchTimer = 0.0
                    silo.rocketAssembled = false
                }
            }

            world.add(silo, to: entity)
        }
    }

    private func updateFlyingRockets(deltaTime: Float) {
        var rocketsToRemove: [Entity] = []

        for entity in world.entities {
            guard var rocket = world.get(RocketComponent.self, for: entity),
                  var position = world.get(PositionComponent.self, for: entity) else {
                continue
            }

            // Update rocket physics
            rocket.velocity += rocket.acceleration * deltaTime
            rocket.altitude += rocket.velocity * deltaTime
            rocket.flightProgress = min(rocket.altitude / rocket.maxAltitude, 1.0)

            // Update visual position (rocket flies upward)
            position.offset.y -= rocket.velocity * deltaTime * 10 // Scale for visibility

            if rocket.flightProgress >= 1.0 {
                // Rocket reached space! Generate space science packs
                generateSpaceSciencePacks(from: rocket)
                rocketsToRemove.append(entity)
                print("Rocket reached space! Space science packs generated.")
            }

            world.add(rocket, to: entity)
            world.add(position, to: entity)
        }

        // Remove completed rockets
        for entity in rocketsToRemove {
            world.despawn(entity)
        }
    }

    private func canAssembleRocket(inventory: InventoryComponent) -> Bool {
        // Check for required rocket components
        let requiredParts = 100
        let requiredFuel = 50

        let partsCount = inventory.count(of: "rocket-parts")
        let fuelCount = inventory.count(of: "rocket-fuel")
        let satelliteCount = inventory.count(of: "satellite")

        return partsCount >= requiredParts &&
               fuelCount >= requiredFuel &&
               satelliteCount >= 1
    }

    private func launchRocket(from siloEntity: Entity, silo: RocketSiloComponent) {
        guard var inventory = world.get(InventoryComponent.self, for: siloEntity) else { return }

        // Consume rocket materials
        let requiredParts = 100
        let requiredFuel = 50

        _ = inventory.remove(itemId: "rocket-parts", count: requiredParts)
        _ = inventory.remove(itemId: "rocket-fuel", count: requiredFuel)
        _ = inventory.remove(itemId: "satellite", count: 1)

        world.add(inventory, to: siloEntity)

        // Create flying rocket entity
        let rocketEntity = world.spawn()

        // Add rocket component
        let rocket = RocketComponent(hasSatellite: true)
        world.add(rocket, to: rocketEntity)

        // Add position component (start at silo position)
        if let siloPosition = world.get(PositionComponent.self, for: siloEntity) {
            let rocketPosition = siloPosition
            world.add(rocketPosition, to: rocketEntity)
        }

        // Add sprite component for visual rocket
        let rocketSprite = SpriteComponent(textureId: "rocket", size: Vector2(1, 2))
        world.add(rocketSprite, to: rocketEntity)

        print("🚀 Rocket launched from silo!")
    }

    private func generateSpaceSciencePacks(from rocket: RocketComponent) {
        // Find a nearby lab or silo to deposit the packs
        // For now, we'll create a simple space science pack generation

        let packsToGenerate = 1000

        // Try to find a rocket silo nearby to deposit packs
        for entity in world.entities {
            if let siloPos = world.get(PositionComponent.self, for: entity),
               var inventory = world.get(InventoryComponent.self, for: entity),
               world.get(RocketSiloComponent.self, for: entity) != nil {

                // Add space science packs to the silo inventory
                if let itemDef = itemRegistry.get("space-science-pack") {
                    inventory.add(itemId: "space-science-pack", count: packsToGenerate, maxStack: itemDef.stackSize)
                }
                world.add(inventory, to: entity)
                print("📦 \(packsToGenerate) space science packs added to rocket silo inventory, at silo at (\(siloPos.tilePosition.x), \(siloPos.tilePosition.y))")
                return
            }
        }

        // Fallback: create packs at origin if no silo found
        print("⚠️ No rocket silo found to deposit space science packs")
    }

    /// Attempts to launch a rocket from the specified silo
    func launchRocketFromSilo(_ siloEntity: Entity) -> Bool {
        guard let silo = world.get(RocketSiloComponent.self, for: siloEntity),
              let _ = world.get(InventoryComponent.self, for: siloEntity) else {
            return false
        }

        // Check if rocket is assembled and not already launching
        if !silo.rocketAssembled || silo.isLaunching {
            return false
        }

        // Start launch sequence
        silo.isLaunching = true
        silo.launchTimer = 0.0
        world.add(silo, to: siloEntity)

        print("🚀 Initiating rocket launch sequence...")
        return true
    }
}
