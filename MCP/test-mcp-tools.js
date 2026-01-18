#!/usr/bin/env node

// Test MCP Tools for FactoryForge
// Tests the MCP server tools without requiring the actual game to be running

import axios from 'axios';

const MCP_HTTP_URL = 'http://localhost:8080';

// Colors for console output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

class MCPToolTester {
  async testAllTools() {
    log('🧪 Testing FactoryForge MCP Tools', 'bright');

    try {
      // Test 1: Get game state
      await this.testGetGameState();

      // Test 2: Execute build command
      await this.testBuildCommand();

      // Test 3: Execute move command
      await this.testMoveCommand();

      // Test 4: Execute research command
      await this.testResearchCommand();

      // Test 5: Get entities
      await this.testGetEntities();

      // Test 6: Get performance metrics
      await this.testPerformanceMetrics();

      // Test 7: Test game controls
      await this.testGameControls();

      log('🎉 All MCP tool tests completed!', 'green');

    } catch (error) {
      log(`❌ MCP tool testing failed: ${error.message}`, 'red');
    }
  }

  async testGetGameState() {
    log('📊 Testing get_game_state tool...', 'blue');

    try {
      const response = await axios.post(`${MCP_HTTP_URL}/command`, {
        command: 'get_game_state'
      });

      const result = response.data;
      if (result.success) {
        log('✅ Game state retrieved successfully', 'green');
        log(`   Player resources: ${Object.keys(result.result?.player?.resources || {}).length} types`, 'cyan');
        log(`   World entities: ${result.result?.world?.entities?.length || 0}`, 'cyan');
        log(`   Current research: ${result.result?.systems?.research?.current || 'None'}`, 'cyan');
      } else {
        log(`❌ Failed to get game state: ${result.error}`, 'red');
      }
    } catch (error) {
      log(`❌ Error testing get_game_state: ${error.response?.data?.error || error.message}`, 'red');
    }
  }

  async testBuildCommand() {
    log('🔨 Testing build command...', 'blue');

    const buildings = [
      { id: 'mining-drill', x: 5, y: 5, name: 'Iron Mining Drill' },
      { id: 'stone-furnace', x: 10, y: 5, name: 'Stone Furnace' },
      { id: 'assembling-machine-1', x: 15, y: 5, name: 'Assembler' },
      { id: 'transport-belt', x: 7, y: 5, name: 'Transport Belt' },
      { id: 'inserter', x: 12, y: 6, name: 'Inserter' }
    ];

    for (const building of buildings) {
      try {
        const response = await axios.post(`${MCP_HTTP_URL}/command`, {
          command: 'build',
          parameters: {
            buildingId: building.id,
            x: building.x,
            y: building.y
          }
        });

        const result = response.data;
        if (result.success) {
          log(`✅ Successfully built ${building.name} at (${building.x}, ${building.y})`, 'green');
        } else {
          log(`❌ Failed to build ${building.name}: ${result.error}`, 'yellow');
        }

        // Small delay between commands
        await this.delay(200);

      } catch (error) {
        log(`❌ Error building ${building.name}: ${error.response?.data?.error || error.message}`, 'red');
      }
    }
  }

  async testMoveCommand() {
    log('🚶 Testing move command...', 'blue');

    try {
      const response = await axios.post(`${MCP_HTTP_URL}/command`, {
        command: 'move',
        parameters: {
          unitId: 'test_unit_1',
          x: 20,
          y: 10
        }
      });

      const result = response.data;
      if (result.success) {
        log('✅ Move command executed successfully', 'green');
      } else {
        log(`⚠️ Move command failed (expected if no units exist): ${result.error}`, 'yellow');
      }
    } catch (error) {
      log(`❌ Error testing move command: ${error.response?.data?.error || error.message}`, 'red');
    }
  }

  async testResearchCommand() {
    log('🔬 Testing research command...', 'blue');

    const technologies = ['automation', 'steel-processing', 'electronics'];

    for (const tech of technologies) {
      try {
        const response = await axios.post(`${MCP_HTTP_URL}/command`, {
          command: 'research',
          parameters: {
            technologyId: tech
          }
        });

        const result = response.data;
        if (result.success) {
          log(`✅ Started research on ${tech}`, 'green');
        } else {
          log(`⚠️ Failed to research ${tech}: ${result.error}`, 'yellow');
        }

        await this.delay(200);

      } catch (error) {
        log(`❌ Error researching ${tech}: ${error.response?.data?.error || error.message}`, 'red');
      }
    }
  }

  async testGetEntities() {
    log('🔍 Testing get_entities tool...', 'blue');

    try {
      const response = await axios.post(`${MCP_HTTP_URL}/command`, {
        command: 'get_entities',
        parameters: {
          type: 'all'
        }
      });

      const result = response.data;
      if (result.success) {
        const entities = result.result || [];
        log(`✅ Found ${entities.length} entities in the world`, 'green');

        // Show breakdown by type
        const typeCounts = {};
        entities.forEach(entity => {
          typeCounts[entity.type] = (typeCounts[entity.type] || 0) + 1;
        });

        Object.entries(typeCounts).forEach(([type, count]) => {
          log(`   ${type}: ${count}`, 'cyan');
        });
      } else {
        log(`❌ Failed to get entities: ${result.error}`, 'red');
      }
    } catch (error) {
      log(`❌ Error testing get_entities: ${error.response?.data?.error || error.message}`, 'red');
    }
  }

  async testPerformanceMetrics() {
    log('📈 Testing performance metrics...', 'blue');

    try {
      const response = await axios.post(`${MCP_HTTP_URL}/command`, {
        command: 'get_performance_metrics'
      });

      const result = response.data;
      if (result.success) {
        const metrics = result.result;
        log('✅ Performance metrics retrieved:', 'green');
        log(`   FPS: ${metrics.fps}`, 'cyan');
        log(`   Memory Usage: ${metrics.memoryUsage} MB`, 'cyan');
        log(`   Entity Count: ${metrics.entityCount}`, 'cyan');
      } else {
        log(`❌ Failed to get performance metrics: ${result.error}`, 'red');
      }
    } catch (error) {
      log(`❌ Error testing performance metrics: ${error.response?.data?.error || error.message}`, 'red');
    }
  }

  async testGameControls() {
    log('🎮 Testing game controls...', 'blue');

    const controls = [
      { command: 'pause', name: 'Pause Game' },
      { command: 'resume', name: 'Resume Game' }
    ];

    for (const control of controls) {
      try {
        const response = await axios.post(`${MCP_HTTP_URL}/command`, {
          command: control.command
        });

        const result = response.data;
        if (result.success) {
          log(`✅ ${control.name} command executed`, 'green');
        } else {
          log(`⚠️ ${control.name} failed: ${result.error}`, 'yellow');
        }

        await this.delay(500);

      } catch (error) {
        log(`❌ Error with ${control.name}: ${error.response?.data?.error || error.message}`, 'red');
      }
    }
  }

  async delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// Run the tests
const tester = new MCPToolTester();
tester.testAllTools().catch(error => {
  log(`💥 Test suite crashed: ${error.message}`, 'red');
  process.exit(1);
});