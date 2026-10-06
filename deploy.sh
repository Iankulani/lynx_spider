#!/usr/bin/env bash
# ============================================
# LYNX-SPIDER-V1 - Deployment Script
# ============================================

set -euo pipefail

ENVIRONMENT="${1:-production}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "🚀 Deploying LYNX-SPIDER-V1 to $ENVIRONMENT"
echo "============================================="

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(staging|production)$ ]]; then
    echo "❌ Invalid environment: $ENVIRONMENT"
    echo "Usage: $0 [staging|production]"
    exit 1
fi

# Check required files
for file in docker-compose.yml Dockerfile; do
    if [ ! -f "$file" ]; then
        echo "❌ Required file not found: $file"
        exit 1
    fi
done

# Load environment variables
if [ -f ".env.$ENVIRONMENT" ]; then
    echo "📄 Loading .env.$ENVIRONMENT"
    set -a
    source ".env.$ENVIRONMENT"
    set +a
elif [ -f ".env" ]; then
    echo "📄 Loading .env"
    set -a
    source ".env"
    set +a
fi

# Pull latest images
echo "📦 Pulling latest images..."
docker-compose pull

# Build if needed
echo "🔨 Building images..."
docker-compose build

# Deploy
echo "🚀 Starting services..."
docker-compose up -d --remove-orphans

# Wait for health check
echo "⏳ Waiting for services to be healthy..."
sleep 10

# Check status
echo "📊 Service status:"
docker-compose ps

# Verify
echo "🔍 Verifying deployment..."
if curl -s -f http://localhost:5000/api/stats > /dev/null 2>&1; then
    echo "✅ Deployment successful!"
    echo ""
    echo "🌐 Web Dashboard: http://localhost:5000"
    echo "📊 Grafana: http://localhost:3000"
    echo "📈 Prometheus: http://localhost:9091"
else
    echo "⚠️  Web dashboard not responding"
    echo "📋 Checking logs..."
    docker-compose logs --tail=50 lynx-spider
fi

echo ""
echo "✅ Deployment complete!"
