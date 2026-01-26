# Quick Iteration Guide - MachineUI Schemas

## 🚀 Instant Iteration (No Rebuild!)

Edit schema → Push → See changes instantly in the running app!

### Basic Workflow

```bash
# 1. Edit the schema file
vim FactoryForge/Assets/furnace_schema.json

# 2. Push to running app (instant!)
./push-schema-to-app.sh furnace

# 3. See changes immediately in the app!
```

### Full Iterative Workflow

```bash
# Push, test, and get feedback in one command
./iterative-schema-dev.sh furnace
```

### LLM-Driven Development

```bash
# Push → Test → Generate LLM fix prompt
./llm-iterate-schema.sh furnace

# LLM reads the prompt and fixes the schema
# Then push again:
./push-schema-to-app.sh furnace
```

## 📋 Available Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `push-schema-to-app.sh <type>` | Push schema to app instantly | After editing schema JSON |
| `iterative-schema-dev.sh <type>` | Full workflow (push + test + feedback) | Complete iteration cycle |
| `llm-iterate-schema.sh <type>` | LLM workflow (push + test + fix prompt) | When you want LLM to fix issues |
| `test-machine-ui-schema.sh test <type>` | Test schema only | Just validation |
| `test-machine-ui-schema.sh test-all` | Test all schemas | Full validation suite |

## 🎯 Common Workflows

### Quick Visual Iteration
```bash
# Edit schema file
code FactoryForge/Assets/furnace_schema.json

# Push changes (watch app update instantly)
./push-schema-to-app.sh furnace
```

### Watch Mode (Auto-push on file change)
```bash
# Install fswatch if needed: brew install fswatch
fswatch FactoryForge/Assets/furnace_schema.json | while read; do
    ./push-schema-to-app.sh furnace --no-test
done
```

### LLM Fix Loop
```bash
# 1. Generate fix prompt
./llm-iterate-schema.sh furnace

# 2. LLM reads .machine-ui-test-results/furnace_fix_prompt.md
#    and fixes FactoryForge/Assets/furnace_schema.json

# 3. Push fixed schema
./push-schema-to-app.sh furnace

# 4. Repeat if needed
```

## ⚡ Speed Comparison

| Method | Time | Rebuild Required |
|--------|------|------------------|
| **Push to app** | ~1 second | ❌ No |
| Rebuild + Install | ~30-60 seconds | ✅ Yes |
| Full Xcode build | ~2-5 minutes | ✅ Yes |

## 💡 Tips

1. **Keep Machine UI Open**: The app must have the machine UI open to see changes
2. **Schema Format**: Must include `"$schema"` field for schema format detection
3. **Validation**: Schema is validated before applying - errors are shown immediately
4. **State Persistence**: Changes are applied to the running UI instance only
5. **Bundle vs Push**: 
   - **Push**: Instant, for development
   - **Bundle**: Permanent, requires rebuild

## 🔧 Troubleshooting

### "Cannot connect to app"
- Ensure app is running and connected to MCP server
- Check: `curl http://localhost:8080/command`

### "Schema not applied"
- Make sure Machine UI is open in the app
- Check schema has `"$schema"` field
- Verify JSON is valid: `jq . FactoryForge/Assets/furnace_schema.json`

### "Validation failed"
- Check error message in test output
- Review `.machine-ui-test-results/<type>_feedback.md`
- Use `./llm-iterate-schema.sh` to get fix suggestions

## 📚 Related Documentation

- `MACHINE_UI_AUTOMATED_TESTING.md` - Full testing documentation
- `DEBUGGING_README.md` - Debugging and MCP setup
- `.machine-ui-test-results/` - Test feedback reports
