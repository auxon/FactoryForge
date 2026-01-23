# FactoryForge Debugging System

This document explains how to use the comprehensive debugging system for controlling Xcode debugging and getting debugger output from the FactoryForge iOS app.

## Overview

The FactoryForge debugging system consists of:

1. **In-App Debug Logging** - Built-in logging system that collects debug messages from the running iOS app
2. **LLDB Debugging Control** - Full control over LLDB debugger with breakpoints, stepping, and variable inspection
3. **MCP Integration** - Model Context Protocol servers that provide debugging tools

## Quick Start

### 1. Start the Main MCP Server

```bash
cd MCP
npm start
```

### 2. Start the Debug MCP Server

```bash
./start-debug-mcp.sh
```

Or use the MCP tool:
```javascript
// In MCP client
start_debug_server()
```

### 3. Check Debug Setup

```javascript
check_debug_setup()
```

This will show:
- ✅ LLDB availability
- ✅ Debug MCP server status
- ✅ FactoryForge process status

### 4. Attach to FactoryForge Process

```bash
./attach-factoryforge-debug.sh
```

Or manually:
```javascript
// Find the process
find_process({ processName: "FactoryForge" })

// Attach debugger
attach_to_process({ processId: 12345 }) // Use PID from find_process result
```

## Available Debugging Tools

### In-App Debug Logging

These tools work with the built-in logging system:

- **`get_debug_logs()`** - Get current debug logs from the running app
- **`monitor-debug.sh`** - Continuous monitoring script

### LLDB Debugging Control

These tools provide full debugger control:

- **`attach_to_process(processId?, processName?)`** - Attach LLDB to a running process
- **`set_breakpoint(file?, line?, symbol?, condition?)`** - Set breakpoints
- **`continue_execution()`** - Continue from breakpoint
- **`step_over()`** - Step over current line
- **`step_into()`** - Step into function calls
- **`step_out()`** - Step out of current function
- **`inspect_variable(expression)`** - Evaluate variables/expressions
- **`get_stack_trace()`** - Get current call stack
- **`list_breakpoints()`** - List all breakpoints
- **`delete_breakpoint(breakpointId)`** - Remove breakpoint
- **`run_lldb_command(command)`** - Execute raw LLDB commands
- **`get_debug_status()`** - Get current debugging state

### Setup and Utility Tools

- **`start_debug_server()`** - Start the LLDB debugging MCP server
- **`find_process(processName)`** - Find running processes by name
- **`check_debug_setup()`** - Verify debugging environment

## Usage Examples

### Setting a Breakpoint and Debugging

```javascript
// 1. Attach to FactoryForge
const result = attach_to_process({ processName: "FactoryForge" });
console.log(result);

// 2. Set a breakpoint in GameViewController.swift
const bpResult = set_breakpoint({
  file: "FactoryForge/GameViewController.swift",
  line: 100
});
console.log("Breakpoint set:", bpResult.breakpointId);

// 3. Continue execution (app will hit breakpoint)
continue_execution();

// 4. When breakpoint is hit, inspect variables
const gameState = inspect_variable("gameState");
console.log("Game state:", gameState);

// 5. Get stack trace
const stack = get_stack_trace();
console.log("Stack trace:", stack.frames);

// 6. Step through code
step_into(); // or step_over(), step_out()
```

### Monitoring Debug Logs

```javascript
// Get current logs
const logs = get_debug_logs();
console.log("Debug logs:", logs.logs);

// Or use the monitoring script
./monitor-debug.sh
```

### Advanced LLDB Commands

```javascript
// Execute raw LLDB commands
run_lldb_command("frame variable"); // Show local variables
run_lldb_command("thread list"); // Show threads
run_lldb_command("memory read 0x1000"); // Read memory
```

## Architecture

```
┌─────────────────┐    HTTP/WebSocket    ┌──────────────────┐
│   iOS App       │◄────────────────────┤   Main MCP        │
│  (FactoryForge) │                     │   Server          │
│                 │                     │                   │
│ • In-app logs   │                     │ • Game control    │
│ • Network API   │                     │ • Debug logs      │
└─────────────────┘                     │ • Setup tools     │
                                        └──────────────────┘
                                               │
                                               │ MCP Protocol
                                               ▼
┌─────────────────┐    LLDB Commands     ┌──────────────────┐
│   LLDB Process  │◄────────────────────┤   Debug MCP       │
│                 │                     │   Server          │
│ • Breakpoints   │                     │                   │
│ • Stepping      │                     │ • Full debugger   │
│ • Variables     │                     │ • LLDB control    │
│ • Stack traces  │                     │ • Raw commands    │
└─────────────────┘                     └──────────────────┘
```

## Files and Scripts

- **`DebugMCP/`** - LLDB debugging MCP server
- **`start-debug-mcp.sh`** - Start debugging MCP server
- **`attach-factoryforge-debug.sh`** - Attach to FactoryForge process
- **`monitor-debug.sh`** - Monitor in-app debug logs
- **`MCP/src/index.ts`** - Main MCP server with debug tools
- **`FactoryForge/Engine/Network/GameNetworkManager.swift`** - In-app logging

## Troubleshooting

### Common Issues

1. **"Process not found"**
   - Ensure FactoryForge is running in Simulator
   - Check process name with `ps aux | grep FactoryForge`

2. **"LLDB attachment failed"**
   - Verify LLDB is installed: `which lldb`
   - Check process permissions
   - Try running with sudo if needed

3. **"Debug server not responding"**
   - Check if debug MCP server is running: `pgrep -f factoryforge-debug-mcp`
   - Restart with `./start-debug-mcp.sh`

4. **"No debug logs"**
   - Ensure app is running and connected to MCP server
   - Check network connectivity (ports 8080, 8083, 8081)

### Debug Commands

```bash
# Check all processes
ps aux | grep -E "(FactoryForge|lldb|MCP)"

# Check network connections
lsof -i :8080,8081,8083

# View LLDB output
tail -f DebugMCP/debug.log

# Kill debug processes
pkill -f "factoryforge-debug-mcp"
pkill -f "lldb"
```

## Integration with Existing Systems

The debugging system integrates with:

- **Existing MCP server** - Adds debug tools alongside game control
- **In-app logging** - Complements LLDB with application-level logs
- **Game network manager** - Uses existing command infrastructure
- **Monitor scripts** - Provides continuous log monitoring

This gives you multiple levels of debugging:
- **Application logs** - High-level game events and state
- **LLDB debugging** - Low-level code inspection and control
- **Network monitoring** - Communication between components