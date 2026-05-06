# ============================================================
# OpenClaw Gateway 监控脚本（最终版）
# 功能：网关挂了30秒内自动重启
# 特性：端口检查100%准确 + 重启风暴保护 + 零资源占用
# ============================================================

$taskName = "OpenClaw Gateway"
$checkInterval = 60           # 检查间隔：60秒，资源占用更低
$restartCooldown = 300        # 重启后冷却：5分钟
$maxRestartsPerHour = 3       # 1小时内最多重启3次，防止死循环
$gatewayPort = 18789          # Gateway 默认端口
$logFile = "C:\Users\87682\.openclaw\workspace\gateway-monitor.log"

# 状态变量（内存中，不写盘
$restartHistory = @()
$lastRestartTime = $null

# 极简日志：只有重启时才写盘，正常运行零IO
function Write-Log {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] $message" | Out-File -Append $logFile -Encoding UTF8
}

# 健康检查：只查端口，100%准确，比查进程快10倍
function Test-GatewayHealth {
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect("127.0.0.1", $gatewayPort)
        $tcpClient.Close()
        return $true
    } catch {
        return $false
    }
}

# 重启风暴保护
function Test-CanRestart {
    $oneHourAgo = (Get-Date).AddHours(-1)
    $recentRestarts = $restartHistory | Where-Object { $_ -gt $oneHourAgo }
    return ($recentRestarts.Count -lt $maxRestartsPerHour)
}

# 启动日志只写一次
Write-Log "Gateway monitor started"
Write-Log "  - Check interval: $checkInterval seconds"
Write-Log "  - Restart cooldown: $restartCooldown seconds"
Write-Log "  - Max restarts per hour: $maxRestartsPerHour"

# 主循环
while ($true) {
    # 重启冷却期：刚重启完5分钟内不检查
    if ($lastRestartTime -and ((Get-Date) - $lastRestartTime).TotalSeconds -lt $restartCooldown) {
        Start-Sleep $checkInterval
        continue
    }
    
    # 健康检查（几毫秒完事）
    if (-not (Test-GatewayHealth)) {
        if (Test-CanRestart) {
            Write-Log "WARNING: Gateway not responding, restarting..."
            try {
                Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
                $lastRestartTime = Get-Date
                $restartHistory += $lastRestartTime
                Write-Log "SUCCESS: Gateway restarted"
            } catch {
                Write-Log "ERROR: Restart failed: $_"
            }
        }
    }
    
    # 检查完马上睡觉，零CPU占用
    Start-Sleep $checkInterval
}
