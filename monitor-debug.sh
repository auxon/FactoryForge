#!/bin/bash

echo "🔍 Starting FactoryForge Debug Monitor..."
echo "Press Ctrl+C to stop monitoring"
echo ""

LAST_LOG_COUNT=0

while true; do
    RESPONSE=$(curl -s -X POST http://localhost:8080/command -H "Content-Type: application/json" -d '{"command":"get_debug_logs","parameters":{}}' 2>/dev/null)
    
    if [ $? -eq 0 ] && echo "$RESPONSE" | jq -e '.logs' >/dev/null 2>&1; then
        LOG_COUNT=$(echo "$RESPONSE" | jq '.logs | length')
        
        if [ "$LOG_COUNT" -gt "$LAST_LOG_COUNT" ]; then
            echo "$RESPONSE" | jq -r '.logs[]' | tail -n +$((LAST_LOG_COUNT + 1))
            LAST_LOG_COUNT=$LOG_COUNT
        fi
    else
        echo "⚠️  Unable to connect to FactoryForge (app may have crashed)"
    fi
    
    sleep 2
done
