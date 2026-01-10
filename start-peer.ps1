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

# Start task worker in background
Write-Host "Starting task worker..."
Start-Job -ScriptBlock {
    param($ScriptDir, $Server)
    $MyMachine = "windows"
    $notifiedTasks = @{}

    while ($true) {
        try {
            $response = Invoke-RestMethod -Uri "$Server/tasks/pending/$MyMachine" -TimeoutSec 10
            if ($response.pending_count -gt 0) {
                foreach ($task in $response.tasks) {
                    if (-not $notifiedTasks.ContainsKey($task.id)) {
                        $notifiedTasks[$task.id] = $true
                        Write-Host "`n======== NEW TASK from $($task.from_machine) ========" -ForegroundColor Yellow
                        Write-Host "ID: $($task.id)" -ForegroundColor Cyan
                        Write-Host "Prompt: $($task.prompt)" -ForegroundColor White
                        Write-Host "Respond: .\scripts\crosslink-peer.ps1 respond $($task.id) 'your response'" -ForegroundColor Green
                    }
                }
            }
        } catch {}
        Start-Sleep -Seconds 5
    }
} -ArgumentList $ScriptDir, "http://${LinuxIP}:8888" | Out-Null

# Start stats collector in background
Write-Host "Starting stats collector..."
Start-Job -ScriptBlock {
    param($ScriptDir)
    & "$ScriptDir\scripts\windows-collector.ps1"
} -ArgumentList $ScriptDir | Out-Null

Write-Host ""
Write-Host "============================================"
Write-Host "  Crosslink Peer is running!"
Write-Host "============================================"
Write-Host "  Dashboard:    http://${LinuxIP}:8888/dashboard"
Write-Host "  OpenCode:     http://localhost:8080"
Write-Host "  Task Queue:   http://${LinuxIP}:8888/tasks"
Write-Host ""
Write-Host "  Background jobs running:"
Write-Host "    - Task worker (polling every 5s)"
Write-Host "    - Stats collector (sending every 2s)"
Write-Host ""
Write-Host "  Press Enter to stop all jobs and exit"
Write-Host "============================================"
Write-Host ""

# Wait for user input, periodically check jobs for output
while (-not [Console]::KeyAvailable) {
    # Show any job output
    Get-Job | Receive-Job 2>$null
    Start-Sleep -Milliseconds 500
}

# Cleanup on exit
Read-Host | Out-Null
Write-Host "Stopping jobs..."
Get-Job | Stop-Job
Get-Job | Remove-Job
Write-Host "Goodbye!"
