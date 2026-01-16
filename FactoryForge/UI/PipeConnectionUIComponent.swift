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
    private var availableNetworksLabel: UILabel?
    private var mergeButtons: [Int: UIKit.UIButton] = [:]

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

        // Store current state
        currentNetworkId = pipe.networkId
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
        let panelRect = ui.panelFrameInPoints()

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
    }

    override func updateUI(for entity: Entity, in ui: MachineUI) {
        guard let gameLoop = ui.gameLoop,
              let pipe = gameLoop.world.get(PipeComponent.self, for: entity) else {
            return
        }

        // Update network info
        currentNetworkId = pipe.networkId
        networkIdLabel?.text = "Network: \(pipe.networkId ?? 0)"

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
        guard let rootView = ui.rootView else { return }

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
        rootView.addSubview(networkInfoLabel)
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
        rootView.addSubview(idLabel)
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
        rootView.addSubview(changeButton)
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
        rootView.addSubview(mergeButton)
        mergeNetworkButton = mergeButton
    }

    private func setupConnectionButtons(in ui: MachineUI) {
        guard let rootView = ui.rootView else { return }

        let directions: [Direction] = [.north, .east, .south, .west]
        let directionNames = ["North", "East", "South", "West"]

        for (index, direction) in directions.enumerated() {
            let button = UIKit.UIButton(type: .system)
            let isConnected = connectedDirections.contains(direction)
            let isAllowed = isDirectionAllowed(direction: direction)

            let stateText = isAllowed ? (isConnected ? "✓" : "✗") : "Blocked"
            button.setTitle("\(directionNames[index]): \(stateText)", for: .normal)
            if isAllowed {
                button.setTitleColor(isConnected ? .green : .red, for: .normal)
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

            rootView.addSubview(button)
            connectionButtons[direction] = button
        }
    }

    private func setupTankSelectionSection(in ui: MachineUI) {
        guard let rootView = ui.rootView else { return }

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
        rootView.addSubview(tankSelectionButton)
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
              let rootView = ui.rootView,
              let entity = ui.currentEntity,
              let gameLoop = ui.gameLoop else {
            return
        }

        // Clear existing tank selection UI
        hideTankSelectionOptions()

        // Create tank selection options for each adjacent building
        for (index, buildingInfo) in adjacentBuildingsWithTanks.enumerated() {
            let (buildingEntity, direction, tanks) = buildingInfo

            // Building header label
            let buildingLabel = UILabel()
            buildingLabel.text = "\(direction.rawValue): Building"
            buildingLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            buildingLabel.textColor = .cyan
            buildingLabel.textAlignment = .center
            buildingLabel.frame = CGRect(x: 20, y: 0, width: ui.panelFrameInPoints().width - 40, height: 20)
            rootView.addSubview(buildingLabel)
            tankSelectionLabels.append(buildingLabel)

            // Tank selection buttons
            for (tankIndex, tank) in tanks.enumerated() {
                let button = UIKit.UIButton(type: .system)

                // Determine if this tank is currently connected
                let isConnected = isTankConnected(entity: entity, buildingEntity: buildingEntity, tankIndex: tankIndex, world: gameLoop.world)
                let fluidName = tank.type.rawValue
                let amountText = String(format: "%.0f/%.0fL", tank.amount, tank.maxAmount)

                button.setTitle("Tank \(tankIndex + 1): \(fluidName) (\(amountText)) \(isConnected ? "✓" : "")", for: .normal)
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

                rootView.addSubview(button)
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

        let isCurrentlyConnected = pipe.tankConnections[buildingEntity] == tankIndex

        if isCurrentlyConnected {
            // Disconnect from this tank
            pipe.tankConnections.removeValue(forKey: buildingEntity)

            // Remove from building's connections if no other tanks are connected from this pipe
            if !pipe.tankConnections.keys.contains(where: { $0 == buildingEntity }) {
                buildingTank.connections.removeAll { $0 == pipeEntity }
            }

            print("PipeConnectionUIComponent: Disconnected pipe \(pipeEntity.id) from building \(buildingEntity.id) tank \(tankIndex)")
        } else {
            // Disconnect from any other tank on this building first
            pipe.tankConnections.removeValue(forKey: buildingEntity)

            // Connect to this specific tank
            pipe.tankConnections[buildingEntity] = tankIndex

            // Add to building's connections if not already connected
            if !buildingTank.connections.contains(pipeEntity) {
                buildingTank.connections.append(pipeEntity)
            }

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

                    button.setTitle("Tank \(tankIndex + 1): \(fluidName) (\(amountText)) \(isConnected ? "✓" : "")", for: .normal)
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
            let stateText = isAllowed ? (isConnected ? "✓" : "✗") : "Blocked"
            button.setTitle("\(directionNames[direction.rawValue]): \(stateText)", for: .normal)
            if isAllowed {
                button.setTitleColor(isConnected ? .green : .red, for: .normal)
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
              let rootView = ui.rootView,
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
        rootView.addSubview(label)
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
            rootView.addSubview(button)
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
        }
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
        var buildings: [(entity: Entity, direction: Direction, tanks: [FluidStack])] = []

        // Check each direction for buildings with fluid tanks
        for direction in Direction.allCases {
            let neighborPos = getNeighborPosition(for: entity, direction: direction, in: world)
            if let neighborPos = neighborPos {
                // Find entities at this position
                let entitiesWithPosition = world.query(PositionComponent.self)
                for otherEntity in entitiesWithPosition {
                    if let otherPos = world.get(PositionComponent.self, for: otherEntity)?.tilePosition,
                       otherPos == neighborPos,
                       let tankComponent = world.get(FluidTankComponent.self, for: otherEntity),
                       !tankComponent.tanks.isEmpty {
                        // Found a building with fluid tanks
                        buildings.append((entity: otherEntity, direction: direction, tanks: tankComponent.tanks))
                        break // Only one building per direction
                    }
                }
            }
        }

        return buildings
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
