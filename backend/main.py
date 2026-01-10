"""
Crosslink - Backend API
Cross-platform system monitoring for Linux and Windows machines
"""

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Literal
from datetime import datetime
import asyncio
import psutil
import platform
import json
import uuid

app = FastAPI(title="Crosslink", version="1.0.0")


# =============================================================================
# TASK QUEUE - Agent-to-Agent Communication
# =============================================================================

class Task(BaseModel):
    prompt: str
    from_machine: Literal["linux", "windows"]
    to_machine: Literal["linux", "windows"]
    context: Optional[dict] = None  # Optional file paths, code snippets, etc.

class TaskResponse(BaseModel):
    task_id: str
    result: str
    error: Optional[str] = None

# In-memory task store
tasks: dict[str, dict] = {}


def create_task_id() -> str:
    return str(uuid.uuid4())[:8]

# Allow cross-origin requests from frontend and Windows
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Store latest stats from each machine
machine_stats = {
    "linux": None,
    "windows": None
}

# Connected WebSocket clients
connected_clients: list[WebSocket] = []


class MachineStats(BaseModel):
    machine_id: Optional[str] = "windows"
    hostname: Optional[str] = "Unknown"
    os: Optional[str] = "Unknown"
    cpu_percent: Optional[float] = 0
    memory_total_gb: Optional[float] = 0
    memory_used_gb: Optional[float] = 0
    memory_percent: Optional[float] = 0
    disk_total_gb: Optional[float] = 0
    disk_used_gb: Optional[float] = 0
    disk_percent: Optional[float] = 0
    network_sent_mb: Optional[float] = 0
    network_recv_mb: Optional[float] = 0
    uptime_hours: Optional[float] = 0
    timestamp: Optional[str] = None
    ip_address: Optional[str] = None

    class Config:
        extra = "allow"  # Allow extra fields from Windows


def get_linux_stats() -> MachineStats:
    """Collect current Linux system stats"""
    net_io = psutil.net_io_counters()
    disk = psutil.disk_usage('/')
    mem = psutil.virtual_memory()
    uptime = (datetime.now() - datetime.fromtimestamp(psutil.boot_time())).total_seconds() / 3600

    return MachineStats(
        machine_id="linux",
        hostname=platform.node(),
        os=f"{platform.system()} {platform.release()}",
        cpu_percent=psutil.cpu_percent(interval=0.1),
        memory_total_gb=round(mem.total / (1024**3), 2),
        memory_used_gb=round(mem.used / (1024**3), 2),
        memory_percent=mem.percent,
        disk_total_gb=round(disk.total / (1024**3), 2),
        disk_used_gb=round(disk.used / (1024**3), 2),
        disk_percent=disk.percent,
        network_sent_mb=round(net_io.bytes_sent / (1024**2), 2),
        network_recv_mb=round(net_io.bytes_recv / (1024**2), 2),
        uptime_hours=round(uptime, 2),
        timestamp=datetime.now().isoformat(),
        ip_address="192.168.50.2"
    )


@app.get("/")
async def root():
    return {
        "service": "Dual Machine Monitor",
        "version": "1.0.0",
        "machines": list(machine_stats.keys()),
        "status": "running"
    }


@app.get("/stats")
async def get_all_stats():
    """Get latest stats from all machines"""
    # Always refresh Linux stats
    machine_stats["linux"] = get_linux_stats().model_dump()
    return machine_stats


@app.get("/stats/linux")
async def get_linux_stats_endpoint():
    """Get current Linux stats"""
    stats = get_linux_stats()
    machine_stats["linux"] = stats.model_dump()
    return stats


@app.post("/stats/windows")
async def receive_windows_stats(stats: dict):
    """Receive stats from Windows machine - accepts any JSON format"""
    # Handle nested structure from OpenCode Windows collector
    normalized = {
        'machine_id': 'windows',
        'hostname': stats.get('hostname', 'Windows PC'),
        'os': 'Windows 11',
        'ip_address': '192.168.50.1',
        'timestamp': stats.get('timestamp', datetime.now().isoformat()),
    }

    # Handle CPU - could be nested or flat
    if 'cpu' in stats and isinstance(stats['cpu'], dict):
        normalized['cpu_percent'] = stats['cpu'].get('usage', 0)
    else:
        normalized['cpu_percent'] = stats.get('cpu_percent', 0)

    # Handle Memory - could be nested or flat
    if 'memory' in stats and isinstance(stats['memory'], dict):
        mem = stats['memory']
        normalized['memory_total_gb'] = round(mem.get('total', 0) / (1024**3), 2)
        normalized['memory_used_gb'] = round(mem.get('used', 0) / (1024**3), 2)
        normalized['memory_percent'] = mem.get('usage', 0)
    else:
        normalized['memory_total_gb'] = stats.get('memory_total_gb', 0)
        normalized['memory_used_gb'] = stats.get('memory_used_gb', 0)
        normalized['memory_percent'] = stats.get('memory_percent', 0)

    # Handle Disk - could be nested or flat
    if 'disk' in stats and isinstance(stats['disk'], dict):
        disk = stats['disk']
        normalized['disk_total_gb'] = round(disk.get('total', 0) / (1024**3), 2)
        normalized['disk_used_gb'] = round(disk.get('used', 0) / (1024**3), 2)
        normalized['disk_percent'] = disk.get('usage', 0)
    else:
        normalized['disk_total_gb'] = stats.get('disk_total_gb', 0)
        normalized['disk_used_gb'] = stats.get('disk_used_gb', 0)
        normalized['disk_percent'] = stats.get('disk_percent', 0)

    # Handle Network - could be nested or flat
    if 'network' in stats and isinstance(stats['network'], dict):
        net = stats['network']
        normalized['network_sent_mb'] = round(net.get('sent', 0) / (1024**2), 2)
        normalized['network_recv_mb'] = round(net.get('received', 0) / (1024**2), 2)
    else:
        normalized['network_sent_mb'] = stats.get('network_sent_mb', 0)
        normalized['network_recv_mb'] = stats.get('network_recv_mb', 0)

    # Handle Uptime - could be nested or flat
    if 'uptime' in stats and isinstance(stats['uptime'], dict):
        normalized['uptime_hours'] = round(stats['uptime'].get('seconds', 0) / 3600, 2)
    else:
        normalized['uptime_hours'] = stats.get('uptime_hours', 0)

    machine_stats["windows"] = normalized

    # Broadcast to all connected WebSocket clients
    await broadcast_stats()

    return {"status": "received", "machine": "windows", "data": normalized}


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket for real-time updates"""
    await websocket.accept()
    connected_clients.append(websocket)

    try:
        while True:
            # Send current stats every 2 seconds
            machine_stats["linux"] = get_linux_stats().model_dump()
            await websocket.send_json(machine_stats)
            await asyncio.sleep(2)
    except WebSocketDisconnect:
        connected_clients.remove(websocket)


async def broadcast_stats():
    """Send stats to all connected clients"""
    for client in connected_clients:
        try:
            await client.send_json(machine_stats)
        except:
            pass


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "linux_stats": machine_stats["linux"] is not None,
        "windows_stats": machine_stats["windows"] is not None,
        "connected_clients": len(connected_clients)
    }


# =============================================================================
# TASK QUEUE ENDPOINTS
# =============================================================================

@app.post("/tasks")
async def create_task(task: Task):
    """Submit a task for another machine's agent to handle"""
    task_id = create_task_id()
    tasks[task_id] = {
        "id": task_id,
        "prompt": task.prompt,
        "from_machine": task.from_machine,
        "to_machine": task.to_machine,
        "context": task.context,
        "status": "pending",
        "result": None,
        "error": None,
        "created_at": datetime.now().isoformat(),
        "completed_at": None
    }
    return {"task_id": task_id, "status": "pending"}


@app.get("/tasks/pending/{machine}")
async def get_pending_tasks(machine: str):
    """Get all pending tasks assigned to a machine"""
    pending = [
        t for t in tasks.values()
        if t["to_machine"] == machine and t["status"] == "pending"
    ]
    return {"machine": machine, "pending_count": len(pending), "tasks": pending}


@app.get("/tasks/{task_id}")
async def get_task(task_id: str):
    """Get status and result of a specific task"""
    if task_id not in tasks:
        raise HTTPException(status_code=404, detail="Task not found")
    return tasks[task_id]


@app.post("/tasks/{task_id}/complete")
async def complete_task(task_id: str, response: TaskResponse):
    """Mark a task as complete with result"""
    if task_id not in tasks:
        raise HTTPException(status_code=404, detail="Task not found")

    tasks[task_id]["status"] = "completed"
    tasks[task_id]["result"] = response.result
    tasks[task_id]["error"] = response.error
    tasks[task_id]["completed_at"] = datetime.now().isoformat()

    return {"status": "completed", "task_id": task_id}


@app.get("/tasks")
async def list_all_tasks():
    """List all tasks (for debugging)"""
    return {
        "total": len(tasks),
        "pending": len([t for t in tasks.values() if t["status"] == "pending"]),
        "completed": len([t for t in tasks.values() if t["status"] == "completed"]),
        "tasks": list(tasks.values())
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8888)
