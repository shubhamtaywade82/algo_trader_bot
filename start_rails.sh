#!/bin/bash

# Start Rails with Autopilot Integration
echo "Starting Rails Algo Trader Bot with Autopilot"
echo "=============================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please create .env file with:"
    echo "  AGENT_URL=http://your-windows-machine:4000"
    echo "  PAPER_MODE=true"
    echo "  EXECUTE_ORDERS=false"
    exit 1
fi

# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

echo -e "${GREEN}Configuration:${NC}"
echo "  AGENT_URL: $AGENT_URL"
echo "  PAPER_MODE: $PAPER_MODE"
echo "  EXECUTE_ORDERS: $EXECUTE_ORDERS"
echo "  Authentication: None (local use)"
echo ""

# Check if agent is reachable
if [ ! -z "$AGENT_URL" ]; then
    echo -e "${YELLOW}Checking agent connectivity...${NC}"
    if curl -s --connect-timeout 5 "$AGENT_URL/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Agent is reachable at $AGENT_URL${NC}"
    else
        echo -e "${YELLOW}⚠ Agent not reachable at $AGENT_URL${NC}"
        echo "  Make sure your LLM agent is running on Windows"
    fi
    echo ""
fi

echo -e "${GREEN}Starting Rails server...${NC}"
echo "Autopilot will start automatically in ${PAPER_MODE:-true} mode"
echo "Press Ctrl+C to stop"
echo ""

# Start Rails
rails server
