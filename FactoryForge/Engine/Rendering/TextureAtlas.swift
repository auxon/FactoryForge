import Metal
import MetalKit
import UIKit // Add this import

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
        // Initialize the atlas texture first
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
        
        // Initialize atlas data
        var atlasData = [UInt8](repeating: 0, count: atlasSize * atlasSize * 4)
        var atlasX = 0
        var atlasY = 0
        let spriteSize = 32
        
        // Load individual sprite files first (higher priority)
        loadIndividualSprites(into: &atlasData, atlasX: &atlasX, atlasY: &atlasY, spriteSize: spriteSize)
        
        // Then try to load from sprite sheet image
        if let spriteSheetImage = loadSpriteSheet() {
            createAtlasFromImage(spriteSheetImage, into: &atlasData, atlasX: &atlasX, atlasY: &atlasY)
        } else {
            // Fallback to procedural generation for any missing sprites
            createProceduralAtlas(into: &atlasData, atlasX: &atlasX, atlasY: &atlasY)
        }
        
        // Upload final atlas to GPU
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: atlasSize, height: atlasSize, depth: 1)
        )
        texture.replace(region: region, mipmapLevel: 0, withBytes: atlasData, bytesPerRow: atlasSize * 4)
    }
    
    private func loadIndividualSprites(into atlasData: inout [UInt8], atlasX: inout Int, atlasY: inout Int, spriteSize: Int) {
        // Load player sprite
        if let playerImage = loadSpriteImage(filename: "player", fileExtension: "png") {
            if packSpriteIntoAtlas(image: playerImage, name: "player", into: &atlasData, atlasX: &atlasX, atlasY: &atlasY, spriteSize: spriteSize) {
                print("Successfully loaded player sprite")
            }
        }
    }
    
    private func loadSpriteImage(filename: String, fileExtension: String) -> UIImage? {
        guard let imagePath = Bundle.main.path(forResource: filename, ofType: fileExtension) else {
            print("Warning: Could not find sprite image: \(filename).\(fileExtension)")
            return nil
        }
        
        guard let image = UIImage(contentsOfFile: imagePath) else {
            print("Warning: Could not load sprite image: \(filename).\(fileExtension)")
            return nil
        }
        
        return image
    }
    
    private func packSpriteIntoAtlas(image: UIImage, name: String, into atlasData: inout [UInt8], atlasX: inout Int, atlasY: inout Int, spriteSize: Int) -> Bool {
        guard let cgImage = image.cgImage else {
            print("Warning: Could not get CGImage for \(name)")
            return false
        }
        
        // Get actual image size
        let imageWidth = cgImage.width
        let imageHeight = cgImage.height
        
        print("Packing sprite '\(name)': source image is \(imageWidth)x\(imageHeight), target size is \(spriteSize)x\(spriteSize)")
        
        // Scale the image to fit the sprite size if it's larger
        let targetSize = spriteSize
        let scaledImage: UIImage
        
        if imageWidth > targetSize || imageHeight > targetSize {
            // Scale down the image to fit
            let scale = min(Float(targetSize) / Float(imageWidth), Float(targetSize) / Float(imageHeight))
            let scaledWidth = Int(Float(imageWidth) * scale)
            let scaledHeight = Int(Float(imageHeight) * scale)
            
            print("Scaling image from \(imageWidth)x\(imageHeight) to \(scaledWidth)x\(scaledHeight)")
            
            UIGraphicsBeginImageContextWithOptions(CGSize(width: scaledWidth, height: scaledHeight), false, 1.0)
            image.draw(in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
            scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            scaledImage = image
        }
        
        guard let scaledCGImage = scaledImage.cgImage else {
            print("Warning: Could not get scaled CGImage for \(name)")
            return false
        }
        
        let finalWidth = min(targetSize, scaledCGImage.width)
        let finalHeight = min(targetSize, scaledCGImage.height)
        
        // Convert scaled image to pixel data
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = scaledCGImage.width * bytesPerPixel
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: scaledCGImage.width * scaledCGImage.height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: scaledCGImage.width,
            height: scaledCGImage.height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            print("Warning: Could not create CGContext for \(name)")
            return false
        }
        
        context.draw(scaledCGImage, in: CGRect(x: 0, y: 0, width: scaledCGImage.width, height: scaledCGImage.height))
        
        // Center the sprite in the target size (if smaller) or copy the top-left portion
        let offsetX = max(0, (targetSize - finalWidth) / 2)
        let offsetY = max(0, (targetSize - finalHeight) / 2)
        
        // Copy sprite to atlas
        for y in 0..<finalHeight {
            for x in 0..<finalWidth {
                let srcIdx = (y * scaledCGImage.width + x) * bytesPerPixel
                let dstIdx = ((atlasY + offsetY + y) * atlasSize + (atlasX + offsetX + x)) * bytesPerPixel
                
                if dstIdx + 3 < atlasData.count && srcIdx + 3 < pixelData.count {
                    atlasData[dstIdx] = pixelData[srcIdx]     // R
                    atlasData[dstIdx + 1] = pixelData[srcIdx + 1] // G
                    atlasData[dstIdx + 2] = pixelData[srcIdx + 2] // B
                    atlasData[dstIdx + 3] = pixelData[srcIdx + 3] // A
                }
            }
        }
        
        // Store UV rect (always use full spriteSize for consistent sizing)
        let uvRect = Rect(
            x: Float(atlasX) / Float(atlasSize),
            y: Float(atlasY) / Float(atlasSize),
            width: Float(targetSize) / Float(atlasSize),
            height: Float(targetSize) / Float(atlasSize)
        )
        textureRects[name] = uvRect
        
        print("Packed sprite '\(name)' into atlas at (\(atlasX), \(atlasY)), size (\(targetSize), \(targetSize))")
        
        // Move to next position in atlas
        atlasX += spriteSize
        if atlasX + spriteSize > atlasSize {
            atlasX = 0
            atlasY += spriteSize
        }
        
        return true
    }
    
    private func loadSpriteSheet() -> UIImage? {
        guard let imagePath = Bundle.main.path(forResource: "Generated Image December 25, 2025 - 2_20PM", ofType: "png") else {
            print("Warning: Could not find sprite sheet image, falling back to procedural generation")
            return nil
        }
        
        guard let image = UIImage(contentsOfFile: imagePath) else {
            print("Warning: Could not load sprite sheet image, falling back to procedural generation")
            return nil
        }
        
        return image
    }
    
    private func createAtlasFromImage(_ image: UIImage, into atlasData: inout [UInt8], atlasX: inout Int, atlasY: inout Int) {
        // Convert UIImage to pixel data
        guard let cgImage = image.cgImage else {
            print("Warning: Could not get CGImage from sprite sheet")
            return
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.width * bytesPerPixel
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            print("Warning: Could not create CGContext for sprite sheet")
            return
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        // Define sprite layout in the sprite sheet
        // Sprite sheet is 1024x1024, each sprite is 32x32, so 32x32 grid (32 columns, 32 rows)
        let spriteSheetTileSize = 32
        let spritesPerRow = cgImage.width / spriteSheetTileSize
        print("Sprite sheet: \(cgImage.width)x\(cgImage.height), \(spritesPerRow) sprites per row")
        
        // Sprite layout mapping: (row, col) where row 0 is top, col 0 is left
        // The sprite sheet is 1024x1024 = 32 rows x 32 columns of 32x32 sprites
        // Adjust these coordinates based on actual sprite sheet layout
        // Common issue: sprites may be offset by 1-2 rows/cols if there are headers/labels
        
        // Try different layouts - uncomment the one that works, or manually adjust coordinates
        // Layout option 1: Sprites start at (0,0) - current default
        // Layout option 2: Sprites start at row 1 (common if first row is labels/headers)
        // Layout option 3: Different grouping/organization
        
        let spriteLayout: [String: (row: Int, col: Int)] = [
            // TERRAIN TILES - Row 0 (or try row 1 if shifted)
            "grass": (0, 0),
            "dirt": (0, 1),
            "stone": (0, 2),
            "water": (0, 3),
            "sand": (0, 4),
            "iron_ore": (0, 5),
            "copper_ore": (0, 6),
            "coal": (0, 7),
            "tree": (0, 8),
            
            // BUILDINGS - Row 1 (or try row 2 if shifted)
            "belt": (1, 0),
            "inserter": (1, 1),
            "miner": (1, 2),
            "furnace": (1, 3),
            "assembler": (1, 4),
            "power_pole": (1, 5),
            "steam_engine": (1, 6),
            "boiler": (1, 7),
            "lab": (1, 8),
            "turret": (1, 9),
            "wall": (1, 10),
            "chest": (1, 11),
            "pipe": (1, 12),
            "solar_panel": (1, 13),
            "accumulator": (1, 14),
            
            // ENTITIES AND ITEMS - Row 2 (or try row 3 if shifted)
            "biter": (2, 0),
            "spawner": (2, 1),
            "bullet": (2, 2),
            "player": (2, 3),
            "iron_plate": (2, 4),
            "copper_plate": (2, 5),
            "gear": (2, 6),
            "circuit": (2, 7),
            "science_pack_red": (2, 8),
            "science_pack_green": (2, 9),
            
            // UI ELEMENTS - Row 3 (or try row 4 if shifted)
            "solid_white": (3, 0),
            "building_placeholder": (3, 1),
        ]
        
        // Pack sprites into atlas (skip player since it's loaded individually)
        let atlasTileSize = 32
        
        for (spriteName, layout) in spriteLayout.sorted(by: { $0.key < $1.key }) {
            // Skip player sprite if it was already loaded individually
            if spriteName == "player" && textureRects["player"] != nil {
                print("Skipping 'player' from sprite sheet (already loaded individually)")
                continue
            }
            // Calculate actual source position
            // Common sprite sheet layouts may have sprites starting at different rows/columns
            // Try adjusting these offsets if sprites are systematically shifted
            // Since sprites are "mostly shifting", try offset of 1 first (common if header row exists)
            let rowOffset = 1  // Try 0, 1, 2, etc. if sprites are shifted down
            let colOffset = 0  // Try 0, 1, 2, etc. if sprites are shifted right
            
            let actualRow = layout.row + rowOffset
            let actualCol = layout.col + colOffset
            let actualSrcX = actualCol * spriteSheetTileSize
            let actualSrcY = actualRow * spriteSheetTileSize
            
            // Debug: print sprite positions being loaded
            print("Loading sprite '\(spriteName)' from sheet position (row: \(actualRow), col: \(actualCol)) = pixel (\(actualSrcX), \(actualSrcY))")
            
            // Copy sprite from sprite sheet to atlas
            for y in 0..<atlasTileSize {
                for x in 0..<atlasTileSize {
                    // Source pixel in sprite sheet (UIImage uses top-left origin)
                    let srcPixelX = actualSrcX + x
                    let srcPixelY = actualSrcY + y
                    
                    // Check bounds
                    guard srcPixelX < cgImage.width && srcPixelY < cgImage.height else {
                        print("Warning: Sprite '\(spriteName)' at (\(actualSrcX), \(actualSrcY)) extends beyond image bounds")
                        continue
                    }
                    
                    // Calculate pixel index in source image (row-major order)
                    let srcIdx = (srcPixelY * cgImage.width + srcPixelX) * bytesPerPixel
                    let dstIdx = ((atlasY + y) * atlasSize + (atlasX + x)) * bytesPerPixel
                    
                    if dstIdx + 3 < atlasData.count && srcIdx + 3 < pixelData.count {
                        atlasData[dstIdx] = pixelData[srcIdx]     // R
                        atlasData[dstIdx + 1] = pixelData[srcIdx + 1] // G
                        atlasData[dstIdx + 2] = pixelData[srcIdx + 2] // B
                        atlasData[dstIdx + 3] = pixelData[srcIdx + 3] // A
                    }
                }
            }
            
            // Store UV rect for this sprite
            let uvRect = Rect(
                x: Float(atlasX) / Float(atlasSize),
                y: Float(atlasY) / Float(atlasSize),
                width: Float(atlasTileSize) / Float(atlasSize),
                height: Float(atlasTileSize) / Float(atlasSize)
            )
            textureRects[spriteName] = uvRect
            
            // Move to next position in atlas
            atlasX += atlasTileSize
            if atlasX + atlasTileSize > atlasSize {
                atlasX = 0
                atlasY += atlasTileSize
            }
        }
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
    
    private func generatePlayer(width: Int, height: Int, data: inout [UInt8]) {
        // Clear background
        for i in stride(from: 0, to: data.count, by: 4) {
            data[i] = 0; data[i+1] = 0; data[i+2] = 0; data[i+3] = 0
        }
        
        let centerX = width / 2
        let centerY = height / 2
        
        // Body (orange suit like Factorio engineer)
        let bodyRadius = width / 3
        for y in 0..<height {
            for x in 0..<width {
                let dx = x - centerX
                let dy = y - centerY
                if dx * dx + dy * dy <= bodyRadius * bodyRadius {
                    let idx = (y * width + x) * 4
                    data[idx] = 255      // R - pure red
                    data[idx + 1] = 0    // G
                    data[idx + 2] = 0    // B
                    data[idx + 3] = 255  // A
                }
            }
        }
        
        // Head (slightly lighter)
        let headRadius = width / 5
        let headY = centerY - bodyRadius / 2
        for y in 0..<height {
            for x in 0..<width {
                let dx = x - centerX
                let dy = y - headY
                if dx * dx + dy * dy <= headRadius * headRadius {
                    let idx = (y * width + x) * 4
                    data[idx] = 255      // R - white
                    data[idx + 1] = 255  // G
                    data[idx + 2] = 255  // B
                    data[idx + 3] = 255
                }
            }
        }
    }
    
    private func generateSolidWhite(width: Int, height: Int, data: inout [UInt8]) {
        // Solid white texture for UI backgrounds - just fill with white
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                data[idx] = 255     // R
                data[idx + 1] = 255 // G
                data[idx + 2] = 255 // B
                data[idx + 3] = 255 // A
            }
        }
    }

    private func generateBuildingPlaceholder(width: Int, height: Int, data: inout [UInt8]) {
        // Simple building placeholder - gray square with darker border
        let borderWidth = 2
        let innerColor: (r: UInt8, g: UInt8, b: UInt8) = (150, 150, 150) // Light gray
        let borderColor: (r: UInt8, g: UInt8, b: UInt8) = (100, 100, 100) // Dark gray

        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                let isBorder = x < borderWidth || x >= width - borderWidth ||
                              y < borderWidth || y >= height - borderWidth

                if isBorder {
                    data[idx] = borderColor.r
                    data[idx + 1] = borderColor.g
                    data[idx + 2] = borderColor.b
                    data[idx + 3] = 255
                } else {
                    data[idx] = innerColor.r
                    data[idx + 1] = innerColor.g
                    data[idx + 2] = innerColor.b
                    data[idx + 3] = 255
                }
            }
        }
    }

    private func createProceduralAtlas(into atlasData: inout [UInt8], atlasX: inout Int, atlasY: inout Int) {
        // Generate procedural textures and pack into atlas (only for sprites not already loaded)
        let tileSize = 32
        var currentX = atlasX
        var currentY = atlasY
        
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
            ("science_pack_green", generateSciencePackGreen),
            ("player", generatePlayer),
            ("solid_white", generateSolidWhite),
            ("building_placeholder", generateBuildingPlaceholder)
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
        
        // Update shared position
        atlasX = currentX
        atlasY = currentY
    }
}

