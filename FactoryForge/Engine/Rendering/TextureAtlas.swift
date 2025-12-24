import Metal
import MetalKit

/// Manages texture atlases for efficient rendering
final class TextureAtlas {
    private let device: MTLDevice
    private var textures: [String: MTLTexture] = [:]
    private var textureRects: [String: Rect] = [:]
    
    // Main atlas texture
    private(set) var atlasTexture: MTLTexture?
    private let atlasSize: Int = 2048
    
    // Default sampler
    let sampler: MTLSamplerState
    
    init(device: MTLDevice) {
        self.device = device
        
        // Create sampler
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .nearest
        samplerDescriptor.magFilter = .nearest
        samplerDescriptor.mipFilter = .nearest
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        
        guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor) else {
            fatalError("Failed to create sampler state")
        }
        self.sampler = sampler
        
        // Load textures
        loadAllTextures()
    }
    
    private func loadAllTextures() {
        // Create procedural textures for now (would be replaced with actual assets)
        createProceduralAtlas()
    }
    
    private func createProceduralAtlas() {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: atlasSize,
            height: atlasSize,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("Failed to create atlas texture")
        }
        
        atlasTexture = texture
        
        // Generate procedural textures and pack into atlas
        var atlasData = [UInt8](repeating: 0, count: atlasSize * atlasSize * 4)
        
        // Define texture regions (16x16 tiles)
        let tileSize = 32
        var currentX = 0
        var currentY = 0
        
        // Generate tiles
        let tiles: [(String, (Int, Int, inout [UInt8]) -> Void)] = [
            ("grass", generateGrass),
            ("dirt", generateDirt),
            ("stone", generateStone),
            ("water", generateWater),
            ("sand", generateSand),
            ("iron_ore", generateIronOre),
            ("copper_ore", generateCopperOre),
            ("coal", generateCoal),
            ("tree", generateTree),
            ("belt", generateBelt),
            ("inserter", generateInserter),
            ("miner", generateMiner),
            ("furnace", generateFurnace),
            ("assembler", generateAssembler),
            ("power_pole", generatePowerPole),
            ("steam_engine", generateSteamEngine),
            ("boiler", generateBoiler),
            ("lab", generateLab),
            ("turret", generateTurret),
            ("wall", generateWall),
            ("chest", generateChest),
            ("pipe", generatePipe),
            ("solar_panel", generateSolarPanel),
            ("accumulator", generateAccumulator),
            ("biter", generateBiter),
            ("spawner", generateSpawner),
            ("bullet", generateBullet),
            ("iron_plate", generateIronPlate),
            ("copper_plate", generateCopperPlate),
            ("gear", generateGear),
            ("circuit", generateCircuit),
            ("science_pack_red", generateSciencePackRed),
            ("science_pack_green", generateSciencePackGreen)
        ]
        
        for (name, generator) in tiles {
            // Generate the tile
            var tileData = [UInt8](repeating: 0, count: tileSize * tileSize * 4)
            generator(tileSize, tileSize, &tileData)
            
            // Copy to atlas
            for y in 0..<tileSize {
                for x in 0..<tileSize {
                    let srcIdx = (y * tileSize + x) * 4
                    let dstIdx = ((currentY + y) * atlasSize + (currentX + x)) * 4
                    atlasData[dstIdx] = tileData[srcIdx]
                    atlasData[dstIdx + 1] = tileData[srcIdx + 1]
                    atlasData[dstIdx + 2] = tileData[srcIdx + 2]
                    atlasData[dstIdx + 3] = tileData[srcIdx + 3]
                }
            }
            
            // Store UV rect
            let uvRect = Rect(
                x: Float(currentX) / Float(atlasSize),
                y: Float(currentY) / Float(atlasSize),
                width: Float(tileSize) / Float(atlasSize),
                height: Float(tileSize) / Float(atlasSize)
            )
            textureRects[name] = uvRect
            
            // Move to next position
            currentX += tileSize
            if currentX + tileSize > atlasSize {
                currentX = 0
                currentY += tileSize
            }
        }
        
        // Upload to GPU
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: atlasSize, height: atlasSize, depth: 1))
        texture.replace(region: region, mipmapLevel: 0, withBytes: atlasData,
                        bytesPerRow: atlasSize * 4)
    }
    
    func getTextureRect(for name: String) -> Rect {
        return textureRects[name] ?? Rect(x: 0, y: 0, width: 1, height: 1)
    }
    
    // MARK: - Procedural Texture Generators
    
    private func generateGrass(width: Int, height: Int, data: inout [UInt8]) {
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                let noise = Float.random(in: 0.8...1.0)
                data[idx] = UInt8(50 * noise)      // R
                data[idx + 1] = UInt8(120 * noise) // G
                data[idx + 2] = UInt8(40 * noise)  // B
                data[idx + 3] = 255                 // A
            }
        }
    }
    
    private func generateDirt(width: Int, height: Int, data: inout [UInt8]) {
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                let noise = Float.random(in: 0.85...1.0)
                data[idx] = UInt8(120 * noise)
                data[idx + 1] = UInt8(85 * noise)
                data[idx + 2] = UInt8(60 * noise)
                data[idx + 3] = 255
            }
        }
    }
    
    private func generateStone(width: Int, height: Int, data: inout [UInt8]) {
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                let noise = Float.random(in: 0.8...1.0)
                let base: UInt8 = UInt8(130 * noise)
                data[idx] = base
                data[idx + 1] = base
                data[idx + 2] = base
                data[idx + 3] = 255
            }
        }
    }
    
    private func generateWater(width: Int, height: Int, data: inout [UInt8]) {
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                let noise = Float.random(in: 0.9...1.0)
                data[idx] = UInt8(30 * noise)
                data[idx + 1] = UInt8(90 * noise)
                data[idx + 2] = UInt8(180 * noise)
                data[idx + 3] = 200
            }
        }
    }
    
    private func generateSand(width: Int, height: Int, data: inout [UInt8]) {
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                let noise = Float.random(in: 0.9...1.0)
                data[idx] = UInt8(210 * noise)
                data[idx + 1] = UInt8(190 * noise)
                data[idx + 2] = UInt8(130 * noise)
                data[idx + 3] = 255
            }
        }
    }
    
    private func generateIronOre(width: Int, height: Int, data: inout [UInt8]) {
        generateOre(width: width, height: height, data: &data, r: 100, g: 120, b: 140)
    }
    
    private func generateCopperOre(width: Int, height: Int, data: inout [UInt8]) {
        generateOre(width: width, height: height, data: &data, r: 200, g: 100, b: 50)
    }
    
    private func generateCoal(width: Int, height: Int, data: inout [UInt8]) {
        generateOre(width: width, height: height, data: &data, r: 40, g: 40, b: 40)
    }
    
    private func generateOre(width: Int, height: Int, data: inout [UInt8], r: UInt8, g: UInt8, b: UInt8) {
        // Base stone
        generateStone(width: width, height: height, data: &data)
        
        // Add ore veins
        for _ in 0..<8 {
            let cx = Int.random(in: 4..<width-4)
            let cy = Int.random(in: 4..<height-4)
            let radius = Int.random(in: 3...6)
            
            for dy in -radius...radius {
                for dx in -radius...radius {
                    if dx * dx + dy * dy <= radius * radius {
                        let x = cx + dx
                        let y = cy + dy
                        if x >= 0 && x < width && y >= 0 && y < height {
                            let idx = (y * width + x) * 4
                            let noise = Float.random(in: 0.8...1.0)
                            data[idx] = UInt8(Float(r) * noise)
                            data[idx + 1] = UInt8(Float(g) * noise)
                            data[idx + 2] = UInt8(Float(b) * noise)
                        }
                    }
                }
            }
        }
    }
    
    private func generateTree(width: Int, height: Int, data: inout [UInt8]) {
        // Clear background
        for i in stride(from: 0, to: data.count, by: 4) {
            data[i] = 0
            data[i + 1] = 0
            data[i + 2] = 0
            data[i + 3] = 0
        }
        
        // Trunk
        let trunkWidth = width / 4
        let trunkHeight = height / 2
        for y in height/2..<height {
            for x in (width - trunkWidth)/2..<(width + trunkWidth)/2 {
                let idx = (y * width + x) * 4
                data[idx] = 90
                data[idx + 1] = 60
                data[idx + 2] = 30
                data[idx + 3] = 255
            }
        }
        
        // Foliage (circle)
        let centerX = width / 2
        let centerY = height / 3
        let radius = width / 3
        for y in 0..<height {
            for x in 0..<width {
                let dx = x - centerX
                let dy = y - centerY
                if dx * dx + dy * dy <= radius * radius {
                    let idx = (y * width + x) * 4
                    let noise = Float.random(in: 0.7...1.0)
                    data[idx] = UInt8(30 * noise)
                    data[idx + 1] = UInt8(100 * noise)
                    data[idx + 2] = UInt8(30 * noise)
                    data[idx + 3] = 255
                }
            }
        }
    }
    
    private func generateBelt(width: Int, height: Int, data: inout [UInt8]) {
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                
                // Belt track edges
                if y < 4 || y >= height - 4 {
                    data[idx] = 60
                    data[idx + 1] = 60
                    data[idx + 2] = 60
                    data[idx + 3] = 255
                } else {
                    // Belt surface with arrows
                    let arrowPhase = (x + y) % 8
                    if arrowPhase < 2 {
                        data[idx] = 180
                        data[idx + 1] = 150
                        data[idx + 2] = 50
                    } else {
                        data[idx] = 140
                        data[idx + 1] = 120
                        data[idx + 2] = 40
                    }
                    data[idx + 3] = 255
                }
            }
        }
    }
    
    private func generateInserter(width: Int, height: Int, data: inout [UInt8]) {
        // Clear
        for i in stride(from: 0, to: data.count, by: 4) {
            data[i] = 0; data[i+1] = 0; data[i+2] = 0; data[i+3] = 0
        }
        
        // Base
        let baseRadius = width / 4
        let centerX = width / 2
        let centerY = height / 2
        for y in 0..<height {
            for x in 0..<width {
                let dx = x - centerX
                let dy = y - centerY
                if dx * dx + dy * dy <= baseRadius * baseRadius {
                    let idx = (y * width + x) * 4
                    data[idx] = 80
                    data[idx + 1] = 80
                    data[idx + 2] = 100
                    data[idx + 3] = 255
                }
            }
        }
        
        // Arm
        for y in 2..<height/2 {
            for x in width/2-2..<width/2+2 {
                let idx = (y * width + x) * 4
                data[idx] = 200
                data[idx + 1] = 180
                data[idx + 2] = 50
                data[idx + 3] = 255
            }
        }
    }
    
    private func generateMiner(width: Int, height: Int, data: inout [UInt8]) {
        generateMachine(width: width, height: height, data: &data, r: 80, g: 100, b: 120)
    }
    
    private func generateFurnace(width: Int, height: Int, data: inout [UInt8]) {
        generateMachine(width: width, height: height, data: &data, r: 140, g: 80, b: 60)
    }
    
    private func generateAssembler(width: Int, height: Int, data: inout [UInt8]) {
        generateMachine(width: width, height: height, data: &data, r: 60, g: 100, b: 140)
    }
    
    private func generateMachine(width: Int, height: Int, data: inout [UInt8], r: UInt8, g: UInt8, b: UInt8) {
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                let edge = x < 2 || x >= width - 2 || y < 2 || y >= height - 2
                let noise = Float.random(in: 0.9...1.0)
                
                if edge {
                    data[idx] = UInt8(Float(r) * 0.6 * noise)
                    data[idx + 1] = UInt8(Float(g) * 0.6 * noise)
                    data[idx + 2] = UInt8(Float(b) * 0.6 * noise)
                } else {
                    data[idx] = UInt8(Float(r) * noise)
                    data[idx + 1] = UInt8(Float(g) * noise)
                    data[idx + 2] = UInt8(Float(b) * noise)
                }
                data[idx + 3] = 255
            }
        }
    }
    
    private func generatePowerPole(width: Int, height: Int, data: inout [UInt8]) {
        for i in stride(from: 0, to: data.count, by: 4) {
            data[i] = 0; data[i+1] = 0; data[i+2] = 0; data[i+3] = 0
        }
        
        // Pole
        for y in 4..<height {
            for x in width/2-2..<width/2+2 {
                let idx = (y * width + x) * 4
                data[idx] = 100
                data[idx + 1] = 70
                data[idx + 2] = 40
                data[idx + 3] = 255
            }
        }
        
        // Top crossbar
        for y in 2..<6 {
            for x in width/4..<width*3/4 {
                let idx = (y * width + x) * 4
                data[idx] = 100
                data[idx + 1] = 70
                data[idx + 2] = 40
                data[idx + 3] = 255
            }
        }
    }
    
    private func generateSteamEngine(width: Int, height: Int, data: inout [UInt8]) {
        generateMachine(width: width, height: height, data: &data, r: 100, g: 100, b: 110)
    }
    
    private func generateBoiler(width: Int, height: Int, data: inout [UInt8]) {
        generateMachine(width: width, height: height, data: &data, r: 130, g: 90, b: 70)
    }
    
    private func generateLab(width: Int, height: Int, data: inout [UInt8]) {
        generateMachine(width: width, height: height, data: &data, r: 200, g: 200, b: 220)
    }
    
    private func generateTurret(width: Int, height: Int, data: inout [UInt8]) {
        for i in stride(from: 0, to: data.count, by: 4) {
            data[i] = 0; data[i+1] = 0; data[i+2] = 0; data[i+3] = 0
        }
        
        // Base
        let baseRadius = width / 3
        let centerX = width / 2
        let centerY = height / 2
        for y in 0..<height {
            for x in 0..<width {
                let dx = x - centerX
                let dy = y - centerY
                if dx * dx + dy * dy <= baseRadius * baseRadius {
                    let idx = (y * width + x) * 4
                    data[idx] = 80
                    data[idx + 1] = 80
                    data[idx + 2] = 80
                    data[idx + 3] = 255
                }
            }
        }
        
        // Gun barrel
        for y in 0..<height/2 {
            for x in width/2-2..<width/2+2 {
                let idx = (y * width + x) * 4
                data[idx] = 50
                data[idx + 1] = 50
                data[idx + 2] = 60
                data[idx + 3] = 255
            }
        }
    }
    
    private func generateWall(width: Int, height: Int, data: inout [UInt8]) {
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                let noise = Float.random(in: 0.9...1.0)
                data[idx] = UInt8(160 * noise)
                data[idx + 1] = UInt8(160 * noise)
                data[idx + 2] = UInt8(170 * noise)
                data[idx + 3] = 255
            }
        }
    }
    
    private func generateChest(width: Int, height: Int, data: inout [UInt8]) {
        generateMachine(width: width, height: height, data: &data, r: 160, g: 120, b: 60)
    }
    
    private func generatePipe(width: Int, height: Int, data: inout [UInt8]) {
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                let isEdge = x < 4 || x >= width - 4 || y < 4 || y >= height - 4
                if isEdge {
                    data[idx] = 100
                    data[idx + 1] = 100
                    data[idx + 2] = 110
                } else {
                    data[idx] = 60
                    data[idx + 1] = 60
                    data[idx + 2] = 70
                }
                data[idx + 3] = 255
            }
        }
    }
    
    private func generateSolarPanel(width: Int, height: Int, data: inout [UInt8]) {
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                let gridX = (x / 8) % 2
                let gridY = (y / 8) % 2
                if gridX == gridY {
                    data[idx] = 40
                    data[idx + 1] = 60
                    data[idx + 2] = 120
                } else {
                    data[idx] = 30
                    data[idx + 1] = 50
                    data[idx + 2] = 100
                }
                data[idx + 3] = 255
            }
        }
    }
    
    private func generateAccumulator(width: Int, height: Int, data: inout [UInt8]) {
        generateMachine(width: width, height: height, data: &data, r: 60, g: 80, b: 60)
    }
    
    private func generateBiter(width: Int, height: Int, data: inout [UInt8]) {
        for i in stride(from: 0, to: data.count, by: 4) {
            data[i] = 0; data[i+1] = 0; data[i+2] = 0; data[i+3] = 0
        }
        
        let centerX = width / 2
        let centerY = height / 2
        let radius = width / 3
        
        for y in 0..<height {
            for x in 0..<width {
                let dx = x - centerX
                let dy = y - centerY
                if dx * dx + dy * dy <= radius * radius {
                    let idx = (y * width + x) * 4
                    data[idx] = 180
                    data[idx + 1] = 60
                    data[idx + 2] = 60
                    data[idx + 3] = 255
                }
            }
        }
    }
    
    private func generateSpawner(width: Int, height: Int, data: inout [UInt8]) {
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                let dx = x - width/2
                let dy = y - height/2
                let dist = Float(dx * dx + dy * dy)
                let maxDist = Float(width * width / 4)
                let factor = 1.0 - dist / maxDist
                
                if factor > 0 {
                    data[idx] = UInt8(min(255, 120 + 80 * factor))
                    data[idx + 1] = UInt8(40 * factor)
                    data[idx + 2] = UInt8(60 * factor)
                    data[idx + 3] = UInt8(min(255, 200 * factor + 55))
                } else {
                    data[idx] = 0
                    data[idx + 1] = 0
                    data[idx + 2] = 0
                    data[idx + 3] = 0
                }
            }
        }
    }
    
    private func generateBullet(width: Int, height: Int, data: inout [UInt8]) {
        for i in stride(from: 0, to: data.count, by: 4) {
            data[i] = 0; data[i+1] = 0; data[i+2] = 0; data[i+3] = 0
        }
        
        let centerX = width / 2
        let centerY = height / 2
        let radius = min(width, height) / 4
        
        for y in 0..<height {
            for x in 0..<width {
                let dx = x - centerX
                let dy = y - centerY
                if dx * dx + dy * dy <= radius * radius {
                    let idx = (y * width + x) * 4
                    data[idx] = 255
                    data[idx + 1] = 220
                    data[idx + 2] = 100
                    data[idx + 3] = 255
                }
            }
        }
    }
    
    private func generateIronPlate(width: Int, height: Int, data: inout [UInt8]) {
        generateItemIcon(width: width, height: height, data: &data, r: 140, g: 150, b: 160)
    }
    
    private func generateCopperPlate(width: Int, height: Int, data: inout [UInt8]) {
        generateItemIcon(width: width, height: height, data: &data, r: 200, g: 120, b: 80)
    }
    
    private func generateGear(width: Int, height: Int, data: inout [UInt8]) {
        generateItemIcon(width: width, height: height, data: &data, r: 100, g: 110, b: 120)
    }
    
    private func generateCircuit(width: Int, height: Int, data: inout [UInt8]) {
        generateItemIcon(width: width, height: height, data: &data, r: 60, g: 140, b: 60)
    }
    
    private func generateSciencePackRed(width: Int, height: Int, data: inout [UInt8]) {
        generateItemIcon(width: width, height: height, data: &data, r: 200, g: 60, b: 60)
    }
    
    private func generateSciencePackGreen(width: Int, height: Int, data: inout [UInt8]) {
        generateItemIcon(width: width, height: height, data: &data, r: 60, g: 180, b: 60)
    }
    
    private func generateItemIcon(width: Int, height: Int, data: inout [UInt8], r: UInt8, g: UInt8, b: UInt8) {
        for i in stride(from: 0, to: data.count, by: 4) {
            data[i] = 0; data[i+1] = 0; data[i+2] = 0; data[i+3] = 0
        }
        
        let margin = 4
        for y in margin..<height-margin {
            for x in margin..<width-margin {
                let idx = (y * width + x) * 4
                let edge = x < margin + 2 || x >= width - margin - 2 || y < margin + 2 || y >= height - margin - 2
                let noise = Float.random(in: 0.9...1.0)
                
                if edge {
                    data[idx] = UInt8(Float(r) * 0.7 * noise)
                    data[idx + 1] = UInt8(Float(g) * 0.7 * noise)
                    data[idx + 2] = UInt8(Float(b) * 0.7 * noise)
                } else {
                    data[idx] = UInt8(Float(r) * noise)
                    data[idx + 1] = UInt8(Float(g) * noise)
                    data[idx + 2] = UInt8(Float(b) * noise)
                }
                data[idx + 3] = 255
            }
        }
    }
}

