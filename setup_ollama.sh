#!/bin/bash

# Setup script for Ollama integration
# This script installs and configures Ollama for local AI development

echo "🚀 Setting up Ollama for Algo Trader Bot"
echo "========================================"

# Check if Ollama is already installed
if command -v ollama &> /dev/null; then
    echo "✅ Ollama is already installed"
    ollama --version
else
    echo "📥 Installing Ollama..."

    # Install Ollama
    curl -fsSL https://ollama.ai/install.sh | sh

    if [ $? -eq 0 ]; then
        echo "✅ Ollama installed successfully"
    else
        echo "❌ Failed to install Ollama"
        exit 1
    fi
fi

# Start Ollama service
echo "🔄 Starting Ollama service..."
ollama serve &
OLLAMA_PID=$!

# Wait for Ollama to start
echo "⏳ Waiting for Ollama to start..."
sleep 5

# Check if Ollama is running
if curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "✅ Ollama is running on http://localhost:11434"
else
    echo "❌ Failed to start Ollama service"
    exit 1
fi

# Pull recommended models
echo "📥 Pulling recommended models..."

echo "  - Pulling llama3.1 (recommended for trading analysis)..."
ollama pull llama3.1

echo "  - Pulling codellama (for code analysis)..."
ollama pull codellama

echo "  - Pulling mistral (alternative model)..."
ollama pull mistral

# Create environment file
echo "📝 Creating environment configuration..."
cat > .env.ollama << EOF
# Ollama Configuration
USE_OLLAMA=true
OLLAMA_URL=http://localhost:11434
OLLAMA_MODEL=llama3.1

# AI Client Configuration
AI_ENABLED=true
AI_CONFIDENCE_THRESHOLD=0.7
AI_ANALYSIS_INTERVAL=300
EOF

echo "✅ Environment configuration created in .env.ollama"

# Test Ollama connection
echo "🧪 Testing Ollama connection..."
if curl -s -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model": "llama3.1", "prompt": "Hello, respond with just: Connection successful", "stream": false}' | grep -q "Connection successful"; then
    echo "✅ Ollama connection test successful"
else
    echo "⚠️  Ollama connection test failed, but service is running"
fi

echo ""
echo "🎉 Ollama setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Copy .env.ollama to .env: cp .env.ollama .env"
echo "2. Start your Rails server: rails server"
echo "3. Test AI integration: ruby test_phase4_implementation.rb"
echo ""
echo "🔧 Available models:"
ollama list
echo ""
echo "💡 To stop Ollama: kill $OLLAMA_PID"
echo "💡 To restart Ollama: ollama serve"
