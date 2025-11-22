<#
.SYNOPSIS
    Rule-based decision engine for Claude Code Watchdog

.DESCRIPTION
    Makes decisions about what action to take based on detected state using simple rules

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
#>

function Invoke-SimpleDecision {
    <#
    .SYNOPSIS
        Makes a rule-based decision about what action to take
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$SessionState,

        [Parameter(Mandatory)]
        [object]$ProjectConfig,

        [Parameter()]
        [array]$DecisionHistory = @()
    )

    Write-Verbose "Making decision for status: $($SessionState.Status)"

    # Initialize decision object
    $decision = @{
        Action = "none"
        Command = $null
        Reasoning = ""
        Confidence = 0.0
        Timestamp = Get-Date -Format "o"
        DecisionMethod = "rule-based"
    }

    # Decision logic based on session status
    switch ($SessionState.Status) {
        "InProgress" {
            $decision.Action = "wait"
            $decision.Reasoning = "Claude is actively processing. Waiting for completion."
            $decision.Confidence = 0.95
        }

        "HasTodos" {
            # Check if auto-progress is enabled
            if ($ProjectConfig.automation.autoProgress) {
                $decision.Action = "continue"
                $decision.Command = "Continue with next TODO"
                $decision.Reasoning = "Auto-progress enabled and TODOs remaining. Continuing to next TODO."
                $decision.Confidence = 0.85
            }
            else {
                $decision.Action = "notify"
                $decision.Reasoning = "TODOs remaining but auto-progress disabled. Notifying human."
                $decision.Confidence = 0.90
            }
        }

        "PhaseComplete" {
            if ($ProjectConfig.automation.autoCommit) {
                $decision.Action = "phase-transition"
                $decision.Command = "Create commit and move to next phase"
                $decision.Reasoning = "Phase complete and auto-commit enabled. Transitioning to next phase."
                $decision.Confidence = 0.80
            }
            else {
                $decision.Action = "notify"
                $decision.Reasoning = "Phase complete but auto-commit disabled. Requesting human approval."
                $decision.Confidence = 0.95
            }
        }

        "Error" {
            $errorCount = $SessionState.Errors.Count
            if ($errorCount -eq 1) {
                $decision.Action = "check-skills"
                $decision.Reasoning = "Single error detected. Checking if a skill can resolve it."
                $decision.Confidence = 0.75
            }
            else {
                $decision.Action = "notify"
                $decision.Reasoning = "Multiple errors detected ($errorCount). Requiring human intervention."
                $decision.Confidence = 0.90
            }
        }

        "WaitingForInput" {
            $decision.Action = "notify"
            $decision.Reasoning = "Session waiting for input but state unclear. Notifying human."
            $decision.Confidence = 0.70
        }

        "Idle" {
            # Check idle time
            $stallThreshold = [TimeSpan]::Parse($ProjectConfig.automation.stallThreshold)
            if ($SessionState.IdleTime -gt $stallThreshold) {
                $decision.Action = "notify"
                $decision.Reasoning = "Session idle for $($SessionState.IdleTime.TotalMinutes) minutes (threshold: $($stallThreshold.TotalMinutes)). Notifying human."
                $decision.Confidence = 0.85
            }
            else {
                $decision.Action = "wait"
                $decision.Reasoning = "Session idle but within threshold. Waiting."
                $decision.Confidence = 0.80
            }
        }

        default {
            $decision.Action = "wait"
            $decision.Reasoning = "Unknown status. Waiting for clearer state."
            $decision.Confidence = 0.50
        }
    }

    Write-Verbose "Decision: $($decision.Action) (confidence: $($decision.Confidence))"

    return $decision
}

function Get-ConfidenceScore {
    <#
    .SYNOPSIS
        Calculates confidence score for a decision
    #>
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
