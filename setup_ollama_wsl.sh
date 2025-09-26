#!/bin/bash

# Setup script for Ollama integration with Windows WSL
# This script configures the Rails app to connect to Ollama running on Windows

echo "🚀 Setting up Ollama for Algo Trader Bot (Windows WSL)"
echo "====================================================="

# Detect Windows host IP
echo "🔍 Detecting Windows host IP..."
WINDOWS_IP=$(ip route show default | awk '/default/ {print $3}')
if [ -z "$WINDOWS_IP" ]; then
    echo "❌ Could not detect Windows host IP"
    echo "Please manually set OLLAMA_URL in your .env file"
    exit 1
fi

echo "✅ Windows host IP detected: $WINDOWS_IP"

# Test Ollama connection on Windows
echo "🧪 Testing Ollama connection on Windows..."
if curl -s "http://$WINDOWS_IP:11434/api/tags" > /dev/null; then
    echo "✅ Ollama is accessible on Windows at $WINDOWS_IP:11434"
    OLLAMA_URL="http://$WINDOWS_IP:11434"
else
    echo "⚠️  Ollama not accessible at $WINDOWS_IP:11434"
    echo "Please ensure Ollama is running on Windows and accessible from WSL"
    echo "You may need to:"
    echo "1. Start Ollama on Windows: ollama serve"
    echo "2. Check Windows Firewall settings"
    echo "3. Verify Ollama is listening on all interfaces"
    OLLAMA_URL="http://$WINDOWS_IP:11434"
fi

# Create environment file for WSL
echo "📝 Creating WSL environment configuration..."
cat > .env.wsl << EOF
# Ollama Configuration for WSL
USE_OLLAMA=true
OLLAMA_URL=$OLLAMA_URL
OLLAMA_MODEL=llama3.1

# AI Client Configuration
AI_ENABLED=true
AI_CONFIDENCE_THRESHOLD=0.7
AI_ANALYSIS_INTERVAL=300

# DhanHQ Configuration (keep existing)
DHAN_CLIENT_ID=your_client_id
DHAN_ACCESS_TOKEN=your_access_token
PAPER_MODE=true
EXECUTE_ORDERS=false

# Agent Configuration
AGENT_URL=http://localhost:3001
EOF

echo "✅ Environment configuration created in .env.wsl"

# Test AI client with Windows Ollama
echo "🧪 Testing AI client with Windows Ollama..."
if curl -s -X POST "$OLLAMA_URL/api/generate" \
  -H "Content-Type: application/json" \
  -d '{"model": "llama3.1", "prompt": "Hello, respond with just: Connection successful", "stream": false}' | grep -q "Connection successful"; then
    echo "✅ AI client test with Windows Ollama successful"
else
    echo "⚠️  AI client test failed, but Ollama is accessible"
fi

echo ""
echo "🎉 WSL Ollama setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Copy .env.wsl to .env: cp .env.wsl .env"
echo "2. Update your DhanHQ credentials in .env"
echo "3. Start your Rails server: rails server"
echo "4. Test AI integration: ruby test_phase4_implementation.rb"
echo ""
echo "🔧 Windows Ollama URLs to try:"
echo "  - http://$WINDOWS_IP:11434"
echo "  - http://localhost:11434 (if port forwarding is set up)"
echo ""
echo "💡 Troubleshooting:"
echo "  - Ensure Ollama is running on Windows: ollama serve"
echo "  - Check Windows Firewall allows port 11434"
echo "  - Verify WSL can access Windows network"
