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

# Open web interfaces
echo "Opening web interfaces..."
sleep 1

# Open Crosslink Dashboard
xdg-open "http://localhost:8888/dashboard" 2>/dev/null &

# Open OpenCode (if running)
if curl -s http://localhost:8080 > /dev/null 2>&1; then
    xdg-open "http://localhost:8080" 2>/dev/null &
fi

echo ""
echo "============================================"
echo "  Crosslink is running!"
echo "============================================"
echo "  Dashboard:  http://localhost:8888/dashboard"
echo "  Task Queue: http://localhost:8888/tasks"
echo "  OpenCode:   http://localhost:8080"
echo ""
echo "  To stop: docker compose down"
echo "============================================"
