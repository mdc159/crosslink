"""
Crosslink Database - SQLite persistence for task queue
"""

import sqlite3
import json
from datetime import datetime
from pathlib import Path
from typing import Optional, List

# Database file location - persists across restarts
# Uses /app/data in Docker (volume mounted) or ./data locally
DATA_DIR = Path("/app/data") if Path("/app/data").exists() else Path(__file__).parent / "data"
DATA_DIR.mkdir(exist_ok=True)
DB_PATH = DATA_DIR / "crosslink.db"


def get_connection():
    """Get database connection with row factory"""
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    """Initialize database tables"""
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS tasks (
            id TEXT PRIMARY KEY,
            prompt TEXT NOT NULL,
            from_machine TEXT NOT NULL,
            to_machine TEXT NOT NULL,
            context TEXT,
            status TEXT DEFAULT 'pending',
            result TEXT,
            error TEXT,
            created_at TEXT NOT NULL,
            completed_at TEXT
        )
    ''')

    conn.commit()
    conn.close()


def create_task(task_id: str, prompt: str, from_machine: str, to_machine: str,
                context: Optional[dict] = None) -> dict:
    """Create a new task"""
    conn = get_connection()
    cursor = conn.cursor()

    created_at = datetime.now().isoformat()
    context_json = json.dumps(context) if context else None

    cursor.execute('''
        INSERT INTO tasks (id, prompt, from_machine, to_machine, context, status, created_at)
        VALUES (?, ?, ?, ?, ?, 'pending', ?)
    ''', (task_id, prompt, from_machine, to_machine, context_json, created_at))

    conn.commit()
    conn.close()

    return {
        "id": task_id,
        "prompt": prompt,
        "from_machine": from_machine,
        "to_machine": to_machine,
        "context": context,
        "status": "pending",
        "result": None,
        "error": None,
        "created_at": created_at,
        "completed_at": None
    }


def get_task(task_id: str) -> Optional[dict]:
    """Get a task by ID"""
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute('SELECT * FROM tasks WHERE id = ?', (task_id,))
    row = cursor.fetchone()
    conn.close()

    if row:
        return row_to_dict(row)
    return None


def get_pending_tasks(machine: str) -> List[dict]:
    """Get all pending tasks for a machine"""
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute('''
        SELECT * FROM tasks
        WHERE to_machine = ? AND status = 'pending'
        ORDER BY created_at ASC
    ''', (machine,))

    rows = cursor.fetchall()
    conn.close()

    return [row_to_dict(row) for row in rows]


def complete_task(task_id: str, result: str, error: Optional[str] = None) -> bool:
    """Mark a task as complete"""
    conn = get_connection()
    cursor = conn.cursor()

    completed_at = datetime.now().isoformat()

    cursor.execute('''
        UPDATE tasks
        SET status = 'completed', result = ?, error = ?, completed_at = ?
        WHERE id = ?
    ''', (result, error, completed_at, task_id))

    success = cursor.rowcount > 0
    conn.commit()
    conn.close()

    return success


def get_all_tasks() -> dict:
    """Get all tasks with counts"""
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute('SELECT * FROM tasks ORDER BY created_at DESC')
    rows = cursor.fetchall()

    tasks = [row_to_dict(row) for row in rows]
    pending = len([t for t in tasks if t["status"] == "pending"])
    completed = len([t for t in tasks if t["status"] == "completed"])

    conn.close()

    return {
        "total": len(tasks),
        "pending": pending,
        "completed": completed,
        "tasks": tasks
    }


def row_to_dict(row: sqlite3.Row) -> dict:
    """Convert database row to dictionary"""
    d = dict(row)
    # Parse context JSON if present
    if d.get("context"):
        try:
            d["context"] = json.loads(d["context"])
        except:
            pass
    return d


# Initialize database on module load
init_db()
