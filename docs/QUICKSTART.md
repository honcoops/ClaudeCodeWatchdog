# Quick Start Guide - Claude Code Watchdog

Get up and running with Claude Code Watchdog in less than 15 minutes!

---

## Table of Contents

- [What You'll Need](#what-youll-need)
- [Installation](#installation)
- [Configuration](#configuration)
- [First Project](#first-project)
- [Running the Watchdog](#running-the-watchdog)
- [Verifying It Works](#verifying-it-works)
- [Next Steps](#next-steps)
- [Troubleshooting](#troubleshooting)

---

## What You'll Need

Before starting, ensure you have:

✅ **Windows 10/11** (required for Windows MCP)
✅ **PowerShell 7.0+** - [Download here](https://github.com/PowerShell/PowerShell)
✅ **Claude API Key** - [Get one here](https://console.anthropic.com/)
✅ **Windows MCP Server** - Configured and running
✅ **Git** - With SSH or HTTPS configured
✅ **Chrome Browser** - For Claude Code sessions

**Check your PowerShell version:**
```powershell
$PSVersionTable.PSVersion
# Should show 7.0 or higher
```

---

## Installation

### Step 1: Clone the Repository

```powershell
# Navigate to your preferred directory
cd C:\repos

# Clone the repository
git clone https://github.com/honcoops/ClaudeCodeWatchdog.git
cd ClaudeCodeWatchdog
```

### Step 2: Install BurntToast Module

This is required for Windows toast notifications:

```powershell
Install-Module BurntToast -Scope CurrentUser -Force
```

### Step 3: Run Installation Script

```powershell
# Run the installer
.\Install-Watchdog.ps1

# This will:
# - Create necessary directories
# - Set up configuration files
# - Initialize the project registry
# - Verify dependencies
```

**Expected output:**
```
🔧 Installing Claude Code Watchdog...
✅ Created directories
✅ Initialized configuration
✅ Set up project registry
✅ Installation complete!
```

### Step 4: Configure API Key

Store your Claude API key securely:

```powershell
.\Set-WatchdogAPIKey.ps1 -APIKey "your-anthropic-api-key-here"
```

The API key is stored encrypted in your user profile.

---

## Configuration

### Global Configuration

The global watchdog config is located at:
```
~/.claude-automation/config/watchdog-config.json
```

**Default settings:**
```json
{
  "polling": {
    "intervalSeconds": 120,
    "maxRetries": 3
  },
  "api": {
    "enabled": true,
    "model": "claude-3-5-sonnet-20241022",
    "maxTokens": 1000,
    "temperature": 1.0,
    "dailyCostLimit": 10.0,
    "weeklyCostLimit": 50.0
  },
  "logging": {
    "level": "Info",
    "retentionDays": 7,
    "maxSizeMB": 10
  }
}
```

You can edit this file to customize behavior, or use the defaults.

---

## First Project

### Step 1: Prepare Your Project

In your project repository, create a configuration file:

```powershell
# Navigate to your project
cd C:\repos\my-project

# Create the directory
mkdir .claude-automation
```

Create `.claude-automation/project-config.json`:

```json
{
  "projectName": "my-project",
  "repoPath": "C:/repos/my-project",
  "repoUrl": "github.com/username/my-project",
  "branch": "main",

  "automation": {
    "autoCommit": false,
    "autoProgress": true,
    "maxRunDuration": "4h",
    "stallThreshold": "10m"
  },

  "humanInLoop": {
    "requiresApprovalFor": [],
    "requiresHumanAfter": ["compilation-errors", "test-failures"]
  },

  "skills": [],

  "phases": [
    {
      "name": "implementation",
      "autoProgress": true,
      "estimatedDuration": "2h"
    }
  ],

  "commitStrategy": {
    "frequency": "phase-completion",
    "branchNaming": "claude/{phase-name}-{timestamp}",
    "prCreation": "manual"
  },

  "notifications": {
    "onError": true,
    "onPhaseComplete": true,
    "onHumanNeeded": true
  }
}
```

**💡 Tip:** Start with `autoCommit: false` and `autoProgress: true` for safe testing.

### Step 2: Register the Project

```powershell
# Navigate back to Watchdog directory
cd C:\repos\ClaudeCodeWatchdog

# Register your project
.\Register-Project.ps1 `
    -ProjectName "my-project" `
    -ConfigPath "C:\repos\my-project\.claude-automation\project-config.json"
```

**Expected output:**
```
✅ Project 'my-project' registered successfully
📁 Config: C:\repos\my-project\.claude-automation\project-config.json
🎯 Status: Active
```

### Step 3: Verify Registration

```powershell
.\Get-RegisteredProjects.ps1
```

You should see your project listed:
```
Name         Status  Config Path
----         ------  -----------
my-project   Active  C:\repos\my-project\.claude-automation\project-config.json
```

---

## Running the Watchdog

### Step 1: Start the Watchdog

```powershell
# In the ClaudeCodeWatchdog directory
.\Start-Watchdog.ps1
```

**You'll see:**
```
🤖 Starting Claude Code Watchdog...
✅ Watchdog initialized. Polling every 120 seconds
📋 Processing 1 project(s)...
  🔍 Checking: my-project...
```

**💡 Tip:** Leave this terminal window open. The Watchdog will run continuously.

### Step 2: Start Your Claude Code Session

1. Open Chrome
2. Navigate to Claude Code
3. Open your project: `C:\repos\my-project`
4. Start working on a task

The Watchdog will automatically detect your session!

**In the Watchdog terminal, you'll see:**
```
  🔍 Checking: my-project...
    Found session: 01WZQC04Z031XZH13HUUW7VX9A
    Status: HasTodos | TODOs: 5 | Errors: 0
    Decision: continue (confidence: 85%)
    ▶️  Sending command: Continue with next TODO
    ✅ Processing complete
```

---

## Verifying It Works

### Check Decision Logs

```powershell
# View the decision log for your project
Get-Content "C:\repos\my-project\.claude-automation\decision-log.md" -Tail 20
```

You should see entries like:
```markdown
## Decision #1
**Timestamp:** 2025-11-22T14:30:00
**Action:** continue
**Command:** Continue with next TODO
**Reasoning:** 5 TODOs remaining, autoProgress enabled
**Confidence:** 0.85
**Method:** claude-api

### Session Context
- Status: HasTodos
- TODOs Remaining: 5
- Errors: 0
```

### Check Notifications

You should receive Windows toast notifications when:
- ✅ Watchdog starts monitoring a project
- ⚠️  Errors are detected
- ✅ Phases are completed
- 🔔 Human intervention is needed

### Check Watchdog Status

```powershell
# View project status
.\Get-ProjectStatus.ps1 -ProjectName "my-project"
```

**Output:**
```
Project: my-project
Status: Active
Current Phase: implementation
TODOs: 3 of 8 completed (37.5%)
Last Activity: 2025-11-22 14:35:00
Decisions Made: 12
Session ID: 01WZQC04Z031XZH13HUUW7VX9A
```

---

## Next Steps

### 1. Enable Skills

Add Claude Skills to your project config for automatic error resolution:

```json
{
  "skills": [
    "/mnt/skills/user/compilation-error-resolution",
    "/mnt/skills/user/type-error-resolution",
    "/mnt/skills/user/lint-error-resolution"
  ]
}
```

### 2. Enable Auto-Commit

Once you're confident, enable automatic commits:

```json
{
  "automation": {
    "autoCommit": true,
    "autoProgress": true
  }
}
```

### 3. Register Multiple Projects

Monitor multiple projects simultaneously:

```powershell
.\Register-Project.ps1 -ProjectName "frontend" -ConfigPath "C:\repos\frontend\.claude-automation\project-config.json"
.\Register-Project.ps1 -ProjectName "backend" -ConfigPath "C:\repos\backend\.claude-automation\project-config.json"
```

The Watchdog will monitor all registered projects in parallel.

### 4. Generate Progress Reports

```powershell
# Generate a progress report
.\src\Logging\Generate-ProgressReport.ps1 -ProjectName "my-project"

# Generate daily summary for all projects
.\src\Logging\Generate-DailySummary.ps1
```

### 5. Monitor API Costs

```powershell
# Check API costs
.\Get-APICosts.ps1

# Set cost limits
.\Set-CostLimits.ps1 -DailyLimit 5.00 -WeeklyLimit 25.00
```

---

## Troubleshooting

### Watchdog Not Detecting Session

**Problem:** Watchdog shows "No active session found"

**Solutions:**
1. Verify Chrome window title contains "Claude Code"
2. Ensure Windows MCP server is running
3. Check project is registered: `.\Get-RegisteredProjects.ps1`
4. Restart Windows MCP

### Commands Not Sending

**Problem:** Commands aren't being sent to Claude Code

**Solutions:**
1. Check Claude Code reply field is visible
2. Verify no popup dialogs are blocking the UI
3. Capture a screenshot to debug:
   ```powershell
   Get-ClaudeCodeState -SessionWindow "hwnd" -IncludeScreenshot
   ```

### API Errors

**Problem:** "API call failed" or "Rate limited"

**Solutions:**
1. Check API key is set: `.\Get-APIKeyStatus.ps1`
2. Verify API costs haven't exceeded limits
3. Enable rule-based fallback in config:
   ```json
   {
     "api": {
       "enabled": true,
       "fallbackToRules": true
     }
   }
   ```

### High API Costs

**Problem:** API costs growing too quickly

**Solutions:**
1. Increase polling interval:
   ```powershell
   .\Start-Watchdog.ps1 -PollingInterval 300  # 5 minutes
   ```
2. Lower daily cost limit
3. Disable API and use rule-based only:
   ```json
   {
     "api": {
       "enabled": false
     }
   }
   ```

### Session Recovery Not Working

**Problem:** Sessions don't recover after restart

**Solutions:**
1. Check state directory exists: `~/.claude-automation/state/`
2. Verify file permissions
3. Check recovery state age (must be <24 hours)

---

## Getting Help

- **Documentation:** [docs/](docs/)
- **Troubleshooting Guide:** [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Issues:** [GitHub Issues](https://github.com/honcoops/ClaudeCodeWatchdog/issues)
- **Examples:** [examples/](examples/)

---

## Common Commands Cheat Sheet

```powershell
# Start Watchdog
.\Start-Watchdog.ps1

# Start with custom interval (5 minutes)
.\Start-Watchdog.ps1 -PollingInterval 300

# Register a project
.\Register-Project.ps1 -ProjectName "name" -ConfigPath "path/to/config.json"

# List projects
.\Get-RegisteredProjects.ps1

# Check project status
.\Get-ProjectStatus.ps1 -ProjectName "name"

# Pause a project
.\Set-ProjectStatus.ps1 -ProjectName "name" -Status "Paused"

# Resume a project
.\Set-ProjectStatus.ps1 -ProjectName "name" -Status "Active"

# View decision log
Get-Content "path/to/project/.claude-automation/decision-log.md"

# Check API costs
.\Get-APICosts.ps1

# Generate progress report
.\src\Logging\Generate-ProgressReport.ps1 -ProjectName "name"

# Run tests
cd tests
.\Run-AllTests.ps1
```

---

## Success!

You're now running Claude Code Watchdog! 🎉

The Watchdog will:
- ✅ Monitor your Claude Code sessions automatically
- ✅ Make intelligent decisions about what to do next
- ✅ Send commands to Claude Code
- ✅ Log all decisions for review
- ✅ Notify you when human input is needed

**Pro Tip:** Start with conservative settings (autoCommit: false, short polling intervals) and gradually enable more automation as you gain confidence.

---

**Need more help?** Check the [full documentation](../README.md) or the [troubleshooting guide](TROUBLESHOOTING.md).
