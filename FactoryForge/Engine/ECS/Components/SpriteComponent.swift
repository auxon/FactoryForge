import Foundation

/// Visual representation of an entity
struct SpriteComponent: Component {
    /// Texture identifier in the atlas
    var textureId: String
    
    /// Size in world units (tiles)
    var size: Vector2
    
    /// Color tint
    var tint: Color
    
    /// Render layer
    var layer: RenderLayer
    
    /// Animation state
    var animation: SpriteAnimation?
    
    /// Whether the sprite should flip horizontally
    var flipX: Bool
    
    /// Whether the sprite should flip vertically
    var flipY: Bool
    
    /// Whether the sprite is centered on its position (true) or has origin at bottom-left (false)
    var centered: Bool
    
    init(textureId: String, size: Vector2 = Vector2(1, 1), tint: Color = .white,
         layer: RenderLayer = .entity, flipX: Bool = false, flipY: Bool = false, centered: Bool = false) {
        self.textureId = textureId
        self.size = size
        self.tint = tint
        self.layer = layer
        self.animation = nil
        self.flipX = flipX
        self.flipY = flipY
        self.centered = centered
    }
}

/// Animation state for sprites
struct SpriteAnimation: Codable {
    var frames: [String]
    var frameTime: Float
    var currentFrame: Int
    var elapsedTime: Float
    var isLooping: Bool
    var isPlaying: Bool
    
    init(frames: [String], frameTime: Float = 0.1, isLooping: Bool = true) {
        self.frames = frames
        self.frameTime = frameTime
        self.currentFrame = 0
        self.elapsedTime = 0
        self.isLooping = isLooping
        self.isPlaying = true
    }
    
    mutating func update(deltaTime: Float) -> String? {
        guard isPlaying && !frames.isEmpty else { return nil }
        
        elapsedTime += deltaTime
        
        if elapsedTime >= frameTime {
            elapsedTime -= frameTime
            currentFrame += 1
            
            if currentFrame >= frames.count {
                if isLooping {
                    currentFrame = 0
                } else {
                    currentFrame = frames.count - 1
                    isPlaying = false
                }
            }
        }
        
        return frames[currentFrame]
    }
    
    mutating func play() {
        isPlaying = true
    }
    
    mutating func pause() {
        isPlaying = false
    }
    
    mutating func reset() {
        currentFrame = 0
        elapsedTime = 0
        isPlaying = true
    }
}

