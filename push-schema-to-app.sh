#!/bin/bash

# Push MachineUI schema directly to running app without rebuilding
# This allows instant iteration on UI layouts

set -e

MCP_SERVER_URL="${MCP_SERVER_URL:-http://localhost:8080}"
SCHEMA_DIR="${SCHEMA_DIR:-FactoryForge/Assets}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo "Usage: $0 <machine_type>"
    echo "Example: $0 furnace"
    exit 1
fi

MACHINE_TYPE=$1
SCHEMA_FILE="$SCHEMA_DIR/${MACHINE_TYPE}_schema.json"

if [ ! -f "$SCHEMA_FILE" ]; then
    echo -e "${RED}Error: Schema file not found: $SCHEMA_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}Pushing schema for $MACHINE_TYPE to running app...${NC}"

# Read and validate JSON
if ! jq . "$SCHEMA_FILE" > /dev/null 2>&1; then
    echo -e "${RED}Error: Invalid JSON in schema file${NC}"
    exit 1
fi

# Read schema JSON
SCHEMA_JSON=$(cat "$SCHEMA_FILE")

# Push to app via update_machine_ui_config
RESPONSE=$(curl -s -X POST "$MCP_SERVER_URL/command" \
    -H "Content-Type: application/json" \
    -d "{
        \"command\": \"update_machine_ui_config\",
        \"requestId\": \"push-$(date +%s)\",
        \"parameters\": {
            \"machineType\": \"$MACHINE_TYPE\",
            \"config\": $SCHEMA_JSON
        }
    }")

# Check response
if echo "$RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Schema pushed successfully!${NC}"
    echo "$RESPONSE" | jq -r '.message // "Schema applied"'
    
    # Optionally test it
    if [ "$2" != "--no-test" ]; then
        echo ""
        echo -e "${BLUE}Testing pushed schema...${NC}"
        ./test-machine-ui-schema.sh test "$MACHINE_TYPE"
    fi
else
    echo -e "${RED}✗ Failed to push schema${NC}"
    echo "$RESPONSE" | jq -r '.error // .' 2>/dev/null || echo "$RESPONSE"
    exit 1
fi
