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
        Formats a decision as a markdown entry with API metadata and enhanced context
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

"@

    # Add API metadata if available (WI-2.6 Enhancement)
    if ($Decision.APIMetadata) {
        $metadata = $Decision.APIMetadata
        $entry += @"

### API Metadata
- **Model:** $($metadata.Model)
- **Input Tokens:** $($metadata.InputTokens)
- **Output Tokens:** $($metadata.OutputTokens)
- **Total Tokens:** $($metadata.TotalTokens)
- **Estimated Cost:** `$$($metadata.EstimatedCost)
- **API Latency:** $($metadata.LatencyMs)ms

"@
    }

    # Add cost tracking summary if available
    if ($Decision.CostTracking) {
        $costs = $Decision.CostTracking
        $entry += @"

### Cost Tracking
- **Session Total:** `$$($costs.SessionTotal)
- **Daily Total:** `$$($costs.DailyTotal)
- **Budget Remaining:** `$$($costs.BudgetRemaining) ($($costs.BudgetUsedPercent)% used)

"@
    }

    # Add skill invocation details if applicable (WI-2.6 Enhancement)
    if ($Decision.SkillInvoked) {
        $entry += @"

### Skill Invocation
- **Skill:** $($Decision.SkillName)
- **Error Type:** $($Decision.ErrorType)
- **Match Score:** $($Decision.SkillMatchScore)
- **Context:** $($Decision.SkillContext)

"@
    }

    $entry += @"

**Reasoning:**
$($Decision.Reasoning)

"@

    # Enhanced context section (WI-2.6)
    $entry += @"

### Session Context
- **TODOs:** $($State.Todos.Total) total, $($State.Todos.Completed) completed, $($State.Todos.Remaining) remaining
- **Errors:** $($State.Errors.Count) active errors
- **Warnings:** $(if ($State.Warnings) { $State.Warnings.Count } else { 0 }) warnings
- **Is Processing:** $($State.IsProcessing)
- **Phase:** $(if ($State.CurrentPhase) { $State.CurrentPhase } else { 'N/A' })
- **Session ID:** $(if ($State.SessionId) { $State.SessionId.Substring(0, [Math]::Min(8, $State.SessionId.Length)) } else { 'N/A' })

"@

    # Add error details if present
    if ($State.Errors -and $State.Errors.Count -gt 0) {
        $entry += @"

### Active Errors
"@
        foreach ($error in $State.Errors) {
            $entry += @"

- **[$($error.Severity)]** $($error.Message)
"@
        }
        $entry += "`n`n"
    }

    # Add command if present
    if ($Decision.Command) {
        $entry += @"

**Command Sent:**
``````
$($Decision.Command)
``````

"@
    }

    # Add comparison if rule-based fallback was used
    if ($Decision.FallbackUsed) {
        $entry += @"

> ⚠️ **Note:** API decision failed, using rule-based fallback.
> API Error: $($Decision.APIError)

"@
    }

    # Add decision comparison if both methods were used (for analysis)
    if ($Decision.RuleBasedDecision -and $Decision.DecisionMethod -eq "Claude API") {
        $entry += @"

### Decision Comparison
- **API Decision:** $($Decision.Action)
- **Rule-Based:** $($Decision.RuleBasedDecision.Action)
- **Agreement:** $(if ($Decision.Action -eq $Decision.RuleBasedDecision.Action) { 'Yes ✓' } else { 'No ✗' })

"@
    }

    $entry += "---`n"

    return $entry
}

function Get-DecisionLogSummary {
    <#
    .SYNOPSIS
        Gets a summary of recent decisions for a project (WI-2.6 Enhancement)
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
            return @{
                Success = $false
                Message = "No decision log found"
            }
        }

        # Read log file
        $content = Get-Content -Path $logPath -Raw

        # Parse decision entries
        $entries = $content -split '(?=## Decision -)'
        $entries = $entries | Where-Object { $_ -match '## Decision' } | Select-Object -Last $Last

        $decisions = @()
        foreach ($entry in $entries) {
            # Extract key information
            if ($entry -match '## Decision - (.+)') {
                $timestamp = $Matches[1]
            }
            if ($entry -match '\*\*Action:\*\* (.+)') {
                $action = $Matches[1]
            }
            if ($entry -match '\*\*Confidence:\*\* (.+)%') {
                $confidence = $Matches[1]
            }
            if ($entry -match '\*\*Method:\*\* (.+)') {
                $method = $Matches[1]
            }

            $decisions += @{
                Timestamp = $timestamp
                Action = $action
                Confidence = $confidence
                Method = $method
            }
        }

        return @{
            Success = $true
            TotalDecisions = $decisions.Count
            Decisions = $decisions
            LogPath = $logPath
        }
    }
    catch {
        Write-Error "Failed to get decision summary: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-DecisionLogAnalytics {
    <#
    .SYNOPSIS
        Analyzes decision log for patterns and statistics (WI-2.6 Enhancement)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter()]
        [int]$Days = 1
    )

    try {
        $config = Get-ProjectConfig -ProjectName $ProjectName
        $logPath = Join-Path $config.repoPath ".claude-automation/decision-log.md"

        if (-not (Test-Path $logPath)) {
            return $null
        }

        $content = Get-Content -Path $logPath -Raw
        $entries = $content -split '(?=## Decision -)'
        $entries = $entries | Where-Object { $_ -match '## Decision' }

        # Calculate analytics
        $totalDecisions = $entries.Count
        $apiDecisions = ($entries | Where-Object { $_ -match '\*\*Method:\*\* Claude API' }).Count
        $ruleDecisions = ($entries | Where-Object { $_ -match '\*\*Method:\*\* Rule-Based' }).Count

        # Count actions
        $continueActions = ($entries | Where-Object { $_ -match '\*\*Action:\*\* continue' }).Count
        $waitActions = ($entries | Where-Object { $_ -match '\*\*Action:\*\* wait' }).Count
        $notifyActions = ($entries | Where-Object { $_ -match '\*\*Action:\*\* notify' }).Count

        # Count skill invocations
        $skillInvocations = ($entries | Where-Object { $_ -match '### Skill Invocation' }).Count

        # Extract cost data
        $totalCost = 0
        foreach ($entry in $entries) {
            if ($entry -match '\*\*Estimated Cost:\*\* \$([0-9.]+)') {
                $totalCost += [double]$Matches[1]
            }
        }

        return @{
            TotalDecisions = $totalDecisions
            APIDecisions = $apiDecisions
            RuleBasedDecisions = $ruleDecisions
            ContinueActions = $continueActions
            WaitActions = $waitActions
            NotifyActions = $notifyActions
            SkillInvocations = $skillInvocations
            TotalAPICost = $totalCost
            AverageCostPerAPICall = if ($apiDecisions -gt 0) { $totalCost / $apiDecisions } else { 0 }
        }
    }
    catch {
        Write-Error "Failed to analyze decision log: $_"
        return $null
    }
}

# Export functions
Export-ModuleMember -Function Add-DecisionLog, Format-DecisionEntry, Get-DecisionLogSummary, Get-DecisionLogAnalytics
