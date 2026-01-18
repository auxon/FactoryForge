#!/bin/bash

# FactoryForge Automation Script
# This script builds and runs the iOS app, then starts the MCP server for AI control

set -e

echo "🚀 Starting FactoryForge Automation..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XCODE_PROJECT="$PROJECT_DIR/FactoryForge.xcodeproj"
SCHEME="FactoryForge"
IOS_DESTINATION="generic/platform=iOS"

echo -e "${BLUE}📱 Building and launching iOS app...${NC}"

# Find the connected iOS device
echo -e "${YELLOW}Finding connected iOS device...${NC}"
DEVICE_ID=$(xcrun xctrace list devices 2>/dev/null | grep -E "iPhone|iPad" | grep -v "Simulator" | head -1 | sed 's/.*(\([0-9A-F\-]*\)).*/\1/')

if [ -z "$DEVICE_ID" ]; then
    echo -e "${YELLOW}No physical device found, using iOS Simulator...${NC}"
    IOS_DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro,OS=latest"
    SIMULATOR_MODE=true
else
    echo -e "${GREEN}Found device: $DEVICE_ID${NC}"
    IOS_DESTINATION="platform=iOS,id=$DEVICE_ID"
    SIMULATOR_MODE=false
    # For physical devices, we need the IP address for network communication
    export FACTORYFORGE_GAME_HOST="192.168.2.41"  # iPhone IP address
fi

# Build and install the app
echo -e "${YELLOW}Building FactoryForge...${NC}"
if [ "$SIMULATOR_MODE" = true ]; then
    xcodebuild -project "$XCODE_PROJECT" -scheme "$SCHEME" -destination "$IOS_DESTINATION" -configuration Debug build
    BUILD_RESULT=$?
else
    xcodebuild -project "$XCODE_PROJECT" -scheme "$SCHEME" -destination "$IOS_DESTINATION" -configuration Debug build CODE_SIGNING_ALLOWED=YES
    BUILD_RESULT=$?
fi

if [ $BUILD_RESULT -eq 0 ]; then
    echo -e "${GREEN}✅ iOS app built successfully${NC}"

    # Launch the app
    echo -e "${YELLOW}Launching FactoryForge...${NC}"
    if [ "$SIMULATOR_MODE" = true ]; then
        xcrun simctl launch booted com.factoryforge.game 2>/dev/null || echo -e "${YELLOW}Note: Simulator may need to be started manually${NC}"
    else
        echo -e "${YELLOW}⚠️  Physical device detected. Please launch the FactoryForge app manually on your device.${NC}"
        echo -e "${YELLOW}   The app should appear in your home screen after building.${NC}"
    fi
else
    echo -e "${RED}❌ iOS app build failed${NC}"
    exit 1
fi

echo -e "${BLUE}🎮 Starting MCP server...${NC}"

# Start MCP server in background
cd "$PROJECT_DIR/MCP"
npm run build
npm start &
MCP_PID=$!

echo -e "${GREEN}✅ MCP server started (PID: $MCP_PID)${NC}"

# Wait for MCP server to initialize
sleep 3

echo -e "${BLUE}🧪 Running factory automation tests...${NC}"

# Wait for the app to launch and connect
echo -e "${YELLOW}⏳ Waiting for FactoryForge to launch and connect...${NC}"
sleep 10

# Run the automation test script
echo -e "${BLUE}🤖 Starting factory automation...${NC}"
cd "$PROJECT_DIR/MCP"
npm run automation

# Cleanup
echo -e "${YELLOW}🧹 Cleaning up...${NC}"
kill $MCP_PID 2>/dev/null || true

echo -e "${GREEN}🎉 Factory automation complete!${NC}"