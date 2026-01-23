#!/usr/bin/env node
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema, } from '@modelcontextprotocol/sdk/types.js';
import { XcodeDebugger } from './xcodeDebugger.js';
class FactoryForgeDebugMCPServer {
    server;
    debugger;
    constructor() {
        this.debugger = new XcodeDebugger();
        this.server = new Server({
            name: 'factoryforge-debug-mcp',
            version: '1.0.0',
        });
        this.setupToolHandlers();
    }
    setupToolHandlers() {
        this.server.setRequestHandler(ListToolsRequestSchema, async () => {
            return {
                tools: [
                    {
                        name: 'attach_to_process',
                        description: 'Attach LLDB debugger to a running process by PID or name',
                        inputSchema: {
                            type: 'object',
                            properties: {
                                processId: {
                                    type: 'number',
                                    description: 'Process ID to attach to',
                                },
                                processName: {
                                    type: 'string',
                                    description: 'Process name to attach to (alternative to PID)',
                                },
                            },
                            oneOf: [
                                { required: ['processId'] },
                                { required: ['processName'] }
                            ],
                        },
                    },
                    {
                        name: 'set_breakpoint',
                        description: 'Set a breakpoint at a specific file and line, or by symbol name',
                        inputSchema: {
                            type: 'object',
                            properties: {
                                file: {
                                    type: 'string',
                                    description: 'Source file path for the breakpoint',
                                },
                                line: {
                                    type: 'number',
                                    description: 'Line number for the breakpoint',
                                },
                                symbol: {
                                    type: 'string',
                                    description: 'Symbol/function name for the breakpoint',
                                },
                                condition: {
                                    type: 'string',
                                    description: 'Optional condition for the breakpoint',
                                },
                            },
                            oneOf: [
                                { required: ['file', 'line'] },
                                { required: ['symbol'] }
                            ],
                        },
                    },
                    {
                        name: 'continue_execution',
                        description: 'Continue execution from current breakpoint',
                        inputSchema: {
                            type: 'object',
                            properties: {},
                        },
                    },
                    {
                        name: 'step_over',
                        description: 'Step over the current line (execute and stop at next line)',
                        inputSchema: {
                            type: 'object',
                            properties: {},
                        },
                    },
                    {
                        name: 'step_into',
                        description: 'Step into function calls on the current line',
                        inputSchema: {
                            type: 'object',
                            properties: {},
                        },
                    },
                    {
                        name: 'step_out',
                        description: 'Step out of the current function',
                        inputSchema: {
                            type: 'object',
                            properties: {},
                        },
                    },
                    {
                        name: 'inspect_variable',
                        description: 'Inspect the value of a variable or expression',
                        inputSchema: {
                            type: 'object',
                            properties: {
                                expression: {
                                    type: 'string',
                                    description: 'Variable name or expression to evaluate',
                                },
                            },
                            required: ['expression'],
                        },
                    },
                    {
                        name: 'get_stack_trace',
                        description: 'Get the current stack trace',
                        inputSchema: {
                            type: 'object',
                            properties: {},
                        },
                    },
                    {
                        name: 'list_breakpoints',
                        description: 'List all current breakpoints',
                        inputSchema: {
                            type: 'object',
                            properties: {},
                        },
                    },
                    {
                        name: 'delete_breakpoint',
                        description: 'Delete a breakpoint by ID',
                        inputSchema: {
                            type: 'object',
                            properties: {
                                breakpointId: {
                                    type: 'number',
                                    description: 'ID of the breakpoint to delete',
                                },
                            },
                            required: ['breakpointId'],
                        },
                    },
                    {
                        name: 'run_lldb_command',
                        description: 'Execute a raw LLDB command',
                        inputSchema: {
                            type: 'object',
                            properties: {
                                command: {
                                    type: 'string',
                                    description: 'Raw LLDB command to execute',
                                },
                            },
                            required: ['command'],
                        },
                    },
                    {
                        name: 'get_debug_status',
                        description: 'Get current debugging status and information',
                        inputSchema: {
                            type: 'object',
                            properties: {},
                        },
                    },
                ],
            };
        });
        this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
            const { name, arguments: args = {} } = request.params;
            try {
                switch (name) {
                    case 'attach_to_process':
                        const attachResult = await this.debugger.attachToProcess(args.processId, args.processName);
                        return {
                            content: [{ type: 'text', text: JSON.stringify(attachResult, null, 2) }],
                        };
                    case 'set_breakpoint':
                        const breakpointResult = await this.debugger.setBreakpoint(args.file, args.line, args.symbol, args.condition);
                        return {
                            content: [{ type: 'text', text: JSON.stringify(breakpointResult, null, 2) }],
                        };
                    case 'continue_execution':
                        const continueResult = await this.debugger.continueExecution();
                        return {
                            content: [{ type: 'text', text: JSON.stringify(continueResult, null, 2) }],
                        };
                    case 'step_over':
                        const stepOverResult = await this.debugger.stepOver();
                        return {
                            content: [{ type: 'text', text: JSON.stringify(stepOverResult, null, 2) }],
                        };
                    case 'step_into':
                        const stepIntoResult = await this.debugger.stepInto();
                        return {
                            content: [{ type: 'text', text: JSON.stringify(stepIntoResult, null, 2) }],
                        };
                    case 'step_out':
                        const stepOutResult = await this.debugger.stepOut();
                        return {
                            content: [{ type: 'text', text: JSON.stringify(stepOutResult, null, 2) }],
                        };
                    case 'inspect_variable':
                        const inspectResult = await this.debugger.inspectVariable(args.expression);
                        return {
                            content: [{ type: 'text', text: JSON.stringify(inspectResult, null, 2) }],
                        };
                    case 'get_stack_trace':
                        const stackTrace = await this.debugger.getStackTrace();
                        return {
                            content: [{ type: 'text', text: JSON.stringify(stackTrace, null, 2) }],
                        };
                    case 'list_breakpoints':
                        const breakpoints = await this.debugger.listBreakpoints();
                        return {
                            content: [{ type: 'text', text: JSON.stringify(breakpoints, null, 2) }],
                        };
                    case 'delete_breakpoint':
                        const deleteResult = await this.debugger.deleteBreakpoint(args.breakpointId);
                        return {
                            content: [{ type: 'text', text: JSON.stringify(deleteResult, null, 2) }],
                        };
                    case 'run_lldb_command':
                        const commandResult = await this.debugger.runLLDBCommand(args.command);
                        return {
                            content: [{ type: 'text', text: JSON.stringify(commandResult, null, 2) }],
                        };
                    case 'get_debug_status':
                        const status = await this.debugger.getDebugStatus();
                        return {
                            content: [{ type: 'text', text: JSON.stringify(status, null, 2) }],
                        };
                    default:
                        throw new Error(`Unknown tool: ${name}`);
                }
            }
            catch (error) {
                const errorMessage = error instanceof Error ? error.message : String(error);
                return {
                    content: [{ type: 'text', text: JSON.stringify({ error: errorMessage }, null, 2) }],
                    isError: true,
                };
            }
        });
    }
    async start() {
        const transport = new StdioServerTransport();
        await this.server.connect(transport);
        console.error('FactoryForge Debug MCP Server started');
    }
}
// Start the server
const server = new FactoryForgeDebugMCPServer();
server.start().catch(console.error);
