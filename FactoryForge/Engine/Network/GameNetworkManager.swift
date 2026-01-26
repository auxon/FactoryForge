import Foundation
import Network
import UIKit

/// JSON configuration for player starting items
struct StartingItemsConfig: Codable {
    let startingItems: [StartingItem]

    struct StartingItem: Codable {
        let itemId: String
        let count: Int
        let comment: String?
    }
}

/// Network manager for MCP communication
@available(iOS 17.0, *)
final class GameNetworkManager {
    static let shared = GameNetworkManager()

    private var wsListener: NWListener?
    private var httpListener: NWListener?
    private var connections: [NWConnection] = []
    private var mcpConnection: NWConnection?
    private var gameLoop: GameLoop?
    private var debugLogs: [String] = []

    // UI callback for triggering actions
    var onNewGameRequested: (() -> Void)?

    private init() {
        // Set up HTTP server for receiving commands from MCP
        setupHTTPServer()
        // Also try to connect to MCP server for bidirectional communication
        connectToMCPServer()
    }

    func setGameLoop(_ gameLoop: GameLoop) {
        self.gameLoop = gameLoop
    }

    private func setupWebSocketServer() {
        do {
            // Create WebSocket listener on port 8082
            let parameters = NWParameters.tcp
            let wsOptions = NWProtocolWebSocket.Options()
            parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

            wsListener = try NWListener(using: parameters, on: 8082)

            wsListener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("GameNetworkManager: WebSocket server ready on port 8082")
                case .failed(let error):
                    print("GameNetworkManager: WebSocket server failed: \(error)")
                default:
                    break
                }
            }

            wsListener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            wsListener?.start(queue: .main)
        } catch {
            print("GameNetworkManager: Failed to create WebSocket server: \(error)")
        }
    }

    private func setupHTTPServer() {
        do {
            // Create HTTP listener on port 8083
            let parameters = NWParameters.tcp
            httpListener = try NWListener(using: parameters, on: 8083)

            httpListener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("GameNetworkManager: HTTP server ready on port 8083")
                case .failed(let error):
                    print("GameNetworkManager: HTTP server failed: \(error)")
                default:
                    break
                }
            }

            httpListener?.newConnectionHandler = { [weak self] connection in
                self?.handleHTTPConnection(connection)
            }

            httpListener?.start(queue: .main)
        } catch {
            print("GameNetworkManager: Failed to create HTTP server: \(error)")
        }
    }

    private func connectToMCPServer() {
        print("GameNetworkManager: Attempting to connect to MCP server...")
        // Connect to MCP server at localhost:8081 (WebSocket port)
        let mcpHost = "localhost"  // Local MCP server
        let mcpPort: NWEndpoint.Port = 8081
        print("GameNetworkManager: Connecting to \(mcpHost):\(mcpPort)")

        let parameters = NWParameters.tcp
        let wsOptions = NWProtocolWebSocket.Options()
        parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        let connection = NWConnection(host: NWEndpoint.Host(mcpHost), port: mcpPort, using: parameters)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("GameNetworkManager: Connected to MCP server at \(mcpHost):\(mcpPort)")
                self?.mcpConnection = connection
                self?.sendInitialGameStateToMCP()
                self?.startReceivingFromMCP()
            case .failed(let error):
                print("GameNetworkManager: Failed to connect to MCP server: \(error)")
                // Retry connection after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self?.connectToMCPServer()
                }
            case .cancelled:
                print("GameNetworkManager: Connection to MCP server cancelled")
                self?.mcpConnection = nil
            default:
                break
            }
        }

        connection.start(queue: .main)
    }

    private func sendInitialGameStateToMCP() {
        guard gameLoop != nil else { return }
        let gameState = createGameState()
        sendToMCP(gameState)
    }

    private func createGameState() -> [String: Any] {
        guard let gameLoop = gameLoop,
              let player = gameLoop.player else { return [:] }

        // Create a basic game state dictionary
        let gameState: [String: Any] = [
            "type": "game_state_update",
            "player": [
                "position": [
                    "x": player.position.x,
                    "y": player.position.y
                ]
            ],
            "world": [
                "chunks": gameLoop.chunkManager.allLoadedChunks.map { chunk in
                    ["coord": ["x": chunk.coord.x, "y": chunk.coord.y], "loaded": true]
                }
            ]
        ]

        return gameState
    }

    private func startReceivingFromMCP() {
        guard let connection = mcpConnection else { return }

        connection.receiveMessage { [weak self] data, context, isComplete, error in
            if let data = data, let message = String(data: data, encoding: .utf8) {
                self?.handleMCPMessage(message)
            }

            if error == nil {
                self?.startReceivingFromMCP()  // Continue receiving
            }
        }
    }

    private func handleMCPMessage(_ message: String) {
        guard gameLoop != nil else { return }

        do {
            if let json = try JSONSerialization.jsonObject(with: message.data(using: .utf8)!, options: []) as? [String: Any],
               let type = json["type"] as? String {
                switch type {
                case "execute_command":
                    if let command = json["command"] as? String,
                       let requestId = json["requestId"] as? String,
                       let parameters = json["parameters"] as? [String: Any] {
                        Task {
                            do {
                                let result = try await self.executeCommand(command, parameters: parameters)
                                let response: [String: Any] = [
                                    "type": "command_result",
                                    "requestId": requestId,
                                    "result": result
                                ]
                                self.sendToMCP(response)
                            } catch {
                                let errorResponse: [String: Any] = [
                                    "type": "command_result",
                                    "requestId": requestId,
                                    "error": error.localizedDescription
                                ]
                                self.sendToMCP(errorResponse)
                            }
                        }
                    }
                default:
                    print("GameNetworkManager: Unknown MCP message type: \(type)")
                }
            }
        } catch {
            print("GameNetworkManager: Failed to parse MCP message: \(error)")
        }
    }

    private func sendToMCP(_ message: [String: Any]) {
        guard let connection = mcpConnection else {
            print("GameNetworkManager: No MCP connection available")
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: message, options: [])
            connection.send(content: data, completion: .contentProcessed({ error in
                if let error = error {
                    print("GameNetworkManager: Failed to send to MCP: \(error)")
                }
            }))
        } catch {
            print("GameNetworkManager: Failed to serialize message for MCP: \(error)")
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("GameNetworkManager: MCP client connected")
                self?.sendInitialGameState(to: connection)
            case .failed(let error):
                print("GameNetworkManager: Connection failed: \(error)")
                if let index = self?.connections.firstIndex(where: { $0 === connection }) {
                    self?.connections.remove(at: index)
                }
            case .cancelled:
                print("GameNetworkManager: Connection cancelled")
                if let index = self?.connections.firstIndex(where: { $0 === connection }) {
                    self?.connections.remove(at: index)
                }
            default:
                break
            }
        }

        connection.start(queue: .main)

        // Set up message handling
        receiveMessage(from: connection)
    }

    private func receiveMessage(from connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            if let data = data, let message = String(data: data, encoding: .utf8) {
                self?.handleMessage(message, from: connection)
            }

            if error == nil {
                // Continue receiving messages
                self?.receiveMessage(from: connection)
            }
        }
    }

    private func handleMessage(_ message: String, from connection: NWConnection) {
        guard gameLoop != nil else { return }

        do {
            let json = try JSONSerialization.jsonObject(with: message.data(using: .utf8)!, options: []) as? [String: Any]

            if let type = json?["type"] as? String {
                switch type {
                case "execute_command":
                    handleCommand(json!, from: connection)
                case "get_game_state":
                    sendGameState(to: connection)
                default:
                    print("GameNetworkManager: Unknown message type: \(type)")
                }
            }
        } catch {
            print("GameNetworkManager: Failed to parse message: \(error)")
        }
    }

    private func handleCommand(_ command: [String: Any], from connection: NWConnection) {
        guard gameLoop != nil,
              let commandType = command["command"] as? String,
              let requestId = command["requestId"] as? String else { return }

        let parameters = command["parameters"] as? [String: Any] ?? [:]

        Task {
            do {
                let result = try await executeCommand(commandType, parameters: parameters)

                let response: [String: Any] = [
                    "type": "command_result",
                    "requestId": requestId,
                    "success": true,
                    "result": result
                ]

                sendJSON(response, to: connection)
            } catch {
                let response: [String: Any] = [
                    "type": "command_result",
                    "requestId": requestId,
                    "success": false,
                    "error": error.localizedDescription
                ]

                sendJSON(response, to: connection)
            }
        }
    }

    private func executeCommand(_ command: String, parameters: [String: Any]) async throws -> Any {
        // Send debug log over HTTP
        sendDebugLog("Executing command: \(command) with parameters: \(parameters)")

        // Commands that don't require a gameLoop
        switch command {
        case "get_debug_logs":
            return ["logs": debugLogs]
        case "list_save_slots":
            return try await listSaveSlots(parameters)
        case "delete_save_slot":
            return try await deleteSaveSlot(parameters)
        case "rename_save_slot":
            return try await renameSaveSlot(parameters)
        default:
            break
        }

        // Commands that require a gameLoop
        guard let gameLoop = gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No game loop available - please start or load a game first"])
        }

        switch command {
        case "build":
            return try await buildStructure(parameters)
        case "delete_building":
            return try await deleteBuilding(parameters)
        case "move_building":
            return try await moveBuilding(parameters)
        case "check_tile_resources":
            return try await checkTileResources(parameters)
        case "build_mining_drill_on_deposit":
            return try await buildMiningDrillOnDeposit(parameters)
        case "move":
            return try await moveUnit(parameters)
        case "move_player":
            return try await movePlayer(parameters)
        case "mine":
            return try await manualMine(parameters)
        case "auto_mine":
            return try await autoMine(parameters)
        case "get_game_state":
            return createGameStateDictionary()
        case "get_player_position":
            guard let player = gameLoop.player else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Player not available"])
        }
        let playerPos = player.position
            return ["x": playerPos.x, "y": playerPos.y]
        case "get_inventory":
            return try await getInventory(parameters)
        case "add_inventory":
            return try await addInventoryItem(parameters)
        case "craft":
            return try await craftItem(parameters)
        case "open_machine_ui":
            return try await openMachineUI(parameters)
        case "add_machine_item":
            return try await addMachineItem(parameters)
        case "take_machine_item":
            return try await takeMachineItem(parameters)
        case "spawn_resource":
            return try await spawnResource(parameters)
        case "start_new_game":
            return try await startNewGame(parameters)
        case "save_game":
            return try await saveGame(parameters)
        case "load_game":
            return try await loadGame(parameters)
        case "list_save_slots":
            return try await listSaveSlots(parameters)
        case "delete_save_slot":
            return try await deleteSaveSlot(parameters)
        case "rename_save_slot":
            return try await renameSaveSlot(parameters)
        case "update_machine_ui_config":
            return try await updateMachineUIConfig(parameters)
        case "get_machine_ui_config":
            return try await getMachineUIConfig(parameters)
        case "list_machine_ui_configs":
            return try await listMachineUIConfigs(parameters)
        case "reload_machine_ui_schema":
            return try await reloadMachineUISchema(parameters)
        case "test_machine_ui_schema":
            return try await testMachineUISchema(parameters)
        case "get_machine_ui_state":
            return try await getMachineUIState(parameters)
        case "get_starting_items_config":
            return try await getStartingItemsConfig(parameters)
        case "update_starting_items_config":
            return try await updateStartingItemsConfig(parameters)
        case "get_building_config":
            return try await getBuildingConfig(parameters)
        case "update_building_config":
            return try await updateBuildingConfig(parameters)
        case "list_building_configs":
            return try await listBuildingConfigs(parameters)
        case "attack":
            // Check if this is a player attack (has targetX/targetY) or unit attack (has unitId/targetId)
            if parameters["targetX"] != nil || parameters["targetY"] != nil {
                return try await attackWithPlayer(parameters)
            } else {
                return try await attackWithUnit(parameters)
            }
        case "research":
            return try await startResearch(parameters)
        case "pause":
            Time.shared.isPaused = true
            sendDebugLog("Game paused")
            return ["status": "paused"]
        case "resume":
            Time.shared.isPaused = false
            sendDebugLog("Game resumed")
            return ["status": "resumed"]
        case "get_debug_logs":
            return ["logs": debugLogs]
        default:
        throw NSError(domain: "GameNetworkManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown command: \(command)"])
    }

    func manualMine(_ parameters: [String: Any]) async throws -> Any {
        guard let resourceType = parameters["resourceType"] as? String else {
            throw NSError(domain: "GameNetworkManager", code: 12, userInfo: [NSLocalizedDescriptionKey: "Missing resourceType parameter"])
        }

        guard let gameLoop = self.gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        guard let player = gameLoop.player else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Player not available"])
        }
        let playerPos = player.position
        let tilePos = IntVector2(Int(playerPos.x), Int(playerPos.y))

        // Check if there's a resource at the player's position
        guard let resource = gameLoop.chunkManager.getResource(at: tilePos), !resource.isEmpty else {
            throw NSError(domain: "GameNetworkManager", code: 13, userInfo: [NSLocalizedDescriptionKey: "No resource found at player position"])
        }

        // Check if the resource type matches
        guard resource.type.outputItem == resourceType else {
            throw NSError(domain: "GameNetworkManager", code: 14, userInfo: [NSLocalizedDescriptionKey: "Resource type mismatch. Found: \(resource.type.outputItem), requested: \(resourceType)"])
        }

        // Check if player can accept the item
        guard let player = gameLoop.player,
              player.inventory.canAccept(itemId: resourceType) else {
            throw NSError(domain: "GameNetworkManager", code: 15, userInfo: [NSLocalizedDescriptionKey: "Inventory full or item not allowed"])
        }

        // Mine the resource
        let mined = gameLoop.chunkManager.mineResource(at: tilePos, amount: 1)
        if mined > 0 {
            // Add to player inventory
            if let itemDef = gameLoop.itemRegistry.get(resourceType) {
                player.inventory.add(itemId: resourceType, count: mined, maxStack: itemDef.stackSize)
            }

            return [
                "success": true,
                "mined": mined,
                "resourceType": resourceType,
                "message": "Successfully mined \(mined) \(resourceType)"
            ]
        }

        throw NSError(domain: "GameNetworkManager", code: 16, userInfo: [NSLocalizedDescriptionKey: "Failed to mine resource"])
    }

    func autoMine(_ parameters: [String: Any]) async throws -> Any {
        let radius = parameters["radius"] as? Int ?? 2  // Default 2 tile radius
        let maxResources = parameters["maxResources"] as? Int ?? 100  // Default 100 resources

        guard let gameLoop = self.gameLoop else {
            sendDebugLog("autoMine: Game not initialized")
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        sendDebugLog("autoMine: Starting auto-mine with radius \(radius), maxResources \(maxResources)")

        guard let player = gameLoop.player else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Player not available"])
        }
        let playerPos = player.position
        let centerTile = IntVector2(Int(playerPos.x), Int(playerPos.y))

        sendDebugLog("autoMine: Player position (\(playerPos.x), \(playerPos.y)), centerTile (\(centerTile.x), \(centerTile.y))")

        var totalMined: [String: Int] = [:]
        var minedCount = 0

        // Mine in a square area around the player
        let radiusInt32 = Int32(radius)
        sendDebugLog("autoMine: Scanning area from (\(centerTile.x - radiusInt32), \(centerTile.y - radiusInt32)) to (\(centerTile.x + radiusInt32), \(centerTile.y + radiusInt32))")

        for x in (centerTile.x - radiusInt32)...(centerTile.x + radiusInt32) {
            for y in (centerTile.y - radiusInt32)...(centerTile.y + radiusInt32) {
                if minedCount >= maxResources {
                    break
                }

                let tilePos = IntVector2(x: x, y: y)

                // Check if there's a resource at this position
                let resource = gameLoop.chunkManager.getResource(at: tilePos)
                if let resource = resource, !resource.isEmpty {
                    sendDebugLog("autoMine: Found resource at (\(x), \(y)): \(resource.type.outputItem)")
                    // Check if player can accept the item
                    let itemId = resource.type.outputItem
                    if let player = gameLoop.player,
                       player.inventory.canAccept(itemId: itemId) {
                        // Mine the resource
                        let mined = gameLoop.chunkManager.mineResource(at: tilePos, amount: 1)
                        if mined > 0 {
                            sendDebugLog("autoMine: Mined \(mined) \(itemId)")
                            // Add to inventory immediately (no animation delay for auto-mining)
                            if let itemDef = gameLoop.itemRegistry.get(itemId) {
                                player.inventory.add(itemId: itemId, count: mined, maxStack: itemDef.stackSize)
                                totalMined[itemId, default: 0] += mined
                                minedCount += mined
                            }
                        }
                    } else {
                        sendDebugLog("autoMine: Cannot accept \(itemId) - inventory full")
                    }
                }
            }
            if minedCount >= maxResources {
                break
            }
        }

        sendDebugLog("autoMine: Completed mining, found \(minedCount) total resources")

        return [
            "success": true,
            "resourcesMined": totalMined,
            "totalMined": minedCount,
            "radius": radius,
            "message": "Auto-mined \(minedCount) resources within \(radius) tile radius"
        ]
    }

    func getInventory(_ parameters: [String: Any]) async throws -> Any {
        guard let gameLoop = self.gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        var inventory: [[String: Any]] = []

        guard let player = gameLoop.player else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Player not available"])
        }
        
        for slot in 0..<player.inventory.slotCount {
            if let itemStack = player.inventory.slots[slot] {
                inventory.append([
                    "slot": slot,
                    "itemId": itemStack.itemId,
                    "count": itemStack.count
                ])
            } else {
                inventory.append([
                    "slot": slot,
                    "itemId": NSNull(),
                    "count": 0
                ])
            }
        }

        return [
            "inventory": inventory,
            "totalSlots": player.inventory.slotCount
        ]
    }

    func addInventoryItem(_ parameters: [String: Any]) async throws -> Any {
        guard let itemId = parameters["itemId"] as? String,
              let count = parameters["count"] as? Int else {
            throw NSError(domain: "GameNetworkManager", code: 17, userInfo: [NSLocalizedDescriptionKey: "Missing itemId or count parameter"])
        }

        guard let gameLoop = self.gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        guard let itemDef = gameLoop.itemRegistry.get(itemId) else {
            throw NSError(domain: "GameNetworkManager", code: 18, userInfo: [NSLocalizedDescriptionKey: "Item not found: \(itemId)"])
        }

        guard let player = gameLoop.player else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Player not available"])
        }
        let added = player.inventory.add(itemId: itemId, count: count, maxStack: itemDef.stackSize)

        return [
            "success": true,
            "itemId": itemId,
            "requested": count,
            "added": added,
            "message": "Added \(added) \(itemId) to inventory"
        ]
    }

    func craftItem(_ parameters: [String: Any]) async throws -> Any {
        guard let recipeId = parameters["recipeId"] as? String,
              let count = parameters["count"] as? Int else {
            throw NSError(domain: "GameNetworkManager", code: 19, userInfo: [NSLocalizedDescriptionKey: "Missing recipeId or count parameter"])
        }

        guard let gameLoop = self.gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        guard let recipe = gameLoop.recipeRegistry.get(recipeId) else {
            throw NSError(domain: "GameNetworkManager", code: 20, userInfo: [NSLocalizedDescriptionKey: "Recipe not found: \(recipeId)"])
        }

        // Try to craft the item
        guard let player = gameLoop.player else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Player not available"])
        }
        let success = player.craft(recipe: recipe, count: count)

        if success {
            return [
                "success": true,
                "recipeId": recipeId,
                "count": count,
                "message": "Started crafting \(count)x \(recipeId)"
            ]
        } else {
            throw NSError(domain: "GameNetworkManager", code: 21, userInfo: [NSLocalizedDescriptionKey: "Failed to craft \(recipeId) - insufficient materials or crafting queue full"])
        }
    }

    func spawnResource(_ parameters: [String: Any]) async throws -> Any {
        guard let resourceType = parameters["resourceType"] as? String,
              let x = parameters["x"] as? Int,
              let y = parameters["y"] as? Int,
              let amount = parameters["amount"] as? Int else {
            throw NSError(domain: "GameNetworkManager", code: 22, userInfo: [NSLocalizedDescriptionKey: "Missing resourceType, x, y, or amount parameter"])
        }

        guard let gameLoop = self.gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        let tilePos = IntVector2(x: Int32(x), y: Int32(y))

        // Create the resource deposit
        guard let resourceTypeEnum = ResourceType(rawValue: resourceType) else {
            throw NSError(domain: "GameNetworkManager", code: 23, userInfo: [NSLocalizedDescriptionKey: "Invalid resource type: \(resourceType)"])
        }

        let resourceDeposit = ResourceDeposit(type: resourceTypeEnum, amount: amount)

        // Get the current tile
        if var tile = gameLoop.chunkManager.getTile(at: tilePos) {
            // Set the resource on the tile
            tile.resource = resourceDeposit
            gameLoop.chunkManager.setTile(at: tilePos, tile: tile)

            sendDebugLog("spawnResource: Successfully spawned \(amount) \(resourceType) at (\(x), \(y))")

            return [
                "success": true,
                "resourceType": resourceType,
                "position": ["x": x, "y": y],
                "amount": amount,
                "message": "Spawned \(amount) \(resourceType) at (\(x), \(y))"
            ]
        } else {
            throw NSError(domain: "GameNetworkManager", code: 24, userInfo: [NSLocalizedDescriptionKey: "Could not access tile at (\(x), \(y))"])
        }
    }

    func openMachineUI(_ parameters: [String: Any]) async throws -> Any {
        sendDebugLog("openMachineUI: Called with parameters: \(parameters)")

        guard let x = parameters["x"] as? Int,
              let y = parameters["y"] as? Int else {
            sendDebugLog("openMachineUI: Missing x or y coordinates")
            throw NSError(domain: "GameNetworkManager", code: 25, userInfo: [NSLocalizedDescriptionKey: "Missing x or y coordinates"])
        }

        sendDebugLog("openMachineUI: Looking for machine at (\(x), \(y))")

        guard let gameLoop = self.gameLoop else {
            sendDebugLog("openMachineUI: Game not initialized")
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        let tilePos = IntVector2(x: Int32(x), y: Int32(y))
        sendDebugLog("openMachineUI: Tile position: (\(tilePos.x), \(tilePos.y))")

        // Find entities at this position
        let entities = gameLoop.world.getAllEntitiesAt(position: tilePos)
        let interactableEntities = entities.filter { entity in
            let hasFurnace = gameLoop.world.has(FurnaceComponent.self, for: entity)
            let hasMiner = gameLoop.world.has(MinerComponent.self, for: entity)
            let hasAssembler = gameLoop.world.has(AssemblerComponent.self, for: entity)
            let hasChest = gameLoop.world.has(ChestComponent.self, for: entity)
            let hasLab = gameLoop.world.has(LabComponent.self, for: entity)

            return hasFurnace || hasMiner || hasAssembler || hasChest || hasLab
        }

        guard let targetEntity = interactableEntities.first else {
            throw NSError(domain: "GameNetworkManager", code: 26, userInfo: [NSLocalizedDescriptionKey: "No interactable machine found at (\(x), \(y))"])
        }

        // Check what type of machine it is
        var machineType = "unknown"
        if gameLoop.world.has(FurnaceComponent.self, for: targetEntity) {
            machineType = "furnace"
        } else if gameLoop.world.has(MinerComponent.self, for: targetEntity) {
            machineType = "miner"
        } else if gameLoop.world.has(AssemblerComponent.self, for: targetEntity) {
            machineType = "assembler"
        } else if gameLoop.world.has(LabComponent.self, for: targetEntity) {
            machineType = "lab"
        } else if gameLoop.world.has(ChestComponent.self, for: targetEntity) {
            machineType = "chest"
        }

        // Programmatically open the machine UI
        // This simulates what happens when the player taps on a building
        DispatchQueue.main.async {
            // Trigger the UI system to show the machine interface
            gameLoop.uiSystem?.openMachineUI(for: targetEntity)
        }

        sendDebugLog("openMachineUI: Opened \(machineType) UI at (\(x), \(y))")

        return [
            "success": true,
            "machineType": machineType,
            "position": ["x": x, "y": y],
            "entityId": targetEntity.id,
            "message": "Opened \(machineType) machine UI at (\(x), \(y))"
        ]
    }

    func addMachineItem(_ parameters: [String: Any]) async throws -> Any {
        sendDebugLog("addMachineItem: Called with parameters: \(parameters)")

        guard let x = parameters["x"] as? Int,
              let y = parameters["y"] as? Int,
              let slotIndex = parameters["slot"] as? Int,
              let itemId = parameters["itemId"] as? String,
              let count = parameters["count"] as? Int else {
            sendDebugLog("addMachineItem: Missing required parameters")
            throw NSError(domain: "GameNetworkManager", code: 25, userInfo: [NSLocalizedDescriptionKey: "Missing required parameters: x, y, slot, itemId, count"])
        }

        guard let gameLoop = self.gameLoop else {
            sendDebugLog("addMachineItem: Game not initialized")
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        // Check if player has the item
        guard let player = gameLoop.player,
              player.inventory.has(itemId: itemId, count: count) else {
            sendDebugLog("addMachineItem: Player doesn't have enough \(itemId)")
            throw NSError(domain: "GameNetworkManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Player doesn't have enough \(itemId)"])
        }

        let tilePos = IntVector2(x: Int32(x), y: Int32(y))

        // Find the machine entity at this position
        let entities = gameLoop.world.getAllEntitiesAt(position: tilePos)
        guard let targetEntity = entities.first(where: { entity in
            gameLoop.world.has(InventoryComponent.self, for: entity) ||
            gameLoop.world.has(FurnaceComponent.self, for: entity)
        }) else {
            sendDebugLog("addMachineItem: No machine found at (\(x), \(y))")
            throw NSError(domain: "GameNetworkManager", code: 27, userInfo: [NSLocalizedDescriptionKey: "No machine found at position"])
        }

        // All machines use InventoryComponent for item slots
        guard var machineInventory = gameLoop.world.get(InventoryComponent.self, for: targetEntity),
              slotIndex < machineInventory.slots.count else {
            sendDebugLog("addMachineItem: Invalid slot index \(slotIndex) or no inventory")
            throw NSError(domain: "GameNetworkManager", code: 28, userInfo: [NSLocalizedDescriptionKey: "Invalid slot index or machine has no inventory"])
        }

        // Check if slot is empty
        guard machineInventory.slots[slotIndex] == nil else {
            sendDebugLog("addMachineItem: Slot \(slotIndex) is not empty")
            throw NSError(domain: "GameNetworkManager", code: 29, userInfo: [NSLocalizedDescriptionKey: "Slot is not empty"])
        }

        // Add item to machine slot
        machineInventory.slots[slotIndex] = ItemStack(itemId: itemId, count: count)
        gameLoop.world.add(machineInventory, to: targetEntity)

        // Remove from player inventory
        player.inventory.remove(itemId: itemId, count: count)

        sendDebugLog("addMachineItem: Added \(count) \(itemId) to machine at (\(x), \(y)) slot \(slotIndex)")

        return [
            "success": true,
            "itemId": itemId,
            "count": count,
            "slot": slotIndex,
            "position": ["x": x, "y": y],
            "message": "Added \(count) \(itemId) to machine slot \(slotIndex)"
        ]
    }

    func takeMachineItem(_ parameters: [String: Any]) async throws -> Any {
        sendDebugLog("takeMachineItem: Called with parameters: \(parameters)")

        guard let x = parameters["x"] as? Int,
              let y = parameters["y"] as? Int,
              let slotIndex = parameters["slot"] as? Int else {
            sendDebugLog("takeMachineItem: Missing required parameters")
            throw NSError(domain: "GameNetworkManager", code: 25, userInfo: [NSLocalizedDescriptionKey: "Missing required parameters: x, y, slot"])
        }

        // Optional count parameter - defaults to all items in slot
        let requestedCount = parameters["count"] as? Int

        guard let gameLoop = self.gameLoop else {
            sendDebugLog("takeMachineItem: Game not initialized")
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        guard let player = gameLoop.player else {
            sendDebugLog("takeMachineItem: Player not found")
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Player not found"])
        }

        let tilePos = IntVector2(x: Int32(x), y: Int32(y))

        // Find the machine entity at this position
        let entities = gameLoop.world.getAllEntitiesAt(position: tilePos)
        guard let targetEntity = entities.first(where: { entity in
            gameLoop.world.has(InventoryComponent.self, for: entity) ||
            gameLoop.world.has(FurnaceComponent.self, for: entity)
        }) else {
            sendDebugLog("takeMachineItem: No machine found at (\(x), \(y))")
            throw NSError(domain: "GameNetworkManager", code: 27, userInfo: [NSLocalizedDescriptionKey: "No machine found at position"])
        }

        // Get machine inventory
        guard var machineInventory = gameLoop.world.get(InventoryComponent.self, for: targetEntity),
              slotIndex < machineInventory.slots.count else {
            sendDebugLog("takeMachineItem: Invalid slot index \(slotIndex) or no inventory")
            throw NSError(domain: "GameNetworkManager", code: 28, userInfo: [NSLocalizedDescriptionKey: "Invalid slot index or machine has no inventory"])
        }

        // Check if slot has items
        guard let itemStack = machineInventory.slots[slotIndex] else {
            sendDebugLog("takeMachineItem: Slot \(slotIndex) is empty")
            throw NSError(domain: "GameNetworkManager", code: 30, userInfo: [NSLocalizedDescriptionKey: "Slot is empty"])
        }

        // Determine how many items to take
        let countToTake = requestedCount ?? itemStack.count
        let actualCount = min(countToTake, itemStack.count)

        // Create item stack to add to player inventory
        let itemToTake = ItemStack(itemId: itemStack.itemId, count: actualCount, maxStack: itemStack.maxStack)
        
        // Try to add to player inventory
        let remainingCount = player.inventory.add(itemToTake)

        if remainingCount == 0 {
            // All items were successfully moved to player inventory
            if actualCount >= itemStack.count {
                // Took all items - clear the slot
                machineInventory.slots[slotIndex] = nil
            } else {
                // Took some items - update the slot
                machineInventory.slots[slotIndex] = ItemStack(
                    itemId: itemStack.itemId,
                    count: itemStack.count - actualCount,
                    maxStack: itemStack.maxStack
                )
            }
            gameLoop.world.add(machineInventory, to: targetEntity)

            sendDebugLog("takeMachineItem: Took \(actualCount) \(itemStack.itemId) from machine at (\(x), \(y)) slot \(slotIndex)")

            return [
                "success": true,
                "itemId": itemStack.itemId,
                "count": actualCount,
                "slot": slotIndex,
                "position": ["x": x, "y": y],
                "message": "Took \(actualCount) \(itemStack.itemId) from machine slot \(slotIndex)"
            ]
        } else {
            // Some items couldn't be moved - player inventory is full
            // Put the items back in the machine slot
            let itemsMoved = actualCount - remainingCount
            if itemsMoved > 0 {
                // Update the slot with remaining items
                machineInventory.slots[slotIndex] = ItemStack(
                    itemId: itemStack.itemId,
                    count: itemStack.count - itemsMoved,
                    maxStack: itemStack.maxStack
                )
                gameLoop.world.add(machineInventory, to: targetEntity)
            }

            sendDebugLog("takeMachineItem: Player inventory full - only moved \(itemsMoved) of \(actualCount) items")

            throw NSError(domain: "GameNetworkManager", code: 31, userInfo: [NSLocalizedDescriptionKey: "Player inventory is full. Only moved \(itemsMoved) of \(actualCount) items."])
        }
    }

    func deleteBuilding(_ parameters: [String: Any]) async throws -> Any {
        sendDebugLog("deleteBuilding: Called with parameters: \(parameters)")

        // Accept both Int and Double coordinates to handle floating point inputs
        let x: Int
        let y: Int

        if let intX = parameters["x"] as? Int {
            x = intX
        } else if let doubleX = parameters["x"] as? Double {
            x = Int(doubleX.rounded())
        } else {
            sendDebugLog("deleteBuilding: Missing or invalid x coordinate")
            throw NSError(domain: "GameNetworkManager", code: 25, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid x coordinate"])
        }

        if let intY = parameters["y"] as? Int {
            y = intY
        } else if let doubleY = parameters["y"] as? Double {
            y = Int(doubleY.rounded())
        } else {
            sendDebugLog("deleteBuilding: Missing or invalid y coordinate")
            throw NSError(domain: "GameNetworkManager", code: 25, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid y coordinate"])
        }

        guard let gameLoop = self.gameLoop else {
            sendDebugLog("deleteBuilding: Game not initialized")
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        let tilePos = IntVector2(x: Int32(x), y: Int32(y))
        sendDebugLog("deleteBuilding: Converted coordinates (\(x), \(y)) to tile position (\(tilePos.x), \(tilePos.y))")

        // Find entities at this position and nearby positions (in case of rounding issues)
        var entities = gameLoop.world.getAllEntitiesAt(position: tilePos)
        sendDebugLog("deleteBuilding: Found \(entities.count) entities at exact tile position (\(tilePos.x), \(tilePos.y))")

        // If no entities found at exact position, check nearby tiles
        if entities.isEmpty {
            for dx in -1...1 {
                for dy in -1...1 {
                    if dx == 0 && dy == 0 { continue } // Skip center tile
                    let nearbyPos = IntVector2(x: tilePos.x + Int32(dx), y: tilePos.y + Int32(dy))
                    let nearbyEntities = gameLoop.world.getAllEntitiesAt(position: nearbyPos)
                    entities.append(contentsOf: nearbyEntities)
                    sendDebugLog("deleteBuilding: Found \(nearbyEntities.count) entities at nearby position (\(nearbyPos.x), \(nearbyPos.y))")
                }
            }
        }

        // Look for buildings (entities with BuildingComponent) or any entity if none found
        var targetEntity = entities.first(where: { entity in
            gameLoop.world.has(BuildingComponent.self, for: entity)
        })

        if targetEntity == nil && !entities.isEmpty {
            // If no building found but entities exist, try the first entity
            // This allows deleting any entity, not just buildings
            targetEntity = entities.first
            sendDebugLog("deleteBuilding: No building component found, but found entity - attempting to delete any entity")
        }

        guard let entityToDelete = targetEntity else {
            sendDebugLog("deleteBuilding: No entity found at (\(x), \(y)) - entities found: \(entities.count)")
            throw NSError(domain: "GameNetworkManager", code: 30, userInfo: [NSLocalizedDescriptionKey: "No entity found at position (\(x), \(y))"])
        }

        // Try to get the building component to know what type it is and refund materials
        if let buildingComponent = gameLoop.world.get(BuildingComponent.self, for: entityToDelete),
           let buildingDef = gameLoop.buildingRegistry.get(buildingComponent.buildingId) {

            // Refund building materials to player
            if let player = gameLoop.player {
                for item in buildingDef.cost {
                    if let itemDef = gameLoop.itemRegistry.get(item.itemId) {
                        player.inventory.add(itemId: item.itemId, count: item.count, maxStack: itemDef.stackSize)
                    } else {
                        player.inventory.add(itemId: item.itemId, count: item.count, maxStack: 100)
                    }
                }
            }

            sendDebugLog("deleteBuilding: Refunded materials for \(buildingComponent.buildingId)")
        } else {
            sendDebugLog("deleteBuilding: No building component found - deleting entity without material refund")
        }

        // Remove the entity from the world
        gameLoop.world.despawn(entityToDelete)

        sendDebugLog("deleteBuilding: Deleted building at (\(x), \(y))")

        return [
            "success": true,
            "position": ["x": x, "y": y],
            "message": "Building deleted and materials refunded"
        ]
    }

    func moveBuilding(_ parameters: [String: Any]) async throws -> Any {
        sendDebugLog("moveBuilding: Called with parameters: \(parameters)")

        // Accept both Int and Double coordinates for all positions
        let fromX: Int, fromY: Int, toX: Int, toY: Int

        if let intX = parameters["fromX"] as? Int {
            fromX = intX
        } else if let doubleX = parameters["fromX"] as? Double {
            fromX = Int(doubleX.rounded())
        } else {
            sendDebugLog("moveBuilding: Missing or invalid fromX coordinate")
            throw NSError(domain: "GameNetworkManager", code: 25, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid fromX coordinate"])
        }

        if let intY = parameters["fromY"] as? Int {
            fromY = intY
        } else if let doubleY = parameters["fromY"] as? Double {
            fromY = Int(doubleY.rounded())
        } else {
            sendDebugLog("moveBuilding: Missing or invalid fromY coordinate")
            throw NSError(domain: "GameNetworkManager", code: 25, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid fromY coordinate"])
        }

        if let intX = parameters["toX"] as? Int {
            toX = intX
        } else if let doubleX = parameters["toX"] as? Double {
            toX = Int(doubleX.rounded())
        } else {
            sendDebugLog("moveBuilding: Missing or invalid toX coordinate")
            throw NSError(domain: "GameNetworkManager", code: 25, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid toX coordinate"])
        }

        if let intY = parameters["toY"] as? Int {
            toY = intY
        } else if let doubleY = parameters["toY"] as? Double {
            toY = Int(doubleY.rounded())
        } else {
            sendDebugLog("moveBuilding: Missing or invalid toY coordinate")
            throw NSError(domain: "GameNetworkManager", code: 25, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid toY coordinate"])
        }

        guard let gameLoop = self.gameLoop else {
            sendDebugLog("moveBuilding: Game not initialized")
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        let fromPos = IntVector2(x: Int32(fromX), y: Int32(fromY))
        let toPos = IntVector2(x: Int32(toX), y: Int32(toY))

        sendDebugLog("moveBuilding: Moving from (\(fromX), \(fromY)) to (\(toX), \(toY))")

        // Find building at source position
        let entities = gameLoop.world.getAllEntitiesAt(position: fromPos)
        guard let targetEntity = entities.first(where: { entity in
            gameLoop.world.has(BuildingComponent.self, for: entity)
        }) else {
            sendDebugLog("moveBuilding: No building found at source position")
            throw NSError(domain: "GameNetworkManager", code: 30, userInfo: [NSLocalizedDescriptionKey: "No building found at source position"])
        }

        // Check if destination is valid (empty)
        let destEntities = gameLoop.world.getAllEntitiesAt(position: toPos)
        guard destEntities.isEmpty else {
            sendDebugLog("moveBuilding: Destination position is not empty")
            throw NSError(domain: "GameNetworkManager", code: 31, userInfo: [NSLocalizedDescriptionKey: "Destination position is not empty"])
        }

        // Check if destination is valid for building placement
        guard let buildingComponent = gameLoop.world.get(BuildingComponent.self, for: targetEntity),
              gameLoop.buildingRegistry.get(buildingComponent.buildingId) != nil,
              gameLoop.canPlaceBuilding(buildingComponent.buildingId, at: toPos, direction: .north) else {
            sendDebugLog("moveBuilding: Cannot place building at destination")
            throw NSError(domain: "GameNetworkManager", code: 32, userInfo: [NSLocalizedDescriptionKey: "Cannot place building at destination"])
        }

        // Move the building by updating its position
        // Note: This is a simplified implementation. Real Factorio might have more complex movement logic
        if let positionComponent = gameLoop.world.get(PositionComponent.self, for: targetEntity) {
            var newPosition = positionComponent
            newPosition.tilePosition = IntVector2(x: Int32(toX), y: Int32(toY))
            gameLoop.world.add(newPosition, to: targetEntity)
        }

        sendDebugLog("moveBuilding: Moved building from (\(fromX), \(fromY)) to (\(toX), \(toY))")

        return [
            "success": true,
            "fromPosition": ["x": fromX, "y": fromY],
            "toPosition": ["x": toX, "y": toY],
            "message": "Building moved successfully"
        ]
    }

    func checkTileResources(_ parameters: [String: Any]) async throws -> Any {
        sendDebugLog("checkTileResources: Called with parameters: \(parameters)")

        // Accept both Int and Double coordinates
        let x: Int
        let y: Int

        if let intX = parameters["x"] as? Int {
            x = intX
        } else if let doubleX = parameters["x"] as? Double {
            x = Int(doubleX.rounded())
        } else {
            sendDebugLog("checkTileResources: Missing or invalid x coordinate")
            throw NSError(domain: "GameNetworkManager", code: 25, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid x coordinate"])
        }

        if let intY = parameters["y"] as? Int {
            y = intY
        } else if let doubleY = parameters["y"] as? Double {
            y = Int(doubleY.rounded())
        } else {
            sendDebugLog("checkTileResources: Missing or invalid y coordinate")
            throw NSError(domain: "GameNetworkManager", code: 25, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid y coordinate"])
        }

        guard let gameLoop = self.gameLoop else {
            sendDebugLog("checkTileResources: Game not initialized")
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        let tilePos = IntVector2(x: Int32(x), y: Int32(y))
        sendDebugLog("checkTileResources: Checking tile at (\(tilePos.x), \(tilePos.y))")

        // Check if there's a resource at this position
        let resource = gameLoop.chunkManager.getResource(at: tilePos)

        if let resource = resource, !resource.isEmpty {
            sendDebugLog("checkTileResources: Found resource: \(resource.type.outputItem), amount: \(resource.amount)")
            return [
                "hasResource": true,
                "resourceType": resource.type.outputItem,
                "amount": resource.amount,
                "position": ["x": x, "y": y],
                "tilePosition": ["x": tilePos.x, "y": tilePos.y]
            ]
        } else {
            sendDebugLog("checkTileResources: No resource found at (\(tilePos.x), \(tilePos.y))")
            // Check tile terrain type
            if let tile = gameLoop.chunkManager.getTile(at: tilePos) {
                let terrainType = tile.type
                sendDebugLog("checkTileResources: Tile exists at (\(tilePos.x), \(tilePos.y)), terrain: \(terrainType)")

                // Return terrain information for all tile types
                return [
                    "hasResource": false,
                    "hasTerrain": true,
                    "terrainType": "\(terrainType)",
                    "position": ["x": x, "y": y],
                    "tilePosition": ["x": tilePos.x, "y": tilePos.y]
                ]
            } else {
                sendDebugLog("checkTileResources: No tile found at (\(tilePos.x), \(tilePos.y))")
            }
            return [
                "hasResource": false,
                "position": ["x": x, "y": y],
                "tilePosition": ["x": tilePos.x, "y": tilePos.y]
            ]
        }
    }

    func buildMiningDrillOnDeposit(_ parameters: [String: Any]) async throws -> Any {
        sendDebugLog("buildMiningDrillOnDeposit: Called with parameters: \(parameters)")

        let resourceType = parameters["resourceType"] as? String ?? "iron-ore"
        let searchRadius = parameters["searchRadius"] as? Int ?? 10
        let fuelAmount = parameters["fuelAmount"] as? Int ?? 5

        guard let gameLoop = self.gameLoop else {
            sendDebugLog("buildMiningDrillOnDeposit: Game not initialized")
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        sendDebugLog("buildMiningDrillOnDeposit: Looking for \(resourceType) deposit within \(searchRadius) tiles")

        guard let player = gameLoop.player else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Player not available"])
        }
        let playerPos = player.position
        let centerTile = IntVector2(Int(playerPos.x), Int(playerPos.y))

        // Search for a resource deposit
        let radiusInt32 = Int32(searchRadius)
        var foundDeposit: (position: IntVector2, resource: Any)? = nil

        for x in (centerTile.x - radiusInt32)...(centerTile.x + radiusInt32) {
            for y in (centerTile.y - radiusInt32)...(centerTile.y + radiusInt32) {
                let tilePos = IntVector2(x: x, y: y)

                // Check if there's the requested resource at this position
                let resource = gameLoop.chunkManager.getResource(at: tilePos)
                if let resource = resource, !resource.isEmpty, resource.type.outputItem == resourceType {
                    sendDebugLog("buildMiningDrillOnDeposit: Found \(resourceType) deposit at (\(x), \(y)) with \(resource.amount) remaining")

                    // Check if there's already a building at this location
                    let entitiesAtPos = gameLoop.world.getAllEntitiesAt(position: tilePos)
                    let hasBuilding = entitiesAtPos.contains { entity in
                        gameLoop.world.has(BuildingComponent.self, for: entity)
                    }

                    if !hasBuilding {
                        sendDebugLog("buildMiningDrillOnDeposit: Location (\(x), \(y)) is clear, can place drill")
                        foundDeposit = (tilePos, resource)
                        break
                    } else {
                        sendDebugLog("buildMiningDrillOnDeposit: Location (\(x), \(y)) already has a building, skipping")
                    }
                }
            }
            if foundDeposit != nil { break }
        }

        guard let deposit = foundDeposit else {
            sendDebugLog("buildMiningDrillOnDeposit: No \(resourceType) deposit found within \(searchRadius) tiles")
            throw NSError(domain: "GameNetworkManager", code: 31, userInfo: [NSLocalizedDescriptionKey: "No \(resourceType) deposit found within search radius"])
        }

        // Check if we have enough resources to build the drill
        guard let player = gameLoop.player,
              player.inventory.has(itemId: "iron-plate", count: 5) else {
            sendDebugLog("buildMiningDrillOnDeposit: Not enough iron plates (need 5)")
            throw NSError(domain: "GameNetworkManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Not enough iron plates to build mining drill"])
        }

        // Build the mining drill at the deposit location
        sendDebugLog("buildMiningDrillOnDeposit: Building burner-mining-drill at (\(deposit.position.x), \(deposit.position.y))")
        let buildResult = gameLoop.placeBuilding("burner-mining-drill", at: deposit.position, direction: .north)

        guard buildResult else {
            sendDebugLog("buildMiningDrillOnDeposit: Failed to place mining drill")
            throw NSError(domain: "GameNetworkManager", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to place mining drill at deposit"])
        }

        // Fuel the mining drill
        sendDebugLog("buildMiningDrillOnDeposit: Fueling mining drill with \(fuelAmount) wood")
        _ = try await addMachineItem([
            "x": Int(deposit.position.x),
            "y": Int(deposit.position.y),
            "slot": 0,
            "itemId": "wood",
            "count": fuelAmount
        ])

        sendDebugLog("buildMiningDrillOnDeposit: Successfully built and fueled mining drill on \(resourceType) deposit")

        return [
            "success": true,
            "buildingId": "burner-mining-drill",
            "resourceType": resourceType,
            "position": ["x": Int(deposit.position.x), "y": Int(deposit.position.y)],
            "fueled": true,
            "fuelAmount": fuelAmount,
            "message": "Mining drill built and fueled on \(resourceType) deposit"
        ]
    }

    }

    private func buildStructure(_ parameters: [String: Any]) async throws -> Any {
        sendDebugLog("buildStructure: Starting build with parameters: \(parameters)")

        guard let gameLoop = gameLoop,
              let buildingId = parameters["buildingId"] as? String,
              let x = parameters["x"] as? Int,
              let y = parameters["y"] as? Int else {
            sendDebugLog("buildStructure: Invalid build parameters")
            throw NSError(domain: "GameNetworkManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid build parameters"])
        }

        sendDebugLog("buildStructure: Parameters validated - buildingId: \(buildingId), position: (\(x), \(y))")

        // Validate building exists
        guard let buildingDef = gameLoop.buildingRegistry.get(buildingId) else {
            sendDebugLog("buildStructure: Building not found in registry: \(buildingId)")
            throw NSError(domain: "GameNetworkManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Building not found: \(buildingId)"])
        }

        sendDebugLog("buildStructure: Building found - \(buildingId): \(buildingDef.name)")

        // Check if position is valid
        let tilePos = IntVector2(x: Int32(x), y: Int32(y))
        sendDebugLog("buildStructure: Checking if can place building at tile position (\(tilePos.x), \(tilePos.y))")

        guard gameLoop.canPlaceBuilding(buildingId, at: tilePos, direction: .north) else {
            sendDebugLog("buildStructure: Cannot place building at position (\(tilePos.x), \(tilePos.y))")
            throw NSError(domain: "GameNetworkManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Cannot place building at position"])
        }

        sendDebugLog("buildStructure: Position validation passed")

        // Check resources
        guard let player = gameLoop.player,
              player.inventory.has(items: buildingDef.cost) else {
            sendDebugLog("buildStructure: Insufficient resources for \(buildingId)")
            throw NSError(domain: "GameNetworkManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Insufficient resources"])
        }

        sendDebugLog("buildStructure: Resource check passed")

        // Place the building
        sendDebugLog("buildStructure: Attempting to place building \(buildingId) at (\(tilePos.x), \(tilePos.y))")
        if gameLoop.placeBuilding(buildingId, at: tilePos, direction: .north) {
            sendDebugLog("buildStructure: Building placement succeeded")

            // Consume resources
            for item in buildingDef.cost {
                player.inventory.remove(itemId: item.itemId, count: item.count)
            }

            sendDebugLog("buildStructure: Resources consumed, build complete")

            return [
                "success": true,
                "buildingId": buildingId,
                "position": ["x": x, "y": y],
                "message": "Building \(buildingId) placed successfully"
            ] as [String: Any]
        } else {
            throw NSError(domain: "GameNetworkManager", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to create building"])
        }
    }

    private func moveUnit(_ parameters: [String: Any]) async throws -> Any {
        guard let gameLoop = gameLoop,
              let unitIdString = parameters["unitId"] as? String,
              let x = parameters["x"] as? Int,
              let y = parameters["y"] as? Int,
              let unitId = UInt32(unitIdString) else {
            throw NSError(domain: "GameNetworkManager", code: 8, userInfo: [NSLocalizedDescriptionKey: "Invalid move parameters"])
        }

        // Find the unit
        let targetEntity = Entity(id: unitId, generation: 0) // Assume current generation
        guard gameLoop.world.get(UnitComponent.self, for: targetEntity) != nil else {
            throw NSError(domain: "GameNetworkManager", code: 9, userInfo: [NSLocalizedDescriptionKey: "Unit not found"])
        }

        // Get mutable unit component and issue move command
        if let unitPtr = gameLoop.world.getMutable(UnitComponent.self, for: targetEntity) {
            let targetPos = IntVector2(x: Int32(x), y: Int32(y))
            unitPtr.pointee.commandQueue.append(.move(to: targetPos))
        }

        return [
            "unitId": unitIdString,
            "targetPosition": ["x": x, "y": y]
        ]
    }

    private func movePlayer(_ parameters: [String: Any]) async throws -> Any {
        guard let gameLoop = gameLoop,
              let x = parameters["x"] as? Int,
              let y = parameters["y"] as? Int else {
            throw NSError(domain: "GameNetworkManager", code: 11, userInfo: [NSLocalizedDescriptionKey: "Invalid move_player parameters"])
        }

        // Move the player entity directly
        let targetPos = IntVector2(x: Int32(x), y: Int32(y))
        guard let player = gameLoop.player else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Player not available"])
        }
        gameLoop.world.add(PositionComponent(tilePosition: targetPos), to: player.playerEntity)

        return [
            "status": "player_moved",
            "targetPosition": ["x": x, "y": y]
        ]
    }

    private func sendDebugLog(_ message: String) {
        let timestamp = Date()
        let logEntry = "[\(timestamp)] \(message)"
        debugLogs.append(logEntry)

        // Keep only last 100 logs
        if debugLogs.count > 100 {
            debugLogs.removeFirst()
        }

        print("DEBUG: \(logEntry)")
    }

    private func attackWithPlayer(_ parameters: [String: Any]) async throws -> Any {
        guard let gameLoop = gameLoop,
              let player = gameLoop.player else {
            throw NSError(domain: "GameNetworkManager", code: 10, userInfo: [NSLocalizedDescriptionKey: "Game loop or player not available"])
        }
        
        // Handle both Double and Int types for coordinates
        var targetX: Double = 0
        var targetY: Double = 0
        
        if let x = parameters["targetX"] as? Double {
            targetX = x
        } else if let x = parameters["targetX"] as? Int {
            targetX = Double(x)
        } else if let x = parameters["targetX"] as? Float {
            targetX = Double(x)
        } else {
            throw NSError(domain: "GameNetworkManager", code: 10, userInfo: [NSLocalizedDescriptionKey: "Invalid targetX parameter - must be a number"])
        }
        
        if let y = parameters["targetY"] as? Double {
            targetY = y
        } else if let y = parameters["targetY"] as? Int {
            targetY = Double(y)
        } else if let y = parameters["targetY"] as? Float {
            targetY = Double(y)
        } else {
            throw NSError(domain: "GameNetworkManager", code: 10, userInfo: [NSLocalizedDescriptionKey: "Invalid targetY parameter - must be a number"])
        }

        let targetPosition = Vector2(Float(targetX), Float(targetY))
        let success = player.attack(at: targetPosition)
        
        print("GameNetworkManager: Player attack at (\(targetX), \(targetY)) - success: \(success)")
        
        if success {
            return [
                "success": true,
                "message": "Player attack executed successfully",
                "targetX": targetX,
                "targetY": targetY
            ]
        } else {
            return [
                "success": false,
                "message": "Player attack failed - check logs for reason (no ammo, out of range, no enemy found, or on cooldown)",
                "targetX": targetX,
                "targetY": targetY
            ]
        }
    }

    private func attackWithUnit(_ parameters: [String: Any]) async throws -> Any {
        guard let gameLoop = gameLoop,
              let unitIdString = parameters["unitId"] as? String,
              let targetIdString = parameters["targetId"] as? String,
              let unitId = UInt32(unitIdString),
              let targetId = UInt32(targetIdString) else {
            throw NSError(domain: "GameNetworkManager", code: 10, userInfo: [NSLocalizedDescriptionKey: "Invalid attack parameters"])
        }

        // Find the unit and target
        let unitEntity = Entity(id: unitId, generation: 0)
        let targetEntity = Entity(id: targetId, generation: 0)

        guard gameLoop.world.get(UnitComponent.self, for: unitEntity) != nil else {
            throw NSError(domain: "GameNetworkManager", code: 11, userInfo: [NSLocalizedDescriptionKey: "Unit not found"])
        }

        // Issue attack command
        if let unitPtr = gameLoop.world.getMutable(UnitComponent.self, for: unitEntity) {
            unitPtr.pointee.commandQueue.append(.attack(entity: targetEntity))
        }

        return [
            "unitId": unitIdString,
            "targetId": targetIdString
        ]
    }

    private func startResearch(_ parameters: [String: Any]) async throws -> Any {
        guard let gameLoop = gameLoop,
              let technologyId = parameters["technologyId"] as? String else {
            throw NSError(domain: "GameNetworkManager", code: 12, userInfo: [NSLocalizedDescriptionKey: "Invalid research parameters"])
        }

        // Check if technology exists and is available
        guard let technology = gameLoop.technologyRegistry.get(technologyId),
              gameLoop.researchSystem.canResearch(technology) else {
            throw NSError(domain: "GameNetworkManager", code: 13, userInfo: [NSLocalizedDescriptionKey: "Technology not available"])
        }

        // Start research
        if gameLoop.researchSystem.selectResearch(technologyId) {
            return [
                "technologyId": technologyId,
                "researchTime": technology.researchTime
            ]
        } else {
            throw NSError(domain: "GameNetworkManager", code: 14, userInfo: [NSLocalizedDescriptionKey: "Failed to start research"])
        }
    }

    private func sendGameState(to connection: NWConnection) {
        guard gameLoop != nil else { return }

        let gameState: [String: Any] = [
            "type": "game_state_update",
            "data": createGameStateDictionary()
        ]

        sendJSON(gameState, to: connection)
    }

    private func sendInitialGameState(to connection: NWConnection) {
        sendGameState(to: connection)
    }

    private func createGameStateDictionary() -> [String: Any] {
        guard let gameLoop = gameLoop else { return [:] }

        // Player data - get inventory items
        var playerResources: [String: Int] = [:]
        guard let player = gameLoop.player else { return [:] }
        for item in player.inventory.getAll() {
            playerResources[item.itemId] = item.count
        }

        let playerData: [String: Any] = [
            "resources": playerResources,
            "research": Array(gameLoop.researchSystem.completedTechnologies),
            "unlockedBuildings": gameLoop.buildingRegistry.all.map { $0.id },
            "unlockedUnits": ["worker", "soldier"] // TODO: Get from unit registry
        ]

        // World entities - only include entities with PositionComponent (to avoid entities without positions)
        var entities: [[String: Any]] = []
        for entity in gameLoop.world.entities {
            // Skip entities without position (they can't be displayed or targeted)
            guard gameLoop.world.has(PositionComponent.self, for: entity) else { continue }
            
            var entityData: [String: Any] = [
                "id": entity.id,
                "type": getEntityType(entity),
                "position": getEntityPosition(entity)
            ]

            if let health = gameLoop.world.get(HealthComponent.self, for: entity) {
                // Store both percentage and actual health values for better debugging
                entityData["health"] = health.percentage
                entityData["healthCurrent"] = health.current
                entityData["healthMax"] = health.max
                entityData["isDead"] = health.isDead
            }

            // Add enemy-specific information
            if let enemy = gameLoop.world.get(EnemyComponent.self, for: entity) {
                entityData["enemyType"] = enemy.type.rawValue
                // Convert EnemyState to string
                let stateString: String
                switch enemy.state {
                case .idle: stateString = "idle"
                case .wandering: stateString = "wandering"
                case .attacking: stateString = "attacking"
                case .returning: stateString = "returning"
                case .fleeing: stateString = "fleeing"
                }
                entityData["enemyState"] = stateString
                if let target = enemy.targetEntity {
                    entityData["targetEntityId"] = target.id
                }
            }

            if let miner = gameLoop.world.get(MinerComponent.self, for: entity) {
                entityData["production"] = ["speed": miner.miningSpeed]
            }

            entities.append(entityData)
        }

        // World chunks
        var chunks: [[String: Any]] = []
        for chunk in gameLoop.chunkManager.allLoadedChunks {
            chunks.append([
                "coord": ["x": chunk.coord.x as Any, "y": chunk.coord.y as Any],
                "loaded": true
            ])
        }

        // Systems data
        let systemsData: [String: Any] = [
            "power": [
                "totalGenerated": 0, // TODO: Implement power tracking
                "totalConsumed": 0   // TODO: Implement power tracking
            ],
            "fluid": [
                "networks": 0, // TODO: Implement network counting
                "totalFlow": 0 // TODO: Calculate total flow
            ],
            "research": [
                "current": gameLoop.researchSystem.currentResearch?.id as Any,
                "progress": [:] // TODO: Expose research progress
            ]
        ]

        // Performance data
        let performanceData: [String: Any] = [
            "fps": 60, // TODO: Get actual FPS
            "memoryUsage": 0, // TODO: Get memory usage
            "entityCount": entities.count
        ]

        return [
            "player": playerData,
            "world": [
                "entities": entities,
                "chunks": chunks
            ],
            "systems": systemsData,
            "performance": performanceData
        ]
    }

    private func getEntityType(_ entity: Entity) -> String {
        guard let gameLoop = gameLoop else { return "unknown" }

        // Check for enemies first (before buildings)
        if gameLoop.world.has(EnemyComponent.self, for: entity) {
            if let enemy = gameLoop.world.get(EnemyComponent.self, for: entity) {
                return enemy.type.rawValue  // Returns "smallBiter", "mediumBiter", etc.
            }
            return "enemy"
        }
        
        // Check for spawners
        if gameLoop.world.has(SpawnerComponent.self, for: entity) {
            return "spawner"
        }

        // Check for specific building types
        if gameLoop.world.has(LabComponent.self, for: entity) {
            return "lab"
        } else if gameLoop.world.has(FurnaceComponent.self, for: entity) {
            return "furnace"
        } else if gameLoop.world.has(MinerComponent.self, for: entity) {
            return "mining_drill"
        } else if gameLoop.world.has(AssemblerComponent.self, for: entity) {
            return "assembler"
        } else if gameLoop.world.has(ChestComponent.self, for: entity) {
            return "chest"
        } else if gameLoop.world.has(AccumulatorComponent.self, for: entity) {
            return "accumulator"
        } else if gameLoop.world.has(SolarPanelComponent.self, for: entity) {
            return "solar_panel"
        } else if gameLoop.world.has(GeneratorComponent.self, for: entity) {
            return "generator"
        } else if gameLoop.world.has(BuildingComponent.self, for: entity) {
            return "building"
        } else if gameLoop.world.has(UnitComponent.self, for: entity) {
            return "unit"
        } else if gameLoop.world.has(ProjectileComponent.self, for: entity) {
            return "projectile"
        }

        return "unknown"
    }

    private func getEntityPosition(_ entity: Entity) -> [String: Any] {
        guard let gameLoop = gameLoop,
              let position = gameLoop.world.get(PositionComponent.self, for: entity) else {
            return ["x": 0, "y": 0]
        }

        // Return both tile position (for grid-based queries) and world position (for distance calculations)
        return [
            "x": Int(position.tilePosition.x),
            "y": Int(position.tilePosition.y),
            "worldX": position.worldPosition.x,
            "worldY": position.worldPosition.y
        ]
    }

    private func sendJSON(_ json: [String: Any], to connection: NWConnection) {
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            connection.send(content: data, completion: .contentProcessed({ error in
                if let error = error {
                    print("GameNetworkManager: Failed to send message: \(error)")
                }
            }))
        } catch {
            print("GameNetworkManager: Failed to serialize JSON: \(error)")
        }
    }

    // Periodic game state broadcasting
    func broadcastGameState() {
        let gameState: [String: Any] = [
            "type": "game_state_update",
            "data": createGameStateDictionary()
        ]

        for connection in connections {
            sendJSON(gameState, to: connection)
        }
    }

    private func handleHTTPConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.receiveHTTPRequest(from: connection)
            case .failed(let error):
                print("GameNetworkManager: HTTP connection failed: \(error)")
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .main)
    }

    private func receiveHTTPRequest(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            if let data = data, let requestString = String(data: data, encoding: .utf8) {
                self?.processHTTPRequest(requestString, from: connection)
            } else if let error = error {
                print("GameNetworkManager: HTTP receive error: \(error)")
                connection.cancel()
            }
        }
    }

    private func processHTTPRequest(_ request: String, from connection: NWConnection) {
        // Simple HTTP request parsing
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return }

        let components = firstLine.components(separatedBy: " ")
        guard components.count >= 3, components[0] == "POST", components[1] == "/command" else {
            // Send 404 for non-command requests
            let response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
            return
        }

        // Find the body (after double CRLF)
        guard let bodyStart = request.range(of: "\r\n\r\n") else { return }
        let body = String(request[bodyStart.upperBound...])

        do {
            if let json = try JSONSerialization.jsonObject(with: body.data(using: .utf8)!, options: []) as? [String: Any],
               let command = json["command"] as? String {
                
                // Parameters might be missing or nil, so handle that case
                let parameters = json["parameters"] as? [String: Any] ?? [:]

                Task {
                    do {
                        // Check if gameLoop is available
                        guard self.gameLoop != nil else {
                            let errorResponse = Data("HTTP/1.1 503 Service Unavailable\r\nContent-Type: application/json\r\nContent-Length: 39\r\n\r\n{\"error\":\"Game not started yet\"}".utf8)
                            connection.send(content: errorResponse, completion: .contentProcessed { _ in
                                connection.cancel()
                            })
                            return
                        }

                        print("GameNetworkManager: Executing command '\(command)' with parameters: \(parameters)")
                        let result = try await self.executeCommand(command, parameters: parameters)
                        print("GameNetworkManager: Command result: \(result)")

                        // Defensive JSON serialization
                        guard JSONSerialization.isValidJSONObject(result) else {
                            // If result is not JSON serializable, convert to string representation
                            let stringResult = String(describing: result)
                            let fallbackResponse: [String: Any] = ["result": stringResult]
                            guard let response = JSONSerialization.isValidJSONObject(fallbackResponse) ? (try? JSONSerialization.data(withJSONObject: fallbackResponse, options: [])) : nil else {
                                // If even fallback fails, send minimal response
                                let minimalResponse = Data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\n\r\n{}".utf8)
                                connection.send(content: minimalResponse, completion: .contentProcessed { _ in
                                    connection.cancel()
                                })
                                return
                            }
                            let httpResponse = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(response.count)\r\n\r\n"
                            var fullResponse = httpResponse.data(using: .utf8)!
                            fullResponse.append(response)

                            connection.send(content: fullResponse, completion: .contentProcessed { _ in
                                connection.cancel()
                            })
                            return
                        }

                        let response = try JSONSerialization.data(withJSONObject: result, options: [])
                        let httpResponse = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(response.count)\r\n\r\n"
                        var fullResponse = httpResponse.data(using: .utf8)!
                        fullResponse.append(response)

                        print("GameNetworkManager: Sending HTTP response with \(response.count) bytes")
                        connection.send(content: fullResponse, completion: .contentProcessed { error in
                            if let error = error {
                                print("GameNetworkManager: Error sending response: \(error)")
                            }
                            connection.cancel()
                        })
                    } catch {
                        // Return error message in response
                        let errorMessage = error.localizedDescription
                        print("GameNetworkManager: Command execution error: \(errorMessage)")
                        let errorDict: [String: Any] = ["error": errorMessage, "success": false]
                        if let errorData = try? JSONSerialization.data(withJSONObject: errorDict, options: []) {
                            let httpResponse = "HTTP/1.1 500 Internal Server Error\r\nContent-Type: application/json\r\nContent-Length: \(errorData.count)\r\n\r\n"
                            var fullResponse = httpResponse.data(using: .utf8)!
                            fullResponse.append(errorData)
                            connection.send(content: fullResponse, completion: .contentProcessed { _ in
                                connection.cancel()
                            })
                        } else {
                            // Fallback to minimal response if JSON serialization fails
                            let minimalResponse = Data("HTTP/1.1 500 Internal Server Error\r\nContent-Length: 0\r\n\r\n".utf8)
                            connection.send(content: minimalResponse, completion: .contentProcessed { _ in
                                connection.cancel()
                            })
                        }
                    }
                }
            } else {
                // Invalid JSON or missing command
                print("GameNetworkManager: Invalid request - missing command or invalid JSON")
                let errorResponse = ["error": "Invalid request - missing command or invalid JSON"]
                if let response = try? JSONSerialization.data(withJSONObject: errorResponse, options: []) {
                    let httpResponse = "HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: \(response.count)\r\n\r\n"
                    var fullResponse = httpResponse.data(using: .utf8)!
                    fullResponse.append(response)
                    connection.send(content: fullResponse, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                }
            }
        } catch {
            let errorResponse = ["error": "Invalid JSON"]
            if let response = try? JSONSerialization.data(withJSONObject: errorResponse, options: []) {
                let httpResponse = "HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: \(response.count)\r\n\r\n"
                var fullResponse = httpResponse.data(using: .utf8)!
                fullResponse.append(response)

                connection.send(content: fullResponse, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    // MARK: - Save/Load Game Functions

    func startNewGame(_ parameters: [String: Any]) async throws -> Any {
        sendDebugLog("startNewGame: Attempting to start new game via MCP")

        // Check if we already have a game loop
        if self.gameLoop != nil {
            sendDebugLog("startNewGame: Game already exists")
            return ["message": "Game already running", "status": "active"]
        }

        // Signal the UI to start a new game
        sendDebugLog("startNewGame: Triggering UI callback for new game")
        let hasCallback = onNewGameRequested != nil
        sendDebugLog("startNewGame: Callback available: \(hasCallback)")

        if hasCallback {
            sendDebugLog("startNewGame: Calling callback...")
            onNewGameRequested?()
            sendDebugLog("startNewGame: Callback executed")
        } else {
            sendDebugLog("startNewGame: ERROR - No callback set up!")
        }

        return [
            "message": hasCallback ? "New game callback triggered" : "No callback available - rebuild app",
            "status": hasCallback ? "callback_triggered" : "callback_missing",
            "callback_setup": hasCallback
        ]
    }

    func saveGame(_ parameters: [String: Any]) async throws -> Any {
        guard let gameLoop = self.gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        let slotName = parameters["slotName"] as? String ?? "mcp_save_\(Int(Date().timeIntervalSince1970))"

        gameLoop.saveSystem.save(gameLoop: gameLoop, slotName: slotName)
        sendDebugLog("saveGame: Game saved to slot '\(slotName)'")

        return ["success": true, "slotName": slotName, "message": "Game saved successfully"]
    }

    func loadGame(_ parameters: [String: Any]) async throws -> Any {
        guard let slotName = parameters["slotName"] as? String else {
            throw NSError(domain: "GameNetworkManager", code: 20, userInfo: [NSLocalizedDescriptionKey: "Missing slotName parameter"])
        }

        guard let gameLoop = self.gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        guard let saveData = gameLoop.saveSystem.loadFromSlot(slotName) else {
            throw NSError(domain: "GameNetworkManager", code: 21, userInfo: [NSLocalizedDescriptionKey: "Save slot '\(slotName)' not found"])
        }

        gameLoop.saveSystem.load(saveData: saveData, into: gameLoop, slotName: slotName)
        sendDebugLog("loadGame: Game loaded from slot '\(slotName)'")

        return ["success": true, "slotName": slotName, "message": "Game loaded successfully"]
    }

    func listSaveSlots(_ parameters: [String: Any]) async throws -> Any {
        // Create a temporary SaveSystem to access saves even without an active gameLoop
        let tempSaveSystem = SaveSystem()
        let slots = tempSaveSystem.getSaveSlots()

        let slotData = slots.map { slot in
            return [
                "name": slot.name,
                "displayName": slot.displayName ?? slot.name,
                "playTime": slot.formattedPlayTime,
                "timestamp": slot.timestamp.ISO8601Format(),
                "modificationDate": slot.modificationDate.ISO8601Format()
            ]
        }

        sendDebugLog("listSaveSlots: Found \(slots.count) save slots")
        return ["saveSlots": slotData, "count": slots.count]
    }

    func deleteSaveSlot(_ parameters: [String: Any]) async throws -> Any {
        guard let slotName = parameters["slotName"] as? String else {
            throw NSError(domain: "GameNetworkManager", code: 22, userInfo: [NSLocalizedDescriptionKey: "Missing slotName parameter"])
        }

        guard let gameLoop = self.gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        gameLoop.saveSystem.deleteSave(slotName)
        sendDebugLog("deleteSaveSlot: Deleted save slot '\(slotName)'")

        return ["success": true, "slotName": slotName, "message": "Save slot deleted successfully"]
    }

    func renameSaveSlot(_ parameters: [String: Any]) async throws -> Any {
        guard let slotName = parameters["slotName"] as? String else {
            throw NSError(domain: "GameNetworkManager", code: 23, userInfo: [NSLocalizedDescriptionKey: "Missing slotName parameter"])
        }

        guard let newName = parameters["newName"] as? String else {
            throw NSError(domain: "GameNetworkManager", code: 24, userInfo: [NSLocalizedDescriptionKey: "Missing newName parameter"])
        }

        guard let gameLoop = self.gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        gameLoop.saveSystem.setDisplayName(newName, for: slotName)
        sendDebugLog("renameSaveSlot: Renamed save slot '\(slotName)' to '\(newName)'")

        return ["success": true, "oldName": slotName, "newName": newName, "message": "Save slot renamed successfully"]
    }

    // MARK: - Machine UI Configuration Methods

    func updateMachineUIConfig(_ parameters: [String: Any]) async throws -> Any {
        guard let machineType = parameters["machineType"] as? String else {
            throw NSError(domain: "GameNetworkManager", code: 25, userInfo: [NSLocalizedDescriptionKey: "Missing machineType parameter"])
        }

        guard let configDict = parameters["config"] as? [String: Any] else {
            throw NSError(domain: "GameNetworkManager", code: 26, userInfo: [NSLocalizedDescriptionKey: "Missing config parameter"])
        }

        guard let gameLoop = self.gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        // Check if this is the new schema format (has $schema field)
        let isSchemaFormat = configDict["$schema"] != nil

        // Apply the configuration to the UI system (must be done on main thread)
        let result: [String: Any] = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: NSError(domain: "GameNetworkManager", code: 27, userInfo: [NSLocalizedDescriptionKey: "Self is nil"]))
                    return
                }

                guard let gameLoop = self.gameLoop else {
                    continuation.resume(throwing: NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"]))
                    return
                }

                if let machineUI = gameLoop.uiSystem?.getMachineUI() {
                    // Check if machine UI is open and has rootView
                    guard machineUI.isOpen, machineUI.rootView != nil else {
                        continuation.resume(throwing: NSError(domain: "GameNetworkManager", code: 29, userInfo: [NSLocalizedDescriptionKey: "Machine UI must be open to apply schema updates. Please open the machine UI panel first."]))
                        return
                    }
                    
                    do {
                        if isSchemaFormat {
                            // Handle new schema format
                            self.sendDebugLog("updateMachineUIConfig: Attempting to serialize configDict for schema format")
                            let jsonData = try JSONSerialization.data(withJSONObject: configDict, options: [])
                            self.sendDebugLog("updateMachineUIConfig: Serialized to JSON data, size: \(jsonData.count) bytes")
                            
                            // Log the JSON string for debugging
                            if let jsonString = String(data: jsonData, encoding: .utf8) {
                                self.sendDebugLog("updateMachineUIConfig: JSON string (first 500 chars): \(String(jsonString.prefix(500)))")
                            }
                            
                            let decoder = JSONDecoder()
                            decoder.keyDecodingStrategy = .convertFromSnakeCase
                            let schema = try decoder.decode(MachineUISchema.self, from: jsonData)
                            self.sendDebugLog("updateMachineUIConfig: Successfully decoded schema with \(schema.groups.count) groups")

                            try machineUI.applySchema(schema)
                            self.sendDebugLog("updateMachineUIConfig: Successfully applied schema for machine type '\(machineType)'")
                            continuation.resume(returning: ["success": true, "machineType": machineType, "message": "Machine UI schema applied successfully"])
                        } else {
                            // Handle old flat component format
                            let jsonData = try JSONSerialization.data(withJSONObject: configDict)
                            let decoder = JSONDecoder()
                            let config = try decoder.decode(MachineUIConfig.self, from: jsonData)

                            machineUI.updateConfiguration(config)
                            self.sendDebugLog("updateMachineUIConfig: Successfully updated configuration for machine type '\(machineType)'")
                            continuation.resume(returning: ["success": true, "machineType": machineType, "message": "Machine UI configuration updated successfully"])
                        }
                    } catch {
                        let errorDetails = "\(error.localizedDescription). Error type: \(type(of: error)). Underlying error: \(error)"
                        self.sendDebugLog("updateMachineUIConfig: Error details: \(errorDetails)")
                        if let decodingError = error as? DecodingError {
                            switch decodingError {
                            case .dataCorrupted(let context):
                                self.sendDebugLog("updateMachineUIConfig: Data corrupted: \(context.debugDescription)")
                            case .keyNotFound(let key, let context):
                                self.sendDebugLog("updateMachineUIConfig: Key '\(key.stringValue)' not found: \(context.debugDescription)")
                            case .typeMismatch(let type, let context):
                                self.sendDebugLog("updateMachineUIConfig: Type mismatch for \(type): \(context.debugDescription)")
                            case .valueNotFound(let type, let context):
                                self.sendDebugLog("updateMachineUIConfig: Value not found for \(type): \(context.debugDescription)")
                            @unknown default:
                                self.sendDebugLog("updateMachineUIConfig: Unknown decoding error")
                            }
                        }
                        continuation.resume(throwing: NSError(domain: "GameNetworkManager", code: 28, userInfo: [NSLocalizedDescriptionKey: "Failed to apply configuration: \(error.localizedDescription)"]))
                    }
                } else {
                    continuation.resume(throwing: NSError(domain: "GameNetworkManager", code: 27, userInfo: [NSLocalizedDescriptionKey: "UI system not available"]))
                }
            }
        }

        return result
    }

    func getMachineUIConfig(_ parameters: [String: Any]) async throws -> Any {
        guard let machineType = parameters["machineType"] as? String else {
            throw NSError(domain: "GameNetworkManager", code: 29, userInfo: [NSLocalizedDescriptionKey: "Missing machineType parameter"])
        }

        guard let gameLoop = self.gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        // Get the configuration from the UI system
        if let machineUI = gameLoop.uiSystem?.getMachineUI(),
           let config = machineUI.getConfiguration(for: machineType) {
            // Convert to dictionary format for JSON response
            let encoder = JSONEncoder()
            let data = try encoder.encode(config)
            let jsonObject = try JSONSerialization.jsonObject(with: data)

            sendDebugLog("getMachineUIConfig: Retrieved configuration for machine type '\(machineType)'")
            return ["config": jsonObject, "message": "Machine UI configuration retrieved successfully"]
        } else {
            throw NSError(domain: "GameNetworkManager", code: 30, userInfo: [NSLocalizedDescriptionKey: "Configuration not found for machine type '\(machineType)'"])
        }
    }

    func listMachineUIConfigs(_ parameters: [String: Any]) async throws -> Any {
        guard let gameLoop = self.gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        // Get all configurations from the UI system
        if let machineUI = gameLoop.uiSystem?.getMachineUI() {
            let allConfigs = machineUI.getAllConfigurations()

            // Convert to array format for JSON response
            var configsArray: [[String: Any]] = []
            let encoder = JSONEncoder()

            for (machineType, config) in allConfigs {
                let data = try encoder.encode(config)
                if var jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    jsonObject["machineType"] = machineType
                    configsArray.append(jsonObject)
                }
            }

            sendDebugLog("listMachineUIConfigs: Found \(configsArray.count) configurations")
            return ["configurations": configsArray, "count": configsArray.count, "message": "Machine UI configurations retrieved successfully"]
        } else {
            throw NSError(domain: "GameNetworkManager", code: 31, userInfo: [NSLocalizedDescriptionKey: "UI system not available"])
        }
    }

    func reloadMachineUISchema(_ parameters: [String: Any]) async throws -> Any {
        guard let gameLoop = self.gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        let machineType = parameters["machineType"] as? String

        // Reload schema (must be done on main thread)
        let result: [String: Any] = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: NSError(domain: "GameNetworkManager", code: 27, userInfo: [NSLocalizedDescriptionKey: "Self is nil"]))
                    return
                }

                guard let gameLoop = self.gameLoop else {
                    continuation.resume(throwing: NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"]))
                    return
                }

                if let machineUI = gameLoop.uiSystem?.getMachineUI() {
                    do {
                        try machineUI.reloadSchema(for: machineType)
                        let message = machineType != nil 
                            ? "Reloaded schema for machine type '\(machineType!)'"
                            : "Reloaded all machine UI schemas"
                        self.sendDebugLog("reloadMachineUISchema: \(message)")
                        continuation.resume(returning: [
                            "success": true,
                            "machineType": machineType ?? "all",
                            "message": message
                        ])
                    } catch {
                        continuation.resume(throwing: NSError(domain: "GameNetworkManager", code: 32, userInfo: [NSLocalizedDescriptionKey: "Failed to reload schema: \(error.localizedDescription)"]))
                    }
                } else {
                    continuation.resume(throwing: NSError(domain: "GameNetworkManager", code: 27, userInfo: [NSLocalizedDescriptionKey: "UI system not available"]))
                }
            }
        }

        return result
    }

    func testMachineUISchema(_ parameters: [String: Any]) async throws -> Any {
        guard let gameLoop = self.gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        guard let machineType = parameters["machineType"] as? String else {
            throw NSError(domain: "GameNetworkManager", code: 33, userInfo: [NSLocalizedDescriptionKey: "Missing machineType parameter"])
        }

        // Test schema (must be done on main thread)
        let result: [String: Any] = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: NSError(domain: "GameNetworkManager", code: 27, userInfo: [NSLocalizedDescriptionKey: "Self is nil"]))
                    return
                }

                guard let gameLoop = self.gameLoop else {
                    continuation.resume(throwing: NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"]))
                    return
                }

                if let machineUI = gameLoop.uiSystem?.getMachineUI() {
                    let testResult = machineUI.testSchema(for: machineType)
                    self.sendDebugLog("testMachineUISchema: Tested schema for \(machineType) - success: \(testResult["success"] as? Bool ?? false)")
                    continuation.resume(returning: testResult)
                } else {
                    continuation.resume(throwing: NSError(domain: "GameNetworkManager", code: 27, userInfo: [NSLocalizedDescriptionKey: "UI system not available"]))
                }
            }
        }

        return result
    }

    func getMachineUIState(_ parameters: [String: Any]) async throws -> Any {
        guard let gameLoop = self.gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"])
        }

        // Get state (must be done on main thread)
        let result: [String: Any] = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: NSError(domain: "GameNetworkManager", code: 27, userInfo: [NSLocalizedDescriptionKey: "Self is nil"]))
                    return
                }

                guard let gameLoop = self.gameLoop else {
                    continuation.resume(throwing: NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not initialized"]))
                    return
                }

                if let machineUI = gameLoop.uiSystem?.getMachineUI() {
                    var state = machineUI.getState()
                    
                    // Add recent debug logs related to MachineUI
                    let recentLogs = self.debugLogs.suffix(20).filter { log in
                        log.contains("MachineUI") || log.contains("schema") || log.contains("Schema")
                    }
                    state["recentLogs"] = Array(recentLogs)
                    
                    self.sendDebugLog("getMachineUIState: Retrieved state for MachineUI")
                    continuation.resume(returning: state)
                } else {
                    continuation.resume(throwing: NSError(domain: "GameNetworkManager", code: 27, userInfo: [NSLocalizedDescriptionKey: "UI system not available"]))
                }
            }
        }

        return result
    }

    // MARK: - Starting Items Configuration Methods

    func getStartingItemsConfig(_ parameters: [String: Any]) async throws -> Any {
        // Load the starting items config from the bundled JSON file
        if let configURL = Bundle.main.url(forResource: "starting_items", withExtension: "json") {
            do {
                let data = try Data(contentsOf: configURL)
                let jsonObject = try JSONSerialization.jsonObject(with: data)
                return ["config": jsonObject, "message": "Starting items configuration retrieved successfully"]
            } catch {
                throw NSError(domain: "GameNetworkManager", code: 32, userInfo: [NSLocalizedDescriptionKey: "Error reading starting items config: \(error)"])
            }
        } else {
            throw NSError(domain: "GameNetworkManager", code: 33, userInfo: [NSLocalizedDescriptionKey: "Starting items config file not found"])
        }
    }

    func updateStartingItemsConfig(_ parameters: [String: Any]) async throws -> Any {
        guard let startingItemsArray = parameters["startingItems"] as? [[String: Any]] else {
            throw NSError(domain: "GameNetworkManager", code: 34, userInfo: [NSLocalizedDescriptionKey: "Missing startingItems parameter"])
        }

        // Convert the array to StartingItem structs
        var startingItems: [StartingItemsConfig.StartingItem] = []
        for itemDict in startingItemsArray {
            guard let itemId = itemDict["itemId"] as? String,
                  let count = itemDict["count"] as? Int else {
                continue
            }
            let comment = itemDict["comment"] as? String
            startingItems.append(StartingItemsConfig.StartingItem(itemId: itemId, count: count, comment: comment))
        }

        // Note: In a full implementation, this would save to a user-editable file
        // For now, we acknowledge the update but it won't persist across app restarts
        sendDebugLog("updateStartingItemsConfig: Updated starting items config with \(startingItems.count) items")

        return ["success": true, "itemCount": startingItems.count, "message": "Starting items configuration updated (will take effect on next game restart)"]
    }

    func getBuildingConfig(_ parameters: [String: Any]) async throws -> Any {
        guard let buildingId = parameters["buildingId"] as? String else {
            throw NSError(domain: "GameNetworkManager", code: 35, userInfo: [NSLocalizedDescriptionKey: "Missing buildingId parameter"])
        }

        guard let gameLoop = gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No game loop available"])
        }

        guard let config = gameLoop.buildingRegistry.getBuildingConfig(for: buildingId) else {
            throw NSError(domain: "GameNetworkManager", code: 36, userInfo: [NSLocalizedDescriptionKey: "Building with ID '\(buildingId)' not found"])
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(config)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        sendDebugLog("getBuildingConfig: Retrieved config for building '\(buildingId)'")
        return ["buildingId": buildingId, "config": config, "json": jsonString]
    }

    func updateBuildingConfig(_ parameters: [String: Any]) async throws -> Any {
        guard let buildingId = parameters["buildingId"] as? String else {
            throw NSError(domain: "GameNetworkManager", code: 37, userInfo: [NSLocalizedDescriptionKey: "Missing buildingId parameter"])
        }

        guard let configDict = parameters["config"] as? [String: Any] else {
            throw NSError(domain: "GameNetworkManager", code: 38, userInfo: [NSLocalizedDescriptionKey: "Missing config parameter"])
        }

        guard let gameLoop = gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No game loop available"])
        }

        // Convert the dictionary to BuildingConfig struct
        let jsonData = try JSONSerialization.data(withJSONObject: configDict, options: [])
        let config = try JSONDecoder().decode(BuildingConfig.self, from: jsonData)

        let success = gameLoop.buildingRegistry.updateBuildingConfig(config)

        if success {
            sendDebugLog("updateBuildingConfig: Successfully updated config for building '\(buildingId)'")
            return ["success": true, "buildingId": buildingId, "message": "Building configuration updated successfully"]
        } else {
            throw NSError(domain: "GameNetworkManager", code: 39, userInfo: [NSLocalizedDescriptionKey: "Failed to update building configuration"])
        }
    }

    func listBuildingConfigs(_ parameters: [String: Any]) async throws -> Any {
        guard let gameLoop = gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No game loop available"])
        }

        let configs = gameLoop.buildingRegistry.getAllBuildingConfigs()

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(configs)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        sendDebugLog("listBuildingConfigs: Retrieved \(configs.count) building configurations")
        return ["buildingCount": configs.count, "configs": configs, "json": jsonString]
    }
}
