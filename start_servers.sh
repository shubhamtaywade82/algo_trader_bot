#!/bin/bash

# Start Servers Script for LLM+MCP+Dhan+Rails Setup
echo "Starting LLM+MCP+Dhan+Rails Setup"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if required environment variables are set
check_env() {
    if [ -z "$RAILS_EXECUTOR_URL" ]; then
        echo -e "${YELLOW}Warning: RAILS_EXECUTOR_URL not set, using default: http://localhost:3000${NC}"
        export RAILS_EXECUTOR_URL="http://localhost:3000"
    fi

    if [ -z "$LLM_API_KEY" ]; then
        echo -e "${RED}Error: LLM_API_KEY not set${NC}"
        echo "Please set LLM_API_KEY environment variable"
        exit 1
    fi
}

# Function to start Rails server (in background)
start_rails() {
    echo -e "${GREEN}Starting Rails server...${NC}"
    echo "Make sure to run this in your Rails project directory:"
    echo "  rails server -p 3000"
    echo ""
    echo "Required Rails environment variables:"
    echo "  PAPER_MODE=true"
    echo "  EXECUTE_ORDERS=false"
    echo "  LLM_API_KEY=$LLM_API_KEY"
    echo ""
}

# Function to start MCP server
start_mcp() {
    echo -e "${GREEN}Starting MCP server...${NC}"

    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        echo "Installing Node.js dependencies..."
        npm install
    fi

    # Start MCP server
    echo "Starting MCP server with:"
    echo "  RAILS_EXECUTOR_URL=$RAILS_EXECUTOR_URL"
    echo "  LLM_API_KEY=$LLM_API_KEY"
    echo ""

    node mcp-server.js
}

# Function to test endpoints
test_endpoints() {
    echo -e "${GREEN}Testing Rails endpoints...${NC}"
    node test_endpoints.js
}

# Main execution
main() {
    check_env

    case "${1:-mcp}" in
        "rails")
            start_rails
            ;;
        "mcp")
            start_mcp
            ;;
        "test")
            test_endpoints
            ;;
        "all")
            start_rails
            sleep 2
            start_mcp
            ;;
        *)
            echo "Usage: $0 [rails|mcp|test|all]"
            echo ""
            echo "Commands:"
            echo "  rails  - Show Rails server startup instructions"
            echo "  mcp    - Start MCP server (default)"
            echo "  test   - Test Rails endpoints"
            echo "  all    - Show instructions for both servers"
            echo ""
            echo "Environment variables:"
            echo "  RAILS_EXECUTOR_URL - Rails server URL (default: http://localhost:3000)"
            echo "  LLM_API_KEY       - API key for authentication (required)"
            echo ""
            echo "Example:"
            echo "  LLM_API_KEY=mykey123 ./start_servers.sh mcp"
            ;;
    esac
}

main "$@"
