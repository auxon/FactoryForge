#!/usr/bin/env node

// Simple test client for the FactoryForge MCP server

import WebSocket from 'ws';
import http from 'http';

const MCP_HOST = 'localhost';
const MCP_HTTP_PORT = 8080;
const MCP_WS_PORT = 8081;

// Test HTTP API
async function testHTTP() {
  console.log('Testing HTTP API...');

  try {
    // Get game state
    const response = await fetch(`http://${MCP_HOST}:${MCP_HTTP_PORT}/game-state`);
    const gameState = await response.json();
    console.log('Game state:', JSON.stringify(gameState, null, 2));
  } catch (error) {
    console.error('HTTP test failed:', error.message);
  }
}

// Test WebSocket connection
function testWebSocket() {
  console.log('Testing WebSocket connection...');

  const ws = new WebSocket(`ws://${MCP_HOST}:${MCP_WS_PORT}`);

  ws.on('open', () => {
    console.log('Connected to MCP WebSocket');

    // Send a test command
    const testCommand = {
      type: 'execute_command',
      requestId: 'test-123',
      command: 'pause',
      parameters: {}
    };

    ws.send(JSON.stringify(testCommand));
  });

  ws.on('message', (data) => {
    const message = JSON.parse(data.toString());
    console.log('Received:', message);
  });

  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });

  ws.on('close', () => {
    console.log('WebSocket connection closed');
  });
}

// Test command execution via HTTP
async function testCommand() {
  console.log('Testing command execution...');

  try {
    const response = await fetch(`http://${MCP_HOST}:${MCP_HTTP_PORT}/command`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        command: 'get_game_state'
      })
    });

    const result = await response.json();
    console.log('Command result:', result);
  } catch (error) {
    console.error('Command test failed:', error.message);
  }
}

// Run tests
async function runTests() {
  console.log('FactoryForge MCP Test Client');
  console.log('============================');

  await testHTTP();
  await testCommand();
  testWebSocket();

  // Keep the process alive for WebSocket testing
  setTimeout(() => {
    console.log('Test complete');
    process.exit(0);
  }, 10000);
}

runTests().catch(console.error);