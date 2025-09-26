# DhanHQ Connection Troubleshooting

## Error: `Faraday::ConnectionFailed Failed to open TCP connection to api.dhan.co:443`

This error occurs when your Rails application cannot connect to the DhanHQ API. Here are the solutions:

## Quick Fix: Enable Mock Mode

The easiest solution is to enable mock mode, which provides realistic test data without requiring DhanHQ connectivity:

```bash
# In your .env file
DHAN_MOCK_MODE=true
```

Then restart Rails:
```bash
rails server
```

## Root Causes & Solutions

### 1. **Network Connectivity Issues**

**Problem**: Cannot resolve `api.dhan.co` domain
**Solutions**:
```bash
# Test DNS resolution
nslookup api.dhan.co

# Test connectivity
ping api.dhan.co

# Check if you're behind a corporate firewall
curl -I https://api.dhan.co
```

### 2. **Missing DhanHQ Credentials**

**Problem**: No API credentials configured
**Solutions**:
```bash
# Add to .env file
DHAN_CLIENT_ID=your_dhan_client_id
DHAN_ACCESS_TOKEN=your_dhan_access_token
DHAN_MOCK_MODE=false
```

### 3. **DhanHQ Service Down**

**Problem**: DhanHQ API is temporarily unavailable
**Solutions**:
- Check DhanHQ status page
- Enable mock mode temporarily
- Retry later

### 4. **Firewall/Proxy Issues**

**Problem**: Corporate firewall blocking API calls
**Solutions**:
- Configure proxy settings
- Whitelist `api.dhan.co:443`
- Use mock mode for development

## Mock Mode Features

When `DHAN_MOCK_MODE=true`, the API provides:

### **Realistic Test Data**
- **Funds**: ₹1,00,000 available cash
- **Positions**: Empty (no open positions)
- **Orders**: Empty (no pending orders)
- **Spot Prices**: NIFTY around 22,490 ± random variation
- **Quotes**: Realistic bid/ask spreads
- **Option Chains**: Generated mock chain with multiple strikes

### **API Responses Include Notes**
```json
{
  "available": 100000.0,
  "note": "Mock data - DhanHQ unavailable"
}
```

## Testing Mock Mode

```bash
# Test all endpoints with mock data
ruby test_mock_mode.rb

# Test specific endpoint
curl http://localhost:3000/llm/funds
```

## Switching Between Modes

### **Enable Mock Mode** (for development/testing)
```bash
# .env file
DHAN_MOCK_MODE=true
# Comment out or remove DhanHQ credentials
# DHAN_CLIENT_ID=...
# DHAN_ACCESS_TOKEN=...
```

### **Enable Real DhanHQ** (for production)
```bash
# .env file
DHAN_MOCK_MODE=false
DHAN_CLIENT_ID=your_actual_client_id
DHAN_ACCESS_TOKEN=your_actual_access_token
```

## Environment Variables Reference

```bash
# Trading Mode
PAPER_MODE=true              # Paper trading (no real orders)
EXECUTE_ORDERS=false         # Disable order execution

# DhanHQ Configuration
DHAN_MOCK_MODE=true          # Use mock data (no API calls)
# DHAN_CLIENT_ID=your_id     # Real DhanHQ credentials
# DHAN_ACCESS_TOKEN=your_token

# No authentication required for local use

# LLM Agent
AGENT_URL=http://172.20.240.1:3001
```

## Logs to Check

### **Rails Logs**
```bash
tail -f log/development.log | grep -i dhan
```

### **Common Log Messages**
```
[LLM::Funds] Error: Failed to open TCP connection to api.dhan.co:443
[LLM::Funds] Using mock data - DhanHQ unavailable
```

## Production Considerations

1. **Always test with mock mode first**
2. **Set up proper DhanHQ credentials for production**
3. **Implement proper error handling and fallbacks**
4. **Monitor API connectivity and switch to mock mode if needed**

## Support

If you continue to have issues:

1. **Check DhanHQ documentation** for API status
2. **Verify your credentials** are correct and active
3. **Test network connectivity** to `api.dhan.co:443`
4. **Use mock mode** for development and testing
5. **Contact DhanHQ support** for API-specific issues

## Mock Data Examples

### **Funds Response**
```json
{
  "available": 100000.0,
  "note": "Mock data - DhanHQ unavailable"
}
```

### **Spot Price Response**
```json
{
  "symbol": "NIFTY",
  "spot": 22490.0,
  "note": "Mock data - DhanHQ unavailable"
}
```

### **Option Chain Response**
```json
{
  "underlying": "NIFTY",
  "expiry": "2024-01-25",
  "chain": {
    "22400": {
      "ce": {"ltp": 90.0, "bid": 85.0, "ask": 95.0},
      "pe": {"ltp": 10.0, "bid": 8.0, "ask": 12.0}
    }
  },
  "note": "Mock data - DhanHQ unavailable"
}
```
