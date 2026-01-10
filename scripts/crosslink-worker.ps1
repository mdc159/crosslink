# Crosslink Worker - Polls for tasks and displays them
# Run this in the background to receive tasks from other machines
# Includes retry logic for unreliable connections

$Server = "http://192.168.50.2:8888"
$MyMachine = "windows"
$PollInterval = 5
$MaxRetryInterval = 60
$RetryInterval = $PollInterval
$ConnectionOK = $false

Write-Host "============================================"
Write-Host "  Crosslink Worker - $MyMachine"
Write-Host "============================================"
Write-Host "  Server: $Server"
Write-Host "  Polling interval: ${PollInterval}s"
Write-Host "  Press Ctrl+C to stop"
Write-Host "============================================"
Write-Host ""

# Track tasks we've already notified about
$notifiedTasks = @{}

function Show-Status {
    param([string]$Status)
    $timestamp = Get-Date -Format "HH:mm:ss"
    if ($Status -eq "connected") {
        Write-Host "`r[$timestamp] Connected - waiting for tasks...          " -NoNewline -ForegroundColor Green
    } elseif ($Status -eq "disconnected") {
        Write-Host "`r[$timestamp] Disconnected - retrying in ${RetryInterval}s...   " -NoNewline -ForegroundColor Yellow
    }
}

while ($true) {
    try {
        $response = Invoke-RestMethod -Uri "$Server/tasks/pending/$MyMachine" -TimeoutSec 10 -ErrorAction Stop

        # Connection successful
        if (-not $ConnectionOK) {
            Write-Host ""
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Connected to $Server" -ForegroundColor Green
            $ConnectionOK = $true
            $RetryInterval = $PollInterval
        }

        Show-Status "connected"

        if ($response.pending_count -gt 0) {
            foreach ($task in $response.tasks) {
                # Only notify for new tasks
                if (-not $notifiedTasks.ContainsKey($task.id)) {
                    $notifiedTasks[$task.id] = $true

                    Write-Host ""
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "  NEW TASK RECEIVED!" -ForegroundColor Yellow
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "  From: $($task.from_machine)" -ForegroundColor Green
                    Write-Host "  Task ID: $($task.id)" -ForegroundColor White
                    Write-Host "  Prompt: $($task.prompt)" -ForegroundColor White
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "To respond, run:"
                    Write-Host "  .\scripts\crosslink-peer.ps1 respond $($task.id) 'your response'" -ForegroundColor Yellow
                    Write-Host ""

                    # Windows toast notification
                    try {
                        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
                        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
                        $textNodes = $template.GetElementsByTagName("text")
                        $textNodes.Item(0).AppendChild($template.CreateTextNode("Task from $($task.from_machine)")) | Out-Null
                        $textNodes.Item(1).AppendChild($template.CreateTextNode($task.prompt)) | Out-Null
                        $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
                        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Crosslink").Show($toast)
                    } catch {
                        # Toast notification failed, that's ok
                    }
                }
            }
        }
    } catch {
        # Connection failed
        if ($ConnectionOK) {
            Write-Host ""
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Connection lost to $Server" -ForegroundColor Red
            $ConnectionOK = $false
        }
        Show-Status "disconnected"

        # Exponential backoff (capped at MaxRetryInterval)
        Start-Sleep -Seconds $RetryInterval
        $RetryInterval = [Math]::Min($RetryInterval * 2, $MaxRetryInterval)
        continue
    }

    Start-Sleep -Seconds $PollInterval
}
