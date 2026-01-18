import Foundation
import Network

/// Network manager for MCP communication
@available(iOS 17.0, *)
final class GameNetworkManager {
    static let shared = GameNetworkManager()

    private var wsListener: NWListener?
    private var httpListener: NWListener?
    private var connections: [NWConnection] = []
    private var gameLoop: GameLoop?
    private var debugLogs: [String] = []

    private init() {
        // setupWebSocketServer()  // Temporarily disabled to debug HTTP server crash
        setupHTTPServer()
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

            wsListener?.stateUpdateHandler = { [weak self] (state: NWListener.State) in
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

            httpListener?.stateUpdateHandler = { [weak self] state in
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
        guard let gameLoop = gameLoop else { return }

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
        guard let gameLoop = gameLoop,
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
        guard let gameLoop = gameLoop else {
            throw NSError(domain: "GameNetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No game loop available"])
        }

        // Send debug log over HTTP
        sendDebugLog("Executing command: \(command) with parameters: \(parameters)")

        switch command {
        case "build":
            return try await buildStructure(parameters)
        case "move":
            return try await moveUnit(parameters)
        case "move_player":
            return try await movePlayer(parameters)
        case "attack":
            return try await attackWithUnit(parameters)
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
    }

    private func buildStructure(_ parameters: [String: Any]) async throws -> Any {
        guard let gameLoop = gameLoop,
              let buildingId = parameters["buildingId"] as? String,
              let x = parameters["x"] as? Int,
              let y = parameters["y"] as? Int else {
            throw NSError(domain: "GameNetworkManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid build parameters"])
        }

        // Validate building exists
        guard let buildingDef = gameLoop.buildingRegistry.get(buildingId) else {
            throw NSError(domain: "GameNetworkManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Building not found: \(buildingId)"])
        }

        // Check if position is valid
        let tilePos = IntVector2(x: Int32(x), y: Int32(y))
        guard gameLoop.canPlaceBuilding(buildingId, at: tilePos, direction: .north) else {
            throw NSError(domain: "GameNetworkManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Cannot place building at position"])
        }

        // Check resources
        guard gameLoop.player.inventory.has(items: buildingDef.cost) else {
            throw NSError(domain: "GameNetworkManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Insufficient resources"])
        }

        // Place the building
        if gameLoop.placeBuilding(buildingId, at: tilePos, direction: .north) {
            // Consume resources
            for item in buildingDef.cost {
                gameLoop.player.inventory.remove(itemId: item.itemId, count: item.count)
            }

            return [
                "success": true,
                "buildingId": buildingId,
                "position": ["x": x, "y": y]
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
        gameLoop.world.add(PositionComponent(tilePosition: targetPos), to: gameLoop.player.playerEntity)

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
        guard let gameLoop = gameLoop else { return }

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
        for item in gameLoop.player.inventory.getAll() {
            playerResources[item.itemId] = item.count
        }

        let playerData: [String: Any] = [
            "resources": playerResources,
            "research": Array(gameLoop.researchSystem.completedTechnologies),
            "unlockedBuildings": gameLoop.buildingRegistry.all.map { $0.id },
            "unlockedUnits": ["worker", "soldier"] // TODO: Get from unit registry
        ]

        // World entities
        var entities: [[String: Any]] = []
        for entity in gameLoop.world.entities {
            var entityData: [String: Any] = [
                "id": entity.id,
                "type": getEntityType(entity),
                "position": getEntityPosition(entity)
            ]

            if let health = gameLoop.world.get(HealthComponent.self, for: entity) {
                entityData["health"] = health.percentage
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
                "coord": ["x": chunk.coord.x, "y": chunk.coord.y],
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
                "current": gameLoop.researchSystem.currentResearch?.id,
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

        if gameLoop.world.has(BuildingComponent.self, for: entity) {
            return "building"
        } else if gameLoop.world.has(UnitComponent.self, for: entity) {
            return "unit"
        }

        return "unknown"
    }

    private func getEntityPosition(_ entity: Entity) -> [String: Int] {
        guard let gameLoop = gameLoop,
              let position = gameLoop.world.get(PositionComponent.self, for: entity)?.tilePosition else {
            return ["x": 0, "y": 0]
        }

        return ["x": Int(position.x), "y": Int(position.y)]
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
               let command = json["command"] as? String,
               let parameters = json["parameters"] as? [String: Any] {

                Task {
                    do {
                        let result = try await self.executeCommand(command, parameters: parameters)

                        // Defensive JSON serialization
                        guard JSONSerialization.isValidJSONObject(result) else {
                            // If result is not JSON serializable, convert to string representation
                            let stringResult = String(describing: result)
                            let fallbackResponse: [String: Any] = ["result": stringResult]
                            guard let response = try? JSONSerialization.data(withJSONObject: fallbackResponse, options: []) else {
                                // If even fallback fails, send minimal response
                                let minimalResponse = Data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\n\r\n{}".utf8)
                                try? connection.send(content: minimalResponse, completion: .contentProcessed { _ in
                                    connection.cancel()
                                })
                                return
                            }
                            let httpResponse = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(response.count)\r\n\r\n"
                            var fullResponse = httpResponse.data(using: .utf8)!
                            fullResponse.append(response)

                            try? connection.send(content: fullResponse, completion: .contentProcessed { _ in
                                connection.cancel()
                            })
                            return
                        }

                        let response = try JSONSerialization.data(withJSONObject: result, options: [])
                        let httpResponse = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(response.count)\r\n\r\n"
                        var fullResponse = httpResponse.data(using: .utf8)!
                        fullResponse.append(response)

                        try? connection.send(content: fullResponse, completion: .contentProcessed { _ in
                            connection.cancel()
                        })
                    } catch {
                        // Absolute minimal error handling - avoid any complex operations that could crash
                        let minimalResponse = Data("HTTP/1.1 500 Internal Server Error\r\nContent-Length: 0\r\n\r\n".utf8)

                        // Use try? to make send operation optional and avoid crashes
                        try? connection.send(content: minimalResponse, completion: .contentProcessed { _ in
                            connection.cancel()
                        })
                    }
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
}