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
    Workstream: WS01 - Core Infrastructure
#>

[CmdletBinding()]
param(
    [Parameter()]
    [int]$PollingInterval = 120,

    [Parameter()]
    [int]$MaxRunDuration = 0
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

        # Register shutdown handler
        Register-ShutdownHandler

        Write-Host "✅ Watchdog initialized. Polling every $PollingIntervalSeconds seconds" -ForegroundColor Green
        Write-WatchdogLog -Message "Watchdog started" -Level "Info"

        # Main loop
        while ($global:WatchdogRunning) {
            try {
                # Check max runtime
                if ($MaxRunHours -gt 0) {
                    $elapsed = (Get-Date) - $startTime
                    if ($elapsed.TotalHours -ge $MaxRunHours) {
                        Write-Host "⏰ Max runtime reached ($MaxRunHours hours). Shutting down..." -ForegroundColor Yellow
                        break
                    }
                }

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

                # Update heartbeat
                Update-Heartbeat

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

        if (-not $session) {
            Write-Verbose "No active session found for $($Project.Name)"
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

function Register-ShutdownHandler {
    <#
    .SYNOPSIS
        Registers Ctrl+C handler for graceful shutdown
    #>

    $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        $global:WatchdogRunning = $false
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

    # Log session summary
    $duration = (Get-Date) - $global:WatchdogStartTime
    Write-Host "`n📊 Session Summary:" -ForegroundColor Cyan
    Write-Host "   Duration: $([math]::Round($duration.TotalHours, 2)) hours" -ForegroundColor Gray
    Write-Host "   Projects Processed: $($global:WatchdogStats.ProjectsProcessed)" -ForegroundColor Gray
    Write-Host "   Decisions Made: $($global:WatchdogStats.DecisionsMade)" -ForegroundColor Gray
    Write-Host "   Commands Sent: $($global:WatchdogStats.CommandsSent)" -ForegroundColor Gray
    Write-Host "   Errors Encountered: $($global:WatchdogStats.ErrorsEncountered)" -ForegroundColor Gray

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
