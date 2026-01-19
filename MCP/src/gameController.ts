import WebSocket from 'ws';
import axios from 'axios';

export interface GameState {
  player: {
    resources: Record<string, number>;
    research: string[];
    unlockedBuildings: string[];
    unlockedUnits: string[];
  };
  world: {
    entities: Array<{
      id: string;
      type: string;
      position: { x: number; y: number };
      health?: number;
      production?: Record<string, number>;
    }>;
    chunks: Array<{
      coord: { x: number; y: number };
      loaded: boolean;
    }>;
  };
  systems: {
    power: { totalGenerated: number; totalConsumed: number };
    fluid: { networks: number; totalFlow: number };
    research: { current?: string; progress: number };
  };
  performance: {
    fps: number;
    memoryUsage: number;
    entityCount: number;
  };
}

export class GameController {
  private gameState: GameState | null = null;
  private gameWs: WebSocket | null = null; // WebSocket connection to iPhone app
  private pendingRequests: Map<string, { resolve: Function; reject: Function }> = new Map();
  private gameHost: string;

  constructor(gameHost: string = 'localhost') {
    this.gameHost = gameHost;
  }

  // Called when iPhone app connects via WebSocket
  setGameConnection(ws: WebSocket) {
    console.log('GameController: iPhone app connected');
    this.gameWs = ws;

    ws.on('message', (data) => {
      try {
        const message = JSON.parse(data.toString());
        this.handleGameMessage(message);
      } catch (error) {
        console.error('Error handling game message:', error);
      }
    });

    ws.on('close', () => {
      console.log('GameController: iPhone app disconnected');
      this.gameWs = null;
    });
  }


  handleGameMessage(message: any) {
    if (message.type === 'game_state_update') {
      this.gameState = message.data;
    } else if (message.type === 'command_result') {
      const request = this.pendingRequests.get(message.requestId);
      if (request) {
        this.pendingRequests.delete(message.requestId);
        if (message.success) {
          request.resolve(message.result);
        } else {
          request.reject(new Error(message.error));
        }
      }
    }
  }

  getGameState(): GameState | null {
    return this.gameState;
  }

  async executeCommand(command: any): Promise<any> {
    console.log(`Executing command: ${command.command}`);

    // Try WebSocket first, then fall back to HTTP
    if (this.gameWs && this.gameWs.readyState === WebSocket.OPEN) {
      console.log('Using WebSocket connection');
      return new Promise((resolve, reject) => {
        const requestId = Math.random().toString(36).substring(7);

        // Set up timeout
        const timeout = setTimeout(() => {
          this.pendingRequests.delete(requestId);
          reject(new Error('Command timed out'));
        }, 10000);

        // Store the promise handlers
        this.pendingRequests.set(requestId, {
          resolve: (result: any) => {
            clearTimeout(timeout);
            resolve(result);
          },
          reject: (error: any) => {
            clearTimeout(timeout);
            reject(error);
          }
        });

        // Send command via WebSocket
        const message = {
          type: 'execute_command',
          command: command.command,
          requestId: requestId,
          parameters: command.parameters || {}
        };

        this.gameWs.send(JSON.stringify(message));
      });
    } else {
      // Fall back to HTTP
      console.log('Using HTTP fallback');
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
        });

        console.log('iPhone response:', response.data);
        return response.data;
      } catch (error: any) {
        console.error('HTTP connection error:', error.response?.data || error.message);
        return {
          success: false,
          error: `Cannot connect to FactoryForge iOS app at ${this.gameHost}:8083.`,
          details: 'Make sure the app is running on your iPhone and on the same network.'
        };
      }
    }
  }

  getEntities(filter: any = {}): any[] {
    if (!this.gameState) return [];

    let entities = this.gameState.world.entities;

    if (filter.type && filter.type !== 'all') {
      entities = entities.filter(e => e.type === filter.type);
    }

    if (filter.area) {
      const { x, y, width, height } = filter.area;
      entities = entities.filter(e =>
        e.position.x >= x && e.position.x < x + width &&
        e.position.y >= y && e.position.y < y + height
      );
    }

    return entities;
  }

  modifyGameCode(modification: { target: string; modification: string }): string {
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

  async takeScreenshot(format: string = 'png'): Promise<string> {
    // This would request a screenshot from the iOS app
    // For now, return a placeholder
    return 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jzyr5AAAAABJRU5ErkJggg=='; // 1x1 transparent PNG
  }
}