# Setting Up FactoryForge MCP Server in Cursor

## The Problem

If you see errors like:
- "Server not yet created, returning empty offerings"
- "No server info found"

This means Cursor can't start or connect to the MCP server.

## Solution

### Step 1: Build the MCP Server

```bash
cd /Users/rah/FactoryForge/MCP
npm install
npm run build
```

### Step 2: Configure Cursor MCP Settings

Cursor uses a different configuration format than the `mcp-config.json` file. You need to add the MCP server to Cursor's settings.

**Option A: Via Cursor Settings UI**
1. Open Cursor Settings (Cmd+,)
2. Search for "MCP" or "Model Context Protocol"
3. Add a new MCP server with:
   - **Name**: `factoryforge`
   - **Command**: `node`
   - **Args**: `["/Users/rah/FactoryForge/MCP/dist/index.js"]`
   - **Working Directory**: `/Users/rah/FactoryForge/MCP` (optional)

**Option B: Via Settings JSON**
1. Open Cursor Settings (Cmd+,)
2. Click the "Open Settings (JSON)" icon in the top right
3. Add to your settings:

```json
{
  "mcp.servers": {
    "factoryforge": {
      "command": "node",
      "args": ["/Users/rah/FactoryForge/MCP/dist/index.js"],
      "cwd": "/Users/rah/FactoryForge/MCP"
    }
  }
}
```

### Step 3: Restart Cursor

After adding the configuration, restart Cursor completely to load the MCP server.

### Step 4: Verify Installation

1. Open the MCP panel in Cursor (usually in the sidebar or via Command Palette)
2. You should see `factoryforge` listed as an available server
3. Check that tools like `get_game_state`, `execute_command`, etc. are available

## Troubleshooting

### Server Still Not Working?

1. **Check if the server starts manually:**
   ```bash
   cd /Users/rah/FactoryForge/MCP
   node dist/index.js
   ```
   You should see: "Using game host: localhost" and "FactoryForge MCP server started"
   Press Ctrl+C to stop it.

2. **Check Node.js version:**
   ```bash
   node --version
   ```
   Should be Node.js 18+ (the MCP SDK requires it)

3. **Verify the path is correct:**
   Make sure the path `/Users/rah/FactoryForge/MCP/dist/index.js` exists and is accessible.

4. **Check Cursor logs:**
   - Open Cursor's Developer Tools (Help > Toggle Developer Tools)
   - Look for MCP-related errors in the console

5. **Try absolute path:**
   If relative paths don't work, use the full absolute path in the configuration.

### Common Issues

**"Cannot find module" errors:**
- Run `npm install` in the MCP directory
- Make sure `node_modules` exists

**"Port already in use" errors:**
- This is normal if the server is already running
- The server will continue to work even with this warning

**"Server not yet created" errors:**
- Usually means Cursor can't start the server
- Check that the command and args are correct
- Verify Node.js is in your PATH

## Testing the MCP Server

Once configured, you can test it by asking the AI assistant:

- "Get the current game state"
- "What tools are available from the FactoryForge MCP server?"
- "Execute a command to build something"

The AI should be able to use the MCP tools to interact with your game.
