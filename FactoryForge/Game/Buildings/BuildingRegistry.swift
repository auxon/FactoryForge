import Foundation

/// Registry of all building definitions
final class BuildingRegistry {
    private var buildings: [String: BuildingDefinition] = [:]
    
    /// Gets a building by ID
    func get(_ id: String) -> BuildingDefinition? {
        return buildings[id]
    }
    
    /// Gets a building by texture ID
    func getByTexture(_ textureId: String) -> BuildingDefinition? {
        return buildings.values.first { $0.textureId == textureId }
    }
    
    /// Gets all buildings
    var all: [BuildingDefinition] {
        return Array(buildings.values)
    }
    
    /// Gets buildings by type
    func buildings(ofType type: BuildingType) -> [BuildingDefinition] {
        return buildings.values.filter { $0.type == type }
    }
    
    /// Registers a building
    func register(_ building: BuildingDefinition) {
        buildings[building.id] = building
    }
    
    /// Loads building definitions
    func loadBuildings() {
        // Miners
        var burnerMiner = BuildingDefinition(
            id: "burner-mining-drill",
            name: "Burner Mining Drill",
            type: .miner,
            width: 2,
            height: 2,
            maxHealth: 150,
            cost: [ItemStack(itemId: "iron-plate", count: 5)]
        )
        burnerMiner.miningSpeed = 0.50
        register(burnerMiner)
        
        var electricMiner = BuildingDefinition(
            id: "electric-mining-drill",
            name: "Electric Mining Drill",
            type: .miner,
            width: 3,
            height: 3,
            maxHealth: 300,
            cost: [ItemStack(itemId: "electric-mining-drill", count: 1)]
        )
        electricMiner.miningSpeed = 0.75
        electricMiner.powerConsumption = 90
        register(electricMiner)
        
        // Furnaces
        var stoneFurnace = BuildingDefinition(
            id: "stone-furnace",
            name: "Stone Furnace",
            type: .furnace,
            width: 2,
            height: 2,
            maxHealth: 200,
            cost: [ItemStack(itemId: "iron-plate", count: 5)]
        )
        stoneFurnace.craftingSpeed = 1
        stoneFurnace.craftingCategory = "smelting"
        register(stoneFurnace)
        
        var steelFurnace = BuildingDefinition(
            id: "steel-furnace",
            name: "Steel Furnace",
            type: .furnace,
            width: 2,
            height: 2,
            maxHealth: 300,
            cost: [ItemStack(itemId: "steel-furnace", count: 1)]
        )
        steelFurnace.craftingSpeed = 2
        steelFurnace.craftingCategory = "smelting"
        register(steelFurnace)
        
        var electricFurnace = BuildingDefinition(
            id: "electric-furnace",
            name: "Electric Furnace",
            type: .furnace,
            width: 3,
            height: 3,
            maxHealth: 350,
            cost: [ItemStack(itemId: "electric-furnace", count: 1)]
        )
        electricFurnace.craftingSpeed = 2
        electricFurnace.craftingCategory = "smelting"
        electricFurnace.powerConsumption = 180
        register(electricFurnace)
        
        // Assemblers
        var assembler1 = BuildingDefinition(
            id: "assembling-machine-1",
            name: "Assembling Machine 1",
            type: .assembler,
            width: 3,
            height: 3,
            maxHealth: 300,
            cost: [ItemStack(itemId: "assembling-machine-1", count: 1)]
        )
        assembler1.craftingSpeed = 0.5
        assembler1.craftingCategory = "crafting"
        assembler1.powerConsumption = 75
        register(assembler1)
        
        var assembler2 = BuildingDefinition(
            id: "assembling-machine-2",
            name: "Assembling Machine 2",
            type: .assembler,
            width: 3,
            height: 3,
            maxHealth: 350,
            cost: [ItemStack(itemId: "assembling-machine-2", count: 1)]
        )
        assembler2.craftingSpeed = 0.75
        assembler2.craftingCategory = "advanced-crafting"
        assembler2.powerConsumption = 150
        register(assembler2)
        
        var assembler3 = BuildingDefinition(
            id: "assembling-machine-3",
            name: "Assembling Machine 3",
            type: .assembler,
            width: 3,
            height: 3,
            maxHealth: 400,
            cost: [ItemStack(itemId: "assembling-machine-3", count: 1)]
        )
        assembler3.craftingSpeed = 1.25
        assembler3.craftingCategory = "advanced-crafting"
        assembler3.powerConsumption = 375
        register(assembler3)
        
        // Belts
        var transportBelt = BuildingDefinition(
            id: "transport-belt",
            name: "Transport Belt",
            type: .belt,
            maxHealth: 50,
            cost: [ItemStack(itemId: "iron-plate", count: 1)]
        )
        transportBelt.beltSpeed = 1.875  // 15 items/s per lane
        register(transportBelt)

        var fastBelt = BuildingDefinition(
            id: "fast-transport-belt",
            name: "Fast Transport Belt",
            type: .belt,
            maxHealth: 50,
            cost: [ItemStack(itemId: "fast-transport-belt", count: 1)]
        )
        fastBelt.beltSpeed = 3.75  // 30 items/s per lane
        register(fastBelt)

        var expressBelt = BuildingDefinition(
            id: "express-transport-belt",
            name: "Express Transport Belt",
            type: .belt,
            maxHealth: 50,
            cost: [ItemStack(itemId: "express-transport-belt", count: 1)]
        )
        expressBelt.beltSpeed = 5.625  // 45 items/s per lane
        register(expressBelt)

        // Advanced Belts
        var undergroundBelt = BuildingDefinition(
            id: "underground-belt",
            name: "Underground Belt",
            type: .belt,
            maxHealth: 60,
            cost: [ItemStack(itemId: "iron-plate", count: 10), ItemStack(itemId: "transport-belt", count: 5)]
        )
        undergroundBelt.beltSpeed = 1.875  // Same speed as transport belt
        register(undergroundBelt)

        var splitter = BuildingDefinition(
            id: "splitter",
            name: "Splitter",
            type: .belt,
            maxHealth: 80,
            cost: [ItemStack(itemId: "electronic-circuit", count: 5), ItemStack(itemId: "iron-plate", count: 5), ItemStack(itemId: "transport-belt", count: 4)]
        )
        splitter.beltSpeed = 1.875
        register(splitter)

        var merger = BuildingDefinition(
            id: "merger",
            name: "Merger",
            type: .belt,
            maxHealth: 80,
            cost: [ItemStack(itemId: "electronic-circuit", count: 5), ItemStack(itemId: "iron-plate", count: 5), ItemStack(itemId: "transport-belt", count: 4)]
        )
        merger.beltSpeed = 1.875
        register(merger)
        
        // Inserters
        var inserter = BuildingDefinition(
            id: "inserter",
            name: "Inserter",
            type: .inserter,
            maxHealth: 40,
            cost: [ItemStack(itemId: "inserter", count: 1)]
        )
        inserter.inserterSpeed = 4.0
        inserter.inserterStackSize = 1
        inserter.powerConsumption = 13
        register(inserter)
        
        var longInserter = BuildingDefinition(
            id: "long-handed-inserter",
            name: "Long Handed Inserter",
            type: .inserter,
            maxHealth: 40,
            cost: [ItemStack(itemId: "long-handed-inserter", count: 1)]
        )
        longInserter.inserterSpeed = 1.2
        longInserter.inserterStackSize = 1
        longInserter.powerConsumption = 18
        register(longInserter)
        
        var fastInserter = BuildingDefinition(
            id: "fast-inserter",
            name: "Fast Inserter",
            type: .inserter,
            maxHealth: 40,
            cost: [ItemStack(itemId: "fast-inserter", count: 1)]
        )
        fastInserter.inserterSpeed = 2.31
        fastInserter.inserterStackSize = 1
        fastInserter.powerConsumption = 46
        register(fastInserter)
        
        // Power poles
        var smallPole = BuildingDefinition(
            id: "small-electric-pole",
            name: "Small Electric Pole",
            type: .powerPole,
            maxHealth: 100,
            cost: [ItemStack(itemId: "small-electric-pole", count: 1)]
        )
        smallPole.wireReach = 7.5
        smallPole.supplyArea = 2.5
        register(smallPole)
        
        var mediumPole = BuildingDefinition(
            id: "medium-electric-pole",
            name: "Medium Electric Pole",
            type: .powerPole,
            maxHealth: 100,
            cost: [ItemStack(itemId: "medium-electric-pole", count: 1)]
        )
        mediumPole.wireReach = 9
        mediumPole.supplyArea = 3.5
        register(mediumPole)
        
        var bigPole = BuildingDefinition(
            id: "big-electric-pole",
            name: "Big Electric Pole",
            type: .powerPole,
            width: 2,
            height: 2,
            maxHealth: 150,
            cost: [ItemStack(itemId: "big-electric-pole", count: 1)]
        )
        bigPole.wireReach = 30
        bigPole.supplyArea = 2
        register(bigPole)
        
        // Power generation
        var boiler = BuildingDefinition(
            id: "boiler",
            name: "Boiler",
            type: .generator,
            width: 2,
            height: 3,
            maxHealth: 200,
            cost: [ItemStack(itemId: "boiler", count: 1)]
        )
        boiler.fuelCategory = "chemical"
        register(boiler)
        
        var steamEngine = BuildingDefinition(
            id: "steam-engine",
            name: "Steam Engine",
            type: .generator,
            width: 3,
            height: 5,
            maxHealth: 400,
            cost: [ItemStack(itemId: "steam-engine", count: 1)]
        )
        steamEngine.powerProduction = 900
        register(steamEngine)
        
        var solarPanel = BuildingDefinition(
            id: "solar-panel",
            name: "Solar Panel",
            type: .solarPanel,
            width: 3,
            height: 3,
            maxHealth: 200,
            cost: [ItemStack(itemId: "solar-panel", count: 1)]
        )
        solarPanel.powerProduction = 60
        register(solarPanel)
        
        var accumulator = BuildingDefinition(
            id: "accumulator",
            name: "Accumulator",
            type: .accumulator,
            width: 2,
            height: 2,
            maxHealth: 150,
            cost: [ItemStack(itemId: "accumulator", count: 1)]
        )
        accumulator.accumulatorCapacity = 5000
        accumulator.accumulatorChargeRate = 300
        register(accumulator)
        
        // Lab
        var lab = BuildingDefinition(
            id: "lab",
            name: "Lab",
            type: .lab,
            width: 3,
            height: 3,
            maxHealth: 150,
            cost: [ItemStack(itemId: "lab", count: 1)]
        )
        lab.researchSpeed = 1
        lab.powerConsumption = 60
        register(lab)
        
        // Combat
        var gunTurret = BuildingDefinition(
            id: "gun-turret",
            name: "Gun Turret",
            type: .turret,
            width: 2,
            height: 2,
            maxHealth: 400,
            cost: [ItemStack(itemId: "gun-turret", count: 1)]
        )
        gunTurret.turretRange = 18
        gunTurret.turretDamage = 6
        gunTurret.turretFireRate = 10
        register(gunTurret)
        
        var laserTurret = BuildingDefinition(
            id: "laser-turret",
            name: "Laser Turret",
            type: .turret,
            width: 2,
            height: 2,
            maxHealth: 1000,
            cost: [ItemStack(itemId: "laser-turret", count: 1)]
        )
        laserTurret.turretRange = 24
        laserTurret.turretDamage = 20
        laserTurret.turretFireRate = 20
        laserTurret.powerConsumption = 800
        register(laserTurret)
        
        let wall = BuildingDefinition(
            id: "stone-wall",
            name: "Wall",
            type: .wall,
            maxHealth: 350,
            cost: [ItemStack(itemId: "wall", count: 1)]
        )
        register(wall)
        
        // Storage
        var woodenChest = BuildingDefinition(
            id: "wooden-chest",
            name: "Wooden Chest",
            type: .chest,
            maxHealth: 100,
            cost: [ItemStack(itemId: "wooden-chest", count: 1)]
        )
        woodenChest.inventorySlots = 16
        register(woodenChest)
        
        var ironChest = BuildingDefinition(
            id: "iron-chest",
            name: "Iron Chest",
            type: .chest,
            maxHealth: 200,
            cost: [ItemStack(itemId: "iron-chest", count: 1)]
        )
        ironChest.inventorySlots = 32
        register(ironChest)
        
        var steelChest = BuildingDefinition(
            id: "steel-chest",
            name: "Steel Chest",
            type: .chest,
            maxHealth: 350,
            cost: [ItemStack(itemId: "steel-chest", count: 1)]
        )
        steelChest.inventorySlots = 48
        register(steelChest)
    }
}

