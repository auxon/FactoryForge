#!/usr/bin/env python3
"""
Automated MachineUI Schema Fix Workflow
This script facilitates the LLM-driven fix workflow for MachineUI schemas.

It reads test feedback, identifies issues, and provides a structured format
for the LLM to make fixes.
"""

import json
import os
import sys
import subprocess
from pathlib import Path
from typing import Dict, List, Any
from datetime import datetime

# Configuration
SCHEMA_DIR = Path(os.getenv("SCHEMA_DIR", "FactoryForge/Assets"))
OUTPUT_DIR = Path(os.getenv("OUTPUT_DIR", ".machine-ui-test-results"))
MCP_SERVER_URL = os.getenv("MCP_SERVER_URL", "http://localhost:8080")


class MachineUISchemaFixer:
    """Handles automated fixing of MachineUI schemas based on test feedback."""
    
    def __init__(self):
        self.schema_dir = SCHEMA_DIR
        self.output_dir = OUTPUT_DIR
        self.output_dir.mkdir(exist_ok=True)
    
    def load_test_results(self, machine_type: str) -> Dict[str, Any]:
        """Load test results for a machine type."""
        result_file = self.output_dir / f"{machine_type}_test_raw.json"
        if not result_file.exists():
            return {}
        
        with open(result_file, 'r') as f:
            return json.load(f)
    
    def load_schema(self, machine_type: str) -> Dict[str, Any]:
        """Load a schema file."""
        schema_file = self.schema_dir / f"{machine_type}_schema.json"
        if not schema_file.exists():
            return {}
        
        with open(schema_file, 'r') as f:
            return json.load(f)
    
    def save_schema(self, machine_type: str, schema: Dict[str, Any]) -> bool:
        """Save a schema file."""
        schema_file = self.schema_dir / f"{machine_type}_schema.json"
        
        try:
            with open(schema_file, 'w') as f:
                json.dump(schema, f, indent=2)
            return True
        except Exception as e:
            print(f"Error saving schema: {e}", file=sys.stderr)
            return False
    
    def test_schema(self, machine_type: str) -> Dict[str, Any]:
        """Test a schema via MCP server."""
        import requests
        
        try:
            response = requests.post(
                f"{MCP_SERVER_URL}/command",
                json={
                    "command": "test_machine_ui_schema",
                    "requestId": f"test-{datetime.now().timestamp()}",
                    "parameters": {"machineType": machine_type}
                },
                timeout=10
            )
            response.raise_for_status()
            result = response.json()
            
            # Save raw result
            result_file = self.output_dir / f"{machine_type}_test_raw.json"
            with open(result_file, 'w') as f:
                json.dump(result, f, indent=2)
            
            return result
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def reload_schema(self, machine_type: str) -> bool:
        """Reload a schema in the running app."""
        import requests
        
        try:
            response = requests.post(
                f"{MCP_SERVER_URL}/command",
                json={
                    "command": "reload_machine_ui_schema",
                    "requestId": f"reload-{datetime.now().timestamp()}",
                    "parameters": {"machineType": machine_type}
                },
                timeout=10
            )
            response.raise_for_status()
            result = response.json()
            return result.get("success", False)
        except Exception as e:
            print(f"Error reloading schema: {e}", file=sys.stderr)
            return False
    
    def get_fix_suggestions(self, machine_type: str) -> Dict[str, Any]:
        """Generate fix suggestions based on test results."""
        test_result = self.load_test_results(machine_type)
        schema = self.load_schema(machine_type)
        
        if not test_result:
            return {"error": "No test results found"}
        
        errors = test_result.get("errors", [])
        warnings = test_result.get("warnings", [])
        
        suggestions = {
            "machine_type": machine_type,
            "schema_file": str(self.schema_dir / f"{machine_type}_schema.json"),
            "errors": errors,
            "warnings": warnings,
            "fixes_needed": [],
            "schema_snippet": {}
        }
        
        # Analyze errors and generate fix suggestions
        for error in errors:
            error_lower = error.lower()
            
            if "not found" in error_lower or "file not found" in error_lower:
                suggestions["fixes_needed"].append({
                    "issue": "Schema file missing",
                    "action": f"Create {machine_type}_schema.json in {self.schema_dir}",
                    "priority": "high"
                })
            
            elif "validation failed" in error_lower or "missing" in error_lower:
                if "header" in error_lower:
                    suggestions["fixes_needed"].append({
                        "issue": "Missing group header",
                        "action": "Add 'header' field to all groups in schema",
                        "priority": "high",
                        "schema_section": "groups"
                    })
                elif "process" in error_lower and "label" in error_lower:
                    suggestions["fixes_needed"].append({
                        "issue": "Missing process label",
                        "action": "Add 'label.text' field to process in schema",
                        "priority": "high",
                        "schema_section": "process"
                    })
            
            elif "invalid" in error_lower or "flow" in error_lower:
                suggestions["fixes_needed"].append({
                    "issue": "Invalid flow position",
                    "action": "Check group anchor positions relative to process anchor",
                    "priority": "medium",
                    "schema_section": "groups"
                })
        
        # Add schema snippet for context
        if schema:
            suggestions["schema_snippet"] = {
                "machineKind": schema.get("machineKind"),
                "version": schema.get("version"),
                "groups_count": len(schema.get("groups", [])),
                "has_process": "process" in schema,
                "has_recipes": "recipes" in schema
            }
        
        return suggestions
    
    def generate_llm_prompt(self, machine_type: str) -> str:
        """Generate a prompt for the LLM to fix the schema."""
        suggestions = self.get_fix_suggestions(machine_type)
        schema = self.load_schema(machine_type)
        
        prompt = f"""# Fix MachineUI Schema: {machine_type}

## Current Issues

"""
        
        if suggestions.get("errors"):
            prompt += "### Errors:\n"
            for error in suggestions["errors"]:
                prompt += f"- {error}\n"
            prompt += "\n"
        
        if suggestions.get("warnings"):
            prompt += "### Warnings:\n"
            for warning in suggestions["warnings"]:
                prompt += f"- {warning}\n"
            prompt += "\n"
        
        if suggestions.get("fixes_needed"):
            prompt += "### Fixes Needed:\n"
            for fix in suggestions["fixes_needed"]:
                prompt += f"- **{fix['issue']}** (Priority: {fix['priority']})\n"
                prompt += f"  - Action: {fix['action']}\n"
            prompt += "\n"
        
        prompt += f"""## Schema File Location
{suggestions['schema_file']}

## Current Schema Structure
```json
{json.dumps(schema, indent=2)[:1000]}...
```

## Task
Please fix the schema file to resolve the errors and warnings listed above.
The schema file is located at: {suggestions['schema_file']}

After fixing, the schema will be automatically tested and reloaded in the app.
"""
        
        return prompt
    
    def run_fix_workflow(self, machine_type: str) -> Dict[str, Any]:
        """Run the complete fix workflow."""
        print(f"Running fix workflow for: {machine_type}")
        
        # Step 1: Test current schema
        print("1. Testing current schema...")
        test_result = self.test_schema(machine_type)
        
        if test_result.get("success"):
            print(f"✓ Schema for {machine_type} is already valid!")
            return {"success": True, "message": "No fixes needed"}
        
        # Step 2: Generate fix suggestions
        print("2. Analyzing issues...")
        suggestions = self.get_fix_suggestions(machine_type)
        
        # Step 3: Generate LLM prompt
        print("3. Generating fix prompt...")
        prompt = self.generate_llm_prompt(machine_type)
        
        prompt_file = self.output_dir / f"{machine_type}_fix_prompt.md"
        with open(prompt_file, 'w') as f:
            f.write(prompt)
        
        print(f"\n{'='*60}")
        print("LLM FIX PROMPT GENERATED")
        print(f"{'='*60}")
        print(f"\nPrompt saved to: {prompt_file}")
        print("\nPlease review the prompt and fix the schema file.")
        print(f"Schema file: {suggestions['schema_file']}")
        print("\nAfter fixing, run:")
        print(f"  python3 automate-machine-ui-fixes.py verify {machine_type}")
        print(f"{'='*60}\n")
        
        return {
            "success": False,
            "fixes_needed": True,
            "prompt_file": str(prompt_file),
            "schema_file": suggestions["schema_file"],
            "suggestions": suggestions
        }
    
    def verify_fix(self, machine_type: str) -> Dict[str, Any]:
        """Verify that a fix was successful."""
        print(f"Verifying fix for: {machine_type}")
        
        # Test the schema
        test_result = self.test_schema(machine_type)
        
        if test_result.get("success"):
            print(f"✓ Schema for {machine_type} is now valid!")
            
            # Reload in app
            print("Reloading schema in app...")
            if self.reload_schema(machine_type):
                print("✓ Schema reloaded successfully!")
            else:
                print("⚠ Could not reload schema (app may not be running)")
            
            return {"success": True, "test_result": test_result}
        else:
            print(f"✗ Schema still has issues:")
            for error in test_result.get("errors", []):
                print(f"  - {error}")
            
            return {"success": False, "test_result": test_result}


def main():
    if len(sys.argv) < 2:
        print("""Usage:
  python3 automate-machine-ui-fixes.py fix <machine_type>    - Generate fix prompt
  python3 automate-machine-ui-fixes.py verify <machine_type> - Verify a fix
  python3 automate-machine-ui-fixes.py test <machine_type>   - Test a schema

Examples:
  python3 automate-machine-ui-fixes.py fix furnace
  python3 automate-machine-ui-fixes.py verify furnace
""")
        sys.exit(1)
    
    command = sys.argv[1]
    fixer = MachineUISchemaFixer()
    
    if command == "fix":
        if len(sys.argv) < 3:
            print("Error: machine_type required")
            sys.exit(1)
        machine_type = sys.argv[2]
        result = fixer.run_fix_workflow(machine_type)
        sys.exit(0 if result.get("success") else 1)
    
    elif command == "verify":
        if len(sys.argv) < 3:
            print("Error: machine_type required")
            sys.exit(1)
        machine_type = sys.argv[2]
        result = fixer.verify_fix(machine_type)
        sys.exit(0 if result.get("success") else 1)
    
    elif command == "test":
        if len(sys.argv) < 3:
            print("Error: machine_type required")
            sys.exit(1)
        machine_type = sys.argv[2]
        result = fixer.test_schema(machine_type)
        print(json.dumps(result, indent=2))
        sys.exit(0 if result.get("success") else 1)
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
