import Metal
import Foundation

/// Procedural 3D model generation system for FactoryForge
/// Creates simple geometric shapes that can be replaced with proper 3D models later
@available(iOS 17.0, *)
final class Model3DGenerator {
    private let device: MTLDevice

    init(device: MTLDevice) {
        self.device = device
    }

    // MARK: - Building Models

    func createBuildingModel(type: BuildingType, width: Int, height: Int, maxHealth: Float) -> Model3D {
        switch type {
        case .miner:
            return createMinerModel()
        case .furnace:
            return createFurnaceModel()
        case .assembler:
            return createAssemblerModel()
        case .belt:
            return createBeltModel()
        case .inserter:
            return createInserterModel()
        case .powerPole:
            return createPowerPoleModel()
        case .generator:
            return createGeneratorModel()
        case .boiler:
            return createFurnaceModel() // Use furnace model as placeholder for boiler
        case .steamEngine:
            return createGeneratorModel() // Use generator model as placeholder for steam engine
        case .solarPanel:
            return createSolarPanelModel()
        case .accumulator:
            return createAccumulatorModel()
        case .lab:
            return createLabModel()
        case .turret:
            return createTurretModel()
        case .wall:
            return createWallModel()
        case .chest:
            return createChestModel()
        case .pipe:
            return createPipeModel()
        case .pumpjack:
            return createPumpjackModel()
        case .waterPump:
            return createWaterPumpModel()
        case .oilRefinery:
            return createOilRefineryModel()
        case .chemicalPlant:
            return createChemicalPlantModel()
        case .rocketSilo:
            return createRocketSiloModel()
        case .centrifuge:
            return createCentrifugeModel()
        case .nuclearReactor:
            return createNuclearReactorModel()
        case .fluidTank:
            return createFluidTankModel()
        case .unitProduction:
            return createUnitProductionModel()
        }
    }

    private func createMinerModel() -> Model3D {
        // Mining drill: tall cylindrical base with rotating top
        let model = Model3D()

        // Base cylinder
        let baseVertices = createCylinder(radius: 1.5, height: 1.0, segments: 8)
        model.addMesh(Mesh3D(vertices: baseVertices, color: Color(r: 0.6, g: 0.6, b: 0.6, a: 1.0)))

        // Top rotating part
        let topVertices = createCylinder(radius: 1.0, height: 0.5, segments: 6)
        // Offset up by base height
        let offsetTopVertices = topVertices.map { vertex in
            Vertex3D(
                position: vertex.position + Vector3(0, 1.0, 0),
                normal: vertex.normal,
                texCoord: vertex.texCoord,
                color: Color(r: 0.4, g: 0.4, b: 0.4, a: 1.0)
            )
        }
        model.addMesh(Mesh3D(vertices: offsetTopVertices, color: Color(r: 0.4, g: 0.4, b: 0.4, a: 1.0)))

        return model
    }

    private func createFurnaceModel() -> Model3D {
        // Furnace: stone cube with glowing interior
        let model = Model3D()

        let cubeVertices = createCube(size: Vector3(2, 2, 2))
        model.addMesh(Mesh3D(vertices: cubeVertices, color: Color(r: 0.5, g: 0.3, b: 0.2, a: 1.0)))

        return model
    }

    private func createAssemblerModel() -> Model3D {
        // Assembler: complex machine with multiple parts
        let model = Model3D()

        // Main body
        let bodyVertices = createCube(size: Vector3(3, 3, 3))
        model.addMesh(Mesh3D(vertices: bodyVertices, color: Color(r: 0.7, g: 0.7, b: 0.8, a: 1.0)))

        // Add some details - smaller cubes on top
        let detailVertices = createCube(size: Vector3(1, 0.5, 1))
        let offsetDetailVertices = detailVertices.map { vertex in
            Vertex3D(
                position: vertex.position + Vector3(0, 1.75, 0),
                normal: vertex.normal,
                texCoord: vertex.texCoord,
                color: Color(r: 0.5, g: 0.5, b: 0.6, a: 1.0)
            )
        }
        model.addMesh(Mesh3D(vertices: offsetDetailVertices, color: Color(r: 0.5, g: 0.5, b: 0.6, a: 1.0)))

        return model
    }

    private func createBeltModel() -> Model3D {
        // Belt: long thin rectangle on ground
        let model = Model3D()

        let beltVertices = createCube(size: Vector3(1, 0.2, 1))
        model.addMesh(Mesh3D(vertices: beltVertices, color: Color(r: 0.8, g: 0.8, b: 0.8, a: 1.0)))

        return model
    }

    private func createInserterModel() -> Model3D {
        // Inserter: arm-like structure
        let model = Model3D()

        // Base
        let baseVertices = createCylinder(radius: 0.3, height: 0.5, segments: 6)
        model.addMesh(Mesh3D(vertices: baseVertices, color: Color(r: 0.6, g: 0.6, b: 0.6, a: 1.0)))

        // Arm
        let armVertices = createCube(size: Vector3(0.1, 0.1, 1.0))
        let offsetArmVertices = armVertices.map { vertex in
            Vertex3D(
                position: vertex.position + Vector3(0, 0.5, 0.5),
                normal: vertex.normal,
                texCoord: vertex.texCoord,
                color: Color(r: 0.5, g: 0.5, b: 0.5, a: 1.0)
            )
        }
        model.addMesh(Mesh3D(vertices: offsetArmVertices, color: Color(r: 0.5, g: 0.5, b: 0.5, a: 1.0)))

        return model
    }

    private func createPowerPoleModel() -> Model3D {
        // Power pole: tall thin pole with crossbars
        let model = Model3D()

        // Pole
        let poleVertices = createCylinder(radius: 0.1, height: 3.0, segments: 4)
        model.addMesh(Mesh3D(vertices: poleVertices, color: Color(r: 0.4, g: 0.4, b: 0.4, a: 1.0)))

        // Crossbars
        let crossbarVertices = createCube(size: Vector3(1.0, 0.05, 0.05))
        let offsetCrossbarVertices = crossbarVertices.map { vertex in
            Vertex3D(
                position: vertex.position + Vector3(0, 2.0, 0),
                normal: vertex.normal,
                texCoord: vertex.texCoord,
                color: Color(r: 0.3, g: 0.3, b: 0.3, a: 1.0)
            )
        }
        model.addMesh(Mesh3D(vertices: offsetCrossbarVertices, color: Color(r: 0.3, g: 0.3, b: 0.3, a: 1.0)))

        return model
    }

    private func createGeneratorModel() -> Model3D {
        // Generator: boiler or steam engine
        let model = Model3D()

        let bodyVertices = createCylinder(radius: 1.0, height: 2.0, segments: 8)
        model.addMesh(Mesh3D(vertices: bodyVertices, color: Color(r: 0.5, g: 0.5, b: 0.5, a: 1.0)))

        // Add some pipes/details
        let pipeVertices = createCylinder(radius: 0.2, height: 1.5, segments: 6)
        let offsetPipeVertices = pipeVertices.map { vertex in
            Vertex3D(
                position: vertex.position + Vector3(0.8, 0, 0),
                normal: vertex.normal,
                texCoord: vertex.texCoord,
                color: Color(r: 0.6, g: 0.4, b: 0.3, a: 1.0)
            )
        }
        model.addMesh(Mesh3D(vertices: offsetPipeVertices, color: Color(r: 0.6, g: 0.4, b: 0.3, a: 1.0)))

        return model
    }

    private func createTurretModel() -> Model3D {
        // Turret: gun turret with rotating gun
        let model = Model3D()

        // Base
        let baseVertices = createCylinder(radius: 0.8, height: 0.5, segments: 8)
        model.addMesh(Mesh3D(vertices: baseVertices, color: Color(r: 0.4, g: 0.4, b: 0.4, a: 1.0)))

        // Gun barrel
        let barrelVertices = createCylinder(radius: 0.1, height: 1.5, segments: 6)
        let offsetBarrelVertices = barrelVertices.map { vertex in
            Vertex3D(
                position: vertex.position + Vector3(0, 0.5, 0.8),
                normal: vertex.normal,
                texCoord: vertex.texCoord,
                color: Color(r: 0.3, g: 0.3, b: 0.3, a: 1.0)
            )
        }
        model.addMesh(Mesh3D(vertices: offsetBarrelVertices, color: Color(r: 0.3, g: 0.3, b: 0.3, a: 1.0)))

        return model
    }

    private func createChestModel() -> Model3D {
        // Chest: simple cube
        let model = Model3D()

        let chestVertices = createCube(size: Vector3(1, 1, 1))
        model.addMesh(Mesh3D(vertices: chestVertices, color: Color(r: 0.6, g: 0.4, b: 0.2, a: 1.0)))

        return model
    }

    private func createPipeModel() -> Model3D {
        // Pipe: thin cylinder
        let model = Model3D()

        let pipeVertices = createCylinder(radius: 0.1, height: 1.0, segments: 6)
        model.addMesh(Mesh3D(vertices: pipeVertices, color: Color(r: 0.7, g: 0.7, b: 0.8, a: 1.0)))

        return model
    }

    private func createRocketSiloModel() -> Model3D {
        // Rocket silo: large complex structure
        let model = Model3D()

        // Main silo
        let siloVertices = createCylinder(radius: 4.0, height: 6.0, segments: 12)
        model.addMesh(Mesh3D(vertices: siloVertices, color: Color(r: 0.6, g: 0.6, b: 0.7, a: 1.0)))

        // Launch platform
        let platformVertices = createCylinder(radius: 5.0, height: 0.5, segments: 12)
        let offsetPlatformVertices = platformVertices.map { vertex in
            Vertex3D(
                position: vertex.position + Vector3(0, 6.0, 0),
                normal: vertex.normal,
                texCoord: vertex.texCoord,
                color: Color(r: 0.5, g: 0.5, b: 0.5, a: 1.0)
            )
        }
        model.addMesh(Mesh3D(vertices: offsetPlatformVertices, color: Color(r: 0.5, g: 0.5, b: 0.5, a: 1.0)))

        return model
    }

    private func createUnitProductionModel() -> Model3D {
        // Unit production building: barracks/academy/circle
        let model = Model3D()

        // Main building
        let buildingVertices = createCube(size: Vector3(4, 3, 4))
        model.addMesh(Mesh3D(vertices: buildingVertices, color: Color(r: 0.7, g: 0.6, b: 0.5, a: 1.0)))

        // Roof
        let roofVertices = createPyramid(baseSize: Vector2(4.5, 4.5), height: 1.5)
        let offsetRoofVertices = roofVertices.map { vertex in
            Vertex3D(
                position: vertex.position + Vector3(0, 3.0, 0),
                normal: vertex.normal,
                texCoord: vertex.texCoord,
                color: Color(r: 0.5, g: 0.3, b: 0.2, a: 1.0)
            )
        }
        model.addMesh(Mesh3D(vertices: offsetRoofVertices, color: Color(r: 0.5, g: 0.3, b: 0.2, a: 1.0)))

        return model
    }

    // Placeholder implementations for other buildings
    private func createSolarPanelModel() -> Model3D { return createCubeModel(Color(r: 0.2, g: 0.2, b: 0.8, a: 1.0)) }
    private func createAccumulatorModel() -> Model3D { return createCubeModel(Color(r: 0.3, g: 0.3, b: 0.3, a: 1.0)) }
    private func createLabModel() -> Model3D { return createCubeModel(Color(r: 0.8, g: 0.8, b: 0.5, a: 1.0)) }
    private func createWallModel() -> Model3D { return createCubeModel(Color(r: 0.4, g: 0.4, b: 0.4, a: 1.0)) }
    private func createPumpjackModel() -> Model3D { return createCubeModel(Color(r: 0.5, g: 0.4, b: 0.3, a: 1.0)) }
    private func createWaterPumpModel() -> Model3D { return createCubeModel(Color(r: 0.6, g: 0.6, b: 0.8, a: 1.0)) }
    private func createOilRefineryModel() -> Model3D { return createCubeModel(Color(r: 0.4, g: 0.3, b: 0.2, a: 1.0)) }
    private func createChemicalPlantModel() -> Model3D { return createCubeModel(Color(r: 0.3, g: 0.5, b: 0.3, a: 1.0)) }
    private func createCentrifugeModel() -> Model3D { return createCubeModel(Color(r: 0.5, g: 0.5, b: 0.5, a: 1.0)) }
    private func createNuclearReactorModel() -> Model3D { return createCubeModel(Color(r: 0.2, g: 0.6, b: 0.8, a: 1.0)) }
    private func createFluidTankModel() -> Model3D { return createCylinderModel(Color(r: 0.4, g: 0.4, b: 0.6, a: 1.0)) }

    func createCubeModel(_ color: Color) -> Model3D {
        let model = Model3D()
        let vertices = createCube(size: Vector3(1, 1, 1))
        model.addMesh(Mesh3D(vertices: vertices, color: color))
        return model
    }

    private func createCylinderModel(_ color: Color) -> Model3D {
        let model = Model3D()
        let vertices = createCylinder(radius: 0.5, height: 1.0, segments: 8)
        model.addMesh(Mesh3D(vertices: vertices, color: color))
        return model
    }

    // MARK: - Unit Models

    func createUnitModel(type: UnitType) -> Model3D {
        switch type {
        case .militia:
            return createHumanoidModel(color: Color(r: 0.6, g: 0.6, b: 0.6, a: 1.0))
        case .soldier:
            return createHumanoidModel(color: Color(r: 0.4, g: 0.4, b: 0.8, a: 1.0))
        case .heavyInfantry:
            return createHumanoidModel(color: Color(r: 0.3, g: 0.3, b: 0.3, a: 1.0), scale: Vector3(1.2, 1.4, 1.2))
        case .scout:
            return createHumanoidModel(color: Color(r: 0.8, g: 0.8, b: 0.4, a: 1.0), scale: Vector3(0.8, 0.8, 0.8))
        case .engineer:
            return createHumanoidModel(color: Color(r: 0.6, g: 0.4, b: 0.2, a: 1.0))

        case .warrior:
            return createHumanoidModel(color: Color(r: 0.8, g: 0.2, b: 0.2, a: 1.0), scale: Vector3(1.1, 1.2, 1.1))
        case .ranger:
            return createHumanoidModel(color: Color(r: 0.4, g: 0.6, b: 0.2, a: 1.0))
        case .mage:
            return createHumanoidModel(color: Color(r: 0.6, g: 0.2, b: 0.8, a: 1.0))
        case .paladin:
            return createHumanoidModel(color: Color(r: 0.9, g: 0.8, b: 0.2, a: 1.0), scale: Vector3(1.1, 1.3, 1.1))
        case .rogue:
            return createHumanoidModel(color: Color(r: 0.3, g: 0.3, b: 0.3, a: 1.0))

        case .fireElemental:
            return createElementalModel(color: Color(r: 1.0, g: 0.3, b: 0.0, a: 1.0))
        case .waterSpirit:
            return createElementalModel(color: Color(r: 0.0, g: 0.5, b: 1.0, a: 1.0))
        case .earthGolem:
            return createElementalModel(color: Color(r: 0.4, g: 0.3, b: 0.2, a: 1.0), scale: Vector3(1.5, 2.0, 1.5))
        case .airSprite:
            return createElementalModel(color: Color(r: 0.8, g: 0.9, b: 1.0, a: 1.0), scale: Vector3(0.7, 0.7, 0.7))
        case .shadowBeast:
            return createElementalModel(color: Color(r: 0.2, g: 0.2, b: 0.2, a: 1.0))
        case .lightSeraph:
            return createElementalModel(color: Color(r: 1.0, g: 1.0, b: 0.8, a: 1.0))
        }
    }

    private func createHumanoidModel(color: Color, scale: Vector3 = Vector3(1, 1, 1)) -> Model3D {
        let model = Model3D()

        // Body (torso)
        let bodyVertices = createCube(size: Vector3(0.6, 0.8, 0.3) * scale)
        model.addMesh(Mesh3D(vertices: bodyVertices, color: color))

        // Head
        let headVertices = createSphere(radius: 0.25 * scale.x, segments: 6)
        let offsetHeadVertices = headVertices.map { vertex in
            Vertex3D(
                position: vertex.position + Vector3(0, 0.65 * scale.y, 0),
                normal: vertex.normal,
                texCoord: vertex.texCoord,
                color: color
            )
        }
        model.addMesh(Mesh3D(vertices: offsetHeadVertices, color: color))

        // Arms
        let armVertices = createCube(size: Vector3(0.2, 0.6, 0.2) * scale)
        // Left arm
        let leftArmVertices = armVertices.map { vertex in
            Vertex3D(
                position: vertex.position + Vector3(-0.45 * scale.x, 0.2 * scale.y, 0),
                normal: vertex.normal,
                texCoord: vertex.texCoord,
                color: color
            )
        }
        model.addMesh(Mesh3D(vertices: leftArmVertices, color: color))

        // Right arm
        let rightArmVertices = armVertices.map { vertex in
            Vertex3D(
                position: vertex.position + Vector3(0.45 * scale.x, 0.2 * scale.y, 0),
                normal: vertex.normal,
                texCoord: vertex.texCoord,
                color: color
            )
        }
        model.addMesh(Mesh3D(vertices: rightArmVertices, color: color))

        // Legs
        let legVertices = createCube(size: Vector3(0.25, 0.7, 0.25) * scale)
        // Left leg
        let leftLegVertices = legVertices.map { vertex in
            Vertex3D(
                position: vertex.position + Vector3(-0.15 * scale.x, -0.55 * scale.y, 0),
                normal: vertex.normal,
                texCoord: vertex.texCoord,
                color: color
            )
        }
        model.addMesh(Mesh3D(vertices: leftLegVertices, color: color))

        // Right leg
        let rightLegVertices = legVertices.map { vertex in
            Vertex3D(
                position: vertex.position + Vector3(0.15 * scale.x, -0.55 * scale.y, 0),
                normal: vertex.normal,
                texCoord: vertex.texCoord,
                color: color
            )
        }
        model.addMesh(Mesh3D(vertices: rightLegVertices, color: color))

        return model
    }

    private func createElementalModel(color: Color, scale: Vector3 = Vector3(1, 1, 1)) -> Model3D {
        let model = Model3D()

        // Main body as sphere or amorphous shape
        let bodyVertices = createSphere(radius: 0.6 * scale.x, segments: 8)
        model.addMesh(Mesh3D(vertices: bodyVertices, color: color))

        // Add some tendrils or appendages for elemental feel
        for i in 0..<3 {
            let angle = Float(i) * .pi * 2 / 3
            let tendrilVertices = createCylinder(radius: 0.05, height: 0.8, segments: 4)
            let offsetTendrilVertices = tendrilVertices.map { vertex in
                let offset = Vector3(cosf(angle) * 0.4, sinf(Float(i) * 0.5) * 0.3, sinf(angle) * 0.4)
                return Vertex3D(
                    position: vertex.position + offset,
                    normal: vertex.normal,
                    texCoord: vertex.texCoord,
                    color: color
                )
            }
            model.addMesh(Mesh3D(vertices: offsetTendrilVertices, color: color))
        }

        return model
    }

    // MARK: - Terrain Models

    func createTerrainChunk(width: Int, height: Int, heightMap: [[Float]], tileTypes: [[TileType]]) -> TerrainChunk3D {
        return TerrainChunk3D(width: width, height: height, heightMap: heightMap, tileTypes: tileTypes, device: device)
    }

    // MARK: - Primitive Generation

    private func createCube(size: Vector3) -> [Vertex3D] {
        let halfSize = size * 0.5
        var vertices: [Vertex3D] = []

        // Define cube vertices (8 corners)
        let positions: [Vector3] = [
            Vector3(-halfSize.x, -halfSize.y, -halfSize.z), // 0: bottom-back-left
            Vector3( halfSize.x, -halfSize.y, -halfSize.z), // 1: bottom-back-right
            Vector3( halfSize.x,  halfSize.y, -halfSize.z), // 2: top-back-right
            Vector3(-halfSize.x,  halfSize.y, -halfSize.z), // 3: top-back-left
            Vector3(-halfSize.x, -halfSize.y,  halfSize.z), // 4: bottom-front-left
            Vector3( halfSize.x, -halfSize.y,  halfSize.z), // 5: bottom-front-right
            Vector3( halfSize.x,  halfSize.y,  halfSize.z), // 6: top-front-right
            Vector3(-halfSize.x,  halfSize.y,  halfSize.z), // 7: top-front-left
        ]

        // Define cube faces (6 faces, 2 triangles each, 6 vertices each)
        let indices: [[Int]] = [
            // Bottom face
            [0, 1, 2, 0, 2, 3],
            // Top face
            [4, 5, 6, 4, 6, 7],
            // Front face
            [4, 5, 1, 4, 1, 0],
            // Back face
            [7, 6, 2, 7, 2, 3],
            // Left face
            [4, 0, 3, 4, 3, 7],
            // Right face
            [5, 1, 2, 5, 2, 6],
        ]

        // Calculate normals for each face
        let normals: [Vector3] = [
            Vector3( 0, -1,  0), // Bottom
            Vector3( 0,  1,  0), // Top
            Vector3( 0,  0,  1), // Front
            Vector3( 0,  0, -1), // Back
            Vector3(-1,  0,  0), // Left
            Vector3( 1,  0,  0), // Right
        ]

        for (faceIndex, faceIndices) in indices.enumerated() {
            let normal = normals[faceIndex]
            for vertexIndex in faceIndices {
                let position = positions[vertexIndex]
                vertices.append(Vertex3D(
                    position: position,
                    normal: normal,
                    texCoord: Vector2(0, 0), // Simple UV mapping
                    color: Color(r: 1, g: 1, b: 1, a: 1)
                ))
            }
        }

        return vertices
    }

    private func createCylinder(radius: Float, height: Float, segments: Int) -> [Vertex3D] {
        var vertices: [Vertex3D] = []
        let halfHeight = height * 0.5

        // Generate vertices for sides
        for i in 0..<segments {
            let angle1 = Float(i) * 2 * .pi / Float(segments)
            let angle2 = Float(i + 1) * 2 * .pi / Float(segments)

            let x1 = cosf(angle1) * radius
            let z1 = sinf(angle1) * radius
            let x2 = cosf(angle2) * radius
            let z2 = sinf(angle2) * radius

            // Two triangles per segment
            let positions: [Vector3] = [
                Vector3(x1, -halfHeight, z1),
                Vector3(x2, -halfHeight, z2),
                Vector3(x2,  halfHeight, z2),
                Vector3(x1, -halfHeight, z1),
                Vector3(x2,  halfHeight, z2),
                Vector3(x1,  halfHeight, z1),
            ]

            let normal = Vector3(cosf(angle1 + .pi / Float(segments)), 0, sinf(angle1 + .pi / Float(segments))).normalized

            for position in positions {
                vertices.append(Vertex3D(
                    position: position,
                    normal: normal,
                    texCoord: Vector2(0, 0),
                    color: Color(r: 1, g: 1, b: 1, a: 1)
                ))
            }
        }

        // Add top and bottom caps (simplified)
        // Top cap
        for i in 0..<segments {
            let angle1 = Float(i) * 2 * .pi / Float(segments)
            let angle2 = Float(i + 1) * 2 * .pi / Float(segments)

            let x1 = cosf(angle1) * radius
            let z1 = sinf(angle1) * radius
            let x2 = cosf(angle2) * radius
            let z2 = sinf(angle2) * radius

            vertices.append(contentsOf: [
                Vertex3D(position: Vector3(0, halfHeight, 0), normal: Vector3(0, 1, 0), texCoord: Vector2(0, 0), color: Color(r: 1, g: 1, b: 1, a: 1)),
                Vertex3D(position: Vector3(x1, halfHeight, z1), normal: Vector3(0, 1, 0), texCoord: Vector2(0, 0), color: Color(r: 1, g: 1, b: 1, a: 1)),
                Vertex3D(position: Vector3(x2, halfHeight, z2), normal: Vector3(0, 1, 0), texCoord: Vector2(0, 0), color: Color(r: 1, g: 1, b: 1, a: 1)),
            ])
        }

        // Bottom cap
        for i in 0..<segments {
            let angle1 = Float(i) * 2 * .pi / Float(segments)
            let angle2 = Float(i + 1) * 2 * .pi / Float(segments)

            let x1 = cosf(angle1) * radius
            let z1 = sinf(angle1) * radius
            let x2 = cosf(angle2) * radius
            let z2 = sinf(angle2) * radius

            vertices.append(contentsOf: [
                Vertex3D(position: Vector3(0, -halfHeight, 0), normal: Vector3(0, -1, 0), texCoord: Vector2(0, 0), color: Color(r: 1, g: 1, b: 1, a: 1)),
                Vertex3D(position: Vector3(x2, -halfHeight, z2), normal: Vector3(0, -1, 0), texCoord: Vector2(0, 0), color: Color(r: 1, g: 1, b: 1, a: 1)),
                Vertex3D(position: Vector3(x1, -halfHeight, z1), normal: Vector3(0, -1, 0), texCoord: Vector2(0, 0), color: Color(r: 1, g: 1, b: 1, a: 1)),
            ])
        }

        return vertices
    }

    private func createSphere(radius: Float, segments: Int) -> [Vertex3D] {
        var vertices: [Vertex3D] = []

        // Simplified sphere using latitudinal bands
        for lat in 0..<segments {
            let theta1 = Float(lat) * .pi / Float(segments)
            let theta2 = Float(lat + 1) * .pi / Float(segments)

            for lon in 0..<segments {
                let phi1 = Float(lon) * 2 * .pi / Float(segments)
                let phi2 = Float(lon + 1) * 2 * .pi / Float(segments)

                // Four corners of quad
                let positions: [Vector3] = [
                    sphericalToCartesian(radius, theta1, phi1),
                    sphericalToCartesian(radius, theta1, phi2),
                    sphericalToCartesian(radius, theta2, phi2),
                    sphericalToCartesian(radius, theta1, phi1),
                    sphericalToCartesian(radius, theta2, phi2),
                    sphericalToCartesian(radius, theta2, phi1),
                ]

                for position in positions {
                    vertices.append(Vertex3D(
                        position: position,
                        normal: position.normalized,
                        texCoord: Vector2(0, 0),
                        color: Color(r: 1, g: 1, b: 1, a: 1)
                    ))
                }
            }
        }

        return vertices
    }

    private func createPyramid(baseSize: Vector2, height: Float) -> [Vertex3D] {
        let halfWidth = baseSize.x * 0.5
        let halfDepth = baseSize.y * 0.5
        var vertices: [Vertex3D] = []

        // Base
        let basePositions: [Vector3] = [
            Vector3(-halfWidth, 0, -halfDepth), // 0
            Vector3( halfWidth, 0, -halfDepth), // 1
            Vector3( halfWidth, 0,  halfDepth), // 2
            Vector3(-halfWidth, 0,  halfDepth), // 3
        ]

        // Apex
        let apex = Vector3(0, height, 0)

        // Base triangles
        let baseIndices = [[0, 1, 2], [0, 2, 3]]

        for triangle in baseIndices {
            for index in triangle {
                vertices.append(Vertex3D(
                    position: basePositions[index],
                    normal: Vector3(0, -1, 0),
                    texCoord: Vector2(0, 0),
                    color: Color(r: 1, g: 1, b: 1, a: 1)
                ))
            }
        }

        // Side triangles
        let sideTriangles = [
            [0, 1, apex],
            [1, 2, apex],
            [2, 3, apex],
            [3, 0, apex],
        ]

        for triangle in sideTriangles {
            let p0 = (triangle[0] as! Int) < 4 ? basePositions[triangle[0] as! Int] : apex
            let p1 = (triangle[1] as! Int) < 4 ? basePositions[triangle[1] as! Int] : apex
            let p2 = (triangle[2] as! Int) < 4 ? basePositions[triangle[2] as! Int] : apex

            // Calculate normal for this triangle
            let v1 = p1 - p0
            let v2 = p2 - p0
            let normal = v1.cross(v2).normalized

            vertices.append(contentsOf: [
                Vertex3D(position: p0, normal: normal, texCoord: Vector2(0, 0), color: Color(r: 1, g: 1, b: 1, a: 1)),
                Vertex3D(position: p1, normal: normal, texCoord: Vector2(0, 0), color: Color(r: 1, g: 1, b: 1, a: 1)),
                Vertex3D(position: p2, normal: normal, texCoord: Vector2(0, 0), color: Color(r: 1, g: 1, b: 1, a: 1)),
            ])
        }

        return vertices
    }

    private func sphericalToCartesian(_ radius: Float, _ theta: Float, _ phi: Float) -> Vector3 {
        let x = radius * sinf(theta) * cosf(phi)
        let y = radius * cosf(theta)
        let z = radius * sinf(theta) * sinf(phi)
        return Vector3(x, y, z)
    }
}

// MARK: - Supporting Types

struct Vertex3D {
    var position: Vector3
    var normal: Vector3
    var texCoord: Vector2
    var color: Color
}

final class Mesh3D {
    let vertices: [Vertex3D]
    let vertexBuffer: MTLBuffer?
    let vertexCount: Int

    init(vertices: [Vertex3D], color: Color, device: MTLDevice? = nil) {
        self.vertices = vertices
        self.vertexCount = vertices.count

        if let device = device {
            vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex3D>.stride * vertices.count, options: .storageModeShared)
        } else {
            vertexBuffer = nil
        }
    }
}

final class Model3D: RenderModel {
    private var meshes: [Mesh3D] = []
    var transform = Transform3D()

    func addMesh(_ mesh: Mesh3D) {
        meshes.append(mesh)
    }

    func render(renderEncoder: MTLRenderCommandEncoder, textureAtlas: TextureAtlas) {
        for mesh in meshes {
            guard let vertexBuffer = mesh.vertexBuffer else { continue }

            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: mesh.vertexCount)
        }
    }
}

final class TerrainChunk3D: TerrainChunk {
    let width: Int
    let height: Int
    let vertexBuffer: MTLBuffer?
    let indexBuffer: MTLBuffer?
    let indexCount: Int

    init(width: Int, height: Int, heightMap: [[Float]], tileTypes: [[TileType]], device: MTLDevice) {
        self.width = width
        self.height = height

        // Generate terrain mesh
        var vertices: [Vertex3D] = []
        var indices: [UInt16] = []

        // Create vertices
        for z in 0..<height {
            for x in 0..<width {
                let heightValue = heightMap[z][x]
                let tileType = tileTypes[z][x]

                // Position with height
                let position = Vector3(Float(x), heightValue, Float(z))

                // Normal (simplified - pointing up)
                let normal = Vector3(0, 1, 0)

                // Color based on tile type
                let color = Self.colorForTileType(tileType)

                vertices.append(Vertex3D(
                    position: position,
                    normal: normal,
                    texCoord: Vector2(Float(x) / Float(width), Float(z) / Float(height)),
                    color: color
                ))
            }
        }

        // Create indices for triangle strips
        for z in 0..<height-1 {
            for x in 0..<width-1 {
                let topLeft = UInt16(z * width + x)
                let topRight = UInt16(z * width + x + 1)
                let bottomLeft = UInt16((z + 1) * width + x)
                let bottomRight = UInt16((z + 1) * width + x + 1)

                // Two triangles per quad
                indices.append(contentsOf: [topLeft, bottomLeft, topRight])
                indices.append(contentsOf: [topRight, bottomLeft, bottomRight])
            }
        }

        // Create Metal buffers
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex3D>.stride * vertices.count, options: .storageModeShared)
        indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.stride * indices.count, options: .storageModeShared)
        indexCount = indices.count
    }

    func render(renderEncoder: MTLRenderCommandEncoder) {
        guard let vertexBuffer = vertexBuffer, let indexBuffer = indexBuffer else { return }

        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
    }

    private static func colorForTileType(_ tileType: TileType) -> Color {
        switch tileType {
        case .grass: return Color(r: 0.2, g: 0.8, b: 0.2, a: 1.0)
        case .dirt: return Color(r: 0.6, g: 0.4, b: 0.2, a: 1.0)
        case .stone: return Color(r: 0.5, g: 0.5, b: 0.5, a: 1.0)
        case .water: return Color(r: 0.0, g: 0.3, b: 0.8, a: 1.0)
        case .sand: return Color(r: 0.9, g: 0.8, b: 0.4, a: 1.0)
        case .ironOre: return Color(r: 0.4, g: 0.5, b: 0.6, a: 1.0)
        case .copperOre: return Color(r: 0.8, g: 0.4, b: 0.2, a: 1.0)
        case .coal: return Color(r: 0.2, g: 0.2, b: 0.2, a: 1.0)
        case .tree: return Color(r: 0.1, g: 0.5, b: 0.1, a: 1.0)
        }
    }
}