#!/bin/bash

echo "🚀 Starting FactoryForge Debug MCP Server..."
echo "This server provides LLDB debugging control tools"
echo ""

cd "$(dirname "$0")/DebugMCP"

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Build if needed
if [ ! -f "dist/index.js" ]; then
    echo "🔨 Building TypeScript..."
    npm run build
fi

echo "🎯 Starting MCP server..."
echo "Available tools:"
echo "  - attach_to_process: Attach LLDB to a running process"
echo "  - set_breakpoint: Set breakpoints in code"
echo "  - continue_execution: Continue from breakpoint"
echo "  - step_over/step_into/step_out: Step through code"
echo "  - inspect_variable: Examine variable values"
echo "  - get_stack_trace: Get current stack trace"
echo "  - run_lldb_command: Execute raw LLDB commands"
echo ""

npm start