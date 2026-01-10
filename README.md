# Crosslink

Cross-platform system monitoring dashboard for Linux and Windows machines connected over LAN.

**Built collaboratively by AI agents on two machines working together.**

## Features

- Real-time CPU, Memory, Disk, Network monitoring
- WebSocket-based live updates
- Side-by-side comparison of both machines
- Works over direct ethernet connection (no router needed)
- Beautiful dark-themed dashboard

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Crosslink                            │
├─────────────────────────────────────────────────────────────┤
│  Linux (192.168.50.2)          Windows (192.168.50.1)       │
│  ├── FastAPI Backend (:8888)    ├── Stats Collector         │
│  ├── WebSocket Server           └── POST → /stats/windows   │
│  ├── Frontend Dashboard                                      │
│  └── Linux Stats Collector                                   │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### On Linux (Server)

```bash
# Clone and start
cd ~/projects/crosslink
./start.sh

# Access dashboard at http://localhost:8888
```

### On Windows (Client)

Set static IP: `192.168.50.1` / `255.255.255.0`

Then run the collector:
```powershell
powershell -ExecutionPolicy Bypass -File scripts/windows-collector.ps1
```

Or access the dashboard at: `http://192.168.50.2:8888`

## Network Setup

| Machine | IP Address | Subnet | Role |
|---------|------------|--------|------|
| Linux | 192.168.50.2 | 255.255.255.0 | Server |
| Windows | 192.168.50.1 | 255.255.255.0 | Client |

### Linux Network Config
```bash
sudo nmcli connection modify "Wired connection 1" ipv4.method manual ipv4.addresses 192.168.50.2/24
sudo nmcli connection up "Wired connection 1"
```

### Windows Network Config
1. Settings → Network & Internet → Ethernet
2. Edit IP assignment → Manual → IPv4 On
3. IP: 192.168.50.1, Subnet: 255.255.255.0

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Service info |
| `/stats` | GET | All machine stats |
| `/stats/linux` | GET | Linux stats only |
| `/stats/windows` | POST | Receive Windows stats |
| `/ws` | WebSocket | Real-time updates |
| `/health` | GET | Health check |

## Project Structure

```
crosslink/
├── backend/
│   ├── main.py           # FastAPI server
│   └── requirements.txt  # Python dependencies
├── frontend/
│   └── index.html        # Dashboard UI
├── scripts/
│   └── windows-collector.ps1  # Windows stats collector
├── start.sh              # Linux startup script
└── README.md
```

## Dependencies

- Python 3.12+
- FastAPI
- uvicorn
- psutil
- pydantic
- websockets

## Development

```bash
# Create virtual environment
uv venv venv
source venv/bin/activate

# Install dependencies
uv pip install -r backend/requirements.txt

# Run server
cd backend && python main.py
```

## License

MIT

---

*Built with AI-powered collaboration between Linux and Windows machines.*
