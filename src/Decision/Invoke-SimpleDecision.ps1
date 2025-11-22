<#
.SYNOPSIS
    Rule-based decision engine for Claude Code Watchdog

.DESCRIPTION
    Makes decisions about what action to take based on detected state using simple rules.
    This is the fallback decision mechanism when Claude API is unavailable or disabled.

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS03 - Decision Engine
    Work Item: WI-1.4 (Week 1) - Rule-Based Decision Engine
#>

function Invoke-SimpleDecision {
    <#
    .SYNOPSIS
        Makes a rule-based decision about what action to take

    .DESCRIPTION
        Uses deterministic rules to decide the next action based on:
        - Current session status
        - Project configuration (autoProgress, autoCommit, etc.)
        - Recent decision history (to avoid loops)
        - Error severity and count
        - Available skills for error resolution

    .PARAMETER SessionState
        The current state of the Claude Code session (from Get-ClaudeCodeState)

    .PARAMETER ProjectConfig
        The project configuration object (from Get-RegisteredProjects)

    .PARAMETER DecisionHistory
        Array of recent decisions to avoid repeated actions

    .PARAMETER GlobalConfig
        Global watchdog configuration (optional, for API settings)

    .OUTPUTS
        Hashtable containing:
        - Action: The action to take (continue, wait, notify, check-skills, phase-transition)
        - Command: The specific command to send (if applicable)
        - Reasoning: Human-readable explanation of the decision
        - Confidence: Float 0.0-1.0 indicating confidence in the decision
        - Timestamp: ISO 8601 timestamp of the decision
        - DecisionMethod: Always "rule-based"
        - SkillToUse: Skill path if Action is "use-skill"
        - Metadata: Additional context about the decision
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$SessionState,

        [Parameter(Mandatory)]
        [object]$ProjectConfig,

        [Parameter()]
        [array]$DecisionHistory = @(),

        [Parameter()]
        [object]$GlobalConfig = $null
    )

    Write-Verbose "Making rule-based decision for status: $($SessionState.Status)"
    Write-Verbose "Session state: Todos=$($SessionState.Todos.Remaining), Errors=$($SessionState.Errors.Count), Processing=$($SessionState.IsProcessing)"

    # Initialize decision object
    $decision = @{
        Action = "none"
        Command = $null
        Reasoning = ""
        Confidence = 0.0
        Timestamp = Get-Date -Format "o"
        DecisionMethod = "rule-based"
        SkillToUse = $null
        Metadata = @{
            SessionStatus = $SessionState.Status
            TodosRemaining = $SessionState.Todos.Remaining
            ErrorCount = $SessionState.Errors.Count
            IsProcessing = $SessionState.IsProcessing
            IdleTimeMinutes = [math]::Round($SessionState.IdleTime.TotalMinutes, 1)
        }
    }

    # Check for repeated decisions (avoid loops)
    $recentSameDecisions = Get-RecentDecisionsByAction -DecisionHistory $DecisionHistory -Action "continue" -WindowMinutes 5
    if ($recentSameDecisions -ge 3) {
        Write-Verbose "Detected potential loop: 'continue' action repeated $recentSameDecisions times in 5 minutes"
        $decision.Action = "notify"
        $decision.Reasoning = "Potential decision loop detected. Made 'continue' decision $recentSameDecisions times in 5 minutes. Requesting human intervention."
        $decision.Confidence = 0.95
        return $decision
    }

    # Decision logic based on session status (priority order)
    switch ($SessionState.Status) {
        "InProgress" {
            # Claude is actively working - always wait
            $decision.Action = "wait"
            $decision.Reasoning = "Claude is actively processing (detected via UI indicators). Waiting for completion."
            $decision.Confidence = 0.98
            $decision.Metadata.EstimatedWaitSeconds = 30
        }

        "Error" {
            # Handle errors - check severity and skills
            $decision = Get-ErrorDecision -SessionState $SessionState -ProjectConfig $ProjectConfig -DecisionHistory $DecisionHistory
        }

        "HasTodos" {
            # Has remaining TODOs - check autoProgress setting
            $decision = Get-TodoDecision -SessionState $SessionState -ProjectConfig $ProjectConfig -DecisionHistory $DecisionHistory
        }

        "PhaseComplete" {
            # All TODOs complete - check autoCommit setting
            $decision = Get-PhaseCompleteDecision -SessionState $SessionState -ProjectConfig $ProjectConfig
        }

        "WaitingForInput" {
            # Reply field available but unclear state
            $decision = Get-WaitingForInputDecision -SessionState $SessionState -ProjectConfig $ProjectConfig
        }

        "Idle" {
            # Session has been idle - check stall threshold
            $decision = Get-IdleDecision -SessionState $SessionState -ProjectConfig $ProjectConfig
        }

        default {
            # Unknown or unexpected status
            $decision.Action = "wait"
            $decision.Reasoning = "Unknown status '$($SessionState.Status)'. Waiting for clearer state."
            $decision.Confidence = 0.50
            $decision.Metadata.NeedsInvestigation = $true
        }
    }

    # Add cost estimate (rule-based decisions are free)
    $decision.Metadata.CostEstimate = 0.0
    $decision.Metadata.TokensUsed = 0

    Write-Verbose "Rule-based decision: Action='$($decision.Action)', Confidence=$($decision.Confidence)"

    return $decision
}

function Get-ErrorDecision {
    <#
    .SYNOPSIS
        Makes a decision when errors are detected
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$SessionState,

        [Parameter(Mandatory)]
        [object]$ProjectConfig,

        [Parameter()]
        [array]$DecisionHistory = @()
    )

    $errorCount = $SessionState.Errors.Count
    $highSeverityErrors = ($SessionState.Errors | Where-Object { $_.Severity -eq "High" }).Count

    $decision = @{
        Action = "notify"
        Command = $null
        Reasoning = ""
        Confidence = 0.0
        Timestamp = Get-Date -Format "o"
        DecisionMethod = "rule-based"
        SkillToUse = $null
        Metadata = @{
            ErrorCount = $errorCount
            HighSeverityCount = $highSeverityErrors
        }
    }

    # Check if human intervention is required for this error type
    $requiresHuman = $false
    foreach ($error in $SessionState.Errors) {
        foreach ($pattern in $ProjectConfig.humanInLoop.requiresHumanAfter) {
            if ($error.Message -match $pattern) {
                $requiresHuman = $true
                $decision.Metadata.RequiresHumanReason = $pattern
                break
            }
        }
    }

    if ($requiresHuman) {
        $decision.Action = "notify"
        $decision.Reasoning = "Error matches human-in-loop requirement: $($decision.Metadata.RequiresHumanReason). Notifying human."
        $decision.Confidence = 0.95
        return $decision
    }

    # Multiple high-severity errors - notify human
    if ($highSeverityErrors -gt 1) {
        $decision.Action = "notify"
        $decision.Reasoning = "Multiple high-severity errors detected ($highSeverityErrors). Requiring human intervention."
        $decision.Confidence = 0.92
        return $decision
    }

    # Single error - check if a skill can handle it
    if ($errorCount -eq 1) {
        $error = $SessionState.Errors[0]
        $matchedSkill = Find-SkillForError -Error $error -AvailableSkills $ProjectConfig.skills

        if ($matchedSkill) {
            $decision.Action = "use-skill"
            $decision.SkillToUse = $matchedSkill
            $decision.Command = "There is a $($error.Category) error: '$($error.Message)'. Please use the skill at: $matchedSkill"
            $decision.Reasoning = "Single $($error.Severity) severity $($error.Category) error detected. Matched skill: $matchedSkill"
            $decision.Confidence = 0.82
            $decision.Metadata.MatchedSkill = $matchedSkill
            return $decision
        }
    }

    # Multiple errors or no skill match - notify
    $decision.Action = "notify"
    $decision.Reasoning = "Detected $errorCount error(s) but no clear resolution strategy. Notifying human."
    $decision.Confidence = 0.88

    return $decision
}

function Get-TodoDecision {
    <#
    .SYNOPSIS
        Makes a decision when TODOs are remaining
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$SessionState,

        [Parameter(Mandatory)]
        [object]$ProjectConfig,

        [Parameter()]
        [array]$DecisionHistory = @()
    )

    $decision = @{
        Action = "wait"
        Command = $null
        Reasoning = ""
        Confidence = 0.0
        Timestamp = Get-Date -Format "o"
        DecisionMethod = "rule-based"
        SkillToUse = $null
        Metadata = @{
            TodosRemaining = $SessionState.Todos.Remaining
            TodosTotal = $SessionState.Todos.Total
        }
    }

    # Check if auto-progress is enabled
    if ($ProjectConfig.automation.autoProgress) {
        $decision.Action = "continue"
        $decision.Command = "Continue with next TODO"
        $decision.Reasoning = "Auto-progress enabled. $($SessionState.Todos.Remaining) TODO(s) remaining. Continuing to next item."
        $decision.Confidence = 0.88
        $decision.Metadata.AutoProgressEnabled = $true
    }
    else {
        $decision.Action = "notify"
        $decision.Reasoning = "$($SessionState.Todos.Remaining) TODO(s) remaining but auto-progress is disabled. Requesting human guidance."
        $decision.Confidence = 0.92
        $decision.Metadata.AutoProgressEnabled = $false
    }

    return $decision
}

function Get-PhaseCompleteDecision {
    <#
    .SYNOPSIS
        Makes a decision when phase is complete
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$SessionState,

        [Parameter(Mandatory)]
        [object]$ProjectConfig
    )

    $decision = @{
        Action = "notify"
        Command = $null
        Reasoning = ""
        Confidence = 0.0
        Timestamp = Get-Date -Format "o"
        DecisionMethod = "rule-based"
        SkillToUse = $null
        Metadata = @{
            PhaseComplete = $true
        }
    }

    if ($ProjectConfig.automation.autoCommit) {
        $decision.Action = "phase-transition"
        $decision.Command = "Phase complete. Create commit and move to next phase."
        $decision.Reasoning = "All TODOs complete and auto-commit enabled. Initiating phase transition."
        $decision.Confidence = 0.85
        $decision.Metadata.AutoCommitEnabled = $true
    }
    else {
        $decision.Action = "notify"
        $decision.Reasoning = "Phase complete but auto-commit disabled. Requesting human approval for commit."
        $decision.Confidence = 0.95
        $decision.Metadata.AutoCommitEnabled = $false
    }

    return $decision
}

function Get-WaitingForInputDecision {
    <#
    .SYNOPSIS
        Makes a decision when session is waiting for input
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$SessionState,

        [Parameter(Mandatory)]
        [object]$ProjectConfig
    )

    $decision = @{
        Action = "notify"
        Command = $null
        Reasoning = "Session is waiting for input but state is unclear. No active TODOs or errors detected. Notifying human."
        Confidence = 0.75
        Timestamp = Get-Date -Format "o"
        DecisionMethod = "rule-based"
        SkillToUse = $null
        Metadata = @{
            HasReplyField = $SessionState.HasReplyField
        }
    }

    return $decision
}

function Get-IdleDecision {
    <#
    .SYNOPSIS
        Makes a decision when session is idle
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$SessionState,

        [Parameter(Mandatory)]
        [object]$ProjectConfig
    )

    $decision = @{
        Action = "wait"
        Command = $null
        Reasoning = ""
        Confidence = 0.0
        Timestamp = Get-Date -Format "o"
        DecisionMethod = "rule-based"
        SkillToUse = $null
        Metadata = @{
            IdleTimeMinutes = [math]::Round($SessionState.IdleTime.TotalMinutes, 1)
        }
    }

    # Parse stall threshold
    $stallThreshold = [TimeSpan]::Parse($ProjectConfig.automation.stallThreshold)

    if ($SessionState.IdleTime -gt $stallThreshold) {
        $decision.Action = "notify"
        $decision.Reasoning = "Session idle for $($decision.Metadata.IdleTimeMinutes) minutes (threshold: $([math]::Round($stallThreshold.TotalMinutes, 1)) minutes). Potential stall detected. Notifying human."
        $decision.Confidence = 0.90
        $decision.Metadata.StallThresholdMinutes = [math]::Round($stallThreshold.TotalMinutes, 1)
        $decision.Metadata.ExceededThreshold = $true
    }
    else {
        $decision.Action = "wait"
        $decision.Reasoning = "Session idle for $($decision.Metadata.IdleTimeMinutes) minutes but within threshold ($([math]::Round($stallThreshold.TotalMinutes, 1)) minutes). Waiting."
        $decision.Confidence = 0.85
        $decision.Metadata.StallThresholdMinutes = [math]::Round($stallThreshold.TotalMinutes, 1)
        $decision.Metadata.ExceededThreshold = $false
    }

    return $decision
}

function Find-SkillForError {
    <#
    .SYNOPSIS
        Finds an appropriate skill to handle a specific error
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Error,

        [Parameter(Mandatory)]
        [array]$AvailableSkills
    )

    # Skill matching patterns
    $skillPatterns = @{
        "type-error-resolution" = @("type error", "typescript.*error", "cannot find.*type", "property.*does not exist", "type.*is not assignable")
        "compilation-error-resolution" = @("compilation failed", "syntax error", "cannot compile", "build failed", "tsc error")
        "lint-error-resolution" = @("eslint", "lint error", "lint warning", "linting failed", "prettier")
        "sql-query-optimization" = @("sql.*error", "query.*failed", "database.*error", "syntax.*near")
    }

    foreach ($skill in $AvailableSkills) {
        $skillName = Split-Path $skill -Leaf

        if ($skillPatterns.ContainsKey($skillName)) {
            foreach ($pattern in $skillPatterns[$skillName]) {
                if ($Error.Message -match $pattern) {
                    Write-Verbose "Matched error to skill: $skillName (pattern: $pattern)"
                    return $skill
                }
            }
        }
    }

    Write-Verbose "No skill matched for error: $($Error.Message)"
    return $null
}

function Get-RecentDecisionsByAction {
    <#
    .SYNOPSIS
        Counts recent decisions with a specific action (for loop detection)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$DecisionHistory,

        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter()]
        [int]$WindowMinutes = 5
    )

    $cutoffTime = (Get-Date).AddMinutes(-$WindowMinutes)

    $recentDecisions = $DecisionHistory | Where-Object {
        $_.Action -eq $Action -and
        [DateTime]::Parse($_.Timestamp) -gt $cutoffTime
    }

    return $recentDecisions.Count
}

function Get-ConfidenceScore {
    <#
    .SYNOPSIS
        Calculates confidence score for a decision (legacy function for compatibility)

    .DESCRIPTION
        This is a legacy function maintained for backward compatibility.
        New code should use the confidence scores returned directly from decision functions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter()]
        [int]$ErrorCount = 0,

        [Parameter()]
        [int]$TodoCount = 0
    )

    # Base confidence scores
    $baseConfidence = @{
        "InProgress" = 0.95
        "HasTodos" = 0.85
        "PhaseComplete" = 0.80
        "Error" = 0.70
        "WaitingForInput" = 0.60
        "Idle" = 0.75
        "Unknown" = 0.40
    }

    $confidence = $baseConfidence[$Status]
    if (-not $confidence) {
        $confidence = 0.50
    }

    # Adjust based on context
    if ($ErrorCount -gt 1) {
        $confidence -= 0.10
    }

    if ($TodoCount -eq 0 -and $Status -eq "HasTodos") {
        $confidence -= 0.20
    }

    # Ensure 0.0 - 1.0 range
    $confidence = [Math]::Max(0.0, [Math]::Min(1.0, $confidence))

    return $confidence
}

# Export functions
Export-ModuleMember -Function Invoke-SimpleDecision, Get-ConfidenceScore
