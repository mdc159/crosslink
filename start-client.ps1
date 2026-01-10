# Crosslink Windows Launcher
# Starts stats collector and opens dashboard

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LinuxIP = "192.168.50.2"

Write-Host "============================================"
Write-Host "  Crosslink - Windows Client"
Write-Host "============================================"
Write-Host ""

# Check connection to Linux server
Write-Host "Checking connection to Linux server..."
$connected = Test-Connection -ComputerName $LinuxIP -Count 1 -Quiet

if (-not $connected) {
    Write-Host "ERROR: Cannot reach Linux server at $LinuxIP" -ForegroundColor Red
    Write-Host "Make sure:"
    Write-Host "  1. Ethernet cable is connected"
    Write-Host "  2. Windows IP is set to 192.168.50.1"
    Write-Host "  3. Linux Crosslink server is running"
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Connected to Linux server!" -ForegroundColor Green
Write-Host ""

# Start OpenCode server if not already running
$openCodeRunning = $false
try {
    $null = Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 2 -ErrorAction Stop
    $openCodeRunning = $true
    Write-Host "OpenCode already running" -ForegroundColor Green
} catch {
    Write-Host "Starting OpenCode server..."
    Start-Process -FilePath "opencode" -ArgumentList "serve", "--port", "8080" -WindowStyle Minimized
    Start-Sleep -Seconds 3
}

# Open dashboard in browser (on Linux server)
Write-Host "Opening Crosslink dashboard..."
Start-Process "http://${LinuxIP}:8888/dashboard"

# Open Windows' own OpenCode (localhost)
Write-Host "Opening Windows OpenCode..."
Start-Process "http://localhost:8080"

# Start stats collector in background
Write-Host "Starting stats collector..."
Write-Host ""
Write-Host "============================================"
Write-Host "  Crosslink is running!"
Write-Host "============================================"
Write-Host "  Dashboard:    http://${LinuxIP}:8888/dashboard"
Write-Host "  OpenCode:     http://localhost:8080"
Write-Host "  Task Queue:   http://${LinuxIP}:8888/tasks"
Write-Host ""
Write-Host "  Sending stats every 2 seconds..."
Write-Host ""
Write-Host "  Press Ctrl+C to stop"
Write-Host "============================================"
Write-Host ""

# Run the collector
& "$ScriptDir\scripts\windows-collector.ps1"
