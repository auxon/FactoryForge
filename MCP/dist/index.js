#!/usr/bin/env node
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema, } from '@modelcontextprotocol/sdk/types.js';
import express from 'express';
import { WebSocketServer } from 'ws';
import { GameController } from './gameController.js';
class FactoryForgeMCPServer {
    server;
    gameController;
    httpServer;
    wss;
    constructor(gameHost) {
        this.gameController = new GameController(gameHost);
        // Set up HTTP server for communication with iOS app
        this.httpServer = express();
        this.httpServer.use(express.json());
        // Game state endpoint
        this.httpServer.get('/game-state', (req, res) => {
            res.json(this.gameController.getGameState());
        });
        // Command endpoint
        this.httpServer.post('/command', async (req, res) => {
            try {
                const result = await this.gameController.executeCommand(req.body);
                res.json(result);
            }
            catch (error) {
                const errorMessage = error instanceof Error ? error.message : String(error);
                res.status(400).json({ error: errorMessage });
            }
        });
        // WebSocket server for real-time updates
        this.wss = new WebSocketServer({ port: 8081, host: '0.0.0.0' });
        this.wss.on('connection', (ws) => {
            console.log('iOS app connected');
            ws.on('message', (data) => {
                try {
                    const message = JSON.parse(data.toString());
                    this.gameController.handleGameMessage(message);
                }
                catch (error) {
                    console.error('Error handling game message:', error);
                }
            });
            ws.on('close', () => {
                console.log('iOS app disconnected');
            });
        });
        // Start HTTP server
        this.httpServer.listen(8080, '0.0.0.0', () => {
            console.log('FactoryForge MCP server listening on port 8080 (HTTP) and 8081 (WebSocket) on all interfaces');
        });
        // MCP server setup
        this.server = new Server({
            name: 'factoryforge-mcp',
            version: '1.0.0',
        });
        this.setupToolHandlers();
    }
    setupToolHandlers() {
        // List available tools
        this.server.setRequestHandler(ListToolsRequestSchema, async () => {
            const tools = [
                {
                    name: 'get_game_state',
                    description: 'Get the current state of the FactoryForge game',
                    inputSchema: {
                        type: 'object',
                        properties: {},
                    },
                },
                {
                    name: 'execute_command',
                    description: 'Execute a command in the game (build, move units, etc.)',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            command: {
                                type: 'string',
                                description: 'The command to execute',
                                enum: ['build', 'move', 'attack', 'research', 'pause', 'resume', 'mine'],
                            },
                            parameters: {
                                type: 'object',
                                description: 'Parameters for the command',
                            },
                        },
                        required: ['command'],
                    },
                },
                {
                    name: 'get_entities',
                    description: 'Get information about game entities (buildings, units, etc.)',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            type: {
                                type: 'string',
                                description: 'Filter by entity type',
                                enum: ['building', 'unit', 'resource', 'all'],
                            },
                            area: {
                                type: 'object',
                                description: 'Area to search (optional)',
                                properties: {
                                    x: { type: 'number' },
                                    y: { type: 'number' },
                                    width: { type: 'number' },
                                    height: { type: 'number' },
                                },
                            },
                        },
                    },
                },
                {
                    name: 'modify_game_code',
                    description: 'Dynamically modify game behavior (for testing)',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            target: {
                                type: 'string',
                                description: 'What to modify',
                                enum: ['unit_ai', 'building_logic', 'resource_generation', 'combat_system'],
                            },
                            modification: {
                                type: 'string',
                                description: 'The modification to apply',
                            },
                        },
                        required: ['target', 'modification'],
                    },
                },
                {
                    name: 'get_performance_metrics',
                    description: 'Get game performance metrics (FPS, memory, etc.)',
                    inputSchema: {
                        type: 'object',
                        properties: {},
                    },
                },
                {
                    name: 'take_screenshot',
                    description: 'Take a screenshot of the current game state',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            format: {
                                type: 'string',
                                enum: ['png', 'jpg'],
                                default: 'png',
                            },
                        },
                    },
                },
                {
                    name: 'mine',
                    description: 'Manually mine a resource at the player\'s current location',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            resourceType: {
                                type: 'string',
                                description: 'Type of resource to mine (coal, iron-ore, etc.)',
                                default: 'coal',
                            },
                        },
                    },
                },
                {
                    name: 'auto_mine',
                    description: 'Automatically mine all resources within a radius around the player',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            radius: {
                                type: 'number',
                                description: 'Radius in tiles to mine around the player',
                                default: 2,
                            },
                            maxResources: {
                                type: 'number',
                                description: 'Maximum number of resources to mine',
                                default: 100,
                            },
                        },
                    },
                },
            ];
            return { tools };
        });
        // Handle tool calls
        this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
            const { name, arguments: args } = request.params;
            try {
                switch (name) {
                    case 'get_game_state':
                        return {
                            content: [{ type: 'text', text: JSON.stringify(this.gameController.getGameState(), null, 2) }],
                        };
                    case 'execute_command':
                        const result = this.gameController.executeCommand(args);
                        return {
                            content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
                        };
                    case 'get_entities':
                        const entities = this.gameController.getEntities(args);
                        return {
                            content: [{ type: 'text', text: JSON.stringify(entities, null, 2) }],
                        };
                    case 'modify_game_code':
                        if (!args || typeof args.target !== 'string' || typeof args.modification !== 'string') {
                            throw new Error('Invalid arguments for modify_game_code');
                        }
                        const modResult = this.gameController.modifyGameCode(args);
                        return {
                            content: [{ type: 'text', text: modResult }],
                        };
                    case 'get_performance_metrics':
                        const metrics = this.gameController.getPerformanceMetrics();
                        return {
                            content: [{ type: 'text', text: JSON.stringify(metrics, null, 2) }],
                        };
                    case 'take_screenshot':
                        const format = (typeof args?.format === 'string' && args.format) || 'png';
                        const screenshot = await this.gameController.takeScreenshot(format);
                        return {
                            content: [
                                { type: 'text', text: 'Screenshot captured' },
                                { type: 'image', data: screenshot, mimeType: `image/${format}` },
                            ],
                        };
                    case 'mine':
                        const mineResult = this.gameController.executeCommand({
                            command: 'mine',
                            parameters: args || {}
                        });
                        return {
                            content: [{ type: 'text', text: JSON.stringify(mineResult, null, 2) }],
                        };
                    case 'auto_mine':
                        const autoMineResult = this.gameController.executeCommand({
                            command: 'auto_mine',
                            parameters: args || {}
                        });
                        return {
                            content: [{ type: 'text', text: JSON.stringify(autoMineResult, null, 2) }],
                        };
                    default:
                        throw new Error(`Unknown tool: ${name}`);
                }
            }
            catch (error) {
                const errorMessage = error instanceof Error ? error.message : String(error);
                return {
                    content: [{ type: 'text', text: `Error: ${errorMessage}` }],
                    isError: true,
                };
            }
        });
    }
    async start() {
        const transport = new StdioServerTransport();
        await this.server.connect(transport);
        console.log('FactoryForge MCP server started');
    }
}
// Start the server
const gameHost = process.argv[2] || process.env.FACTORYFORGE_GAME_HOST || 'localhost';
console.log(`Using game host: ${gameHost}`);
const server = new FactoryForgeMCPServer(gameHost);
server.start().catch(console.error);
