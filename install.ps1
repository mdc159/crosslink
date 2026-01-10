# Crosslink - Windows Install Script
# Creates a desktop shortcut

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $DesktopPath "Crosslink.lnk"

Write-Host "Installing Crosslink desktop shortcut..."

# Create shortcut
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = Join-Path $ScriptDir "start-peer.bat"
$Shortcut.WorkingDirectory = $ScriptDir
$Shortcut.Description = "Crosslink - Cross-Machine Agent Bridge"
$Shortcut.Save()

Write-Host "Done! Crosslink shortcut added to your desktop."
Write-Host ""
Write-Host "Double-click the shortcut to:"
Write-Host "  1. Open the dashboard in your browser"
Write-Host "  2. Start sending stats to Linux"
