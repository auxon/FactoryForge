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
        burnerMiner.inputSlots = 0
        burnerMiner.outputSlots = 1
        burnerMiner.fuelSlots = 0
        register(burnerMiner)
        
        var electricMiner = BuildingDefinition(
            id: "electric-mining-drill",
            name: "Electric Mining Drill",
            type: .miner,
            width: 3,
            height: 3,
            maxHealth: 300,
            cost: [
                ItemStack(itemId: "electronic-circuit", count: 3),
                ItemStack(itemId: "iron-gear-wheel", count: 5),
                ItemStack(itemId: "iron-plate", count: 10)
            ]
        )
        electricMiner.miningSpeed = 0.75
        electricMiner.powerConsumption = 90
        electricMiner.inputSlots = 0
        electricMiner.outputSlots = 1
        electricMiner.fuelSlots = 0
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
        stoneFurnace.inputSlots = 1
        stoneFurnace.outputSlots = 1
        stoneFurnace.fuelSlots = 1
        register(stoneFurnace)
        
        var steelFurnace = BuildingDefinition(
            id: "steel-furnace",
            name: "Steel Furnace",
            type: .furnace,
            width: 2,
            height: 2,
            maxHealth: 300,
            cost: [
                ItemStack(itemId: "steel-plate", count: 6),
                ItemStack(itemId: "stone-brick", count: 10)
            ]
        )
        steelFurnace.craftingSpeed = 2
        steelFurnace.craftingCategory = "smelting"
        steelFurnace.inputSlots = 1
        steelFurnace.outputSlots = 1
        steelFurnace.fuelSlots = 1
        register(steelFurnace)
        
        var electricFurnace = BuildingDefinition(
            id: "electric-furnace",
            name: "Electric Furnace",
            type: .furnace,
            width: 3,
            height: 3,
            maxHealth: 350,
            cost: [
                ItemStack(itemId: "steel-plate", count: 10),
                ItemStack(itemId: "advanced-circuit", count: 5),
                ItemStack(itemId: "stone-brick", count: 10)
            ]
        )
        electricFurnace.craftingSpeed = 2
        electricFurnace.craftingCategory = "smelting"
        electricFurnace.powerConsumption = 180
        electricFurnace.inputSlots = 1
        electricFurnace.outputSlots = 1
        electricFurnace.fuelSlots = 0
        register(electricFurnace)
        
        // Assemblers
        var assembler1 = BuildingDefinition(
            id: "assembling-machine-1",
            name: "Assembling Machine 1",
            type: .assembler,
            width: 3,
            height: 3,
            maxHealth: 300,
            cost: [
                ItemStack(itemId: "electronic-circuit", count: 3),
                ItemStack(itemId: "iron-gear-wheel", count: 5),
                ItemStack(itemId: "iron-plate", count: 9)
            ]
        )
        assembler1.craftingSpeed = 0.5
        assembler1.craftingCategory = "crafting"
        assembler1.powerConsumption = 75
        assembler1.inputSlots = 4
        assembler1.outputSlots = 4
        assembler1.fuelSlots = 0
        register(assembler1)
        
        var assembler2 = BuildingDefinition(
            id: "assembling-machine-2",
            name: "Assembling Machine 2",
            type: .assembler,
            width: 3,
            height: 3,
            maxHealth: 350,
            cost: [
                ItemStack(itemId: "iron-plate", count: 9),
                ItemStack(itemId: "electronic-circuit", count: 3),
                ItemStack(itemId: "iron-gear-wheel", count: 5),
                ItemStack(itemId: "assembling-machine-1", count: 1)
            ]
        )
        assembler2.craftingSpeed = 0.75
        assembler2.craftingCategory = "advanced-crafting"
        assembler2.powerConsumption = 150
        assembler2.inputSlots = 4
        assembler2.outputSlots = 4
        assembler2.fuelSlots = 0
        register(assembler2)
        
        var assembler3 = BuildingDefinition(
            id: "assembling-machine-3",
            name: "Assembling Machine 3",
            type: .assembler,
            width: 3,
            height: 3,
            maxHealth: 400,
            cost: [
                ItemStack(itemId: "assembling-machine-2", count: 2),
                ItemStack(itemId: "speed-module", count: 4)
            ]
        )
        assembler3.craftingSpeed = 1.25
        assembler3.craftingCategory = "advanced-crafting"
        assembler3.powerConsumption = 375
        assembler3.inputSlots = 4
        assembler3.outputSlots = 4
        assembler3.fuelSlots = 0
        register(assembler3)
        
        // Belts
        var transportBelt = BuildingDefinition(
            id: "transport-belt",
            name: "Transport Belt",
            type: .belt,
            maxHealth: 50,
            cost: [ItemStack(itemId: "iron-gear-wheel", count: 1),
                   ItemStack(itemId: "iron-plate", count: 1)
            ]
        )
        transportBelt.beltSpeed = 1.875  // 15 items/s per lane
        register(transportBelt)

        var fastBelt = BuildingDefinition(
            id: "fast-transport-belt",
            name: "Fast Transport Belt",
            type: .belt,
            maxHealth: 50,
            cost: [
                ItemStack(itemId: "iron-gear-wheel", count: 5),
                ItemStack(itemId: "iron-plate", count: 1)
            ]
        )
        fastBelt.beltSpeed = 3.75  // 30 items/s per lane
        register(fastBelt)

        var expressBelt = BuildingDefinition(
            id: "express-transport-belt",
            name: "Express Transport Belt",
            type: .belt,
            maxHealth: 50,
            cost: [
                ItemStack(itemId: "iron-gear-wheel", count: 10),
                ItemStack(itemId: "advanced-circuit", count: 2),
                ItemStack(itemId: "steel-plate", count: 1)
            ]
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

        // Belt Bridges
        var beltBridge = BuildingDefinition(
            id: "belt-bridge",
            name: "Belt Bridge",
            type: .belt,
            maxHealth: 50,
            cost: [
                ItemStack(itemId: "iron-plate", count: 1),
                ItemStack(itemId: "iron-stick", count: 2),
                ItemStack(itemId: "iron-gear-wheel", count: 2)
            ]
        )
        beltBridge.beltSpeed = 1.875  // Same speed as transport belt
        register(beltBridge)

        // Inserters
        var inserter = BuildingDefinition(
            id: "inserter",
            name: "Inserter",
            type: .inserter,
            maxHealth: 40,
            cost: [
                ItemStack(itemId: "electronic-circuit", count: 1),
                ItemStack(itemId: "iron-gear-wheel", count: 1),
                ItemStack(itemId: "iron-plate", count: 1)
            ]
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
            cost: [
                ItemStack(itemId: "iron-gear-wheel", count: 1),
                ItemStack(itemId: "iron-plate", count: 1),
                ItemStack(itemId: "inserter", count: 1)
            ]
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
            cost: [
                ItemStack(itemId: "electronic-circuit", count: 2),
                ItemStack(itemId: "iron-plate", count: 2),
                ItemStack(itemId: "inserter", count: 1)
            ]
        )
        fastInserter.inserterSpeed = 2.31
        fastInserter.inserterStackSize = 1
        fastInserter.powerConsumption = 46
        register(fastInserter)

        var stackInserter = BuildingDefinition(
            id: "stack-inserter",
            name: "Stack Inserter",
            type: .inserter,
            maxHealth: 40,
            cost: [
                ItemStack(itemId: "advanced-circuit", count: 1),
                ItemStack(itemId: "electronic-circuit", count: 15),
                ItemStack(itemId: "iron-gear-wheel", count: 15),
                ItemStack(itemId: "fast-inserter", count: 1)
            ]
        )
        stackInserter.inserterSpeed = 1.5
        stackInserter.inserterStackSize = 2
        stackInserter.powerConsumption = 75
        register(stackInserter)

        // Power poles
        var smallPole = BuildingDefinition(
            id: "small-electric-pole",
            name: "Small Electric Pole",
            type: .powerPole,
            maxHealth: 100,
            cost: [
                ItemStack(itemId: "wood", count: 2),
                ItemStack(itemId: "copper-cable", count: 2)
            ]
        )
        smallPole.wireReach = 7.5
        smallPole.supplyArea = 2.5
        register(smallPole)
        
        var mediumPole = BuildingDefinition(
            id: "medium-electric-pole",
            name: "Medium Electric Pole",
            type: .powerPole,
            maxHealth: 100,
            cost: [
                ItemStack(itemId: "steel-plate", count: 2),
                ItemStack(itemId: "copper-plate", count: 2)
            ]
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
            cost: [
                ItemStack(itemId: "steel-plate", count: 5),
                ItemStack(itemId: "copper-plate", count: 5)
            ]
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
            cost: [
                ItemStack(itemId: "stone-furnace", count: 1),
                ItemStack(itemId: "pipe", count: 4)
            ]
        )
        boiler.fuelCategory = "chemical"
        boiler.inputSlots = 0  // Takes fuel from fuel category
        boiler.outputSlots = 0  // Produces steam (fluid)
        boiler.fuelSlots = 1
        register(boiler)
        
        var steamEngine = BuildingDefinition(
            id: "steam-engine",
            name: "Steam Engine",
            type: .generator,
            width: 3,
            height: 5,
            maxHealth: 400,
            cost: [
                ItemStack(itemId: "iron-gear-wheel", count: 8),
                ItemStack(itemId: "iron-plate", count: 10),
                ItemStack(itemId: "pipe", count: 5)
            ]
        )
        steamEngine.powerProduction = 900
        steamEngine.inputSlots = 0  // Takes steam (fluid)
        steamEngine.outputSlots = 0  // Produces power
        steamEngine.fuelSlots = 0
        register(steamEngine)
        
        var solarPanel = BuildingDefinition(
            id: "solar-panel",
            name: "Solar Panel",
            type: .solarPanel,
            width: 3,
            height: 3,
            maxHealth: 200,
            cost: [
                ItemStack(itemId: "steel-plate", count: 5),
                ItemStack(itemId: "electronic-circuit", count: 15),
                ItemStack(itemId: "copper-plate", count: 5)
            ]
        )
        solarPanel.powerProduction = 60
        solarPanel.inputSlots = 0
        solarPanel.outputSlots = 0
        solarPanel.fuelSlots = 0
        register(solarPanel)
        
        var accumulator = BuildingDefinition(
            id: "accumulator",
            name: "Accumulator",
            type: .accumulator,
            width: 2,
            height: 2,
            maxHealth: 150,
            cost: [
                ItemStack(itemId: "iron-plate", count: 2),
                ItemStack(itemId: "battery", count: 5)
            ]
        )
        accumulator.accumulatorCapacity = 5000
        accumulator.accumulatorChargeRate = 300
        accumulator.inputSlots = 0
        accumulator.outputSlots = 0
        accumulator.fuelSlots = 0
        register(accumulator)
        
        // Lab
        var lab = BuildingDefinition(
            id: "lab",
            name: "Lab",
            type: .lab,
            width: 3,
            height: 3,
            maxHealth: 150,
            cost: [
                ItemStack(itemId: "electronic-circuit", count: 10),
                ItemStack(itemId: "iron-gear-wheel", count: 10),
                ItemStack(itemId: "transport-belt", count: 4)
            ]
        )
        lab.researchSpeed = 1
        lab.powerConsumption = 60
        lab.inputSlots = 4  // Science pack slots
        lab.outputSlots = 0
        lab.fuelSlots = 0
        register(lab)
        
        // Combat
        var gunTurret = BuildingDefinition(
            id: "gun-turret",
            name: "Gun Turret",
            type: .turret,
            width: 2,
            height: 2,
            maxHealth: 400,
            cost: [
                ItemStack(itemId: "iron-gear-wheel", count: 10),
                ItemStack(itemId: "copper-plate", count: 10),
                ItemStack(itemId: "iron-plate", count: 20)
            ]
        )
        gunTurret.turretRange = 18
        gunTurret.turretDamage = 6
        gunTurret.turretFireRate = 10
        gunTurret.inputSlots = 1  // Ammo slot
        gunTurret.outputSlots = 0
        gunTurret.fuelSlots = 0
        register(gunTurret)
        
        var laserTurret = BuildingDefinition(
            id: "laser-turret",
            name: "Laser Turret",
            type: .turret,
            width: 2,
            height: 2,
            maxHealth: 1000,
            cost: [
                ItemStack(itemId: "steel-plate", count: 20),
                ItemStack(itemId: "electronic-circuit", count: 20),
                ItemStack(itemId: "battery", count: 12)
            ]
        )
        laserTurret.turretRange = 24
        laserTurret.turretDamage = 20
        laserTurret.turretFireRate = 20
        laserTurret.powerConsumption = 800
        laserTurret.inputSlots = 1  // Ammo slot
        laserTurret.outputSlots = 0
        laserTurret.fuelSlots = 0
        register(laserTurret)
        
        let wall = BuildingDefinition(
            id: "stone-wall",
            name: "Wall",
            type: .wall,
            maxHealth: 350,
            textureId: "wall",
            cost: [ItemStack(itemId: "stone-brick", count: 5)]
        )
        register(wall)
        
        // Storage
        var woodenChest = BuildingDefinition(
            id: "wooden-chest",
            name: "Wooden Chest",
            type: .chest,
            maxHealth: 100,
            cost: [ItemStack(itemId: "wood", count: 2)]
        )
        woodenChest.inventorySlots = 16
        woodenChest.inputSlots = 0
        woodenChest.outputSlots = 0
        woodenChest.fuelSlots = 0
        register(woodenChest)
        
        var ironChest = BuildingDefinition(
            id: "iron-chest",
            name: "Iron Chest",
            type: .chest,
            maxHealth: 200,
            cost: [ItemStack(itemId: "iron-plate", count: 8)]
        )
        ironChest.inventorySlots = 32
        ironChest.inputSlots = 0
        ironChest.outputSlots = 0
        ironChest.fuelSlots = 0
        register(ironChest)
        
        var steelChest = BuildingDefinition(
            id: "steel-chest",
            name: "Steel Chest",
            type: .chest,
            maxHealth: 350,
            cost: [ItemStack(itemId: "steel-plate", count: 8)]
        )
        steelChest.inventorySlots = 48
        steelChest.inputSlots = 0
        steelChest.outputSlots = 0
        steelChest.fuelSlots = 0
        register(steelChest)

        // Oil processing buildings
        var pumpjack = BuildingDefinition(
            id: "pumpjack",
            name: "Pumpjack",
            type: .pumpjack,
            maxHealth: 200,
            cost: [ItemStack(itemId: "steel-plate", count: 5),
                   ItemStack(itemId: "iron-gear-wheel", count: 10),
                   ItemStack(itemId: "electronic-circuit", count: 5),
                   ItemStack(itemId: "pipe", count: 10)]
        )
        pumpjack.powerConsumption = 90  // kW
        pumpjack.extractionRate = 1.0   // 1 crude oil per second at full power
        pumpjack.inventorySlots = 1     // Output slot for crude oil
        pumpjack.inputSlots = 0
        pumpjack.outputSlots = 1
        pumpjack.fuelSlots = 0
        register(pumpjack)

        var waterPump = BuildingDefinition(
            id: "water-pump",
            name: "Water Pump",
            type: .waterPump,
            maxHealth: 150,
            cost: [ItemStack(itemId: "iron-plate", count: 5),
                   ItemStack(itemId: "pipe", count: 5),
                   ItemStack(itemId: "electronic-circuit", count: 2)]
        )
        waterPump.powerConsumption = 30  // kW - less than oil well
        waterPump.extractionRate = 20.0  // 20 water per second - matches Factorio offshore pump
        waterPump.inventorySlots = 0     // No inventory - outputs fluid directly to pipes
        waterPump.inputSlots = 0
        waterPump.outputSlots = 0        // No item outputs
        waterPump.fuelSlots = 0
        register(waterPump)

        var oilRefinery = BuildingDefinition(
            id: "oil-refinery",
            name: "Oil Refinery",
            type: .oilRefinery,
            width: 3,
            height: 3,
            maxHealth: 300,
            cost: [ItemStack(itemId: "steel-plate", count: 15),
                   ItemStack(itemId: "iron-gear-wheel", count: 10),
                   ItemStack(itemId: "electronic-circuit", count: 10),
                   ItemStack(itemId: "pipe", count: 10),
                   ItemStack(itemId: "stone-brick", count: 10)]
        )
        oilRefinery.powerConsumption = 420  // kW
        oilRefinery.inventorySlots = 6      // Input + outputs for various fluids
        oilRefinery.inputSlots = 2
        oilRefinery.outputSlots = 2
        oilRefinery.fuelSlots = 0
        register(oilRefinery)

        var chemicalPlant = BuildingDefinition(
            id: "chemical-plant",
            name: "Chemical Plant",
            type: .chemicalPlant,
            width: 3,
            height: 3,
            maxHealth: 300,
            cost: [ItemStack(itemId: "steel-plate", count: 5),
                   ItemStack(itemId: "iron-gear-wheel", count: 5),
                   ItemStack(itemId: "electronic-circuit", count: 5),
                   ItemStack(itemId: "pipe", count: 5)]
        )
        chemicalPlant.powerConsumption = 210  // kW
        chemicalPlant.inventorySlots = 6      // Multiple inputs and outputs
        chemicalPlant.inputSlots = 3
        chemicalPlant.outputSlots = 2
        chemicalPlant.fuelSlots = 0
        register(chemicalPlant)

        // Nuclear buildings
        var nuclearReactor = BuildingDefinition(
            id: "nuclear-reactor",
            name: "Nuclear Reactor",
            type: .nuclearReactor,
            width: 5,
            height: 5,
            maxHealth: 500,
            cost: [ItemStack(itemId: "steel-plate", count: 400),
                   ItemStack(itemId: "advanced-circuit", count: 400),
                   ItemStack(itemId: "copper-plate", count: 400),
                   ItemStack(itemId: "stone-brick", count: 400)]
        )
        nuclearReactor.powerProduction = 40000  // 40 MW
        nuclearReactor.inputSlots = 0
        nuclearReactor.outputSlots = 0
        nuclearReactor.fuelSlots = 1  // Uranium fuel cells
        register(nuclearReactor)

        var centrifuge = BuildingDefinition(
            id: "centrifuge",
            name: "Centrifuge",
            type: .centrifuge,
            width: 3,
            height: 3,
            maxHealth: 300,
            cost: [ItemStack(itemId: "centrifuge", count: 1)]
        )
        centrifuge.powerConsumption = 350  // kW
        centrifuge.inventorySlots = 4      // Input slots for uranium ore, output slots for U-235 and U-238
        centrifuge.inputSlots = 2
        centrifuge.outputSlots = 2
        centrifuge.fuelSlots = 0
        register(centrifuge)

        // Rocket facilities
        var rocketSilo = BuildingDefinition(
            id: "rocket-silo",
            name: "Rocket Silo",
            type: .rocketSilo,
            width: 9,
            height: 9,
            maxHealth: 5000,
            cost: [ItemStack(itemId: "steel-plate", count: 1000),
                   ItemStack(itemId: "stone-brick", count: 1000),
                   ItemStack(itemId: "pipe", count: 100),
                   ItemStack(itemId: "processing-unit", count: 200)]
        )
        rocketSilo.powerConsumption = 1000  // kW - high power for rocket launches
        rocketSilo.inventorySlots = 10      // Large inventory for rocket parts and fuel
        rocketSilo.inputSlots = 4
        rocketSilo.outputSlots = 0
        rocketSilo.fuelSlots = 1  // Rocket fuel
        register(rocketSilo)

        // Pipes
        var pipe = BuildingDefinition(
            id: "pipe",
            name: "Pipe",
            type: .pipe,
            maxHealth: 50,
            cost: [ItemStack(itemId: "iron-plate", count: 1)]
        )
        pipe.fluidCapacity = 100
        register(pipe)

        var undergroundPipe = BuildingDefinition(
            id: "underground-pipe",
            name: "Underground Pipe",
            type: .pipe,
            maxHealth: 60,
            cost: [ItemStack(itemId: "iron-plate", count: 5),
                   ItemStack(itemId: "pipe", count: 5)]
        )
        undergroundPipe.fluidCapacity = 300  // Underground pipe capacity
        register(undergroundPipe)

        // Storage Tank
        var storageTank = BuildingDefinition(
            id: "fluid-tank",
            name: "Fluid Tank",
            type: .fluidTank,
            width: 3,
            height: 3,
            maxHealth: 500,
            cost: [
                ItemStack(itemId: "iron-plate", count: 20),
                ItemStack(itemId: "steel-plate", count: 5),
                ItemStack(itemId: "iron-gear-wheel", count: 3)
            ]
        )
        storageTank.fluidCapacity = 25000  // 25,000 unit capacity like Factorio
        register(storageTank)
    }
}

