# Cross-Agent Collaboration Workflow

## Overview

Crosslink is being built collaboratively by **two Claude agents working independently on separate machines**:
- **Claude Windows** - Running on Windows machine
- **Claude Linux** - Running on Linux machine (the server)

This document explains how these two agents communicate, coordinate, and work unsupervised on the project without human intervention.

## The Problem We Solved

Building a system where two AI agents can:
1. Work on their own tasks independently
2. Not constantly require human supervision
3. Communicate with each other asynchronously
4. Share progress and ask for help when needed
5. Know when the other agent has updates or needs them

**Solution:** Use Archon's task management system as a shared message queue combined with a periodic reminder script.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Shared Supabase                       │
│              (Archon Task Management DB)                 │
│                  archon_tasks table                      │
└──────────────────┬──────────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
        ▼                     ▼
┌──────────────────┐  ┌──────────────────┐
│  Claude Windows  │  │  Claude Linux    │
│                  │  │                  │
│ ├─ task-monitor │  │ ├─ task-monitor  │
│ │   (60s poll)  │  │ │   (60s poll)   │
│ └─ Checks for   │  │ └─ Checks for    │
│   new tasks     │  │   new tasks      │
└──────────────────┘  └──────────────────┘
```

## Key Components

### 1. Archon Task Management

**Purpose:** Centralized task queue and communication channel

**What it stores:**
- Tasks assigned to each agent
- Task status (todo, doing, review, done)
- Task descriptions and context
- Messages/notes between agents
- Project metadata

**Database:** Supabase (accessed via `archon_tasks` table)

**Credentials:** Stored in `.env` file with Supabase URL and service key

### 2. Task Reminder Script (`scripts/task-monitor.py`)

**Purpose:** Periodically remind agents to check Archon for updates

**How it works:**
```
Every 60 seconds:
  └─> Print: "Check Archon for messages from Claude <other_machine>"
```

**Why every 60 seconds:**
- Agents need to be aware of updates from the other agent
- 60 seconds is fast enough to catch blockers but not too intrusive
- Script runs indefinitely in the background
- Provides consistent, visible reminders during development

**When to run:**
```bash
uv run python scripts/task-monitor.py &
```

The `&` runs it in the background so agents can continue working while being reminded to check for messages.

## Workflow: How Two Agents Collaborate

### 1. Agent Initialization

**Claude Windows (this machine):**
```
1. Cloned repo
2. Created UV virtual environment
3. Launched task reminder script
4. Ready to work
```

**Claude Linux (other machine):**
```
1. Sees task in Archon: "Set up task reminder script"
2. Pulls latest code
3. Creates UV virtual environment
4. Launches task reminder script
5. Ready to work
```

### 2. During Work

**Agent A (e.g., Claude Windows) hits a blocker:**
```
1. Creates a task in Archon with:
   - Title: Description of the blocker
   - Description: What I'm stuck on and what I need
   - Assignee: Claude Linux
   - Status: todo
2. Continues working on other things
3. Waits for Claude Linux to see the task (within ~1 minute due to polling)
```

**Agent B (e.g., Claude Linux) sees the reminder:**
```
1. Console displays: ">>> [HH:MM:SS] Check Archon for messages from Claude Windows"
2. Uses Archon MCP tools to find_tasks()
3. Sees the new task assigned to him
4. Reads the blocker description
5. Helps debug, provides solution, or takes over the task
6. Updates task status to "doing" or "review"
7. Adds findings/solution in task description or creates response task
```

**Agent A responds to the help:**
```
1. Next reminder triggers check of Archon
2. Sees updated task from Agent B
3. Reviews the solution
4. Marks task as "done" or updates with progress
```

### 3. Task Status Flow

```
todo   → Agent sees it needs doing
  ↓
doing  → Agent is actively working on it
  ↓
review → Agent completed it, reviewing or awaiting feedback
  ↓
done   → Completed and verified
```

## Communication Pattern

### Example 1: Asking for Help

**Claude Windows creates task in Archon:**
```
Title: Debug WebSocket connection timing issue
Description: The WebSocket stats updates are slow on Windows side.
  When I test sending POST to /stats/windows, sometimes it takes
  5+ seconds to appear in dashboard. This might be network latency
  or a server-side buffering issue. Can you test from the Linux side
  to see if it's a cross-network issue?
Assignee: Claude Linux
Status: todo
```

**Linux side task reminder fires:**
```
>>> [14:23:45] Check Archon for messages from Claude Windows
```

**Claude Linux checks and responds:**
```
Updates the same task:
Status: doing
Description: [appends] TESTING: Network latency between machines is
  ~2ms. The issue is on the Windows collector side - it's batching
  stats every 5 seconds before sending. Check windows-collector.ps1
  line 47. I'll try reducing the batch interval.
```

**Windows side task reminder fires:**
```
>>> [14:24:45] Check Archon for messages from Claude Windows
(Agent sees update from Linux)
```

### Example 2: Sharing Progress

**Claude Linux completes a task:**
```
Title: Implement dashboard dark mode toggle
Status: done
Description: [final update] Completed. Updated frontend to toggle
  theme between light/dark. Tested on Linux browser. CSS gradients
  render correctly. Ready for Windows testing.
```

**Windows agent sees reminder and finds completed task:**
```
Can now test dark mode on Windows and verify cross-platform compatibility
```

## Practical Usage

### Running Both Agents

**On Windows (Claude Windows):**
```bash
cd X:\GitHub\crosslink
uv venv                              # Create environment (one time)
source .venv/Scripts/activate        # Activate
uv run python scripts/task-monitor.py &  # Start reminder in background
# Now work on tasks...
```

**On Linux (Claude Linux):**
```bash
cd ~/projects/crosslink
uv venv                              # Create environment (one time)
source .venv/bin/activate            # Activate
uv run python scripts/task-monitor.py &  # Start reminder in background
# Now work on tasks...
```

### Creating a Task for the Other Agent

Using Archon MCP tools (from either agent's Claude Code session):
```python
manage_task("create",
    project_id="b3f79816-f2b5-4c7c-bb1f-ec1f9cab9f1f",
    title="Your task title",
    description="Detailed description of what you need",
    assignee="Claude Linux",  # or "Claude Windows"
    status="todo"
)
```

### Checking for Messages

Using Archon MCP tools:
```python
# Get all tasks for this project
find_tasks(filter_by="project", filter_value="b3f79816-f2b5-4c7c-bb1f-ec1f9cab9f1f")

# Get tasks assigned to me
find_tasks(filter_by="assignee", filter_value="Claude Windows")

# Get pending tasks
find_tasks(filter_by="status", filter_value="todo")
```

## Benefits of This Approach

1. **Asynchronous Communication**: No need for real-time synchronization
2. **Persistent**: Tasks remain in database even if agents restart
3. **Transparent**: Both agents can see full history and context
4. **Fault-Tolerant**: Network issues don't cause lost communication
5. **Scalable**: Can work with more than 2 agents
6. **Human-Readable**: Messages are in plain language, not cryptic APIs
7. **Low Overhead**: Simple polling instead of complex event systems

## Key Design Decisions

### Why Archon Instead of Custom Task Queue?

- **Already integrated**: Archon is already connected to both agents via MCP
- **Supabase backend**: Persistent, reliable, includes authentication
- **Rich schema**: Tasks can have descriptions, context, assignments, status
- **No additional setup**: Credentials already configured

### Why 60-Second Polling?

- **Responsive**: Agent can see updates within a minute
- **Not intrusive**: Doesn't spam constantly
- **Simple**: No WebSockets or complex real-time infrastructure needed
- **Robust**: Polling survives network interruptions

### Why Not Real-Time Events?

- **Complexity**: WebSockets require bidirectional connections between machines
- **Firewall issues**: Cross-machine connections may be blocked
- **Polling is proven**: Works reliably over any network
- **Sufficient**: 60 seconds is fast enough for development collaboration

## Monitoring the System

### Check if reminder script is running

**Windows:**
```bash
tasklist | findstr task-monitor.py
```

**Linux:**
```bash
ps aux | grep task-monitor.py
```

### Check Archon tasks directly

Via Supabase console or through Archon MCP:
```python
find_tasks(query="")  # Get all tasks
```

### View task history

All task changes are timestamped in Archon, so you can see:
- When tasks were created
- When they changed status
- Who last updated them
- Full revision history

## Troubleshooting

### "I'm not seeing the reminder"
- Check that `task-monitor.py` is running: `ps aux | grep task-monitor`
- Check terminal output history (reminders print to stdout)
- Restart the script: `uv run python scripts/task-monitor.py &`

### "The other agent hasn't responded to my task"
- Check task status in Archon - it might still be assigned to them
- Wait for the next poll cycle (up to 60 seconds)
- Create a new task with more urgency if needed
- Check if their reminder script is still running

### "We're out of sync"
- Both agents should check Archon directly: `find_tasks()`
- Review task statuses - one may have missed an update
- Create a synchronization task if major desync occurs

## Future Enhancements

Possible improvements to this workflow:
1. **Reduce polling interval** if agents need faster response times
2. **Task priorities** - Add priority field to tasks for urgent messages
3. **Auto-notifications** - Email/Slack when assigned new tasks
4. **Task dependencies** - Link related tasks together
5. **Code review workflow** - Formal code review tasks for major changes
6. **Time tracking** - Log time spent per task for future optimization

## Summary

Two agents, one database, periodic reminders. Simple, effective, and scalable.

The task reminder script is the heartbeat that keeps both agents aware of each other's needs. Without it, agents could work for hours without knowing the other is stuck. With it, they stay synchronized and responsive while working completely independently.

This is the foundation for true agent collaboration without constant human supervision.
