<#
.SYNOPSIS
    Stops the Claude Code Watchdog gracefully

.DESCRIPTION
    Signals the running watchdog process to shut down gracefully

.EXAMPLE
    .\Stop-Watchdog.ps1

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
#>

function Stop-Watchdog {
    <#
    .SYNOPSIS
        Gracefully stops the watchdog process
    #>

    Write-Host "🛑 Stopping Claude Code Watchdog..." -ForegroundColor Yellow

    # Set the global flag to stop the main loop
    if (Get-Variable -Name WatchdogRunning -Scope Global -ErrorAction SilentlyContinue) {
        $global:WatchdogRunning = $false
        Write-Host "✅ Shutdown signal sent" -ForegroundColor Green
    }
    else {
        Write-Warning "Watchdog doesn't appear to be running"
    }
}

# Entry point
Stop-Watchdog
