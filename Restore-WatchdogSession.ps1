<#
.SYNOPSIS
    Manually restore Claude Code Watchdog sessions from saved state

.DESCRIPTION
    This script allows manual recovery of watchdog sessions after a crash or
    unexpected shutdown. It reads the saved recovery state and attempts to
    reconnect to active Claude Code sessions.

.PARAMETER Force
    Force recovery even if state is older than 24 hours

.PARAMETER ProjectName
    Restore only a specific project (optional)

.EXAMPLE
    .\Restore-WatchdogSession.ps1

.EXAMPLE
    .\Restore-WatchdogSession.ps1 -ProjectName "my-project"

.EXAMPLE
    .\Restore-WatchdogSession.ps1 -Force

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS05 - Project Management
    Work Item: WI-3.6 - Session Recovery System
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [string]$ProjectName
)

# Import required modules
$ScriptRoot = Split-Path -Parent $PSCommandPath
. "$ScriptRoot/src/Registry/Get-RegisteredProjects.ps1"
. "$ScriptRoot/src/Registry/Update-ProjectState.ps1"
. "$ScriptRoot/src/Detection/Find-ClaudeCodeSession.ps1"
. "$ScriptRoot/src/Logging/Write-WatchdogLog.ps1"
. "$ScriptRoot/src/Logging/Send-Notification.ps1"

function Restore-WatchdogSession {
    param(
        [switch]$ForceRecovery,
        [string]$SpecificProject
    )

    $recoveryStatePath = "$HOME/.claude-automation/state/watchdog-recovery.json"

    if (-not (Test-Path $recoveryStatePath)) {
        Write-Host "❌ No recovery state found at: $recoveryStatePath" -ForegroundColor Red
        Write-Host "   Recovery state is created when watchdog shuts down normally." -ForegroundColor Gray
        return
    }

    try {
        Write-Host "🔄 Claude Code Watchdog - Session Recovery" -ForegroundColor Cyan
        Write-Host "=" * 60 -ForegroundColor Gray

        $recoveryState = Get-Content $recoveryStatePath -Raw | ConvertFrom-Json

        # Check if recovery state is recent
        $savedTime = [DateTime]::Parse($recoveryState.SavedAt)
        $timeSinceSave = (Get-Date) - $savedTime

        Write-Host "`n📁 Recovery state found:" -ForegroundColor Cyan
        Write-Host "   Saved at: $($savedTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
        Write-Host "   Age: $([math]::Round($timeSinceSave.TotalHours, 1)) hours" -ForegroundColor Gray
        Write-Host "   Projects: $($recoveryState.Projects.Count)" -ForegroundColor Gray

        if ($timeSinceSave.TotalHours -gt 24 -and -not $ForceRecovery) {
            Write-Host "`n⚠️  Recovery state is older than 24 hours." -ForegroundColor Yellow
            Write-Host "   Use -Force to proceed anyway." -ForegroundColor Gray
            return
        }

        Write-Host "`n🔧 Starting recovery process..." -ForegroundColor Cyan

        $recoveredCount = 0
        $failedCount = 0
        $skippedCount = 0

        foreach ($projectState in $recoveryState.Projects) {
            $projectName = $projectState.ProjectName

            # Skip if specific project requested and this isn't it
            if ($SpecificProject -and $projectName -ne $SpecificProject) {
                $skippedCount++
                continue
            }

            try {
                Write-Host "`n  📦 $projectName" -ForegroundColor White

                # Check if project still registered
                $projects = Get-RegisteredProjects
                $project = $projects | Where-Object { $_.Name -eq $projectName }

                if (-not $project) {
                    Write-Host "    ⚠️  Project no longer registered" -ForegroundColor Yellow
                    $failedCount++
                    continue
                }

                # Look for active session
                Write-Host "    🔍 Searching for Claude Code session..." -ForegroundColor Gray
                $session = Find-ClaudeCodeSession -ProjectName $projectName

                if ($session) {
                    Write-Host "    ✅ Session found: $($session.SessionId)" -ForegroundColor Green

                    # Update registry with restored session
                    Update-RegistrySessionId -ProjectName $projectName -SessionId $session.SessionId

                    # Update project state
                    Update-ProjectState -ProjectName $projectName -StateUpdates @{
                        status = "Active"
                        lastActivity = (Get-Date).ToString("o")
                        sessionRecovered = $true
                    }

                    # Send notification
                    Send-Notification -Title "Session Recovered" `
                        -Message "Project '$projectName' session recovered successfully" `
                        -ProjectName $projectName

                    $recoveredCount++
                }
                else {
                    Write-Host "    ❌ No active session found" -ForegroundColor Red
                    Write-Host "       Start Claude Code and open this project to resume" -ForegroundColor Gray
                    $failedCount++
                }
            }
            catch {
                Write-Host "    ❌ Recovery failed: $_" -ForegroundColor Red
                $failedCount++
            }
        }

        Write-Host "`n" + ("=" * 60) -ForegroundColor Gray
        Write-Host "📊 Recovery Summary:" -ForegroundColor Cyan
        Write-Host "   ✅ Recovered: $recoveredCount" -ForegroundColor Green
        Write-Host "   ❌ Failed: $failedCount" -ForegroundColor Red

        if ($skippedCount -gt 0) {
            Write-Host "   ⏭️  Skipped: $skippedCount" -ForegroundColor Gray
        }

        if ($recoveredCount -gt 0) {
            Write-Host "`n✨ You can now start the watchdog with: .\Start-Watchdog.ps1" -ForegroundColor Cyan
        }

        # Clean up recovery file if all successful
        if ($failedCount -eq 0 -and $recoveredCount -gt 0) {
            Remove-Item $recoveryStatePath -Force -ErrorAction SilentlyContinue
            Write-Verbose "Cleaned up recovery state file"
        }
    }
    catch {
        Write-Host "`n❌ Recovery error: $_" -ForegroundColor Red
        Write-Host "   Check the recovery state file: $recoveryStatePath" -ForegroundColor Gray
    }
}

# Execute recovery
Restore-WatchdogSession -ForceRecovery:$Force -SpecificProject $ProjectName
