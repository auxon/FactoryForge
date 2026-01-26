#!/bin/bash

# LLM-driven iterative schema development
# Push schema -> Test -> Generate feedback -> LLM fixes -> Repeat

set -e

MACHINE_TYPE="${1:-furnace}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${MAGENTA}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  LLM-Driven MachineUI Schema Iteration              ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Push current schema
echo -e "${BLUE}[1/4] Pushing schema to app...${NC}"
if ! ./push-schema-to-app.sh "$MACHINE_TYPE" --no-test 2>&1 | grep -q "successfully"; then
    echo -e "${RED}Failed to push schema${NC}"
    exit 1
fi

# Step 2: Test schema
echo ""
echo -e "${BLUE}[2/4] Testing schema...${NC}"
TEST_OUTPUT=$(./test-machine-ui-schema.sh test "$MACHINE_TYPE" 2>&1)
echo "$TEST_OUTPUT"

# Check if test passed
if echo "$TEST_OUTPUT" | grep -q "✓ Schema test passed"; then
    echo ""
    echo -e "${GREEN}✅ Schema is valid!${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo -e "  • Edit FactoryForge/Assets/${MACHINE_TYPE}_schema.json"
    echo -e "  • Run: ${YELLOW}./push-schema-to-app.sh $MACHINE_TYPE${NC}"
    echo -e "  • Or use: ${YELLOW}./iterative-schema-dev.sh $MACHINE_TYPE${NC}"
    exit 0
fi

# Step 3: Generate LLM feedback
echo ""
echo -e "${BLUE}[3/4] Generating LLM feedback...${NC}"
python3 automate-machine-ui-fixes.py fix "$MACHINE_TYPE" 2>&1 | tail -20

# Step 4: Show feedback summary
echo ""
echo -e "${BLUE}[4/4] Feedback Summary${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

FEEDBACK_FILE=".machine-ui-test-results/${MACHINE_TYPE}_feedback.md"
if [ -f "$FEEDBACK_FILE" ]; then
    echo ""
    echo -e "${YELLOW}Errors found:${NC}"
    grep -A 5 "### Errors" "$FEEDBACK_FILE" | grep -v "^###" | sed 's/^/  /' || echo "  None"
    
    echo ""
    echo -e "${YELLOW}Warnings:${NC}"
    grep -A 5 "### Warnings" "$FEEDBACK_FILE" | grep -v "^###" | sed 's/^/  /' || echo "  None"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${MAGENTA}LLM Fix Prompt:${NC}"
echo -e "  ${CYAN}.machine-ui-test-results/${MACHINE_TYPE}_fix_prompt.md${NC}"
echo ""
echo -e "${YELLOW}After LLM fixes the schema, run:${NC}"
echo -e "  ${GREEN}./llm-iterate-schema.sh $MACHINE_TYPE${NC}"
echo ""
