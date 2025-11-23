# Troubleshooting Guide - Claude Code Watchdog

Comprehensive guide to diagnosing and resolving common issues with Claude Code Watchdog.

---

## Table of Contents

- [Quick Reference](#quick-reference)
- [Installation Issues](#installation-issues)
- [Session Detection Issues](#session-detection-issues)
- [Command Execution Issues](#command-execution-issues)
- [API and Decision Issues](#api-and-decision-issues)
- [Project Registration Issues](#project-registration-issues)
- [Performance Issues](#performance-issues)
- [Logging and Reporting Issues](#logging-and-reporting-issues)
- [Cost Management Issues](#cost-management-issues)
- [Recovery and State Issues](#recovery-and-state-issues)
- [Advanced Diagnostics](#advanced-diagnostics)

---

## Quick Reference

| Issue | Quick Fix | Full Solution |
|-------|-----------|---------------|
| Session not detected | Restart Windows MCP | [Session Detection](#session-detection-issues) |
| Commands not sending | Check reply field coordinates | [Command Execution](#command-execution-issues) |
| API errors | Check API key | [API Issues](#api-and-decision-issues) |
| High costs | Reduce polling interval | [Cost Management](#cost-management-issues) |
| Recovery failing | Check state directory | [Recovery Issues](#recovery-and-state-issues) |

---

## Installation Issues

### Issue: PowerShell Version Too Old

**Severity**: Critical
**Affected Components**: All
**Estimated Resolution Time**: 10 minutes

#### Symptoms

1. **Installation Fails with Syntax Errors**
   ```
   ParserError: Unexpected token '??' in expression
   ```

2. **Watchdog Won't Start**
   ```
   The term '??' is not recognized as the name of a cmdlet
   ```

#### Diagnostic Steps

**Step 1: Check PowerShell Version**

```powershell
$PSVersionTable.PSVersion
```

**Expected:** Version 7.0 or higher
**Problem:** Shows version 5.1 or lower

#### Resolution

1. **Download PowerShell 7+**
   - Visit: https://github.com/PowerShell/PowerShell
   - Download latest release for Windows
   - Run installer

2. **Verify Installation**
   ```powershell
   pwsh --version
   # Should show: PowerShell 7.x.x
   ```

3. **Use Correct Shell**
   - Open "PowerShell 7" (not "Windows PowerShell")
   - Or run: `pwsh` from any terminal

#### Prevention

- Always launch PowerShell 7 (not Windows PowerShell 5.1)
- Update PowerShell regularly: `winget upgrade Microsoft.PowerShell`

---

### Issue: BurntToast Module Missing

**Severity**: Medium
**Affected Components**: Notifications
**Estimated Resolution Time**: 5 minutes

#### Symptoms

1. **Error on Startup**
   ```
   ModuleNotFoundError: The specified module 'BurntToast' was not loaded
   ```

2. **Notifications Don't Appear**
   - No toast notifications
   - No errors in logs

#### Resolution

```powershell
# Install BurntToast module
Install-Module BurntToast -Scope CurrentUser -Force

# Verify installation
Get-Module BurntToast -ListAvailable
```

#### Prevention

- Run `Install-Watchdog.ps1` which checks dependencies
- Add to your PowerShell profile for auto-load

---

### Issue: Windows MCP Not Installed

**Severity**: Critical
**Affected Components**: State Detection, Command Execution
**Estimated Resolution Time**: 30 minutes

#### Symptoms

1. **MCP Commands Fail**
   ```
   CommandNotFoundException: The term 'mcp-client' is not recognized
   ```

2. **Session Detection Always Fails**
   ```
   Warning: Windows MCP is not available
   ```

#### Diagnostic Steps

```powershell
# Check if MCP is installed
Get-Command mcp-client -ErrorAction SilentlyContinue

# Check MCP server status
mcp-server --status
```

#### Resolution

1. **Install Windows MCP Server**
   - Follow Windows MCP installation guide
   - Ensure server is running

2. **Verify MCP Accessibility**
   ```powershell
   mcp-client --version
   ```

3. **Start MCP Server**
   ```powershell
   mcp-server start
   ```

4. **Add MCP to PATH** (if needed)
   - Add MCP install directory to system PATH
   - Restart PowerShell

#### Prevention

- Configure MCP to start automatically with Windows
- Add health check: `mcp-server --status` before starting Watchdog

---

## Session Detection Issues

### Issue: Watchdog Not Detecting Claude Code Session

**Severity**: High
**Affected Components**: Detection, Registry
**Common Occurrence**: Common during initial setup
**Estimated Resolution Time**: 10 minutes

#### Symptoms

1. **"No active session found" Message**
   ```
   🔍 Checking: my-project...
   ⚠️  No active session found for my-project
   ```

2. **Project Shows as No Session**
   ```powershell
   .\Get-ProjectStatus.ps1 -ProjectName "my-project"
   # Session ID: (none)
   ```

#### Possible Causes

**Most Likely:**

1. **Windows MCP Server Not Running**
   - MCP service stopped or crashed
   - Check: `mcp-server --status`

2. **Chrome Window Title Incorrect**
   - Claude Code not in window title
   - Different browser being used
   - Check: Window title should contain "Claude Code"

3. **Project Not Registered**
   - Project wasn't registered with Watchdog
   - Check: `Get-RegisteredProjects`

**Less Common:**

4. **Session ID Format Changed**
   - Claude Code updated with new format
   - ULID pattern no longer matches

5. **Multiple Chrome Profiles**
   - Claude Code in different Chrome profile
   - MCP can't access that profile

#### Diagnostic Steps

**Step 1: Verify Windows MCP**

```powershell
# Check MCP is running
mcp-server --status
# Expected: "Server running on port 3000"

# Test MCP can see windows
mcp-client list-windows
# Should show all open windows including Chrome
```

**Step 2: Check Chrome Window**

```powershell
# List all window titles
mcp-client list-windows | Select-String "Claude"

# Expected: See window with "Claude Code" in title
```

**Step 3: Verify Project Registration**

```powershell
.\Get-RegisteredProjects.ps1

# Your project should be listed
# Status should be "Active"
```

**Step 4: Test Session Detection Manually**

```powershell
# Try to find session manually
.\src\Detection\Find-ClaudeCodeSession.ps1 -ProjectName "my-project" -Verbose

# Review verbose output for clues
```

#### Resolution

**Solution 1: Restart Windows MCP**

```powershell
# Stop MCP server
mcp-server stop

# Wait 5 seconds
Start-Sleep -Seconds 5

# Start MCP server
mcp-server start

# Verify it's running
mcp-server --status
```

**Solution 2: Fix Chrome Window Title**

1. **Ensure Claude Code is Active**
   - Open Claude Code in Chrome
   - Make sure it's the active tab
   - Window title should show "Claude Code"

2. **Check Browser**
   - Only Chrome is supported currently
   - Edge/Firefox may not work with Windows MCP

**Solution 3: Re-register Project**

```powershell
# Unregister old registration
.\Unregister-Project.ps1 -ProjectName "my-project"

# Register again
.\Register-Project.ps1 `
    -ProjectName "my-project" `
    -ConfigPath "C:\repos\my-project\.claude-automation\project-config.json"
```

**Solution 4: Update Session Detection Pattern**

If Claude Code changed ULID format:

1. Capture current session manually
2. Update pattern in `Get-SessionIdFromUI`
3. File issue on GitHub with new format

#### Prevention

- Keep Windows MCP updated
- Always use Chrome for Claude Code
- Use descriptive project names
- Monitor MCP server health

---

### Issue: Session Detected But State Always "Unknown"

**Severity**: Medium
**Affected Components**: State Detection
**Estimated Resolution Time**: 15 minutes

#### Symptoms

1. **State Classification Fails**
   ```
   Status: Unknown | TODOs: 0 | Errors: 0
   ```

2. **No UI Elements Detected**
   - HasReplyField: false
   - No TODOs found
   - No errors found

#### Diagnostic Steps

```powershell
# Capture state with screenshot
$state = Get-ClaudeCodeState -SessionWindow "hwnd" -IncludeScreenshot

# Save screenshot for analysis
$state.RawUIState.Screenshot | Set-Content "debug-screenshot.png" -Encoding Byte

# Check what UI elements were found
$state.RawUIState.InteractiveElements | Format-Table
$state.RawUIState.InformativeElements | Format-Table
```

#### Resolution

1. **Update Windows MCP**
   - Newer versions have better UI detection
   - Check for updates

2. **Adjust Detection Patterns**
   - Edit `Parse-UIElements.ps1`
   - Add new patterns for current Claude Code UI

3. **Use Vision API** (if available)
   - Enable screenshot-based detection
   - More robust to UI changes

#### Prevention

- Report UI detection issues on GitHub
- Contribute updated patterns
- Use latest Windows MCP version

---

## Command Execution Issues

### Issue: Commands Not Being Sent to Claude Code

**Severity**: High
**Affected Components**: Action Execution
**Common Occurrence**: Common after Claude Code UI updates
**Estimated Resolution Time**: 20 minutes

#### Symptoms

1. **Decision Made But Command Not Sent**
   ```
   Decision: continue (confidence: 85%)
   ⚠️  Command not sent - reply field not found
   ```

2. **Claude Code Doesn't Progress**
   - TODOs remain unchanged
   - Session appears stuck
   - No errors in Claude Code

#### Possible Causes

**Most Likely:**

1. **Reply Field Coordinates Wrong**
   - Claude Code UI changed
   - Coordinates no longer valid
   - Check: Capture screenshot to see field location

2. **Reply Field Not Detected**
   - UI element name changed
   - Detection pattern outdated
   - Check: `$state.HasReplyField` is false

3. **Popup Dialog Blocking UI**
   - Modal dialog is open
   - Reply field obscured
   - Check: Look for dialogs in screenshot

**Less Common:**

4. **MCP Click Not Working**
   - Windows MCP issue
   - Coordinates system different
   - Check: Test MCP click manually

5. **Session Window Lost Focus**
   - Different window became active
   - Claude Code minimized
   - Check: Ensure window is visible

#### Diagnostic Steps

**Step 1: Verify Reply Field Detection**

```powershell
# Get current state
$state = Get-ClaudeCodeState -SessionWindow "your-session" -IncludeScreenshot

# Check reply field status
Write-Host "Has Reply Field: $($state.HasReplyField)"
Write-Host "Coordinates: $($state.ReplyFieldCoordinates)"

# Save screenshot
$state.RawUIState.Screenshot | Set-Content "reply-field-check.png" -Encoding Byte
```

**Step 2: Test Manual Command**

```powershell
# Try sending a command manually
Send-ClaudeCodeCommand `
    -Command "test message" `
    -ReplyFieldCoordinates @(800, 900)

# Watch Claude Code to see if it appears
```

**Step 3: Check for Blocking Elements**

```powershell
# List all interactive elements
$state.RawUIState.InteractiveElements |
    Where-Object { $_.Type -like "*dialog*" -or $_.Type -like "*modal*" } |
    Format-Table
```

#### Resolution

**Solution 1: Update Reply Field Coordinates**

1. **Capture Current UI State**
   ```powershell
   $state = Get-ClaudeCodeState -SessionWindow "hwnd" -IncludeScreenshot
   ```

2. **Find Reply Field Manually**
   - Open screenshot
   - Note X, Y coordinates of reply field
   - Usually at bottom of screen

3. **Update Coordinates**
   - Edit `Find-ReplyField` in `Get-ClaudeCodeState.ps1`
   - Add new coordinates as fallback
   - Test with manual command

**Solution 2: Improve Reply Field Detection**

Edit `src/Detection/Get-ClaudeCodeState.ps1`:

```powershell
# Add additional detection patterns
$replyField = $UIState.InteractiveElements | Where-Object {
    $_.Name -like "*Reply*" -or
    $_.Name -like "*Message*" -or
    $_.Name -like "*Input*" -or          # Add this
    $_.Placeholder -like "*Type*" -or    # Add this
    $_.ControlType -eq "Edit"            # Add this
} | Select-Object -First 1
```

**Solution 3: Clear Blocking Dialogs**

If dialogs are blocking:

1. **Close Dialogs Manually**
   - Review Claude Code UI
   - Close any open dialogs/modals

2. **Add Dialog Detection**
   - Detect dialogs automatically
   - Log warning when detected
   - Wait for dialogs to close

**Solution 4: Re-focus Claude Code Window**

```powershell
# Function to bring window to front (add to utils)
function Set-WindowFocus {
    param([string]$WindowHandle)

    # Use Windows MCP to focus window
    mcp-client focus-window --handle $WindowHandle
}
```

#### Prevention

- Monitor for Claude Code UI updates
- Implement retry logic with different coordinates
- Add fallback detection methods
- Log coordinates used for debugging

---

### Issue: Commands Sent But Not Executed

**Severity**: Medium
**Affected Components**: Action Execution, Windows MCP
**Estimated Resolution Time**: 15 minutes

#### Symptoms

1. **Watchdog Reports Command Sent**
   ```
   ▶️  Sending command: Continue with next TODO
   ✅ Command sent successfully
   ```

2. **Claude Code Shows No Change**
   - Reply field empty
   - No response from Claude
   - TODOs unchanged

#### Diagnostic Steps

**Step 1: Verify Command Verification**

```powershell
# Enable verification
$result = Send-ClaudeCodeCommand -Command "test" -ReplyFieldCoordinates @(800, 900) -Verify

Write-Host "Success: $($result.Success)"
Write-Host "Verification: $($result.Verified)"
```

**Step 2: Check Send Delay**

Commands may need delay between click and type:

```powershell
# Check timing in Send-ClaudeCodeCommand
# Ensure adequate delays:
# - Click to focus: 500ms
# - Type command: 100ms between chars
# - Submit (Enter): 200ms after typing
```

#### Resolution

1. **Increase Delays**
   - Edit `Send-ClaudeCodeCommand.ps1`
   - Increase `Start-Sleep` durations
   - Recommended: 500ms click, 100ms typing, 300ms submit

2. **Add Verification Step**
   - Re-read UI after send
   - Verify reply field is now empty
   - Retry if verification fails

3. **Use Alternative Input Method**
   - Some systems require keyboard events
   - Try SendKeys instead of MCP type

#### Prevention

- Always use verification
- Implement retry with exponential backoff
- Log failures for pattern detection

---

## API and Decision Issues

### Issue: Claude API Calls Failing

**Severity**: High
**Affected Components**: Decision Engine
**Common Occurrence**: Moderate
**Estimated Resolution Time**: 10 minutes

#### Symptoms

1. **API Error Messages**
   ```
   Error: Claude API call failed: 401 Unauthorized
   Warning: API call failed. Falling back to rule-based decision.
   ```

2. **Only Rule-Based Decisions**
   - All decisions show `DecisionMethod: rule-based`
   - No API metadata in decision logs
   - No API costs accumulating

#### Possible Causes

**Most Likely:**

1. **API Key Not Set**
   - Key never configured
   - Check: API key file doesn't exist

2. **API Key Invalid/Expired**
   - Key was revoked
   - Anthropic account issue
   - Check: Test key with curl

3. **Network/Firewall Issues**
   - Can't reach api.anthropic.com
   - Corporate firewall blocking
   - Check: Test with `Test-NetConnection`

**Less Common:**

4. **API Rate Limiting**
   - Too many requests
   - Check: HTTP 429 status code

5. **Cost Limits Exceeded**
   - Daily/weekly budget exhausted
   - Check: API cost tracking

#### Diagnostic Steps

**Step 1: Verify API Key**

```powershell
# Check if API key file exists
Test-Path "$env:USERPROFILE\.claude-automation\api-key.encrypted"

# Try to retrieve key (will show if configured)
.\Get-SecureAPIKey.ps1
# Should return: "API key configured: sk-ant-...***"
```

**Step 2: Test API Connectivity**

```powershell
# Test network connectivity
Test-NetConnection api.anthropic.com -Port 443

# Expected: TcpTestSucceeded: True
```

**Step 3: Test API Key**

```powershell
# Test API call manually
$apiKey = "your-api-key"
$headers = @{
    "x-api-key" = $apiKey
    "anthropic-version" = "2023-06-01"
    "content-type" = "application/json"
}

try {
    Invoke-RestMethod -Uri "https://api.anthropic.com/v1/messages" `
        -Method Post `
        -Headers $headers `
        -Body '{"model":"claude-3-5-sonnet-20241022","max_tokens":10,"messages":[{"role":"user","content":"test"}]}'
    Write-Host "✅ API key valid"
}
catch {
    Write-Host "❌ API error: $_"
}
```

**Step 4: Check Cost Limits**

```powershell
# View cost limits
Get-Content "$env:USERPROFILE\.claude-automation\config\watchdog-config.json" | ConvertFrom-Json | Select-Object -ExpandProperty api

# Check current costs
.\Get-APICosts.ps1
```

#### Resolution

**Solution 1: Set/Update API Key**

```powershell
# Set new API key
.\Set-WatchdogAPIKey.ps1 -APIKey "sk-ant-your-new-key-here"

# Verify it works
.\Test-APIKey.ps1
```

**Solution 2: Fix Network/Firewall**

1. **Check Corporate Proxy**
   ```powershell
   # Set proxy if needed
   $env:HTTPS_PROXY = "http://proxy.company.com:8080"
   ```

2. **Whitelist Anthropic API**
   - Add api.anthropic.com to firewall allowlist
   - Ports: 443 (HTTPS)

**Solution 3: Increase Cost Limits**

```powershell
# Edit config
$config = Get-Content "$env:USERPROFILE\.claude-automation\config\watchdog-config.json" | ConvertFrom-Json
$config.api.dailyCostLimit = 20.0
$config.api.weeklyCostLimit = 100.0
$config | ConvertTo-Json -Depth 10 | Set-Content "$env:USERPROFILE\.claude-automation\config\watchdog-config.json"
```

**Solution 4: Disable API Temporarily**

If API issues persist, use rule-based only:

```json
{
  "api": {
    "enabled": false
  }
}
```

#### Prevention

- Monitor API key expiration
- Set up cost alerts
- Keep backup API key
- Implement health checks
- Log all API errors with full context

---

### Issue: API Costs Too High

**Severity**: Medium
**Affected Components**: Decision Engine, Cost Tracking
**Common Occurrence**: Common without tuning
**Estimated Resolution Time**: 10 minutes

#### Symptoms

1. **High Daily Costs**
   ```
   Warning: Daily cost limit exceeded ($12.50 >= $10.00)
   Warning: API cost limit exceeded. Using fallback decision.
   ```

2. **Frequent API Calls**
   - Decision logs show 100+ API calls per hour
   - Costs accumulating quickly

#### Diagnostic Steps

```powershell
# Check costs
.\Get-APICosts.ps1

# View cost breakdown by project
Get-Content "$env:USERPROFILE\.claude-automation\api-costs.json" | ConvertFrom-Json | Format-List

# Check decision frequency
$logs = Get-Content "path\to\decision-log.md" -Raw
$decisions = ([regex]::Matches($logs, "## Decision #")).Count
Write-Host "Total decisions made: $decisions"
```

#### Resolution

**Solution 1: Reduce Polling Frequency**

```powershell
# Start with longer interval (5 minutes instead of 2)
.\Start-Watchdog.ps1 -PollingInterval 300
```

**Solution 2: Use Rule-Based for Simple Decisions**

Update decision logic to use rules for obvious cases:

```powershell
# In Invoke-ClaudeDecision, add early return for simple cases
if ($SessionState.Status -eq "InProgress") {
    # No need for API - always wait when processing
    return Invoke-SimpleDecision -SessionState $SessionState -ProjectConfig $ProjectConfig
}
```

**Solution 3: Lower Cost Limits**

```powershell
.\Set-CostLimits.ps1 -DailyLimit 5.00 -WeeklyLimit 25.00
```

**Solution 4: Optimize Prompts**

- Reduce prompt length
- Remove verbose context
- Use smaller model for simple decisions

#### Prevention

- Set conservative cost limits initially
- Monitor costs daily for first week
- Tune polling interval based on project needs
- Use API only for complex decisions

---

## Project Registration Issues

### Issue: Cannot Register Project - Config Invalid

**Severity**: Medium
**Affected Components**: Registry
**Estimated Resolution Time**: 5 minutes

#### Symptoms

```
Error: Invalid project configuration
Required field 'projectName' missing
```

#### Diagnostic Steps

```powershell
# Validate JSON syntax
Get-Content "C:\repos\my-project\.claude-automation\project-config.json" | ConvertFrom-Json
# If this errors, JSON is malformed

# Check required fields
$config = Get-Content "path\to\config.json" | ConvertFrom-Json
$required = @('projectName', 'repoPath', 'automation')
$required | ForEach-Object {
    if (-not $config.$_) {
        Write-Host "❌ Missing: $_"
    }
}
```

#### Resolution

Use the example config as template:

```powershell
# Copy example config
Copy-Item examples\example-project-config.json "C:\repos\my-project\.claude-automation\project-config.json"

# Edit with your values
notepad "C:\repos\my-project\.claude-automation\project-config.json"
```

---

## Performance Issues

### Issue: Watchdog Using High CPU/Memory

**Severity**: Low
**Affected Components**: Core, Resource Monitoring
**Estimated Resolution Time**: 15 minutes

#### Symptoms

1. **High Resource Usage**
   - CPU > 20% constantly
   - Memory > 500MB
   - Fan noise increases

2. **Slow Response Times**
   - Long delays between cycles
   - UI becomes sluggish

#### Diagnostic Steps

```powershell
# Check Watchdog resource usage
Get-Process powershell | Select-Object CPU, WorkingSet, Handles

# Monitor over time
$global:WatchdogStats.ResourceSamples | Select-Object -Last 10 | Format-Table
```

#### Resolution

1. **Increase Polling Interval**
   ```powershell
   .\Start-Watchdog.ps1 -PollingInterval 300  # 5 minutes
   ```

2. **Limit Number of Projects**
   - Pause inactive projects
   - Monitor only active projects

3. **Disable Unnecessary Logging**
   ```json
   {
     "logging": {
       "level": "Warning"  // Instead of "Debug"
     }
   }
   ```

4. **Check for Memory Leaks**
   - Monitor memory over 24 hours
   - If growing, report issue on GitHub

---

## Recovery and State Issues

### Issue: Session Recovery Fails After Restart

**Severity**: Medium
**Affected Components**: Project Management, State Persistence
**Estimated Resolution Time**: 10 minutes

#### Symptoms

```
🔄 Attempting session recovery...
⚠️  Recovery state too old (25.3h). Skipping...
```

OR

```
⚠️  Recovery state from [timestamp]
  📁 Recovery complete: 0 restored, 2 unavailable
```

#### Diagnostic Steps

```powershell
# Check recovery state file
$recoveryPath = "$env:USERPROFILE\.claude-automation\state\watchdog-recovery.json"

if (Test-Path $recoveryPath) {
    $recovery = Get-Content $recoveryPath | ConvertFrom-Json
    Write-Host "Saved At: $($recovery.SavedAt)"
    Write-Host "Projects: $($recovery.Projects.Count)"

    # Check age
    $saved = [DateTime]::Parse($recovery.SavedAt)
    $age = (Get-Date) - $saved
    Write-Host "Age: $($age.TotalHours) hours"
}
else {
    Write-Host "No recovery state found"
}
```

#### Resolution

**Solution 1: Recovery State Too Old**

If > 24 hours old, state is ignored for safety:

```powershell
# Delete old state
Remove-Item "$env:USERPROFILE\.claude-automation\state\watchdog-recovery.json"

# Restart Claude Code sessions manually
# Watchdog will detect them
```

**Solution 2: Fix State Permissions**

```powershell
# Check permissions
$stateDir = "$env:USERPROFILE\.claude-automation\state"
Get-Acl $stateDir | Format-List

# Fix if needed
icacls $stateDir /grant "$env:USERNAME:(OI)(CI)F" /T
```

**Solution 3: Verify State Format**

```powershell
# Check state file is valid JSON
$recoveryPath = "$env:USERPROFILE\.claude-automation\state\watchdog-recovery.json"
try {
    $state = Get-Content $recoveryPath | ConvertFrom-Json
    Write-Host "✅ Valid state file"
}
catch {
    Write-Host "❌ Invalid state file: $_"
    # Delete and let Watchdog recreate
    Remove-Item $recoveryPath
}
```

#### Prevention

- Run Watchdog as service for persistence
- Keep sessions active for quicker recovery
- Monitor state directory for issues

---

## Advanced Diagnostics

### Enabling Debug Logging

```powershell
# Set log level to Debug
$config = Get-Content "$env:USERPROFILE\.claude-automation\config\watchdog-config.json" | ConvertFrom-Json
$config.logging.level = "Debug"
$config | ConvertTo-Json -Depth 10 | Set-Content "$env:USERPROFILE\.claude-automation\config\watchdog-config.json"

# Restart Watchdog
.\Start-Watchdog.ps1
```

### Capturing Full Diagnostic Info

```powershell
# Create diagnostic report
$diagnostic = @{
    Timestamp = Get-Date -Format "o"
    PSVersion = $PSVersionTable.PSVersion.ToString()
    WatchdogVersion = "1.0.0-beta"
    Projects = Get-RegisteredProjects
    APIConfig = (Get-Content "$env:USERPROFILE\.claude-automation\config\watchdog-config.json" | ConvertFrom-Json).api
    Costs = Get-Content "$env:USERPROFILE\.claude-automation\api-costs.json" -Raw | ConvertFrom-Json
    RecentLogs = Get-Content "$env:USERPROFILE\.claude-automation\logs\watchdog.log" -Tail 50
}

$diagnostic | ConvertTo-Json -Depth 10 | Set-Content "diagnostic-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
```

### Testing Individual Components

```powershell
# Test Windows MCP
mcp-client list-windows

# Test session detection
.\src\Detection\Find-ClaudeCodeSession.ps1 -ProjectName "test" -Verbose

# Test state classification
$state = Get-ClaudeCodeState -SessionWindow "hwnd"
Get-SessionStatus -ParsedState $state

# Test decision making
Invoke-SimpleDecision -SessionState $state -ProjectConfig $config

# Test command sending
Send-ClaudeCodeCommand -Command "test" -ReplyFieldCoordinates @(800, 900)
```

---

## Getting Help

If none of these solutions work:

1. **Check GitHub Issues**
   - Search existing issues: https://github.com/honcoops/ClaudeCodeWatchdog/issues
   - Similar problems may have solutions

2. **Create Issue with Diagnostic Info**
   - Include PowerShell version
   - Include error messages
   - Include diagnostic report (see above)
   - Include steps to reproduce

3. **Community Support**
   - GitHub Discussions
   - Include relevant logs (redact sensitive info)

4. **Review Documentation**
   - [README.md](../README.md)
   - [QUICKSTART.md](QUICKSTART.md)
   - [ARCHITECTURE.md](ARCHITECTURE.md)
   - [Error Handling Guidelines](ERROR-HANDLING-GUIDELINES.md)

---

## Appendix: Common Error Messages

| Error Message | Likely Cause | Quick Fix |
|---------------|--------------|-----------|
| `CommandNotFoundException: mcp-client` | Windows MCP not installed | Install Windows MCP |
| `ModuleNotFoundError: BurntToast` | Module not installed | `Install-Module BurntToast` |
| `ParserError: Unexpected token` | PowerShell version < 7 | Upgrade to PowerShell 7+ |
| `401 Unauthorized` | Invalid API key | Reset API key |
| `429 Too Many Requests` | Rate limited | Reduce polling frequency |
| `Session lost` | Claude Code closed | Restart Claude Code |
| `Reply field not found` | UI changed | Update coordinates |
| `Cost limit exceeded` | Budget exhausted | Increase limit or use rules |

---

**Last Updated**: November 22, 2025
**Version**: 1.0.0-beta
