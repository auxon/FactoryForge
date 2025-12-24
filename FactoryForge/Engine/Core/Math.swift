import Foundation
import simd

// MARK: - Vector Types
typealias Vector2 = SIMD2<Float>
typealias Vector3 = SIMD3<Float>
typealias Vector4 = SIMD4<Float>
typealias Matrix4 = simd_float4x4

// MARK: - Vector2 Extensions
extension Vector2 {
    static let zero = Vector2(0, 0)
    static let one = Vector2(1, 1)
    static let up = Vector2(0, 1)
    static let down = Vector2(0, -1)
    static let left = Vector2(-1, 0)
    static let right = Vector2(1, 0)
    
    var length: Float {
        return simd_length(self)
    }
    
    var lengthSquared: Float {
        return simd_length_squared(self)
    }
    
    var normalized: Vector2 {
        let len = length
        return len > 0 ? self / len : .zero
    }
    
    func distance(to other: Vector2) -> Float {
        return simd_distance(self, other)
    }
    
    func dot(_ other: Vector2) -> Float {
        return simd_dot(self, other)
    }
    
    func lerp(to other: Vector2, t: Float) -> Vector2 {
        return simd_mix(self, other, Vector2(repeating: t))
    }
    
    func rotated(by angle: Float) -> Vector2 {
        let cos = cosf(angle)
        let sin = sinf(angle)
        return Vector2(x * cos - y * sin, x * sin + y * cos)
    }
    
    var angle: Float {
        return atan2f(y, x)
    }
}

// MARK: - Integer Vector
struct IntVector2: Hashable, Codable {
    var x: Int32
    var y: Int32
    
    static let zero = IntVector2(x: 0, y: 0)
    
    init(x: Int32, y: Int32) {
        self.x = x
        self.y = y
    }
    
    init(_ x: Int, _ y: Int) {
        self.x = Int32(x)
        self.y = Int32(y)
    }
    
    init(from vector: Vector2) {
        self.x = Int32(floorf(vector.x))
        self.y = Int32(floorf(vector.y))
    }
    
    var toVector2: Vector2 {
        return Vector2(Float(x), Float(y))
    }
    
    static func + (lhs: IntVector2, rhs: IntVector2) -> IntVector2 {
        return IntVector2(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func - (lhs: IntVector2, rhs: IntVector2) -> IntVector2 {
        return IntVector2(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    static func * (lhs: IntVector2, rhs: Int32) -> IntVector2 {
        return IntVector2(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}

// MARK: - Matrix Extensions
extension Matrix4 {
    static var identity: Matrix4 {
        return matrix_identity_float4x4
    }
    
    static func translation(_ translation: Vector3) -> Matrix4 {
        var matrix = Matrix4.identity
        matrix.columns.3 = Vector4(translation.x, translation.y, translation.z, 1)
        return matrix
    }
    
    static func translation(_ translation: Vector2) -> Matrix4 {
        return translation(Vector3(translation.x, translation.y, 0))
    }
    
    static func scale(_ scale: Vector3) -> Matrix4 {
        var matrix = Matrix4.identity
        matrix.columns.0.x = scale.x
        matrix.columns.1.y = scale.y
        matrix.columns.2.z = scale.z
        return matrix
    }
    
    static func scale(_ scale: Float) -> Matrix4 {
        return Matrix4.scale(Vector3(repeating: scale))
    }
    
    static func scale(_ scale: Vector2) -> Matrix4 {
        return Matrix4.scale(Vector3(scale.x, scale.y, 1))
    }
    
    static func rotationZ(_ angle: Float) -> Matrix4 {
        let cos = cosf(angle)
        let sin = sinf(angle)
        var matrix = Matrix4.identity
        matrix.columns.0.x = cos
        matrix.columns.0.y = sin
        matrix.columns.1.x = -sin
        matrix.columns.1.y = cos
        return matrix
    }
    
    static func orthographic(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> Matrix4 {
        let width = right - left
        let height = top - bottom
        let depth = far - near
        
        var matrix = Matrix4.identity
        matrix.columns.0.x = 2 / width
        matrix.columns.1.y = 2 / height
        matrix.columns.2.z = -2 / depth
        matrix.columns.3.x = -(right + left) / width
        matrix.columns.3.y = -(top + bottom) / height
        matrix.columns.3.z = -(far + near) / depth
        return matrix
    }
    
    static func * (lhs: Matrix4, rhs: Matrix4) -> Matrix4 {
        return simd_mul(lhs, rhs)
    }
}

// MARK: - Rectangle
struct Rect: Codable {
    var origin: Vector2
    var size: Vector2
    
    var minX: Float { origin.x }
    var minY: Float { origin.y }
    var maxX: Float { origin.x + size.x }
    var maxY: Float { origin.y + size.y }
    var center: Vector2 { origin + size * 0.5 }
    var width: Float { size.x }
    var height: Float { size.y }
    
    init(origin: Vector2, size: Vector2) {
        self.origin = origin
        self.size = size
    }
    
    init(x: Float, y: Float, width: Float, height: Float) {
        self.origin = Vector2(x, y)
        self.size = Vector2(width, height)
    }
    
    init(center: Vector2, size: Vector2) {
        self.origin = center - size * 0.5
        self.size = size
    }
    
    func contains(_ point: Vector2) -> Bool {
        return point.x >= minX && point.x <= maxX &&
               point.y >= minY && point.y <= maxY
    }
    
    func intersects(_ other: Rect) -> Bool {
        return !(maxX < other.minX || minX > other.maxX ||
                 maxY < other.minY || minY > other.maxY)
    }
    
    func expanded(by amount: Float) -> Rect {
        return Rect(origin: origin - Vector2(repeating: amount),
                    size: size + Vector2(repeating: amount * 2))
    }
}

// MARK: - Direction
enum Direction: Int, CaseIterable, Codable {
    case north = 0
    case east = 1
    case south = 2
    case west = 3
    
    var vector: Vector2 {
        switch self {
        case .north: return Vector2(0, 1)
        case .east: return Vector2(1, 0)
        case .south: return Vector2(0, -1)
        case .west: return Vector2(-1, 0)
        }
    }
    
    var intVector: IntVector2 {
        switch self {
        case .north: return IntVector2(0, 1)
        case .east: return IntVector2(1, 0)
        case .south: return IntVector2(0, -1)
        case .west: return IntVector2(-1, 0)
        }
    }
    
    var angle: Float {
        return Float(rawValue) * .pi / 2
    }
    
    var opposite: Direction {
        return Direction(rawValue: (rawValue + 2) % 4)!
    }
    
    var clockwise: Direction {
        return Direction(rawValue: (rawValue + 1) % 4)!
    }
    
    var counterClockwise: Direction {
        return Direction(rawValue: (rawValue + 3) % 4)!
    }
    
    static func from(angle: Float) -> Direction {
        let normalized = (angle + .pi / 4).truncatingRemainder(dividingBy: .pi * 2)
        let index = Int(normalized / (.pi / 2)) % 4
        return Direction(rawValue: index) ?? .north
    }
}

// MARK: - Color
struct Color: Codable {
    var r: Float
    var g: Float
    var b: Float
    var a: Float
    
    static let white = Color(r: 1, g: 1, b: 1, a: 1)
    static let black = Color(r: 0, g: 0, b: 0, a: 1)
    static let red = Color(r: 1, g: 0, b: 0, a: 1)
    static let green = Color(r: 0, g: 1, b: 0, a: 1)
    static let blue = Color(r: 0, g: 0, b: 1, a: 1)
    static let yellow = Color(r: 1, g: 1, b: 0, a: 1)
    static let clear = Color(r: 0, g: 0, b: 0, a: 0)
    
    var vector4: Vector4 {
        return Vector4(r, g, b, a)
    }
    
    init(r: Float, g: Float, b: Float, a: Float = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
    
    init(hex: UInt32, alpha: Float = 1) {
        self.r = Float((hex >> 16) & 0xFF) / 255.0
        self.g = Float((hex >> 8) & 0xFF) / 255.0
        self.b = Float(hex & 0xFF) / 255.0
        self.a = alpha
    }
    
    func withAlpha(_ alpha: Float) -> Color {
        return Color(r: r, g: g, b: b, a: alpha)
    }
    
    func lerp(to other: Color, t: Float) -> Color {
        return Color(
            r: r + (other.r - r) * t,
            g: g + (other.g - g) * t,
            b: b + (other.b - b) * t,
            a: a + (other.a - a) * t
        )
    }
}

// MARK: - Random
struct Random {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    
    mutating func nextFloat() -> Float {
        return Float(next() & 0xFFFFFF) / Float(0xFFFFFF)
    }
    
    mutating func nextFloat(in range: ClosedRange<Float>) -> Float {
        return range.lowerBound + nextFloat() * (range.upperBound - range.lowerBound)
    }
    
    mutating func nextInt(in range: Range<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound)
        return range.lowerBound + Int(next() % span)
    }
    
    mutating func nextBool() -> Bool {
        return next() & 1 == 1
    }
    
    mutating func nextVector2(in rect: Rect) -> Vector2 {
        return Vector2(
            nextFloat(in: rect.minX...rect.maxX),
            nextFloat(in: rect.minY...rect.maxY)
        )
    }
}

// MARK: - Noise
struct PerlinNoise {
    private let permutation: [Int]
    
    init(seed: UInt64) {
        var rng = Random(seed: seed)
        var p = Array(0..<256)
        for i in stride(from: 255, to: 0, by: -1) {
            let j = rng.nextInt(in: 0..<(i + 1))
            p.swapAt(i, j)
        }
        permutation = p + p
    }
    
    func noise(x: Float, y: Float) -> Float {
        let xi = Int(floorf(x)) & 255
        let yi = Int(floorf(y)) & 255
        
        let xf = x - floorf(x)
        let yf = y - floorf(y)
        
        let u = fade(xf)
        let v = fade(yf)
        
        let aa = permutation[permutation[xi] + yi]
        let ab = permutation[permutation[xi] + yi + 1]
        let ba = permutation[permutation[xi + 1] + yi]
        let bb = permutation[permutation[xi + 1] + yi + 1]
        
        let x1 = lerp(grad(hash: aa, x: xf, y: yf),
                      grad(hash: ba, x: xf - 1, y: yf), t: u)
        let x2 = lerp(grad(hash: ab, x: xf, y: yf - 1),
                      grad(hash: bb, x: xf - 1, y: yf - 1), t: u)
        
        return lerp(x1, x2, t: v)
    }
    
    func octaveNoise(x: Float, y: Float, octaves: Int, persistence: Float) -> Float {
        var total: Float = 0
        var frequency: Float = 1
        var amplitude: Float = 1
        var maxValue: Float = 0
        
        for _ in 0..<octaves {
            total += noise(x: x * frequency, y: y * frequency) * amplitude
            maxValue += amplitude
            amplitude *= persistence
            frequency *= 2
        }
        
        return total / maxValue
    }
    
    private func fade(_ t: Float) -> Float {
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
    
    private func lerp(_ a: Float, _ b: Float, t: Float) -> Float {
        return a + t * (b - a)
    }
    
    private func grad(hash: Int, x: Float, y: Float) -> Float {
        let h = hash & 3
        let u = h < 2 ? x : y
        let v = h < 2 ? y : x
        return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v)
    }
}

