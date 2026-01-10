#!/bin/bash
# Crosslink Worker - Polls for tasks and displays them
# Run this in the background to receive tasks from other machines

SERVER="http://192.168.50.2:8888"
MY_MACHINE="linux"
POLL_INTERVAL=5

echo "============================================"
echo "  Crosslink Worker - $MY_MACHINE"
echo "============================================"
echo "  Polling for tasks every ${POLL_INTERVAL}s..."
echo "  Press Ctrl+C to stop"
echo "============================================"
echo ""

while true; do
    # Check for pending tasks
    RESPONSE=$(curl -s "$SERVER/tasks/pending/$MY_MACHINE")
    COUNT=$(echo "$RESPONSE" | grep -o '"pending_count":[0-9]*' | cut -d':' -f2)

    if [ "$COUNT" != "0" ] && [ -n "$COUNT" ]; then
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
        echo "  ./scripts/crosslink-cli.sh respond $TASK_ID \"your response\""
        echo ""

        # Desktop notification (if available)
        if command -v notify-send &> /dev/null; then
            notify-send "Crosslink Task from $FROM" "$PROMPT"
        fi
    fi

    sleep $POLL_INTERVAL
done
