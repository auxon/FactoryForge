//
//  FluidMachineUIComponent.swift
//  FactoryForge
//
//  Created by Richard Anthony Hein on 2026-01-15.
//
import Foundation
import UIKit

/// Component for fluid-based machines (boilers, steam engines)
class FluidMachineUIComponent: BaseMachineUIComponent {
    private var currentEntity: Entity?
    private weak var gameLoop: GameLoop?
    private weak var ui: MachineUI?
    private var fluidInputIndicators: [FluidIndicator] = []
    private var fluidOutputIndicators: [FluidIndicator] = []
    private var fluidInputLabels: [UILabel] = []
    private var producerLabels: [UILabel] = []
    private var tankLabels: [UILabel] = []
    private var fluidTankViews: [UIView] = []
    private var fluidTankImages: [UIImageView] = [] // Images for fluid textures
    private var bufferBars: [UIView] = [] // Small buffer visualization bars for converters like boilers
    private var bufferFills: [UIView] = [] // Fill views for buffer bars (one per bar)
    private var bufferLabels: [UILabel] = [] // Tiny labels under buffer bars showing amounts
    private var boilerBuffersSetup: Bool = false // Track if boiler buffers have been set up

    override func setupUI(for entity: Entity, in ui: MachineUI) {
        clearFluidUI()
        currentEntity = entity
        gameLoop = ui.gameLoop
        self.ui = ui
        let buildingDef = ui.getBuildingDefinition(for: entity, gameLoop: ui.gameLoop!)
        setupFluidIndicators(for: entity, in: ui, buildingDef: buildingDef)
        positionLabels(in: ui)
    }

    private func clearTankViews() {
        for view in fluidTankViews {
            view.removeFromSuperview()
        }
        fluidTankViews.removeAll()
        fluidTankImages.removeAll()
    }

    private func clearFluidUI() {
        for l in fluidInputLabels { l.removeFromSuperview() }
        for l in producerLabels { l.removeFromSuperview() }
        for l in tankLabels { l.removeFromSuperview() }
        for bar in bufferBars { bar.removeFromSuperview() }
        for l in bufferLabels { l.removeFromSuperview() }

        fluidInputLabels.removeAll()
        producerLabels.removeAll()
        tankLabels.removeAll()
        bufferBars.removeAll()
        bufferFills.removeAll()
        bufferLabels.removeAll()
        boilerBuffersSetup = false

        fluidInputIndicators.removeAll()
        fluidOutputIndicators.removeAll()

        clearTankViews()
    }

    override func updateUI(for entity: Entity, in ui: MachineUI) {
        print("FluidMachineUIComponent: updateUI called for entity \(entity.id)")
        currentEntity = entity
        gameLoop = ui.gameLoop
        self.ui = ui

        let buildingDef = ui.getBuildingDefinition(for: entity, gameLoop: ui.gameLoop!)
        let isBoiler = (buildingDef?.id == "boiler")

        if isBoiler {
            // For boilers, check if buffers are set up
            if !boilerBuffersSetup {
                print("FluidMachineUIComponent: Boiler buffers not setup, setting up UI")
                clearFluidUI()
                setupFluidIndicators(for: entity, in: ui, buildingDef: buildingDef)
                positionLabels(in: ui)
            } else {
                print("FluidMachineUIComponent: Boiler buffers already setup, calling updateFluidIndicators")
                updateFluidIndicators(for: entity, in: ui)
            }
        } else {
            // For non-boilers, use the original tank-based logic
            if let tank = ui.gameLoop?.world.get(FluidTankComponent.self, for: entity) {
                let currentTankCount = tank.tanks.count
                let displayedTankCount = fluidTankViews.count
                print("FluidMachineUIComponent: Tank check - current: \(currentTankCount), displayed: \(displayedTankCount)")

                // If tank count changed, re-setup the fluid indicators
                if currentTankCount != displayedTankCount {
                    print("FluidMachineUIComponent: Tank count changed from \(displayedTankCount) to \(currentTankCount), re-setting up UI")
                    clearFluidUI()
                    setupFluidIndicators(for: entity, in: ui, buildingDef: buildingDef)
                    positionLabels(in: ui)
                } else {
                    print("FluidMachineUIComponent: Tank count unchanged, calling updateFluidIndicators")
                    updateFluidIndicators(for: entity, in: ui)
                }
            } else {
                print("FluidMachineUIComponent: No tank component, calling updateFluidIndicators")
                updateFluidIndicators(for: entity, in: ui)
            }
        }
    }

    override func getLabels() -> [UILabel] {
        let labels = fluidInputLabels + producerLabels + tankLabels
        
        return labels
    }

    override func render(in renderer: MetalRenderer) {
        // Render fluid input indicators
        for indicator in fluidInputIndicators {
            indicator.render(renderer: renderer)
        }

        // Render fluid output indicators
        for indicator in fluidOutputIndicators {
            indicator.render(renderer: renderer)
        }

        // Render conversion arrow for boilers (Water → Steam)
        if fluidInputIndicators.count >= 1 && fluidOutputIndicators.count >= 1 {
            let inputIndicator = fluidInputIndicators[0]
            let outputIndicator = fluidOutputIndicators[0]

            // Position arrow between the two indicators
            let arrowX = (inputIndicator.frame.center.x + outputIndicator.frame.center.x) * 0.5
            let arrowY = inputIndicator.frame.center.y
            let arrowSize: Float = 12

            let arrowRect = renderer.textureAtlas.getTextureRect(for: "right_arrow")
            renderer.queueSprite(SpriteInstance(
                position: Vector2(arrowX, arrowY),
                size: Vector2(arrowSize, arrowSize),
                textureRect: arrowRect,
                color: Color(r: 0.8, g: 0.8, b: 0.9, a: 0.7),
                layer: .ui
            ))
        }
    }

    func positionLabels(in ui: MachineUI) {
        guard let entity = currentEntity, let gameLoop = gameLoop else { return }
        let buildingDef = ui.getBuildingDefinition(for: entity, gameLoop: gameLoop)
        let scale = UIScreen.main.scale
        let panelOriginPts = ui.panelFrameInPoints().origin

        // Position fluid input labels to the right of indicators, stacked vertically
        for (index, label) in fluidInputLabels.enumerated() {
            guard index < fluidInputIndicators.count else { continue }
            let indicator = fluidInputIndicators[index]

            // Position label to the right of the indicator, aligned with indicator Y
            let labelWidth: Float = 130
            let labelHeight: Float = 20
            let labelSpacing: Float = 4

            let labelX = indicator.frame.maxX + labelSpacing
            let labelY = indicator.frame.minY

            // Convert to UIView coordinates relative to rootView
            let uiX = CGFloat(labelX) / scale - panelOriginPts.x
            let uiY = CGFloat(labelY) / scale - panelOriginPts.y

            label.frame = CGRect(x: uiX, y: uiY, width: CGFloat(labelWidth), height: CGFloat(labelHeight))
        }

        // Producer labels to the right of indicators, stacked vertically
        for (i, label) in producerLabels.enumerated() {
            guard i < fluidOutputIndicators.count else { continue }
            let ind = fluidOutputIndicators[i]

            let labelWidth: Float = 130
            let labelHeight: Float = 20
            let labelSpacing: Float = 4

            let labelXpx = ind.frame.maxX + labelSpacing
            let labelYpx = ind.frame.minY

            label.frame = CGRect(
                x: CGFloat(labelXpx)/scale - panelOriginPts.x,
                y: CGFloat(labelYpx)/scale - panelOriginPts.y,
                width: CGFloat(labelWidth),
                height: CGFloat(labelHeight)
            )
        }

        // Position buffer bars for boilers
        if buildingDef?.id == "boiler" {
            positionBoilerBufferBars(in: ui)
        }

        // Tank labels to the right of tank views, stacked vertically
        for (i, label) in tankLabels.enumerated() {
            guard i < fluidTankViews.count else { continue }
            let tankFrame = fluidTankViews[i].frame

            let labelWidth: CGFloat = 90
            let labelHeight: CGFloat = 20
            let labelSpacing: CGFloat = 4

            label.frame = CGRect(
                x: tankFrame.maxX + labelSpacing,
                y: tankFrame.minY,
                width: labelWidth,
                height: labelHeight
            )
        }
    }

    private func setupBoilerBars(in rootView: UIView, count: Int) {
        bufferBars.removeAll()
        bufferFills.removeAll()
        bufferLabels.removeAll()

        for _ in 0..<count {
            let bar = UIView()
            bar.backgroundColor = UIColor.gray.withAlphaComponent(0.25)
            bar.layer.borderWidth = 1
            bar.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
            bar.layer.cornerRadius = 2
            bar.clipsToBounds = true

            let fill = UIView()
            fill.frame = .zero
            fill.layer.cornerRadius = 2
            bar.addSubview(fill)

            // Create tiny label under the bar
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 8, weight: .regular)
            label.textColor = UIColor.white.withAlphaComponent(0.7)
            label.textAlignment = .center
            label.text = "0/540"

            rootView.addSubview(bar)
            rootView.addSubview(label)
            bufferBars.append(bar)
            bufferFills.append(fill)
            bufferLabels.append(label)
        }
    }

    private func setupFluidIndicators(for entity: Entity, in ui: MachineUI, buildingDef: BuildingDefinition?) {
        guard let gameLoop = ui.gameLoop else { return }

        print("FluidMachineUIComponent: setupFluidIndicators called for entity \(entity.id)")

        let indicatorSize: Float = 40 * UIScale  // Match fuel slot size

        // Check if components exist
        let consumer = gameLoop.world.get(FluidConsumerComponent.self, for: entity)
        let producer = gameLoop.world.get(FluidProducerComponent.self, for: entity)
        let tank = gameLoop.world.get(FluidTankComponent.self, for: entity)
        print("FluidMachineUIComponent: Components - consumer: \(consumer != nil), producer: \(producer != nil), tank: \(tank != nil)")
        if let consumer = consumer {
            print("FluidMachineUIComponent: Consumer details - inputType: \(consumer.inputType), consumptionRate: \(consumer.consumptionRate)")
        }
        if let producer = producer {
            print("FluidMachineUIComponent: Producer details - outputType: \(producer.outputType), productionRate: \(producer.productionRate)")
        }

        // Use MachineUILayout for more stable positioning
        let layoutY: Float
        let waterX: Float
        let steamX: Float

        if let rootView = ui.rootView {
            let L = MachineUILayout(bounds: rootView.bounds)
            let scale = Float(UIScreen.main.scale)
            let panelOriginPts = ui.panelFrameInPoints().origin

            // Convert UIKit layout coordinates to Metal pixels
            // Use boilerLaneY for better vertical centering of the conversion indicators
            layoutY = (Float(L.boilerLaneY) + Float(panelOriginPts.y)) * scale
            waterX = (Float(L.midColX) - 80 + Float(panelOriginPts.x)) * scale
            steamX = (Float(L.midColX) + 80 + Float(panelOriginPts.x)) * scale
        } else {
            // Fallback to old positioning
            layoutY = ui.frame.center.y
            waterX = ui.frame.center.x - 150 * UIScale
            steamX = ui.frame.center.x - 150 * UIScale + 100 * UIScale
        }

        var fluidIndex = 0

        // Check for fluid consumers (water input) - place at water position
        if gameLoop.world.get(FluidConsumerComponent.self, for: entity) != nil {
            print("FluidMachineUIComponent: Creating consumer indicator")
            let inputFrame = Rect(center: Vector2(waterX, layoutY), size: Vector2(indicatorSize, indicatorSize))
            let inputIndicator = FluidIndicator(frame: inputFrame, isInput: true)
            fluidInputIndicators.append(inputIndicator)

            let inputLabel = ui.createFluidLabel()
            fluidInputLabels.append(inputLabel)

            // Add label to rootView
            if let rootView = ui.rootView {
                rootView.addSubview(inputLabel)
            }

            fluidIndex += 1
        } else {
            print("FluidMachineUIComponent: No consumer component found")
        }

        // Check for fluid producers (steam output) - place at steam position
        if gameLoop.world.get(FluidProducerComponent.self, for: entity) != nil {
            print("FluidMachineUIComponent: Creating producer indicator")
            let outputFrame = Rect(center: Vector2(steamX, layoutY), size: Vector2(indicatorSize, indicatorSize))
            let outputIndicator = FluidIndicator(frame: outputFrame, isInput: false)
            outputIndicator.isProducer = true
            fluidOutputIndicators.append(outputIndicator)

            let outputLabel = ui.createFluidLabel()
            producerLabels.append(outputLabel)

            // Add label to rootView
            if let rootView = ui.rootView {
                rootView.addSubview(outputLabel)
            }

            fluidIndex += 1
        } else {
            print("FluidMachineUIComponent: No producer component found")
        }

        // Check for fluid tanks (used by oil refineries, chemical plants, etc.)
        // Fluid tanks can serve as both inputs and outputs depending on the recipe
        // Only create the generic "tank acts like an input" indicator
        // for machines that are basically just tanks / fluid storage,
        // not converters like boilers/engines.
        let hasConsumer = (gameLoop.world.get(FluidConsumerComponent.self, for: entity) != nil)
        let hasProducer = (gameLoop.world.get(FluidProducerComponent.self, for: entity) != nil)
        let hasTank = (gameLoop.world.get(FluidTankComponent.self, for: entity) != nil)

        let isOilRefinery = (buildingDef?.type == .oilRefinery)
        let isChemicalPlant = (buildingDef?.type == .chemicalPlant)

        if hasTank && !isOilRefinery && !isChemicalPlant && !hasConsumer && !hasProducer {
            // For tank-only machines, use the water position (since they're input-focused)
            let inputFrame = Rect(center: Vector2(waterX, layoutY), size: Vector2(indicatorSize, indicatorSize))
            let inputIndicator = FluidIndicator(frame: inputFrame, isInput: true)
            fluidInputIndicators.append(inputIndicator)

            let inputLabel = ui.createFluidLabel()
            fluidInputLabels.append(inputLabel)

            // Add label to rootView
            if let rootView = ui.rootView {
                rootView.addSubview(inputLabel)
            }

            fluidIndex += 1
        }

        // For boilers, add small buffer visualization bars below the indicators
        if buildingDef?.id == "boiler", let rootView = ui.rootView {
            setupBoilerBars(in: rootView, count: 2) // Boilers always have 2 buffers: water and steam
            boilerBuffersSetup = true
        }

        // Check for fluid tanks - create UIKit views for fluid tank indicators
        // Skip for boilers since they use buffer bars instead
        let isBoiler = (buildingDef?.id == "boiler")
        if let tank = gameLoop.world.get(FluidTankComponent.self, for: entity), !isBoiler {
            print("FluidMachineUIComponent: Found FluidTankComponent with \(tank.tanks.count) tanks, maxCapacity: \(tank.maxCapacity)")

            // Position tanks just below the progress bar in a fixed right column
            let tankSpacing: Float = 50 * UIScale  // Reduced spacing for better fit

            // Calculate fixed right-side X position in UIKit points, then convert to Metal pixels
            let tankXUIKitPoints: Float
            if let rootView = ui.rootView {
                tankXUIKitPoints = Float(rootView.bounds.width) * 0.75  // 75% from left for right column
            } else {
                tankXUIKitPoints = Float(ui.frame.center.x) + 150 * UIScale  // Fallback
            }

            // Convert UIKit points to Metal pixels
            let scale = Float(UIScreen.main.scale)
            let panelOriginPts = ui.panelFrameInPoints().origin
            let tankBaseX = (tankXUIKitPoints + Float(panelOriginPts.x)) * scale
            let labelSpacing: Float = 20 * UIScale

            // Calculate starting Y position based on progress bar position
            let progressBarBottom: Float
            if let rootView = ui.rootView {
                let b = rootView.bounds
                let scale = Float(UIScreen.main.scale)
                let panelOriginPts = ui.panelFrameInPoints().origin

                // Progress bar position in UIKit points
                let barYUIPoints = Float(b.height) * 0.18
                let barHeight: Float = 20

                // Convert to Metal coordinates: (UIKit points + panel origin) * scale
                let barYMetal = (barYUIPoints + Float(panelOriginPts.y)) * scale
                progressBarBottom = barYMetal + (barHeight * 4) + 16 * scale // Add padding below progress bar
            } else {
                progressBarBottom = Float(ui.frame.center.y) // Fallback
            }

            // Show at least one tank indicator, even if empty
            let tankCount = max(tank.tanks.count, 1)
            let maxVisibleTanks = 8 // Allow up to 8 tanks for complex fluid processing buildings
            print("FluidMachineUIComponent: Found \(tank.tanks.count) tanks, will show \(min(tankCount, maxVisibleTanks)) tank indicators")
            for i in 0..<tank.tanks.count {
                let tank = tank.tanks[i]
                print("FluidMachineUIComponent: Tank \(i): \(tank.amount)L of \(tank.type)")
            }

            // Get building definition to determine input vs output tank positioning
            let buildingDef = ui.getBuildingDefinition(for: ui.currentEntity!, gameLoop: ui.gameLoop!)
            let inputTankCount = buildingDef?.fluidInputTanks ?? 0

            for index in 0..<min(tankCount, maxVisibleTanks) { // Allow more tanks for fluid processing
                // Determine X position based on whether this is an input or output tank
                let isInputTank = index < inputTankCount
                let tankX: Float

                if isInputTank {
                    // Input tanks go near the left edge of the panel with padding
                    if ui.rootView != nil {
                        let leftPadding: Float = 30 * UIScale // Padding from left edge
                        let leftXUIKitPoints = leftPadding
                        let scale = Float(UIScreen.main.scale)
                        let panelOriginPts = ui.panelFrameInPoints().origin
                        tankX = (leftXUIKitPoints + Float(panelOriginPts.x)) * scale
                    } else {
                        tankX = tankBaseX - 200 * UIScale // Fallback position
                    }
                } else {
                    // Output tanks stay on the right side
                    tankX = tankBaseX // Original right position
                }

                let tankY = progressBarBottom + Float(index % 4) * (tankSpacing + labelSpacing) // Wrap every 4 tanks
                let tankSize: Float = indicatorSize
                let tankFrame = Rect(center: Vector2(tankX, tankY), size: Vector2(tankSize, tankSize))

                // Convert Metal pixel coordinates to UIKit points relative to rootView
                let scale = UIScreen.main.scale
                let panelOriginPts = ui.panelFrameInPoints().origin

                let xPtsScreen = CGFloat(tankFrame.minX) / scale
                let yPtsScreen = CGFloat(tankFrame.minY) / scale

                let tankView = UIView(frame: CGRect(
                    x: xPtsScreen - panelOriginPts.x,
                    y: yPtsScreen - panelOriginPts.y,
                    width: CGFloat(tankFrame.size.x) / scale,
                    height: CGFloat(tankFrame.size.y) / scale
                ))

                // Style the tank indicator (white border, gray background for empty tanks)
                tankView.backgroundColor = UIColor.gray.withAlphaComponent(0.7)  // Gray for empty tanks
                tankView.layer.borderColor = UIColor.white.cgColor
                tankView.layer.borderWidth = 1.5
                tankView.layer.cornerRadius = 4.0

                // Add tap gesture to allow emptying tanks
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tankViewTapped(_:)))
                tankView.addGestureRecognizer(tapGesture)
                tankView.isUserInteractionEnabled = true
                tankView.tag = index // Store tank index

                // Add to the UI panel
                if let rootView = ui.rootView {
                    rootView.addSubview(tankView)
                    fluidTankViews.append(tankView)
                    print("FluidMachineUIComponent: Added tank view \(index) at UIKit frame: \(tankView.frame), rootView bounds: \(rootView.bounds), panelOriginPts: \(panelOriginPts)")
                }

                // Create image view for fluid texture
                let fluidImageView = UIImageView(frame: tankView.bounds)
                fluidImageView.contentMode = .scaleAspectFill
                fluidImageView.clipsToBounds = true
                fluidImageView.isHidden = true // Hidden by default (empty tank)
                tankView.addSubview(fluidImageView)
                fluidTankImages.append(fluidImageView)

                // Add label for tank
                let tankLabel = ui.createFluidLabel()
                tankLabels.append(tankLabel)

                // Add label to rootView
                if let rootView = ui.rootView {
                    rootView.addSubview(tankLabel)
                }

                print("FluidMachineUIComponent: Created UIKit tank indicator \(index)")
            }
        } else {
            print("FluidMachineUIComponent: No FluidTankComponent found for entity \(entity.id)")
        }
    }

    private func positionBoilerBufferBars(in ui: MachineUI) {
        guard bufferBars.count >= 2, bufferLabels.count >= 2 else { return }
        guard fluidInputIndicators.count >= 1, fluidOutputIndicators.count >= 1 else { return }
        guard fluidInputLabels.count >= 1, producerLabels.count >= 1 else { return }

        let scale = UIScreen.main.scale
        let panelOriginPts = ui.panelFrameInPoints().origin

        let barWidth: CGFloat = 80
        let barHeight: CGFloat = 8
        let gap: CGFloat = 6
        let labelGap: CGFloat = 2

        // water
        do {
            let ind = fluidInputIndicators[0]
            let x = CGFloat(ind.frame.minX) / scale - panelOriginPts.x
            let barY = fluidInputLabels[0].frame.maxY + gap
            let labelY = barY + barHeight + labelGap

            bufferBars[0].frame = CGRect(x: x, y: barY, width: barWidth, height: barHeight)
            bufferLabels[0].frame = CGRect(x: x, y: labelY, width: barWidth, height: 10)
        }

        // steam
        do {
            let ind = fluidOutputIndicators[0]
            let x = CGFloat(ind.frame.minX) / scale - panelOriginPts.x
            let barY = producerLabels[0].frame.maxY + gap
            let labelY = barY + barHeight + labelGap

            bufferBars[1].frame = CGRect(x: x, y: barY, width: barWidth, height: barHeight)
            bufferLabels[1].frame = CGRect(x: x, y: labelY, width: barWidth, height: 10)
        }
    }

    @objc private func tankViewTapped(_ sender: UITapGestureRecognizer) {
        guard let tankView = sender.view,
              let entity = currentEntity,
              let gameLoop = gameLoop,
              let ui = ui else { return }

        let tankIndex = tankView.tag

        if let fluidTank = gameLoop.world.get(FluidTankComponent.self, for: entity),
           tankIndex < fluidTank.tanks.count {

            let tank = fluidTank.tanks[tankIndex]
            if tank.amount > 0 {
                // Empty the tank by replacing it with an empty tank of the same type
                fluidTank.tanks[tankIndex] = FluidStack(type: tank.type, amount: 0, temperature: tank.temperature, maxAmount: tank.maxAmount)
                gameLoop.world.add(fluidTank, to: entity)

                // Update the UI immediately
                ui.updateMachine(entity)

                // Play sound and show tooltip
                AudioManager.shared.playClickSound()
                gameLoop.inputManager?.onTooltip?("Tank emptied")
            }
        }
    }

    private func updateFluidIndicators(for entity: Entity, in ui: MachineUI) {
        guard let gameLoop = ui.gameLoop else { 
            print("FluidMachineUIComponent: updateFluidIndicators - no gameLoop")
            return 
        }

        let buildingDef = ui.getBuildingDefinition(for: entity, gameLoop: gameLoop)
        let isBoiler = (buildingDef?.id == "boiler")

        print("FluidMachineUIComponent: updateFluidIndicators called for entity \(entity.id), building: \(buildingDef?.id ?? "unknown"), isBoiler: \(isBoiler)")
        print("FluidMachineUIComponent: fluidOutputIndicators.count: \(fluidOutputIndicators.count), producerLabels.count: \(producerLabels.count)")
        print("FluidMachineUIComponent: fluidInputIndicators.count: \(fluidInputIndicators.count), fluidInputLabels.count: \(fluidInputLabels.count)")

        // Update fluid producers
        let producer = gameLoop.world.get(FluidProducerComponent.self, for: entity)
        print("FluidMachineUIComponent: Producer component exists: \(producer != nil)")
        if let producer = producer,
           fluidOutputIndicators.count > 0 && producerLabels.count > 0 {
            print("FluidMachineUIComponent: Producer - outputType: \(producer.outputType), productionRate: \(producer.productionRate), currentProduction: \(producer.currentProduction), connections: \(producer.connections.count)")
            fluidOutputIndicators[0].fluidType = producer.outputType
            fluidOutputIndicators[0].amount = producer.currentProduction * 60.0
            fluidOutputIndicators[0].maxAmount = producer.productionRate * 60.0
            fluidOutputIndicators[0].hasConnection = !producer.connections.isEmpty

            let actualRate = producer.currentProduction
            let targetRate = producer.productionRate
            let flowRateText: String
            if abs(actualRate - targetRate) < 0.01 {
                // Rates match - show single value
                flowRateText = String(format: "%.1f L/s", targetRate)
            } else {
                // Rates differ - show actual/target
                flowRateText = String(format: "%.1f/%.1f L/s", actualRate, targetRate)
            }
            let fluidName = producer.outputType == .steam ? "Steam" : producer.outputType.rawValue
            producerLabels[0].text = "\(fluidName): \(flowRateText)"
            print("FluidMachineUIComponent: Updated producer label: \(producerLabels[0].text!), currentProduction: \(producer.currentProduction), productionRate: \(producer.productionRate)")
        } else {
            print("FluidMachineUIComponent: Producer update skipped - producer: \(producer != nil), indicators: \(fluidOutputIndicators.count), labels: \(producerLabels.count)")
        }

        // Update buffer bars for boilers
        if let tank = gameLoop.world.get(FluidTankComponent.self, for: entity),
           bufferBars.count >= 2, bufferFills.count >= 2, bufferLabels.count >= 2 {
            // Ensure bars have been laid out before using bounds
            if bufferBars[0].bounds.width <= 1 || bufferBars[1].bounds.width <= 1 { return }

            for i in 0..<min(2, tank.tanks.count) {
                let stack = tank.tanks[i]
                let frac = stack.maxAmount > 0 ? CGFloat(stack.amount / stack.maxAmount) : 0
                let f = min(max(frac, 0), 1)

                let fill = bufferFills[i]
                fill.frame = CGRect(x: 0, y: 0, width: bufferBars[i].bounds.width * f, height: bufferBars[i].bounds.height)

                fill.backgroundColor = (stack.type == .water)
                    ? UIColor.systemBlue.withAlphaComponent(0.85)
                    : UIColor.lightGray.withAlphaComponent(0.85)

                // Update label with current/max amounts
                let currentAmount = Int(stack.amount.rounded())
                let maxAmount = Int(stack.maxAmount.rounded())
                bufferLabels[i].text = "\(currentAmount)/\(maxAmount)"
            }
        }

        // Update fluid consumers
        let consumer = gameLoop.world.get(FluidConsumerComponent.self, for: entity)
        print("FluidMachineUIComponent: Consumer component exists: \(consumer != nil)")
        if let consumer = consumer,
           fluidInputIndicators.count > 0 && fluidInputLabels.count > 0 {
            print("FluidMachineUIComponent: Consumer - inputType: \(consumer.inputType), consumptionRate: \(consumer.consumptionRate), currentConsumption: \(consumer.currentConsumption), connections: \(consumer.connections.count)")
            fluidInputIndicators[0].fluidType = consumer.inputType
            fluidInputIndicators[0].amount = consumer.currentConsumption * 60.0
            fluidInputIndicators[0].maxAmount = consumer.consumptionRate * 60.0
            fluidInputIndicators[0].hasConnection = !consumer.connections.isEmpty

            let actualRate = consumer.currentConsumption
            let targetRate = consumer.consumptionRate
            let flowRateText: String
            if abs(actualRate - targetRate) < 0.01 {
                // Rates match - show single value
                flowRateText = String(format: "%.1f L/s", targetRate)
            } else {
                // Rates differ - show actual/target
                flowRateText = String(format: "%.1f/%.1f L/s", actualRate, targetRate)
            }
            let fluidName = consumer.inputType == .water ? "Water" : consumer.inputType!.rawValue
            fluidInputLabels[0].text = "\(fluidName): \(flowRateText)"
            print("FluidMachineUIComponent: Updated consumer label: \(fluidInputLabels[0].text!), currentConsumption: \(consumer.currentConsumption), consumptionRate: \(consumer.consumptionRate)")
        } else {
            print("FluidMachineUIComponent: Consumer update skipped - consumer: \(consumer != nil), indicators: \(fluidInputIndicators.count), labels: \(fluidInputLabels.count)")
        }

        // Update fluid tank inputs (for oil refineries, chemical plants, etc.)
        // Show the current tank contents as input indicators
        // Only for machines that are tank-only, not converters
        let hasConsumer = (gameLoop.world.get(FluidConsumerComponent.self, for: entity) != nil)
        let hasProducer = (gameLoop.world.get(FluidProducerComponent.self, for: entity) != nil)

        if !hasConsumer && !hasProducer,
           let tank = gameLoop.world.get(FluidTankComponent.self, for: entity),
           fluidInputIndicators.count > 0 && fluidInputLabels.count > 0 {
            // For fluid tanks, show the current tank contents
            if tank.tanks.isEmpty {
                // No fluids in tanks
                fluidInputIndicators[0].fluidType = nil
                fluidInputIndicators[0].amount = 0
                fluidInputIndicators[0].maxAmount = tank.maxCapacity
                fluidInputIndicators[0].hasConnection = !tank.connections.isEmpty
                fluidInputLabels[0].text = "Empty"
            } else {
                // Show the first tank's contents (or aggregate if multiple tanks)
                let totalAmount = tank.tanks.reduce(0) { $0 + $1.amount }
                let firstTank = tank.tanks[0]
                fluidInputIndicators[0].fluidType = firstTank.type
                fluidInputIndicators[0].amount = totalAmount
                fluidInputIndicators[0].maxAmount = tank.maxCapacity
                fluidInputIndicators[0].hasConnection = !tank.connections.isEmpty

                let fluidName = firstTank.type.rawValue
                let amountText = String(format: "%.0f L", totalAmount)
                fluidInputLabels[0].text = "\(fluidName): \(amountText)"
            }
        }

        // Update fluid tanks (UIKit views) - skip for boilers
        if let tank = gameLoop.world.get(FluidTankComponent.self, for: entity), !isBoiler {
            let maxVisibleTanks = 8
            for i in 0..<min(tankLabels.count, max(tank.tanks.count, 1), maxVisibleTanks) {
                if tank.tanks.indices.contains(i) && i < fluidTankViews.count && i < fluidTankImages.count {
                    let stack = tank.tanks[i]
                    let tankView = fluidTankViews[i]
                    let fluidImageView = fluidTankImages[i]

                    if stack.amount > 0 {
                        // Tank has fluid - show texture
                        let fluidName = stack.type.rawValue.replacingOccurrences(of: "-", with: " ").capitalized
                        tankLabels[i].text = String(format: "%@: %.0f/%.0f L", fluidName, stack.amount, stack.maxAmount)

                        // Load fluid texture
                        let textureName = stack.type.rawValue.replacingOccurrences(of: "-", with: "_")
                        if let fluidImage = ui.loadRecipeImage(for: textureName) {
                            fluidImageView.image = fluidImage
                            fluidImageView.isHidden = false
                            tankView.backgroundColor = UIColor.clear // Hide gray background when showing texture
                        } else {
                            // Fallback to colored background if texture not found
                            fluidImageView.isHidden = true
                            tankView.backgroundColor = ui.getFluidColor(for: stack.type)
                        }
                    } else {
                        // Tank is empty - show gray background
                        tankLabels[i].text = String(format: "Empty: 0/%.0f L", stack.maxAmount)
                        fluidImageView.isHidden = true
                        tankView.backgroundColor = UIColor.gray.withAlphaComponent(0.7)
                    }
                } else if i < tankLabels.count {
                    tankLabels[i].text = String(format: "Empty: 0/%.0f L", tank.maxCapacity)
                    if i < fluidTankViews.count {
                        fluidTankViews[i].backgroundColor = UIColor.gray.withAlphaComponent(0.7)
                    }
                    if i < fluidTankImages.count {
                        fluidTankImages[i].isHidden = true
                    }
                }
            }
        }
    }
}
