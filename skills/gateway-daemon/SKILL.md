---
name: gateway-daemon
description: Deploy an independent Windows daemon that monitors OpenClaw Gateway (port 18789) and auto-restarts it when down, with desktop-visible gateway window via scheduled task. Use when gateway keeps dying after `openclaw gateway restart`, or when the user wants zero-touch gateway auto-recovery on Windows. Triggers on: gateway crash, gateway restart fails, gateway won't auto-recover, need gateway monitor/daemon, gateway window not visible after restart.
---

# Gateway Daemon

Deploy an independent Windows daemon that keeps OpenClaw Gateway running 24/7 with automatic crash recovery and desktop-visible console window.

## Architecture

```
gateway-monitor.ps1 (daemon, Session-agnostic)
    │  polls port 18789 every 10s
    ▼
  Gateway down?
    │
    ▼ YES
schtasks /run "OpenClaw Gateway"
    │  runs in user's interactive session
    ▼
gateway.cmd → node gateway.exe (VISIBLE window on desktop)
```

**Key design decisions:**

- Monitor runs as **independent PowerShell process** outside the gateway's process tree — survives `gateway restart` or crash
- Uses `schtasks /run` (not `Start-Process`) to launch gateway — avoids Windows Session 0 isolation where spawned windows are invisible
- Registry Run key ensures monitor auto-starts on Windows login
- Lock file prevents duplicate monitor instances
- Logs all restart events with timestamps

## When to Use

1. Gateway does not auto-recover after `openclaw gateway restart`
2. Gateway cmd window disappears after restart
3. Need zero-touch gateway recovery on crash or restart
4. Setting up a new Windows OpenClaw installation and want service reliability

## Setup (One-time)

Run the setup script with PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup-monitor.ps1
```

Optional parameters:
- `-GatewayCmd "path\to\gateway.cmd"` — custom gateway script path (default: `~/.openclaw/gateway.cmd`)
- `-CheckInterval 15` — poll interval in seconds (default: 10)

What it does:
1. Deploys `gateway-monitor.ps1` to the workspace
2. Configures gateway path and check interval
3. Registers auto-start via Windows Registry Run key
4. Starts the monitor immediately
5. Verifies monitor is running

## Manual Control

| Action | Command |
|--------|---------|
| Check status | `openclaw gateway status` |
| View monitor log | `type ~\.openclaw\gateway-monitor.log` |
| Kill & restart monitor | Kill the PowerShell process (pid in `~\.openclaw\gateway-monitor.lock`) and re-run setup script |
| Remove startup entry | Delete `OpenClawGatewayMonitor` from `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run` |

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Gateway window not visible | Process spawned from Session 0 | Ensure monitor uses `schtasks /run` (not `Start-Process`); run setup script again |
| Duplicate gateway instances | Old scheduled task also launching | Check `schtasks /query /tn "OpenClaw Gateway"` |
| Monitor not starting | Registry Run key disabled | Manually run: `powershell -File ~\.openclaw\workspace\gateway-monitor.ps1` |
| Monitor log shows repeated "DOWN" | Gateway crashing immediately | Check `openclaw doctor`, review gateway error logs |

## Pre-requisites

- Windows with PowerShell 5.1+
- Existing `\OpenClaw Gateway` scheduled task pointing to `gateway.cmd`
- `Test-NetConnection` available (built into Windows 8+/Server 2012+)
