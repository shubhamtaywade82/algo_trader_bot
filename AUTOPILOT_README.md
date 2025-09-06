# Rails Algo Trader Bot - Complete Integration

This Rails application provides both LLM API endpoints for MCP integration and autopilot functionality with your external LLM agent.

## Architecture

```
Ollama + MCP (Windows) ←→ Rails API ←→ DhanHQ
         ↓                    ↓
    LLM Agent            Autopilot Services
    (Windows)            (Signal Processing)
```

## Components

1. **Rails API** - Provides `/llm/*` endpoints for MCP integration
2. **Autopilot** - Integrates with external LLM agent for signal processing
3. **DhanHQ** - Market data and order execution
4. **MCP Server** - Bridges Ollama to Rails API (external)
5. **LLM Agent** - Signal processing and plan generation (external)

## Quick Start

### 1. Configure Environment
```bash
# Update .env file with your agent URL
AGENT_URL=http://your-windows-machine:4000
PAPER_MODE=true
EXECUTE_ORDERS=false
```

### 2. Start Rails Server
```bash
rails server
```

The autopilot will automatically start in paper mode when Rails boots.

### 3. Test Integration
```bash
ruby test_rails_api.rb
```

## Environment Variables

```bash
# Trading Mode
PAPER_MODE=true              # Paper trading mode (default)
EXECUTE_ORDERS=false         # Disable real execution

# LLM Agent Configuration
AGENT_URL=http://172.20.240.1:3001  # Your Windows LLM agent URL

# No authentication required for local use

# DhanHQ API (update with your credentials)
DHAN_CLIENT_ID=your_id
DHAN_ACCESS_TOKEN=your_token
```

## Autopilot Services

### 1. AgentClient (`app/services/autopilot/agent_client.rb`)
- Communicates with your external LLM agent
- Sends signals and receives trading plans
- Executes plans (in live mode)
- Health checking

### 2. SignalProcessor (`app/services/autopilot/signal_processor.rb`)
- Processes trading signals
- Validates signal data
- Handles paper vs live mode execution
- Logging and notifications

### 3. Manager (`app/services/autopilot/manager.rb`)
- Manages autopilot lifecycle
- Starts/stops autopilot service
- Health monitoring
- Thread management

## API Endpoints

### LLM API (for MCP Integration)
- `GET /llm/funds` - Get available cash
- `GET /llm/positions` - Get open positions
- `GET /llm/orders` - Get order book
- `GET /llm/spot?underlying=NIFTY` - Get spot price
- `GET /llm/quote?securityId=256265` - Get quote data
- `GET /llm/option_chain?underlying=NIFTY&expiry=2024-01-25` - Get option chain
- `POST /llm/place_bracket_order` - Place bracket order
- `POST /llm/modify_order` - Modify order
- `POST /llm/cancel_order` - Cancel order

### Autopilot Management
- `GET /autopilot/status` - Get autopilot status
- `POST /autopilot/start` - Start autopilot
- `POST /autopilot/stop` - Stop autopilot
- `GET /autopilot/agent_health` - Check agent health

### Signal Processing
- `POST /autopilot/signal` - Send trading signal

### Example Signal
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

## Modes

### Paper Mode (Default)
- `PAPER_MODE=true`
- `EXECUTE_ORDERS=false`
- All trades are simulated
- Plans are logged but not executed
- Safe for testing

### Live Mode
- `PAPER_MODE=false`
- `EXECUTE_ORDERS=true`
- Real trades are executed
- Use with caution

## Integration with External Agent

The Rails app expects your LLM agent to provide these endpoints:

### Agent Endpoints
- `GET /health` - Health check
- `POST /signal` - Receive trading signals
- `POST /execute` - Execute trading plans

### Signal Format
```json
{
  "symbol": "NIFTY",
  "spot": 22490,
  "supertrend_15m": "bullish",
  "adx_15m": 32,
  "iv_percentile": 65,
  "session_time": "10:30"
}
```

### Plan Format (from agent)
```json
{
  "action": "BUY",
  "symbol": "NIFTY",
  "quantity": 1,
  "entry_price": 22500,
  "stop_loss": 22400,
  "take_profit": 22600,
  "trail_stop": 50
}
```

## Logging

### Paper Mode Logs
```
[PAPER_TRADE] {"timestamp":"2024-01-15T10:30:00Z","mode":"PAPER","signal":{...},"plan":{...}}
```

### Autopilot Logs
```
[Autopilot::Manager] Starting autopilot...
[Autopilot::SignalProcessor] Sending signal to agent: {...}
[Autopilot::AgentClient] Received plan from agent: {...}
```

## Testing

### Manual Testing
```bash
# Test LLM endpoints
curl http://localhost:3000/llm/funds
curl http://localhost:3000/llm/spot?underlying=NIFTY

# Test autopilot endpoints
curl http://localhost:3000/autopilot/agent_health
curl http://localhost:3000/autopilot/status

# Run comprehensive tests
ruby test_rails_api.rb
```

### Automated Testing
```bash
# Run all tests (LLM + Autopilot)
ruby test_rails_api.rb
```

## Troubleshooting

### Agent Connection Issues
- Check `AGENT_URL` is correct
- Ensure agent is running on Windows
- Test with: `curl http://your-agent-url/health`

### Autopilot Not Starting
- Check Rails logs for errors
- Verify agent health
- Check environment variables

### Paper Mode Not Working
- Verify `PAPER_MODE=true` in .env
- Check logs for paper trade entries
- Test with signal endpoint

## File Structure

```
app/
├── controllers/
│   └── autopilot_controller.rb      # API endpoints
├── services/autopilot/
│   ├── agent_client.rb              # Agent communication
│   ├── signal_processor.rb          # Signal processing
│   └── manager.rb                   # Autopilot management
config/
├── initializers/autopilot.rb        # Auto-start autopilot
└── routes.rb                        # API routes
test_autopilot.rb                    # Test script
.env                                 # Environment variables
```

## Next Steps

1. **Configure Agent URL**: Update `AGENT_URL` in `.env`
2. **Test Connection**: Run `ruby test_autopilot.rb`
3. **Start Trading**: Send signals via API
4. **Monitor Logs**: Watch for paper trades and agent communication
5. **Go Live**: Switch to live mode when ready

## Security Notes

- Change `LLM_API_KEY` from default value
- Use HTTPS for production
- Validate all signal data
- Monitor for suspicious activity
