<#
.SYNOPSIS
    Adds decision entries to the project decision log

.DESCRIPTION
    Logs decisions in markdown format for audit trail

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
#>

function Add-DecisionLog {
    <#
    .SYNOPSIS
        Adds a decision to the project's decision log
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter(Mandatory)]
        [hashtable]$Decision,

        [Parameter(Mandatory)]
        [hashtable]$SessionState
    )

    try {
        # Get project config to find log location
        $config = Get-ProjectConfig -ProjectName $ProjectName
        $logPath = Join-Path $config.repoPath ".claude-automation/decision-log.md"

        # Format decision entry
        $entry = Format-DecisionEntry -Decision $Decision -State $SessionState

        # Append to log
        $entry | Add-Content -Path $logPath -Force

        Write-Verbose "Decision logged for project: $ProjectName"
    }
    catch {
        Write-Error "Failed to log decision: $_"
    }
}

function Format-DecisionEntry {
    <#
    .SYNOPSIS
        Formats a decision as a markdown entry
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Decision,

        [Parameter(Mandatory)]
        [hashtable]$State
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $entry = @"

## Decision - $timestamp

**Status:** $($State.Status)
**Action:** $($Decision.Action)
**Confidence:** $($Decision.Confidence * 100)%
**Method:** $($Decision.DecisionMethod)

**Reasoning:**
$($Decision.Reasoning)

**Context:**
- TODOs Remaining: $($State.Todos.Remaining)
- Errors: $($State.Errors.Count)
- Is Processing: $($State.IsProcessing)

"@

    if ($Decision.Command) {
        $entry += @"

**Command:**
``````
$($Decision.Command)
``````

"@
    }

    $entry += "---`n"

    return $entry
}

function Get-DecisionLogSummary {
    <#
    .SYNOPSIS
        Gets a summary of recent decisions for a project
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter()]
        [int]$Last = 5
    )

    try {
        $config = Get-ProjectConfig -ProjectName $ProjectName
        $logPath = Join-Path $config.repoPath ".claude-automation/decision-log.md"

        if (-not (Test-Path $logPath)) {
            return "No decision log found"
        }

        # TODO: Parse last N decision entries
        # Return formatted summary

        return "Decision log summary not yet implemented"
    }
    catch {
        Write-Error "Failed to get decision summary: $_"
        return $null
    }
}

# Export functions
Export-ModuleMember -Function Add-DecisionLog, Format-DecisionEntry, Get-DecisionLogSummary
