import Foundation

/// Generates world terrain and resources
final class WorldGenerator {
    private let seed: UInt64
    private let terrainNoise: PerlinNoise
    private let resourceNoise: PerlinNoise
    private let treeNoise: PerlinNoise
    private var rng: Random
    
    init(seed: UInt64) {
        self.seed = seed
        self.terrainNoise = PerlinNoise(seed: seed)
        self.resourceNoise = PerlinNoise(seed: seed ^ 0xCAFEBABE)
        self.treeNoise = PerlinNoise(seed: seed ^ 0xFEEDFACE)
        self.rng = Random(seed: seed)
    }
    
    func generateChunk(at coord: ChunkCoord, biome: Biome) -> Chunk {
        let chunk = Chunk(coord: coord, biome: biome)
        
        // Generate terrain
        generateTerrain(chunk: chunk, biome: biome)
        
        // Generate resources
        generateResources(chunk: chunk, biome: biome)
        
        // Generate decorations (trees, etc.)
        generateDecorations(chunk: chunk, biome: biome)
        
        // Place enemy nests
        placeEnemyNests(chunk: chunk, biome: biome)
        
        return chunk
    }
    
    private func generateTerrain(chunk: Chunk, biome: Biome) {
        let origin = chunk.worldOrigin
        
        for y in 0..<Chunk.size {
            for x in 0..<Chunk.size {
                let worldX = Float(origin.x + Int32(x))
                let worldY = Float(origin.y + Int32(y))
                
                // Get noise value for terrain variation
                let noiseValue = terrainNoise.octaveNoise(
                    x: worldX * 0.02,
                    y: worldY * 0.02,
                    octaves: 4,
                    persistence: 0.5
                )
                
                // Determine tile type based on noise and biome
                var tileType: TileType
                
                if noiseValue < -0.4 {
                    // Water
                    tileType = .water
                } else if noiseValue < -0.2 {
                    // Secondary tile
                    tileType = biome.secondaryTile
                } else {
                    // Primary tile
                    tileType = biome.primaryTile
                }
                
                let variation = UInt8(rng.nextInt(in: 0..<4))
                chunk.setTile(localX: x, localY: y, tile: Tile(type: tileType, variation: variation))
            }
        }
    }
    
    private func generateResources(chunk: Chunk, biome: Biome) {
        let origin = chunk.worldOrigin
        let distanceFromSpawn = sqrtf(Float(origin.x * origin.x + origin.y * origin.y))
        
        // Use Poisson disk sampling for resource distribution
        let resourcePatches = generatePoissonPoints(
            in: Rect(x: 0, y: 0, width: Float(Chunk.size), height: Float(Chunk.size)),
            minDistance: 8,
            seed: seed ^ UInt64(bitPattern: Int64(chunk.coord.x)) ^ (UInt64(bitPattern: Int64(chunk.coord.y)) << 32)
        )
        
        for point in resourcePatches {
            let worldPos = Vector2(Float(origin.x) + point.x, Float(origin.y) + point.y)
            
            // Determine resource type based on distance and noise
            guard let resourceType = selectResourceType(
                at: worldPos,
                distanceFromSpawn: distanceFromSpawn,
                biome: biome
            ) else { continue }
            
            // Generate resource patch
            let patchSize = rng.nextInt(in: 3..<8)
            let richness = 0.5 + rng.nextFloat() * 0.5
            
            generateResourcePatch(
                chunk: chunk,
                center: IntVector2(Int(point.x), Int(point.y)),
                type: resourceType,
                size: patchSize,
                richness: richness
            )
        }
    }
    
    private func selectResourceType(at worldPos: Vector2, distanceFromSpawn: Float, biome: Biome) -> ResourceType? {
        // Filter by distance
        let availableResources = ResourceType.allCases.filter { $0.minimumSpawnDistance <= distanceFromSpawn }
        guard !availableResources.isEmpty else { return nil }
        
        // Use noise to determine if we should place a resource
        let resourceChance = resourceNoise.noise(x: worldPos.x * 0.05, y: worldPos.y * 0.05)
        guard resourceChance > 0.3 * (1 / biome.resourceModifier) else { return nil }
        
        // Weighted random selection
        let weights: [ResourceType: Float] = [
            .ironOre: 1.0,
            .copperOre: 0.8,
            .coal: 0.6,
            .stone: 0.5,
            .uraniumOre: 0.1,
            .oil: 0.2
        ]
        
        var totalWeight: Float = 0
        for resource in availableResources {
            totalWeight += weights[resource] ?? 0.1
        }
        
        var random = rng.nextFloat() * totalWeight
        for resource in availableResources {
            random -= weights[resource] ?? 0.1
            if random <= 0 {
                return resource
            }
        }
        
        return availableResources.first
    }
    
    private func generateResourcePatch(chunk: Chunk, center: IntVector2, type: ResourceType, size: Int, richness: Float) {
        for dy in -size...size {
            for dx in -size...size {
                let dist = sqrtf(Float(dx * dx + dy * dy))
                if dist > Float(size) { continue }
                
                let localX = Int(center.x) + dx
                let localY = Int(center.y) + dy
                
                guard localX >= 0 && localX < Chunk.size && localY >= 0 && localY < Chunk.size else { continue }
                
                // Get existing tile
                guard var tile = chunk.getTile(localX: localX, localY: localY) else { continue }
                guard tile.type.isBuildable && tile.resource == nil else { continue }
                
                // Calculate amount based on distance from center
                let falloff = 1 - (dist / Float(size + 1))
                let baseAmount = Float(rng.nextInt(in: type.typicalAmount))
                let amount = Int(baseAmount * falloff * richness)
                
                tile.type = type.tileType
                tile.resource = ResourceDeposit(type: type, amount: amount, richness: richness)
                chunk.setTile(localX: localX, localY: localY, tile: tile)
            }
        }
    }
    
    private func generateDecorations(chunk: Chunk, biome: Biome) {
        let origin = chunk.worldOrigin
        
        for y in 0..<Chunk.size {
            for x in 0..<Chunk.size {
                guard var tile = chunk.getTile(localX: x, localY: y) else { continue }
                guard tile.type == biome.primaryTile && tile.resource == nil else { continue }
                
                let worldX = Float(origin.x + Int32(x))
                let worldY = Float(origin.y + Int32(y))
                
                let treeNoise = self.treeNoise.noise(x: worldX * 0.1, y: worldY * 0.1)
                
                if treeNoise > 0.5 - biome.treeChance * 5 {
                    if rng.nextFloat() < biome.treeChance * 3 {
                        tile.type = .tree
                        chunk.setTile(localX: x, localY: y, tile: tile)
                    }
                }
            }
        }
    }
    
    private func placeEnemyNests(chunk: Chunk, biome: Biome) {
        let origin = chunk.worldOrigin
        let distanceFromSpawn = sqrtf(Float(origin.x * origin.x + origin.y * origin.y))
        
        // Don't place nests too close to spawn
        guard distanceFromSpawn > 100 else { return }
        
        // Probability increases with distance
        let nestChance = 0.001 * biome.nestModifier * (distanceFromSpawn / 100)
        
        for y in stride(from: 0, to: Chunk.size, by: 8) {
            for x in stride(from: 0, to: Chunk.size, by: 8) {
                if rng.nextFloat() < nestChance {
                    // Clear area for nest
                    for dy in -2...2 {
                        for dx in -2...2 {
                            let localX = x + dx
                            let localY = y + dy
                            guard localX >= 0 && localX < Chunk.size && localY >= 0 && localY < Chunk.size else { continue }
                            
                            if var tile = chunk.getTile(localX: localX, localY: localY) {
                                if tile.type == .tree {
                                    tile.type = biome.primaryTile
                                    chunk.setTile(localX: localX, localY: localY, tile: tile)
                                }
                            }
                        }
                    }
                    
                    // Store spawner position (center of cleared area)
                    let worldX = origin.x + Int32(x + 4)
                    let worldY = origin.y + Int32(y + 4)
                    chunk.spawnerPositions.append(IntVector2(x: worldX, y: worldY))
                }
            }
        }
    }
    
    // MARK: - Poisson Disk Sampling
    
    private func generatePoissonPoints(in rect: Rect, minDistance: Float, seed: UInt64) -> [Vector2] {
        var points: [Vector2] = []
        var rng = Random(seed: seed)
        
        let cellSize = minDistance / sqrtf(2)
        let gridWidth = Int(ceilf(rect.width / cellSize))
        let gridHeight = Int(ceilf(rect.height / cellSize))
        
        var grid = [[Vector2?]](repeating: [Vector2?](repeating: nil, count: gridWidth), count: gridHeight)
        var active: [Vector2] = []
        
        // Start with a random point
        let firstPoint = rng.nextVector2(in: rect)
        points.append(firstPoint)
        active.append(firstPoint)
        
        let gx = Int(firstPoint.x / cellSize)
        let gy = Int(firstPoint.y / cellSize)
        if gy >= 0 && gy < gridHeight && gx >= 0 && gx < gridWidth {
            grid[gy][gx] = firstPoint
        }
        
        let maxAttempts = 30
        
        while !active.isEmpty && points.count < 50 {
            let randomIndex = rng.nextInt(in: 0..<active.count)
            let point = active[randomIndex]
            
            var found = false
            
            for _ in 0..<maxAttempts {
                let angle = rng.nextFloat() * .pi * 2
                let distance = minDistance + rng.nextFloat() * minDistance
                
                let newPoint = Vector2(
                    point.x + cosf(angle) * distance,
                    point.y + sinf(angle) * distance
                )
                
                guard rect.contains(newPoint) else { continue }
                
                let ngx = Int(newPoint.x / cellSize)
                let ngy = Int(newPoint.y / cellSize)
                
                var valid = true
                
                for dy in -2...2 {
                    for dx in -2...2 {
                        let checkX = ngx + dx
                        let checkY = ngy + dy
                        
                        guard checkY >= 0 && checkY < gridHeight && checkX >= 0 && checkX < gridWidth else { continue }
                        
                        if let existingPoint = grid[checkY][checkX] {
                            if newPoint.distance(to: existingPoint) < minDistance {
                                valid = false
                                break
                            }
                        }
                    }
                    if !valid { break }
                }
                
                if valid {
                    points.append(newPoint)
                    active.append(newPoint)
                    if ngy >= 0 && ngy < gridHeight && ngx >= 0 && ngx < gridWidth {
                        grid[ngy][ngx] = newPoint
                    }
                    found = true
                    break
                }
            }
            
            if !found {
                active.remove(at: randomIndex)
            }
        }
        
        return points
    }
}

