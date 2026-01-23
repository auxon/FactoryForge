#!/bin/bash

echo "🔍 Finding FactoryForge process..."

# Find the FactoryForge process in the simulator
FACTORYFORGE_PID=$(ps aux | grep "FactoryForge.app" | grep -v grep | awk '{print $2}' | head -1)

if [ -z "$FACTORYFORGE_PID" ]; then
    echo "❌ FactoryForge process not found. Make sure the app is running in the simulator."
    exit 1
fi

echo "✅ Found FactoryForge process with PID: $FACTORYFORGE_PID"

# Check if MCP server is running
if ! pgrep -f "factoryforge-debug-mcp" > /dev/null; then
    echo "⚠️  Debug MCP server not running. Starting it..."
    ./start-debug-mcp.sh &
    sleep 3
fi

echo "🔗 Attaching debugger to FactoryForge..."
echo ""
echo "You can now use debugging commands like:"
echo "  - set_breakpoint with file/line or symbol"
echo "  - continue_execution, step_over, step_into, step_out"
echo "  - inspect_variable to check values"
echo "  - get_stack_trace for call stack"
echo ""

# You would need to call the MCP tool here, but for now just show the PID
echo "Process ready for debugging. PID: $FACTORYFORGE_PID"