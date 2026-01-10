#!/bin/bash
# Crosslink Worker - Polls for tasks and displays them
# Run this in the background to receive tasks from other machines
# Includes retry logic for unreliable connections

SERVER="http://192.168.50.2:8888"
MY_MACHINE="linux"
POLL_INTERVAL=5
MAX_RETRY_INTERVAL=60
RETRY_INTERVAL=$POLL_INTERVAL
CONNECTION_OK=false

echo "============================================"
echo "  Crosslink Worker - $MY_MACHINE"
echo "============================================"
echo "  Server: $SERVER"
echo "  Polling interval: ${POLL_INTERVAL}s"
echo "  Press Ctrl+C to stop"
echo "============================================"
echo ""

show_status() {
    local status=$1
    local timestamp=$(date '+%H:%M:%S')
    if [ "$status" = "connected" ]; then
        echo -ne "\r[$timestamp] Connected - waiting for tasks...          "
    elif [ "$status" = "disconnected" ]; then
        echo -ne "\r[$timestamp] Disconnected - retrying in ${RETRY_INTERVAL}s...   "
    fi
}

while true; do
    # Try to check for pending tasks
    RESPONSE=$(curl -s --connect-timeout 5 --max-time 10 "$SERVER/tasks/pending/$MY_MACHINE" 2>/dev/null)
    CURL_EXIT=$?

    if [ $CURL_EXIT -ne 0 ]; then
        # Connection failed
        if [ "$CONNECTION_OK" = true ]; then
            echo ""
            echo "[$(date '+%H:%M:%S')] Connection lost to $SERVER"
            CONNECTION_OK=false
        fi
        show_status "disconnected"

        # Exponential backoff (capped at MAX_RETRY_INTERVAL)
        sleep $RETRY_INTERVAL
        RETRY_INTERVAL=$((RETRY_INTERVAL * 2))
        if [ $RETRY_INTERVAL -gt $MAX_RETRY_INTERVAL ]; then
            RETRY_INTERVAL=$MAX_RETRY_INTERVAL
        fi
        continue
    fi

    # Connection successful
    if [ "$CONNECTION_OK" = false ]; then
        echo ""
        echo "[$(date '+%H:%M:%S')] Connected to $SERVER"
        CONNECTION_OK=true
        RETRY_INTERVAL=$POLL_INTERVAL
    fi

    show_status "connected"

    # Parse response
    COUNT=$(echo "$RESPONSE" | grep -o '"pending_count":[0-9]*' | cut -d':' -f2)

    if [ "$COUNT" != "0" ] && [ -n "$COUNT" ]; then
        echo ""
        echo ""
        echo "========================================"
        echo "  NEW TASK RECEIVED!"
        echo "========================================"

        # Extract task details
        TASK_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        PROMPT=$(echo "$RESPONSE" | grep -o '"prompt":"[^"]*"' | head -1 | cut -d'"' -f4)
        FROM=$(echo "$RESPONSE" | grep -o '"from_machine":"[^"]*"' | head -1 | cut -d'"' -f4)

        echo "  From: $FROM"
        echo "  Task ID: $TASK_ID"
        echo "  Prompt: $PROMPT"
        echo "========================================"
        echo ""
        echo "To respond, run:"
        echo "  ./scripts/crosslink-peer.sh respond $TASK_ID \"your response\""
        echo ""

        # Desktop notification (if available)
        if command -v notify-send &> /dev/null; then
            notify-send "Crosslink Task from $FROM" "$PROMPT"
        fi
    fi

    sleep $POLL_INTERVAL
done
