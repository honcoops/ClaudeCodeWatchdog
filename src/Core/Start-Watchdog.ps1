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
. "$ScriptRoot/../Detection/Get-ClaudeCodeState.ps1"
. "$ScriptRoot/../Decision/Invoke-SimpleDecision.ps1"
. "$ScriptRoot/../Action/Send-ClaudeCodeCommand.ps1"
. "$ScriptRoot/../Logging/Write-WatchdogLog.ps1"
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

    # TODO: Implement project processing logic
    # 1. Find Claude Code session for this project
    # 2. Get current state
    # 3. Make decision
    # 4. Execute action
    # 5. Update project state
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

    # TODO: Implement error quarantine logic
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

    # TODO: Save any pending state
    # TODO: Close any open handles
}

# Entry point
Start-Watchdog -PollingIntervalSeconds $PollingInterval -MaxRunHours $MaxRunDuration
