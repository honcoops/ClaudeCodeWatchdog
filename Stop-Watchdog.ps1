<#
.SYNOPSIS
    Convenience wrapper to stop the Claude Code Watchdog

.DESCRIPTION
    Stops the watchdog from the project root directory

.EXAMPLE
    .\Stop-Watchdog.ps1

.NOTES
    Part of the Claude Code Watchdog project
#>

$scriptPath = Join-Path $PSScriptRoot "src/Core/Stop-Watchdog.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Stop-Watchdog.ps1 not found at $scriptPath"
    exit 1
}

& $scriptPath
