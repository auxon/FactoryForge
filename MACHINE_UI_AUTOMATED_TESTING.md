# MachineUI Automated Testing and Fix Workflow

This document describes the automated testing and LLM-driven fix workflow for MachineUI schemas.

## Overview

The automated testing system allows you to:
1. **Test schemas** - Validate schema files and capture errors
2. **Get feedback** - Generate detailed reports for LLM consumption
3. **Automate fixes** - Use LLM to fix issues based on feedback
4. **Iterate quickly** - Test, fix, and reload without rebuilding

## Quick Start

### 1. Instant Iteration (No Rebuild Required!)

**Push schema changes directly to the running app:**

```bash
# Push schema to app and test
./push-schema-to-app.sh furnace

# Full iterative workflow (push + test + feedback)
./iterative-schema-dev.sh furnace

# LLM-driven iteration workflow (push + test + generate fix prompt)
./llm-iterate-schema.sh furnace
```

**Workflow:**
1. Edit `FactoryForge/Assets/furnace_schema.json`
2. Run `./push-schema-to-app.sh furnace`
3. See changes instantly in the app!

### 2. Test a Schema

```bash
# Test a specific schema
./test-machine-ui-schema.sh test furnace

# Test all schemas
./test-machine-ui-schema.sh test-all

# Reload and test (after rebuilding)
./test-machine-ui-schema.sh reload-test furnace
```

### 2. Get Current UI State

```bash
./test-machine-ui-schema.sh state
```

### 3. Automated Fix Workflow

```bash
# Generate fix prompt for LLM
python3 automate-machine-ui-fixes.py fix furnace

# After LLM fixes the schema, verify it
python3 automate-machine-ui-fixes.py verify furnace
```

## Workflow for LLM-Driven Fixes

### Step 1: Test and Identify Issues

```bash
./test-machine-ui-schema.sh test furnace
```

This generates:
- `.machine-ui-test-results/furnace_test_raw.json` - Raw test results
- `.machine-ui-test-results/furnace_feedback.md` - Human-readable feedback

### Step 2: Generate Fix Prompt

```bash
python3 automate-machine-ui-fixes.py fix furnace
```

This generates:
- `.machine-ui-test-results/furnace_fix_prompt.md` - LLM-friendly prompt with:
  - Current errors and warnings
  - Fix suggestions
  - Schema file location
  - Current schema structure

### Step 3: LLM Fixes the Schema

The LLM reads the prompt and fixes the schema file:
- `FactoryForge/Assets/furnace_schema.json`

### Step 4: Verify the Fix

```bash
python3 automate-machine-ui-fixes.py verify furnace
```

This:
1. Tests the fixed schema
2. Reloads it in the running app
3. Reports success or remaining issues

## MCP Commands

You can also use MCP commands directly:

### Test Schema

```javascript
test_machine_ui_schema({ machineType: "furnace" })
```

Returns:
```json
{
  "success": true/false,
  "schemaFound": true,
  "validationPassed": true,
  "errors": [],
  "warnings": [],
  "validationResults": []
}
```

### Get UI State

```javascript
get_machine_ui_state({})
```

Returns:
```json
{
  "isOpen": true,
  "currentMachineType": "furnace",
  "hasCurrentSchema": true,
  "currentSchemaKind": "furnace",
  "schemaGroupCount": 3,
  "hasProcess": true,
  "hasRecipes": true,
  "recentLogs": [...]
}
```

### Reload Schema

```javascript
reload_machine_ui_schema({ machineType: "furnace" })
```

## Feedback Report Format

Feedback reports are generated in Markdown format for easy LLM consumption:

```markdown
# MachineUI Schema Test Feedback: furnace

## Test Results
- **Success:** false
- **Schema Found:** true
- **Validation Passed:** false

### Errors
- Validation failed: missingGroupHeader(groupID: "fuel")

### Warnings
- Schema has no recipes defined (may be intentional)

## Recommended Actions
- ❌ Fix the following issues:
  - Add header field to "fuel" group
  - Review schema file: FactoryForge/Assets/furnace_schema.json
```

## Integration with LLM

The system is designed to work seamlessly with LLMs:

1. **Test Command**: LLM runs test to identify issues
2. **Fix Prompt**: System generates structured prompt with context
3. **Schema Fix**: LLM reads prompt and fixes schema file
4. **Verification**: System automatically tests and reloads

### Example LLM Workflow

```python
# 1. Test schema
test_result = test_machine_ui_schema("furnace")

# 2. If failed, generate fix prompt
if not test_result["success"]:
    fixer = MachineUISchemaFixer()
    prompt = fixer.generate_llm_prompt("furnace")
    
    # 3. LLM reads prompt and fixes schema
    # (LLM edits FactoryForge/Assets/furnace_schema.json)
    
    # 4. Verify fix
    verify_result = fixer.verify_fix("furnace")
```

## Error Types

The system captures several types of errors:

### Validation Errors
- `missingGroupHeader` - Group missing header field
- `missingProcessLabel` - Process missing label
- `invalidFlowPosition` - Groups positioned incorrectly relative to process

### Loading Errors
- `schemaFileNotFound` - Schema file doesn't exist
- `decodeError` - Schema JSON is malformed

### Runtime Errors
- `rootViewNotAvailable` - UI not initialized
- `applySchemaError` - Error applying schema to UI

## Best Practices

1. **Use Push Workflow for Fast Iteration**: 
   - Edit schema JSON file
   - Run `./push-schema-to-app.sh <machine_type>`
   - See changes instantly without rebuilding!

2. **LLM-Driven Development**:
   - Run `./llm-iterate-schema.sh <machine_type>`
   - Get feedback and fix prompts
   - LLM fixes the schema
   - Push and verify immediately

3. **Test Before Deploying**: Always test schemas before finalizing
4. **Check Feedback**: Review feedback reports for detailed error info
5. **Fix Incrementally**: Fix one error at a time and verify
6. **Watch Mode**: Use `watch -n 2 './push-schema-to-app.sh furnace --no-test'` for continuous updates

## Troubleshooting

### Schema Not Found
- Ensure schema file exists: `FactoryForge/Assets/{machine_type}_schema.json`
- Check file is included in Xcode project bundle

### Validation Fails
- Check error messages in feedback report
- Review schema structure against MachineUISchema format
- Use `get_machine_ui_state` to see current UI state

### Reload Doesn't Work
- Ensure app is running and connected to MCP server
- Check MCP server is running: `curl http://localhost:8080/command`
- Verify schema file was rebuilt in bundle

## Environment Variables

- `MCP_SERVER_URL` - MCP server URL (default: http://localhost:8080)
- `SCHEMA_DIR` - Schema directory (default: FactoryForge/Assets)
- `OUTPUT_DIR` - Output directory (default: .machine-ui-test-results)

## Files Generated

All test results and feedback are saved to `.machine-ui-test-results/`:

- `{machine_type}_test_raw.json` - Raw test results (JSON)
- `{machine_type}_feedback.md` - Human-readable feedback
- `{machine_type}_fix_prompt.md` - LLM fix prompt
- `ui_state.json` - Current UI state snapshot
- `llm_feedback_summary.md` - Summary of all tests

## Next Steps

1. Test your schemas: `./test-machine-ui-schema.sh test-all`
2. Review feedback: Check `.machine-ui-test-results/` directory
3. Fix issues: Use LLM workflow or manual fixes
4. Verify: Run tests again to confirm fixes

For more information, see `DEBUGGING_README.md`.
