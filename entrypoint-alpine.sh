#!/bin/sh
# ============================================
# LYNX-SPIDER-V1 - Alpine Docker Entrypoint
# ============================================

set -e

echo "🕷️ Starting LYNX-SPIDER-V1 (Alpine)..."

# Create directories
mkdir -p /app/.lynx_spider/{payloads,workspaces,scans,reports}
mkdir -p /app/lynx_spider_reports
mkdir -p /var/log/lynx_spider

# Set permissions
chown -R lynx:lynx /app/.lynx_spider /app/lynx_spider_reports /var/log/lynx_spider 2>/dev/null || true

# Initialize configuration
if [ ! -f /app/.lynx_spider/config.json ]; then
    echo "📝 Creating default configuration..."
    cat > /app/.lynx_spider/config.json << 'EOF'
{
    "version": "1.0.0",
    "web": {
        "enabled": true,
        "port": 5000,
        "host": "0.0.0.0"
    }
}
EOF
fi

# Environment
export LYNX_HOME="${LYNX_HOME:-/app}"
export LYNX_CONFIG_DIR="${LYNX_CONFIG_DIR:-/app/.lynx_spider}"

echo "🚀 Starting application..."
exec "$@"
