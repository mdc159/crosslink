# Windows System Stats Collector
# Sends stats to Linux backend every 5 seconds
# Run this on your Windows 11 PC

$LinuxServer = "http://192.168.50.2:8888"
$Interval = 5  # seconds

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Dual Machine Monitor - Windows Agent" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sending stats to: $LinuxServer" -ForegroundColor Yellow
Write-Host "Interval: ${Interval}s" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host ""

function Get-SystemStats {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $net = Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface |
           Select-Object -First 1
    $comp = Get-CimInstance Win32_ComputerSystem

    $bootTime = $os.LastBootUpTime
    $uptime = (Get-Date) - $bootTime

    $memTotal = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $memFree = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $memUsed = [math]::Round($memTotal - $memFree, 2)
    $memPercent = [math]::Round(($memUsed / $memTotal) * 100, 1)

    $diskTotal = [math]::Round($disk.Size / 1GB, 2)
    $diskFree = [math]::Round($disk.FreeSpace / 1GB, 2)
    $diskUsed = [math]::Round($diskTotal - $diskFree, 2)
    $diskPercent = [math]::Round(($diskUsed / $diskTotal) * 100, 1)

    @{
        machine_id = "windows"
        hostname = $comp.Name
        os = "Windows $($os.Version)"
        cpu_percent = (Get-CimInstance Win32_Processor).LoadPercentage
        memory_total_gb = $memTotal
        memory_used_gb = $memUsed
        memory_percent = $memPercent
        disk_total_gb = $diskTotal
        disk_used_gb = $diskUsed
        disk_percent = $diskPercent
        network_sent_mb = [math]::Round($net.BytesSentPersec / 1MB, 2)
        network_recv_mb = [math]::Round($net.BytesReceivedPersec / 1MB, 2)
        uptime_hours = [math]::Round($uptime.TotalHours, 2)
        timestamp = (Get-Date).ToString("o")
        ip_address = "192.168.50.1"
    }
}

while ($true) {
    try {
        $stats = Get-SystemStats
        $json = $stats | ConvertTo-Json -Depth 3

        $response = Invoke-RestMethod -Uri "$LinuxServer/stats/windows" `
                                       -Method Post `
                                       -Body $json `
                                       -ContentType "application/json"

        $time = Get-Date -Format "HH:mm:ss"
        Write-Host "[$time] Sent: CPU $($stats.cpu_percent)% | RAM $($stats.memory_percent)% | Disk $($stats.disk_percent)%" -ForegroundColor Green
    }
    catch {
        Write-Host "[$time] Error: $($_.Exception.Message)" -ForegroundColor Red
    }

    Start-Sleep -Seconds $Interval
}
