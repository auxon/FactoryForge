#!/bin/bash

# Iterative schema development workflow
# Edit schema -> Push -> Test -> Get feedback -> Repeat

set -e

MACHINE_TYPE="${1:-furnace}"
SCHEMA_FILE="FactoryForge/Assets/${MACHINE_TYPE}_schema.json"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Iterative MachineUI Schema Development        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Check if schema file exists
if [ ! -f "$SCHEMA_FILE" ]; then
    echo -e "${RED}Error: Schema file not found: $SCHEMA_FILE${NC}"
    exit 1
fi

# Function to push and test
push_and_test() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Step 1: Pushing schema to app...${NC}"
    
    if ./push-schema-to-app.sh "$MACHINE_TYPE" --no-test; then
        echo ""
        echo -e "${BLUE}Step 2: Testing schema...${NC}"
        ./test-machine-ui-schema.sh test "$MACHINE_TYPE"
        
        echo ""
        echo -e "${BLUE}Step 3: Getting UI state...${NC}"
        curl -s http://localhost:8080/command -X POST -H "Content-Type: application/json" \
            -d "{\"command\": \"get_machine_ui_state\", \"requestId\": \"state-check\", \"parameters\": {}}" \
            | jq -r 'if .isOpen then "✅ Machine UI is open" else "⚠️  Machine UI is not open" end'
        
        echo ""
        echo -e "${GREEN}✓ Iteration complete!${NC}"
        echo -e "${CYAN}Edit $SCHEMA_FILE and run this script again to see changes.${NC}"
    else
        echo -e "${RED}✗ Push failed${NC}"
        return 1
    fi
}

# Initial push and test
push_and_test

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Workflow:${NC}"
echo -e "  1. Edit: ${CYAN}$SCHEMA_FILE${NC}"
echo -e "  2. Run: ${CYAN}./iterative-schema-dev.sh $MACHINE_TYPE${NC}"
echo -e "  3. See changes instantly in the app!"
echo ""
echo -e "${YELLOW}Or use watch mode:${NC}"
echo -e "  ${CYAN}watch -n 2 './push-schema-to-app.sh $MACHINE_TYPE --no-test'${NC}"
echo ""
