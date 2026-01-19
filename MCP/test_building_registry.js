import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

async function testBuildingRegistry() {
  try {
    const transport = new StdioClientTransport({
      command: 'node',
      args: ['dist/index.js'],
      env: { FACTORYFORGE_GAME_HOST: '192.168.2.41' }
    });

    const client = new Client({
      name: 'building-registry-test',
      version: '1.0.0'
    });

    await client.connect(transport);

    // Test listing building configs
    console.log('Testing list_building_configs...');
    const result = await client.callTool({
      name: 'list_building_configs',
      arguments: {}
    });

    console.log('Result:', JSON.stringify(result, null, 2));

  } catch (error) {
    console.error('Error:', error);
  }
}

testBuildingRegistry();