<#
.SYNOPSIS
    Progress reporting and analytics for Claude Code Watchdog

.DESCRIPTION
    Generates progress reports, daily summaries, and project status analytics
    Part of WI-3.7: Progress Reporting

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS06 - Logging & Reporting (Week 3)
#>

function Generate-ProgressReport {
    <#
    .SYNOPSIS
        Generates a comprehensive progress report for a project

    .DESCRIPTION
        Creates a markdown-formatted progress report including:
        - Phase progress and completion
        - TODO statistics
        - Decision summary
        - Time tracking
        - Error history
        - Cost tracking
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter()]
        [switch]$IncludeCosts,

        [Parameter()]
        [switch]$ExportCSV
    )

    try {
        # Get project state and config
        $state = Get-ProjectState -ProjectName $ProjectName
        $config = Get-ProjectConfig -ProjectName $ProjectName

        if (-not $state) {
            Write-Error "Could not load project state for: $ProjectName"
            return $null
        }

        # Generate timestamp
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $reportDate = Get-Date -Format "yyyy-MM-dd"

        # Calculate time tracking
        $timeTracking = Get-ProjectTimeTracking -ProjectName $ProjectName -State $state

        # Get decision analytics
        $decisionAnalytics = Get-DecisionLogAnalytics -ProjectName $ProjectName

        # Build report
        $report = @"
# Progress Report - $ProjectName
**Generated:** $timestamp

## Project Overview
- **Repository:** $($config.repoPath)
- **Current Phase:** $($state.CurrentPhase)
- **Status:** $($state.Status)
- **Last Active:** $($state.LastCheckTime)

## Phase Progress
"@

        # Add phase information
        if ($config.Phases -and $config.Phases.Count -gt 0) {
            $currentPhaseIndex = Get-CurrentPhaseIndex -Config $config -State $state

            $report += "`n"
            for ($i = 0; $i -lt $config.Phases.Count; $i++) {
                $phase = $config.Phases[$i]
                $status = if ($i -lt $currentPhaseIndex) { "✅ Complete" }
                         elseif ($i -eq $currentPhaseIndex) { "🔄 In Progress" }
                         else { "⏳ Pending" }

                $report += "- **Phase $($i + 1): $($phase.Name)** - $status`n"
            }
        }

        # Add TODO statistics
        $report += @"

## TODO Statistics
- **Total TODOs:** $($state.Todos.Total)
- **Completed:** $($state.Todos.Completed)
- **Remaining:** $($state.Todos.Remaining)
- **Completion Rate:** $(if ($state.Todos.Total -gt 0) { [Math]::Round(($state.Todos.Completed / $state.Todos.Total) * 100, 1) } else { 0 })%

"@

        # Add time tracking
        if ($timeTracking) {
            $report += @"
## Time Tracking
- **Session Duration:** $($timeTracking.SessionDuration)
- **Current Phase Time:** $($timeTracking.CurrentPhaseTime)
- **Total Project Time:** $($timeTracking.TotalProjectTime)
- **Average Cycle Time:** $($timeTracking.AverageCycleTime)

"@
        }

        # Add decision summary
        if ($decisionAnalytics) {
            $report += @"
## Decision Summary
- **Total Decisions:** $($decisionAnalytics.TotalDecisions)
- **API Decisions:** $($decisionAnalytics.APIDecisions)
- **Rule-Based Decisions:** $($decisionAnalytics.RuleBasedDecisions)
- **Continue Actions:** $($decisionAnalytics.ContinueActions)
- **Wait Actions:** $($decisionAnalytics.WaitActions)
- **Skill Invocations:** $($decisionAnalytics.SkillInvocations)

"@

            # Add cost information if requested
            if ($IncludeCosts -and $decisionAnalytics.TotalAPICost -gt 0) {
                $report += @"
## Cost Tracking
- **Total API Cost:** `$$($decisionAnalytics.TotalAPICost.ToString('F4'))
- **Average Cost per API Call:** `$$($decisionAnalytics.AverageCostPerAPICall.ToString('F4'))
- **API Efficiency:** $(if ($decisionAnalytics.TotalDecisions -gt 0) { [Math]::Round(($decisionAnalytics.APIDecisions / $decisionAnalytics.TotalDecisions) * 100, 1) } else { 0 })% API usage

"@
            }
        }

        # Add error history
        if ($state.ErrorHistory -and $state.ErrorHistory.Count -gt 0) {
            $report += @"
## Error History
- **Total Errors Encountered:** $($state.ErrorHistory.Count)
- **Currently Active:** $($state.Errors.Count)
- **Resolved:** $($state.ErrorHistory.Count - $state.Errors.Count)

"@
        }

        # Add session statistics
        if ($state.Statistics) {
            $stats = $state.Statistics
            $report += @"
## Session Statistics
- **Projects Processed:** $($stats.ProjectsProcessed)
- **Decisions Made:** $($stats.DecisionsMade)
- **Commands Sent:** $($stats.CommandsSent)
- **Errors Encountered:** $($stats.ErrorsEncountered)
- **Skill Invocations:** $($stats.SkillsInvoked)

"@
        }

        # Add recommendations
        $report += @"

## Recommendations
"@

        $recommendations = Get-ProjectRecommendations -State $state -DecisionAnalytics $decisionAnalytics
        foreach ($rec in $recommendations) {
            $report += "- $rec`n"
        }

        # Save report to file
        $reportsDir = Join-Path $config.repoPath ".claude-automation/reports"
        if (-not (Test-Path $reportsDir)) {
            New-Item -Path $reportsDir -ItemType Directory -Force | Out-Null
        }

        $reportPath = Join-Path $reportsDir "progress-report-$reportDate.md"
        $report | Set-Content -Path $reportPath -Force

        # Export to CSV if requested
        if ($ExportCSV) {
            $csvPath = Join-Path $reportsDir "progress-report-$reportDate.csv"
            Export-ProgressReportCSV -ProjectName $ProjectName -State $state -Analytics $decisionAnalytics -Path $csvPath
        }

        return @{
            Success = $true
            ReportPath = $reportPath
            CSVPath = if ($ExportCSV) { $csvPath } else { $null }
            Report = $report
        }
    }
    catch {
        Write-Error "Failed to generate progress report: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Generate-DailySummary {
    <#
    .SYNOPSIS
        Generates a daily summary for all active projects

    .DESCRIPTION
        Creates a consolidated daily summary report across all registered projects
    #>
    param(
        [Parameter()]
        [switch]$IncludeCosts,

        [Parameter()]
        [switch]$SendNotification
    )

    try {
        $projects = Get-RegisteredProjects
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $reportDate = Get-Date -Format "yyyy-MM-dd"

        $summary = @"
# Daily Summary - Claude Code Watchdog
**Generated:** $timestamp
**Active Projects:** $($projects.Count)

---

"@

        $totalDecisions = 0
        $totalAPIDecisions = 0
        $totalCosts = 0
        $totalTodos = 0
        $totalCompleted = 0

        foreach ($project in $projects) {
            $projectName = $project.Name
            $state = Get-ProjectState -ProjectName $projectName

            if (-not $state) {
                continue
            }

            $analytics = Get-DecisionLogAnalytics -ProjectName $projectName

            $summary += @"
## $projectName
- **Status:** $($state.Status)
- **Current Phase:** $($state.CurrentPhase)
- **TODOs:** $($state.Todos.Completed)/$($state.Todos.Total) completed
- **Decisions Today:** $(if ($analytics) { $analytics.TotalDecisions } else { 0 })
- **Last Active:** $($state.LastCheckTime)

"@

            # Aggregate statistics
            $totalTodos += $state.Todos.Total
            $totalCompleted += $state.Todos.Completed
            if ($analytics) {
                $totalDecisions += $analytics.TotalDecisions
                $totalAPIDecisions += $analytics.APIDecisions
                $totalCosts += $analytics.TotalAPICost
            }
        }

        # Add aggregate summary
        $summary += @"

---

## Aggregate Statistics
- **Total TODOs Across Projects:** $totalCompleted/$totalTodos completed
- **Overall Completion Rate:** $(if ($totalTodos -gt 0) { [Math]::Round(($totalCompleted / $totalTodos) * 100, 1) } else { 0 })%
- **Total Decisions Made:** $totalDecisions
- **API Decisions:** $totalAPIDecisions ($(if ($totalDecisions -gt 0) { [Math]::Round(($totalAPIDecisions / $totalDecisions) * 100, 1) } else { 0 })%)

"@

        if ($IncludeCosts -and $totalCosts -gt 0) {
            $summary += @"
- **Total API Costs Today:** `$$($totalCosts.ToString('F4'))

"@
        }

        # Save summary
        $summaryDir = "$HOME/.claude-automation/reports"
        if (-not (Test-Path $summaryDir)) {
            New-Item -Path $summaryDir -ItemType Directory -Force | Out-Null
        }

        $summaryPath = Join-Path $summaryDir "daily-summary-$reportDate.md"
        $summary | Set-Content -Path $summaryPath -Force

        # Send notification if requested
        if ($SendNotification) {
            Send-Notification -Title "Daily Summary Ready" -Message "Generated for $($projects.Count) projects. $totalCompleted/$totalTodos TODOs completed." -Type "Info"
        }

        return @{
            Success = $true
            SummaryPath = $summaryPath
            Summary = $summary
            Projects = $projects.Count
            TotalDecisions = $totalDecisions
            CompletionRate = if ($totalTodos -gt 0) { ($totalCompleted / $totalTodos) * 100 } else { 0 }
        }
    }
    catch {
        Write-Error "Failed to generate daily summary: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-ProjectTimeTracking {
    <#
    .SYNOPSIS
        Calculates time tracking metrics for a project
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter(Mandatory)]
        [hashtable]$State
    )

    try {
        $now = Get-Date

        # Calculate session duration
        $sessionStart = if ($State.SessionStartTime) {
            [DateTime]$State.SessionStartTime
        } else {
            $now
        }
        $sessionDuration = $now - $sessionStart

        # Calculate current phase time
        $phaseStart = if ($State.CurrentPhaseStartTime) {
            [DateTime]$State.CurrentPhaseStartTime
        } else {
            $sessionStart
        }
        $currentPhaseTime = $now - $phaseStart

        # Calculate total project time from all phases
        $totalProjectTime = $sessionDuration
        if ($State.PhaseHistory -and $State.PhaseHistory.Count -gt 0) {
            foreach ($phase in $State.PhaseHistory) {
                if ($phase.Duration) {
                    $totalProjectTime += [TimeSpan]$phase.Duration
                }
            }
        }

        # Calculate average cycle time
        $avgCycleTime = if ($State.Statistics -and $State.Statistics.ProjectsProcessed -gt 0) {
            $sessionDuration.TotalSeconds / $State.Statistics.ProjectsProcessed
        } else {
            0
        }

        return @{
            SessionDuration = Format-TimeSpan -TimeSpan $sessionDuration
            CurrentPhaseTime = Format-TimeSpan -TimeSpan $currentPhaseTime
            TotalProjectTime = Format-TimeSpan -TimeSpan $totalProjectTime
            AverageCycleTime = "$([Math]::Round($avgCycleTime, 1))s"
        }
    }
    catch {
        Write-Verbose "Error calculating time tracking: $_"
        return $null
    }
}

function Format-TimeSpan {
    <#
    .SYNOPSIS
        Formats a timespan into a readable string
    #>
    param(
        [Parameter(Mandatory)]
        [TimeSpan]$TimeSpan
    )

    if ($TimeSpan.TotalHours -ge 1) {
        return "$([Math]::Round($TimeSpan.TotalHours, 1)) hours"
    }
    elseif ($TimeSpan.TotalMinutes -ge 1) {
        return "$([Math]::Round($TimeSpan.TotalMinutes, 1)) minutes"
    }
    else {
        return "$([Math]::Round($TimeSpan.TotalSeconds, 1)) seconds"
    }
}

function Get-ProjectRecommendations {
    <#
    .SYNOPSIS
        Generates actionable recommendations based on project state
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter()]
        [hashtable]$DecisionAnalytics
    )

    $recommendations = @()

    # Check TODO completion rate
    if ($State.Todos.Total -gt 0) {
        $completionRate = ($State.Todos.Completed / $State.Todos.Total) * 100
        if ($completionRate -lt 25) {
            $recommendations += "⚠️ Low TODO completion rate ($([Math]::Round($completionRate, 1))%). Project may need attention."
        }
        elseif ($completionRate -ge 90) {
            $recommendations += "✅ Excellent progress! $([Math]::Round($completionRate, 1))% of TODOs completed."
        }
    }

    # Check error frequency
    if ($State.ErrorHistory -and $State.ErrorHistory.Count -gt 10) {
        $recommendations += "⚠️ High error count ($($State.ErrorHistory.Count)). Consider reviewing error patterns."
    }

    # Check API vs Rule-based decisions
    if ($DecisionAnalytics) {
        if ($DecisionAnalytics.TotalDecisions -gt 0) {
            $apiPercentage = ($DecisionAnalytics.APIDecisions / $DecisionAnalytics.TotalDecisions) * 100
            if ($apiPercentage -lt 20) {
                $recommendations += "💡 Low API usage ($([Math]::Round($apiPercentage, 1))%). Consider enabling API for better decisions."
            }
        }

        # Check skill invocations
        if ($DecisionAnalytics.SkillInvocations -gt 5) {
            $recommendations += "🔧 Frequent skill invocations ($($DecisionAnalytics.SkillInvocations)). Error resolution is working well."
        }
    }

    # Check project status
    if ($State.Status -eq "Quarantined") {
        $recommendations += "🚨 Project is quarantined. Manual intervention required."
    }
    elseif ($State.Status -eq "Paused") {
        $recommendations += "⏸️ Project is paused. Resume when ready to continue."
    }

    # Default recommendation if all is well
    if ($recommendations.Count -eq 0) {
        $recommendations += "✅ Project is progressing smoothly. No action needed."
    }

    return $recommendations
}

function Export-ProgressReportCSV {
    <#
    .SYNOPSIS
        Exports progress report data to CSV format
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter()]
        [hashtable]$Analytics,

        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        $csvData = @()

        # Create row for project data
        $row = [PSCustomObject]@{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ProjectName = $ProjectName
            Status = $State.Status
            CurrentPhase = $State.CurrentPhase
            TotalTodos = $State.Todos.Total
            CompletedTodos = $State.Todos.Completed
            RemainingTodos = $State.Todos.Remaining
            CompletionRate = if ($State.Todos.Total -gt 0) { ($State.Todos.Completed / $State.Todos.Total) * 100 } else { 0 }
            TotalDecisions = if ($Analytics) { $Analytics.TotalDecisions } else { 0 }
            APIDecisions = if ($Analytics) { $Analytics.APIDecisions } else { 0 }
            RuleDecisions = if ($Analytics) { $Analytics.RuleBasedDecisions } else { 0 }
            SkillInvocations = if ($Analytics) { $Analytics.SkillInvocations } else { 0 }
            TotalAPICost = if ($Analytics) { $Analytics.TotalAPICost } else { 0 }
            ErrorCount = $State.Errors.Count
            ErrorHistoryCount = if ($State.ErrorHistory) { $State.ErrorHistory.Count } else { 0 }
        }

        $csvData += $row

        # Export to CSV
        $csvData | Export-Csv -Path $Path -NoTypeInformation -Force

        Write-Verbose "Exported progress report to CSV: $Path"
    }
    catch {
        Write-Error "Failed to export CSV: $_"
    }
}

function Get-CurrentPhaseIndex {
    <#
    .SYNOPSIS
        Gets the index of the current phase
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if (-not $Config.Phases -or $Config.Phases.Count -eq 0) {
        return 0
    }

    for ($i = 0; $i -lt $Config.Phases.Count; $i++) {
        if ($Config.Phases[$i].Name -eq $State.CurrentPhase) {
            return $i
        }
    }

    return 0
}

# Export functions
Export-ModuleMember -Function Generate-ProgressReport, Generate-DailySummary, Get-ProjectTimeTracking, Format-TimeSpan, Get-ProjectRecommendations, Export-ProgressReportCSV
