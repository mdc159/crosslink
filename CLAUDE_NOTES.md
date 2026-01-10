# Claude Code Session Notes - Crosslink Project

## Current Status (2026-01-10)

### Completed
1. SQLite persistence for task queue - tasks survive restarts
2. Docker volume mount for database persistence
3. Retry logic with exponential backoff in all workers
4. All scripts updated and pushed to repo

### In Progress
**Building MCP server for OpenCode integration** - so agents can automatically handle tasks instead of manual copy/paste

### The Goal
Make Claude Code on Linux and Windows able to automatically communicate through the Crosslink task queue without human copy/paste intervention.

## Architecture
- **Broker (Linux)**: Runs Crosslink server in Docker on port 8888
- **Peer (Windows)**: Connects to broker, runs OpenCode on port 8080
- **Task Queue API**:
  - POST /tasks - create task
  - GET /tasks/pending/{machine} - get pending tasks
  - POST /tasks/{task_id}/complete - respond to task
  - GET /tasks/{task_id} - check task status

## Next Steps
1. User is restarting Claude Code to connect Archon MCP
2. Once MCP is connected, use Crosslink to communicate with Windows Claude Code
3. Build/configure MCP server so OpenCode can automatically:
   - Poll for incoming tasks
   - Execute prompts from other machines
   - Send responses back

## Key Files
- `backend/main.py` - FastAPI server with task queue
- `backend/database.py` - SQLite persistence
- `scripts/crosslink-worker.ps1` - Windows task worker (manual)
- `scripts/crosslink-peer.ps1` - Windows CLI for responding

## Test Command
Send task to Windows:
```bash
curl -s -X POST http://localhost:8888/tasks -H "Content-Type: application/json" -d '{"prompt": "YOUR MESSAGE", "from_machine": "linux", "to_machine": "windows"}' | jq .
```

Check for responses:
```bash
curl -s http://localhost:8888/tasks | jq .
```
