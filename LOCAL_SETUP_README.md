# Local Rails Algo Trader Bot Setup

This Rails application is configured for local development with live DhanHQ data integration and no API authentication requirements.

## 🚀 Quick Start

```bash
# 1. Configure DhanHQ credentials in .env
# 2. Start Rails server
rails server

# 3. Test all endpoints with live data
ruby test_live_data.rb
```

## 🔧 Configuration

### Environment Variables (`.env`)
```bash
# Trading Mode
PAPER_MODE=true              # Paper trading (default)
EXECUTE_ORDERS=false         # No real execution

# LLM Agent
AGENT_URL=http://172.20.240.1:3001

# DhanHQ (REQUIRED - live data)
DHAN_CLIENT_ID=your_dhan_client_id
DHAN_ACCESS_TOKEN=your_dhan_access_token

# Rails
RAILS_ENV=development
```

## 📡 API Endpoints (No Authentication Required)

### LLM Endpoints
- `GET /llm/funds` - Available cash
- `GET /llm/positions` - Open positions
- `GET /llm/orders` - Order book
- `GET /llm/spot?underlying=NIFTY` - Spot price
- `GET /llm/quote?securityId=256265` - Quote data
- `GET /llm/option_chain?underlying=NIFTY&expiry=2024-01-25` - Option chain
- `POST /llm/place_bracket_order` - Place bracket order (paper mode)

### Autopilot Endpoints
- `GET /autopilot/status` - Autopilot status
- `POST /autopilot/start` - Start autopilot
- `POST /autopilot/stop` - Stop autopilot
- `GET /autopilot/agent_health` - Check agent health
- `POST /autopilot/signal` - Send trading signal

## 🧪 Testing

### Test All Endpoints
```bash
# Test with live DhanHQ data
ruby test_live_data.rb

# Alternative test scripts
ruby test_no_auth.rb
ruby test_rails_api.rb
```

### Test Individual Endpoints
```bash
# LLM endpoints
curl http://localhost:3000/llm/funds
curl http://localhost:3000/llm/spot?underlying=NIFTY

# Autopilot endpoints
curl http://localhost:3000/autopilot/status
curl http://localhost:3000/autopilot/agent_health
```

### Send Test Signal
```bash
curl -X POST http://localhost:3000/autopilot/signal \
  -H "Content-Type: application/json" \
  -d '{
    "signal": {
      "symbol": "NIFTY",
      "spot": 22490,
      "supertrend_15m": "bullish",
      "adx_15m": 32,
      "iv_percentile": 65,
      "session_time": "10:30"
    }
  }'
```

## 🔄 Modes

### Paper Mode (Default)
- All trades are simulated
- Uses live DhanHQ data for market information
- Safe for development and testing

### Live Mode (When Ready)
```bash
# In .env file
PAPER_MODE=false
EXECUTE_ORDERS=true
# Keep your DhanHQ credentials
DHAN_CLIENT_ID=your_actual_id
DHAN_ACCESS_TOKEN=your_actual_token
```

## 🏗️ Architecture

```
Your MCP/LLM Agent (Windows) ←→ Rails API ←→ DhanHQ (Live Data)
         ↓                           ↓
    Signal Processing          Live Market Data
```

## 📁 Key Files

- `app/controllers/llm_controller.rb` - LLM API endpoints
- `app/controllers/autopilot_controller.rb` - Autopilot management
- `app/services/autopilot/` - Autopilot services
- `test_live_data.rb` - Live data testing script
- `test_no_auth.rb` - General testing script

## 🔍 Troubleshooting

### DhanHQ Connection Issues
- **REQUIRED**: Set valid DHAN_CLIENT_ID and DHAN_ACCESS_TOKEN in .env
- Check DhanHQ API credentials are correct
- Verify network connectivity to api.dhan.co
- All endpoints require live DhanHQ connection

### Agent Connection Issues
- Check `AGENT_URL` in .env
- Ensure your LLM agent is running
- Test with: `curl http://172.20.240.1:3001/health`

### Rails Server Issues
- Check port 3000 is available
- Run: `rails server`
- Check logs: `tail -f log/development.log`

## 🎯 Next Steps

1. **Start Rails**: `rails server`
2. **Test API**: `ruby test_no_auth.rb`
3. **Connect MCP**: Point your MCP server to `http://localhost:3000`
4. **Connect Agent**: Set `AGENT_URL` to your LLM agent
5. **Go Live**: Switch to live mode when ready

## 🔒 Security Notes

- **No authentication** - Only use locally
- **Paper mode** - No real money at risk
- **Live data** - Real market data from DhanHQ
- **Local only** - Not for production deployment

This setup is perfect for local development and testing with your MCP and LLM agent integration using live market data!
