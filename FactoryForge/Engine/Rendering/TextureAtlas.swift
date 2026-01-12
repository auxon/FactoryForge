import Metal
import MetalKit
import UIKit // Add this import

/// Manages texture atlases for efficient rendering
final class TextureAtlas {
    private let device: MTLDevice
    private var textures: [String: MTLTexture] = [:]
    private var textureRects: [String: Rect] = [:]
    private var textureSizes: [String: (width: Int, height: Int)] = [:]
    
    // Main atlas texture
    private(set) var atlasTexture: MTLTexture?
    private let atlasSize: Int = 8192
    
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
        // This includes player.png and player_left.png which extract all frames
        loadIndividualSprites(into: &atlasData, atlasX: &atlasX, atlasY: &atlasY, spriteSize: spriteSize)
        
        // Fallback to procedural generation for any missing sprites
        createProceduralAtlas(into: &atlasData, atlasX: &atlasX, atlasY: &atlasY)
        
        // Upload final atlas to GPU
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: atlasSize, height: atlasSize, depth: 1)
        )
        texture.replace(region: region, mipmapLevel: 0, withBytes: atlasData, bytesPerRow: atlasSize * 4)
    }
    
    private func loadIndividualSprites(into atlasData: inout [UInt8], atlasX: inout Int, atlasY: inout Int, spriteSize: Int) {
        // List of sprite files to load with their textureId mappings
        // Format: (filename, textureId) - if textureId is nil, uses filename
        let spriteFiles: [(filename: String, textureId: String?)] = [
            // UI - FIRST for stable atlas packing (variable widths affect subsequent textures)
            ("building_placeholder", nil),
            ("delete_game", nil),
            ("inventory", nil),
            ("gear", nil),
            ("rotate", nil),
            ("assembler", nil),
            ("load_game", nil),
            ("menu", nil),
            ("build", nil),
            ("research", nil),
            ("new_game", nil),
            ("save_game", nil),
            ("help", nil),
            ("buy", nil),
            ("recycle", nil),
            ("move", nil),
            ("disable_audio", nil),
            ("right_arrow", nil),
            ("cancel_button", nil),
            ("trash", nil),
            ("solid_white", nil),

            // Entities (load sprite sheets first - they extract all frames)
            ("player", nil),
            ("player_left", nil),
            ("biter_left", nil),
            ("biter_right", nil),
            ("biter", nil),
            ("spawner", nil),
            ("bullet", nil),
            ("bullet_up", nil),
            ("bullet_down", nil),
            ("bullet_left", nil),
            ("bullet_right", nil),
            
            // Terrain (try regular version first, fallback to _2 if needed)
            ("grass", nil),
            ("dirt", nil),
            ("stone", nil),  // Try stone.png first, will handle _2 in loading logic
            ("water", nil),
            ("sand", nil),
            ("iron_ore", nil),  // Try iron_ore.png first
            ("copper_ore", nil),
            ("coal", nil),  // Try coal.png first
            ("tree", nil),
            
            // Buildings - Mining
            ("burner_miner_drill", "burner_mining_drill"),  // Handle typo in filename
            ("electric_mining_drill", nil),
            
            // Buildings - Smelting
            ("stone_furnace", nil),
            ("steel_furnace", nil),
            ("electric_furnace", nil),
            
            // Buildings - Crafting
            ("assembling_machine_1", nil),
            ("assembling_machine_2", nil),
            ("assembling_machine_3", nil),
            
            // Buildings - Belts
            ("transport_belt", nil),
            ("fast_transport_belt", nil),
            ("express_transport_belt", nil),

            // Belt animation frames
            ("transport_belt_animation", nil),

            // Advanced Belts
            ("underground_belt", nil),
            ("splitter", nil),
            ("merger", nil),
            ("belt_bridge", nil),
            
            // Buildings - Inserters
            ("inserter", nil),
            ("long_handed_inserter", nil),
            ("fast_inserter", nil),
            ("inserters_sheet", nil),
            ("inserter_input_button", nil),
            ("inserter_output_button", nil),
            ("inserter_cancel_button", nil),
            ("clear", nil),

            // Buildings - Storage
            ("wooden_chest", nil),
            ("iron_chest", nil),
            ("steel_chest", nil),
            
            // Buildings - Power
            ("boiler", nil),
            ("steam_engine", nil),
            ("solar_panel", nil),
            ("accumulator", nil),
            ("small_electric_pole", nil),
            ("medium_electric_pole", nil),
            ("big_electric_pole", nil),
            
            // Buildings - Research
            ("lab", nil),
            
            // Buildings - Combat
            ("gun_turret", nil),
            ("laser_turret", nil),
            ("stone_wall", nil),
            ("wall", nil),
            ("radar", nil),
            
            // Buildings - Fluids
            ("pipe", nil),
            ("pipe_2", nil),
            ("underground_pipe", nil),
            ("oil_well", nil),
            ("oil_refinery", nil),
            ("chemical_plant", nil),
            ("water_pump", nil),
            ("sulfuric_acid", nil),
            ("petroleum_gas", nil),
            
            // Items - Raw Materials (wood handled with fallback logic above)
            ("wood", nil),
            ("crude_oil", nil),
            ("uranium_ore", nil),
            
            // Items - Intermediate
            ("iron_plate", nil),
            ("copper_plate", nil),
            ("steel_plate", nil),
            ("stone_brick", nil),
            ("iron_gear_wheel", nil),
            ("copper_cable", nil),
            ("electronic_circuit", nil),
            ("advanced_circuit", nil),
            ("processing_unit", nil),
            ("engine_unit", nil),
            ("electric_engine_unit", nil),
            
            // Items - Science Packs
            ("automation_science_pack", nil),
            ("logistic_science_pack", nil),
            ("military_science_pack", nil),
            ("chemical_science_pack", nil),
            ("production_science_pack", nil),
            ("utility_science_pack", nil),
            
            // Items - Combat
            ("firearm_magazine", nil),
            ("piercing_rounds_magazine", nil),
            ("grenade", nil),

            // Build menu categories non-duplicates only
            ("miner", nil),
            ("furnace", nil),
            ("belt", nil),
            ("power_pole", nil),
            ("turret", nil),
            ("chest", nil),

            // Advanced items
            ("stack-inserter", nil),
            ("centrifuge", nil),
            ("nuclear-reactor", nil),
            ("processing-unit", nil),
            ("plastic-bar", nil),
            ("sulfur", nil),
            ("battery", nil),
            ("explosives", nil),
            ("uranium-ore", nil),
            ("uranium-235", nil),
            ("uranium-238", nil),
            ("nuclear-fuel", nil),
            ("rocket-silo", nil),
            ("rocket-fuel", nil),
            ("rocket-part", nil),
            ("satellite", nil),
            ("low-density-structure", nil),
            ("solid-fuel", nil),
        ]
        
        print("Loading \(spriteFiles.count) sprite files...")
        
        for (filename, textureIdOverride) in spriteFiles {
            let textureId = textureIdOverride ?? filename
            
            // Try to load the sprite (try _2 version as fallback for certain files)
            var image: UIImage? = loadSpriteImage(filename: filename, fileExtension: "png")
            
            // Fallback to _2 version for files that commonly have duplicates
            if image == nil && ["stone", "coal", "iron_ore", "wood"].contains(filename) {
                let fallbackName = "\(filename)_2"
                image = loadSpriteImage(filename: fallbackName, fileExtension: "png")
                if image != nil {
                    print("  Using fallback: \(fallbackName).png for \(filename)")
                }
            }
            
            if let image = image {
                if textureId == "transport_belt_animation" {
                    print("🎬 Processing transport_belt_animation.png...")
                }

                // UI buttons need larger slots to preserve quality (they're 805x279px)
                let uiButtonNames = ["new_game", "save_game", "load_game", "delete_game"]
                // Bullet images use their actual size (not forced to 32x32)
                let bulletNames = ["bullet", "bullet_up", "bullet_down", "bullet_left", "bullet_right"]
                // Multi-tile buildings use their actual size to prevent distortion
                let multiTileBuildings = [
                    "assembling_machine_1", "assembling_machine_2", "assembling_machine_3",
                    "electric_mining_drill", "electric_furnace", "burner_miner_drill",
                    "burner_mining_drill", "stone_furnace", "steel_furnace",
                    "lab", "solar_panel", "boiler", "steam_engine",
                    "gun_turret", "laser_turret", "radar", "oil_refinery", "chemical_plant"
                ]
                let buttonSpriteSize = uiButtonNames.contains(textureId) ? 256 : spriteSize
                let useActualSize = bulletNames.contains(textureId)
                let scaleDownMultiTile = multiTileBuildings.contains(textureId)

                if scaleDownMultiTile {
                    // Processing multi-tile building
                }

                if packSpriteIntoAtlas(image: image, name: textureId, into: &atlasData, atlasX: &atlasX, atlasY: &atlasY, spriteSize: buttonSpriteSize, useActualSize: useActualSize, scaleDownMultiTile: scaleDownMultiTile) {
                    if textureId == "transport_belt_animation" {
                        print("✓ Successfully processed transport_belt_animation.png")
                    } else if textureId == "merger" {
                        print("✓ Loaded merger: \(filename).png -> textureId: \(textureId)")
                    } else {
                        print("✓ Loaded: \(filename).png -> textureId: \(textureId)")
                    }
                } else {
                    if textureId == "transport_belt_animation" {
                        print("✗ Failed to process transport_belt_animation.png")
                    } else {
                        print("✗ Failed to pack: \(filename).png")
                    }
                }
            } else {
                print("✗ Could not load: \(filename).png (textureId: \(textureId))")
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
    
    private func packSpriteIntoAtlas(image: UIImage, name: String, into atlasData: inout [UInt8], atlasX: inout Int, atlasY: inout Int, spriteSize: Int, skipBorderCrop: Bool = false, useActualSize: Bool = false, scaleDownMultiTile: Bool = false) -> Bool {
        if name.contains("transport_belt") {
            print("🎨 Packing belt texture: \(name), size: \(image.size), skipBorderCrop: \(skipBorderCrop), useActualSize: \(useActualSize)")
        }

        guard let cgImage = image.cgImage else {
            print("Warning: Could not get CGImage for \(name)")
            return false
        }

        if name.contains("transport_belt") {
            print("  CGImage size: \(cgImage.width)x\(cgImage.height)")
        }
        
        // UI button names (define once at function start)
        let uiButtonNames = ["new_game", "save_game", "load_game", "delete_game", "inserter_input_button", "inserter_output_button", "inserter_cancel_button"]
        
        // Get actual image size
        let imageWidth = cgImage.width
        let imageHeight = cgImage.height
        let targetSize = spriteSize
        let processedImage: UIImage
        
        // Check if this is a sprite sheet with animations (player or biter)
        // Player and biter sprite sheets are 1024x1024 with 4x4 grid (16 frames, each 256x256)
        if (name == "player" || name == "player_left") && imageWidth == 1024 && imageHeight == 1024 {
            // Load all 16 frames from 4x4 grid for player
            let frameSize = 256  // 1024 / 4 = 256
            let framesPerRow = 4
            let prefix = name == "player_left" ? "player_left" : "player"

            for frameIndex in 0..<16 {
                let row = frameIndex / framesPerRow
                let col = frameIndex % framesPerRow
                let frameX = col * frameSize
                let frameY = row * frameSize
                let frameRect = CGRect(x: frameX, y: frameY, width: frameSize, height: frameSize)

                if let croppedCGImage = cgImage.cropping(to: frameRect) {
                    let frameImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
                    let frameName = "\(prefix)_\(frameIndex)"

                    // Pack this frame into the atlas (skip border crop since it's already extracted)
                    if packSpriteIntoAtlas(image: frameImage, name: frameName, into: &atlasData, atlasX: &atlasX, atlasY: &atlasY, spriteSize: spriteSize, skipBorderCrop: true, useActualSize: false, scaleDownMultiTile: false) {
                    }
                }
            }

            // All frames have been loaded into the atlas, return false to indicate this was handled separately
            return false
        } else if name == "transport_belt_animation" && imageWidth == 1024 && imageHeight == 1024 {
            print("🎬 Processing transport_belt_animation.png sprite sheet (\(imageWidth)x\(imageHeight)) - extracting 4x4 grid of 256x256 frames")

            // Based on user correction: "4x4 256x256 pixels"
            // 4x4 grid of 256x256 pixel frames = 16 frames total (1024/4 = 256)
            let frameSize = 256
            let framesPerRow = 4
            let directions = ["north", "east", "south", "west"]

            // Extract 16 frames from the 4x4 grid
            var frameCount = 0

            for row in 0..<framesPerRow {
                for col in 0..<framesPerRow {
                    let frameX = col * frameSize
                    let frameY = row * frameSize
                    let frameRect = CGRect(x: frameX, y: frameY, width: frameSize, height: frameSize)

                    if let croppedCGImage = cgImage.cropping(to: frameRect) {
                        // Check if this frame has visible pixels
                        let hasVisiblePixels = checkForVisiblePixels(in: croppedCGImage)

                        if hasVisiblePixels {
                            let directionIndex = frameCount / 4  // 4 frames per direction
                            let frameIndex = (frameCount % 4) + 1  // 1-based

                            if directionIndex < directions.count {
                                let direction = directions[directionIndex]
                                let frameImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
                                let frameName = "transport_belt_\(direction)_\(String(format: "%03d", frameIndex))"

                                print("    Processing frame \(frameCount) at (\(frameX),\(frameY)) -> \(frameName) (direction: \(direction), frame: \(frameIndex))")

                                if packSpriteIntoAtlas(image: frameImage, name: frameName, into: &atlasData, atlasX: &atlasX, atlasY: &atlasY, spriteSize: spriteSize, skipBorderCrop: true, useActualSize: false, scaleDownMultiTile: false) {
                                    print("    ✓ Loaded \(frameName)")
                                } else {
                                    print("    ✗ Failed to load \(frameName)")
                                }
                            }
                            frameCount += 1
                        } else {
                            print("    Skipping empty frame at (\(frameX),\(frameY))")
                        }
                    } else {
                        print("    ✗ Failed to crop frame at (\(frameX),\(frameY))")
                    }
                }
            }

            print("✓ Finished processing transport_belt_animation sprite sheet - loaded \(frameCount) valid frames")

            if frameCount < 16 {
                print("⚠️ Only found \(frameCount) valid frames, falling back to existing belt texture")
                // Fallback: use existing belt texture
                if let existingBeltRect = textureRects["transport_belt"] {
                    let directions = ["north", "east", "south", "west"]
                    for direction in directions {
                        for i in 1...16 {
                            let frameName = "transport_belt_\(direction)_\(String(format: "%03d", i))"
                            textureRects[frameName] = existingBeltRect
                        }
                    }
                }
            }

            return false
        } else if name == "inserters_sheet" && imageWidth == 1024 && imageHeight == 1024 {
            // Load all 16 frames from 4x4 grid for inserters (256x256 frames each)
            let frameSize = 256  // Each sprite is 256x256 pixels
            let framesPerRow = 4
            let prefix = "inserter"

            for frameIndex in 0..<16 {
                let row = frameIndex / framesPerRow
                let col = frameIndex % framesPerRow
                let frameX = col * frameSize
                let frameY = row * frameSize
                let frameRect = CGRect(x: frameX, y: frameY, width: frameSize, height: frameSize)

                if let croppedCGImage = cgImage.cropping(to: frameRect) {
                    let frameImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
                    let frameName = "\(prefix)_\(frameIndex)"

                    // Pack this frame into the atlas (skip border crop since it's already extracted)
                    if packSpriteIntoAtlas(image: frameImage, name: frameName, into: &atlasData, atlasX: &atlasX, atlasY: &atlasY, spriteSize: spriteSize, skipBorderCrop: true, useActualSize: false, scaleDownMultiTile: false) {
                    }
                }
            }

            // All frames have been loaded into the atlas, return false to indicate this was handled separately
            return false
        } else if (name == "biter_left" || name == "biter_right") && imageWidth == 1024 && imageHeight == 1024 {
            // Load all 16 frames from 4x4 grid for biter (256x256 frames, same as player)
            let frameSize = 256  // 1024 / 4 = 256
            let framesPerRow = 4
            let prefix = name == "biter_left" ? "biter_left" : "biter_right"

            for frameIndex in 0..<16 {
                let row = frameIndex / framesPerRow
                let col = frameIndex % framesPerRow
                let frameX = col * frameSize
                let frameY = row * frameSize
                let frameRect = CGRect(x: frameX, y: frameY, width: frameSize, height: frameSize)

                if let croppedCGImage = cgImage.cropping(to: frameRect) {
                    let frameImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
                    let frameName = "\(prefix)_\(frameIndex)"

                    // Pack this frame into the atlas (skip border crop since it's already extracted)
                    if packSpriteIntoAtlas(image: frameImage, name: frameName, into: &atlasData, atlasX: &atlasX, atlasY: &atlasY, spriteSize: spriteSize, skipBorderCrop: true, useActualSize: false, scaleDownMultiTile: false) {
                    }
                }
            }

            // All frames have been loaded into the atlas, return false to indicate this was handled separately
            return false
        } else if imageWidth > targetSize || imageHeight > targetSize {
            // Handle UI buttons specially - scale to larger size preserving aspect ratio
            if uiButtonNames.contains(name) {
                // UI buttons: scale to targetSize height, preserve aspect ratio
                let aspectRatio = Float(imageWidth) / Float(imageHeight)
                let scaledHeight = targetSize
                let scaledWidth = Int(Float(scaledHeight) * aspectRatio)
                
                UIGraphicsBeginImageContextWithOptions(CGSize(width: scaledWidth, height: scaledHeight), false, 1.0)
                image.draw(in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
                processedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
                UIGraphicsEndImageContext()
            } else if scaleDownMultiTile {
                // Multi-tile buildings: use optimized scaling for space efficiency
                let multiTileSize = 384  // Use 384x384 to balance quality and space
                let scale = min(Float(multiTileSize) / Float(imageWidth), Float(multiTileSize) / Float(imageHeight))
                let scaledWidth = Int(Float(imageWidth) * scale)
                let scaledHeight = Int(Float(imageHeight) * scale)

                // Use higher quality scaling
                UIGraphicsBeginImageContextWithOptions(CGSize(width: scaledWidth, height: scaledHeight), false, 1.0)
                let context = UIGraphicsGetCurrentContext()
                context?.interpolationQuality = .high
                context?.setShouldAntialias(true)
                image.draw(in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
                processedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
                UIGraphicsEndImageContext()
            } else if useActualSize {
                // Bullet images: use actual size, only scale down if too large
                if imageWidth > targetSize || imageHeight > targetSize {
                    let scale = min(Float(targetSize) / Float(imageWidth), Float(targetSize) / Float(imageHeight))
                    let scaledWidth = Int(Float(imageWidth) * scale)
                    let scaledHeight = Int(Float(imageHeight) * scale)

                    UIGraphicsBeginImageContextWithOptions(CGSize(width: scaledWidth, height: scaledHeight), false, 1.0)
                    image.draw(in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
                    processedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
                    UIGraphicsEndImageContext()
                } else {
                    processedImage = image
                }
            } else if skipBorderCrop {
                // Scale directly without cropping borders
                let scale = min(Float(targetSize) / Float(imageWidth), Float(targetSize) / Float(imageHeight))
                let scaledWidth = Int(Float(imageWidth) * scale)
                let scaledHeight = Int(Float(imageHeight) * scale)
                
                UIGraphicsBeginImageContextWithOptions(CGSize(width: scaledWidth, height: scaledHeight), false, 1.0)
                image.draw(in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
                processedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
                UIGraphicsEndImageContext()
            } else {
                // Crop pixels from each side to remove transparent borders
                // Use a percentage-based crop for better results across different image sizes
                let cropPercentage: Float = 0.20  // Crop 20% from each side (30% total removed)
                let borderCropX = Int(Float(imageWidth) * cropPercentage)
                let borderCropY = Int(Float(imageHeight) * cropPercentage)
                let cropX = borderCropX
                let cropY = borderCropY
                let cropWidth = imageWidth - (borderCropX * 2)
                let cropHeight = imageHeight - (borderCropY * 2)
                
                // Extract center region (excluding borders)
                if let croppedCGImage = cgImage.cropping(to: CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)) {
                    let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
                    
                    // Scale the cropped image to target size
                    let scale = min(Float(targetSize) / Float(cropWidth), Float(targetSize) / Float(cropHeight))
                    let scaledWidth = Int(Float(cropWidth) * scale)
                    let scaledHeight = Int(Float(cropHeight) * scale)
                    
                    UIGraphicsBeginImageContextWithOptions(CGSize(width: scaledWidth, height: scaledHeight), false, 1.0)
                    croppedImage.draw(in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
                    processedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
                    UIGraphicsEndImageContext()
                } else {
                    // Fallback to normal scaling if cropping fails
                    let scale = min(Float(targetSize) / Float(imageWidth), Float(targetSize) / Float(imageHeight))
                    let scaledWidth = Int(Float(imageWidth) * scale)
                    let scaledHeight = Int(Float(imageHeight) * scale)
                    
                    UIGraphicsBeginImageContextWithOptions(CGSize(width: scaledWidth, height: scaledHeight), false, 1.0)
                    image.draw(in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
                    processedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
                    UIGraphicsEndImageContext()
                }
            }
        } else {
            processedImage = image
        }
        
        guard let processedCGImage = processedImage.cgImage else {
            print("Warning: Could not get processed CGImage for \(name)")
            return false
        }

        if name.contains("transport_belt") {
            print("  Processed CGImage size: \(processedCGImage.width)x\(processedCGImage.height)")
        }
        
        // For UI buttons and bullets, keep their aspect ratio; for others, scale to square targetSize
        let finalImage: UIImage
        if uiButtonNames.contains(name) {
            // UI buttons: keep aspect ratio, use actual processed size
            finalImage = processedImage
        } else if scaleDownMultiTile {
            // Multi-tile buildings: already scaled appropriately, use as-is
            finalImage = processedImage
        } else if useActualSize {
            // Bullet images: use actual size without scaling
            finalImage = processedImage
        } else {
            // Other sprites: scale to square targetSize
            
            if processedCGImage.width != targetSize || processedCGImage.height != targetSize {
                // Scale to exactly targetSize
                UIGraphicsBeginImageContextWithOptions(CGSize(width: targetSize, height: targetSize), false, 1.0)
                processedImage.draw(in: CGRect(x: 0, y: 0, width: targetSize, height: targetSize))
                finalImage = UIGraphicsGetImageFromCurrentImageContext() ?? processedImage
                UIGraphicsEndImageContext()
            } else {
                finalImage = processedImage
            }
        }
        
        guard let finalCGImage = finalImage.cgImage else {
            print("Warning: Could not get final CGImage for \(name)")
            return false
        }
        
        // Convert final image to pixel data
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = finalCGImage.width * bytesPerPixel
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: finalCGImage.width * finalCGImage.height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: finalCGImage.width,
            height: finalCGImage.height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            print("Warning: Could not create CGContext for \(name)")
            return false
        }
        
        context.draw(finalCGImage, in: CGRect(x: 0, y: 0, width: finalCGImage.width, height: finalCGImage.height))
        
        // Copy sprite to atlas (use actual final image size)
        let copyWidth = finalCGImage.width
        let copyHeight = finalCGImage.height
        
        for y in 0..<copyHeight {
            for x in 0..<copyWidth {
                let srcIdx = (y * finalCGImage.width + x) * bytesPerPixel
                let dstX = atlasX + x
                let dstY = atlasY + y
                let dstIdx = (dstY * atlasSize + dstX) * bytesPerPixel
                
                if dstIdx + 3 < atlasData.count && srcIdx + 3 < pixelData.count && dstX < atlasSize && dstY < atlasSize {
                    atlasData[dstIdx] = pixelData[srcIdx]     // R
                    atlasData[dstIdx + 1] = pixelData[srcIdx + 1] // G
                    atlasData[dstIdx + 2] = pixelData[srcIdx + 2] // B
                    atlasData[dstIdx + 3] = pixelData[srcIdx + 3] // A
                }
            }
        }
        
        // Store UV rect (use actual image size)
        let uvRect = Rect(
            x: Float(atlasX) / Float(atlasSize),
            y: Float(atlasY) / Float(atlasSize),
            width: Float(copyWidth) / Float(atlasSize),
            height: Float(copyHeight) / Float(atlasSize)
        )
        textureRects[name] = uvRect
        textureSizes[name] = (width: copyWidth, height: copyHeight)

        
        // Move to next position in atlas (UI buttons and bullets use actual size)
        if uiButtonNames.contains(name) {
            // UI buttons: force to next row to avoid overlap with other sprites
            atlasX = 0
            atlasY += spriteSize
        } else if useActualSize {
            // Bullet images: advance by actual width (rounded up to next multiple of 4 for alignment)
            let advanceWidth = ((copyWidth + 3) / 4) * 4  // Round up to multiple of 4
            atlasX += advanceWidth
            if atlasX + spriteSize > atlasSize {
                atlasX = 0
                atlasY += max(spriteSize, ((copyHeight + 3) / 4) * 4)  // Round up height too
            }
        } else if scaleDownMultiTile {
            // Multi-tile buildings: take entire rows exclusively to prevent any overlap
            atlasX = 0
            atlasY += 384  // Match the 384x384 texture size
        } else {
            // Regular sprites: advance by spriteSize
            atlasX += spriteSize
            if atlasX + spriteSize > atlasSize {
                atlasX = 0
                atlasY += spriteSize
            }
        }

        if name.contains("transport_belt") {
            print("  ✓ Successfully packed \(name) into atlas at (\(atlasX),\(atlasY))")
        }

        return true
    }
    
    private func checkForVisiblePixels(in cgImage: CGImage) -> Bool {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data else {
            return false
        }

        let length = CFDataGetLength(data)
        let bytesPerPixel = 4 // RGBA
        let pixelCount = length / bytesPerPixel

        // Sample a few pixels to check for visibility
        let sampleCount = min(100, pixelCount) // Check up to 100 pixels
        let step = max(1, pixelCount / sampleCount)

        for i in stride(from: 0, to: pixelCount, by: step) {
            let pixelStart = i * bytesPerPixel
            if pixelStart + 3 < length {
                // Check alpha channel (index 3 in RGBA)
                let alpha: UInt8 = CFDataGetBytePtr(data)![pixelStart + 3]
                if alpha > 10 { // More than 10/255 alpha
                    return true
                }
            }
        }

        return false
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
            "spawner": (2, 0),
            "bullet": (2, 1),
            "player": (2, 2),
            "iron_plate": (2, 3),
            "copper_plate": (2, 4),
            "gear": (2, 5),
            "circuit": (2, 6),
            "science_pack_red": (2, 7),
            "science_pack_green": (2, 8),
            
            // UI ELEMENTS - Row 3 (or try row 4 if shifted)
            "solid_white": (3, 0),
            "building_placeholder": (3, 1),
        ]
        
        // Pack sprites into atlas (skip player since it's loaded individually)
        let atlasTileSize = 32
        
        for (spriteName, layout) in spriteLayout.sorted(by: { $0.key < $1.key }) {
            // Skip player and biter sprites if they were already loaded individually
            if (spriteName == "player" || spriteName == "biter") && textureRects[spriteName] != nil {
                print("Skipping '\(spriteName)' from sprite sheet (already loaded individually)")
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

    /// Checks if a texture exists in the atlas
    func hasTexture(_ name: String) -> Bool {
        return textureRects[name] != nil
    }

    func getTextureRect(for name: String) -> Rect {
        if let rect = textureRects[name] {
            return rect
        } else {
            // Debug: print warning if texture not found
            print("Warning: Texture '\(name)' not found in atlas, using default rect")
            return Rect(x: 0, y: 0, width: 1, height: 1)
        }
    }

    func getTextureSize(for name: String) -> (width: Int, height: Int)? {
        return textureSizes[name]
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
            // Skip if already loaded from sprite files
            guard textureRects[name] == nil else {
                continue
            }
            
            // Generate the tile
            var tileData = [UInt8](repeating: 0, count: tileSize * tileSize * 4)
            generator(tileSize, tileSize, &tileData)

            // Check bounds before copying
            if currentY + tileSize > atlasSize {
                print("Warning: Procedural texture \(name) would exceed atlas bounds vertically")
                continue
            }

            // Copy to atlas
            for y in 0..<tileSize {
                for x in 0..<tileSize {
                    let srcIdx = (y * tileSize + x) * 4
                    let dstIdx = ((currentY + y) * atlasSize + (currentX + x)) * 4

                    // Double-check bounds
                    if dstIdx + 3 < atlasData.count {
                        atlasData[dstIdx] = tileData[srcIdx]
                        atlasData[dstIdx + 1] = tileData[srcIdx + 1]
                        atlasData[dstIdx + 2] = tileData[srcIdx + 2]
                        atlasData[dstIdx + 3] = tileData[srcIdx + 3]
                    }
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

            // Debug UV coordinates for UI textures
            if ["new_game", "save_game", "load_game", "delete_game", "menu", "solid_white", "building_placeholder", "merger"].contains(name) {
                print("DEBUG: \(name) UV rect: x=\(uvRect.origin.x), y=\(uvRect.origin.y), w=\(uvRect.size.x), h=\(uvRect.size.y)")
            }

        // Debug UV coordinates for UI textures
        if ["new_game", "save_game", "load_game", "delete_game", "menu", "solid_white", "building_placeholder", "merger"].contains(name) {
            print("DEBUG: \(name) UV rect: x=\(uvRect.origin.x), y=\(uvRect.origin.y), w=\(uvRect.size.x), h=\(uvRect.size.y)")
        }

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

