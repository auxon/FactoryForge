#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  type Tool,
} from '@modelcontextprotocol/sdk/types.js';
import express from 'express';
import { WebSocketServer } from 'ws';
import { GameController } from './gameController.js';

class FactoryForgeMCPServer {
  private server: Server;
  private gameController: GameController;
  private httpServer: express.Express;
  private wss: WebSocketServer;

  constructor(gameHost?: string) {
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
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        res.status(400).json({ error: errorMessage });
      }
    });

    // WebSocket server for real-time updates
    this.wss = new WebSocketServer({ port: 8081, host: '0.0.0.0' });

    this.wss.on('connection', (ws) => {
      console.log('iOS app connected');
      this.gameController.setGameConnection(ws);
    });

    // Start HTTP server
    this.httpServer.listen(8080, '0.0.0.0', () => {
      console.log('FactoryForge MCP server listening on port 8080 (HTTP) and 8081 (WebSocket) on all interfaces');
    });

    // MCP server setup
    this.server = new Server(
      {
        name: 'factoryforge-mcp',
        version: '1.0.0',
      }
    );

    this.setupToolHandlers();
  }

  private setupToolHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      const tools: Tool[] = [
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
        {
          name: 'spawn_resource',
          description: 'Spawn a resource deposit at a specific location',
          inputSchema: {
            type: 'object',
            properties: {
              resourceType: {
                type: 'string',
                description: 'Type of resource to spawn (coal, iron-ore, copper-ore)',
                default: 'coal',
              },
              x: {
                type: 'number',
                description: 'X coordinate to spawn resource',
              },
              y: {
                type: 'number',
                description: 'Y coordinate to spawn resource',
              },
              amount: {
                type: 'number',
                description: 'Amount of resource to spawn',
                default: 1000,
              },
            },
            required: ['x', 'y'],
          },
        },
        {
          name: 'open_machine_ui',
          description: 'Open the machine UI for a building at the specified coordinates',
          inputSchema: {
            type: 'object',
            properties: {
              x: {
                type: 'number',
                description: 'X coordinate of the building',
              },
              y: {
                type: 'number',
                description: 'Y coordinate of the building',
              },
            },
            required: ['x', 'y'],
          },
        },
        {
          name: 'start_new_game',
          description: 'Start a new FactoryForge game session',
          inputSchema: {
            type: 'object',
            properties: {},
          },
        },
        {
          name: 'save_game',
          description: 'Save the current game to a save slot',
          inputSchema: {
            type: 'object',
            properties: {
              slotName: {
                type: 'string',
                description: 'Name of the save slot (optional, will auto-generate if not provided)',
              },
            },
          },
        },
        {
          name: 'load_game',
          description: 'Load a game from a save slot',
          inputSchema: {
            type: 'object',
            properties: {
              slotName: {
                type: 'string',
                description: 'Name of the save slot to load',
              },
            },
            required: ['slotName'],
          },
        },
        {
          name: 'list_save_slots',
          description: 'List all available save slots with their information',
          inputSchema: {
            type: 'object',
            properties: {},
          },
        },
        {
          name: 'delete_save_slot',
          description: 'Delete a save slot',
          inputSchema: {
            type: 'object',
            properties: {
              slotName: {
                type: 'string',
                description: 'Name of the save slot to delete',
              },
            },
            required: ['slotName'],
          },
        },
        {
          name: 'rename_save_slot',
          description: 'Rename a save slot',
          inputSchema: {
            type: 'object',
            properties: {
              slotName: {
                type: 'string',
                description: 'Current name of the save slot',
              },
              newName: {
                type: 'string',
                description: 'New name for the save slot',
              },
            },
            required: ['slotName', 'newName'],
          },
        },
        {
          name: 'update_machine_ui_config',
          description: 'Update the UI configuration for a machine type at runtime',
          inputSchema: {
            type: 'object',
            properties: {
              machineType: {
                type: 'string',
                description: 'Type of machine to update (assembler, furnace, mining_drill, etc.)',
              },
              config: {
                type: 'object',
                description: 'New UI configuration JSON object',
                properties: {
                  machineType: { type: 'string' },
                  layout: {
                    type: 'object',
                    properties: {
                      panelWidth: { type: 'number' },
                      panelHeight: { type: 'number' },
                      backgroundColor: { type: 'string' },
                      borderWidth: { type: 'number' },
                      cornerRadius: { type: 'number' }
                    }
                  },
                  components: {
                    type: 'array',
                    description: 'Array of UI components',
                    items: {
                      type: 'object',
                      properties: {
                        type: { type: 'string' },
                        position: {
                          type: 'object',
                          properties: {
                            x: { type: 'number' },
                            y: { type: 'number' },
                            width: { type: 'number' },
                            height: { type: 'number' }
                          }
                        },
                        properties: {
                          type: 'object',
                          description: 'Component properties (string, number, or boolean values)'
                        }
                      }
                    }
                  }
                }
              },
            },
            required: ['machineType', 'config'],
          },
        },
        {
          name: 'get_machine_ui_config',
          description: 'Get the current UI configuration for a machine type',
          inputSchema: {
            type: 'object',
            properties: {
              machineType: {
                type: 'string',
                description: 'Type of machine to get config for',
              },
            },
            required: ['machineType'],
          },
        },
        {
          name: 'list_machine_ui_configs',
          description: 'List all available machine UI configurations',
          inputSchema: {
            type: 'object',
            properties: {},
          },
        },
        {
          name: 'get_starting_items_config',
          description: 'Get the current starting items configuration',
          inputSchema: {
            type: 'object',
            properties: {},
          },
        },
        {
          name: 'update_starting_items_config',
          description: 'Update the starting items configuration',
          inputSchema: {
            type: 'object',
            properties: {
              startingItems: {
                type: 'array',
                description: 'Array of starting items',
                items: {
                  type: 'object',
                  properties: {
                    itemId: { type: 'string' },
                    count: { type: 'number' },
                    comment: { type: 'string' }
                  },
                  required: ['itemId', 'count']
                }
              },
            },
            required: ['startingItems'],
          },
        },
        {
          name: 'get_building_config',
          description: 'Get the configuration for a specific building',
          inputSchema: {
            type: 'object',
            properties: {
              buildingId: { type: 'string', description: 'ID of the building to get config for' },
            },
            required: ['buildingId'],
          },
        },
        {
          name: 'update_building_config',
          description: 'Update the configuration for a building at runtime',
          inputSchema: {
            type: 'object',
            properties: {
              buildingId: { type: 'string', description: 'ID of the building to update' },
              config: {
                type: 'object',
                description: 'Building configuration object',
                properties: {
                  name: { type: 'string' },
                  type: { type: 'string' },
                  width: { type: 'number' },
                  height: { type: 'number' },
                  maxHealth: { type: 'number' },
                  cost: {
                    type: 'array',
                    items: {
                      type: 'object',
                      properties: {
                        itemId: { type: 'string' },
                        count: { type: 'number' }
                      },
                      required: ['itemId', 'count']
                    }
                  },
                  miningSpeed: { type: 'number' },
                  powerConsumption: { type: 'number' },
                  powerProduction: { type: 'number' },
                  craftingSpeed: { type: 'number' },
                  craftingCategory: { type: 'string' },
                  beltSpeed: { type: 'number' },
                  inserterSpeed: { type: 'number' },
                  inserterStackSize: { type: 'number' },
                  wireReach: { type: 'number' },
                  supplyArea: { type: 'number' },
                  fuelCategory: { type: 'string' },
                  accumulatorCapacity: { type: 'number' },
                  accumulatorChargeRate: { type: 'number' },
                  researchSpeed: { type: 'number' },
                  turretRange: { type: 'number' },
                  turretDamage: { type: 'number' },
                  turretFireRate: { type: 'number' },
                  inventorySlots: { type: 'number' },
                  fluidCapacity: { type: 'number' },
                  fluidInputType: { type: 'string' },
                  fluidOutputType: { type: 'string' },
                  extractionRate: { type: 'number' },
                  inputSlots: { type: 'number' },
                  outputSlots: { type: 'number' },
                  fuelSlots: { type: 'number' },
                },
                required: ['name', 'type', 'maxHealth', 'cost'],
              },
            },
            required: ['buildingId', 'config'],
          },
        },
        {
          name: 'list_building_configs',
          description: 'List all building configurations',
          inputSchema: { type: 'object', properties: {}, },
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
            const modResult = this.gameController.modifyGameCode(args as { target: string; modification: string });
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

          case 'spawn_resource':
            const spawnResult = this.gameController.executeCommand({
              command: 'spawn_resource',
              parameters: args || {}
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(spawnResult, null, 2) }],
            };

          case 'open_machine_ui':
            const openUIResult = this.gameController.executeCommand({
              command: 'open_machine_ui',
              parameters: args || {}
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(openUIResult, null, 2) }],
            };

          case 'start_new_game':
            const newGameResult = this.gameController.executeCommand({
              command: 'start_new_game',
              parameters: args || {}
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(newGameResult, null, 2) }],
            };

          case 'save_game':
            const saveResult = this.gameController.executeCommand({
              command: 'save_game',
              parameters: args || {}
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(saveResult, null, 2) }],
            };

          case 'load_game':
            const loadResult = this.gameController.executeCommand({
              command: 'load_game',
              parameters: args || {}
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(loadResult, null, 2) }],
            };

          case 'list_save_slots':
            const listResult = this.gameController.executeCommand({
              command: 'list_save_slots',
              parameters: args || {}
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(listResult, null, 2) }],
            };

          case 'delete_save_slot':
            const deleteResult = this.gameController.executeCommand({
              command: 'delete_save_slot',
              parameters: args || {}
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(deleteResult, null, 2) }],
            };

          case 'rename_save_slot':
            const renameResult = this.gameController.executeCommand({
              command: 'rename_save_slot',
              parameters: args || {}
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(renameResult, null, 2) }],
            };

          case 'update_machine_ui_config':
            const updateUIResult = this.gameController.executeCommand({
              command: 'update_machine_ui_config',
              parameters: args || {}
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(updateUIResult, null, 2) }],
            };

          case 'get_machine_ui_config':
            const getUIResult = this.gameController.executeCommand({
              command: 'get_machine_ui_config',
              parameters: args || {}
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(getUIResult, null, 2) }],
            };

          case 'list_machine_ui_configs':
            const listUIResult = this.gameController.executeCommand({
              command: 'list_machine_ui_configs',
              parameters: args || {}
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(listUIResult, null, 2) }],
            };

          case 'get_starting_items_config':
            const getStartingItemsResult = this.gameController.executeCommand({
              command: 'get_starting_items_config',
              parameters: args || {}
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(getStartingItemsResult, null, 2) }],
            };

          case 'update_starting_items_config':
            const updateStartingItemsResult = this.gameController.executeCommand({
              command: 'update_starting_items_config',
              parameters: args || {}
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(updateStartingItemsResult, null, 2) }],
            };

          case 'get_building_config':
            const getBuildingResult = this.gameController.executeCommand({
              command: 'get_building_config',
              parameters: args || {}
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(getBuildingResult, null, 2) }],
            };

          case 'update_building_config':
            const updateBuildingResult = this.gameController.executeCommand({
              command: 'update_building_config',
              parameters: args || {}
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(updateBuildingResult, null, 2) }],
            };

          case 'list_building_configs':
            const listBuildingsResult = this.gameController.executeCommand({
              command: 'list_building_configs',
              parameters: args || {}
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(listBuildingsResult, null, 2) }],
            };

          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
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