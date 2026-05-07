# OpenClaw Gateway Monitor - Independent Daemon
# Runs outside gateway process tree, auto-restarts gateway if down
# PID: uses lock file to prevent duplicate instances

$lockFile = "$env:USERPROFILE\.openclaw\gateway-monitor.lock"
$gatewayCmd = "$env:USERPROFILE\.openclaw\gateway.cmd"
$logFile = "$env:USERPROFILE\.openclaw\gateway-monitor.log"
$checkInterval = 10  # seconds

# Prevent duplicate instances
if (Test-Path $lockFile) {
    $oldPid = Get-Content $lockFile
    $oldProc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
    if ($oldProc -and $oldProc.ProcessName -eq "powershell") {
        Write-Host "Monitor already running (pid $oldPid)"
        exit 0
    }
}
$pid | Out-File -FilePath $lockFile -Force

function Log-Message {
    param($Msg)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

Log-Message "Monitor started (pid $pid). Checking gateway on port 18789 every ${checkInterval}s..."

while ($true) {
    $tcp = Test-NetConnection -ComputerName 127.0.0.1 -Port 18789 `
        -WarningAction SilentlyContinue -ErrorAction SilentlyContinue `
        -InformationLevel Quiet

    if (-not $tcp) {
        Log-Message "Gateway DOWN. Launching gateway.cmd..."
        schtasks /run /tn "OpenClaw Gateway" > $null 2>&1
        Start-Sleep -Seconds 5  # Give gateway time to start before next check
    }

    Start-Sleep -Seconds $checkInterval
}
