#!/usr/bin/env bash
# ============================================
# LYNX-SPIDER-V1 - Test Script
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "🧪 LYNX-SPIDER-V1 Test Suite"
echo "============================="

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found"
    exit 1
fi

# Activate venv if exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Run tests
python3 test-commands.py "$@"

exit $?
