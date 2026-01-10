#!/bin/bash
# Crosslink CLI - Agent-to-Agent Communication
# Usage:
#   crosslink send <to_machine> "prompt"    - Send task to other machine
#   crosslink check                          - Check for pending tasks
#   crosslink respond <task_id> "result"    - Respond to a task
#   crosslink status <task_id>              - Check task status

SERVER="http://192.168.50.2:8888"
MY_MACHINE="linux"  # Change to "windows" on Windows

case "$1" in
    send)
        TO_MACHINE="$2"
        PROMPT="$3"

        if [ -z "$TO_MACHINE" ] || [ -z "$PROMPT" ]; then
            echo "Usage: crosslink send <linux|windows> \"your prompt\""
            exit 1
        fi

        RESPONSE=$(curl -s -X POST "$SERVER/tasks" \
            -H "Content-Type: application/json" \
            -d "{\"prompt\": \"$PROMPT\", \"from_machine\": \"$MY_MACHINE\", \"to_machine\": \"$TO_MACHINE\"}")

        TASK_ID=$(echo "$RESPONSE" | grep -o '"task_id":"[^"]*"' | cut -d'"' -f4)
        echo "Task sent: $TASK_ID"
        echo "$RESPONSE"
        ;;

    check)
        RESPONSE=$(curl -s "$SERVER/tasks/pending/$MY_MACHINE")
        COUNT=$(echo "$RESPONSE" | grep -o '"pending_count":[0-9]*' | cut -d':' -f2)

        if [ "$COUNT" = "0" ]; then
            echo "No pending tasks"
        else
            echo "Found $COUNT pending task(s):"
            echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
        fi
        ;;

    respond)
        TASK_ID="$2"
        RESULT="$3"

        if [ -z "$TASK_ID" ] || [ -z "$RESULT" ]; then
            echo "Usage: crosslink respond <task_id> \"result\""
            exit 1
        fi

        RESPONSE=$(curl -s -X POST "$SERVER/tasks/$TASK_ID/complete" \
            -H "Content-Type: application/json" \
            -d "{\"task_id\": \"$TASK_ID\", \"result\": \"$RESULT\"}")

        echo "Response sent:"
        echo "$RESPONSE"
        ;;

    status)
        TASK_ID="$2"

        if [ -z "$TASK_ID" ]; then
            echo "Usage: crosslink status <task_id>"
            exit 1
        fi

        curl -s "$SERVER/tasks/$TASK_ID" | python3 -m json.tool 2>/dev/null
        ;;

    list)
        curl -s "$SERVER/tasks" | python3 -m json.tool 2>/dev/null
        ;;

    *)
        echo "Crosslink CLI - Agent Communication"
        echo ""
        echo "Commands:"
        echo "  send <machine> \"prompt\"   Send task to linux or windows"
        echo "  check                      Check for tasks assigned to me"
        echo "  respond <id> \"result\"     Complete a task with result"
        echo "  status <id>                Check status of a task"
        echo "  list                       List all tasks"
        ;;
esac
