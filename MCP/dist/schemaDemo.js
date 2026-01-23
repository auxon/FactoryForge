// Schema Demo - Shows how to use the new formal MachineUI schema
// This demonstrates the improved architecture with Groups and Anchors
import * as fs from 'fs';
import * as path from 'path';
export class SchemaDemo {
    gameController;
    output = [];
    constructor(gameController) {
        this.gameController = gameController;
    }
    log(message) {
        console.log(message);
        this.output.push(message);
    }
    async demonstrateSchemaUsage() {
        this.output = [];
        this.log('🎯 Demonstrating Formal MachineUI Schema Usage');
        try {
            // 1. Load the formal schema for furnace
            const schemaPath = path.join(__dirname, '../../FactoryForge/Assets/furnace_schema.json');
            const schemaContent = fs.readFileSync(schemaPath, 'utf8');
            const schema = JSON.parse(schemaContent);
            this.log(`✅ Loaded furnace schema: ${schema.id}`);
            // 2. Validate schema invariants
            this.validateSchemaInvariants(schema);
            // 3. Schema demonstration
            this.log('\n🏗️  Schema Architecture:');
            this.log('• Formal Groups with anchoring system');
            this.log('• Semantic role binding');
            this.log('• Invariant enforcement');
            this.log('• Structured UI layout');
            this.log('\n✨ Schema validation and demonstration complete!');
            return this.output.join('\n');
        }
        catch (error) {
            const errorMsg = `❌ Schema demo failed: ${error}`;
            console.error(errorMsg);
            return errorMsg;
        }
    }
    validateSchemaInvariants(schema) {
        this.log('\n🔍 Validating Schema Invariants:');
        // Check 1: Every group has a header
        const groupsWithoutHeaders = schema.groups.filter((g) => !g.header?.text);
        if (groupsWithoutHeaders.length > 0) {
            throw new Error(`Groups missing headers: ${groupsWithoutHeaders.map((g) => g.id)}`);
        }
        this.log('✅ All groups have headers');
        // Check 2: Process has label if present
        if (schema.process && !schema.process.label?.text) {
            throw new Error('Process missing label');
        }
        this.log('✅ Process has label');
        // Check 3: Flow axis constraints
        if (schema.layout.flowAxis === 'leftToRight') {
            const inputs = schema.groups.filter((g) => g.role === 'input');
            const outputs = schema.groups.filter((g) => g.role === 'output');
            const processX = schema.process?.anchor?.gridX;
            if (processX !== undefined) {
                const misplacedInputs = inputs.filter((g) => g.anchor.gridX >= processX);
                const misplacedOutputs = outputs.filter((g) => g.anchor.gridX <= processX);
                if (misplacedInputs.length > 0 || misplacedOutputs.length > 0) {
                    throw new Error('Flow axis constraints violated');
                }
            }
        }
        this.log('✅ Flow axis constraints satisfied');
        this.log('🎉 All invariants validated!');
    }
    // Example of how to convert current JSON config to formal schema
    convertLegacyConfigToSchema(legacyConfig) {
        // This would be a migration utility
        return {
            version: "1.0.0",
            id: `machineui.${legacyConfig.machineType}`,
            machineKind: legacyConfig.machineType,
            title: legacyConfig.machineType.charAt(0).toUpperCase() + legacyConfig.machineType.slice(1),
            // Convert flat components to Groups
            groups: this.extractGroupsFromComponents(legacyConfig.components),
            process: this.extractProcessFromComponents(legacyConfig.components),
            // Add standard layout
            layout: {
                flowAxis: "leftToRight",
                safeArea: { top: 16, left: 16, bottom: 16, right: 16 },
                padding: { x: 24, y: 24 },
                grid: { columns: 12, rows: 8, gutterX: 12, gutterY: 12 }
            },
            // Standard invariants
            invariants: [
                "Every GroupHeader must be a descendant of exactly one Group.",
                "No floating labels: GroupHeader must not be sibling of Slot; it must be ancestor (container header).",
                "Process.progress must be visually adjacent to Process.label (max distance <= 1 grid row).",
                "All input-role groups must be placed left of process anchor when flowAxis=leftToRight.",
                "All output-role groups must be placed right of process anchor when flowAxis=leftToRight.",
                "Slots in the same Group must share the same leading alignment and spacing.",
                "If operators.showFlowGlyphs=true, glyphs must use glyphStyleRole=muted and never use semantic colors.",
                "Any progress bar must have an explicit label (Process.label.text non-empty).",
                "Empty state text must be inside the owning Group (content.stateText), never global."
            ]
        };
    }
    extractGroupsFromComponents(components) {
        // Implementation would parse the flat component array and group related elements
        // This is a placeholder for the migration logic
        return [];
    }
    extractProcessFromComponents(components) {
        // Extract progress bar and related labels into Process structure
        return null;
    }
}
