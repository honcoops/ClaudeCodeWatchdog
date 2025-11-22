<#
.SYNOPSIS
    Main entry point for the Claude Code Watchdog

.DESCRIPTION
    Starts the watchdog monitoring process that continuously polls Claude Code sessions
    and takes autonomous actions based on detected state.

.PARAMETER PollingInterval
    Interval in seconds between polling cycles (default: 120)

.PARAMETER MaxRunDuration
    Maximum runtime in hours before auto-shutdown (default: none)

.EXAMPLE
    .\Start-Watchdog.ps1

.EXAMPLE
    .\Start-Watchdog.ps1 -PollingInterval 60 -MaxRunDuration 8

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS05 - Project Management
    Enhanced: WI-3.2 (Concurrent Processing) & WI-3.6 (Session Recovery)
#>

[CmdletBinding()]
param(
    [Parameter()]
    [int]$PollingInterval = 120,

    [Parameter()]
    [int]$MaxRunDuration = 0,

    [Parameter()]
    [switch]$SkipRecovery
)

# Import required modules
$ScriptRoot = Split-Path -Parent $PSCommandPath
. "$ScriptRoot/../Utils/Invoke-WindowsMCP.ps1"
. "$ScriptRoot/../Utils/Get-WatchdogConfig.ps1"
. "$ScriptRoot/../Registry/Get-RegisteredProjects.ps1"
. "$ScriptRoot/../Registry/Update-ProjectState.ps1"
. "$ScriptRoot/../Detection/Get-ClaudeCodeState.ps1"
. "$ScriptRoot/../Detection/Find-ClaudeCodeSession.ps1"
. "$ScriptRoot/../Decision/Invoke-SimpleDecision.ps1"
. "$ScriptRoot/../Decision/Get-DecisionHistory.ps1"
. "$ScriptRoot/../Action/Send-ClaudeCodeCommand.ps1"
. "$ScriptRoot/../Logging/Write-WatchdogLog.ps1"
. "$ScriptRoot/../Logging/Add-DecisionLog.ps1"
. "$ScriptRoot/../Logging/Send-Notification.ps1"
. "$ScriptRoot/Initialize-Watchdog.ps1"

function Start-Watchdog {
    <#
    .SYNOPSIS
        Initializes and runs the main watchdog loop
    #>
    param(
        [int]$PollingIntervalSeconds = 120,
        [int]$MaxRunHours = 0
    )

    try {
        # Initialize environment
        Write-Host "🤖 Starting Claude Code Watchdog..." -ForegroundColor Cyan
        Initialize-WatchdogEnvironment

        # Set global running flag
        $global:WatchdogRunning = $true
        $startTime = Get-Date
        $global:WatchdogStartTime = $startTime

        # Initialize resource monitoring (WI-3.2)
        Initialize-ResourceMonitoring

        # Register shutdown handler
        Register-ShutdownHandler

        # Attempt session recovery (WI-3.6)
        if (-not $SkipRecovery) {
            Restore-WatchdogSessions
        }

        Write-Host "✅ Watchdog initialized. Polling every $PollingIntervalSeconds seconds" -ForegroundColor Green
        Write-WatchdogLog -Message "Watchdog started (Recovery: $(-not $SkipRecovery))" -Level "Info"

        # Main loop
        while ($global:WatchdogRunning) {
            $cycleStartTime = Get-Date

            try {
                # Check max runtime
                if ($MaxRunHours -gt 0) {
                    $elapsed = (Get-Date) - $startTime
                    if ($elapsed.TotalHours -ge $MaxRunHours) {
                        Write-Host "⏰ Max runtime reached ($MaxRunHours hours). Shutting down..." -ForegroundColor Yellow
                        break
                    }
                }

                # Measure resource usage before processing (WI-3.2)
                $preProcessResources = Measure-ResourceUsage

                # Get active projects
                $projects = Get-ActiveProjects

                if ($projects.Count -eq 0) {
                    Write-Host "⚠️  No active projects registered. Use Register-Project.ps1 to add projects." -ForegroundColor Yellow
                }
                else {
                    Write-Host "`n📋 Processing $($projects.Count) project(s)..." -ForegroundColor Cyan

                    foreach ($project in $projects) {
                        try {
                            Process-Project -Project $project
                        }
                        catch {
                            Handle-ProjectError -Project $project -Error $_
                        }
                    }
                }

                # Measure resource usage after processing (WI-3.2)
                $postProcessResources = Measure-ResourceUsage
                Update-ResourceMetrics -PreProcess $preProcessResources -PostProcess $postProcessResources

                # Update heartbeat
                Update-Heartbeat

                # Calculate cycle time and adjust sleep if needed (WI-3.2)
                $cycleTime = ((Get-Date) - $cycleStartTime).TotalSeconds
                $global:WatchdogStats.LastCycleDuration = $cycleTime
                $global:WatchdogStats.CyclesCompleted++

                # Sleep until next cycle
                Start-Sleep -Seconds $PollingIntervalSeconds
            }
            catch {
                Write-Error "Error in main loop: $_"
                Write-WatchdogLog -Message "Main loop error: $_" -Level "Error"
                Start-Sleep -Seconds 30
            }
        }

        # Cleanup
        Write-Host "`n🛑 Shutting down watchdog..." -ForegroundColor Yellow

        # Persist state before shutdown (WI-3.6)
        Save-WatchdogState

        Cleanup-WatchdogResources
        Write-Host "✅ Watchdog stopped cleanly" -ForegroundColor Green
    }
    catch {
        Write-Error "Fatal error: $_"
        throw
    }
}

function Process-Project {
    <#
    .SYNOPSIS
        Processes a single project: detect state, decide action, execute
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Project
    )

    Write-Host "  🔍 Checking: $($Project.Name)..." -ForegroundColor Gray

    try {
        # Step 1: Find Claude Code session for this project
        $session = Find-ClaudeCodeSession -ProjectName $Project.Name

        # Session loss detection (WI-3.6)
        if (-not $session) {
            # Check if we previously had a session
            $projectState = Get-ProjectState -ProjectName $Project.Name

            if ($projectState -and $projectState.sessionId) {
                # Session was lost
                Write-Host "    ⚠️  Session lost (was: $($projectState.sessionId))" -ForegroundColor Yellow
                Write-WatchdogLog -Message "Session lost for project $($Project.Name)" -Level "Warning"

                # Notify user
                Send-Notification -Title "Session Lost" `
                    -Message "Claude Code session for '$($Project.Name)' has closed or crashed" `
                    -ProjectName $Project.Name

                # Update state to reflect session loss
                Update-ProjectState -ProjectName $Project.Name -StateUpdates @{
                    status = "SessionLost"
                    lastActivity = (Get-Date).ToString("o")
                    sessionId = $null
                }
            }
            else {
                Write-Verbose "No active session found for $($Project.Name)"
            }

            return
        }

        Write-Verbose "Found session for $($Project.Name): $($session.SessionId)"

        # Step 2: Get current state
        $state = Get-ClaudeCodeState -SessionWindow $session.WindowHandle

        Write-Host "    Status: $($state.Status) | TODOs: $($state.Todos.Remaining) | Errors: $($state.Errors.Count)" -ForegroundColor Gray

        # Step 3: Load project configuration
        $config = Get-ProjectConfig -ProjectName $Project.Name

        # Step 4: Get decision history for context
        $history = Get-DecisionHistory -ProjectName $Project.Name -Last 5

        # Step 5: Make decision
        $decision = Invoke-SimpleDecision -SessionState $state -ProjectConfig $config -DecisionHistory $history

        Write-Host "    Decision: $($decision.Action) (confidence: $([math]::Round($decision.Confidence * 100))%)" -ForegroundColor Cyan

        # Step 6: Log the decision
        Add-DecisionLog -ProjectName $Project.Name -Decision $decision -SessionState $state

        # Step 7: Execute action based on decision
        switch ($decision.Action) {
            "continue" {
                if ($state.HasReplyField -and $decision.Command) {
                    Write-Host "    ▶️  Sending command: $($decision.Command)" -ForegroundColor Green
                    Send-ClaudeCodeCommand -Command $decision.Command -ReplyFieldCoordinates $state.ReplyFieldCoordinates
                    $global:WatchdogStats.CommandsSent++
                }
            }

            "check-skills" {
                # Find appropriate skill for the error
                $skill = Find-SkillForError -Error $state.Errors[0] -ProjectConfig $config
                if ($skill) {
                    Write-Host "    🔧 Invoking skill: $skill" -ForegroundColor Magenta
                    Send-SkillCommand -SkillPath $skill -ReplyFieldCoordinates $state.ReplyFieldCoordinates
                    $global:WatchdogStats.CommandsSent++
                }
                else {
                    Write-Host "    ⚠️  No suitable skill found for error" -ForegroundColor Yellow
                    Send-Notification -Title "Manual Intervention Needed" -Message "Error in $($Project.Name) requires attention" -ProjectName $Project.Name
                }
            }

            "phase-transition" {
                Write-Host "    🎯 Phase complete - transition required" -ForegroundColor Yellow
                # Phase transition will be implemented in WS04 (Sprint 3)
                Send-Notification -Title "Phase Complete" -Message "$($Project.Name) phase complete. Review needed." -ProjectName $Project.Name
            }

            "notify" {
                Write-Host "    🔔 Notifying human..." -ForegroundColor Yellow
                Send-Notification -Title "Attention Required" -Message "$($decision.Reasoning)" -ProjectName $Project.Name
            }

            "wait" {
                Write-Verbose "Waiting for session to complete processing"
            }

            default {
                Write-Verbose "No action taken for status: $($state.Status)"
            }
        }

        # Step 8: Update project state
        $stateUpdates = @{
            status = $state.Status
            lastActivity = Get-Date -Format "o"
            todosRemaining = $state.Todos.Remaining
            todosCompleted = $state.Todos.Completed
            decisions = $global:WatchdogStats.DecisionsMade + 1
        }

        Update-ProjectState -ProjectName $Project.Name -StateUpdates $stateUpdates
        Update-RegistrySessionId -ProjectName $Project.Name -SessionId $session.SessionId

        $global:WatchdogStats.ProjectsProcessed++
        $global:WatchdogStats.DecisionsMade++

        Write-Host "    ✅ Processing complete" -ForegroundColor Gray
    }
    catch {
        Write-Warning "Error processing project $($Project.Name): $_"
        throw
    }
}

function Handle-ProjectError {
    <#
    .SYNOPSIS
        Handles errors for a specific project without stopping watchdog
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Project,

        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$Error
    )

    Write-Warning "Error processing project $($Project.Name): $($Error.Exception.Message)"
    Write-WatchdogLog -Message "Project error [$($Project.Name)]: $($Error.Exception.Message)" -Level "Error"

    # Implement error quarantine logic
    $global:WatchdogStats.ErrorsEncountered++

    # Track consecutive errors for this project
    if (-not $script:ProjectErrors) {
        $script:ProjectErrors = @{}
    }

    if (-not $script:ProjectErrors[$Project.Name]) {
        $script:ProjectErrors[$Project.Name] = @{
            Count = 0
            LastError = $null
            FirstErrorTime = $null
        }
    }

    $projectErrorInfo = $script:ProjectErrors[$Project.Name]
    $projectErrorInfo.Count++
    $projectErrorInfo.LastError = $Error.Exception.Message

    if ($projectErrorInfo.Count -eq 1) {
        $projectErrorInfo.FirstErrorTime = Get-Date
    }

    # Quarantine project if too many consecutive errors
    $errorThreshold = 5
    if ($projectErrorInfo.Count -ge $errorThreshold) {
        Write-Warning "Project $($Project.Name) has encountered $($projectErrorInfo.Count) consecutive errors. Quarantining..."

        # Update project status to Quarantined
        try {
            Update-ProjectState -ProjectName $Project.Name -StateUpdates @{
                status = "Quarantined"
                lastActivity = Get-Date -Format "o"
                errors = @($Error.Exception.Message)
            }

            # Send notification
            Send-ErrorNotification -Message "Project $($Project.Name) quarantined after $($projectErrorInfo.Count) errors. Manual intervention required." -ProjectName $Project.Name

            Write-WatchdogLog -Message "Project $($Project.Name) quarantined" -Level "Warning"
        }
        catch {
            Write-Error "Failed to quarantine project: $_"
        }
    }
}

function Find-SkillForError {
    <#
    .SYNOPSIS
        Finds an appropriate skill to resolve an error
    #>
    param(
        [Parameter(Mandatory)]
        [object]$Error,

        [Parameter(Mandatory)]
        [object]$ProjectConfig
    )

    $errorMessage = $Error.Message.ToLower()

    # Map error patterns to skills
    $skillMappings = @{
        "compilation error" = "compilation-error-resolution"
        "type error" = "type-error-resolution"
        "lint" = "lint-error-resolution"
        "test fail" = "test-failure-resolution"
        "syntax error" = "syntax-error-resolution"
    }

    # Find matching skill
    foreach ($pattern in $skillMappings.Keys) {
        if ($errorMessage -match $pattern) {
            $skillName = $skillMappings[$pattern]

            # Check if project has this skill configured
            $skill = $ProjectConfig.skills | Where-Object { $_ -like "*$skillName*" }

            if ($skill) {
                return $skill
            }
        }
    }

    return $null
}

function Initialize-ResourceMonitoring {
    <#
    .SYNOPSIS
        Initializes resource monitoring for WI-3.2
    #>

    $global:WatchdogStats.CyclesCompleted = 0
    $global:WatchdogStats.LastCycleDuration = 0
    $global:WatchdogStats.AverageCpuPercent = 0
    $global:WatchdogStats.PeakMemoryMB = 0
    $global:WatchdogStats.ResourceSamples = @()

    Write-Verbose "Resource monitoring initialized"
}

function Measure-ResourceUsage {
    <#
    .SYNOPSIS
        Measures current resource usage (WI-3.2)
    #>

    try {
        $process = Get-Process -Id $PID -ErrorAction SilentlyContinue

        if ($process) {
            return @{
                CpuTime = $process.CPU
                WorkingSetMB = [math]::Round($process.WorkingSet64 / 1MB, 2)
                Timestamp = Get-Date
            }
        }
    }
    catch {
        Write-Verbose "Failed to measure resources: $_"
    }

    return @{
        CpuTime = 0
        WorkingSetMB = 0
        Timestamp = Get-Date
    }
}

function Update-ResourceMetrics {
    <#
    .SYNOPSIS
        Updates resource usage metrics (WI-3.2)
    #>
    param(
        [hashtable]$PreProcess,
        [hashtable]$PostProcess
    )

    try {
        # Calculate CPU usage percentage
        $cpuDelta = $PostProcess.CpuTime - $PreProcess.CpuTime
        $timeDelta = ($PostProcess.Timestamp - $PreProcess.Timestamp).TotalSeconds

        if ($timeDelta -gt 0) {
            $cpuPercent = ($cpuDelta / $timeDelta) * 100
            $global:WatchdogStats.AverageCpuPercent = $cpuPercent
        }

        # Track peak memory
        if ($PostProcess.WorkingSetMB -gt $global:WatchdogStats.PeakMemoryMB) {
            $global:WatchdogStats.PeakMemoryMB = $PostProcess.WorkingSetMB
        }

        # Keep last 100 samples for trending
        $sample = @{
            Timestamp = $PostProcess.Timestamp
            CpuPercent = $cpuPercent
            MemoryMB = $PostProcess.WorkingSetMB
        }

        $global:WatchdogStats.ResourceSamples += $sample

        if ($global:WatchdogStats.ResourceSamples.Count -gt 100) {
            $global:WatchdogStats.ResourceSamples = $global:WatchdogStats.ResourceSamples[-100..-1]
        }

        # Log if resource usage is high
        if ($cpuPercent -gt 5.0) {
            Write-WatchdogLog -Message "High CPU usage detected: $([math]::Round($cpuPercent, 2))%" -Level "Warning"
        }

        Write-Verbose "Resource usage - CPU: $([math]::Round($cpuPercent, 2))%, Memory: $($PostProcess.WorkingSetMB)MB"
    }
    catch {
        Write-Verbose "Failed to update resource metrics: $_"
    }
}

function Register-ShutdownHandler {
    <#
    .SYNOPSIS
        Registers Ctrl+C handler for graceful shutdown
    #>

    $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        $global:WatchdogRunning = $false
    }
}

function Restore-WatchdogSessions {
    <#
    .SYNOPSIS
        Attempts to restore sessions from previous run (WI-3.6)
    #>

    $recoveryStatePath = "$HOME/.claude-automation/state/watchdog-recovery.json"

    if (-not (Test-Path $recoveryStatePath)) {
        Write-Verbose "No recovery state found"
        return
    }

    try {
        Write-Host "🔄 Attempting session recovery..." -ForegroundColor Cyan

        $recoveryState = Get-Content $recoveryStatePath -Raw | ConvertFrom-Json

        # Check if recovery state is recent (within last 24 hours)
        $savedTime = [DateTime]::Parse($recoveryState.SavedAt)
        $timeSinceSave = (Get-Date) - $savedTime

        if ($timeSinceSave.TotalHours -gt 24) {
            Write-Host "  ⚠️  Recovery state too old ($([math]::Round($timeSinceSave.TotalHours, 1))h). Skipping..." -ForegroundColor Yellow
            return
        }

        Write-Host "  📁 Recovery state from $($savedTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray

        $recoveredCount = 0
        $failedCount = 0

        foreach ($projectState in $recoveryState.Projects) {
            try {
                # Restore project state
                $projectName = $projectState.ProjectName

                Write-Host "  🔧 Restoring: $projectName..." -ForegroundColor Gray

                # Check if project still registered
                $projects = Get-RegisteredProjects
                $project = $projects | Where-Object { $_.Name -eq $projectName }

                if (-not $project) {
                    Write-Warning "  Project '$projectName' no longer registered. Skipping..."
                    $failedCount++
                    continue
                }

                # Restore state if session is still active
                $session = Find-ClaudeCodeSession -ProjectName $projectName

                if ($session) {
                    Write-Host "    ✅ Session found - state restored" -ForegroundColor Green
                    $recoveredCount++

                    # Update registry with restored session
                    Update-RegistrySessionId -ProjectName $projectName -SessionId $session.SessionId

                    # Send recovery notification
                    Send-Notification -Title "Session Recovered" -Message "Project '$projectName' session recovered successfully" -ProjectName $projectName
                }
                else {
                    Write-Verbose "  Session for '$projectName' not found - may have closed"
                    $failedCount++
                }
            }
            catch {
                Write-Warning "  Failed to restore project $($projectState.ProjectName): $_"
                $failedCount++
            }
        }

        Write-Host "  📊 Recovery complete: $recoveredCount restored, $failedCount unavailable" -ForegroundColor Cyan
        Write-WatchdogLog -Message "Session recovery: $recoveredCount restored, $failedCount failed" -Level "Info"

        # Clean up old recovery file
        Remove-Item $recoveryStatePath -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Session recovery failed: $_"
        Write-WatchdogLog -Message "Session recovery error: $_" -Level "Error"
    }
}

function Save-WatchdogState {
    <#
    .SYNOPSIS
        Saves watchdog state for recovery (WI-3.6)
    #>

    $recoveryStatePath = "$HOME/.claude-automation/state/watchdog-recovery.json"

    try {
        Write-Verbose "Saving watchdog state for recovery..."

        # Get all active projects
        $projects = Get-ActiveProjects

        $projectStates = @()

        foreach ($project in $projects) {
            try {
                # Get current session if available
                $session = Find-ClaudeCodeSession -ProjectName $project.Name

                if ($session) {
                    $projectState = @{
                        ProjectName = $project.Name
                        SessionId = $session.SessionId
                        LastActive = (Get-Date).ToString("o")
                    }

                    $projectStates += $projectState
                }
            }
            catch {
                Write-Verbose "Failed to save state for $($project.Name): $_"
            }
        }

        $recoveryState = @{
            SavedAt = (Get-Date).ToString("o")
            Projects = $projectStates
            Statistics = $global:WatchdogStats
        }

        # Ensure directory exists
        $stateDir = Split-Path $recoveryStatePath
        if (-not (Test-Path $stateDir)) {
            New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
        }

        # Save recovery state
        $recoveryState | ConvertTo-Json -Depth 10 | Set-Content $recoveryStatePath -Force

        Write-Verbose "Watchdog state saved successfully ($($projectStates.Count) projects)"
        Write-WatchdogLog -Message "State saved for recovery: $($projectStates.Count) projects" -Level "Info"
    }
    catch {
        Write-Warning "Failed to save watchdog state: $_"
        Write-WatchdogLog -Message "State save error: $_" -Level "Error"
    }
}

function Update-Heartbeat {
    <#
    .SYNOPSIS
        Updates heartbeat timestamp
    #>

    $heartbeatFile = "$HOME/.claude-automation/watchdog-heartbeat.txt"
    Get-Date | Out-File -FilePath $heartbeatFile -Force
}

function Cleanup-WatchdogResources {
    <#
    .SYNOPSIS
        Performs cleanup before shutdown
    #>

    Write-WatchdogLog -Message "Watchdog stopped" -Level "Info"

    # Save final statistics
    if ($global:WatchdogStats) {
        $statsPath = "$HOME/.claude-automation/state/final-stats-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $global:WatchdogStats | ConvertTo-Json | Set-Content $statsPath -Force
        Write-Verbose "Saved final statistics to $statsPath"
    }

    # Log session summary (enhanced with WI-3.2 metrics)
    $duration = (Get-Date) - $global:WatchdogStartTime
    Write-Host "`n📊 Session Summary:" -ForegroundColor Cyan
    Write-Host "   Duration: $([math]::Round($duration.TotalHours, 2)) hours" -ForegroundColor Gray
    Write-Host "   Cycles Completed: $($global:WatchdogStats.CyclesCompleted)" -ForegroundColor Gray
    Write-Host "   Projects Processed: $($global:WatchdogStats.ProjectsProcessed)" -ForegroundColor Gray
    Write-Host "   Decisions Made: $($global:WatchdogStats.DecisionsMade)" -ForegroundColor Gray
    Write-Host "   Commands Sent: $($global:WatchdogStats.CommandsSent)" -ForegroundColor Gray
    Write-Host "   Errors Encountered: $($global:WatchdogStats.ErrorsEncountered)" -ForegroundColor Gray
    Write-Host "`n📈 Resource Usage:" -ForegroundColor Cyan
    Write-Host "   Average CPU: $([math]::Round($global:WatchdogStats.AverageCpuPercent, 2))%" -ForegroundColor Gray
    Write-Host "   Peak Memory: $($global:WatchdogStats.PeakMemoryMB) MB" -ForegroundColor Gray
    Write-Host "   Last Cycle Duration: $([math]::Round($global:WatchdogStats.LastCycleDuration, 2))s" -ForegroundColor Gray

    # Perform log rotation
    try {
        Initialize-LogRotation
    }
    catch {
        Write-Verbose "Log rotation failed: $_"
    }

    # Unregister event handlers
    Get-EventSubscriber | Where-Object { $_.SourceIdentifier -eq "PowerShell.Exiting" } | Unregister-Event -Force
}

# Entry point
Start-Watchdog -PollingIntervalSeconds $PollingInterval -MaxRunHours $MaxRunDuration
