# Complete Setup Guide: LLM+MCP+Dhan+Rails

This guide shows you how to run the complete setup with your Rails app in a separate directory.

## Architecture Overview

```
LLM Agent ←→ MCP Server ←→ Rails API ←→ DhanHQ API
    ↓              ↓           ↓
  Planning    Tool Calls   Execution
```

## Prerequisites

1. **Rails App** (in separate directory) - Your algo trader bot
2. **MCP Server** (this directory) - Bridges LLM agent to Rails
3. **DhanHQ API** - Market data and execution
4. **LLM Agent** - Planning and decision making

## Step 1: Rails Server Setup

### In your Rails project directory:

1. **Set environment variables** (create `.env` file):
```bash
# Rails .env file
PAPER_MODE=true
EXECUTE_ORDERS=false
LLM_API_KEY=your_secure_api_key_here

# DhanHQ credentials
DHAN_CLIENT_ID=your_dhan_client_id
DHAN_ACCESS_TOKEN=your_dhan_access_token
```

2. **Start Rails server**:
```bash
rails server -p 3000
```

3. **Verify Rails is running**:
```bash
curl http://localhost:3000/up
```

## Step 2: MCP Server Setup

### In this directory (algo_trader_bot):

1. **Set environment variables**:
```bash
export RAILS_EXECUTOR_URL="http://localhost:3000"
export LLM_API_KEY="your_secure_api_key_here"
```

2. **Install dependencies**:
```bash
npm install
```

3. **Start MCP server**:
```bash
./start_servers.sh mcp
```

## Step 3: Test the Setup

### Test Rails endpoints directly:
```bash
./start_servers.sh test
```

### Test MCP server:
```bash
# In another terminal
node mcp-server.js
```

## Step 4: LLM Agent Integration

### Configure your LLM agent to use the MCP server:

```json
{
  "mcpServers": {
    "rails-algo-trader": {
      "command": "node",
      "args": ["mcp-server.js"],
      "env": {
        "RAILS_EXECUTOR_URL": "http://localhost:3000",
        "LLM_API_KEY": "your_secure_api_key_here"
      }
    }
  }
}
```

## Available MCP Tools

The MCP server provides these tools to your LLM agent:

1. **get_funds** - Get available cash
2. **get_positions** - Get open positions
3. **get_orders** - Get order book
4. **get_spot** - Get spot price for symbol
5. **get_quote** - Get quote data for security ID
6. **get_option_chain** - Get option chain data
7. **place_bracket_order** - Place bracket order (paper mode)
8. **modify_order** - Modify existing order
9. **cancel_order** - Cancel existing order

## API Endpoints (Rails)

Your Rails app exposes these endpoints:

- `GET /llm/funds` - Available cash
- `GET /llm/positions` - Open positions
- `GET /llm/orders` - Order book
- `GET /llm/spot?underlying=NIFTY` - Spot price
- `GET /llm/quote?securityId=256265` - Quote data
- `GET /llm/option_chain?underlying=NIFTY&expiry=2024-01-25` - Option chain
- `POST /llm/place_bracket_order` - Place bracket order
- `POST /llm/modify_order` - Modify order
- `POST /llm/cancel_order` - Cancel order

## Environment Variables

### Rails (.env):
```bash
PAPER_MODE=true              # Paper trading mode
EXECUTE_ORDERS=false         # Disable real execution
LLM_API_KEY=your_key        # API authentication
DHAN_CLIENT_ID=your_id      # DhanHQ credentials
DHAN_ACCESS_TOKEN=your_token
```

### MCP Server:
```bash
RAILS_EXECUTOR_URL=http://localhost:3000  # Rails server URL
LLM_API_KEY=your_key                     # Must match Rails
```

## Quick Start Commands

```bash
# 1. Start Rails (in Rails directory)
rails server -p 3000

# 2. Start MCP (in this directory)
LLM_API_KEY=yourkey ./start_servers.sh mcp

# 3. Test endpoints
LLM_API_KEY=yourkey ./start_servers.sh test
```

## Troubleshooting

### Rails server not starting:
- Check database setup: `rails db:create db:migrate`
- Verify DhanHQ credentials
- Check port 3000 is available

### MCP server connection failed:
- Verify Rails server is running on port 3000
- Check `RAILS_EXECUTOR_URL` and `LLM_API_KEY` match
- Test with: `curl -H "X-API-KEY: yourkey" http://localhost:3000/llm/funds`

### API authentication errors:
- Ensure `LLM_API_KEY` is the same in both Rails and MCP server
- Check Rails controller `auth!` method

## Next Steps (Phase 5)

1. **Signal Endpoint**: Add `/signal` endpoint to your LLM agent
2. **Signal Flow**: Bot → Agent → Plan → Execution
3. **Live Trading**: Switch from paper mode to live execution

## File Structure

```
algo_trader_bot/           # This directory (MCP server)
├── mcp-server.js         # MCP server implementation
├── test_endpoints.js     # Endpoint testing
├── start_servers.sh      # Server startup script
└── package.json          # Node.js dependencies

your_rails_app/           # Your Rails app directory
├── app/controllers/llm_controller.rb  # API endpoints
├── config/routes.rb      # Route definitions
└── .env                  # Environment variables
```
