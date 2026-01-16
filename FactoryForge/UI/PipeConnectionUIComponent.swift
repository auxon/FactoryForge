//
//  PipeConnectionUIComponent.swift
//  FactoryForge
//
//  Created by Richard Anthony Hein on 2026-01-15.
//
import Foundation
import UIKit

/// Component for managing pipe connections and networks
class PipeConnectionUIComponent: BaseMachineUIComponent {
    private var connectionButtons: [Direction: UIKit.UIButton] = [:]
    private var networkLabel: UILabel?
    private var networkIdLabel: UILabel?
    private var changeNetworkButton: UIKit.UIButton?
    private var mergeNetworkButton: UIKit.UIButton?
    private var clearPipeButton: UIKit.UIButton?
    private var clearNetworkButton: UIKit.UIButton?
    private var clearTanksButton: UIKit.UIButton?
    private var availableNetworksLabel: UILabel?
    private var mergeButtons: [Int: UIKit.UIButton] = [:]
    private var scrollView: UIScrollView?
    private var scrollContentView: UIView?

    // Store current pipe state
    private var currentNetworkId: Int?
    private var connectedDirections: Set<Direction> = []

    // Merge UI state
    private var showingMergeOptions: Bool = false

    // Tank selection UI state
    private var showingTankSelection: Bool = false
    private var adjacentBuildingsWithTanks: [(entity: Entity, direction: Direction, tanks: [FluidStack])] = []
    private var tankSelectionLabels: [UILabel] = []
    private var tankSelectionButtons: [Int: UIKit.UIButton] = [:] // Tank index -> Button

    // Reference to parent UI
    private weak var parentUI: MachineUI?

    override func setupUI(for entity: Entity, in ui: MachineUI) {
        guard let gameLoop = ui.gameLoop,
              let pipe = gameLoop.world.get(PipeComponent.self, for: entity) else {
            return
        }

        print("PipeConnectionUIComponent: Setting up UI for pipe entity \(entity.id)")

        // Store parent UI reference
        parentUI = ui

        teardownUIElements()

        setupScrollContainer(in: ui)

        // Store current state
        if pipe.networkId == nil {
            gameLoop.fluidNetworkSystem.markEntityDirty(entity)
            gameLoop.fluidNetworkSystem.rebuildNetworks()
        }
        currentNetworkId = gameLoop.world.get(PipeComponent.self, for: entity)?.networkId
        connectedDirections = getConnectedDirections(for: entity, in: gameLoop.world)

        // Find adjacent buildings with fluid tanks
        adjacentBuildingsWithTanks = findAdjacentBuildingsWithTanks(for: entity, in: gameLoop.world)

        // Create network info section
        setupNetworkInfo(in: ui)

        // Create directional connection buttons
        setupConnectionButtons(in: ui)

        // Create tank selection section if adjacent buildings found
        if !adjacentBuildingsWithTanks.isEmpty {
            setupTankSelectionSection(in: ui)
        }

        // Position all elements
        positionLabels(in: ui)
    }

    func positionLabels(in ui: MachineUI) {
        guard let rootView = ui.rootView else { return }
        let panelRect = rootView.bounds

        if let scrollView = scrollView {
            scrollView.frame = rootView.bounds
        }

        // Start positioning from top-left of panel
        var currentY: CGFloat = 20 // Start 20 points from top

        // Position network info section
        if let networkLabel = networkLabel {
            networkLabel.frame = CGRect(x: 20, y: currentY, width: panelRect.width - 40, height: 20)
            currentY += 25
        }

        if let networkIdLabel = networkIdLabel {
            networkIdLabel.frame = CGRect(x: 20, y: currentY, width: panelRect.width - 40, height: 20)
            currentY += 25
        }

        // Tank selection button (if adjacent buildings exist)
        if !adjacentBuildingsWithTanks.isEmpty {
            if let changeNetworkButton = changeNetworkButton {
                changeNetworkButton.frame = CGRect(x: 20, y: currentY, width: panelRect.width - 40, height: 30)
                currentY += 40
            }
        } else {
            // Original change network button for network management
            if let changeNetworkButton = changeNetworkButton {
                changeNetworkButton.frame = CGRect(x: 20, y: currentY, width: panelRect.width - 40, height: 30)
                currentY += 40
            }
        }

        if let mergeNetworkButton = mergeNetworkButton {
            mergeNetworkButton.frame = CGRect(x: 20, y: currentY, width: panelRect.width - 40, height: 30)
            currentY += 45
        }

        if let clearPipeButton = clearPipeButton {
            clearPipeButton.frame = CGRect(x: 20, y: currentY, width: panelRect.width - 40, height: 30)
            currentY += 45
        }

        if let clearNetworkButton = clearNetworkButton {
            clearNetworkButton.frame = CGRect(x: 20, y: currentY, width: panelRect.width - 40, height: 30)
            currentY += 45
        }

        if let clearTanksButton = clearTanksButton {
            clearTanksButton.frame = CGRect(x: 20, y: currentY, width: panelRect.width - 40, height: 30)
            currentY += 45
        }

        // Add available networks section if showing merge options
        if showingMergeOptions {
            if let availableNetworksLabel = availableNetworksLabel {
                availableNetworksLabel.frame = CGRect(x: 20, y: currentY, width: panelRect.width - 40, height: 20)
                currentY += 25
            }

            // Position merge target buttons
            for (_, button) in mergeButtons.sorted(by: { $0.key < $1.key }) {
                button.frame = CGRect(x: 30, y: currentY, width: panelRect.width - 60, height: 25)
                currentY += 30
            }
            currentY += 10 // Extra spacing after merge options
        } else if showingTankSelection {
            // Position tank selection options
            for (index, buildingInfo) in adjacentBuildingsWithTanks.enumerated() {
                // Building label
                if index < tankSelectionLabels.count {
                    let label = tankSelectionLabels[index]
                    label.frame = CGRect(x: 20, y: currentY, width: panelRect.width - 40, height: 20)
                    currentY += 25
                }

                // Tank buttons for this building
                let (_, _, tanks) = buildingInfo
                for tankIndex in 0..<tanks.count {
                    if let button = tankSelectionButtons[tankIndex] {
                        button.frame = CGRect(x: 30, y: currentY, width: panelRect.width - 60, height: 25)
                        currentY += 30
                    }
                }
                currentY += 10 // Spacing between buildings
            }
            currentY += 10 // Extra spacing after tank options
        } else {
            // Add some spacing before connection buttons when not showing merge or tank options
            currentY += 20
        }

        // Position connection buttons vertically
        let buttonWidth: CGFloat = panelRect.width - 40
        let buttonHeight: CGFloat = 35
        let buttonSpacing: CGFloat = 10

        // North
        if let northButton = connectionButtons[.north] {
            northButton.frame = CGRect(x: 20, y: currentY, width: buttonWidth, height: buttonHeight)
            currentY += buttonHeight + buttonSpacing
        }

        // East
        if let eastButton = connectionButtons[.east] {
            eastButton.frame = CGRect(x: 20, y: currentY, width: buttonWidth, height: buttonHeight)
            currentY += buttonHeight + buttonSpacing
        }

        // South
        if let southButton = connectionButtons[.south] {
            southButton.frame = CGRect(x: 20, y: currentY, width: buttonWidth, height: buttonHeight)
            currentY += buttonHeight + buttonSpacing
        }

        // West
        if let westButton = connectionButtons[.west] {
            westButton.frame = CGRect(x: 20, y: currentY, width: buttonWidth, height: buttonHeight)
        }

        let contentHeight = max(currentY + buttonHeight + 20, panelRect.height + 1)
        scrollContentView?.frame = CGRect(x: 0, y: 0, width: panelRect.width, height: contentHeight)
        scrollView?.contentSize = CGSize(width: panelRect.width, height: contentHeight)
    }

    override func updateUI(for entity: Entity, in ui: MachineUI) {
        guard let gameLoop = ui.gameLoop,
              let pipe = gameLoop.world.get(PipeComponent.self, for: entity) else {
            return
        }

        // Update network info
        if pipe.networkId == nil {
            gameLoop.fluidNetworkSystem.markEntityDirty(entity)
            gameLoop.fluidNetworkSystem.rebuildNetworks()
        }
        let refreshedNetworkId = gameLoop.world.get(PipeComponent.self, for: entity)?.networkId
        currentNetworkId = refreshedNetworkId
        networkIdLabel?.text = "Network: \(refreshedNetworkId?.description ?? "-")"

        // Update connection states
        connectedDirections = getConnectedDirections(for: entity, in: gameLoop.world)
        updateConnectionButtons()

        // Update tank selection buttons if showing
        if showingTankSelection {
            updateTankSelectionButtons()
        }
    }

    override func getLabels() -> [UILabel] {
        var labels = [UILabel]()
        if let networkLabel = networkLabel { labels.append(networkLabel) }
        if let networkIdLabel = networkIdLabel { labels.append(networkIdLabel) }
        if let availableNetworksLabel = availableNetworksLabel { labels.append(availableNetworksLabel) }
        labels.append(contentsOf: tankSelectionLabels)
        return labels
    }

    private func setupNetworkInfo(in ui: MachineUI) {
        guard let containerView = scrollContentView ?? ui.rootView else { return }

        // Network info label
        let networkInfoLabel = UILabel()
        networkInfoLabel.text = "Fluid Network"
        networkInfoLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        networkInfoLabel.textColor = .white
        networkInfoLabel.textAlignment = .center
        networkInfoLabel.frame = CGRect(x: 0, y: 0, width: 120, height: 20)
        networkInfoLabel.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.8)
        networkInfoLabel.layer.borderColor = UIColor.cyan.cgColor
        networkInfoLabel.layer.borderWidth = 1.0
        networkInfoLabel.layer.cornerRadius = 4.0
        containerView.addSubview(networkInfoLabel)
        networkLabel = networkInfoLabel

        // Network ID label
        let idLabel = UILabel()
        idLabel.text = "Network: \(currentNetworkId ?? 0)"
        idLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        idLabel.textColor = .cyan
        idLabel.textAlignment = .center
        idLabel.frame = CGRect(x: 0, y: 0, width: 120, height: 20)
        idLabel.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 0.8)
        idLabel.layer.borderColor = UIColor.cyan.cgColor
        idLabel.layer.borderWidth = 0.5
        idLabel.layer.cornerRadius = 3.0
        containerView.addSubview(idLabel)
        networkIdLabel = idLabel

        // Change network button
        let changeButton = UIKit.UIButton(type: .system)
        changeButton.setTitle("Split Network", for: .normal)
        changeButton.setTitleColor(.white, for: .normal)
        changeButton.backgroundColor = UIColor(red: 0.3, green: 0.3, blue: 0.5, alpha: 0.8)
        changeButton.layer.borderColor = UIColor.blue.cgColor
        changeButton.layer.borderWidth = 1.0
        changeButton.layer.cornerRadius = 4.0
        changeButton.frame = CGRect(x: 0, y: 0, width: 120, height: 30)
        changeButton.addTarget(self, action: #selector(changeNetworkTapped(_:)), for: .touchUpInside)
        containerView.addSubview(changeButton)
        changeNetworkButton = changeButton

        // Merge network button
        let mergeButton = UIKit.UIButton(type: .system)
        mergeButton.setTitle("Merge Networks", for: .normal)
        mergeButton.setTitleColor(.white, for: .normal)
        mergeButton.backgroundColor = UIColor(red: 0.3, green: 0.5, blue: 0.3, alpha: 0.8)
        mergeButton.layer.borderColor = UIColor.green.cgColor
        mergeButton.layer.borderWidth = 1.0
        mergeButton.layer.cornerRadius = 4.0
        mergeButton.frame = CGRect(x: 0, y: 0, width: 120, height: 30)
        mergeButton.addTarget(self, action: #selector(mergeNetworkTapped(_:)), for: .touchUpInside)
        containerView.addSubview(mergeButton)
        mergeNetworkButton = mergeButton

        // Clear pipe button
        let clearButton = UIKit.UIButton(type: .system)
        clearButton.setTitle("Clear Pipe Fluid", for: .normal)
        clearButton.setTitleColor(.white, for: .normal)
        clearButton.backgroundColor = UIColor(red: 0.5, green: 0.3, blue: 0.3, alpha: 0.8)
        clearButton.layer.borderColor = UIColor.red.cgColor
        clearButton.layer.borderWidth = 1.0
        clearButton.layer.cornerRadius = 4.0
        clearButton.frame = CGRect(x: 0, y: 0, width: 120, height: 30)
        clearButton.addTarget(self, action: #selector(clearPipeTapped(_:)), for: .touchUpInside)
        containerView.addSubview(clearButton)
        clearPipeButton = clearButton

        let clearNetwork = UIKit.UIButton(type: .system)
        clearNetwork.setTitle("Clear Network Fluid", for: .normal)
        clearNetwork.setTitleColor(.white, for: .normal)
        clearNetwork.backgroundColor = UIColor(red: 0.5, green: 0.25, blue: 0.25, alpha: 0.8)
        clearNetwork.layer.borderColor = UIColor.red.cgColor
        clearNetwork.layer.borderWidth = 1.0
        clearNetwork.layer.cornerRadius = 4.0
        clearNetwork.frame = CGRect(x: 0, y: 0, width: 120, height: 30)
        clearNetwork.addTarget(self, action: #selector(clearNetworkTapped(_:)), for: .touchUpInside)
        containerView.addSubview(clearNetwork)
        clearNetworkButton = clearNetwork

        let clearTanks = UIKit.UIButton(type: .system)
        clearTanks.setTitle("Clear Connected Tanks", for: .normal)
        clearTanks.setTitleColor(.white, for: .normal)
        clearTanks.backgroundColor = UIColor(red: 0.45, green: 0.25, blue: 0.25, alpha: 0.8)
        clearTanks.layer.borderColor = UIColor.red.cgColor
        clearTanks.layer.borderWidth = 1.0
        clearTanks.layer.cornerRadius = 4.0
        clearTanks.frame = CGRect(x: 0, y: 0, width: 120, height: 30)
        clearTanks.addTarget(self, action: #selector(clearConnectedTanksTapped(_:)), for: .touchUpInside)
        containerView.addSubview(clearTanks)
        clearTanksButton = clearTanks
    }

    private func setupConnectionButtons(in ui: MachineUI) {
        guard let containerView = scrollContentView ?? ui.rootView else { return }

        let directions: [Direction] = [.north, .east, .south, .west]
        let directionNames = ["North", "East", "South", "West"]

        for (index, direction) in directions.enumerated() {
            let button = UIKit.UIButton(type: .system)
            let isConnected = connectedDirections.contains(direction)
            let isAllowed = isDirectionAllowed(direction: direction)
            let mismatchText = fluidTypeMismatchText(for: direction)

            let stateText = isAllowed ? (isConnected ? "✓" : "✗") : "Blocked"
            let warningSuffix = mismatchText != nil ? "\nType mismatch: \(mismatchText!)" : ""
            button.setTitle("\(directionNames[index]): \(stateText)\(warningSuffix)", for: .normal)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.lineBreakMode = .byWordWrapping
            button.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .medium)
            if isAllowed {
                if mismatchText != nil {
                    button.setTitleColor(.systemOrange, for: .normal)
                } else {
                    button.setTitleColor(isConnected ? .green : .red, for: .normal)
                }
                button.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.8)
                button.layer.borderColor = UIColor.white.cgColor
            } else {
                button.setTitleColor(.lightGray, for: .normal)
                button.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 0.8)
                button.layer.borderColor = UIColor.gray.cgColor
            }
            button.layer.borderWidth = 1.0
            button.layer.cornerRadius = 4.0
            button.frame = CGRect(x: 0, y: 0, width: 100, height: 30)
            button.isEnabled = isAllowed

            // Store direction in button tag for callback
            button.tag = Int(direction.rawValue)
            button.addTarget(self, action: #selector(connectionButtonTapped(_:)), for: .touchUpInside)

            containerView.addSubview(button)
            connectionButtons[direction] = button
        }
    }

    private func setupTankSelectionSection(in ui: MachineUI) {
        guard let containerView = scrollContentView ?? ui.rootView else { return }

        // Tank selection toggle button
        let tankSelectionButton = UIKit.UIButton(type: .system)
        tankSelectionButton.setTitle("Tank Connections", for: .normal)
        tankSelectionButton.setTitleColor(.white, for: .normal)
        tankSelectionButton.backgroundColor = UIColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 0.8)
        tankSelectionButton.layer.borderColor = UIColor.green.cgColor
        tankSelectionButton.layer.borderWidth = 1.0
        tankSelectionButton.layer.cornerRadius = 4.0
        tankSelectionButton.frame = CGRect(x: 0, y: 0, width: 120, height: 30)
        tankSelectionButton.addTarget(self, action: #selector(tankSelectionTapped(_:)), for: .touchUpInside)
        containerView.addSubview(tankSelectionButton)
        changeNetworkButton = tankSelectionButton // Reuse this variable for now
    }

    @objc private func tankSelectionTapped(_ sender: UIKit.UIButton) {
        showingTankSelection = !showingTankSelection

        if showingTankSelection {
            showTankSelectionOptions()
        } else {
            hideTankSelectionOptions()
        }

        // Reposition all elements
        if let ui = parentUI {
            positionLabels(in: ui)
        }
    }

    private func showTankSelectionOptions() {
        guard let ui = parentUI,
              let containerView = scrollContentView ?? ui.rootView,
              let entity = ui.currentEntity,
              let gameLoop = ui.gameLoop else {
            return
        }

        // Clear existing tank selection UI
        hideTankSelectionOptions()

        // Create tank selection options for each adjacent building
        for (index, buildingInfo) in adjacentBuildingsWithTanks.enumerated() {
            let (buildingEntity, direction, tanks) = buildingInfo
            let tankRoles = tankRolesForBuilding(entity: buildingEntity, gameLoop: gameLoop, tankCount: tanks.count)

            // Building header label
            let buildingLabel = UILabel()
            buildingLabel.text = "\(direction.rawValue): Building"
            buildingLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            buildingLabel.textColor = .cyan
            buildingLabel.textAlignment = .center
            buildingLabel.frame = CGRect(x: 20, y: 0, width: ui.panelFrameInPoints().width - 40, height: 20)
            containerView.addSubview(buildingLabel)
            tankSelectionLabels.append(buildingLabel)

            // Tank selection buttons
            for (tankIndex, tank) in tanks.enumerated() {
                let button = UIKit.UIButton(type: .system)

                // Determine if this tank is currently connected
                let isConnected = isTankConnected(entity: entity, buildingEntity: buildingEntity, tankIndex: tankIndex, world: gameLoop.world)
                let fluidName = tank.type.rawValue
                let amountText = String(format: "%.0f/%.0fL", tank.amount, tank.maxAmount)
                let roleText = tankIndex < tankRoles.count ? tankRoles[tankIndex] : "Tank"

                button.setTitle("\(roleText) \(tankIndex + 1): \(fluidName) (\(amountText)) \(isConnected ? "✓" : "")", for: .normal)
                button.setTitleColor(isConnected ? .green : .white, for: .normal)
                button.backgroundColor = UIColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 0.8)
                button.layer.borderColor = isConnected ? UIColor.green.cgColor : UIColor.gray.cgColor
                button.layer.borderWidth = 1.0
                button.layer.cornerRadius = 3.0
                button.frame = CGRect(x: 30, y: 0, width: ui.panelFrameInPoints().width - 60, height: 25)

                // Store building and tank info in button tag
                // Use a compound tag: (buildingEntity.id * 1000) + tankIndex
                button.tag = (Int(buildingEntity.id) * 1000) + tankIndex
                button.addTarget(self, action: #selector(tankButtonTapped(_:)), for: .touchUpInside)

                containerView.addSubview(button)
                tankSelectionButtons[tankIndex] = button
            }
        }
    }

    private func hideTankSelectionOptions() {
        for label in tankSelectionLabels {
            label.removeFromSuperview()
        }
        tankSelectionLabels.removeAll()

        for button in tankSelectionButtons.values {
            button.removeFromSuperview()
        }
        tankSelectionButtons.removeAll()
    }

    private func isTankConnected(entity: Entity, buildingEntity: Entity, tankIndex: Int, world: World) -> Bool {
        guard let pipe = world.get(PipeComponent.self, for: entity) else {
            return false
        }
        return pipe.tankConnections[buildingEntity] == tankIndex
    }

    @objc private func tankButtonTapped(_ sender: UIKit.UIButton) {
        guard let ui = parentUI,
              let entity = ui.currentEntity,
              let gameLoop = ui.gameLoop else {
            return
        }

        // Decode building entity ID and tank index from button tag
        let compoundTag = sender.tag
        let buildingEntityId = compoundTag / 1000
        let tankIndex = compoundTag % 1000

        // Find the building entity
        guard let buildingEntity = gameLoop.world.entities.first(where: { $0.id == buildingEntityId }) else {
            return
        }

        toggleTankConnection(for: entity, buildingEntity: buildingEntity, tankIndex: tankIndex, in: gameLoop.world, fluidNetworkSystem: gameLoop.fluidNetworkSystem)

        // Update UI
        updateTankSelectionButtons()
    }

    private func toggleTankConnection(for pipeEntity: Entity, buildingEntity: Entity, tankIndex: Int, in world: World, fluidNetworkSystem: FluidNetworkSystem) {
        guard let pipe = world.get(PipeComponent.self, for: pipeEntity),
              let buildingTank = world.get(FluidTankComponent.self, for: buildingEntity) else {
            return
        }

        func addConnection(_ entity: Entity, to componentConnections: inout [Entity]) {
            if !componentConnections.contains(entity) {
                componentConnections.append(entity)
            }
        }

        func removeConnection(_ entity: Entity, from componentConnections: inout [Entity]) {
            componentConnections.removeAll { $0 == entity }
        }

        let isCurrentlyConnected = pipe.tankConnections[buildingEntity] == tankIndex

        if isCurrentlyConnected {
            // Disconnect from this tank
            pipe.tankConnections.removeValue(forKey: buildingEntity)

            // Remove from building's connections if no other tanks are connected from this pipe
            if !pipe.tankConnections.keys.contains(where: { $0 == buildingEntity }) {
                removeConnection(pipeEntity, from: &buildingTank.connections)
                if var consumer = world.get(FluidConsumerComponent.self, for: buildingEntity) {
                    removeConnection(pipeEntity, from: &consumer.connections)
                    world.add(consumer, to: buildingEntity)
                }
                if var producer = world.get(FluidProducerComponent.self, for: buildingEntity) {
                    removeConnection(pipeEntity, from: &producer.connections)
                    world.add(producer, to: buildingEntity)
                }
                if var pump = world.get(FluidPumpComponent.self, for: buildingEntity) {
                    removeConnection(pipeEntity, from: &pump.connections)
                    world.add(pump, to: buildingEntity)
                }
                removeConnection(buildingEntity, from: &pipe.connections)
            }

            print("PipeConnectionUIComponent: Disconnected pipe \(pipeEntity.id) from building \(buildingEntity.id) tank \(tankIndex)")
        } else {
            // Disconnect from any other tank on this building first
            pipe.tankConnections.removeValue(forKey: buildingEntity)

            // Connect to this specific tank
            pipe.tankConnections[buildingEntity] = tankIndex

            // Add to building's connections if not already connected
            addConnection(pipeEntity, to: &buildingTank.connections)
            if var consumer = world.get(FluidConsumerComponent.self, for: buildingEntity) {
                addConnection(pipeEntity, to: &consumer.connections)
                world.add(consumer, to: buildingEntity)
            }
            if var producer = world.get(FluidProducerComponent.self, for: buildingEntity) {
                addConnection(pipeEntity, to: &producer.connections)
                world.add(producer, to: buildingEntity)
            }
            if var pump = world.get(FluidPumpComponent.self, for: buildingEntity) {
                addConnection(pipeEntity, to: &pump.connections)
                world.add(pump, to: buildingEntity)
            }
            addConnection(buildingEntity, to: &pipe.connections)

            print("PipeConnectionUIComponent: Connected pipe \(pipeEntity.id) to building \(buildingEntity.id) tank \(tankIndex)")
        }

        // Update components in world
        world.add(pipe, to: pipeEntity)
        world.add(buildingTank, to: buildingEntity)

        // Mark networks as dirty for recalculation
        fluidNetworkSystem.markEntityDirty(pipeEntity)
        fluidNetworkSystem.markEntityDirty(buildingEntity)
    }

    private func updateTankSelectionButtons() {
        guard let ui = parentUI,
              let entity = ui.currentEntity,
              let gameLoop = ui.gameLoop else {
            return
        }

        // Update all tank selection buttons
        for (tankIndex, button) in tankSelectionButtons {
            // Find which building this button belongs to
            for buildingInfo in adjacentBuildingsWithTanks {
                let (buildingEntity, _, tanks) = buildingInfo
                if tankIndex < tanks.count {
                    let tank = tanks[tankIndex]
                    let isConnected = isTankConnected(entity: entity, buildingEntity: buildingEntity, tankIndex: tankIndex, world: gameLoop.world)
                    let fluidName = tank.type.rawValue
                    let amountText = String(format: "%.0f/%.0fL", tank.amount, tank.maxAmount)
                    let tankRoles = tankRolesForBuilding(entity: buildingEntity, gameLoop: gameLoop, tankCount: tanks.count)
                    let roleText = tankIndex < tankRoles.count ? tankRoles[tankIndex] : "Tank"

                    button.setTitle("\(roleText) \(tankIndex + 1): \(fluidName) (\(amountText)) \(isConnected ? "✓" : "")", for: .normal)
                    button.setTitleColor(isConnected ? .green : .white, for: .normal)
                    button.layer.borderColor = isConnected ? UIColor.green.cgColor : UIColor.gray.cgColor
                    break
                }
            }
        }
    }

    private func updateConnectionButtons() {
        let directions: [Direction] = [.north, .east, .south, .west]
        let directionNames = ["North", "East", "South", "West"]

        for direction in directions {
            guard let button = connectionButtons[direction] else { continue }
            let isConnected = connectedDirections.contains(direction)

            let isAllowed = isDirectionAllowed(direction: direction)
            let mismatchText = fluidTypeMismatchText(for: direction)
            let stateText = isAllowed ? (isConnected ? "✓" : "✗") : "Blocked"
            let warningSuffix = mismatchText != nil ? "\nType mismatch: \(mismatchText!)" : ""
            button.setTitle("\(directionNames[direction.rawValue]): \(stateText)\(warningSuffix)", for: .normal)
            if isAllowed {
                if mismatchText != nil {
                    button.setTitleColor(.systemOrange, for: .normal)
                } else {
                    button.setTitleColor(isConnected ? .green : .red, for: .normal)
                }
                button.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.8)
                button.layer.borderColor = UIColor.white.cgColor
            } else {
                button.setTitleColor(.lightGray, for: .normal)
                button.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 0.8)
                button.layer.borderColor = UIColor.gray.cgColor
            }
            button.isEnabled = isAllowed
        }
    }

    private func getConnectedDirections(for entity: Entity, in world: World) -> Set<Direction> {
        guard world.has(PipeComponent.self, for: entity) else {
            return []
        }

        var connected: Set<Direction> = []

        // Check each direction for connections
        for direction in Direction.allCases {
            let neighborPos = getNeighborPosition(for: entity, direction: direction, in: world)
            if neighborPos != nil && hasConnection(to: neighborPos!, for: entity, in: world) {
                connected.insert(direction)
            }
        }

        return connected
    }

    private func getNeighborPosition(for entity: Entity, direction: Direction, in world: World) -> IntVector2? {
        guard let position = world.get(PositionComponent.self, for: entity)?.tilePosition else {
            return nil
        }
        return position + direction.intVector
    }

    private func tankRolesForBuilding(entity: Entity, gameLoop: GameLoop, tankCount: Int) -> [String] {
        let buildingId = gameLoop.world.get(FluidTankComponent.self, for: entity)?.buildingId ?? ""
        guard let def = gameLoop.buildingRegistry.get(buildingId) else {
            return Array(repeating: "Tank", count: tankCount)
        }

        let inputSource = def.fluidInputTypes.isEmpty ? def.fluidInputTanks : def.fluidInputTypes.count
        let outputSource = def.fluidOutputTypes.isEmpty ? def.fluidOutputTanks : def.fluidOutputTypes.count
        let inputCount = min(inputSource, tankCount)
        let outputCount = max(0, min(outputSource, tankCount - inputCount))
        let remaining = max(0, tankCount - inputCount - outputCount)

        return Array(repeating: "Input", count: inputCount) +
            Array(repeating: "Output", count: outputCount) +
            Array(repeating: "Tank", count: remaining)
    }

    private func fluidTypeMismatchText(for direction: Direction) -> String? {
        guard let ui = parentUI,
              let entity = ui.currentEntity,
              let world = ui.gameLoop?.world,
              let pipe = world.get(PipeComponent.self, for: entity),
              let neighborPos = getNeighborPosition(for: entity, direction: direction, in: world) else {
            return nil
        }

        var neighborPipe: PipeComponent?
        for otherEntity in world.query(PositionComponent.self) {
            if let otherPos = world.get(PositionComponent.self, for: otherEntity)?.tilePosition,
               otherPos == neighborPos,
               let otherPipe = world.get(PipeComponent.self, for: otherEntity) {
                neighborPipe = otherPipe
                break
            }
        }

        guard let otherPipe = neighborPipe,
              let pipeType = pipe.fluidType,
              let neighborType = otherPipe.fluidType,
              pipeType != neighborType else {
            return nil
        }

        return "\(pipeType.rawValue) vs \(neighborType.rawValue)"
    }

    private func isDirectionAllowed(direction: Direction) -> Bool {
        guard let ui = parentUI,
              let entity = ui.currentEntity,
              let world = ui.gameLoop?.world,
              let pipe = world.get(PipeComponent.self, for: entity) else {
            return true
        }
        return pipe.allowedDirections.contains(direction)
    }

    private func hasConnection(to neighborPos: IntVector2, for entity: Entity, in world: World) -> Bool {
        guard let pipe = world.get(PipeComponent.self, for: entity) else {
            return false
        }

        guard let gameLoop = parentUI?.gameLoop else {
            return false
        }

        // Check if any connected entity occupies the neighbor position
        for connectedEntity in pipe.connections {
            if entityOccupiesTile(connectedEntity, tile: neighborPos, gameLoop: gameLoop) {
                return true
            }
        }

        return false
    }

    private func entityOccupiesTile(_ entity: Entity, tile: IntVector2, gameLoop: GameLoop) -> Bool {
        guard let pos = gameLoop.world.get(PositionComponent.self, for: entity)?.tilePosition else {
            return false
        }
        let size = fluidEntitySize(entity: entity, gameLoop: gameLoop)
        let withinX = tile.x >= pos.x && tile.x < pos.x + Int32(size.width)
        let withinY = tile.y >= pos.y && tile.y < pos.y + Int32(size.height)
        return withinX && withinY
    }

    private func fluidEntitySize(entity: Entity, gameLoop: GameLoop) -> (width: Int, height: Int) {
        var buildingId: String?

        if let pipe = gameLoop.world.get(PipeComponent.self, for: entity) {
            buildingId = pipe.buildingId
        } else if let producer = gameLoop.world.get(FluidProducerComponent.self, for: entity) {
            buildingId = producer.buildingId
        } else if let consumer = gameLoop.world.get(FluidConsumerComponent.self, for: entity) {
            buildingId = consumer.buildingId
        } else if let tank = gameLoop.world.get(FluidTankComponent.self, for: entity) {
            buildingId = tank.buildingId
        } else if let pump = gameLoop.world.get(FluidPumpComponent.self, for: entity) {
            buildingId = pump.buildingId
        }

        if let buildingId = buildingId, let def = gameLoop.buildingRegistry.get(buildingId) {
            return (def.width, def.height)
        }

        return (1, 1)
    }

    @objc private func connectionButtonTapped(_ sender: UIKit.UIButton) {
        guard let direction = Direction(rawValue: Int(sender.tag)),
              let ui = parentUI,
              let entity = ui.currentEntity,
              let gameLoop = ui.gameLoop else {
            return
        }

        print("PipeConnectionUIComponent: Connection button tapped for direction \(direction)")

        // Toggle connection in that direction
        toggleConnection(for: entity, direction: direction, in: gameLoop.world, fluidNetworkSystem: gameLoop.fluidNetworkSystem)

        // Update UI immediately
        connectedDirections = getConnectedDirections(for: entity, in: gameLoop.world)
        updateConnectionButtons()
    }

    @objc private func changeNetworkTapped(_ sender: UIKit.UIButton) {
        guard let ui = parentUI,
              let entity = ui.currentEntity,
              let gameLoop = ui.gameLoop,
              let pipe = gameLoop.world.get(PipeComponent.self, for: entity) else {
            return
        }

        print("PipeConnectionUIComponent: Change network button tapped")

        // Create a new network for this pipe (split from current network)
        gameLoop.fluidNetworkSystem.markEntityDirty(entity)

        // Get a new network ID
        let newNetworkId = gameLoop.fluidNetworkSystem.getNextNetworkId()
        pipe.networkId = newNetworkId
        gameLoop.world.add(pipe, to: entity)
        gameLoop.fluidNetworkSystem.markNetworkDirty(newNetworkId)
        gameLoop.fluidNetworkSystem.markEntityDirty(entity)

        // Update UI
        currentNetworkId = newNetworkId
        networkIdLabel?.text = "Network: \(newNetworkId)"

        print("PipeConnectionUIComponent: Split pipe \(entity.id) into new network \(newNetworkId)")
    }

    @objc private func mergeNetworkTapped(_ sender: UIKit.UIButton) {
        showingMergeOptions = !showingMergeOptions

        if showingMergeOptions {
            showAvailableNetworks()
        } else {
            hideAvailableNetworks()
        }

        // Reposition all elements
        if let ui = parentUI {
            positionLabels(in: ui)
        }
    }

    private func showAvailableNetworks() {
        guard let ui = parentUI,
              let containerView = scrollContentView ?? ui.rootView,
              let entity = ui.currentEntity,
              let gameLoop = ui.gameLoop else {
            return
        }

        // Clear existing merge buttons
        for button in mergeButtons.values {
            button.removeFromSuperview()
        }
        mergeButtons.removeAll()

        // Clear existing label
        availableNetworksLabel?.removeFromSuperview()
        availableNetworksLabel = nil

        // Create available networks label
        let label = UILabel()
        label.text = "Available Networks:"
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .cyan
        label.textAlignment = .center
        label.frame = CGRect(x: 20, y: 0, width: ui.panelFrameInPoints().width - 40, height: 20)
        containerView.addSubview(label)
        availableNetworksLabel = label

        // Get all network IDs except current one
        let allNetworkIds = gameLoop.fluidNetworkSystem.getAllNetworkIds()
        let currentNetworkId = gameLoop.world.get(PipeComponent.self, for: entity)?.networkId ?? 0
        let availableNetworks = allNetworkIds.filter { $0 != currentNetworkId }

        // Create buttons for each available network
        for networkId in availableNetworks {
            let button = UIKit.UIButton(type: .system)
            button.setTitle("Merge with Network \(networkId)", for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = UIColor(red: 0.4, green: 0.4, blue: 0.6, alpha: 0.8)
            button.layer.borderColor = UIColor.blue.cgColor
            button.layer.borderWidth = 1.0
            button.layer.cornerRadius = 3.0
            button.frame = CGRect(x: 30, y: 0, width: ui.panelFrameInPoints().width - 60, height: 25)
            button.tag = networkId
            button.addTarget(self, action: #selector(mergeWithNetworkTapped(_:)), for: .touchUpInside)
            containerView.addSubview(button)
            mergeButtons[networkId] = button
        }
    }

    private func hideAvailableNetworks() {
        availableNetworksLabel?.removeFromSuperview()
        availableNetworksLabel = nil

        for button in mergeButtons.values {
            button.removeFromSuperview()
        }
        mergeButtons.removeAll()
    }

    @objc private func mergeWithNetworkTapped(_ sender: UIKit.UIButton) {
        guard let ui = parentUI,
              let entity = ui.currentEntity,
              let gameLoop = ui.gameLoop else {
            return
        }

        let targetNetworkId = sender.tag
        print("PipeConnectionUIComponent: Merging with network \(targetNetworkId)")

        // Find an entity in the target network to merge with
        if let targetEntity = findEntityInNetwork(targetNetworkId, gameLoop: gameLoop) {
            guard let sourceNetworkId = ensureNetworkId(for: entity, gameLoop: gameLoop),
                  let targetEntityNetworkId = ensureNetworkId(for: targetEntity, gameLoop: gameLoop) else {
                gameLoop.inputManager?.onTooltip?("Merge failed: missing network id")
                return
            }

            guard sourceNetworkId != targetEntityNetworkId else {
                gameLoop.inputManager?.onTooltip?("Already in network \(sourceNetworkId)")
                return
            }

            gameLoop.fluidNetworkSystem.mergeNetworksContainingEntities(entity, targetEntity)

            // Update UI
            if let pipe = gameLoop.world.get(PipeComponent.self, for: entity) {
                currentNetworkId = pipe.networkId
                networkIdLabel?.text = "Network: \(pipe.networkId ?? 0)"
            }

            // Hide merge options
            showingMergeOptions = false
            hideAvailableNetworks()

            // Reposition elements
            positionLabels(in: ui)

            print("PipeConnectionUIComponent: Successfully merged networks")
        } else {
            gameLoop.inputManager?.onTooltip?("Merge failed: target network not found")
        }
    }

    private func ensureNetworkId(for entity: Entity, gameLoop: GameLoop) -> Int? {
        if let networkId = networkId(for: entity, in: gameLoop.world) {
            return networkId
        }
        gameLoop.fluidNetworkSystem.markEntityDirty(entity)
        gameLoop.fluidNetworkSystem.rebuildNetworks()
        return networkId(for: entity, in: gameLoop.world)
    }

    private func networkId(for entity: Entity, in world: World) -> Int? {
        if let pipe = world.get(PipeComponent.self, for: entity) {
            return pipe.networkId
        }
        if let producer = world.get(FluidProducerComponent.self, for: entity) {
            return producer.networkId
        }
        if let consumer = world.get(FluidConsumerComponent.self, for: entity) {
            return consumer.networkId
        }
        if let tank = world.get(FluidTankComponent.self, for: entity) {
            return tank.networkId
        }
        if let pump = world.get(FluidPumpComponent.self, for: entity) {
            return pump.networkId
        }
        return nil
    }

    @objc private func clearPipeTapped(_ sender: UIKit.UIButton) {
        guard let ui = parentUI,
              let entity = ui.currentEntity,
              let gameLoop = ui.gameLoop,
              let pipe = gameLoop.world.get(PipeComponent.self, for: entity) else {
            return
        }

        pipe.fluidAmount = 0
        pipe.fluidType = nil
        pipe.flowRate = 0
        gameLoop.world.add(pipe, to: entity)
        gameLoop.fluidNetworkSystem.markEntityDirty(entity)

        updateUI(for: entity, in: ui)
    }

    @objc private func clearNetworkTapped(_ sender: UIKit.UIButton) {
        guard let ui = parentUI,
              let entity = ui.currentEntity,
              let gameLoop = ui.gameLoop,
              let pipe = gameLoop.world.get(PipeComponent.self, for: entity),
              let networkId = pipe.networkId else {
            return
        }

        for pipeEntity in gameLoop.world.query(PipeComponent.self) {
            guard let networkPipe = gameLoop.world.get(PipeComponent.self, for: pipeEntity),
                  networkPipe.networkId == networkId else {
                continue
            }
            networkPipe.fluidAmount = 0
            networkPipe.fluidType = nil
            networkPipe.flowRate = 0
            gameLoop.world.add(networkPipe, to: pipeEntity)
        }

        gameLoop.fluidNetworkSystem.markNetworkDirty(networkId)
        updateUI(for: entity, in: ui)
    }

    @objc private func clearConnectedTanksTapped(_ sender: UIKit.UIButton) {
        guard let ui = parentUI,
              let entity = ui.currentEntity,
              let gameLoop = ui.gameLoop else {
            return
        }

        var clearedAny = false
        for connected in getConnectedTankEntities(from: entity, gameLoop: gameLoop) {
            guard let tank = gameLoop.world.get(FluidTankComponent.self, for: connected) else { continue }
            tank.tanks = tank.tanks.map { stack in
                var cleared = stack
                cleared.amount = 0
                return cleared
            }
            gameLoop.world.add(tank, to: connected)
            clearedAny = true
        }

        if clearedAny {
            gameLoop.fluidNetworkSystem.markEntityDirty(entity)
        }
        updateUI(for: entity, in: ui)
    }

    private func setupScrollContainer(in ui: MachineUI) {
        guard let rootView = ui.rootView else { return }
        if scrollView == nil {
            let newScrollView = UIScrollView(frame: rootView.bounds)
            newScrollView.showsVerticalScrollIndicator = true
            newScrollView.alwaysBounceVertical = true
            newScrollView.backgroundColor = .clear
            rootView.addSubview(newScrollView)
            scrollView = newScrollView

            let contentView = UIView(frame: newScrollView.bounds)
            contentView.backgroundColor = .clear
            newScrollView.addSubview(contentView)
            scrollContentView = contentView
        } else {
            scrollView?.frame = rootView.bounds
            scrollContentView?.frame = rootView.bounds
        }
    }

    private func teardownUIElements() {
        let viewsToRemove: [UIView?] = [
            networkLabel,
            networkIdLabel,
            changeNetworkButton,
            mergeNetworkButton,
            clearPipeButton,
            clearNetworkButton,
            clearTanksButton,
            availableNetworksLabel
        ]

        for view in viewsToRemove {
            view?.removeFromSuperview()
        }

        for button in connectionButtons.values {
            button.removeFromSuperview()
        }
        connectionButtons.removeAll()

        for button in mergeButtons.values {
            button.removeFromSuperview()
        }
        mergeButtons.removeAll()

        for label in tankSelectionLabels {
            label.removeFromSuperview()
        }
        tankSelectionLabels.removeAll()

        for button in tankSelectionButtons.values {
            button.removeFromSuperview()
        }
        tankSelectionButtons.removeAll()

        networkLabel = nil
        networkIdLabel = nil
        changeNetworkButton = nil
        mergeNetworkButton = nil
        clearPipeButton = nil
        clearNetworkButton = nil
        clearTanksButton = nil
        availableNetworksLabel = nil
    }

    private func getConnectedTankEntities(from entity: Entity, gameLoop: GameLoop) -> [Entity] {
        var tankEntities: Set<Entity> = []

        if let pipe = gameLoop.world.get(PipeComponent.self, for: entity) {
            for connected in pipe.connections where gameLoop.world.has(FluidTankComponent.self, for: connected) {
                tankEntities.insert(connected)
            }
        }

        for connected in tankEntities {
            if let tank = gameLoop.world.get(FluidTankComponent.self, for: connected) {
                for other in tank.connections where gameLoop.world.has(FluidTankComponent.self, for: other) {
                    tankEntities.insert(other)
                }
            }
        }

        return Array(tankEntities)
    }

    private func findEntityInNetwork(_ networkId: Int, gameLoop: GameLoop) -> Entity? {
        // Find any entity in the specified network
        for entity in gameLoop.world.entities {
            if let pipe = gameLoop.world.get(PipeComponent.self, for: entity),
               pipe.networkId == networkId {
                return entity
            }
            if let producer = gameLoop.world.get(FluidProducerComponent.self, for: entity),
               producer.networkId == networkId {
                return entity
            }
            if let consumer = gameLoop.world.get(FluidConsumerComponent.self, for: entity),
               consumer.networkId == networkId {
                return entity
            }
        }
        return nil
    }

    private func findAdjacentBuildingsWithTanks(for entity: Entity, in world: World) -> [(entity: Entity, direction: Direction, tanks: [FluidStack])] {
        guard let gameLoop = parentUI?.gameLoop,
              let pipePos = world.get(PositionComponent.self, for: entity)?.worldPosition else {
            return []
        }

        var buildingsByEntity: [Entity: (direction: Direction, tanks: [FluidStack])] = [:]
        let connectionRange: Float = 0.75

        for otherEntity in world.query(FluidTankComponent.self) {
            guard let tankComponent = world.get(FluidTankComponent.self, for: otherEntity),
                  !tankComponent.tanks.isEmpty else {
                continue
            }

            let bounds = buildingBounds(for: otherEntity, gameLoop: gameLoop)
            let nearest = nearestPoint(on: bounds, to: pipePos)
            let delta = pipePos - nearest
            let distance = (delta.x * delta.x + delta.y * delta.y).squareRoot()
            guard distance <= connectionRange else { continue }

            let direction = dominantDirection(from: delta)
            buildingsByEntity[otherEntity] = (direction: direction, tanks: tankComponent.tanks)
        }

        return buildingsByEntity.map { (entity: $0.key, direction: $0.value.direction, tanks: $0.value.tanks) }
    }

    private func buildingBounds(for entity: Entity, gameLoop: GameLoop) -> Rect {
        guard let pos = gameLoop.world.get(PositionComponent.self, for: entity)?.tilePosition else {
            return Rect(x: 0, y: 0, width: 0, height: 0)
        }
        let size = fluidEntitySize(entity: entity, gameLoop: gameLoop)
        return Rect(origin: pos.toVector2, size: Vector2(Float(size.width), Float(size.height)))
    }

    private func nearestPoint(on bounds: Rect, to point: Vector2) -> Vector2 {
        let clampedX = min(max(point.x, bounds.minX), bounds.maxX)
        let clampedY = min(max(point.y, bounds.minY), bounds.maxY)
        return Vector2(clampedX, clampedY)
    }

    private func dominantDirection(from delta: Vector2) -> Direction {
        if abs(delta.x) >= abs(delta.y) {
            return delta.x >= 0 ? .east : .west
        }
        return delta.y >= 0 ? .north : .south
    }

    private func toggleConnection(for entity: Entity, direction: Direction, in world: World, fluidNetworkSystem: FluidNetworkSystem) {
        guard let neighborPos = getNeighborPosition(for: entity, direction: direction, in: world) else {
            return
        }

        // Find the neighbor entity
        var neighborEntity: Entity?
        let entitiesWithPosition = world.query(PositionComponent.self)
        for otherEntity in entitiesWithPosition {
            if let otherPos = world.get(PositionComponent.self, for: otherEntity)?.tilePosition,
               otherPos == neighborPos,
               world.has(PipeComponent.self, for: otherEntity) {
                neighborEntity = otherEntity
                break
            }
        }

        guard let neighbor = neighborEntity,
              let pipe = world.get(PipeComponent.self, for: entity),
              let neighborPipe = world.get(PipeComponent.self, for: neighbor) else {
            return
        }

        if pipe.connections.contains(neighbor) {
            // Disconnect - mark direction as manually disconnected
            pipe.connections.removeAll { $0 == neighbor }
            neighborPipe.connections.removeAll { $0 == entity }
            pipe.manuallyDisconnectedDirections.insert(direction)
            neighborPipe.manuallyDisconnectedDirections.insert(direction.opposite)
            world.add(pipe, to: entity)
            world.add(neighborPipe, to: neighbor)
            print("PipeConnectionUIComponent: Disconnected pipe \(entity.id) from \(neighbor.id) (direction: \(direction))")
        } else {
            // Connect - remove from manually disconnected directions
            pipe.connections.append(neighbor)
            neighborPipe.connections.append(entity)
            pipe.manuallyDisconnectedDirections.remove(direction)
            neighborPipe.manuallyDisconnectedDirections.remove(direction.opposite)
            world.add(pipe, to: entity)
            world.add(neighborPipe, to: neighbor)
            print("PipeConnectionUIComponent: Connected pipe \(entity.id) to \(neighbor.id) (direction: \(direction))")
        }

        // Mark networks as dirty for recalculation
        fluidNetworkSystem.markEntityDirty(entity)
        fluidNetworkSystem.markEntityDirty(neighbor)
    }

}
