# Claude Code Watchdog - Project Requirements

## Project Overview

Build a PowerShell-based watchdog automation system that monitors and manages Claude Code sessions, enabling autonomous end-to-end project execution with intelligent decision-making and human-in-the-loop controls.

## Business Context

As a Senior Manager of Software Engineering leading a team of 6 engineers working with C#/.NET, Angular, MySQL, Oracle, and Snowflake, you need to:
- Automate repetitive development tasks using Claude Code
- Manage multiple parallel workstreams simultaneously
- Maintain oversight without constant babysitting
- Balance automation with appropriate human review gates
- Track progress and decisions for audit/review purposes

## Core Problem Statement

Claude Code sessions frequently stall waiting for:
- User input to continue to next task
- Approval to proceed after phase completion
- Decision on how to handle errors
- Direction when encountering ambiguous situations

**Current Pain Point:** You must manually monitor Claude Code sessions every 10-20 minutes to keep them progressing, which defeats the purpose of automation.

## Solution Architecture

### High-Level Components

```
┌─────────────────────────────────────────┐
│     Single Watchdog Process             │
│     (PowerShell Background Service)     │
│                                         │
│  ┌─────────────────────────────────┐  │
│  │   Project Registry Manager       │  │
│  │   - Multiple project tracking    │  │
│  │   - State management per project │  │
│  └─────────────────────────────────┘  │
│                                         │
│  ┌─────────────────────────────────┐  │
│  │   Claude Code Monitor            │  │
│  │   - Windows MCP integration      │  │
│  │   - UI state detection           │  │
│  │   - Session identification       │  │
│  └─────────────────────────────────┘  │
│                                         │
│  ┌─────────────────────────────────┐  │
│  │   Decision Engine                │  │
│  │   - Claude API integration       │  │
│  │   - Skill-based resolution       │  │
│  │   - Rule-based fallbacks         │  │
│  └─────────────────────────────────┘  │
│                                         │
│  ┌─────────────────────────────────┐  │
│  │   Action Executor                │  │
│  │   - Send commands to Claude Code │  │
│  │   - Git operations               │  │
│  │   - Logging & notifications      │  │
│  └─────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Functional Requirements

### FR1: Watchdog Core Loop

**Description:** A continuously running PowerShell process that monitors registered Claude Code sessions.

**Acceptance Criteria:**
- Single PowerShell process can run indefinitely in background
- Polls Claude Code UI state every 2 minutes (configurable)
- Gracefully handles process interruptions and restarts
- Maintains in-memory state for active sessions
- Writes heartbeat to log file every 5 minutes
- Resource-efficient (minimal CPU/memory when idle)

**Technical Details:**
- Use Windows MCP `State-Tool` to capture Claude Code UI state
- Parse window titles to identify active Claude Code sessions
- Detect multiple Claude Code browser tabs/windows
- Use `Start-Job` or `Runspace` for non-blocking operations

### FR2: Project Registration System

**Description:** Ability to register multiple projects for watchdog monitoring with individual configurations.

**Acceptance Criteria:**
- Command: `Register-Project -ProjectName "name" -ConfigPath "path"`
- Creates central registry at `~/.claude-automation/registry.json`
- Each project maintains its own state in project repo
- Projects can be paused/resumed without losing state
- Support unregistering projects
- List all registered projects with status

**Project Configuration Schema:**
```json
{
  "projectName": "team-project-assignment",
  "repoPath": "C:/repos/team-project-assignment",
  "repoUrl": "github.com/username/team-project-assignment",
  "branch": "main",
  "autoCommit": true,
  "autoProgress": true,
  "maxRunDuration": "8h",
  "stallThreshold": "10m",
  "requiresApprovalFor": ["database-changes", "API-modifications"],
  "requiresHumanAfter": ["compilation-errors", "test-failures"],
  "skills": [
    "/mnt/skills/user/workstream-planning",
    "/mnt/skills/user/sprint-planning-documentation",
    "/mnt/skills/user/type-error-resolution",
    "/mnt/skills/user/compilation-error-resolution"
  ],
  "phases": [
    {
      "name": "requirements-analysis",
      "autoProgress": false,
      "estimatedDuration": "1h"
    },
    {
      "name": "workstream-planning",
      "autoProgress": true,
      "estimatedDuration": "30m"
    },
    {
      "name": "implementation",
      "autoProgress": true,
      "estimatedDuration": "6h"
    },
    {
      "name": "testing",
      "autoProgress": false,
      "estimatedDuration": "2h"
    }
  ],
  "commitStrategy": {
    "frequency": "phase-completion",
    "branchNaming": "claude/{phase-name}-{timestamp}",
    "prCreation": "phase-completion",
    "autoMerge": false
  },
  "notifications": {
    "onError": true,
    "onPhaseComplete": true,
    "onProjectComplete": true,
    "onHumanNeeded": true
  }
}
```

### FR3: State Detection & Classification

**Description:** Accurately detect the current state of Claude Code sessions using UI analysis.

**Acceptance Criteria:**
- Detect 6 primary states:
  1. **InProgress** - Actively working, tokens streaming
  2. **WaitingForInput** - Reply field empty, ready for command
  3. **HasTodos** - Update Todos section visible with unchecked items
  4. **PhaseComplete** - All phase TODOs checked, session idle
  5. **Error** - Error messages or warnings displayed
  6. **Idle** - No activity for threshold duration

**State Detection Methods:**
```powershell
# Example state detection logic
function Get-ClaudeCodeState {
    param($SessionWindow)
    
    # Capture UI state
    $uiState = Invoke-WindowsMCP -Tool "State-Tool" -UseVision $true
    
    # Parse for indicators
    $hasReplyField = $uiState.InteractiveElements | Where-Object { $_.Name -like "*Reply*" }
    $hasTodos = $uiState.InformativeElements | Where-Object { $_.Text -like "*Update Todos*" }
    $hasErrors = $uiState.InformativeElements | Where-Object { $_.Text -like "*error*" -or $_.Text -like "*failed*" }
    
    # Classify state
    if ($hasErrors) { return "Error" }
    if ($hasTodos -and -not $hasReplyField.Enabled) { return "InProgress" }
    if ($hasTodos -and $hasReplyField.Enabled) { return "HasTodos" }
    if (-not $hasTodos -and $hasReplyField.Enabled) { return "PhaseComplete" }
    if ($sessionIdleTime -gt $stallThreshold) { return "Idle" }
    
    return "InProgress"
}
```

### FR4: Intelligent Decision Engine

**Description:** Make smart decisions about how to proceed based on current state, using Claude API for complex scenarios.

**Acceptance Criteria:**
- Use Claude API (claude-sonnet-4-20250514) for decision-making
- Provide full context: project config, current state, recent history
- Get structured JSON responses with action + reasoning
- Track API costs and warn if exceeding threshold
- Fallback to rule-based decisions if API unavailable or too expensive
- Log all decisions with reasoning to markdown

**Decision Logic:**
```
State: HasTodos
├─ Check project config: autoProgress = true?
│  ├─ YES → API Decision:
│  │      "Should I continue with next TODO or use a skill?"
│  │      Response: {action: "continue", command: "Continue with next TODO"}
│  └─ NO → Pause and notify human
│
State: Error
├─ Parse error messages
├─ Check if minor error (warnings, lint issues)
│  ├─ Minor → API Decision:
│  │      "Can this error be resolved with available skills?"
│  │      Response: {action: "use_skill", skill: "type-error-resolution"}
│  └─ Major → Pause and notify human
│
State: PhaseComplete
├─ Check project config: next phase exists?
│  ├─ YES → Commit changes, start next phase
│  └─ NO → Mark project complete, notify human
│
State: Idle (stalled)
├─ Check last activity timestamp
├─ If > stallThreshold → API Decision:
│      "Session appears stalled. Continue or investigate?"
│      Response: {action: "continue", command: "Please continue"}
```

**Claude API Integration:**
```powershell
function Invoke-ClaudeDecision {
    param(
        [string]$ProjectName,
        [object]$CurrentState,
        [object]$ProjectConfig,
        [array]$RecentHistory
    )
    
    $prompt = @"
You are managing a Claude Code session for project: $ProjectName

Current State:
- Status: $($CurrentState.Status)
- Phase: $($CurrentState.CurrentPhase)
- TODOs Remaining: $($CurrentState.TodosRemaining)
- Errors: $($CurrentState.Errors)
- Last Action: $($RecentHistory[-1].Action)
- Idle Time: $($CurrentState.IdleTime)

Project Configuration:
- Auto-Progress: $($ProjectConfig.autoProgress)
- Auto-Commit: $($ProjectConfig.autoCommit)
- Available Skills: $($ProjectConfig.skills -join ', ')
- Requires Approval For: $($ProjectConfig.requiresApprovalFor -join ', ')

Recent History (last 5 actions):
$($RecentHistory | Select-Object -Last 5 | ForEach-Object { "- $($_.Timestamp): $($_.Action) → $($_.Result)" } | Out-String)

Task: Decide the next action.

Respond ONLY with valid JSON:
{
  "action": "continue|use_skill|pause|commit_and_next|investigate",
  "reasoning": "Brief explanation of decision",
  "skill": "skill-name (only if action=use_skill)",
  "command": "Exact text to send to Claude Code (if action=continue or use_skill)",
  "confidence": 0.0-1.0,
  "estimatedCost": "low|medium|high"
}

Guidelines:
- Use "continue" for straightforward next TODOs
- Use "use_skill" when errors match available skills
- Use "pause" for ambiguous situations or when human approval required
- Use "commit_and_next" when phase is complete
- Use "investigate" when session appears stuck
- Prefer skills over manual fixes when available
- Be conservative - when in doubt, pause for human
"@

    $response = Invoke-AnthropicAPI `
        -Model "claude-sonnet-4-20250514" `
        -MaxTokens 1000 `
        -Messages @(@{role="user"; content=$prompt})
    
    $decision = $response.content[0].text | ConvertFrom-Json
    
    # Log decision
    Add-DecisionLog -Project $ProjectName -Decision $decision -State $CurrentState
    
    # Track costs
    Update-APICosts -InputTokens $response.usage.input_tokens `
                     -OutputTokens $response.usage.output_tokens
    
    return $decision
}
```

### FR5: Action Execution

**Description:** Execute decisions by interacting with Claude Code UI and performing Git operations.

**Acceptance Criteria:**
- Send commands to Claude Code using Windows MCP
- Click on Reply field, type command, press Enter
- Verify command was sent successfully
- Handle UI quirks (focus issues, timing)
- Execute Git operations (commit, push, branch, PR)
- Update project state after actions
- Retry failed actions with exponential backoff

**Implementation:**
```powershell
function Invoke-ClaudeCodeAction {
    param(
        [string]$SessionWindow,
        [object]$Decision
    )
    
    switch ($Decision.action) {
        "continue" {
            Send-ClaudeCodeCommand -Window $SessionWindow -Command $Decision.command
            Start-Sleep -Seconds 2
            Verify-CommandSent
        }
        
        "use_skill" {
            $skillCommand = @"
$($Decision.command)

Please read and follow the skill at: $($Decision.skill)/SKILL.md
"@
            Send-ClaudeCodeCommand -Window $SessionWindow -Command $skillCommand
        }
        
        "commit_and_next" {
            # Wait for any pending work
            Wait-ForClaudeCodeIdle -Timeout 300
            
            # Trigger commit in Claude Code
            Send-ClaudeCodeCommand -Window $SessionWindow -Command "Please commit these changes with message: 'Completed phase: $($CurrentState.Phase)'"
            
            # Wait for commit
            Wait-ForCommitComplete
            
            # Start next phase
            $nextPhase = Get-NextPhase
            if ($nextPhase) {
                Send-ClaudeCodeCommand -Window $SessionWindow -Command "Begin next phase: $($nextPhase.name)"
            }
        }
        
        "pause" {
            Send-Notification -Type "Warning" -Message $Decision.reasoning
            Set-ProjectState -Status "PausedForHuman"
        }
    }
}

function Send-ClaudeCodeCommand {
    param(
        [string]$Window,
        [string]$Command
    )
    
    # Find Reply field coordinates
    $state = Invoke-WindowsMCP -Tool "State-Tool"
    $replyField = $state.InteractiveElements | Where-Object { $_.Name -like "*Reply*" }
    
    if (-not $replyField) {
        throw "Cannot find Reply field in Claude Code UI"
    }
    
    # Click on Reply field
    Invoke-WindowsMCP -Tool "Click-Tool" -Loc $replyField.Coordinates
    Start-Sleep -Milliseconds 500
    
    # Type command
    Invoke-WindowsMCP -Tool "Type-Tool" -Loc $replyField.Coordinates -Text $Command
    Start-Sleep -Milliseconds 300
    
    # Press Enter
    Invoke-WindowsMCP -Tool "Key-Tool" -Key "enter"
    
    Write-Log "Sent command to Claude Code: $Command"
}
```

### FR6: Progress Tracking & Logging

**Description:** Maintain detailed logs and progress tracking for audit, debugging, and human review.

**Acceptance Criteria:**
- Create markdown files for decision logs
- Update progress files after each phase
- Track time spent per phase and task
- Log all API calls with costs
- Generate daily summary reports
- Export session transcripts from Claude Code

**File Structure:**
```
~/.claude-automation/
├── registry.json                    # All registered projects
├── watchdog-state.json             # Current running state
├── global-log.md                   # High-level watchdog activity
├── api-costs.json                  # API usage tracking
└── notifications.log               # All notifications sent

{project-repo}/.claude-automation/
├── project-config.json             # Project configuration
├── current-state.json              # Where we are now
├── decision-log.md                 # All decisions made
├── watchdog-activity.log           # Detailed action log
└── sessions/
    ├── 2024-11-22-session-1.md    # Session transcript
    └── 2024-11-22-session-2.md

{project-repo}/progress/
├── phase-requirements-analysis.md
├── phase-implementation.md
└── project-summary.md              # Overall progress
```

**Decision Log Format:**
```markdown
# Decision Log - Project: team-project-assignment

## 2024-11-22 14:35:22 - Continue with Next TODO

**State:** HasTodos
**Phase:** implementation
**Idle Time:** 0m 15s

**Context:**
- TODOs Remaining: 8
- Last Action: Fixed type errors in Client.ts
- No errors detected

**Decision (via Claude API):**
- Action: `continue`
- Reasoning: "All type errors resolved successfully. Next TODO is to fix compilation errors in codebase, which can proceed automatically."
- Confidence: 0.95
- Cost: low

**Command Sent:**
```
Continue with next TODO: Fix compilation errors in codebase
```

**Result:** ✅ Command sent successfully, session resumed

---

## 2024-11-22 15:12:44 - Use Skill for Error Resolution

**State:** Error
**Phase:** implementation
**Idle Time:** 2m 30s

**Context:**
- Error: "TypeScript compilation failed: 15 errors in src/components/"
- TODOs Remaining: 5
- Last Action: Attempted to fix type definitions

**Decision (via Claude API):**
- Action: `use_skill`
- Skill: `/mnt/skills/user/compilation-error-resolution`
- Reasoning: "Multiple compilation errors detected that match the compilation-error-resolution skill's capabilities. Using specialized skill will be more efficient than ad-hoc fixes."
- Confidence: 0.88
- Cost: medium

**Command Sent:**
```
There are TypeScript compilation errors in src/components/. Please use the compilation-error-resolution skill to systematically resolve them.

Read and follow the skill at: /mnt/skills/user/compilation-error-resolution/SKILL.md
```

**Result:** ✅ Skill invoked, session resumed

---
```

### FR7: Notification System

**Description:** Alert the user when human intervention is needed or significant events occur.

**Acceptance Criteria:**
- Windows toast notifications for urgent items
- Console output (if watchdog window visible)
- Log file for all notifications
- Different notification levels: Error, Warning, Info, Success
- Rate limiting to avoid spam
- Summary notifications (daily digest)

**Implementation:**
```powershell
function Send-WatchdogNotification {
    param(
        [string]$ProjectName,
        [ValidateSet("Error","Warning","Info","Success")]
        [string]$Type,
        [string]$Message,
        [switch]$Urgent
    )
    
    # Windows Toast (for urgent or errors)
    if ($Urgent -or $Type -eq "Error") {
        New-BurntToastNotification `
            -Text "Claude Code Watchdog: $ProjectName", $Message `
            -AppLogo "C:\path\to\icon.png"
    }
    
    # Console output
    $color = @{
        "Error" = "Red"
        "Warning" = "Yellow"
        "Info" = "Cyan"
        "Success" = "Green"
    }[$Type]
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [$ProjectName] $Type: $Message" -ForegroundColor $color
    
    # Log file
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$ProjectName] $Type: $Message"
    Add-Content -Path "~/.claude-automation/notifications.log" -Value $logEntry
}
```

### FR8: Cost Management

**Description:** Track and manage Claude API costs to prevent runaway expenses.

**Acceptance Criteria:**
- Track token usage per decision
- Calculate cost based on API pricing
- Warn when daily/weekly costs exceed threshold
- Provide cost breakdown by project
- Fallback to rule-based decisions if over budget
- Export cost reports

**Cost Tracking:**
```json
{
  "daily_costs": {
    "2024-11-22": {
      "total_usd": 2.45,
      "projects": {
        "team-project-assignment": {
          "decisions": 47,
          "input_tokens": 125000,
          "output_tokens": 8500,
          "cost_usd": 1.20
        }
      }
    }
  },
  "thresholds": {
    "daily_warning": 5.00,
    "daily_limit": 10.00,
    "weekly_limit": 50.00
  }
}
```

### FR9: Session Recovery

**Description:** Handle interruptions gracefully and resume work after restarts.

**Acceptance Criteria:**
- Detect when Claude Code session closes unexpectedly
- Save state before watchdog shutdown
- Resume monitoring after watchdog restart
- Notify human if session cannot be recovered
- Provide manual recovery instructions
- Option to start fresh session with context from logs

**Recovery Scenarios:**
1. **Watchdog Crash:** Auto-restart watchdog service, reload state from files
2. **Browser Crash:** Notify human, provide option to reopen and resume
3. **Network Issues:** Wait and retry, notify if prolonged
4. **Claude Code Error:** Log error, notify human with details

### FR10: Multi-Project Support

**Description:** Monitor multiple Claude Code sessions for different projects simultaneously.

**Acceptance Criteria:**
- Single watchdog process handles multiple projects
- Distinguish between Claude Code tabs by URL or window title
- Independent state tracking per project
- Prioritize projects by urgency/deadlines
- Balance attention across projects
- Prevent interference between projects

**Implementation:**
```powershell
# In main loop
$registeredProjects = Get-RegisteredProjects
foreach ($project in $registeredProjects) {
    if ($project.Status -ne "Paused") {
        $session = Find-ClaudeCodeSession -ProjectName $project.Name
        if ($session) {
            Process-Project -Project $project -Session $session
        }
    }
}
```

## Non-Functional Requirements

### NFR1: Performance
- Watchdog process uses <5% CPU when idle
- Memory footprint <200MB for 5 concurrent projects
- UI state capture completes in <2 seconds
- Decision-making latency <5 seconds (including API)

### NFR2: Reliability
- Watchdog uptime >99% (handle crashes gracefully)
- Automatic restart on failure
- No data loss on unexpected shutdown
- Transactional state updates

### NFR3: Security
- API keys stored securely (Windows Credential Manager)
- No sensitive data in logs
- Project configs validated before use
- Safe handling of Git credentials

### NFR4: Maintainability
- Modular PowerShell scripts
- Clear separation of concerns
- Comprehensive inline documentation
- Unit tests for core functions
- Integration tests for workflows

### NFR5: Usability
- Simple commands to start/stop/status
- Clear error messages
- Easy configuration
- Helpful documentation
- Examples and templates

## Technical Constraints

1. **Windows MCP:** Must be installed and configured
2. **PowerShell:** Version 7.0 or higher
3. **Claude API:** Valid API key with sufficient quota
4. **Git:** Installed and configured with SSH/HTTPS
5. **Browser:** Chrome with Claude Code sessions
6. **Network:** Stable internet connection

## Dependencies

### Required PowerShell Modules
- `BurntToast` (Windows notifications)
- `PSReadLine` (enhanced console)
- Custom Windows MCP wrapper module

### External Services
- Anthropic API (Claude)
- GitHub API (for PR creation)
- Windows MCP Server

### File System Requirements
- Write access to user profile (`~/.claude-automation/`)
- Write access to project repositories
- ~100MB disk space for logs/state

## Success Criteria

### Minimum Viable Product (MVP)
1. ✅ Watchdog monitors single Claude Code session
2. ✅ Detects when waiting for input
3. ✅ Auto-continues on TODOs
4. ✅ Logs all decisions
5. ✅ Notifies on errors or completion

### Full Release
1. ✅ All functional requirements implemented
2. ✅ Multi-project support working
3. ✅ Claude API integration functional
4. ✅ Skill-based error resolution working
5. ✅ Phase-based commits and PRs
6. ✅ Cost management operational
7. ✅ Documentation complete
8. ✅ Tested on 3+ real projects

## Implementation Phases

### Phase 1: Core Watchdog (Week 1)
- Single watchdog process
- Basic state detection
- Simple auto-continue logic
- Logging system
- Project registration

**Deliverables:**
- `Start-Watchdog.ps1`
- `Register-Project.ps1`
- `Get-ClaudeCodeState.ps1`
- Basic logging functions

### Phase 2: Smart Decisions (Week 2)
- Claude API integration
- Decision engine logic
- Skill-based resolution
- Cost tracking
- Enhanced state detection

**Deliverables:**
- `Invoke-ClaudeDecision.ps1`
- `Execute-Decision.ps1`
- `Manage-APICosts.ps1`
- Decision log system

### Phase 3: Multi-Project & Git (Week 3)
- Multi-project monitoring
- Git integration (commit, push, PR)
- Phase-based workflows
- Progress tracking
- Session recovery

**Deliverables:**
- `Process-MultipleProjects.ps1`
- `Invoke-GitOperations.ps1`
- `Manage-PhaseTransitions.ps1`
- Recovery system

### Phase 4: Polish & Documentation (Week 4)
- Comprehensive testing
- Error handling improvements
- Documentation
- Examples and templates
- Installation script

**Deliverables:**
- Complete documentation
- Example project configs
- Installation wizard
- Troubleshooting guide

## Testing Strategy

### Unit Tests
- State detection functions
- Decision logic
- Git operations
- Cost calculations

### Integration Tests
- Full watchdog loop
- Multi-project scenarios
- API integration
- Windows MCP interactions

### Manual Tests
- Real Claude Code sessions
- Different project types
- Error scenarios
- Recovery scenarios

## Risk Mitigation

### Risk 1: API Costs Exceed Budget
**Mitigation:**
- Implement strict cost limits
- Fallback to rule-based decisions
- Daily cost alerts
- Cost dashboard

### Risk 2: Claude Code UI Changes
**Mitigation:**
- Flexible state detection
- Version detection
- Graceful degradation
- Easy updates to selectors

### Risk 3: Session Interruptions
**Mitigation:**
- Robust state persistence
- Recovery mechanisms
- Human notifications
- Manual override options

### Risk 4: Windows MCP Limitations
**Mitigation:**
- Comprehensive error handling
- Alternative detection methods
- Retry logic
- Fallback to screenshots + OCR

## Future Enhancements (Post-MVP)

1. **Web Dashboard:** Real-time project monitoring
2. **Mobile Notifications:** SMS/app alerts
3. **Slack Integration:** Team notifications
4. **Analytics:** Performance metrics, bottleneck identification
5. **Templates:** Pre-configured project types
6. **AI Learning:** Improve decisions based on history
7. **Azure DevOps:** Support for work projects
8. **Multi-Browser:** Support Edge, Firefox
9. **Cloud Hosting:** Run watchdog on cloud VM
10. **Team Collaboration:** Shared project monitoring

## Appendix A: Example Project Configuration

See `example-project-config.json` for a complete, annotated example.

## Appendix B: Decision Flow Diagram

See `decision-flow-diagram.mermaid` for visual representation.

## Appendix C: API Cost Calculator

See `api-cost-calculator.xlsx` for cost estimation tool.

## Appendix D: Troubleshooting Guide

See `TROUBLESHOOTING.md` for common issues and solutions.
