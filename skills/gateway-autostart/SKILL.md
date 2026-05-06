# Gateway 自动重启 & 开机自启动配置指南

## ⚠️ 重要说明（2026-05-07 更新）

**之前对 Windows 计划任务的 `RestartCount` 参数理解有误！**

❌ **错误理解：** `RestartCount: 3` 代表 Gateway 进程崩溃后自动重启 3 次

✅ **正确理解：** `RestartCount: 3` 只是**计划任务本身执行失败时重试 3 次**，跟进程死活没关系！

进程死了就是死了，计划任务根本不会管！感谢实际测试发现了这个问题！

---

## 正确的自动重启方案（经过实测验证）

### 方案 A：进程监控脚本（推荐，简单有效）

这是真正能实现 "网关死掉自动拉起来" 的方案，经过实测验证。

#### 第一步：创建监控脚本

创建 `gateway-monitor.ps1` 文件：

```powershell
# OpenClaw Gateway Process Monitor
# Auto restart gateway if process dies

$taskName = "OpenClaw Gateway"
$checkInterval = 10
$logFile = "C:\Users\$env:USERNAME\.openclaw\workspace\gateway-monitor.log"

function Write-Log {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] $message" | Out-File -Append $logFile -Encoding UTF8
    Write-Output "[$timestamp] $message"
}

Write-Log "Gateway monitor started, check interval: $checkInterval seconds"

while ($true) {
    $gatewayProcess = Get-Process -Name "node" -ErrorAction SilentlyContinue | 
                        Where-Object { $_.Path -like "*openclaw*" }
    
    if (-not $gatewayProcess) {
        Write-Log "WARNING: Gateway process not found, restarting..."
        try {
            Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
            Write-Log "SUCCESS: Gateway restarted!"
        } catch {
            Write-Log "ERROR: Restart failed: $_"
        }
    }
    
    Start-Sleep $checkInterval
}
```

#### 第二步：后台运行脚本

打开 PowerShell 执行：

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\Users\$env:USERNAME\.openclaw\workspace\gateway-monitor.ps1"
```

窗口最小化放后台即可。

#### 第三步（可选）：设置开机自动运行脚本

1. `Win+R` → 输入 `taskschd.msc` 打开任务计划程序
2. 创建新任务：
   - 触发器：**开机时**
   - 操作：**启动程序** → 程序/脚本填 `powershell.exe`
   - 添加参数：`-ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Users\$env:USERNAME\.openclaw\workspace\gateway-monitor.ps1"`
   - 勾选：**不管用户是否登录都要运行**
   - 勾选：**隐藏**

---

### 方案 B：注册成 Windows 服务（更专业，适合服务器）

适合需要长期稳定运行的场景，用 NSSM 把 Gateway 注册成真正的 Windows 服务。

1. 下载 NSSM：https://nssm.cc/download
2. 执行：
   ```bash
   nssm install OpenClawGateway
   ```
3. 在弹出的窗口里配置：
   - Path：选 `openclaw.exe` 的完整路径
   - Arguments：填 `gateway start`
4. 在 Windows 服务管理器里设置 "崩溃后自动重启"

---

## 计划任务配置（还是需要的，给脚本调用）

虽然计划任务本身不会监控进程，但我们还是需要它来启动 Gateway：

1. 确保已有 `OpenClaw Gateway` 计划任务（OpenClaw 安装时自动创建的）
2. 确认触发器是 "开机时"
3. `RestartCount` 保持 3 次就好，只是备用机制

---

## 验证方法

部署完成后可以这样测试：

1. 运行监控脚本
2. 执行 `openclaw gateway restart` 杀掉网关
3. 观察 10 秒内网关会不会自动回来
4. 如果会话自动恢复了，说明监控脚本工作正常！

---

## 优缺点对比

| 方案 | 优点 | 缺点 |
|------|------|------|
| **方案 A（监控脚本） | ✅ 简单，1 分钟搞定<br>✅ 不需要额外软件<br>✅ 出错了看日志方便 | ❌ 多一个后台进程<br>❌ 脚本本身崩溃了就失效 |
| **方案 B（Windows 服务） | ✅ 专业稳定，Windows 原生管理<br>✅ 服务崩溃自动重启是内置功能<br>✅ 不需要额外脚本 | ❌ 需要下载 NSSM<br>❌ 配置稍微复杂一点 |

---

## 版本历史

- **v1.1 (2026-05-07)**：重大修正！澄清了计划任务 `RestartCount` 的真实作用，添加真正的进程监控脚本
- **v1.0 (2026-05-07)**：初始版本

---

**欢迎提交 PR 优化！如果发现文档有错误，欢迎指出，一起改进！**
