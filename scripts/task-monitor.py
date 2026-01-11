#!/usr/bin/env python3
"""Task Reminder - Periodic reminder to check Archon for messages

Runs every minute to remind you to check Archon for messages and tasks
from Claude Lennox. This ensures unsupervised agents stay synchronized.

Usage:
    uv run python scripts/task-monitor.py

Or after activating venv:
    python scripts/task-monitor.py
"""
import sys
import time
from datetime import datetime

# Color codes for terminal
COLORS = {
    "reset": "\033[0m",
    "yellow": "\033[93m",
    "blue": "\033[94m",
    "bold": "\033[1m",
}


def colorize(text: str, color: str) -> str:
    """Add color to terminal text"""
    return f"{COLORS.get(color, '')}{text}{COLORS['reset']}"


def main():
    print(colorize("=" * 70, "blue"))
    print(colorize("  Archon Task Reminder - Claude Crosslink Monitor", "bold"))
    print(colorize("=" * 70, "blue"))
    print("Reminding every 60s to check Archon for messages from Claude Lennox.")
    print("Press Ctrl+C to stop.\n")

    POLL_INTERVAL = 60  # seconds

    try:
        while True:
            time.sleep(POLL_INTERVAL)
            timestamp = datetime.now().strftime("%H:%M:%S")
            print(colorize(f"\n>>> [{timestamp}] Check Archon for messages from Claude Lennox", "yellow"))
            sys.stdout.flush()

    except KeyboardInterrupt:
        print(colorize("\n\nReminder stopped.", "blue"))
        sys.exit(0)


if __name__ == "__main__":
    main()
