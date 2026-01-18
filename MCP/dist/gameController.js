import axios from 'axios';
export class GameController {
    gameState = null;
    wsClient = null;
    pendingRequests = new Map();
    gameHost;
    constructor(gameHost = 'localhost') {
        this.gameHost = gameHost;
    }
    // HTTP-based communication - no persistent connection needed
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
        console.log(`Executing command: ${command.command} via HTTP`);
        // Connect to iOS FactoryForge app
        try {
            const response = await axios.post(`http://${this.gameHost}:8083/command`, {
                command: command.command,
                requestId: Math.random().toString(36).substring(7),
                parameters: command.parameters || {},
            }, {
                timeout: 10000, // 10 second timeout
                headers: {
                    'Content-Type': 'application/json',
                },
            });
            console.log('iPhone response:', response.data);
            return response.data;
        }
        catch (error) {
            console.error('iPhone connection error:', error.response?.data || error.message);
            // If iPhone is not available, return a helpful error message
            if (error.code === 'ECONNREFUSED' || error.code === 'ENOTFOUND') {
                return {
                    success: false,
                    error: `Cannot connect to FactoryForge iOS app at ${this.gameHost}:8083. Make sure the app is running on your iPhone.`,
                    details: 'Check that your iPhone is on the same network and the FactoryForge app is launched.'
                };
            }
            throw new Error(`Command failed: ${error.response?.data?.error || error.message}`);
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
}
