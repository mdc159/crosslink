#!/bin/bash
# Crosslink - Startup Script
# Starts backend API with task queue and serves frontend

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================"
echo "  Crosslink - Cross-Machine Agent Bridge"
echo "============================================"
echo ""

# Check if venv exists, create if not
if [ ! -d "venv" ]; then
    echo "[1/3] Creating virtual environment..."
    uv venv venv
fi

# Install dependencies
echo "[2/3] Installing dependencies..."
source venv/bin/activate
uv pip install -r backend/requirements.txt -q

# Start the server
echo "[3/3] Starting server..."
echo ""
echo "============================================"
echo "  SERVICES"
echo "============================================"
echo "  Dashboard:   http://192.168.50.2:8888"
echo "  API:         http://192.168.50.2:8888/stats"
echo "  Task Queue:  http://192.168.50.2:8888/tasks"
echo "  WebSocket:   ws://192.168.50.2:8888/ws"
echo ""
echo "  TASK QUEUE ENDPOINTS"
echo "  POST /tasks              - Submit task"
echo "  GET  /tasks/pending/{m}  - Poll for tasks"
echo "  POST /tasks/{id}/complete - Return result"
echo "============================================"
echo ""
echo "On Windows, clone repo and run collector:"
echo "  git clone https://github.com/mdc159/crosslink.git"
echo "  powershell -File scripts/windows-collector.ps1"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Serve frontend files and run API
cd backend
python -c "
import uvicorn
from fastapi.staticfiles import StaticFiles
from main import app

# Mount frontend at /dashboard to avoid conflict with API routes
app.mount('/dashboard', StaticFiles(directory='../frontend', html=True), name='frontend')

uvicorn.run(app, host='0.0.0.0', port=8888)
"
