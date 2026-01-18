# FactoryForge MCP Server

This MCP (Model Context Protocol) server allows AI agents to control and interact with the FactoryForge iOS game while it's running on the simulator or device.

## Setup

1. Install dependencies:
```bash
cd MCP
npm install
```

2. Build the MCP server:
```bash
npm run build
```

## Running the MCP Server

### Automated Setup (Recommended)

Use the automated script to build, launch, and test everything:

```bash
# From the project root
./run-factory-automation.sh
```

This script will:
1. Build the iOS app for your connected device/simulator
2. Launch the FactoryForge app
3. Start the MCP server
4. Run automated factory-building tests

### Manual Setup

Start the MCP server manually:
```bash
npm start
```

Then launch the FactoryForge iOS app separately on your device/simulator.

The server will:
- Start an HTTP server on port 8080 for REST API access
- Start a WebSocket server on port 8081 for real-time communication
- Connect to the FactoryForge iOS app running on port 8082

## iOS App Integration

The FactoryForge iOS app automatically starts a WebSocket server on port 8082 when a game is running. The MCP server connects to this to send commands and receive game state updates.

## Available Tools

### get_game_state
Get the current state of the FactoryForge game including:
- Player resources and research progress
- World entities (buildings, units, resources)
- Loaded chunks and terrain
- System status (power, fluids, research)
- Performance metrics

### execute_command
Execute commands in the game:
- `build`: Place buildings
- `move`: Move units to positions
- `attack`: Order units to attack targets
- `research`: Start technology research
- `pause`/`resume`: Control game time

### get_entities
Query game entities with filtering by type and area.

### modify_game_code
Apply dynamic modifications to game behavior (for testing).

### get_performance_metrics
Retrieve FPS, memory usage, and entity counts.

### take_screenshot
Capture and return game screenshots.

## Example Usage

### Automated Factory Building

The easiest way to see FactoryForge automation in action:

```bash
# From the project root
./run-factory-automation.sh
```

This automated script will:
- Build and launch FactoryForge on your iOS device/simulator
- Start the MCP server
- Demonstrate AI-controlled factory construction
- Build mining drills, furnaces, and transport belts

### Manual API Usage

```typescript
// Get current game state
const state = await mcp.callTool('get_game_state', {});

// Build a mining drill
await mcp.callTool('execute_command', {
  command: 'build',
  parameters: {
    buildingId: 'mining-drill',
    x: 10,
    y: 15
  }
});

// Move a unit
await mcp.callTool('execute_command', {
  command: 'move',
  parameters: {
    unitId: 'unit_123',
    x: 20,
    y: 25
  }
});
```

## Architecture

- **MCP Server**: Node.js/TypeScript server exposing MCP tools
- **HTTP Server**: REST API for game state queries
- **WebSocket Server**: Real-time communication with iOS app
- **iOS GameNetworkManager**: Handles network communication in the game
- **GameController**: Manages game state and command execution

## Network Ports

- **8080**: MCP HTTP server
- **8081**: MCP WebSocket server (for external clients)
- **8082**: iOS app WebSocket server

## Development

For development, you can run the MCP server and connect AI agents directly to control the game. The system supports:

- Real-time game state monitoring
- Command execution with validation
- Dynamic code modification for testing
- Performance monitoring
- Screenshot capture for analysis