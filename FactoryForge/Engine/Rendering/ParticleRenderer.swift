import Metal
import simd

/// GPU-driven particle system renderer
final class ParticleRenderer {
    private let device: MTLDevice
    private let textureAtlas: TextureAtlas
    
    // Vertex buffer for a single quad
    private let quadVertexBuffer: MTLBuffer
    
    // Instance buffer for particle data
    private var instanceBuffer: MTLBuffer?
    private var instanceCount: Int = 0
    private let maxParticles = 10000
    
    // Active particle emitters
    private var emitters: [ParticleEmitter] = []
    
    // Queued particles for current frame
    private var queuedParticles: [ParticleInstance] = []
    
    init(device: MTLDevice, library: MTLLibrary, textureAtlas: TextureAtlas) {
        self.device = device
        self.textureAtlas = textureAtlas
        
        // Create quad vertices (centered on origin)
        let vertices: [ParticleVertex] = [
            ParticleVertex(position: Vector2(-0.5, -0.5), texCoord: Vector2(0, 1)),
            ParticleVertex(position: Vector2(0.5, -0.5), texCoord: Vector2(1, 1)),
            ParticleVertex(position: Vector2(0.5, 0.5), texCoord: Vector2(1, 0)),
            ParticleVertex(position: Vector2(-0.5, -0.5), texCoord: Vector2(0, 1)),
            ParticleVertex(position: Vector2(0.5, 0.5), texCoord: Vector2(1, 0)),
            ParticleVertex(position: Vector2(-0.5, 0.5), texCoord: Vector2(0, 0))
        ]
        
        guard let buffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<ParticleVertex>.stride * vertices.count,
            options: .storageModeShared
        ) else {
            fatalError("Failed to create particle vertex buffer")
        }
        quadVertexBuffer = buffer
        
        // Create instance buffer
        instanceBuffer = device.makeBuffer(
            length: MemoryLayout<ParticleInstanceData>.stride * maxParticles,
            options: .storageModeShared
        )
    }
    
    func queue(_ particle: ParticleInstance) {
        queuedParticles.append(particle)
    }
    
    func addEmitter(_ emitter: ParticleEmitter) {
        emitters.append(emitter)
    }
    
    func removeEmitter(_ emitter: ParticleEmitter) {
        emitters.removeAll { $0 === emitter }
    }
    
    func update(deltaTime: Float) {
        // Update all emitters
        for emitter in emitters {
            emitter.update(deltaTime: deltaTime)
            
            // Queue particles from emitter
            for particle in emitter.particles {
                queuedParticles.append(particle)
            }
        }
        
        // Remove dead emitters
        emitters.removeAll { $0.isDead }
    }
    
    func render(encoder: MTLRenderCommandEncoder, viewProjection: Matrix4) {
        // Update emitters first
        update(deltaTime: Time.shared.deltaTime)
        
        guard !queuedParticles.isEmpty else { return }
        guard let instanceBuffer = instanceBuffer else { return }
        
        // Convert to instance data
        var instances: [ParticleInstanceData] = []
        instances.reserveCapacity(min(queuedParticles.count, maxParticles))
        
        for particle in queuedParticles.prefix(maxParticles) {
            let lifeRatio = particle.life / particle.maxLife
            let alpha = particle.color.a * lifeRatio
            let size = particle.size * (0.5 + 0.5 * lifeRatio)
            
            instances.append(ParticleInstanceData(
                position: particle.position,
                size: size,
                rotation: particle.rotation,
                color: Vector4(particle.color.r, particle.color.g, particle.color.b, alpha)
            ))
        }
        
        queuedParticles.removeAll(keepingCapacity: true)
        
        guard !instances.isEmpty else { return }
        
        // Update instance buffer
        instanceBuffer.contents().copyMemory(
            from: instances,
            byteCount: MemoryLayout<ParticleInstanceData>.stride * instances.count
        )
        instanceCount = instances.count
        
        // Set uniforms
        var uniforms = ParticleUniforms(viewProjection: viewProjection)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<ParticleUniforms>.size, index: 0)
        
        // Set buffers
        encoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 1)
        encoder.setVertexBuffer(instanceBuffer, offset: 0, index: 2)
        
        // Draw instanced
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: instanceCount)
    }
    
    // MARK: - Convenience Methods
    
    func spawnSmoke(at position: Vector2, count: Int = 10) {
        let emitter = ParticleEmitter(
            position: position,
            config: ParticleEmitterConfig(
                particlesPerSecond: 0,
                burstCount: count,
                lifetime: 1.5,
                lifetimeVariance: 0.5,
                speed: 0.5,
                speedVariance: 0.3,
                direction: Vector2(0, 1),
                spread: .pi / 3,
                size: 0.3,
                sizeVariance: 0.1,
                startColor: Color(r: 0.5, g: 0.5, b: 0.5, a: 0.8),
                endColor: Color(r: 0.3, g: 0.3, b: 0.3, a: 0),
                gravity: Vector2(0, 0.1)
            ),
            oneShot: true
        )
        addEmitter(emitter)
    }
    
    func spawnExplosion(at position: Vector2, count: Int = 30) {
        let emitter = ParticleEmitter(
            position: position,
            config: ParticleEmitterConfig(
                particlesPerSecond: 0,
                burstCount: count,
                lifetime: 0.5,
                lifetimeVariance: 0.2,
                speed: 3.0,
                speedVariance: 1.5,
                direction: .zero,
                spread: .pi * 2,
                size: 0.2,
                sizeVariance: 0.1,
                startColor: Color(r: 1, g: 0.8, b: 0.3, a: 1),
                endColor: Color(r: 1, g: 0.2, b: 0, a: 0),
                gravity: Vector2(0, -2)
            ),
            oneShot: true
        )
        addEmitter(emitter)
    }
    
    func spawnMiningParticles(at position: Vector2, color: Color, count: Int = 5) {
        let emitter = ParticleEmitter(
            position: position,
            config: ParticleEmitterConfig(
                particlesPerSecond: 0,
                burstCount: count,
                lifetime: 0.3,
                lifetimeVariance: 0.1,
                speed: 1.0,
                speedVariance: 0.5,
                direction: Vector2(0, 1),
                spread: .pi / 2,
                size: 0.15,
                sizeVariance: 0.05,
                startColor: color,
                endColor: color.withAlpha(0),
                gravity: Vector2(0, -3)
            ),
            oneShot: true
        )
        addEmitter(emitter)
    }
}

// MARK: - Particle Emitter

final class ParticleEmitter {
    var position: Vector2
    let config: ParticleEmitterConfig
    let oneShot: Bool
    
    private(set) var particles: [ParticleInstance] = []
    private var emitAccumulator: Float = 0
    private var hasEmittedBurst = false
    
    var isDead: Bool {
        return oneShot && hasEmittedBurst && particles.isEmpty
    }
    
    init(position: Vector2, config: ParticleEmitterConfig, oneShot: Bool = false) {
        self.position = position
        self.config = config
        self.oneShot = oneShot
    }
    
    func update(deltaTime: Float) {
        // Update existing particles
        particles = particles.compactMap { particle in
            var p = particle
            p.velocity = p.velocity + config.gravity * deltaTime
            p.position = p.position + p.velocity * deltaTime
            p.rotation += p.velocity.x * deltaTime
            p.life -= deltaTime
            
            return p.life > 0 ? p : nil
        }
        
        // Emit new particles
        if !oneShot {
            emitAccumulator += config.particlesPerSecond * deltaTime
            while emitAccumulator >= 1 {
                emitParticle()
                emitAccumulator -= 1
            }
        } else if !hasEmittedBurst {
            for _ in 0..<config.burstCount {
                emitParticle()
            }
            hasEmittedBurst = true
        }
    }
    
    private func emitParticle() {
        let lifetime = config.lifetime + Float.random(in: -config.lifetimeVariance...config.lifetimeVariance)
        let speed = config.speed + Float.random(in: -config.speedVariance...config.speedVariance)
        let angle = config.direction.angle + Float.random(in: -config.spread...config.spread)
        let size = config.size + Float.random(in: -config.sizeVariance...config.sizeVariance)
        
        let velocity = Vector2(cosf(angle), sinf(angle)) * speed
        
        let particle = ParticleInstance(
            position: position,
            velocity: velocity,
            size: size,
            rotation: Float.random(in: 0...(.pi * 2)),
            color: config.startColor,
            life: lifetime,
            maxLife: lifetime
        )
        
        particles.append(particle)
    }
}

struct ParticleEmitterConfig {
    var particlesPerSecond: Float
    var burstCount: Int
    var lifetime: Float
    var lifetimeVariance: Float
    var speed: Float
    var speedVariance: Float
    var direction: Vector2
    var spread: Float
    var size: Float
    var sizeVariance: Float
    var startColor: Color
    var endColor: Color
    var gravity: Vector2
}

// MARK: - Shader Data Structures

struct ParticleVertex {
    var position: Vector2
    var texCoord: Vector2
}

struct ParticleInstanceData {
    var position: Vector2
    var size: Float
    var rotation: Float
    var color: Vector4
}

struct ParticleUniforms {
    var viewProjection: Matrix4
}

