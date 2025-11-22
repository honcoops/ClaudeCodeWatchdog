<#
.SYNOPSIS
    Phase transition management for Claude Code Watchdog

.DESCRIPTION
    Manages transitions between project phases including commits and notifications

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS04 - Action & Execution
    Work Item: WI-3.4 - Phase Transition Logic
#>

# Import dependencies
$ScriptRoot = Split-Path -Parent $PSCommandPath
. "$ScriptRoot/Invoke-GitOperations.ps1"
. "$ScriptRoot/../Logging/Write-WatchdogLog.ps1"
. "$ScriptRoot/../Logging/Send-Notification.ps1"
. "$ScriptRoot/../Registry/Update-ProjectState.ps1"

function Test-PhaseComplete {
    <#
    .SYNOPSIS
        Checks if the current phase is complete
    .DESCRIPTION
        Analyzes project state to determine if all phase objectives are met
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$ProjectState,

        [Parameter(Mandatory)]
        [hashtable]$PhaseConfig
    )

    Write-Verbose "Checking if phase is complete: $($PhaseConfig.name)"

    try {
        $completionIndicators = @{
            AllTodosDone = $false
            NoErrors = $false
            DurationMet = $false
            ManualApproval = $false
        }

        # Check 1: All TODOs completed
        if ($ProjectState.todos) {
            $totalTodos = $ProjectState.todos.total
            $completedTodos = $ProjectState.todos.completed

            if ($totalTodos -gt 0 -and $completedTodos -eq $totalTodos) {
                $completionIndicators.AllTodosDone = $true
                Write-Verbose "✓ All TODOs completed ($completedTodos/$totalTodos)"
            }
            elseif ($totalTodos -eq 0) {
                # No TODOs defined means this check passes
                $completionIndicators.AllTodosDone = $true
            }
            else {
                Write-Verbose "✗ TODOs incomplete ($completedTodos/$totalTodos)"
            }
        }
        else {
            # No TODO tracking means this check passes
            $completionIndicators.AllTodosDone = $true
        }

        # Check 2: No critical errors
        if ($ProjectState.errors) {
            $criticalErrors = $ProjectState.errors | Where-Object {
                $_.Severity -eq 'High' -or $_.Category -eq 'Critical'
            }

            if ($criticalErrors.Count -eq 0) {
                $completionIndicators.NoErrors = $true
                Write-Verbose "✓ No critical errors"
            }
            else {
                Write-Verbose "✗ Critical errors present ($($criticalErrors.Count))"
            }
        }
        else {
            $completionIndicators.NoErrors = $true
        }

        # Check 3: Phase duration objectives met (optional)
        if ($PhaseConfig.estimatedDuration) {
            $phaseStartTime = if ($ProjectState.currentPhase.startTime) {
                [DateTime]::Parse($ProjectState.currentPhase.startTime)
            }
            else {
                Get-Date
            }

            $elapsed = (Get-Date) - $phaseStartTime

            # Parse duration (format: "1h", "30m", "2h30m")
            $estimatedMinutes = ConvertTo-Minutes -Duration $PhaseConfig.estimatedDuration

            if ($elapsed.TotalMinutes -ge $estimatedMinutes) {
                $completionIndicators.DurationMet = $true
                Write-Verbose "✓ Phase duration met ($([int]$elapsed.TotalMinutes)m / $estimatedMinutes m)"
            }
            else {
                Write-Verbose "⏱ Phase duration not yet met ($([int]$elapsed.TotalMinutes)m / $estimatedMinutes m)"
                # Don't block on this - it's informational
                $completionIndicators.DurationMet = $true
            }
        }
        else {
            $completionIndicators.DurationMet = $true
        }

        # Check 4: Manual approval if required
        if ($PhaseConfig.requiresManualApproval) {
            if ($ProjectState.currentPhase.manuallyApproved) {
                $completionIndicators.ManualApproval = $true
                Write-Verbose "✓ Manual approval granted"
            }
            else {
                Write-Verbose "✗ Awaiting manual approval"
            }
        }
        else {
            $completionIndicators.ManualApproval = $true
        }

        # Phase is complete if all required checks pass
        $isComplete = $completionIndicators.AllTodosDone -and
                      $completionIndicators.NoErrors -and
                      $completionIndicators.ManualApproval

        return @{
            IsComplete = $isComplete
            Indicators = $completionIndicators
            Phase = $PhaseConfig.name
        }
    }
    catch {
        Write-Error "Error checking phase completion: $_"
        return @{
            IsComplete = $false
            Error = $_.Exception.Message
        }
    }
}

function Invoke-PhaseTransition {
    <#
    .SYNOPSIS
        Executes a transition from one phase to the next
    .DESCRIPTION
        Handles all phase transition tasks: commits, notifications, state updates
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$ProjectConfig,

        [Parameter(Mandatory)]
        [hashtable]$ProjectState,

        [Parameter()]
        [switch]$Force
    )

    Write-Host "`n🔄 Initiating phase transition..." -ForegroundColor Cyan

    try {
        # Get current and next phase
        $currentPhaseIndex = Get-CurrentPhaseIndex -ProjectConfig $ProjectConfig -ProjectState $ProjectState
        $currentPhase = $ProjectConfig.phases[$currentPhaseIndex]

        # Check if this is the last phase
        $isLastPhase = $currentPhaseIndex -eq ($ProjectConfig.phases.Count - 1)

        if (-not $Force) {
            # Verify phase is actually complete
            $completionCheck = Test-PhaseComplete -ProjectState $ProjectState -PhaseConfig $currentPhase

            if (-not $completionCheck.IsComplete) {
                Write-Warning "Phase is not complete. Use -Force to override."
                return @{
                    Success = $false
                    Transitioned = $false
                    Reason = "Phase not complete"
                    CompletionStatus = $completionCheck
                }
            }
        }

        # Step 1: Create phase completion commit
        Write-Host "📝 Creating phase completion commit..." -ForegroundColor Cyan

        $commitMessage = Build-PhaseCommitMessage -Phase $currentPhase -ProjectState $ProjectState
        $commitResult = Invoke-GitCommit -Message $commitMessage -RepoPath $ProjectConfig.repoPath

        if (-not $commitResult.Success) {
            Write-Warning "Commit failed, but continuing transition"
        }
        else {
            Write-Host "✅ Commit created: $($commitResult.CommitHash)" -ForegroundColor Green
        }

        # Step 2: Push to remote if configured
        if ($ProjectConfig.commitStrategy.autoPush) {
            Write-Host "📤 Pushing to remote..." -ForegroundColor Cyan

            $pushResult = Invoke-GitPush -RepoPath $ProjectConfig.repoPath -SetUpstream

            if ($pushResult.Success) {
                Write-Host "✅ Pushed to remote successfully" -ForegroundColor Green
            }
            else {
                Write-Warning "Push failed: $($pushResult.Error)"
            }
        }

        # Step 3: Send completion notification
        $notificationTitle = "Phase Complete: $($currentPhase.name)"
        $notificationMessage = "Completed phase '$($currentPhase.name)' for project $($ProjectConfig.projectName)"

        Send-Notification -Title $notificationTitle -Message $notificationMessage -Type "Success"

        # Step 4: Log phase completion
        Write-WatchdogLog -Message "Phase completed: $($currentPhase.name)" -Level "Info"

        # Step 5: Transition to next phase (if not last)
        if ($isLastPhase) {
            Write-Host "`n🎉 Project complete! All phases finished." -ForegroundColor Green

            # Mark project as complete
            $ProjectState.status = "Complete"
            $ProjectState.completedAt = (Get-Date).ToString('o')

            Update-ProjectState -ProjectName $ProjectConfig.projectName -State $ProjectState

            return @{
                Success = $true
                Transitioned = $true
                ProjectComplete = $true
                CompletedPhase = $currentPhase.name
                CommitHash = $commitResult.CommitHash
            }
        }
        else {
            $nextPhaseIndex = $currentPhaseIndex + 1
            $nextPhase = $ProjectConfig.phases[$nextPhaseIndex]

            Write-Host "`n➡️ Advancing to phase: $($nextPhase.name)" -ForegroundColor Cyan

            # Update project state
            $ProjectState.currentPhase = @{
                index = $nextPhaseIndex
                name = $nextPhase.name
                startTime = (Get-Date).ToString('o')
                manuallyApproved = $false
            }

            # Reset phase-specific state
            $ProjectState.todos = @{
                total = 0
                completed = 0
                remaining = 0
            }

            # Clear completed phase errors
            if ($ProjectState.errors) {
                $ProjectState.errors = @()
            }

            Update-ProjectState -ProjectName $ProjectConfig.projectName -State $ProjectState

            # Notify about new phase
            $nextPhaseNotification = "Starting phase: $($nextPhase.name)"
            Send-Notification -Title "New Phase" -Message $nextPhaseNotification -Type "Info"

            Write-Host "✅ Transitioned to phase: $($nextPhase.name)" -ForegroundColor Green

            return @{
                Success = $true
                Transitioned = $true
                ProjectComplete = $false
                CompletedPhase = $currentPhase.name
                NewPhase = $nextPhase.name
                CommitHash = $commitResult.CommitHash
            }
        }
    }
    catch {
        Write-Error "Phase transition failed: $_"
        Write-WatchdogLog -Message "Phase transition failed: $_" -Level "Error"

        return @{
            Success = $false
            Transitioned = $false
            Error = $_.Exception.Message
        }
    }
}

function Build-PhaseCommitMessage {
    <#
    .SYNOPSIS
        Builds a descriptive commit message for phase completion
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Phase,

        [Parameter(Mandatory)]
        [hashtable]$ProjectState
    )

    $message = "Complete Phase: $($Phase.name)"

    # Add summary if available
    if ($ProjectState.todos) {
        $message += "`n`nCompleted $($ProjectState.todos.completed) tasks"
    }

    # Add timing information
    if ($ProjectState.currentPhase.startTime) {
        $startTime = [DateTime]::Parse($ProjectState.currentPhase.startTime)
        $duration = (Get-Date) - $startTime
        $message += "`nDuration: $([int]$duration.TotalHours)h $($duration.Minutes)m"
    }

    # Add phase description if available
    if ($Phase.description) {
        $message += "`n`n$($Phase.description)"
    }

    return $message
}

function Get-CurrentPhaseIndex {
    <#
    .SYNOPSIS
        Gets the index of the current phase
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$ProjectConfig,

        [Parameter(Mandatory)]
        [hashtable]$ProjectState
    )

    if ($ProjectState.currentPhase -and $ProjectState.currentPhase.index -ne $null) {
        return $ProjectState.currentPhase.index
    }

    # Default to first phase if not set
    return 0
}

function ConvertTo-Minutes {
    <#
    .SYNOPSIS
        Converts duration string to minutes
    .DESCRIPTION
        Parses duration strings like "1h", "30m", "2h30m" to total minutes
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Duration
    )

    try {
        $totalMinutes = 0

        # Match hours
        if ($Duration -match '(\d+)h') {
            $totalMinutes += [int]$matches[1] * 60
        }

        # Match minutes
        if ($Duration -match '(\d+)m') {
            $totalMinutes += [int]$matches[1]
        }

        # If no units found, assume minutes
        if ($totalMinutes -eq 0 -and $Duration -match '^\d+$') {
            $totalMinutes = [int]$Duration
        }

        return $totalMinutes
    }
    catch {
        Write-Warning "Failed to parse duration '$Duration', defaulting to 60 minutes"
        return 60
    }
}

function Approve-PhaseCompletion {
    <#
    .SYNOPSIS
        Manually approves a phase for completion
    .DESCRIPTION
        Sets manual approval flag for phases that require human sign-off
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter()]
        [string]$ApprovedBy = $env:USERNAME
    )

    try {
        # Load project state
        $projectState = Get-ProjectState -ProjectName $ProjectName

        if (-not $projectState) {
            throw "Project not found: $ProjectName"
        }

        # Set approval flag
        $projectState.currentPhase.manuallyApproved = $true
        $projectState.currentPhase.approvedBy = $ApprovedBy
        $projectState.currentPhase.approvedAt = (Get-Date).ToString('o')

        # Update state
        Update-ProjectState -ProjectName $ProjectName -State $projectState

        Write-Host "✅ Phase approved by $ApprovedBy" -ForegroundColor Green
        Write-WatchdogLog -Message "Phase manually approved: $($projectState.currentPhase.name) by $ApprovedBy" -Level "Info"

        return @{
            Success = $true
            Phase = $projectState.currentPhase.name
            ApprovedBy = $ApprovedBy
        }
    }
    catch {
        Write-Error "Failed to approve phase: $_"

        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-ProjectState {
    <#
    .SYNOPSIS
        Helper to retrieve project state
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName
    )

    # This would normally load from the registry
    # Placeholder implementation
    return @{
        currentPhase = @{
            index = 0
            name = "implementation"
            startTime = (Get-Date).ToString('o')
            manuallyApproved = $false
        }
        todos = @{
            total = 0
            completed = 0
            remaining = 0
        }
        errors = @()
        status = "InProgress"
    }
}

# Export functions
Export-ModuleMember -Function Test-PhaseComplete, Invoke-PhaseTransition,
    Build-PhaseCommitMessage, Get-CurrentPhaseIndex, ConvertTo-Minutes,
    Approve-PhaseCompletion
