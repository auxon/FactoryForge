import Metal
import Foundation

/// System that manages 3D models for entities and handles rendering
@available(iOS 17.0, *)
final class ModelRenderer3D {
    private let device: MTLDevice
    private let modelGenerator: Model3DGenerator
    private let renderer: Metal3DRenderer
    private weak var world: World?

    // Cache of models by entity
    private var entityModels: [Entity: Model3D] = [:]
    private var modelTransforms: [Entity: Transform3D] = [:]

    init(device: MTLDevice, renderer: Metal3DRenderer, world: World) {
        self.device = device
        self.renderer = renderer
        self.world = world
        self.modelGenerator = Model3DGenerator(device: device)
    }

    /// Updates 3D models for all entities that need them
    func updateModels() {
        guard let world = world else { return }

        // Clear previous frame's models
        entityModels.removeAll()
        modelTransforms.removeAll()

        // Create/update models for entities with position and sprite components
        for entity in world.entities {
            if let position = world.get(PositionComponent.self, for: entity),
               let sprite = world.get(SpriteComponent.self, for: entity) {

                // Determine model type based on entity components
                let model = createModelForEntity(entity, sprite: sprite)
                let transform = createTransformForEntity(entity, position: position)

                entityModels[entity] = model
                modelTransforms[entity] = transform

                // Queue for rendering
                renderer.queueModel(RenderableModel3D(model: model, transform: transform))
            }
        }
    }

    private func createModelForEntity(_ entity: Entity, sprite: SpriteComponent) -> Model3D {
        guard let world = world else { return Model3D() }

        // Determine model type based on entity type
        if world.has(UnitComponent.self, for: entity) {
            // Unit entity
            if let unit = world.get(UnitComponent.self, for: entity) {
                return modelGenerator.createUnitModel(type: unit.type)
            }
        } else if world.has(TurretComponent.self, for: entity) {
            // Turret
            return modelGenerator.createBuildingModel(type: .turret, width: 1, height: 1, maxHealth: 100)
        } else if world.has(FurnaceComponent.self, for: entity) {
            // Furnace
            return modelGenerator.createBuildingModel(type: .furnace, width: 2, height: 2, maxHealth: 200)
        } else if world.has(AssemblerComponent.self, for: entity) {
            // Assembler
            return modelGenerator.createBuildingModel(type: .assembler, width: 3, height: 3, maxHealth: 300)
        } else if world.has(MinerComponent.self, for: entity) {
            // Mining drill
            return modelGenerator.createBuildingModel(type: .miner, width: 2, height: 2, maxHealth: 150)
        } else if world.has(ChestComponent.self, for: entity) {
            // Chest/storage
            return modelGenerator.createBuildingModel(type: .chest, width: 1, height: 1, maxHealth: 100)
        } else if world.has(InserterComponent.self, for: entity) {
            // Inserter
            return modelGenerator.createBuildingModel(type: .inserter, width: 1, height: 1, maxHealth: 40)
        } else if world.has(BeltComponent.self, for: entity) {
            // Conveyor belt
            return modelGenerator.createBuildingModel(type: .belt, width: 1, height: 1, maxHealth: 50)
        } else if world.has(PipeComponent.self, for: entity) {
            // Pipe
            return modelGenerator.createBuildingModel(type: .pipe, width: 1, height: 1, maxHealth: 50)
        } else if world.has(GeneratorComponent.self, for: entity) {
            // Power generator
            return modelGenerator.createBuildingModel(type: .generator, width: 2, height: 2, maxHealth: 200)
        } else if world.has(LabComponent.self, for: entity) {
            // Research lab
            return modelGenerator.createBuildingModel(type: .lab, width: 3, height: 3, maxHealth: 300)
        } else if world.has(SolarPanelComponent.self, for: entity) {
            // Solar panel
            return modelGenerator.createBuildingModel(type: .solarPanel, width: 3, height: 3, maxHealth: 200)
        } else if world.has(AccumulatorComponent.self, for: entity) {
            // Battery
            return modelGenerator.createBuildingModel(type: .accumulator, width: 2, height: 2, maxHealth: 150)
        } else if world.has(WallComponent.self, for: entity) {
            // Wall
            return modelGenerator.createBuildingModel(type: .wall, width: 1, height: 1, maxHealth: 200)
        } else if world.has(UnitProductionComponent.self, for: entity) {
            // Unit production building
            return modelGenerator.createBuildingModel(type: .unitProduction, width: 4, height: 3, maxHealth: 400)
        } else if world.has(RocketSiloComponent.self, for: entity) {
            // Rocket silo
            return modelGenerator.createBuildingModel(type: .rocketSilo, width: 9, height: 9, maxHealth: 5000)
        }

        // Fallback: simple cube model
        return Model3D()
    }

    private func createTransformForEntity(_ entity: Entity, position: PositionComponent) -> Transform3D {
        guard let world = world else { return Transform3D() }

        var transform = Transform3D()

        // Position
        transform.position = position.worldPosition3D

        // Rotation based on direction
        switch position.direction {
        case .north:
            transform.rotation.y = 0
        case .east:
            transform.rotation.y = -.pi / 2
        case .south:
            transform.rotation.y = .pi
        case .west:
            transform.rotation.y = .pi / 2
        }

        // Scale based on building size (if applicable)
        if let sprite = world.get(SpriteComponent.self, for: entity) {
            transform.scale = Vector3(sprite.size.x, sprite.size.y, sprite.size.x)
        } else {
            transform.scale = Vector3(1, 1, 1)
        }

        // Adjust for units (they should be above ground)
        if world.has(UnitComponent.self, for: entity) {
            transform.position.y += 0.5 // Units float slightly above ground
        }

        return transform
    }

    /// Gets the model for a specific entity
    func getModel(for entity: Entity) -> Model3D? {
        return entityModels[entity]
    }

    /// Gets the transform for a specific entity
    func getTransform(for entity: Entity) -> Transform3D? {
        return modelTransforms[entity]
    }

    /// Updates a specific entity's model (called when entity changes)
    func updateEntityModel(_ entity: Entity) {
        guard let world = world,
              let position = world.get(PositionComponent.self, for: entity),
              let sprite = world.get(SpriteComponent.self, for: entity) else {
            return
        }

        let model = createModelForEntity(entity, sprite: sprite)
        let transform = createTransformForEntity(entity, position: position)

        entityModels[entity] = model
        modelTransforms[entity] = transform
    }

    /// Removes an entity's model (when entity is destroyed)
    func removeEntityModel(_ entity: Entity) {
        entityModels.removeValue(forKey: entity)
        modelTransforms.removeValue(forKey: entity)
    }
}

/// Wrapper that makes a Model3D renderable by the Metal3DRenderer
@available(iOS 17.0, *)
struct RenderableModel3D: RenderModel {
    let model: Model3D
    let transform: Transform3D

    func render(renderEncoder: MTLRenderCommandEncoder, textureAtlas: TextureAtlas) {
        // Update the model's transform
        model.transform = transform
        model.render(renderEncoder: renderEncoder, textureAtlas: textureAtlas)
    }
}