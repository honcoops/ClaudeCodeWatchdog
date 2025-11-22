# Technical Architecture - Claude Code Watchdog

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Interface Layer                      │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐   │
│  │ PowerShell   │  │  Windows     │  │  Log Files &       │   │
│  │ Commands     │  │  Toast       │  │  Markdown Reports  │   │
│  └──────────────┘  └──────────────┘  └────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                      Orchestration Layer                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │           Main Watchdog Loop (PowerShell)                │   │
│  │  - Project Registry Management                           │   │
│  │  - State Machine Controller                              │   │
│  │  - Polling Scheduler (2-minute intervals)                │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                        Business Logic Layer                      │
│  ┌───────────────┐  ┌───────────────┐  ┌──────────────────┐   │
│  │ State         │  │ Decision      │  │  Action          │   │
│  │ Detection     │  │ Engine        │  │  Executor        │   │
│  │ Module        │  │ Module        │  │  Module          │   │
│  └───────────────┘  └───────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                        Integration Layer                         │
│  ┌───────────┐  ┌────────────┐  ┌──────────┐  ┌────────────┐  │
│  │ Windows   │  │ Claude API │  │   Git    │  │  GitHub    │  │
│  │   MCP     │  │ (Anthropic)│  │   CLI    │  │    API     │  │
│  └───────────┘  └────────────┘  └──────────┘  └────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                         Target Systems                           │
│  ┌───────────────────┐         ┌──────────────────────────┐    │
│  │  Claude Code      │         │  Project Repositories    │    │
│  │  (Chrome Browser) │         │  (GitHub)                │    │
│  └───────────────────┘         └──────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Module Breakdown

### 1. Main Watchdog Module (`Start-Watchdog.ps1`)

**Responsibilities:**
- Initialize watchdog service
- Load registered projects
- Execute main polling loop
- Handle graceful shutdown
- Manage process lifecycle

**Key Functions:**
```powershell
function Start-Watchdog {
    Initialize-WatchdogEnvironment
    Load-RegisteredProjects
    
    while ($global:WatchdogRunning) {
        $projects = Get-ActiveProjects
        
        foreach ($project in $projects) {
            try {
                Process-Project -Project $project
            }
            catch {
                Handle-ProjectError -Project $project -Error $_
            }
        }
        
        Update-Heartbeat
        Start-Sleep -Seconds 120  # 2-minute polling interval
    }
    
    Cleanup-WatchdogResources
}
```

**Dependencies:**
- Project-Registry.ps1
- State-Detection.ps1
- Decision-Engine.ps1
- Action-Executor.ps1

### 2. Project Registry Module (`Project-Registry.ps1`)

**Responsibilities:**
- Register/unregister projects
- Load project configurations
- Maintain project state
- Validate configurations
- Provide project lookup

**Key Functions:**
```powershell
function Register-Project {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,
        
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )
    
    # Validate config
    $config = Get-Content $ConfigPath | ConvertFrom-Json
    Test-ProjectConfiguration -Config $config
    
    # Register in central registry
    $registry = Get-WatchdogRegistry
    $registry.Projects[$ProjectName] = @{
        ConfigPath = $ConfigPath
        RegisteredAt = Get-Date
        Status = "Active"
        LastChecked = $null
    }
    
    Save-WatchdogRegistry -Registry $registry
    Initialize-ProjectState -ProjectName $ProjectName -Config $config
    
    Write-Host "✅ Registered project: $ProjectName" -ForegroundColor Green
}

function Get-RegisteredProjects {
    $registry = Get-WatchdogRegistry
    return $registry.Projects | Where-Object { $_.Status -eq "Active" }
}

function Get-ProjectConfig {
    param([string]$ProjectName)
    
    $registry = Get-WatchdogRegistry
    $project = $registry.Projects[$ProjectName]
    
    if (-not $project) {
        throw "Project not found: $ProjectName"
    }
    
    return Get-Content $project.ConfigPath | ConvertFrom-Json
}
```

**Data Structures:**

Registry File (`~/.claude-automation/registry.json`):
```json
{
  "version": "1.0",
  "lastUpdated": "2024-11-22T14:30:00Z",
  "projects": {
    "team-project-assignment": {
      "configPath": "C:/repos/team-project-assignment/.claude-automation/project-config.json",
      "registeredAt": "2024-11-22T10:00:00Z",
      "status": "Active",
      "lastChecked": "2024-11-22T14:28:00Z",
      "sessionId": "01WZQC04Z031XZH13huuW7Vx"
    }
  }
}
```

Project State File (`{repo}/.claude-automation/current-state.json`):
```json
{
  "projectName": "team-project-assignment",
  "currentPhase": "implementation",
  "phaseStartedAt": "2024-11-22T11:00:00Z",
  "status": "InProgress",
  "lastActivity": "2024-11-22T14:28:00Z",
  "todosRemaining": 5,
  "todosCompleted": 12,
  "decisions": 47,
  "commits": 3,
  "apiCalls": 47,
  "totalCost": 1.20,
  "errors": [],
  "warnings": [],
  "currentBranch": "claude/implementation-20241122",
  "lastCommand": "Continue with next TODO: Fix compilation errors",
  "nextReview": "2024-11-22T16:00:00Z"
}
```

### 3. State Detection Module (`State-Detection.ps1`)

**Responsibilities:**
- Capture Claude Code UI state
- Parse UI elements
- Classify session status
- Detect TODOs and errors
- Calculate idle time
- Identify session context

**Key Functions:**
```powershell
function Get-ClaudeCodeState {
    param(
        [string]$SessionWindow,
        [switch]$IncludeScreenshot
    )
    
    # Capture UI state using Windows MCP
    $uiState = Invoke-WindowsMCPStateTool -UseVision:$IncludeScreenshot
    
    # Parse for key indicators
    $state = @{
        Status = "Unknown"
        SessionId = Get-SessionIdFromURL -UIState $uiState
        HasReplyField = Test-ReplyFieldAvailable -UIState $uiState
        ReplyFieldCoordinates = Get-ReplyFieldLocation -UIState $uiState
        Todos = Get-TodosList -UIState $uiState
        Errors = Get-ErrorMessages -UIState $uiState
        Warnings = Get-WarningMessages -UIState $uiState
        LastTokenTimestamp = Get-LastTokenTimestamp -UIState $uiState
        IsProcessing = Test-ProcessingIndicator -UIState $uiState
        CurrentPhase = Get-CurrentPhaseFromUI -UIState $uiState
        IdleTime = Calculate-IdleTime -UIState $uiState
    }
    
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
    
    if ($ParsedState.Todos.Remaining -eq 0 -and $ParsedState.HasReplyField) {
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

function Get-TodosList {
    param([object]$UIState)
    
    # Look for "Update Todos" section
    $todosSection = $UIState.InformativeElements | 
        Where-Object { $_.Text -like "*Update Todos*" -or $_.Text -like "*Todos*" }
    
    if (-not $todosSection) {
        return @{ Total = 0; Completed = 0; Remaining = 0; Items = @() }
    }
    
    # Parse checkbox states
    $checkboxes = $UIState.InteractiveElements | 
        Where-Object { $_.ControlType -eq "CheckBox" -and $_.IsNear($todosSection) }
    
    $completed = ($checkboxes | Where-Object { $_.IsChecked }).Count
    $total = $checkboxes.Count
    
    return @{
        Total = $total
        Completed = $completed
        Remaining = $total - $completed
        Items = $checkboxes | ForEach-Object { 
            @{ 
                Text = $_.Name
                Completed = $_.IsChecked
            } 
        }
    }
}

function Get-ErrorMessages {
    param([object]$UIState)
    
    $errorIndicators = @(
        "*error*", "*failed*", "*exception*", 
        "*cannot*", "*unable*", "*❌*"
    )
    
    $errors = $UIState.InformativeElements | Where-Object {
        $text = $_.Text.ToLower()
        $errorIndicators | Where-Object { $text -like $_ }
    }
    
    return $errors | ForEach-Object {
        @{
            Message = $_.Text
            Location = $_.Coordinates
            Severity = Get-ErrorSeverity -Message $_.Text
        }
    }
}
```

**Windows MCP Integration:**
```powershell
function Invoke-WindowsMCPStateTool {
    param([bool]$UseVision = $false)
    
    # Call Windows MCP State-Tool
    $params = @{
        use_vision = $UseVision
    }
    
    $result = & "windows-mcp" "State-Tool" ($params | ConvertTo-Json)
    
    return $result | ConvertFrom-Json
}
```

### 4. Decision Engine Module (`Decision-Engine.ps1`)

**Responsibilities:**
- Analyze current state
- Consult project configuration
- Make decisions via Claude API or rules
- Estimate decision confidence
- Track decision history
- Manage API costs

**Key Functions:**
```powershell
function Invoke-DecisionEngine {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,
        
        [Parameter(Mandatory)]
        [hashtable]$CurrentState,
        
        [Parameter(Mandatory)]
        [object]$ProjectConfig
    )
    
    # Get recent decision history
    $history = Get-DecisionHistory -ProjectName $ProjectName -Last 10
    
    # Check if we should use API or rule-based decision
    $apiCosts = Get-APICosts -ProjectName $ProjectName
    $useAPI = ($apiCosts.DailyTotal -lt $ProjectConfig.CostThresholds.DailyLimit)
    
    if ($useAPI) {
        $decision = Invoke-ClaudeAPIDecision `
            -ProjectName $ProjectName `
            -CurrentState $CurrentState `
            -ProjectConfig $ProjectConfig `
            -History $history
    }
    else {
        Write-Warning "Daily API cost limit reached. Using rule-based decisions."
        $decision = Invoke-RuleBasedDecision `
            -ProjectName $ProjectName `
            -CurrentState $CurrentState `
            -ProjectConfig $ProjectConfig
    }
    
    # Log decision
    Add-DecisionToLog -ProjectName $ProjectName -Decision $decision -State $CurrentState
    
    return $decision
}

function Invoke-ClaudeAPIDecision {
    param(
        [string]$ProjectName,
        [hashtable]$CurrentState,
        [object]$ProjectConfig,
        [array]$History
    )
    
    # Build comprehensive prompt
    $prompt = Build-DecisionPrompt `
        -ProjectName $ProjectName `
        -State $CurrentState `
        -Config $ProjectConfig `
        -History $History
    
    # Call Claude API
    $response = Invoke-AnthropicAPI `
        -Model "claude-sonnet-4-20250514" `
        -MaxTokens 1000 `
        -Messages @(@{
            role = "user"
            content = $prompt
        })
    
    # Parse JSON response
    $decision = $response.content[0].text | ConvertFrom-Json
    
    # Add metadata
    $decision.DecisionMethod = "API"
    $decision.TokensUsed = $response.usage.total_tokens
    $decision.Cost = Calculate-APICost -Usage $response.usage
    $decision.Timestamp = Get-Date
    
    # Update cost tracking
    Update-APICosts -ProjectName $ProjectName -Cost $decision.Cost
    
    return $decision
}

function Invoke-RuleBasedDecision {
    param(
        [string]$ProjectName,
        [hashtable]$CurrentState,
        [object]$ProjectConfig
    )
    
    $decision = @{
        action = $null
        reasoning = $null
        confidence = 0.7
        command = $null
        skill = $null
        DecisionMethod = "Rules"
        Cost = 0
        Timestamp = Get-Date
    }
    
    # Rule 1: If has TODOs and auto-progress enabled → Continue
    if ($CurrentState.Status -eq "HasTodos" -and $ProjectConfig.autoProgress) {
        $decision.action = "continue"
        $decision.reasoning = "Auto-progress enabled and TODOs remaining"
        $decision.command = "Continue with next TODO"
        $decision.confidence = 0.9
        return $decision
    }
    
    # Rule 2: If phase complete → Commit and advance
    if ($CurrentState.Status -eq "PhaseComplete") {
        $decision.action = "commit_and_next"
        $decision.reasoning = "Current phase TODOs completed"
        $decision.confidence = 0.95
        return $decision
    }
    
    # Rule 3: If errors → Check if skill can help
    if ($CurrentState.Status -eq "Error") {
        $matchingSkill = Find-SkillForError `
            -Errors $CurrentState.Errors `
            -AvailableSkills $ProjectConfig.skills
        
        if ($matchingSkill) {
            $decision.action = "use_skill"
            $decision.skill = $matchingSkill
            $decision.reasoning = "Error matches available skill: $matchingSkill"
            $decision.command = "Use $matchingSkill to resolve these errors. Read and follow: $matchingSkill/SKILL.md"
            $decision.confidence = 0.85
            return $decision
        }
        else {
            $decision.action = "pause"
            $decision.reasoning = "Errors detected but no matching skill available"
            $decision.confidence = 0.8
            return $decision
        }
    }
    
    # Rule 4: If idle too long → Investigate
    if ($CurrentState.Status -eq "Idle") {
        $decision.action = "investigate"
        $decision.reasoning = "Session idle for $($CurrentState.IdleTime.TotalMinutes) minutes"
        $decision.command = "Please provide a status update"
        $decision.confidence = 0.6
        return $decision
    }
    
    # Default: Pause for human
    $decision.action = "pause"
    $decision.reasoning = "Unclear state, requesting human review"
    $decision.confidence = 0.5
    return $decision
}

function Build-DecisionPrompt {
    param(
        [string]$ProjectName,
        [hashtable]$State,
        [object]$Config,
        [array]$History
    )
    
    $historyText = $History | ForEach-Object {
        "- $($_.Timestamp.ToString('HH:mm:ss')): $($_.Action) → $($_.Result)"
    } | Join-String -Separator "`n"
    
    return @"
You are managing a Claude Code session for project: $ProjectName

CURRENT STATE:
- Status: $($State.Status)
- Phase: $($State.CurrentPhase)
- TODOs: $($State.Todos.Completed)/$($State.Todos.Total) complete ($($State.Todos.Remaining) remaining)
- Errors: $($State.Errors.Count)
- Idle Time: $($State.IdleTime.TotalMinutes.ToString('F1')) minutes
- Last Activity: $($State.LastTokenTimestamp)

ERROR DETAILS:
$($State.Errors | ForEach-Object { "- $($_.Message)" } | Join-String -Separator "`n")

PROJECT CONFIGURATION:
- Auto-Progress: $($Config.autoProgress)
- Auto-Commit: $($Config.autoCommit)
- Available Skills:
$($Config.skills | ForEach-Object { "  - $_" } | Join-String -Separator "`n")
- Requires Approval For:
$($Config.requiresApprovalFor | ForEach-Object { "  - $_" } | Join-String -Separator "`n")
- Requires Human After:
$($Config.requiresHumanAfter | ForEach-Object { "  - $_" } | Join-String -Separator "`n")

RECENT HISTORY (last 10 actions):
$historyText

TASK: Decide the next action for this Claude Code session.

GUIDELINES:
1. Use "continue" for straightforward progression through TODOs
2. Use "use_skill" when errors match available skill capabilities
3. Use "pause" when human judgment is required or for ambiguous situations
4. Use "commit_and_next" when current phase is complete
5. Use "investigate" when session appears stuck or unclear
6. Prioritize skills over ad-hoc fixes when applicable
7. Be conservative - prefer "pause" when uncertain
8. Consider project configuration rules (requires approval for specific changes)

RESPOND WITH VALID JSON ONLY (no markdown, no explanation):
{
  "action": "continue|use_skill|pause|commit_and_next|investigate",
  "reasoning": "Brief explanation (1-2 sentences)",
  "skill": "full-skill-path (only if action=use_skill, otherwise null)",
  "command": "Exact text to send to Claude Code (if applicable, otherwise null)",
  "confidence": 0.0-1.0,
  "estimatedImpact": "low|medium|high"
}
"@
}
```

**Anthropic API Integration:**
```powershell
function Invoke-AnthropicAPI {
    param(
        [string]$Model = "claude-sonnet-4-20250514",
        [int]$MaxTokens = 1000,
        [array]$Messages
    )
    
    # Get API key from secure storage
    $apiKey = Get-SecureAPIKey
    
    # Build request
    $body = @{
        model = $Model
        max_tokens = $MaxTokens
        messages = $Messages
    } | ConvertTo-Json -Depth 10
    
    # Call API
    $headers = @{
        "x-api-key" = $apiKey
        "anthropic-version" = "2023-06-01"
        "content-type" = "application/json"
    }
    
    try {
        $response = Invoke-RestMethod `
            -Uri "https://api.anthropic.com/v1/messages" `
            -Method Post `
            -Headers $headers `
            -Body $body
        
        return $response
    }
    catch {
        Write-Error "API call failed: $_"
        throw
    }
}

function Get-SecureAPIKey {
    # Retrieve from Windows Credential Manager
    $credential = Get-StoredCredential -Target "ClaudeWatchdog-AnthropicAPI"
    
    if (-not $credential) {
        throw "API key not found. Run: Set-WatchdogAPIKey"
    }
    
    return $credential.GetNetworkCredential().Password
}

function Set-WatchdogAPIKey {
    param([string]$APIKey)
    
    # Store securely in Windows Credential Manager
    $credential = New-Object System.Management.Automation.PSCredential(
        "ClaudeWatchdog",
        (ConvertTo-SecureString $APIKey -AsPlainText -Force)
    )
    
    Set-StoredCredential -Target "ClaudeWatchdog-AnthropicAPI" -Credential $credential
    
    Write-Host "✅ API key stored securely" -ForegroundColor Green
}
```

### 5. Action Executor Module (`Action-Executor.ps1`)

**Responsibilities:**
- Execute decisions
- Interact with Claude Code UI
- Perform Git operations
- Create PRs on GitHub
- Verify action success
- Handle action failures
- Retry with backoff

**Key Functions:**
```powershell
function Invoke-WatchdogAction {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,
        
        [Parameter(Mandatory)]
        [hashtable]$Decision,
        
        [Parameter(Mandatory)]
        [string]$SessionWindow
    )
    
    Write-Log "Executing action: $($Decision.action)" -Project $ProjectName
    
    $result = switch ($Decision.action) {
        "continue" {
            Send-ClaudeCodeCommand -Window $SessionWindow -Command $Decision.command
        }
        
        "use_skill" {
            $command = @"
$($Decision.command)

Please read and follow the skill documentation at: $($Decision.skill)/SKILL.md
"@
            Send-ClaudeCodeCommand -Window $SessionWindow -Command $command
        }
        
        "commit_and_next" {
            Invoke-PhaseTransition -ProjectName $ProjectName -SessionWindow $SessionWindow
        }
        
        "pause" {
            Send-Notification `
                -ProjectName $ProjectName `
                -Type "Warning" `
                -Message "Human review needed: $($Decision.reasoning)" `
                -Urgent
            
            Set-ProjectStatus -ProjectName $ProjectName -Status "PausedForHuman"
            
            @{ Success = $true; Message = "Project paused" }
        }
        
        "investigate" {
            Send-ClaudeCodeCommand -Window $SessionWindow -Command $Decision.command
        }
        
        default {
            throw "Unknown action: $($Decision.action)"
        }
    }
    
    # Update project state
    Update-ProjectState -ProjectName $ProjectName -Action $Decision -Result $result
    
    return $result
}

function Send-ClaudeCodeCommand {
    param(
        [Parameter(Mandatory)]
        [string]$Window,
        
        [Parameter(Mandatory)]
        [string]$Command,
        
        [int]$MaxRetries = 3
    )
    
    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        try {
            # Get current UI state to find Reply field
            $state = Invoke-WindowsMCPStateTool
            $replyField = $state.InteractiveElements | 
                Where-Object { $_.Name -like "*Reply*" -or $_.ControlType -eq "EditBox" } |
                Select-Object -First 1
            
            if (-not $replyField) {
                throw "Cannot locate Reply field in Claude Code UI"
            }
            
            # Click on Reply field to focus
            Invoke-WindowsMCPClick -Coordinates $replyField.Coordinates
            Start-Sleep -Milliseconds 500
            
            # Type command
            Invoke-WindowsMCPType `
                -Coordinates $replyField.Coordinates `
                -Text $Command `
                -Clear $false
            
            Start-Sleep -Milliseconds 300
            
            # Press Enter to send
            Invoke-WindowsMCPKey -Key "enter"
            
            # Verify command was sent (look for command in UI)
            Start-Sleep -Seconds 2
            $verifyState = Invoke-WindowsMCPStateTool
            
            if (Test-CommandSent -State $verifyState -Command $Command) {
                Write-Log "✅ Command sent successfully: $Command"
                return @{ Success = $true; Message = "Command sent" }
            }
            else {
                throw "Command verification failed"
            }
        }
        catch {
            $attempt++
            if ($attempt -eq $MaxRetries) {
                Write-Error "Failed to send command after $MaxRetries attempts: $_"
                return @{ Success = $false; Message = $_.Exception.Message }
            }
            
            Write-Warning "Command send attempt $attempt failed, retrying..."
            Start-Sleep -Seconds 2
        }
    }
}

function Invoke-WindowsMCPClick {
    param([array]$Coordinates)
    
    # Call Windows MCP Click-Tool
    $params = @{
        loc = $Coordinates
        button = "left"
        clicks = 1
    }
    
    & "windows-mcp" "Click-Tool" ($params | ConvertTo-Json)
}

function Invoke-WindowsMCPType {
    param(
        [array]$Coordinates,
        [string]$Text,
        [bool]$Clear = $false
    )
    
    $params = @{
        loc = $Coordinates
        text = $Text
        clear = $Clear
    }
    
    & "windows-mcp" "Type-Tool" ($params | ConvertTo-Json)
}

function Invoke-WindowsMCPKey {
    param([string]$Key)
    
    $params = @{ key = $Key }
    
    & "windows-mcp" "Key-Tool" ($params | ConvertTo-Json)
}

function Invoke-PhaseTransition {
    param(
        [string]$ProjectName,
        [string]$SessionWindow
    )
    
    $config = Get-ProjectConfig -ProjectName $ProjectName
    $state = Get-ProjectState -ProjectName $ProjectName
    
    # Get current and next phase
    $currentPhaseIndex = $config.phases.FindIndex({ $_.name -eq $state.currentPhase })
    $nextPhase = $config.phases[$currentPhaseIndex + 1]
    
    # Trigger commit in Claude Code
    $commitMessage = "Completed phase: $($state.currentPhase)"
    Send-ClaudeCodeCommand `
        -Window $SessionWindow `
        -Command "Please commit and push these changes with message: '$commitMessage'"
    
    # Wait for commit to complete (poll git status)
    Wait-ForGitCommit -RepoPath $config.repoPath -Timeout 300
    
    # Create PR if configured
    if ($config.commitStrategy.prCreation -eq "phase-completion") {
        $pr = New-GitHubPullRequest `
            -RepoUrl $config.repoUrl `
            -Branch $state.currentBranch `
            -Title "Phase Complete: $($state.currentPhase)" `
            -Body "Automated PR from Claude Code Watchdog"
        
        Write-Log "✅ Created PR: $($pr.html_url)"
        
        Send-Notification `
            -ProjectName $ProjectName `
            -Type "Success" `
            -Message "Phase '$($state.currentPhase)' complete. PR created: $($pr.html_url)"
    }
    
    # If there's a next phase, start it
    if ($nextPhase) {
        Update-ProjectState -ProjectName $ProjectName -Phase $nextPhase.name
        
        $nextCommand = "Begin phase: $($nextPhase.name)"
        Send-ClaudeCodeCommand -Window $SessionWindow -Command $nextCommand
        
        Write-Log "🚀 Started next phase: $($nextPhase.name)"
    }
    else {
        # Project complete!
        Set-ProjectStatus -ProjectName $ProjectName -Status "Complete"
        
        Send-Notification `
            -ProjectName $ProjectName `
            -Type "Success" `
            -Message "Project complete! All phases finished." `
            -Urgent
    }
    
    return @{ Success = $true; Message = "Phase transition complete" }
}
```

### 6. Logging & Notification Module (`Logging.ps1`)

**Responsibilities:**
- Write to markdown decision logs
- Append to activity logs
- Send Windows notifications
- Generate progress reports
- Track metrics

**Key Functions:**
```powershell
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
**Phase:** $($State.CurrentPhase)
**Idle Time:** $($State.IdleTime.TotalMinutes.ToString('F1'))m

**Context:**
- TODOs: $($State.Todos.Completed)/$($State.Todos.Total) complete
- Errors: $($State.Errors.Count)
- Last Activity: $($State.LastTokenTimestamp)

**Decision ($($Decision.DecisionMethod)):**
- Action: ``$($Decision.action)``
- Reasoning: "$($Decision.reasoning)"
- Confidence: $($Decision.confidence)
- Cost: $$(if ($Decision.Cost) { $Decision.Cost.ToString('F4') } else { '0.0000' })

$(if ($Decision.skill) { "**Skill:** ``$($Decision.skill)``" })

$(if ($Decision.command) {
"**Command Sent:**
\`\`\`
$($Decision.command)
\`\`\`"
})

**Result:** ✅ Executed successfully

---

"@
    
    Add-Content -Path $logPath -Value $entry
}

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$Project = "Global",
        
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Project] [$Level] $Message"
    
    # Console output with color
    $color = @{
        "Info" = "White"
        "Warning" = "Yellow"
        "Error" = "Red"
        "Success" = "Green"
    }[$Level]
    
    Write-Host $logEntry -ForegroundColor $color
    
    # File output
    $logFile = if ($Project -eq "Global") {
        "~/.claude-automation/global-log.md"
    }
    else {
        $config = Get-ProjectConfig -ProjectName $Project
        Join-Path $config.repoPath ".claude-automation\watchdog-activity.log"
    }
    
    Add-Content -Path $logFile -Value $logEntry
}

function Send-Notification {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,
        
        [Parameter(Mandatory)]
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Type,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [switch]$Urgent
    )
    
    # Log notification
    Write-Log -Message $Message -Project $ProjectName -Level $Type
    
    # Windows Toast (for urgent or errors)
    if ($Urgent -or $Type -in @("Error", "Warning")) {
        $toastParams = @{
            Text = "Claude Code Watchdog: $ProjectName", $Message
            AppLogo = "C:\path\to\claude-icon.png"  # Update with actual path
        }
        
        New-BurntToastNotification @toastParams
    }
    
    # Add to notification log
    $notificationLog = "~/.claude-automation/notifications.log"
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$ProjectName] $Type: $Message"
    Add-Content -Path $notificationLog -Value $entry
}
```

## Data Flow Diagram

```
┌──────────────────┐
│  Start Watchdog  │
└────────┬─────────┘
         │
         v
┌──────────────────────────┐
│ Load Registered Projects │
└────────┬─────────────────┘
         │
         v
    ┌────────────────────┐
    │ Main Polling Loop  │◄──────────────┐
    │ (Every 2 minutes)  │               │
    └────────┬───────────┘               │
             │                           │
             v                           │
    ┌──────────────────┐                │
    │ For Each Project │                │
    └────────┬─────────┘                │
             │                           │
             v                           │
    ┌───────────────────────┐           │
    │ Find Claude Code      │           │
    │ Session (Windows MCP) │           │
    └────────┬──────────────┘           │
             │                           │
             v                           │
    ┌───────────────────┐               │
    │ Get UI State      │               │
    │ (State Detection) │               │
    └────────┬──────────┘               │
             │                           │
             v                           │
    ┌────────────────────┐              │
    │ Classify Status    │              │
    │ (HasTodos, Error,  │              │
    │  PhaseComplete)    │              │
    └────────┬───────────┘              │
             │                           │
             v                           │
    ┌──────────────────────┐            │
    │ Make Decision        │            │
    │ (API or Rule-based)  │            │
    └────────┬─────────────┘            │
             │                           │
             v                           │
    ┌──────────────────┐                │
    │ Execute Action   │                │
    │ (Send command,   │                │
    │  Git ops, etc)   │                │
    └────────┬─────────┘                │
             │                           │
             v                           │
    ┌────────────────────┐              │
    │ Update State       │              │
    │ & Logs             │              │
    └────────┬───────────┘              │
             │                           │
             v                           │
    ┌──────────────────────┐            │
    │ Send Notifications   │            │
    │ (if needed)          │            │
    └────────┬─────────────┘            │
             │                           │
             └───────────────────────────┘
```

## Error Handling Strategy

### Retry Logic
- UI interaction failures: 3 retries with 2s backoff
- API failures: 2 retries with 5s backoff
- Git operations: 2 retries with 3s backoff

### Graceful Degradation
- API unavailable → Fall back to rule-based decisions
- Windows MCP fails → Notify and pause
- Git operation fails → Log and notify, don't crash

### Recovery Mechanisms
- Watchdog crash → Auto-restart via scheduled task
- Session lost → Notify human, provide recovery options
- State corruption → Rebuild from logs

## Performance Considerations

### Optimization Strategies
1. **Caching:** Cache UI state for 30s to reduce MCP calls
2. **Lazy Loading:** Only load project configs when needed
3. **Async Operations:** Use PowerShell jobs for parallel processing
4. **Throttling:** Rate-limit API calls (max 1 per project per minute)

### Resource Limits
- Max 5 concurrent projects
- Max 100MB total memory usage
- Max 200 API calls per hour
- Max 1GB log file size (rotate after)

## Security Considerations

### Secrets Management
- API keys stored in Windows Credential Manager
- No secrets in logs or state files
- Git credentials use SSH keys (no passwords in config)

### Input Validation
- Validate all project configs before use
- Sanitize commands before sending to Claude Code
- Verify URLs before Git operations

### Least Privilege
- Run watchdog as regular user (not admin)
- Only write to designated directories
- Read-only access to project files (except .claude-automation/)

## Testing Strategy

### Unit Tests
- Test each module function independently
- Mock Windows MCP responses
- Validate decision logic with fixtures

### Integration Tests
- Test full workflow with test project
- Verify Git operations (use test repo)
- Check API integration (use test key with limits)

### Manual Testing Checklist
- [ ] Watchdog starts and runs continuously
- [ ] Project registration works
- [ ] State detection accurate
- [ ] Decisions make sense
- [ ] Commands sent successfully
- [ ] Git operations complete
- [ ] Notifications received
- [ ] Logs written correctly
- [ ] Cost tracking accurate
- [ ] Recovery after crashes

## Deployment

### Installation Steps
1. Install prerequisites (PowerShell 7, Windows MCP, BurntToast)
2. Clone watchdog repository
3. Run installation script: `.\Install-Watchdog.ps1`
4. Set API key: `Set-WatchdogAPIKey -APIKey "your-key"`
5. Register first project: `Register-Project -ProjectName "test" -ConfigPath "..."`
6. Start watchdog: `Start-Watchdog`

### Scheduled Task Setup
```powershell
# Create scheduled task to auto-start watchdog
$action = New-ScheduledTaskAction -Execute "pwsh.exe" `
    -Argument "-File C:\path\to\Start-Watchdog.ps1"

$trigger = New-ScheduledTaskTrigger -AtStartup

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName "ClaudeCodeWatchdog" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -User $env:USERNAME
```

## Monitoring & Maintenance

### Health Checks
- Watchdog heartbeat every 5 minutes
- API connectivity check every hour
- Disk space check daily

### Maintenance Tasks
- Rotate logs weekly (keep last 4 weeks)
- Archive completed project states monthly
- Review API costs weekly
- Update skills quarterly

### Alerts
- Watchdog down for >10 minutes
- API costs >80% of daily limit
- Disk space <1GB
- Any project stuck for >2 hours
