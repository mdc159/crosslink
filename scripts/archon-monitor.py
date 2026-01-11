#!/usr/bin/env python3
"""Archon Task Monitor - Real-time updates via Supabase

Polls Archon tasks and alerts on changes. Useful for cross-agent communication.

Usage:
    uv run python Scripts/archon-monitor.py

Note: Auto-loads credentials from archon.env - no manual sourcing needed.
"""
import os
import sys
import time
from datetime import datetime
from pathlib import Path

# Auto-load Archon credentials from archon.env
try:
    from dotenv import load_dotenv
except ImportError:
    print("Installing python-dotenv...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "python-dotenv", "-q"])
    from dotenv import load_dotenv

# Load archon.env from repo root (Scripts/../archon.env)
archon_env = Path(__file__).parent.parent / "archon.env"
if archon_env.exists():
    load_dotenv(archon_env)
else:
    print(f"Warning: {archon_env} not found")

try:
    from supabase import create_client, Client
except ImportError:
    print("Installing supabase...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "supabase", "-q"])
    from supabase import create_client, Client

# Configuration - loaded from archon.env
SUPABASE_URL = os.getenv("SUPABASE_URL")  # Archon project URL
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY")  # Service key for reads
PROJECT_ID = "2f65621a-b676-40e4-be5d-e1cf27561d52"  # Karaoke Pipeline
POLL_INTERVAL = 15  # seconds

# Color codes for terminal
COLORS = {
    "reset": "\033[0m",
    "green": "\033[92m",
    "yellow": "\033[93m",
    "blue": "\033[94m",
    "red": "\033[91m",
    "bold": "\033[1m",
}

def colorize(text, color):
    return f"{COLORS.get(color, '')}{text}{COLORS['reset']}"

def format_task(task):
    """Format task for display"""
    status_colors = {
        "todo": "yellow",
        "doing": "blue",
        "review": "green",
        "done": "green",
    }
    status = task.get("status", "unknown")
    color = status_colors.get(status, "reset")

    assignee = task.get("assignee", "Unassigned")
    title = task.get("title", "No title")[:60]

    return f"[{colorize(status.upper(), color)}] [{assignee}] {title}"

def main():
    if not SUPABASE_URL or not SUPABASE_KEY:
        print(colorize("ERROR: Archon credentials not found!", "red"))
        print(f"Expected archon.env at: {archon_env}")
        print("Ensure archon.env exists with SUPABASE_URL and SUPABASE_SERVICE_KEY")
        sys.exit(1)

    print(colorize("=" * 60, "blue"))
    print(colorize("  Archon Task Monitor - Karaoke Pipeline", "bold"))
    print(colorize("=" * 60, "blue"))
    print(f"Polling every {POLL_INTERVAL}s. Press Ctrl+C to stop.\n")

    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    last_states = {}

    try:
        while True:
            try:
                result = supabase.table("archon_tasks").select("*").eq("project_id", PROJECT_ID).execute()

                for task in result.data:
                    task_id = task["id"]
                    updated_at = task.get("updated_at")

                    # Check if task changed
                    if task_id in last_states:
                        if last_states[task_id] != updated_at:
                            timestamp = datetime.now().strftime("%H:%M:%S")
                            print(f"\n{colorize('🔔 CHANGED', 'yellow')} [{timestamp}]", flush=True)
                            print(f"   {format_task(task)}", flush=True)

                            # Show description preview if it changed
                            desc = task.get("description", "")[:200]
                            if desc:
                                print(f"   {colorize('Preview:', 'blue')} {desc}...", flush=True)

                    last_states[task_id] = updated_at

                # Heartbeat
                sys.stdout.write(".")
                sys.stdout.flush()

            except Exception as e:
                print(colorize(f"\nError polling: {e}", "red"))

            time.sleep(POLL_INTERVAL)

    except KeyboardInterrupt:
        print(colorize("\n\nMonitor stopped.", "yellow"))

if __name__ == "__main__":
    main()
