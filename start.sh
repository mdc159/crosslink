#!/bin/bash
# Dual Machine Monitor - Startup Script
# Starts both backend API and serves frontend

cd /home/hammer/projects/dual-machine-monitor

echo "============================================"
echo "  🖥️  Dual Machine Monitor"
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
echo "  Dashboard: http://192.168.50.2:8888"
echo "  API:       http://192.168.50.2:8888/stats"
echo "  WebSocket: ws://192.168.50.2:8888/ws"
echo "============================================"
echo ""
echo "On Windows, run:"
echo "  powershell -ExecutionPolicy Bypass -File scripts/windows-collector.ps1"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Serve frontend files and run API
cd backend
python -c "
import uvicorn
from fastapi.staticfiles import StaticFiles
from main import app

# Mount frontend
app.mount('/', StaticFiles(directory='../frontend', html=True), name='frontend')

uvicorn.run(app, host='0.0.0.0', port=8888)
"
