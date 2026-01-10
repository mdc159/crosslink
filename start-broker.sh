#!/bin/bash
# Crosslink One-Click Launcher
# Starts Docker container and opens web interfaces

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================"
echo "  Crosslink - Starting..."
echo "============================================"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Starting Docker..."
    sudo systemctl start docker
    sleep 3
fi

# Stop any existing container
docker compose down 2>/dev/null

# Build and start container
echo "Starting Crosslink container..."
docker compose up -d --build

# Wait for container to be healthy
echo "Waiting for server to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:8888/health > /dev/null 2>&1; then
        echo "Server is ready!"
        break
    fi
    sleep 1
done

# Start OpenCode if not already running
if curl -s http://localhost:8080 > /dev/null 2>&1; then
    echo "OpenCode already running"
else
    echo "Starting OpenCode server..."
    nohup opencode serve --port 8080 > /tmp/opencode.log 2>&1 &
    sleep 3
fi

# Start task worker in background
echo "Starting task worker..."
nohup "$SCRIPT_DIR/scripts/crosslink-worker.sh" > /tmp/crosslink-worker.log 2>&1 &
WORKER_PID=$!

# Open web interfaces
echo "Opening web interfaces..."
sleep 1

# Open Crosslink Dashboard
xdg-open "http://localhost:8888/dashboard" 2>/dev/null &

# Open OpenCode
xdg-open "http://localhost:8080" 2>/dev/null &

echo ""
echo "============================================"
echo "  Crosslink Broker is running!"
echo "============================================"
echo "  Dashboard:  http://localhost:8888/dashboard"
echo "  Task Queue: http://localhost:8888/tasks"
echo "  OpenCode:   http://localhost:8080"
echo ""
echo "  Background processes:"
echo "    - Broker (Docker container)"
echo "    - Task worker (PID: $WORKER_PID)"
echo "    - OpenCode server"
echo ""
echo "  To stop all:"
echo "    docker compose down"
echo "    kill $WORKER_PID"
echo "============================================"
