# OpenClaw Gateway Daemon - Setup Script
# Installs the independent gateway monitor that auto-restarts when down
# Run: powershell -ExecutionPolicy Bypass -File setup-monitor.ps1

param(
    [string]$GatewayCmd = "$env:USERPROFILE\.openclaw\gateway.cmd",
    [int]$CheckInterval = 10
)

$ErrorActionPreference = "Stop"
$workspaceDir = "$env:USERPROFILE\.openclaw\workspace"
$monitorScript = Join-Path $workspaceDir "gateway-monitor.ps1"
$skillScriptsDir = Split-Path $MyInvocation.MyCommand.Path

Write-Host "=== OpenClaw Gateway Daemon Setup ==="
Write-Host ""

# 1. Deploy monitor script
Write-Host "[1/4] Deploying gateway-monitor.ps1 to $workspaceDir..."
if (-not (Test-Path $workspaceDir)) {
    New-Item -ItemType Directory -Path $workspaceDir -Force | Out-Null
}
Copy-Item -Path (Join-Path $skillScriptsDir "gateway-monitor.ps1") -Destination $monitorScript -Force
Write-Host "  -> Deployed."

# 2. Update monitor script paths
Write-Host "[2/4] Configuring paths in monitor script..."
$content = Get-Content $monitorScript -Raw
$content = $content -replace '\$gatewayCmd = ".*"', "`$gatewayCmd = `"$GatewayCmd`""
$content = $content -replace '\$checkInterval = \d+', "`$checkInterval = $CheckInterval"
$content | Set-Content $monitorScript -Encoding utf8
Write-Host "  -> Gateway cmd: $GatewayCmd"
Write-Host "  -> Check interval: ${CheckInterval}s"

# 3. Register Windows startup (HKCU Run)
Write-Host "[3/4] Registering startup entry..."
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "OpenClawGatewayMonitor"
$regValue = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$monitorScript`""
Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force
Write-Host "  -> Registered: $regName"

# 4. Start monitor now
Write-Host "[4/4] Starting monitor..."

# Kill existing monitor if running
$lockFile = "$env:USERPROFILE\.openclaw\gateway-monitor.lock"
if (Test-Path $lockFile) {
    $oldPid = Get-Content $lockFile
    Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
    Write-Host "  -> Killed old monitor (pid $oldPid)"
}

Start-Process powershell.exe `
    -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$monitorScript`"" `
    -WindowStyle Hidden

Start-Sleep -Seconds 3

# Verify
if (Test-Path $lockFile) {
    $newPid = Get-Content $lockFile
    Write-Host "  -> Monitor running (pid $newPid)"
} else {
    Write-Host "  -> WARNING: Monitor may not have started. Check $env:USERPROFILE\.openclaw\gateway-monitor.log"
}

Write-Host ""
Write-Host "=== Setup Complete ==="
Write-Host "Monitor will auto-start on Windows login."
Write-Host "Log: $env:USERPROFILE\.openclaw\gateway-monitor.log"
