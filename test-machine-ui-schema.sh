#!/bin/bash

# Automated MachineUI Schema Testing and Feedback Script
# This script tests MachineUI schemas and generates feedback reports for LLM consumption

set -e

MCP_SERVER_URL="${MCP_SERVER_URL:-http://localhost:8080}"
SCHEMA_DIR="${SCHEMA_DIR:-FactoryForge/Assets}"
OUTPUT_DIR="${OUTPUT_DIR:-.machine-ui-test-results}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to send command to MCP server
send_command() {
    local command=$1
    local params=$2
    local response=$(curl -s -X POST "$MCP_SERVER_URL/command" \
        -H "Content-Type: application/json" \
        -d "{\"command\": \"$command\", \"requestId\": \"test-$(date +%s)\", \"parameters\": $params}" 2>&1)
    
    # Check if curl failed
    if [ $? -ne 0 ] || [ -z "$response" ]; then
        echo "{\"error\": \"Failed to connect to MCP server at $MCP_SERVER_URL\", \"success\": false}" >&2
        echo "{\"error\": \"Failed to connect to MCP server\", \"success\": false}"
        return 1
    fi
    
    # Try to parse as JSON, if it fails return error
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        echo "{\"error\": \"Invalid JSON response from server\", \"response\": $(echo "$response" | jq -R .), \"success\": false}"
        return 1
    fi
    
    echo "$response"
}

# Function to test a schema
test_schema() {
    local machine_type=$1
    echo -e "${BLUE}Testing schema for: $machine_type${NC}"
    
    # Test the schema
    local result=$(send_command "test_machine_ui_schema" "{\"machineType\": \"$machine_type\"}")
    
    # Save raw result
    echo "$result" > "$OUTPUT_DIR/${machine_type}_test_raw.json"
    
    # Check if result is empty or invalid
    if [ -z "$result" ] || ! echo "$result" | jq . >/dev/null 2>&1; then
        echo -e "${RED}✗ Failed to test schema for $machine_type${NC}"
        echo -e "${RED}Error: Invalid or empty response from server${NC}"
        echo "$result" > "$OUTPUT_DIR/${machine_type}_test_raw.json"
        return 1
    fi
    
    # Parse result
    local success=$(echo "$result" | jq -r '.success // false' 2>/dev/null || echo "false")
    local errors=$(echo "$result" | jq -r '.errors // []' 2>/dev/null || echo "[]")
    local warnings=$(echo "$result" | jq -r '.warnings // []' 2>/dev/null || echo "[]")
    local validation_passed=$(echo "$result" | jq -r '.validationPassed // false' 2>/dev/null || echo "false")
    
    # Check for connection errors
    if echo "$result" | jq -e '.error' >/dev/null 2>&1; then
        local error_msg=$(echo "$result" | jq -r '.error')
        echo -e "${RED}✗ Schema test failed for $machine_type${NC}"
        echo -e "${RED}Error: $error_msg${NC}"
        echo -e "${YELLOW}Make sure the MCP server is running at $MCP_SERVER_URL${NC}"
        return 1
    fi
    
    if [ "$success" = "true" ]; then
        echo -e "${GREEN}✓ Schema test passed for $machine_type${NC}"
    else
        echo -e "${RED}✗ Schema test failed for $machine_type${NC}"
        local error_count=$(echo "$errors" | jq 'length' 2>/dev/null || echo "0")
        if [ "$error_count" -gt 0 ]; then
            echo -e "${RED}Errors:${NC}"
            echo "$errors" | jq -r '.[]' 2>/dev/null | sed 's/^/  - /' || echo "  - (Unable to parse errors)"
        fi
    fi
    
    local warning_count=$(echo "$warnings" | jq 'length' 2>/dev/null || echo "0")
    if [ "$warning_count" -gt 0 ] 2>/dev/null; then
        echo -e "${YELLOW}Warnings:${NC}"
        echo "$warnings" | jq -r '.[]' 2>/dev/null | sed 's/^/  - /' || echo "  - (Unable to parse warnings)"
    fi
    
    # Generate feedback report
    generate_feedback_report "$machine_type" "$result"
    
    return $([ "$success" = "true" ] && echo 0 || echo 1)
}

# Function to generate feedback report for LLM
generate_feedback_report() {
    local machine_type=$1
    local test_result=$2
    
    local report_file="$OUTPUT_DIR/${machine_type}_feedback.md"
    
    cat > "$report_file" <<EOF
# MachineUI Schema Test Feedback: $machine_type

## Test Results

**Timestamp:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Machine Type:** $machine_type

### Status
- **Success:** $(echo "$test_result" | jq -r '.success // false')
- **Schema Found:** $(echo "$test_result" | jq -r '.schemaFound // false')
- **Validation Passed:** $(echo "$test_result" | jq -r '.validationPassed // false')

### Schema Information
- **Version:** $(echo "$test_result" | jq -r '.schemaVersion // "unknown"')
- **Title:** $(echo "$test_result" | jq -r '.schemaTitle // "unknown"')
- **Group Count:** $(echo "$test_result" | jq -r '.groupCount // 0')

### Errors
$(echo "$test_result" | jq -r '.errors // [] | if length > 0 then "```\n" + (.[] | tostring) + "\n```" else "No errors" end')

### Warnings
$(echo "$test_result" | jq -r '.warnings // [] | if length > 0 then "```\n" + (.[] | tostring) + "\n```" else "No warnings" end')

### Validation Results
$(echo "$test_result" | jq -r '.validationResults // [] | if length > 0 then "```\n" + (.[] | tostring) + "\n```" else "No validation results" end')

## Recommended Actions

$(if [ "$(echo "$test_result" | jq -r '.success // false')" = "true" ]; then
    echo "- ✅ Schema is valid and ready for deployment"
else
    echo "- ❌ Fix the following issues:"
    echo "$test_result" | jq -r '.errors // [] | .[] | "- " + .'
    echo ""
    echo "- Review the schema file: \`$SCHEMA_DIR/${machine_type}_schema.json\`"
fi)

## Schema File Location
\`$SCHEMA_DIR/${machine_type}_schema.json\`

---
*This report was generated automatically by the MachineUI schema testing system.*
EOF

    echo -e "${GREEN}Feedback report saved to: $report_file${NC}"
}

# Function to get current MachineUI state
get_ui_state() {
    echo -e "${BLUE}Getting current MachineUI state...${NC}"
    local result=$(send_command "get_machine_ui_state" "{}")
    echo "$result" > "$OUTPUT_DIR/ui_state.json"
    echo "$result" | jq '.'
}

# Function to reload and test a schema
reload_and_test() {
    local machine_type=$1
    
    echo -e "${BLUE}Reloading schema for: $machine_type${NC}"
    send_command "reload_machine_ui_schema" "{\"machineType\": \"$machine_type\"}" > /dev/null
    
    sleep 1
    
    test_schema "$machine_type"
}

# Function to test all schemas
test_all_schemas() {
    local schemas=("furnace" "assembler" "mining_drill" "rocket_silo" "lab" "generator")
    local failed=0
    
    echo -e "${BLUE}Testing all MachineUI schemas...${NC}"
    echo ""
    
    for schema in "${schemas[@]}"; do
        if test_schema "$schema"; then
            :
        else
            failed=$((failed + 1))
        fi
        echo ""
    done
    
    echo -e "${BLUE}=== Test Summary ===${NC}"
    echo -e "Total schemas tested: ${#schemas[@]}"
    echo -e "Failed: $failed"
    echo -e "Passed: $((${#schemas[@]} - failed))"
    
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}All schemas passed!${NC}"
        return 0
    else
        echo -e "${RED}Some schemas failed. Check feedback reports in $OUTPUT_DIR${NC}"
        return 1
    fi
}

# Function to generate LLM-friendly summary
generate_llm_summary() {
    local summary_file="$OUTPUT_DIR/llm_feedback_summary.md"
    
    cat > "$summary_file" <<EOF
# MachineUI Schema Testing Summary for LLM

## Overview
This document contains a summary of all MachineUI schema tests for automated fixing.

## Test Results

EOF

    for schema_file in "$OUTPUT_DIR"/*_feedback.md; do
        if [ -f "$schema_file" ]; then
            local machine_type=$(basename "$schema_file" _feedback.md)
            local success=$(grep -A 1 "### Status" "$schema_file" | grep "Success:" | grep -o "true\|false")
            
            echo "### $machine_type" >> "$summary_file"
            echo "- **Status:** $success" >> "$summary_file"
            
            if [ "$success" = "false" ]; then
                echo "- **Errors:**" >> "$summary_file"
                grep -A 100 "### Errors" "$schema_file" | grep -B 100 "### Warnings" | grep -v "###" | sed 's/^/  /' >> "$summary_file"
            fi
            echo "" >> "$summary_file"
        fi
    done

    cat >> "$summary_file" <<EOF

## Action Items for LLM

1. Review each schema's feedback report in \`$OUTPUT_DIR\`
2. Fix errors identified in the test results
3. Update schema files in \`$SCHEMA_DIR\`
4. Re-run tests: \`./test-machine-ui-schema.sh test <machine_type>\`

## Schema Files Location
\`$SCHEMA_DIR/*_schema.json\`

---
*Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF

    echo -e "${GREEN}LLM summary saved to: $summary_file${NC}"
}

# Main script logic
case "${1:-help}" in
    test)
        if [ -z "$2" ]; then
            echo "Usage: $0 test <machine_type>"
            echo "Machine types: furnace, assembler, mining_drill, rocket_silo, lab, generator"
            exit 1
        fi
        test_schema "$2"
        ;;
    test-all)
        test_all_schemas
        generate_llm_summary
        ;;
    reload-test)
        if [ -z "$2" ]; then
            echo "Usage: $0 reload-test <machine_type>"
            exit 1
        fi
        reload_and_test "$2"
        ;;
    state)
        get_ui_state
        ;;
    *)
        cat <<EOF
MachineUI Schema Testing Script

Usage:
  $0 test <machine_type>        Test a specific schema
  $0 test-all                   Test all schemas
  $0 reload-test <machine_type> Reload and test a schema
  $0 state                      Get current MachineUI state

Examples:
  $0 test furnace
  $0 test-all
  $0 reload-test assembler

Environment Variables:
  MCP_SERVER_URL  - MCP server URL (default: http://localhost:8080)
  SCHEMA_DIR      - Schema directory (default: FactoryForge/Assets)
  OUTPUT_DIR      - Output directory (default: .machine-ui-test-results)

Output:
  Test results and feedback reports are saved to: $OUTPUT_DIR
EOF
        exit 1
        ;;
esac
