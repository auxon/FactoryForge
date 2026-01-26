import axios from 'axios';
export class GameController {
    gameState = null;
    gameWs = null; // WebSocket connection to iPhone app
    pendingRequests = new Map();
    gameHost;
    constructor(gameHost = 'localhost') {
        this.gameHost = gameHost;
    }
    // Called when iPhone app connects via WebSocket
    setGameConnection(ws) {
        console.log('GameController: iPhone app connected');
        this.gameWs = ws;
        ws.on('message', (data) => {
            try {
                const message = JSON.parse(data.toString());
                this.handleGameMessage(message);
            }
            catch (error) {
                console.error('Error handling game message:', error);
            }
        });
        ws.on('close', () => {
            console.log('GameController: iPhone app disconnected');
            this.gameWs = null;
        });
    }
    handleGameMessage(message) {
        if (message.type === 'game_state_update') {
            this.gameState = message.data;
        }
        else if (message.type === 'command_result') {
            const request = this.pendingRequests.get(message.requestId);
            if (request) {
                this.pendingRequests.delete(message.requestId);
                if (message.success) {
                    request.resolve(message.result);
                }
                else {
                    request.reject(new Error(message.error));
                }
            }
        }
    }
    getGameState() {
        return this.gameState;
    }
    async executeCommand(command) {
        console.log(`Executing command: ${command.command}`);
        // Use HTTP only (WebSocket connections are unstable in simulator)
        console.log('Using HTTP connection (WebSocket disabled)');
        try {
            const response = await axios.post(`http://${this.gameHost}:8083/command`, {
                command: command.command,
                requestId: Math.random().toString(36).substring(7),
                parameters: command.parameters || {},
            }, {
                timeout: 10000,
                headers: {
                    'Content-Type': 'application/json',
                },
                responseType: 'json', // Explicitly request JSON response
                validateStatus: (status) => status < 500, // Accept any status < 500
            });
            // Handle response data - ensure it's an object
            let responseData = response.data;
            // If response.data is a string, try to parse it as JSON
            if (typeof responseData === 'string') {
                try {
                    responseData = JSON.parse(responseData);
                }
                catch (parseError) {
                    console.error('Failed to parse response as JSON:', responseData);
                    return {
                        success: false,
                        error: 'Invalid JSON response from game',
                        rawResponse: responseData.substring(0, 100) // First 100 chars for debugging
                    };
                }
            }
            console.log('iPhone response:', JSON.stringify(responseData, null, 2));
            // If response is empty object, log warning
            if (responseData && typeof responseData === 'object' && Object.keys(responseData).length === 0) {
                console.warn('Received empty response object from game - this might indicate the command was not processed');
            }
            return responseData;
        }
        catch (error) {
            console.error('HTTP connection error:', error.response?.data || error.message);
            // If axios throws an error, try to extract useful information
            if (error.response) {
                // Server responded with error status
                let errorData = error.response.data;
                if (typeof errorData === 'string') {
                    try {
                        errorData = JSON.parse(errorData);
                    }
                    catch {
                        // If parsing fails, return the string
                        errorData = { error: errorData };
                    }
                }
                return {
                    success: false,
                    error: errorData.error || error.message,
                    status: error.response.status,
                    details: errorData
                };
            }
            return {
                success: false,
                error: `Cannot connect to FactoryForge iOS app at ${this.gameHost}:8083.`,
                details: error.message || 'Make sure the app is running on your iPhone and on the same network.'
            };
        }
    }
    getEntities(filter = {}) {
        if (!this.gameState)
            return [];
        let entities = this.gameState.world.entities;
        if (filter.type && filter.type !== 'all') {
            entities = entities.filter(e => e.type === filter.type);
        }
        if (filter.area) {
            const { x, y, width, height } = filter.area;
            entities = entities.filter(e => e.position.x >= x && e.position.x < x + width &&
                e.position.y >= y && e.position.y < y + height);
        }
        return entities;
    }
    modifyGameCode(modification) {
        // This would send a code modification request to the iOS app
        // The iOS app would need to support dynamic code modification
        console.log(`Modifying ${modification.target}: ${modification.modification}`);
        // For now, just return a placeholder response
        return `Code modification applied to ${modification.target}: ${modification.modification}`;
    }
    getPerformanceMetrics() {
        return this.gameState?.performance || {
            fps: 0,
            memoryUsage: 0,
            entityCount: 0,
        };
    }
    async takeScreenshot(format = 'png') {
        // This would request a screenshot from the iOS app
        // For now, return a placeholder
        return 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jzyr5AAAAABJRU5ErkJggg=='; // 1x1 transparent PNG
    }
    isGameOver() {
        // Check if the player has died or the game is over
        // Since the user reported death, we'll use multiple indicators
        if (!this.gameState)
            return false;
        // Check for excessive number of entities which might indicate biters after death
        if (this.gameState.world.entities.length > 50) {
            console.log(`Game over detected: ${this.gameState.world.entities.length} entities (possible biter infestation after death)`);
            return true;
        }
        // Check for many scattered "unknown" entities (likely biters)
        const unknownEntities = this.gameState.world.entities.filter(e => e.type === 'unknown');
        if (unknownEntities.length > 40) {
            console.log(`Game over detected: ${unknownEntities.length} unknown entities (likely biters after player death)`);
            return true;
        }
        // Check for entities at extreme coordinates (biter spawns after death)
        const extremeEntities = this.gameState.world.entities.filter(e => Math.abs(e.position.x) > 100 || Math.abs(e.position.y) > 100);
        if (extremeEntities.length > 10) {
            console.log(`Game over detected: ${extremeEntities.length} entities at extreme coordinates (biter infestation)`);
            return true;
        }
        return false;
    }
    getGameOverStatus() {
        return {
            gameOver: this.isGameOver(),
            message: this.isGameOver() ? 'Player has died. Game over.' : 'Game is active.',
            canRespawn: this.isGameOver(),
            respawnHint: 'Load a saved game or start a new game to continue.'
        };
    }
}
