# Implementation Guide - Claude Code Watchdog

## Phase 1: Core Watchdog (Week 1)

### Goals
- Build the foundational watchdog process
- Implement basic project registration
- Create simple state detection
- Enable auto-continue functionality
- Set up logging infrastructure

### Tasks

#### Task 1.1: Project Structure Setup
**Estimated Time:** 2 hours

Create the following directory structure:
```
claude-code-watchdog/
├── src/
│   ├── Core/
│   │   ├── Start-Watchdog.ps1           # Main entry point
│   │   ├── Initialize-Watchdog.ps1      # Setup and initialization
│   │   └── Stop-Watchdog.ps1            # Graceful shutdown
│   ├── Registry/
│   │   ├── Register-Project.ps1         # Project registration
│   │   ├── Get-RegisteredProjects.ps1   # Load projects
│   │   └── Update-ProjectState.ps1      # State management
│   ├── Detection/
│   │   ├── Get-ClaudeCodeState.ps1      # Main state detection
│   │   ├── Find-ClaudeCodeSession.ps1   # Locate sessions
│   │   └── Parse-UIElements.ps1         # Parse UI state
│   ├── Decision/
│   │   ├── Invoke-SimpleDecision.ps1    # Rule-based decisions
│   │   └── Get-DecisionHistory.ps1      # Decision tracking
│   ├── Action/
│   │   ├── Send-ClaudeCodeCommand.ps1   # Send commands
│   │   └── Verify-CommandSent.ps1       # Verify delivery
│   ├── Logging/
│   │   ├── Write-WatchdogLog.ps1        # Logging functions
│   │   ├── Add-DecisionLog.ps1          # Decision logging
│   │   └── Send-Notification.ps1        # Notifications
│   └── Utils/
│       ├── Invoke-WindowsMCP.ps1        # MCP wrapper
│       └── Get-WatchdogConfig.ps1       # Configuration
├── config/
│   └── watchdog-config.json             # Global config
├── tests/
│   ├── Unit/
│   └── Integration/
├── docs/
│   ├── REQUIREMENTS.md                  # From previous
│   ├── ARCHITECTURE.md                  # From previous
│   └── QUICKSTART.md                    # Getting started
└── Install-Watchdog.ps1                 # Installation script
```

**Deliverables:**
- [ ] Directory structure created
- [ ] Placeholder files with function signatures
- [ ] Basic module imports working

---

#### Task 1.2: Windows MCP Integration
**Estimated Time:** 3 hours

Create wrapper functions for Windows MCP tools:

**File:** `src/Utils/Invoke-WindowsMCP.ps1`

```powershell
function Invoke-WindowsMCPStateTool {
    param([bool]$UseVision = $false)
    
    try {
        # TODO: Call Windows MCP State-Tool
        # Parse the JSON response
        # Return structured object
    }
    catch {
        Write-Error "Failed to get UI state: $_"
        throw
    }
}

function Invoke-WindowsMCPClick {
    param(
        [Parameter(Mandatory)]
        [array]$Coordinates,
        
        [string]$Button = "left",
        [int]$Clicks = 1
    )
    
    try {
        # TODO: Call Windows MCP Click-Tool
    }
    catch {
        Write-Error "Failed to click at $Coordinates: $_"
        throw
    }
}

function Invoke-WindowsMCPType {
    param(
        [Parameter(Mandatory)]
        [array]$Coordinates,
        
        [Parameter(Mandatory)]
        [string]$Text,
        
        [bool]$Clear = $false
    )
    
    try {
        # TODO: Call Windows MCP Type-Tool
    }
    catch {
        Write-Error "Failed to type text: $_"
        throw
    }
}

function Invoke-WindowsMCPKey {
    param([Parameter(Mandatory)][string]$Key)
    
    try {
        # TODO: Call Windows MCP Key-Tool
    }
    catch {
        Write-Error "Failed to press key '$Key': $_"
        throw
    }
}
```

**Testing:**
- [ ] Can capture UI state
- [ ] Can click on coordinates
- [ ] Can type text
- [ ] Can press keys
- [ ] Error handling works

---

#### Task 1.3: State Detection
**Estimated Time:** 4 hours

Implement the state detection logic:

**File:** `src/Detection/Get-ClaudeCodeState.ps1`

```powershell
function Get-ClaudeCodeState {
    param(
        [Parameter(Mandatory)]
        [string]$SessionWindow,
        
        [switch]$IncludeScreenshot
    )
    
    # Capture UI state
    $uiState = Invoke-WindowsMCPStateTool -UseVision:$IncludeScreenshot
    
    # Parse key elements
    $state = @{
        SessionId = Get-SessionIdFromURL -UIState $uiState
        Status = "Unknown"
        HasReplyField = $false
        ReplyFieldCoordinates = $null
        Todos = @{ Total = 0; Completed = 0; Remaining = 0; Items = @() }
        Errors = @()
        Warnings = @()
        IsProcessing = $false
        LastActivity = Get-Date
        IdleTime = [TimeSpan]::Zero
    }
    
    # Detect Reply field
    $replyField = $uiState.InteractiveElements | 
        Where-Object { $_.Name -like "*Reply*" -or $_.ControlType -eq "EditBox" }
    
    if ($replyField) {
        $state.HasReplyField = $true
        $state.ReplyFieldCoordinates = $replyField.Coordinates
    }
    
    # Detect TODOs
    $state.Todos = Get-TodosFromUI -UIState $uiState
    
    # Detect errors
    $state.Errors = Get-ErrorsFromUI -UIState $uiState
    
    # Detect if processing
    $state.IsProcessing = Test-ProcessingIndicator -UIState $uiState
    
    # Classify overall status
    $state.Status = Get-SessionStatus -ParsedState $state
    
    return $state
}

function Get-SessionStatus {
    param([hashtable]$ParsedState)
    
    if ($ParsedState.IsProcessing) {
        return "InProgress"
    }
    
    if ($ParsedState.Errors.Count -gt 0) {
        return "Error"
    }
    
    if ($ParsedState.Todos.Remaining -gt 0 -and $ParsedState.HasReplyField) {
        return "HasTodos"
    }
    
    if ($ParsedState.Todos.Remaining -eq 0 -and $ParsedState.Todos.Total -gt 0 -and $ParsedState.HasReplyField) {
        return "PhaseComplete"
    }
    
    if ($ParsedState.IdleTime.TotalMinutes -gt 10) {
        return "Idle"
    }
    
    if ($ParsedState.HasReplyField) {
        return "WaitingForInput"
    }
    
    return "Unknown"
}

function Get-TodosFromUI {
    param([object]$UIState)
    
    # Look for TODO section indicators
    $todosSection = $UIState.InformativeElements | 
        Where-Object { $_.Text -like "*Update Todos*" -or $_.Text -like "*TODO*" }
    
    if (-not $todosSection) {
        return @{ Total = 0; Completed = 0; Remaining = 0; Items = @() }
    }
    
    # Find checkboxes near TODO section
    # Parse checked vs unchecked
    # Return structured data
    
    # TODO: Implement checkbox parsing
    return @{ Total = 0; Completed = 0; Remaining = 0; Items = @() }
}

function Get-ErrorsFromUI {
    param([object]$UIState)
    
    $errorKeywords = @("*error*", "*failed*", "*exception*", "*❌*")
    
    $errors = $UIState.InformativeElements | Where-Object {
        $text = $_.Text.ToLower()
        $errorKeywords | Where-Object { $text -like $_ }
    }
    
    return $errors | ForEach-Object {
        @{
            Message = $_.Text
            Location = $_.Coordinates
            Severity = Get-ErrorSeverity -Message $_.Text
        }
    }
}

function Test-ProcessingIndicator {
    param([object]$UIState)
    
    # Look for indicators that Claude is actively working
    # Streaming tokens, "thinking" indicators, etc.
    
    # TODO: Implement processing detection
    return $false
}
```

**Testing:**
- [ ] Correctly identifies all 6 states
- [ ] Parses TODOs accurately
- [ ] Detects errors
- [ ] Handles edge cases

---

#### Task 1.4: Simple Decision Logic
**Estimated Time:** 3 hours

Implement rule-based decisions (no API yet):

**File:** `src/Decision/Invoke-SimpleDecision.ps1`

```powershell
function Invoke-SimpleDecision {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,
        
        [Parameter(Mandatory)]
        [hashtable]$CurrentState,
        
        [Parameter(Mandatory)]
        [object]$ProjectConfig
    )
    
    $decision = @{
        action = $null
        reasoning = $null
        command = $null
        confidence = 0.0
        DecisionMethod = "Rules"
        Timestamp = Get-Date
    }
    
    # Rule 1: If has TODOs and auto-progress → Continue
    if ($CurrentState.Status -eq "HasTodos" -and $ProjectConfig.automation.autoProgress) {
        $decision.action = "continue"
        $decision.reasoning = "Auto-progress enabled and TODOs remaining"
        $decision.command = "Continue with next TODO"
        $decision.confidence = 0.9
        return $decision
    }
    
    # Rule 2: If phase complete → Mark complete (commit handled later)
    if ($CurrentState.Status -eq "PhaseComplete") {
        $decision.action = "phase_complete"
        $decision.reasoning = "All TODOs in current phase completed"
        $decision.confidence = 0.95
        return $decision
    }
    
    # Rule 3: If errors → Pause
    if ($CurrentState.Status -eq "Error") {
        $decision.action = "pause"
        $decision.reasoning = "Errors detected: $($CurrentState.Errors.Count) error(s)"
        $decision.confidence = 0.8
        return $decision
    }
    
    # Rule 4: If idle → Try to continue
    if ($CurrentState.Status -eq "Idle") {
        $decision.action = "continue"
        $decision.reasoning = "Session idle for $($CurrentState.IdleTime.TotalMinutes.ToString('F1')) minutes"
        $decision.command = "Please continue"
        $decision.confidence = 0.6
        return $decision
    }
    
    # Rule 5: If waiting for input → Continue
    if ($CurrentState.Status -eq "WaitingForInput") {
        $decision.action = "continue"
        $decision.reasoning = "Session waiting for input"
        $decision.command = "Please continue with the next task"
        $decision.confidence = 0.7
        return $decision
    }
    
    # Default: Pause
    $decision.action = "pause"
    $decision.reasoning = "Unclear state: $($CurrentState.Status)"
    $decision.confidence = 0.5
    return $decision
}
```

**Testing:**
- [ ] Returns correct action for each state
- [ ] Reasoning makes sense
- [ ] Confidence levels appropriate

---

#### Task 1.5: Action Execution
**Estimated Time:** 4 hours

Implement command sending:

**File:** `src/Action/Send-ClaudeCodeCommand.ps1`

```powershell
function Send-ClaudeCodeCommand {
    param(
        [Parameter(Mandatory)]
        [string]$SessionWindow,
        
        [Parameter(Mandatory)]
        [string]$Command,
        
        [int]$MaxRetries = 3
    )
    
    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        try {
            Write-Verbose "Sending command (attempt $($attempt + 1)/$MaxRetries): $Command"
            
            # Get current UI state
            $state = Invoke-WindowsMCPStateTool
            
            # Find Reply field
            $replyField = $state.InteractiveElements | 
                Where-Object { $_.Name -like "*Reply*" } |
                Select-Object -First 1
            
            if (-not $replyField) {
                throw "Reply field not found in UI"
            }
            
            # Click to focus
            Invoke-WindowsMCPClick -Coordinates $replyField.Coordinates
            Start-Sleep -Milliseconds 500
            
            # Type command
            Invoke-WindowsMCPType `
                -Coordinates $replyField.Coordinates `
                -Text $Command `
                -Clear $false
            
            Start-Sleep -Milliseconds 300
            
            # Press Enter
            Invoke-WindowsMCPKey -Key "enter"
            
            # Verify
            Start-Sleep -Seconds 2
            $verifyState = Invoke-WindowsMCPStateTool
            
            if (Test-CommandSent -State $verifyState -Command $Command) {
                Write-Verbose "Command sent successfully"
                return @{ Success = $true; Message = "Command sent" }
            }
            else {
                throw "Command verification failed"
            }
        }
        catch {
            $attempt++
            if ($attempt -ge $MaxRetries) {
                Write-Error "Failed after $MaxRetries attempts: $_"
                return @{ Success = $false; Message = $_.Exception.Message }
            }
            
            Write-Warning "Retry $attempt after error: $_"
            Start-Sleep -Seconds 2
        }
    }
}

function Test-CommandSent {
    param(
        [object]$State,
        [string]$Command
    )
    
    # Look for command in recent messages
    # Check if Reply field is now empty
    # Look for processing indicators
    
    # TODO: Implement verification logic
    return $true  # Assume success for now
}
```

**Testing:**
- [ ] Commands sent successfully
- [ ] Retries work on failure
- [ ] Verification detects issues

---

#### Task 1.6: Project Registration
**Estimated Time:** 3 hours

Implement project registration system:

**File:** `src/Registry/Register-Project.ps1`

```powershell
function Register-Project {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,
        
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )
    
    # Validate config file exists
    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }
    
    # Load and validate config
    $config = Get-Content $ConfigPath | ConvertFrom-Json
    Test-ProjectConfiguration -Config $config
    
    # Load registry
    $registryPath = Get-RegistryPath
    $registry = if (Test-Path $registryPath) {
        Get-Content $registryPath | ConvertFrom-Json
    }
    else {
        @{
            version = "1.0"
            lastUpdated = Get-Date
            projects = @{}
        }
    }
    
    # Add/update project
    $registry.projects[$ProjectName] = @{
        configPath = $ConfigPath
        registeredAt = Get-Date
        status = "Active"
        lastChecked = $null
        sessionId = $null
    }
    
    $registry.lastUpdated = Get-Date
    
    # Save registry
    $registry | ConvertTo-Json -Depth 10 | Set-Content $registryPath
    
    # Initialize project state
    Initialize-ProjectState -ProjectName $ProjectName -Config $config
    
    Write-Host "✅ Registered project: $ProjectName" -ForegroundColor Green
    Write-Host "   Config: $ConfigPath"
    Write-Host "   Repo: $($config.repoPath)"
}

function Test-ProjectConfiguration {
    param([object]$Config)
    
    # Validate required fields
    $requiredFields = @(
        "projectName",
        "repoPath",
        "automation",
        "phases"
    )
    
    foreach ($field in $requiredFields) {
        if (-not $Config.PSObject.Properties[$field]) {
            throw "Missing required field in config: $field"
        }
    }
    
    # Validate repo path exists
    if (-not (Test-Path $Config.repoPath)) {
        throw "Repository path does not exist: $($Config.repoPath)"
    }
    
    # Validate phases
    if ($Config.phases.Count -eq 0) {
        throw "At least one phase must be defined"
    }
    
    Write-Verbose "Configuration validated successfully"
}

function Initialize-ProjectState {
    param(
        [string]$ProjectName,
        [object]$Config
    )
    
    $stateDir = Join-Path $Config.repoPath ".claude-automation"
    
    # Create directory if doesn't exist
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir | Out-Null
    }
    
    # Create initial state file
    $statePath = Join-Path $stateDir "current-state.json"
    $initialState = @{
        projectName = $ProjectName
        currentPhase = $Config.phases[0].name
        phaseStartedAt = Get-Date
        status = "NotStarted"
        lastActivity = $null
        todosRemaining = 0
        todosCompleted = 0
        decisions = 0
        commits = 0
        errors = @()
        warnings = @()
    }
    
    $initialState | ConvertTo-Json -Depth 10 | Set-Content $statePath
    
    # Create empty decision log
    $logPath = Join-Path $stateDir "decision-log.md"
    $logHeader = @"
# Decision Log - $ProjectName

Project registered at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

---

"@
    Set-Content -Path $logPath -Value $logHeader
    
    Write-Verbose "Initialized state for project: $ProjectName"
}

function Get-RegistryPath {
    $homeDir = [Environment]::GetFolderPath("UserProfile")
    $configDir = Join-Path $homeDir ".claude-automation"
    
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir | Out-Null
    }
    
    return Join-Path $configDir "registry.json"
}
```

**Testing:**
- [ ] Can register new project
- [ ] Validates config properly
- [ ] Creates necessary files
- [ ] Handles errors gracefully

---

#### Task 1.7: Main Watchdog Loop
**Estimated Time:** 4 hours

Implement the core loop:

**File:** `src/Core/Start-Watchdog.ps1`

```powershell
param(
    [int]$PollingInterval = 120,  # 2 minutes
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$global:WatchdogRunning = $true

# Handle Ctrl+C gracefully
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    $global:WatchdogRunning = $false
}

function Start-Watchdog {
    Write-Host "🚀 Starting Claude Code Watchdog..." -ForegroundColor Cyan
    Write-Host "   Polling Interval: $PollingInterval seconds"
    Write-Host "   Press Ctrl+C to stop"
    Write-Host ""
    
    # Initialize
    Initialize-WatchdogEnvironment
    
    # Load registered projects
    $projects = Get-RegisteredProjects
    
    if ($projects.Count -eq 0) {
        Write-Warning "No projects registered. Use Register-Project to add projects."
        return
    }
    
    Write-Host "Monitoring $($projects.Count) project(s):" -ForegroundColor Green
    foreach ($proj in $projects.Keys) {
        Write-Host "  - $proj"
    }
    Write-Host ""
    
    $iteration = 0
    
    # Main loop
    while ($global:WatchdogRunning) {
        $iteration++
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Iteration $iteration" -ForegroundColor DarkGray
        
        foreach ($projectName in $projects.Keys) {
            $project = $projects[$projectName]
            
            if ($project.status -ne "Active") {
                continue
            }
            
            try {
                Process-Project -ProjectName $projectName
            }
            catch {
                Write-Error "Error processing project '$projectName': $_"
                Add-ErrorToLog -ProjectName $projectName -Error $_
            }
        }
        
        # Update heartbeat
        Update-Heartbeat
        
        # Sleep until next iteration
        Start-Sleep -Seconds $PollingInterval
    }
    
    Write-Host "`n👋 Watchdog stopped gracefully" -ForegroundColor Yellow
}

function Process-Project {
    param([string]$ProjectName)
    
    Write-Verbose "Processing project: $ProjectName"
    
    # Load project config and state
    $config = Get-ProjectConfig -ProjectName $ProjectName
    $state = Get-ProjectState -ProjectName $ProjectName
    
    # Find Claude Code session
    $session = Find-ClaudeCodeSession -ProjectName $ProjectName
    
    if (-not $session) {
        Write-Verbose "No active Claude Code session found for $ProjectName"
        return
    }
    
    # Get current UI state
    $uiState = Get-ClaudeCodeState -SessionWindow $session
    
    Write-Host "  [$ProjectName] Status: $($uiState.Status)" -ForegroundColor Cyan
    
    # Update project state with UI info
    Update-ProjectState -ProjectName $ProjectName -UIState $uiState
    
    # Make decision
    $decision = Invoke-SimpleDecision `
        -ProjectName $ProjectName `
        -CurrentState $uiState `
        -ProjectConfig $config
    
    Write-Host "  [$ProjectName] Decision: $($decision.action) - $($decision.reasoning)" -ForegroundColor Yellow
    
    # Execute action
    if ($decision.action -ne "pause") {
        $result = Invoke-Action `
            -ProjectName $ProjectName `
            -Decision $decision `
            -SessionWindow $session
        
        if ($result.Success) {
            Write-Host "  [$ProjectName] ✅ Action completed" -ForegroundColor Green
        }
        else {
            Write-Host "  [$ProjectName] ❌ Action failed: $($result.Message)" -ForegroundColor Red
        }
    }
    else {
        Send-Notification `
            -ProjectName $ProjectName `
            -Type "Warning" `
            -Message $decision.reasoning
    }
}

function Initialize-WatchdogEnvironment {
    # Ensure directories exist
    $homeDir = [Environment]::GetFolderPath("UserProfile")
    $configDir = Join-Path $homeDir ".claude-automation"
    
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir | Out-Null
    }
    
    # Initialize logs
    $logPath = Join-Path $configDir "global-log.md"
    if (-not (Test-Path $logPath)) {
        Set-Content -Path $logPath -Value "# Claude Code Watchdog - Global Log`n`n"
    }
    
    Write-Verbose "Environment initialized"
}

function Update-Heartbeat {
    $homeDir = [Environment]::GetFolderPath("UserProfile")
    $heartbeatPath = Join-Path $homeDir ".claude-automation\heartbeat.txt"
    
    Set-Content -Path $heartbeatPath -Value (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
}

# Start the watchdog
Start-Watchdog
```

**Testing:**
- [ ] Loop runs continuously
- [ ] Processes all projects
- [ ] Handles errors without crashing
- [ ] Stops gracefully on Ctrl+C

---

#### Task 1.8: Logging System
**Estimated Time:** 2 hours

Implement logging functions:

**File:** `src/Logging/Write-WatchdogLog.ps1`

```powershell
function Write-WatchdogLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$ProjectName = "Global",
        
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$ProjectName] [$Level] $Message"
    
    # Console output
    $color = @{
        "Info" = "White"
        "Warning" = "Yellow"
        "Error" = "Red"
        "Success" = "Green"
    }[$Level]
    
    Write-Host $logEntry -ForegroundColor $color
    
    # File output
    $logFile = if ($ProjectName -eq "Global") {
        Get-GlobalLogPath
    }
    else {
        $config = Get-ProjectConfig -ProjectName $ProjectName
        Join-Path $config.repoPath ".claude-automation\watchdog-activity.log"
    }
    
    Add-Content -Path $logFile -Value $logEntry
}

function Add-DecisionToLog {
    param(
        [string]$ProjectName,
        [hashtable]$Decision,
        [hashtable]$State
    )
    
    $config = Get-ProjectConfig -ProjectName $ProjectName
    $logPath = Join-Path $config.repoPath ".claude-automation\decision-log.md"
    
    $entry = @"

## $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $($Decision.action)

**State:** $($State.Status)
**Idle Time:** $($State.IdleTime.TotalMinutes.ToString('F1'))m

**Decision ($($Decision.DecisionMethod)):**
- Action: ``$($Decision.action)``
- Reasoning: "$($Decision.reasoning)"
- Confidence: $($Decision.confidence)

$(if ($Decision.command) {
"**Command:**
\`\`\`
$($Decision.command)
\`\`\`"
})

---

"@
    
    Add-Content -Path $logPath -Value $entry
}

function Send-Notification {
    param(
        [string]$ProjectName,
        [string]$Type,
        [string]$Message,
        [switch]$Urgent
    )
    
    Write-WatchdogLog -Message $Message -ProjectName $ProjectName -Level $Type
    
    # Windows Toast (for urgent/errors)
    if ($Urgent -or $Type -in @("Error", "Warning")) {
        # Requires BurntToast module
        if (Get-Module -ListAvailable -Name "BurntToast") {
            New-BurntToastNotification `
                -Text "Claude Watchdog: $ProjectName", $Message
        }
    }
}
```

---

### Phase 1 Deliverables Checklist

- [ ] All scripts created and documented
- [ ] Windows MCP integration working
- [ ] State detection identifies 6 states correctly
- [ ] Simple decision logic implemented
- [ ] Commands sent to Claude Code successfully
- [ ] Project registration system functional
- [ ] Main watchdog loop runs continuously
- [ ] Logging system operational
- [ ] Basic testing completed
- [ ] Documentation updated

### Phase 1 Testing

Create a test project and verify:
1. Register the test project
2. Start a Claude Code session
3. Start watchdog
4. Verify watchdog detects session
5. Verify state detection works
6. Verify decisions are logged
7. Verify commands are sent
8. Verify auto-continue works
9. Stop watchdog gracefully
10. Review logs

---

## Next Phases (High-Level Overview)

### Phase 2: Smart Decisions (Week 2)
- Claude API integration
- Skill-based error resolution
- Cost tracking
- Enhanced decision logic

### Phase 3: Multi-Project & Git (Week 3)
- Multi-project monitoring
- Git operations (commit, push, PR)
- Phase transitions
- Session recovery

### Phase 4: Polish & Documentation (Week 4)
- Comprehensive testing
- Error handling improvements
- Complete documentation
- Installation wizard

---

## Getting Started Checklist

Before starting implementation:
- [ ] Windows MCP installed and configured
- [ ] PowerShell 7+ installed
- [ ] BurntToast module installed: `Install-Module BurntToast`
- [ ] Git configured with SSH
- [ ] Claude API key obtained (for Phase 2)
- [ ] Test repository created
- [ ] Development environment ready

## Tips for Claude Code

1. **Start with Phase 1, Task 1.1** - Create the directory structure first
2. **Implement incrementally** - Test each function before moving on
3. **Use the example-project-config.json** as a template
4. **Test with a simple project** before using on production code
5. **Keep logs** - They're invaluable for debugging
6. **Ask questions** if requirements are unclear
7. **Document as you go** - Update docs with any changes

## Common Issues & Solutions

### Issue: Windows MCP not responding
**Solution:** Check if Windows-MCP server is running, restart if needed

### Issue: Cannot find Claude Code window
**Solution:** Verify Chrome window title matches expected pattern

### Issue: Commands not sending
**Solution:** Check Reply field coordinates, may need recalibration

### Issue: Watchdog crashes
**Solution:** Check error logs, add more try/catch blocks

### Issue: State detection inaccurate
**Solution:** Capture screenshots for debugging, adjust selectors

## Success Metrics

Phase 1 is successful when:
- Watchdog runs for 2+ hours without crashing
- Successfully monitors 1 project end-to-end
- Auto-continues on TODOs correctly
- Logs all decisions with reasoning
- Notifications work for errors/completion
- Code is clean and well-documented

## Questions to Resolve During Implementation

1. What is the exact structure of Windows MCP JSON responses?
2. How do we reliably detect "processing" state vs "idle"?
3. What are the best coordinates to use for Reply field (stable across sessions)?
4. How long should we wait between command send and verification?
5. What's the best way to detect when a commit completes?

Document answers as you discover them!
