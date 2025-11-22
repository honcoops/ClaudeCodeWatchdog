<#
.SYNOPSIS
    Retrieves decision history for a project

.DESCRIPTION
    Loads, parses, and returns the decision history from the decision log.
    Supports both JSON and Markdown formats for backward compatibility.

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS03 - Decision Engine
    Enhanced for WS03 decision tracking requirements
#>

function Get-DecisionHistory {
    <#
    .SYNOPSIS
        Gets decision history for a project

    .DESCRIPTION
        Retrieves past decisions from the decision log, either in JSON or Markdown format.
        Used by the decision engine to avoid loops and provide context.

    .PARAMETER ProjectName
        The name of the project

    .PARAMETER Last
        Number of recent decisions to return (default: 10)

    .PARAMETER IncludeMetadata
        Include full metadata in the response

    .EXAMPLE
        Get-DecisionHistory -ProjectName "my-project" -Last 5

    .OUTPUTS
        Array of decision objects with Action, Reasoning, Timestamp, etc.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter()]
        [int]$Last = 10,

        [Parameter()]
        [switch]$IncludeMetadata
    )

    try {
        # Try JSON format first (more efficient)
        $jsonPath = Join-Path $env:USERPROFILE ".claude-automation/decisions-$ProjectName.json"

        if (Test-Path $jsonPath) {
            $decisions = Get-Content $jsonPath -Raw | ConvertFrom-Json

            if ($Last -gt 0) {
                $decisions = $decisions | Select-Object -Last $Last
            }

            Write-Verbose "Loaded $($decisions.Count) decisions from JSON for project: $ProjectName"
            return $decisions
        }

        # Fallback to Markdown format (legacy)
        $config = Get-RegisteredProjects | Where-Object { $_.projectName -eq $ProjectName }
        if (-not $config) {
            Write-Warning "Project not found: $ProjectName"
            return @()
        }

        $logPath = Join-Path $config.repoPath ".claude-automation/decision-log.md"

        if (-not (Test-Path $logPath)) {
            Write-Verbose "No decision log found for project: $ProjectName"
            return @()
        }

        # Parse Markdown decision log
        $decisions = Parse-MarkdownDecisionLog -LogPath $logPath -Last $Last

        Write-Verbose "Loaded $($decisions.Count) decisions from Markdown for project: $ProjectName"

        return $decisions
    }
    catch {
        Write-Error "Failed to get decision history: $_"
        return @()
    }
}

function Add-DecisionToHistory {
    <#
    .SYNOPSIS
        Adds a decision to the history

    .DESCRIPTION
        Appends a decision to both JSON and Markdown logs

    .PARAMETER Decision
        The decision object to add

    .PARAMETER ProjectName
        The project name

    .PARAMETER ProjectPath
        The project repository path

    .EXAMPLE
        Add-DecisionToHistory -Decision $decision -ProjectName "my-project" -ProjectPath "C:\repos\my-project"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Decision,

        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter(Mandatory)]
        [string]$ProjectPath
    )

    try {
        # Save to JSON (primary format)
        $jsonPath = Join-Path $env:USERPROFILE ".claude-automation/decisions-$ProjectName.json"
        $decisions = @()

        if (Test-Path $jsonPath) {
            $decisions = @(Get-Content $jsonPath -Raw | ConvertFrom-Json)
        }

        $decisions += $Decision
        $decisions | ConvertTo-Json -Depth 10 | Set-Content $jsonPath

        # Also save to Markdown (human-readable format)
        Add-MarkdownDecisionLog -Decision $Decision -ProjectPath $ProjectPath

        Write-Verbose "Decision added to history for project: $ProjectName"
    }
    catch {
        Write-Error "Failed to add decision to history: $_"
    }
}

function Parse-MarkdownDecisionLog {
    <#
    .SYNOPSIS
        Parses a Markdown decision log file

    .DESCRIPTION
        Extracts decision entries from the Markdown log format

    .PARAMETER LogPath
        Path to the decision log Markdown file

    .PARAMETER Last
        Number of recent decisions to return

    .OUTPUTS
        Array of decision objects
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogPath,

        [Parameter()]
        [int]$Last = 10
    )

    try {
        $content = Get-Content $LogPath -Raw

        # Split by decision separator (##)
        $entries = $content -split '(?=^##\s+\d{4}-\d{2}-\d{2})' | Where-Object { $_ -match '##\s+\d{4}-\d{2}-\d{2}' }

        $decisions = @()

        foreach ($entry in $entries) {
            # Extract timestamp and action from header
            if ($entry -match '##\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+-\s+(.+?)[\r\n]') {
                $timestamp = $matches[1]
                $actionDescription = $matches[2]

                # Extract action
                $action = "unknown"
                if ($entry -match '\*\*Decision.*?\*\*:\s*[\r\n]+- Action:\s*`([^`]+)`') {
                    $action = $matches[1]
                }

                # Extract reasoning
                $reasoning = ""
                if ($entry -match '- Reasoning:\s*"([^"]+)"') {
                    $reasoning = $matches[1]
                }

                # Extract confidence
                $confidence = 0.0
                if ($entry -match '- Confidence:\s*([\d.]+)') {
                    $confidence = [double]$matches[1]
                }

                $decisions += @{
                    Timestamp = $timestamp
                    Action = $action
                    Reasoning = $reasoning
                    Confidence = $confidence
                    Source = "markdown"
                }
            }
        }

        if ($Last -gt 0) {
            $decisions = $decisions | Select-Object -Last $Last
        }

        return $decisions
    }
    catch {
        Write-Error "Failed to parse Markdown decision log: $_"
        return @()
    }
}

function Add-MarkdownDecisionLog {
    <#
    .SYNOPSIS
        Adds a decision entry to the Markdown log

    .DESCRIPTION
        Appends a formatted decision entry to the project's decision log

    .PARAMETER Decision
        The decision object

    .PARAMETER ProjectPath
        The project repository path
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Decision,

        [Parameter(Mandatory)]
        [string]$ProjectPath
    )

    try {
        $logDir = Join-Path $ProjectPath ".claude-automation"
        $logPath = Join-Path $logDir "decision-log.md"

        # Create directory if it doesn't exist
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        # Create log file with header if it doesn't exist
        if (-not (Test-Path $logPath)) {
            $header = @"
# Decision Log - Project: $(Split-Path $ProjectPath -Leaf)

> Automated decisions made by Claude Code Watchdog

---

"@
            Set-Content -Path $logPath -Value $header
        }

        # Format the decision entry
        $entry = @"

## $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - $($Decision.Action)

**State**: $(if ($Decision.Metadata.SessionStatus) { $Decision.Metadata.SessionStatus } else { "Unknown" })
**Method**: $($Decision.DecisionMethod)

**Context**:
- TODOs Remaining: $(if ($Decision.Metadata.TodosRemaining) { $Decision.Metadata.TodosRemaining } else { "N/A" })
- Error Count: $(if ($Decision.Metadata.ErrorCount) { $Decision.Metadata.ErrorCount } else { 0 })
- Processing: $(if ($Decision.Metadata.IsProcessing) { "Yes" } else { "No" })

**Decision**:
- Action: ``$($Decision.Action)``
- Reasoning: "$($Decision.Reasoning)"
- Confidence: $($Decision.Confidence)
$(if ($Decision.Metadata.CostEstimate) { "- Cost: `$$($Decision.Metadata.CostEstimate)" } else { "" })

$(if ($Decision.Command) { "**Command Sent**:`n``````n$($Decision.Command)`n``````" } else { "" })

---
"@

        # Append to log
        Add-Content -Path $logPath -Value $entry

        Write-Verbose "Decision logged to: $logPath"
    }
    catch {
        Write-Error "Failed to add Markdown decision log: $_"
    }
}

function Get-RecentDecisionCount {
    <#
    .SYNOPSIS
        Gets count of decisions made in recent time period

    .DESCRIPTION
        Counts how many decisions were made in the specified time period.
        Useful for detecting decision loops or high activity.

    .PARAMETER ProjectName
        The project name

    .PARAMETER Period
        Time period to check (default: 1 hour)

    .EXAMPLE
        Get-RecentDecisionCount -ProjectName "my-project" -Period ([TimeSpan]::FromMinutes(10))
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter()]
        [TimeSpan]$Period = [TimeSpan]::FromHours(1)
    )

    $history = Get-DecisionHistory -ProjectName $ProjectName -Last 100

    $cutoff = (Get-Date) - $Period
    $recentDecisions = $history | Where-Object {
        [DateTime]::Parse($_.Timestamp) -gt $cutoff
    }

    return $recentDecisions.Count
}

function Get-DecisionStatistics {
    <#
    .SYNOPSIS
        Gets statistics about decisions for a project

    .DESCRIPTION
        Calculates statistics like most common actions, average confidence, etc.

    .PARAMETER ProjectName
        The project name

    .PARAMETER Days
        Number of days to analyze (default: 7)

    .EXAMPLE
        Get-DecisionStatistics -ProjectName "my-project" -Days 7
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter()]
        [int]$Days = 7
    )

    try {
        $history = Get-DecisionHistory -ProjectName $ProjectName -Last 1000

        $cutoff = (Get-Date).AddDays(-$Days)
        $recentHistory = $history | Where-Object {
            [DateTime]::Parse($_.Timestamp) -gt $cutoff
        }

        if ($recentHistory.Count -eq 0) {
            return @{
                TotalDecisions = 0
                Period = "$Days days"
            }
        }

        # Calculate statistics
        $actionCounts = $recentHistory | Group-Object -Property Action | ForEach-Object {
            @{
                Action = $_.Name
                Count = $_.Count
                Percentage = [math]::Round(($_.Count / $recentHistory.Count) * 100, 1)
            }
        } | Sort-Object -Property Count -Descending

        $avgConfidence = ($recentHistory | Measure-Object -Property Confidence -Average).Average

        $apiDecisions = @($recentHistory | Where-Object { $_.DecisionMethod -eq "claude-api" }).Count
        $ruleDecisions = @($recentHistory | Where-Object { $_.DecisionMethod -eq "rule-based" }).Count

        return @{
            TotalDecisions = $recentHistory.Count
            Period = "$Days days"
            AverageConfidence = [math]::Round($avgConfidence, 3)
            ActionBreakdown = $actionCounts
            APIDecisions = $apiDecisions
            RuleBasedDecisions = $ruleDecisions
            APIUsagePercentage = if ($recentHistory.Count -gt 0) { [math]::Round(($apiDecisions / $recentHistory.Count) * 100, 1) } else { 0.0 }
        }
    }
    catch {
        Write-Error "Failed to get decision statistics: $_"
        return $null
    }
}

# Export functions
Export-ModuleMember -Function Get-DecisionHistory, Add-DecisionToHistory, Get-RecentDecisionCount, Get-DecisionStatistics
