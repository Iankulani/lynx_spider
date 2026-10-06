#!/usr/bin/env bash
# ============================================
# LYNX-SPIDER-V1 - Setup Script
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🕷️ LYNX-SPIDER-V1 Setup"
echo "========================"

cd "$PROJECT_DIR"

# Create directories
echo "📁 Creating directories..."
mkdir -p .lynx_spider/{payloads,workspaces,scans,reports,phishing_pages,captured_credentials}
mkdir -p lynx_spider_reports
mkdir -p config/certs

# Copy secrets example
if [ ! -f secrets.yml ]; then
    if [ -f secrets.example.yml ]; then
        cp secrets.example.yml secrets.yml
        echo "⚠️  Created secrets.yml from example. Please edit it!"
    fi
fi

# Create .env file
if [ ! -f .env ]; then
    cat > .env << 'EOF'
# LYNX-SPIDER-V1 Environment Variables
LYNX_LOG_LEVEL=INFO
TZ=UTC

# Bot Tokens (optional)
DISCORD_TOKEN=
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
SLACK_BOT_TOKEN=
SLACK_APP_TOKEN=

# SMTP
SMTP_SERVER=
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=

# Web
WEB_SECRET_KEY=
WEB_USERNAME=admin
WEB_PASSWORD=

# Database
POSTGRES_USER=lynx
POSTGRES_PASSWORD=lynx_spider_2024
POSTGRES_DB=lynx_spider
REDIS_PASSWORD=lynx_redis_2024

# Grafana
GRAFANA_USER=admin
GRAFANA_PASSWORD=lynx_spider_2024
EOF
    echo "✅ Created .env file"
fi

# Generate secret key
if command -v openssl &> /dev/null; then
    SECRET_KEY=$(openssl rand -hex 32)
    sed -i "s/^WEB_SECRET_KEY=.*/WEB_SECRET_KEY=$SECRET_KEY/" .env 2>/dev/null || \
    sed -i '' "s/^WEB_SECRET_KEY=.*/WEB_SECRET_KEY=$SECRET_KEY/" .env 2>/dev/null || true
    echo "✅ Generated web secret key"
fi

# Set permissions
chmod +x install.sh
chmod +x docker/*.sh 2>/dev/null || true
chmod +x scripts/*.sh 2>/dev/null || true

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Edit secrets.yml and .env with your credentials"
echo "  2. Run: ./install.sh"
echo "  3. Or run: docker-compose up -d"
echo ""
