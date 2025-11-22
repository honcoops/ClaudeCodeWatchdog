<#
.SYNOPSIS
    Retrieves decision history for a project

.DESCRIPTION
    Loads and returns the decision history from the decision log

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
#>

function Get-DecisionHistory {
    <#
    .SYNOPSIS
        Gets decision history for a project
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter()]
        [int]$Last = 10
    )

    try {
        # Get project config to find log location
        $config = Get-ProjectConfig -ProjectName $ProjectName
        $logPath = Join-Path $config.repoPath ".claude-automation/decision-log.md"

        if (-not (Test-Path $logPath)) {
            Write-Verbose "No decision log found for project: $ProjectName"
            return @()
        }

        # TODO: Parse decision log markdown file
        # Extract last N decisions
        # Return as structured objects

        Write-Verbose "Decision history parsing not yet implemented"

        return @()
    }
    catch {
        Write-Error "Failed to get decision history: $_"
        return @()
    }
}

function Get-RecentDecisionCount {
    <#
    .SYNOPSIS
        Gets count of decisions made in recent time period
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter()]
        [TimeSpan]$Period = [TimeSpan]::FromHours(1)
    )

    $history = Get-DecisionHistory -ProjectName $ProjectName -Last 100

    $cutoff = (Get-Date) - $Period
    $recentDecisions = $history | Where-Object {
        $_.Timestamp -gt $cutoff
    }

    return $recentDecisions.Count
}

# Export functions
Export-ModuleMember -Function Get-DecisionHistory, Get-RecentDecisionCount
